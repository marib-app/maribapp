<?php

namespace App\Http\Controllers\Wifi;

use App\Enums\Wifi\WifiCodeStatus;
use App\Enums\Wifi\WifiNetworkStatus;
use App\Enums\Wifi\WifiPlanStatus;
use App\Enums\Wifi\WifiReportStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Wifi\AdminUpdateWifiNetworkStatusRequest;
use App\Http\Requests\Wifi\AdminUpdateWifiReportRequest;
use App\Http\Requests\Wifi\UpsertReputationCounterRequest;
use App\Http\Resources\Wifi\ReputationCounterResource;
use App\Http\Resources\Wifi\WifiNetworkResource;
use App\Http\Resources\Wifi\WifiReportResource;
use App\Models\Wifi\ReputationCounter;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiReport;
use App\Services\Audit\AuditLogger;
use App\Services\NotificationService;
use App\Models\UserFcmToken;
use App\Services\NotificationDispatchService;
use App\Data\Notifications\NotificationIntent;
use App\Enums\NotificationType;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class AdminModerationController extends Controller
{
    public function __construct(private AuditLogger $auditLogger)
    {
    }

    public function networks(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'status' => ['nullable', 'string', 'in:active,inactive,suspended'],
            'owner_id' => ['nullable', 'integer', 'exists:users,id'],
            'q' => ['nullable', 'string', 'max:120'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = WifiNetwork::query()
            ->with('owner:id,name,email')
            ->withCount([
                'plans',
                'plans as active_plans_count' => static function ($q): void {
                    $q->where('status', WifiPlanStatus::ACTIVE->value);
                },
                'codes as codes_total',
                'codes as codes_available' => static function ($q): void {
                    $q->where('status', WifiCodeStatus::AVAILABLE->value);
                },
                'codes as codes_sold' => static function ($q): void {
                    $q->where('status', WifiCodeStatus::SOLD->value);
                },
            ]);

        if (! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (! empty($filters['owner_id'])) {
            $query->where('user_id', $filters['owner_id']);
        }

        if (! empty($filters['q'])) {
            $term = strtolower($filters['q']);
            $query->where(static function (Builder $builder) use ($term): void {
                $builder->whereRaw('LOWER(name) LIKE ?', ['%' . $term . '%'])
                    ->orWhereRaw('LOWER(address) LIKE ?', ['%' . $term . '%']);
            });
        }

        $networks = $query
            ->orderByDesc('created_at')
            ->paginate($filters['per_page'] ?? 20)
            ->appends($request->query());

        \Log::info('wifi.admin.networks.fetch', [
            'user_id' => $request->user()?->id,
            'filters' => $filters,
            'total' => $networks->total(),
        ]);

        $resource = WifiNetworkResource::collection($networks);
        $resolved = $resource->response($request)->getData(true);
        $rows = $resolved['data'] ?? [];

        return response()->json([
            'total' => $networks->total(),
            'rows' => $rows,
        ]);
    }

    public function updateNetworkStatus(AdminUpdateWifiNetworkStatusRequest $request, WifiNetwork $network): WifiNetworkResource
    {
        $validated = $request->validated();
        $target = WifiNetworkStatus::from($validated['status']);

        $network->status = $target;

        if (! empty($validated['reason'])) {
            $meta = $network->meta ?? [];
            $meta['moderation_reason'] = $validated['reason'];
            $network->meta = $meta;
        }

        $dirty = array_keys($network->getDirty());
        if ($dirty === []) {
            return WifiNetworkResource::make($network->refresh());
        }

        $this->auditLogger->logChanges($network, 'wifi.network.moderated', $dirty, $request->user(), [
            'description' => 'Wifi network status updated by administrator',
        ]);

        $network->save();
        $this->notifyOwnerNetworkUpdated($network, $target, $validated['reason'] ?? null);

        return WifiNetworkResource::make($network->refresh());
    }

    private function notifyOwnerNetworkUpdated(WifiNetwork $network, WifiNetworkStatus $status, ?string $reason = null): void
    {
        if (! $network->user_id) {
            return;
        }

        $title = match ($status) {
            WifiNetworkStatus::ACTIVE => 'تم تفعيل شبكتك',
            WifiNetworkStatus::SUSPENDED => 'تم إيقاف شبكتك مؤقتاً',
            WifiNetworkStatus::INACTIVE => 'تم إيقاف شبكتك',
            default => 'تم تحديث حالة الشبكة',
        };

        $updatedAt = now()->format('Y-m-d H:i');
        $lines = [
            "الشبكة: {$network->name}",
            "الحالة الجديدة: {$status->label()}",
            "التاريخ: {$updatedAt}",
        ];

        if (! empty($reason)) {
            $lines[] = "السبب: {$reason}";
        }

        $lines[] = in_array($status, [WifiNetworkStatus::SUSPENDED, WifiNetworkStatus::INACTIVE], true)
            ? 'الشبكة لن تظهر للمستخدمين حتى إعادة التفعيل.'
            : 'الشبكة مفعلة الآن ومشاهدة للمستخدمين.';

        $body = implode(' • ', $lines);
        $deeplink = url('/wifi-cabin/networks/' . $network->id);

        $payload = [
            'network_id' => $network->id,
            'network_name' => $network->name,
            'status' => $status->value,
            'status_label' => $status->label(),
            'reason' => $reason,
            'updated_at' => $updatedAt,
            'deeplink' => $deeplink,
            'action' => 'open_url',
        ];

        $intent = new NotificationIntent(
            userId: $network->user_id,
            type: NotificationType::ActionRequest,
            title: $title,
            body: $body,
            deeplink: $deeplink,
            entity: 'wifi_network_status',
            entityId: $network->id . '-' . $status->value,
            data: $payload,
            meta: [
                'source' => 'wifi_admin',
                'event' => 'network_status_updated',
            ],
        );

        app(NotificationDispatchService::class)->dispatch($intent);

        $tokens = UserFcmToken::query()
            ->where('user_id', $network->user_id)
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if ($tokens !== []) {
            NotificationService::sendFcmNotification(
                $tokens,
                $title,
                $body,
                'wifi_network_status_updated',
                $payload,
                false
            );
        }
    }
    public function reports(Request $request): AnonymousResourceCollection
    {
        $filters = $request->validate([
            'status' => ['nullable', 'string', 'in:open,investigating,resolved,dismissed'],
            'network_id' => ['nullable', 'integer', 'exists:wifi_networks,id'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = WifiReport::query()->with('network:id,name,slug,status');

        if (! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (! empty($filters['network_id'])) {
            $query->where('wifi_network_id', $filters['network_id']);
        }

        $reports = $query
            ->orderByDesc('created_at')
            ->paginate($filters['per_page'] ?? 20)
            ->appends($request->query());

        return WifiReportResource::collection($reports);
    }

    public function updateReport(AdminUpdateWifiReportRequest $request, WifiReport $report): WifiReportResource
    {
        $validated = $request->validated();

        $report->status = WifiReportStatus::from($validated['status']);
        $report->assigned_to = $validated['assigned_to'] ?? null;
        $report->resolution_notes = $validated['resolution_notes'] ?? $report->resolution_notes;

        if ($report->status === WifiReportStatus::RESOLVED) {
            $report->resolved_at = $report->resolved_at ?? now();
        }

        if ($report->status === WifiReportStatus::DISMISSED) {
            $report->resolved_at = now();
        }

        $dirty = array_keys($report->getDirty());
        if ($dirty === []) {
            return WifiReportResource::make($report->refresh());
        }

        $this->auditLogger->logChanges($report, 'wifi.report.moderated', $dirty, $request->user(), [
            'description' => 'Wifi report updated by administrator',
        ]);

        $report->save();

        return WifiReportResource::make($report->refresh());
    }

    public function reputationCounters(Request $request): AnonymousResourceCollection
    {
        $filters = $request->validate([
            'network_id' => ['nullable', 'integer', 'exists:wifi_networks,id'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = ReputationCounter::query()->with('network:id,name,slug');

        if (! empty($filters['network_id'])) {
            $query->where('wifi_network_id', $filters['network_id']);
        }

        $counters = $query
            ->orderByDesc('period_start')
            ->paginate($filters['per_page'] ?? 20)
            ->appends($request->query());

        return ReputationCounterResource::collection($counters);
    }

    public function storeReputationCounter(UpsertReputationCounterRequest $request, WifiNetwork $network): JsonResponse
    {
        $data = $request->validated();

        $counter = ReputationCounter::create([
            'wifi_network_id' => $network->id,
            'metric' => $data['metric'],
            'score' => $data['score'],
            'value' => $data['value'],
            'period_start' => $data['period_start'] ?? null,
            'period_end' => $data['period_end'] ?? null,
            'meta' => $data['meta'] ?? null,
        ]);

        $this->auditLogger->logChanges($counter, 'wifi.reputation.created', ['metric', 'score', 'value'], $request->user(), [
            'description' => 'Reputation counter created by administrator',
        ]);

        return ReputationCounterResource::make($counter)->response()->setStatusCode(201);
    }

    public function updateReputationCounter(UpsertReputationCounterRequest $request, ReputationCounter $counter): ReputationCounterResource
    {
        $counter->fill($request->validated());

        $dirty = array_keys($counter->getDirty());
        if ($dirty === []) {
            return ReputationCounterResource::make($counter->refresh());
        }

        $this->auditLogger->logChanges($counter, 'wifi.reputation.updated', $dirty, $request->user(), [
            'description' => 'Reputation counter updated by administrator',
        ]);

        $counter->save();

        return ReputationCounterResource::make($counter->refresh());
    }
}













