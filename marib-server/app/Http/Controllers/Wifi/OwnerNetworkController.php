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
use App\Models\Wifi\ReputationCounter;
use App\Models\Wifi\WifiCode;
use App\Models\Wifi\WifiCodeBatch;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiReport;
use App\Services\Audit\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;

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
            ->withCount('plans')
            ->orderByDesc('created_at')
            ->paginate($perPage)
            ->appends($request->query());

        return WifiNetworkResource::collection($networks);
    }

    public function store(StoreWifiNetworkRequest $request): JsonResponse
    {
        $data = $request->validated();
        $network = new WifiNetwork($data);
        $network->user_id = $request->user()->id;

        $network->save();
        $network->refresh();

        $this->auditLogger->logChanges($network, 'wifi.network.created', array_keys($data), $request->user(), [
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
}