<?php



namespace App\Http\Controllers\Wifi;

use App\Enums\Wifi\WifiCodeBatchStatus;
use App\Enums\Wifi\WifiCodeStatus;
use App\Enums\Wifi\WifiNetworkStatus;
use App\Enums\Wifi\WifiPlanStatus;
use App\Enums\Wifi\WifiReportStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Wifi\OwnerNetworkStatsRequest;
use App\Http\Requests\Wifi\SetWifiCommissionRequest;
use App\Http\Requests\Wifi\StoreWifiNetworkRequest;
use App\Http\Requests\Wifi\ToggleWifiNetworkAvailabilityRequest;
use App\Http\Requests\Wifi\UpdateWifiNetworkRequest;
use App\Http\Resources\Wifi\ReputationCounterResource;
use App\Http\Resources\Wifi\WifiNetworkResource;
use App\Data\Notifications\NotificationIntent;
use App\Enums\NotificationType;
use App\Models\Wifi\ReputationCounter;
use App\Models\Wifi\WifiCode;
use App\Models\Wifi\WifiCodeBatch;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiReport;
use App\Services\Audit\AuditLogger;
use App\Services\NotificationDispatchService;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Storage;

class OwnerNetworkController extends Controller
{
    public function __construct(private AuditLogger $auditLogger)
    {
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $request->user();
        $perPage = (int) $request->integer('per_page', 15);

        $networks = WifiNetwork::query()
            ->where('user_id', $user->id)
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
            ])
            ->orderByDesc('created_at')
            ->paginate($perPage)
            ->appends($request->query());

        return WifiNetworkResource::collection($networks);
    }

    public function store(StoreWifiNetworkRequest $request): JsonResponse
    {
        $data = $request->validated();
        $logoFile = $request->file('logo');
        $loginScreenshotFile = $request->file('login_screenshot');

        unset($data['logo'], $data['login_screenshot']);

        $network = new WifiNetwork($data);
        $network->user_id = $request->user()->id;

        $auditFields = array_keys($data);

        if ($logoFile !== null) {
            $network->icon_path = $this->storeNetworkMedia($logoFile, 'wifi/networks/logos');
            $auditFields[] = 'icon_path';
        }

        if ($loginScreenshotFile !== null) {
            $network->login_screenshot_path = $this->storeNetworkMedia($loginScreenshotFile, 'wifi/networks/screenshots');
            $auditFields[] = 'login_screenshot_path';
        }

        $network->save();
        $network->refresh();

        $this->auditLogger->logChanges($network, 'wifi.network.created', array_unique($auditFields), $request->user(), [
            'description' => 'Wifi network created by owner',
        ]);

        return WifiNetworkResource::make($network)->response()->setStatusCode(201);
    }

    public function show(WifiNetwork $network): WifiNetworkResource
    {
        $this->authorize('view', $network);

        return WifiNetworkResource::make($network->load('plans'));
    }

    public function update(UpdateWifiNetworkRequest $request, WifiNetwork $network): WifiNetworkResource
    {
        $data = $request->validated();
        $network->fill($data);

        $dirty = array_keys($network->getDirty());
        if ($dirty === []) {
            return WifiNetworkResource::make($network->refresh());
        }

        $this->auditLogger->logChanges($network, 'wifi.network.updated', $dirty, $request->user(), [
            'description' => 'Wifi network updated by owner',
        ]);

        $network->save();

        return WifiNetworkResource::make($network->refresh());
    }

    public function destroy(Request $request, WifiNetwork $network)
    {
        $this->authorize('delete', $network);

        $iconPath = $network->icon_path;
        $loginScreenshotPath = $network->login_screenshot_path;

        $this->auditLogger->logChanges($network, 'wifi.network.deleted', ['status'], $request->user(), [
            'description' => 'Wifi network deleted by owner',
        ]);

        $network->delete();

        if (! empty($iconPath)) {
            Storage::disk('public')->delete($iconPath);
        }

        if (! empty($loginScreenshotPath)) {
            Storage::disk('public')->delete($loginScreenshotPath);
        }

        return response()->noContent();
    }

    public function setCommission(SetWifiCommissionRequest $request, WifiNetwork $network): WifiNetworkResource
    {
        $commission = (float) $request->validated('commission_rate');

        $settings = $network->settings ?? [];
        $settings['commission_rate'] = $commission;
        $network->settings = $settings;

        $dirty = array_keys($network->getDirty());
        if ($dirty !== []) {
            $this->auditLogger->logChanges($network, 'wifi.network.commission_updated', $dirty, $request->user(), [
                'description' => 'Wifi network commission updated by owner',
            ]);
            $network->save();
            $this->notifyCommissionUpdated($network, $commission);
        }

        return WifiNetworkResource::make($network->refresh());
    }

    public function toggleAvailability(ToggleWifiNetworkAvailabilityRequest $request, WifiNetwork $network): WifiNetworkResource
    {
        $validated = $request->validated();
        $target = WifiNetworkStatus::from($validated['status']);

        $network->status = $target;

        if (! empty($validated['reason'])) {
            $meta = $network->meta ?? [];
            $meta['availability_reason'] = $validated['reason'];
            $network->meta = $meta;
        }

        $dirty = array_keys($network->getDirty());
        if ($dirty !== []) {
            $this->auditLogger->logChanges($network, 'wifi.network.status_toggled', $dirty, $request->user(), [
                'description' => 'Wifi network availability toggled by owner',
            ]);
            $network->save();
        }

        return WifiNetworkResource::make($network->refresh());
    }

    public function stats(OwnerNetworkStatsRequest $request, WifiNetwork $network): JsonResponse
    {
        $from = $request->date('from');
        $to = $request->date('to');

        $planQuery = $network->plans();
        if ($from) {
            $planQuery->whereDate('created_at', '>=', $from);
        }
        if ($to) {
            $planQuery->whereDate('created_at', '<=', $to);
        }

        $plansTotal = (clone $planQuery)->count();
        $plansActive = (clone $planQuery)->where('status', WifiPlanStatus::ACTIVE->value)->count();
        $plansArchived = (clone $planQuery)->where('status', WifiPlanStatus::ARCHIVED->value)->count();

        $batchQuery = WifiCodeBatch::query()->whereHas('plan', static function ($query) use ($network, $from, $to): void {
            $query->where('wifi_network_id', $network->id);
            if ($from) {
                $query->whereDate('wifi_code_batches.created_at', '>=', $from);
            }
            if ($to) {
                $query->whereDate('wifi_code_batches.created_at', '<=', $to);
            }
        });

        $batchesTotal = (clone $batchQuery)->count();
        $batchesActive = (clone $batchQuery)->where('status', WifiCodeBatchStatus::ACTIVE->value)->count();

        $codeQuery = WifiCode::query()->whereHas('plan', static function ($query) use ($network): void {
            $query->where('wifi_network_id', $network->id);
        });

        if ($from) {
            $codeQuery->whereDate('created_at', '>=', $from);
        }
        if ($to) {
            $codeQuery->whereDate('created_at', '<=', $to);
        }

        $codesTotal = (clone $codeQuery)->count();
        $codesAvailable = (clone $codeQuery)->where('status', WifiCodeStatus::AVAILABLE->value)->count();
        $codesSold = (clone $codeQuery)->where('status', WifiCodeStatus::SOLD->value)->count();

        $reportQuery = WifiReport::query()->where('wifi_network_id', $network->id);
        if ($from) {
            $reportQuery->whereDate('created_at', '>=', $from);
        }
        if ($to) {
            $reportQuery->whereDate('created_at', '<=', $to);
        }

        $reportsOpen = (clone $reportQuery)->where('status', WifiReportStatus::OPEN->value)->count();
        $reportsInvestigating = (clone $reportQuery)->where('status', WifiReportStatus::INVESTIGATING->value)->count();
        $reportsResolved = (clone $reportQuery)->where('status', WifiReportStatus::RESOLVED->value)->count();

        $counters = ReputationCounter::query()
            ->where('wifi_network_id', $network->id)
            ->get();

        $stats = [
            'plans' => [
                'total' => $plansTotal,
                'active' => $plansActive,
                'archived' => $plansArchived,
            ],
            'batches' => [
                'total' => $batchesTotal,
                'active' => $batchesActive,
            ],
            'codes' => [
                'total' => $codesTotal,
                'available' => $codesAvailable,
                'sold' => $codesSold,
            ],
            'reports' => [
                'open' => $reportsOpen,
                'investigating' => $reportsInvestigating,
                'resolved' => $reportsResolved,
            ],
            'reputation_counters' => ReputationCounterResource::collection($counters),
        ];

        $network->statistics = Arr::except($stats, ['reputation_counters']);

        return response()->json([
            'data' => [
                'network' => WifiNetworkResource::make($network)->resolve(),
                'reputation_counters' => ReputationCounterResource::collection($counters)->resolve(),
            ],
        ]);
    }

    public function codes(Request $request, WifiNetwork $network): JsonResponse
    {
        $this->authorize('view', $network);

        $perPage = max(5, min(100, (int) $request->integer('per_page', 25)));
        $search = trim((string) $request->input('search', ''));
        $statusFilter = $request->input('status');

        $baseQuery = WifiCode::query()
            ->where('wifi_network_id', $network->getKey());

        $totalCount = (clone $baseQuery)->count();
        $availableCount = (clone $baseQuery)
            ->where('status', WifiCodeStatus::AVAILABLE->value)
            ->count();
        $soldCount = (clone $baseQuery)
            ->where('status', WifiCodeStatus::SOLD->value)
            ->count();

        $query = $baseQuery
            ->with(['plan:id,name'])
            ->leftJoin('users', 'users.id', '=', 'wifi_codes.allocated_to_user_id')
            ->select('wifi_codes.*', 'users.name as allocated_user_name', 'users.email as allocated_user_email')
            ->orderByDesc('wifi_codes.id');

        if ($search !== '') {
            $term = '%' . $search . '%';
            $query->where(static function ($q) use ($term): void {
                $q->where('wifi_codes.code_suffix', 'like', $term)
                    ->orWhere('wifi_codes.code_last4', 'like', $term)
                    ->orWhere('wifi_codes.serial_no_encrypted', 'like', $term)
                    ->orWhere('wifi_codes.id', 'like', $term);
            });
        }

        if (is_string($statusFilter) && $statusFilter !== '') {
            $query->where('wifi_codes.status', $statusFilter);
        }

        /** @var LengthAwarePaginator $codes */
        $codes = $query->paginate($perPage)->appends($request->query());

        $data = $codes->getCollection()->map(static function (WifiCode $code): array {
            return [
                'id' => $code->id,
                'status' => $code->status,
                'code_suffix' => $code->code_suffix,
                'code_last4' => $code->code_last4,
                'plan_id' => $code->wifi_plan_id,
                'plan_name' => $code->plan->name ?? null,
                'allocated_to_user_id' => $code->allocated_to_user_id,
                'allocated_user_name' => $code->allocated_user_name,
                'allocated_user_email' => $code->allocated_user_email,
                'allocated_at' => $code->allocated_at,
                'sold_at' => $code->sold_at,
                'delivered_at' => $code->delivered_at,
                'revealed_at' => $code->revealed_at,
            ];
        })->values();

        return response()->json([
            'data' => $data,
            'meta' => [
                'total' => $totalCount,
                'available' => $availableCount,
                'sold' => $soldCount,
                'current_page' => $codes->currentPage(),
                'last_page' => $codes->lastPage(),
                'per_page' => $codes->perPage(),
            ],
        ]);
    }

    private function storeNetworkMedia(UploadedFile $file, string $directory): string
    {
        return $file->store($directory, 'public');
    }

    private function notifyCommissionUpdated(WifiNetwork $network, float $commissionRate): void
    {
        if (! $network->user_id) {
            return;
        }

        $updatedAt = now()->format('Y-m-d H:i');
        $title = 'تم فرض عمولة جديدة على شبكتك';
        $body = implode(' • ', [
            "الشبكة: {$network->name}",
            'العمولة الجديدة: ' . number_format($commissionRate * 100, 2) . '%',
            "التاريخ: {$updatedAt}",
            'سيتم احتساب العمولة تلقائياً عند كل عملية بيع.',
        ]);

        $deeplink = url('/wifi-cabin/networks/' . $network->id);
        $payload = [
            'network_id' => $network->id,
            'network_name' => $network->name,
            'commission_rate' => $commissionRate,
            'commission_rate_percent' => number_format($commissionRate * 100, 2),
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
            entity: 'wifi_network_commission',
            entityId: $network->id . '-commission',
            data: $payload,
            meta: [
                'source' => 'wifi_owner',
                'event' => 'network_commission_updated',
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
                'wifi_network_commission_updated',
                $payload,
                false
            );
        }
    }
}
