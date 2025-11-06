<?php

namespace App\Http\Controllers\Wifi;

use App\Enums\Wifi\WifiNetworkStatus;
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
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class AdminModerationController extends Controller
{
    public function __construct(private AuditLogger $auditLogger)
    {
    }

    public function networks(Request $request): AnonymousResourceCollection
    {
        $filters = $request->validate([
            'status' => ['nullable', 'string', 'in:active,inactive,suspended'],
            'owner_id' => ['nullable', 'integer', 'exists:users,id'],
            'q' => ['nullable', 'string', 'max:120'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = WifiNetwork::query()->with('owner:id,name,email');

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

        return WifiNetworkResource::collection($networks);
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

        return WifiNetworkResource::make($network->refresh());
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