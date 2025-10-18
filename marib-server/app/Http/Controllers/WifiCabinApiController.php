<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\WifiCode;
use App\Models\WifiCodeBatch;
use App\Models\WifiNetwork;
use App\Models\WifiPlan;
use App\Services\Wifi\WifiOwnerRequestService;
use Illuminate\Auth\Access\AuthorizationException;
use App\Services\Wifi\WifiCodeSummaryService;
use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Pagination\CursorPaginator;
use Illuminate\Pagination\Paginator;
use Illuminate\Validation\ValidationException;
use Throwable;




class WifiCabinApiController extends Controller
{
    protected bool $requiresManagePermission = true;


    protected int $defaultLowStockThreshold = 10;

    public function __construct(
        protected WifiCodeSummaryService $codeSummaryService,
        protected WifiOwnerRequestService $ownerRequestService,
    )


    {
        if ($this->requiresManagePermission) {
            $this->middleware('permission:wifi-cabin-manage');
        }
    
    }



    public function networks(Request $request): JsonResponse
    {
        $filters = $this->resolveFilters($request);
        $perPage = $this->resolvePerPage($request);

        $query = $this->visibleNetworksQuery($request)
            ->withCount('plans as plans_count')
            ->orderBy('name')
            ->orderBy('id');

        $this->applyNetworkFilters($query, $filters);

        $paginator = $this->paginate($query, $request, $perPage);

        $networks = collect($paginator->items());

        $prefetchIds = $this->resolvePrefetchIds($request);
        $prefetchIds = $prefetchIds->diff($networks->pluck('id'));

        $prefetchedNetworks = $prefetchIds->isNotEmpty()
            ? $this->visibleNetworksQuery($request)
                ->whereIn('id', $prefetchIds)
                ->withCount('plans as plans_count')
                ->orderBy('name')
                ->orderBy('id')
                ->get()
            : collect();

        $allNetworks = $networks->concat($prefetchedNetworks);
        $allNetworkIds = $allNetworks->pluck('id');

        $summaryFilters = $this->resolveSummaryFilters($filters);

        $planSummary = $this->codeSummaryService->planSummary($allNetworkIds, $summaryFilters);
        $networkSummary = $this->codeSummaryService->networkSummary($allNetworkIds, $summaryFilters);
        $pendingBatches = $this->pendingBatchCounts($allNetworkIds);
        $lastSynced = $this->networkLastSyncedAt($allNetworkIds, $allNetworks);

        $data = $networks->map(function (WifiNetwork $network) use ($planSummary, $networkSummary, $pendingBatches, $lastSynced) {
            $summary = $networkSummary[$network->getKey()] ?? ['available' => 0, 'allocated' => 0, 'redeemed' => 0, 'total' => 0];

            return $this->transformNetwork(
                $network,
                $planSummary[$network->getKey()] ?? [],
                $summary,
                $lastSynced[$network->getKey()] ?? null,
                $pendingBatches[$network->getKey()] ?? 0
            );
        })->values();

        $prefetched = $prefetchedNetworks->map(function (WifiNetwork $network) use ($planSummary, $networkSummary, $pendingBatches, $lastSynced) {
            $summary = $networkSummary[$network->getKey()] ?? ['available' => 0, 'allocated' => 0, 'redeemed' => 0, 'total' => 0];

            return $this->transformNetwork(
                $network,
                $planSummary[$network->getKey()] ?? [],
                $summary,
                $lastSynced[$network->getKey()] ?? null,
                $pendingBatches[$network->getKey()] ?? 0
            );
        })->values();

        $response = [
            'data' => $data,
            'links' => $this->buildPaginationLinks($paginator),
            'meta' => $this->buildPaginationMeta($paginator),
        ];

        if ($prefetched->isNotEmpty()) {
            $response['included']['networks'] = $prefetched;
        }

        return response()->json($response);
    }



    public function plans(Request $request): JsonResponse
    {
        $filters = $this->resolveFilters($request);
        $perPage = $this->resolvePerPage($request);
        $networkIds = $this->resolveNetworkIds($request);

        if ($request->filled('network')) {
            $networkModel = $this->findNetwork($request, (string) $request->input('network'));
            $networkIds = collect([$networkModel->getKey()]);
        }

        if ($networkIds->isEmpty()) {
            return response()->json(['data' => [], 'links' => [], 'meta' => ['per_page' => $perPage, 'count' => 0]]);
        }

        $query = WifiPlan::query()
            ->whereIn('wifi_network_id', $networkIds)
            ->with(['network:id,name,slug'])
            ->select(['id', 'wifi_network_id', 'name', 'slug', 'is_active'])
            ->orderBy('name')
            ->orderBy('id');

        $this->applyPlanFilters($query, $filters);

        $paginator = $this->paginate($query, $request, $perPage);

        $plans = collect($paginator->items());

        $prefetchIds = $this->resolvePrefetchIds($request)->diff($plans->pluck('id'));

        $prefetchedPlans = $prefetchIds->isNotEmpty()
            ? WifiPlan::query()
                ->whereIn('id', $prefetchIds)
                ->whereIn('wifi_network_id', $networkIds)
                ->with(['network:id,name,slug'])
                ->select(['id', 'wifi_network_id', 'name', 'slug', 'is_active'])
                ->orderBy('name')
                ->orderBy('id')
                ->get()
            : collect();

        $allPlans = $plans->concat($prefetchedPlans);
        $allNetworkIds = $allPlans->pluck('wifi_network_id')->unique();

        $summaryFilters = $this->resolveSummaryFilters($filters);
        $summaryFilters['plan_ids'] = $allPlans->pluck('id')->all();

        $planSummary = $this->codeSummaryService->planSummary($allNetworkIds, $summaryFilters);

        $data = $plans->map(function (WifiPlan $plan) use ($planSummary) {
            $stock = Arr::get($planSummary, $plan->wifi_network_id . '.' . $plan->getKey(), []);

            return $this->transformPlan($plan, $stock);
        })->values();

        $prefetched = $prefetchedPlans->map(function (WifiPlan $plan) use ($planSummary) {
            $stock = Arr::get($planSummary, $plan->wifi_network_id . '.' . $plan->getKey(), []);

            return $this->transformPlan($plan, $stock);
        })->values();

        $response = [
            'data' => $data,
            'links' => $this->buildPaginationLinks($paginator),
            'meta' => $this->buildPaginationMeta($paginator),
        ];

        if ($prefetched->isNotEmpty()) {
            $response['included']['plans'] = $prefetched;
        }

        return response()->json($response);
    }

    public function networkPlans(Request $request, string $network): JsonResponse
    {
        $networkModel = $this->findNetwork($request, $network);
        $filters = $this->resolveFilters($request);

        $plans = $this->loadPlansForNetworks(collect([$networkModel->getKey()]), $filters);

        return response()->json(['data' => $plans]);
    }

    protected function loadPlansForNetworks(Collection $networkIds, array $filters = []): Collection
    {
        if ($networkIds->isEmpty()) {
            return collect();
        }

        $query = WifiPlan::query()
            ->whereIn('wifi_network_id', $networkIds)
            ->with(['network:id,name,slug'])
            ->select(['id', 'wifi_network_id', 'name', 'slug', 'is_active'])
            ->orderBy('name')
            ->orderBy('id');

        $this->applyPlanFilters($query, $filters);

        $plans = $query->get();

        if ($plans->isEmpty()) {
            return collect();
        }

        $summaryFilters = $this->resolveSummaryFilters($filters);
        $summaryFilters['plan_ids'] = $plans->pluck('id')->all();

        $planSummary = $this->codeSummaryService->planSummary($networkIds, $summaryFilters);

        return $plans->map(function (WifiPlan $plan) use ($planSummary) {
            $stock = Arr::get($planSummary, $plan->wifi_network_id . '.' . $plan->getKey(), []);

            return $this->transformPlan($plan, $stock);
        })->values();
    }

    public function balances(Request $request): JsonResponse
    {
        $filters = $this->resolveFilters($request);
        $perPage = $this->resolvePerPage($request);

        $query = $this->visibleNetworksQuery($request)
            ->with(['wallet:id,currency,balance'])
            ->orderBy('name')
            ->orderBy('id');

        $this->applyNetworkFilters($query, $filters);

        $paginator = $this->paginate($query, $request, $perPage);

        $networks = collect($paginator->items());

        $prefetchIds = $this->resolvePrefetchIds($request)->diff($networks->pluck('id'));

        $prefetchedNetworks = $prefetchIds->isNotEmpty()
            ? $this->visibleNetworksQuery($request)
                ->whereIn('id', $prefetchIds)
                ->with(['wallet:id,currency,balance'])
                ->orderBy('name')
                ->orderBy('id')
                ->get()
            : collect();

        $allNetworks = $networks->concat($prefetchedNetworks);
        $allNetworkIds = $allNetworks->pluck('id');

        $summaryFilters = $this->resolveSummaryFilters($filters);
        $codeSummary = $this->codeSummaryService->networkSummary($allNetworkIds, $summaryFilters);
        $lastSynced = $this->networkLastSyncedAt($allNetworkIds, $allNetworks);

        $balances = $networks->map(function (WifiNetwork $network) use ($codeSummary, $lastSynced) {
            $summary = $codeSummary[$network->getKey()] ?? ['available' => 0, 'allocated' => 0, 'redeemed' => 0, 'total' => 0];

            return [
                'network_id' => $network->getKey(),
                'name' => $network->name,
                'slug' => $network->slug,
                'status' => $network->is_active ? 'active' : 'inactive',
                'available' => $summary['available'],
                'reserved' => $summary['allocated'],
                'issued' => $summary['redeemed'],
                'remaining' => max(0, $summary['available']),
                'total' => $summary['total'],
                'currency' => $network->wallet?->currency,
                'synced_at' => $lastSynced[$network->getKey()] ?? null,
            ];
        })->values();

        $prefetched = $prefetchedNetworks->map(function (WifiNetwork $network) use ($codeSummary, $lastSynced) {
            $summary = $codeSummary[$network->getKey()] ?? ['available' => 0, 'allocated' => 0, 'redeemed' => 0, 'total' => 0];

            return [
                'network_id' => $network->getKey(),
                'name' => $network->name,
                'slug' => $network->slug,
                'status' => $network->is_active ? 'active' : 'inactive',
                'available' => $summary['available'],
                'reserved' => $summary['allocated'],
                'issued' => $summary['redeemed'],
                'remaining' => max(0, $summary['available']),
                'total' => $summary['total'],
                'currency' => $network->wallet?->currency,
                'synced_at' => $lastSynced[$network->getKey()] ?? null,
            ];
        })->values();

        $response = [
            'data' => $balances,
            'links' => $this->buildPaginationLinks($paginator),
            'meta' => $this->buildPaginationMeta($paginator),
        ];

        if ($prefetched->isNotEmpty()) {
            $response['included']['networks'] = $prefetched;
        }

        return response()->json($response);
    }

    public function alerts(Request $request): JsonResponse
    {
        $filters = $this->resolveFilters($request);
        $perPage = $this->resolvePerPage($request);

        $query = $this->visibleNetworksQuery($request)
            ->with(['plans' => fn ($q) => $q->select(['id', 'wifi_network_id', 'name', 'meta', 'is_active'])->orderBy('name')])
            ->orderBy('name')
            ->orderBy('id');

        $this->applyNetworkFilters($query, $filters);

        $paginator = $this->paginate($query, $request, $perPage);

        $networks = collect($paginator->items());

        $prefetchIds = $this->resolvePrefetchIds($request)->diff($networks->pluck('id'));

        $prefetchedNetworks = $prefetchIds->isNotEmpty()
            ? $this->visibleNetworksQuery($request)
                ->whereIn('id', $prefetchIds)
                ->with(['plans' => fn ($q) => $q->select(['id', 'wifi_network_id', 'name', 'meta', 'is_active'])->orderBy('name')])
                ->orderBy('name')
                ->orderBy('id')
                ->get()
            : collect();

        $allNetworks = $networks->concat($prefetchedNetworks);
        $allNetworkIds = $allNetworks->pluck('id');

        $summaryFilters = $this->resolveSummaryFilters($filters);
        $planSummary = $this->codeSummaryService->planSummary($allNetworkIds, $summaryFilters);
        $networkSummary = $this->codeSummaryService->networkSummary($allNetworkIds, $summaryFilters);
        $pendingBatches = $this->pendingBatchCounts($allNetworkIds);

        $alerts = collect();

        foreach ($networks as $network) {
            $alerts = $alerts->merge($this->buildNetworkAlerts(
                $network,
                $planSummary[$network->getKey()] ?? [],
                $networkSummary[$network->getKey()] ?? ['available' => 0, 'allocated' => 0, 'redeemed' => 0, 'total' => 0],
                $pendingBatches[$network->getKey()] ?? 0
            ));
        }

        $prefetchedAlerts = collect();

        foreach ($prefetchedNetworks as $network) {
            $prefetchedAlerts = $prefetchedAlerts->merge($this->buildNetworkAlerts(
                $network,
                $planSummary[$network->getKey()] ?? [],
                $networkSummary[$network->getKey()] ?? ['available' => 0, 'allocated' => 0, 'redeemed' => 0, 'total' => 0],
                $pendingBatches[$network->getKey()] ?? 0
            ));
        }

        $response = [
            'data' => $alerts->values()->all(),
            'links' => $this->buildPaginationLinks($paginator),
            'meta' => $this->buildPaginationMeta($paginator),
        ];

        if ($prefetchedAlerts->isNotEmpty()) {
            $response['included']['alerts'] = $prefetchedAlerts->values()->all();
        }

        return response()->json($response);
    }


    public function ownerRequests(Request $request): JsonResponse
    {
        $networkIds = $this->resolveNetworkIds($request);

        if ($networkIds->isEmpty() && ! $this->canViewAll($request->user())) {
            return response()->json(['data' => []]);
        }

        $query = WifiCodeBatch::query()
            ->with([
                'network' => fn ($builder) => $builder
                    ->select(['id', 'user_id', 'name', 'slug'])
                    ->with(['owner:id,name,email']),
                'plan' => fn ($builder) => $builder->select(['id', 'wifi_network_id', 'name']),
                'uploader:id,name,email',
            ])
            ->where('status', WifiCodeBatch::STATUS_PENDING)
            ->orderByDesc('created_at');

        if ($networkIds->isNotEmpty()) {
            $query->whereIn('wifi_network_id', $networkIds);
        }

        $requests = $query->get()->map(fn (WifiCodeBatch $batch) => $this->transformOwnerRequest($batch));

        return response()->json(['data' => $requests]);
    }


    public function approveOwnerRequest(Request $request, WifiCodeBatch $batch): JsonResponse
    {
        return $this->handleOwnerRequestDecision(
            fn () => $this->ownerRequestService->approve($batch, $request->user()),
            __('Owner request approved successfully.'),
            __('Failed to approve the owner request.'),
            __('An unexpected error occurred while approving the owner request.'),
        );
    }

    public function rejectOwnerRequest(Request $request, WifiCodeBatch $batch): JsonResponse
    {
        return $this->handleOwnerRequestDecision(
            fn () => $this->ownerRequestService->reject($batch, $request->user()),
            __('Owner request rejected successfully.'),
            __('Failed to reject the owner request.'),
            __('An unexpected error occurred while rejecting the owner request.'),
        );
    }


    public function network(Request $request, string $network): JsonResponse
    {
        $networkModel = $this->findNetwork($request, $network);
        $networkModel->loadMissing([
            'wallet:id,currency,balance',
            'plans' => fn ($query) => $query->select(['id', 'wifi_network_id', 'name', 'slug', 'is_active'])->orderBy('name'),
        ]);

        $networkIds = collect([$networkModel->getKey()]);
        $planIds = $networkModel->relationLoaded('plans') ? $networkModel->plans->pluck('id')->all() : [];

        $summaryFilters = [];
        if ($planIds !== []) {
            $summaryFilters['plan_ids'] = $planIds;
        }

        $planSummary = $this->codeSummaryService->planSummary($networkIds, $summaryFilters);
        $networkSummary = $this->codeSummaryService->networkSummary($networkIds, []);
        $lastSynced = $this->networkLastSyncedAt($networkIds, collect([$networkModel]));
        $pendingBatches = $this->pendingBatchCounts($networkIds);

        $planSummaryForNetwork = $planSummary[$networkModel->getKey()] ?? [];
        $networkSummaryForNetwork = $networkSummary[$networkModel->getKey()] ?? ['available' => 0, 'allocated' => 0, 'redeemed' => 0, 'total' => 0];

        $data = $this->transformNetworkDetail(
            $networkModel,
            $planSummaryForNetwork,
            $networkSummaryForNetwork,
            $lastSynced[$networkModel->getKey()] ?? null,
            $pendingBatches[$networkModel->getKey()] ?? 0
        );

        return response()->json(['data' => $data]);
    }

    public function networkStock(Request $request, string $network): JsonResponse
    {
        $networkModel = $this->findNetwork($request, $network);
        $networkModel->loadMissing(['plans' => fn ($query) => $query->select(['id', 'wifi_network_id', 'name'])->orderBy('name')]);

        $networkIds = collect([$networkModel->getKey()]);
        $planIds = $networkModel->plans->pluck('id')->all();

        $planSummary = $this->codeSummaryService->planSummary($networkIds, ['plan_ids' => $planIds]);
        $planSummaryForNetwork = $planSummary[$networkModel->getKey()] ?? [];
        $networkSummary = $this->codeSummaryService->networkSummary($networkIds, []);
        $lastSynced = $this->networkLastSyncedAt($networkIds, collect([$networkModel]));

        $summary = $networkSummary[$networkModel->getKey()] ?? ['available' => 0, 'allocated' => 0, 'redeemed' => 0, 'total' => 0];

        $plans = $networkModel->plans->map(function (WifiPlan $plan) use ($planSummaryForNetwork) {
            $stock = $planSummaryForNetwork[$plan->getKey()] ?? [];

            return [
                'id' => $plan->getKey(),
                'name' => $plan->name,
                'available' => $stock[WifiCode::STATUS_AVAILABLE] ?? 0,
                'reserved' => $stock[WifiCode::STATUS_ALLOCATED] ?? 0,
                'issued' => $stock[WifiCode::STATUS_REDEEMED] ?? 0,
                'total' => array_sum($stock ?: []),
            ];
        })->values();

        $data = [
            'network_id' => $networkModel->getKey(),
            'name' => $networkModel->name,
            'slug' => $networkModel->slug,
            'status' => $networkModel->is_active ? 'active' : 'inactive',
            'available' => $summary['available'],
            'reserved' => $summary['allocated'],
            'issued' => $summary['redeemed'],
            'remaining' => max(0, $summary['available']),
            'total' => $summary['total'],
            'synced_at' => $lastSynced[$networkModel->getKey()] ?? null,
            'plans' => $plans,
        ];

        return response()->json(['data' => $data]);
    }

    public function plan(Request $request, string $plan): JsonResponse
    {
        $planModel = $this->findPlan($request, $plan);

        $planModel->loadMissing(['network:id,name,slug']);

        $networkIds = collect([$planModel->wifi_network_id]);
        $planSummary = $this->codeSummaryService->planSummary($networkIds, ['plan_ids' => [$planModel->getKey()]]);
        $stock = Arr::get($planSummary, $planModel->wifi_network_id . '.' . $planModel->getKey(), []);

        $data = $this->transformPlanDetail($planModel, $stock);

        return response()->json(['data' => $data]);
    }

    public function networkAlerts(Request $request, string $network): JsonResponse
    {
        $networkModel = $this->findNetwork($request, $network);
        $networkModel->loadMissing(['plans' => fn ($query) => $query->select(['id', 'wifi_network_id', 'name', 'meta', 'is_active'])->orderBy('name')]);

        $networkIds = collect([$networkModel->getKey()]);
        $planSummary = $this->codeSummaryService->planSummary($networkIds, ['plan_ids' => $networkModel->plans->pluck('id')->all()]);
        $networkSummary = $this->codeSummaryService->networkSummary($networkIds, []);
        $pendingBatches = $this->pendingBatchCounts($networkIds);

        $alerts = $this->buildNetworkAlerts(
            $networkModel,
            $planSummary[$networkModel->getKey()] ?? [],
            $networkSummary[$networkModel->getKey()] ?? ['available' => 0, 'allocated' => 0, 'redeemed' => 0, 'total' => 0],
            $pendingBatches[$networkModel->getKey()] ?? 0
        );

        return response()->json(['data' => $alerts->values()->all()]);
    }



    protected function transformOwnerRequest(WifiCodeBatch $batch): array
    {
        $network = $batch->network;
        $owner = $network?->owner;
        $plan = $batch->plan;
        $uploader = $batch->uploader;

        return [
            'id' => $batch->getKey(),
            'status' => $batch->status,
            'total_rows' => (int) $batch->total_rows,
            'accepted_rows' => (int) $batch->accepted_rows,
            'rejected_rows' => (int) $batch->rejected_rows,
            'created_at' => optional($batch->created_at)?->toDateTimeString(),
            'original_filename' => $batch->original_filename,
            'network' => $network ? [
                'id' => $network->getKey(),
                'name' => $network->name,
                'slug' => $network->slug,
            ] : null,
            'plan' => $plan ? [
                'id' => $plan->getKey(),
                'name' => $plan->name,
            ] : null,
            'owner' => $owner ? [
                'id' => $owner->getKey(),
                'name' => $owner->name,
                'email' => $owner->email,
            ] : null,
            'uploader' => $uploader ? [
                'id' => $uploader->getKey(),
                'name' => $uploader->name,
                'email' => $uploader->email,
            ] : null,
        ];
    }



    /**
     * @param  callable():WifiCodeBatch  $decision
     */
    protected function handleOwnerRequestDecision(
        callable $decision,
        string $successMessage,
        string $validationFallbackMessage,
        string $unexpectedErrorMessage,
    ): JsonResponse {
        try {
            $batch = $decision();

            return response()->json([
                'message' => $successMessage,
                'data' => $this->transformOwnerRequest($batch),
            ]);
        } catch (ValidationException $exception) {
            $errors = $exception->errors();
            $flattened = Arr::flatten($errors);
            $message = Arr::first($flattened) ?? $validationFallbackMessage;

            return response()->json([
                'message' => $message,
                'errors' => $errors,
            ], 422);
        } catch (AuthorizationException $exception) {
            throw $exception;
        } catch (Throwable $exception) {
            report($exception);

            return response()->json([
                'message' => $unexpectedErrorMessage,
            ], 500);
        }
    }

    protected function transformNetwork(
        WifiNetwork $network,
        array $planSummary,
        array $networkSummary,
        ?string $lastSynced,
        int $pendingBatches
    ): array {
        $planCount = (int) ($network->plans_count ?? count($planSummary));

        return [
            'id' => $network->getKey(),
            'name' => $network->name,
            'slug' => $network->slug,
            'status' => $network->is_active ? 'active' : 'inactive',
            'is_active' => (bool) $network->is_active,
            'counters' => [
                'codes' => $this->ensureSummaryShape($networkSummary),
                'plans' => [
                    'total' => $planCount,
                ],
                'pending_batches' => $pendingBatches,
            ],
            'synced_at' => $lastSynced,
        ];
    }

    protected function transformNetworkDetail(
        WifiNetwork $network,
        array $planSummary,
        array $networkSummary,
        ?string $lastSynced,
        int $pendingBatches
    ): array {
        $summary = $this->transformNetwork($network, $planSummary, $networkSummary, $lastSynced, $pendingBatches);

        $plans = $network->relationLoaded('plans')
            ? $network->plans->map(function (WifiPlan $plan) use ($planSummary) {
                $stock = $planSummary[$plan->getKey()] ?? [];

                return $this->transformPlan($plan, $stock);
            })->values()
            : collect();

        $summary['identifier'] = $network->slug;
        $summary['code'] = $network->slug;
        $summary['description'] = $network->description;
        $summary['location_name'] = $network->location_name;
        $summary['latitude'] = $network->latitude;
        $summary['longitude'] = $network->longitude;
        $summary['coverage_radius_km'] = $network->coverage_radius_km;
        $summary['commission_rate'] = (float) $network->commission_rate;
        $summary['commission_flat'] = (float) $network->commission_flat;
        $summary['notes'] = $network->notes;
        $summary['contacts'] = $network->contacts ?? [];
        $summary['wallet'] = $network->wallet ? Arr::only($network->wallet->toArray(), ['id', 'currency', 'balance']) : null;
        $summary['meta'] = $network->meta ?? [];
        $summary['plans'] = $plans;
        $summary['counters']['plans']['total'] = $plans->count() ?: ($summary['counters']['plans']['total'] ?? 0);

        return $summary;
    }

    protected function transformPlan(WifiPlan $plan, array $stock = []): array
    {
        $available = (int) ($stock[WifiCode::STATUS_AVAILABLE] ?? 0);
        $reserved = (int) ($stock[WifiCode::STATUS_ALLOCATED] ?? 0);
        $issued = (int) ($stock[WifiCode::STATUS_REDEEMED] ?? 0);
        $total = $available + $reserved + $issued;

        return [
            'id' => $plan->getKey(),
            'network_id' => $plan->wifi_network_id,
            'name' => $plan->name,
            'slug' => $plan->slug,
            'status' => $plan->is_active ? 'active' : 'inactive',
            'is_active' => (bool) $plan->is_active,
            'network' => $plan->relationLoaded('network') && $plan->network
                ? [
                    'id' => $plan->network->getKey(),
                    'name' => $plan->network->name,
                    'slug' => $plan->network->slug,
                ]
                : null,
            'counters' => [
                'codes' => [
                    'available' => $available,
                    'reserved' => $reserved,
                    'issued' => $issued,
                    'total' => $total,
                ],
            ],
        ];
    }

    protected function transformPlanDetail(WifiPlan $plan, array $stock = []): array
    {
        $available = (int) ($stock[WifiCode::STATUS_AVAILABLE] ?? $plan->available_count ?? 0);
        $reserved = (int) ($stock[WifiCode::STATUS_ALLOCATED] ?? 0);
        $issued = (int) ($stock[WifiCode::STATUS_REDEEMED] ?? 0);
        $sold = (int) ($plan->sold_count ?? ($reserved + $issued));
        $total = (int) ($plan->total_codes ?? ($available + $sold));

        return [
            'id' => $plan->getKey(),
            'network_id' => $plan->wifi_network_id,
            'name' => $plan->name,
            'slug' => $plan->slug,
            'description' => $plan->description,
            'status' => $plan->is_active ? 'active' : 'inactive',
            'is_active' => (bool) $plan->is_active,
            'price' => $plan->price,
            'cost' => $plan->cost,
            'currency' => $plan->currency,
            'duration_minutes' => $plan->duration_minutes,
            'meta' => $plan->meta ?? [],
            'network' => $plan->relationLoaded('network') && $plan->network
                ? [
                    'id' => $plan->network->getKey(),
                    'name' => $plan->network->name,
                    'slug' => $plan->network->slug,
                ]
                : null,
            'financials' => [
                'owner_net_amount' => round((float) ($plan->owner_net_amount ?? 0), 2),
                'gross_revenue_amount' => round((float) ($plan->gross_revenue_amount ?? 0), 2),
            ],
            'counters' => [
                'codes' => [
                    'available' => $available,
                    'reserved' => $reserved,
                    'issued' => $issued,
                    'sold' => $sold,
                    'total' => $total,
                ],
            ],
        ];
    }

    protected function buildNetworkAlerts(
        WifiNetwork $network,
        array $planSummary,
        array $networkSummary,
        int $pendingBatches
    ): Collection {
        $alerts = collect();
        $now = Carbon::now()->toDateTimeString();

        if (! $network->is_active) {
            $alerts->push([
                'id' => 'network-' . $network->getKey() . '-inactive',
                'network_id' => $network->getKey(),
                'severity' => 'warning',
                'title' => __('Network inactive'),
                'message' => __('The network :name is currently inactive.', ['name' => $network->name]),
                'category' => 'network',
                'reported_at' => $now,
            ]);
        }

        if ($pendingBatches > 0) {
            $alerts->push([
                'id' => 'network-' . $network->getKey() . '-pending-batches',
                'network_id' => $network->getKey(),
                'severity' => 'info',
                'title' => __('Pending voucher imports'),
                'message' => __(':count batches are waiting to be processed for this network.', ['count' => $pendingBatches]),
                'category' => 'imports',
                'reported_at' => $now,
            ]);
        }

        foreach ($network->plans as $plan) {
            $stock = $planSummary[$plan->getKey()] ?? [];
            $available = (int) ($stock[WifiCode::STATUS_AVAILABLE] ?? 0);
            $allocated = (int) ($stock[WifiCode::STATUS_ALLOCATED] ?? 0);
            $redeemed = (int) ($stock[WifiCode::STATUS_REDEEMED] ?? 0);
            $total = $available + $allocated + $redeemed;

            $threshold = $this->resolveLowStockThreshold($plan);

            if ($total === 0) {
                $alerts->push([
                    'id' => 'plan-' . $plan->getKey() . '-no-stock',
                    'network_id' => $network->getKey(),
                    'plan_id' => $plan->getKey(),
                    'severity' => 'warning',
                    'title' => __('No vouchers available'),
                    'message' => __('Plan :plan has no vouchers uploaded yet.', ['plan' => $plan->name]),
                    'category' => 'stock',
                    'reported_at' => $now,
                ]);

                continue;
            }

            if ($available <= 0) {
                $alerts->push([
                    'id' => 'plan-' . $plan->getKey() . '-out-of-stock',
                    'network_id' => $network->getKey(),
                    'plan_id' => $plan->getKey(),
                    'severity' => 'critical',
                    'title' => __('Plan out of stock'),
                    'message' => __('Plan :plan has run out of available vouchers.', ['plan' => $plan->name]),
                    'category' => 'stock',
                    'reported_at' => $now,
                ]);

                continue;
            }

            if ($available <= $threshold) {
                $alerts->push([
                    'id' => 'plan-' . $plan->getKey() . '-low-stock',
                    'network_id' => $network->getKey(),
                    'plan_id' => $plan->getKey(),
                    'severity' => 'warning',
                    'title' => __('Low voucher availability'),
                    'message' => __('Only :count vouchers remain for plan :plan.', [
                        'count' => $available,
                        'plan' => $plan->name,
                    ]),
                    'category' => 'stock',
                    'reported_at' => $now,
                ]);
            }
        }

        $availableTotal = (int) ($networkSummary['available'] ?? 0);
        if ($availableTotal <= 0) {
            $alerts->push([
                'id' => 'network-' . $network->getKey() . '-no-available-codes',
                'network_id' => $network->getKey(),
                'severity' => 'critical',
                'title' => __('No vouchers available'),
                'message' => __('All vouchers for :name are allocated or redeemed.', ['name' => $network->name]),
                'category' => 'stock',
                'reported_at' => $now,
            ]);
        }

        return $alerts->unique('id');
    }

    protected function resolveLowStockThreshold(WifiPlan $plan): int
    {
        $threshold = (int) data_get($plan->meta ?? [], 'low_stock_threshold', $this->defaultLowStockThreshold);

        return max(0, $threshold);
    }

    protected function resolveFilters(Request $request): array
    {
        $filters = $request->input('filters', []);
        $filters = $this->normalizeArrayInput($filters);

        if (! is_array($filters)) {
            return [];
        }

        return Arr::where($filters, function ($value) {
            if (is_array($value)) {
                return $value !== [];
            }

            return $value !== null && $value !== '';
        });
    }

    protected function applyNetworkFilters(Builder $query, array $filters): void
    {
        if (($status = Arr::get($filters, 'status')) !== null) {
            $statuses = collect(Arr::wrap($status))
                ->map(function ($value) {
                    return match ($value) {
                        'active' => true,
                        'inactive' => false,
                        default => null,
                    };
                })
                ->filter(function ($value) {
                    return $value !== null;
                })
                ->unique()
                ->values();

            if ($statuses->isNotEmpty()) {
                $query->whereIn('is_active', $statuses);
            }
        }

        if (($ids = Arr::get($filters, 'ids')) !== null) {
            $query->whereIn('id', Arr::wrap($ids));
        }

        if (($search = Arr::get($filters, 'search')) !== null) {
            $query->where(function (Builder $builder) use ($search) {
                $builder->where('name', 'like', '%' . $search . '%')
                    ->orWhere('slug', 'like', '%' . $search . '%');
            });
        }
    }

    protected function applyPlanFilters(Builder $query, array $filters): void
    {
        if (($status = Arr::get($filters, 'status')) !== null) {
            $statuses = collect(Arr::wrap($status))
                ->map(function ($value) {
                    return match ($value) {
                        'active' => true,
                        'inactive' => false,
                        default => null,
                    };
                })
                ->filter(function ($value) {
                    return $value !== null;
                })
                ->unique()
                ->values();

            if ($statuses->isNotEmpty()) {
                $query->whereIn('is_active', $statuses);
            }
        }

        if (($ids = Arr::get($filters, 'ids')) !== null) {
            $query->whereIn('id', Arr::wrap($ids));
        }

        if (($search = Arr::get($filters, 'search')) !== null) {
            $query->where(function (Builder $builder) use ($search) {
                $builder->where('name', 'like', '%' . $search . '%')
                    ->orWhere('slug', 'like', '%' . $search . '%');
            });
        }
    }

    protected function resolvePerPage(Request $request): int
    {
        $perPage = (int) ($request->input('per_page', 20));

        if ($perPage <= 0) {
            $perPage = 20;
        }

        return min(50, max(1, $perPage));
    }

    protected function resolvePrefetchIds(Request $request): Collection
    {
        $prefetch = $request->input('prefetch', []);

        if (is_string($prefetch)) {
            $prefetch = $this->normalizeArrayInput($prefetch);
        }

        if (! is_array($prefetch)) {
            $prefetch = Arr::wrap($prefetch);
        }

        if (Arr::isAssoc($prefetch) && array_key_exists('ids', $prefetch)) {
            $prefetch = Arr::wrap($prefetch['ids']);
        }

        return collect($prefetch)
            ->filter(fn ($id) => is_numeric($id))
            ->map(fn ($id) => (int) $id)
            ->filter(fn ($id) => $id > 0)
            ->unique()
            ->values();
    }

    protected function paginate(Builder $query, Request $request, int $perPage): Paginator|CursorPaginator
    {
        if ($request->filled('cursor')) {
            return $query->cursorPaginate($perPage)->withQueryString();
        }

        return $query->simplePaginate($perPage)->appends($this->paginationParameters($request));
    }

    protected function paginationParameters(Request $request): array
    {
        $params = [];

        if ($request->has('per_page')) {
            $params['per_page'] = $request->input('per_page');
        }

        if ($request->has('filters')) {
            $params['filters'] = $request->input('filters');
        }

        return $params;
    }

    protected function buildPaginationLinks(CursorPaginator|Paginator $paginator): array
    {
        if ($paginator instanceof CursorPaginator) {
            return [
                'next' => optional($paginator->nextCursor())->encode(),
                'prev' => optional($paginator->previousCursor())->encode(),
            ];
        }

        return [
            'next' => $paginator->nextPageUrl(),
            'prev' => $paginator->previousPageUrl(),
        ];
    }

    protected function buildPaginationMeta(CursorPaginator|Paginator $paginator): array
    {
        $meta = [
            'per_page' => $paginator->perPage(),
            'count' => $paginator->count(),
        ];

        if ($paginator instanceof CursorPaginator) {
            $meta['has_more'] = $paginator->hasMorePages();
            $meta['current_cursor'] = optional($paginator->cursor())->encode();
        } else {
            $meta['current_page'] = $paginator->currentPage();
            $meta['has_more'] = $paginator->hasMorePages();
        }

        return $meta;
    }

    protected function resolveSummaryFilters(array $filters): array
    {
        $summaryFilters = [];

        if (array_key_exists('code_status', $filters)) {
            $summaryFilters['status'] = Arr::wrap($filters['code_status']);
        }

        if (array_key_exists('plan_ids', $filters)) {
            $summaryFilters['plan_ids'] = Arr::wrap($filters['plan_ids']);
        }

        return $summaryFilters;
    }

    protected function ensureSummaryShape(array $summary): array
    {
        return [
            'available' => (int) ($summary['available'] ?? 0),
            'allocated' => (int) ($summary['allocated'] ?? 0),
            'redeemed' => (int) ($summary['redeemed'] ?? 0),
            'total' => (int) ($summary['total'] ?? 0),
        ];
    }

    protected function normalizeArrayInput(mixed $value): array
    {
        if (is_array($value)) {
            return $value;
        }

        if (is_string($value) && $value !== '') {
            $decoded = json_decode($value, true);

            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                return $decoded;
            }
        }

        return [];
    }

    protected function visibleNetworksQuery(Request $request): Builder
    {
        $query = WifiNetwork::query();
        $user = $request->user();
        $ownerOnly = $request->boolean('owner_only', ! $this->canViewAll($user));

        if ($ownerOnly && $user) {
            $query->where('user_id', $user->getKey());
        }

        return $query;
    }

    protected function resolveNetworkIds(Request $request): Collection
    {
        return $this->visibleNetworksQuery($request)->pluck('id');
    }

    protected function findNetwork(Request $request, string $identifier): WifiNetwork
    {
        $query = $this->visibleNetworksQuery($request);

        $query->where(function (Builder $builder) use ($identifier) {
            $builder->where('slug', $identifier);

            if (ctype_digit($identifier)) {
                $builder->orWhere('id', (int) $identifier);
            }
        });

        $network = $query->first();

        abort_if(! $network, 404, __('Wi-Fi network not found.'));

        return $network;
    }

    protected function findPlan(Request $request, string $identifier): WifiPlan
    {
        $networkIds = $this->resolveNetworkIds($request);

        if ($networkIds->isEmpty()) {
            abort(404, __('Wi-Fi plan not found.'));
        }

        $query = WifiPlan::query()
            ->with(['network:id,name,slug'])
            ->withCodeMetrics()
            ->withRevenueAggregates()
            ->whereIn('wifi_network_id', $networkIds);

        $query->where(function (Builder $builder) use ($identifier) {
            $builder->where('slug', $identifier);

            if (ctype_digit($identifier)) {
                $builder->orWhere('id', (int) $identifier);
            }
        });

        $plan = $query->first();

        abort_if(! $plan, 404, __('Wi-Fi plan not found.'));

        return $plan;
    }

    protected function pendingBatchCounts(Collection $networkIds): array
    {
        if ($networkIds->isEmpty()) {
            return [];
        }

        return WifiCodeBatch::query()
            ->selectRaw('wifi_network_id, COUNT(*) as aggregate')
            ->whereIn('wifi_network_id', $networkIds)
            ->where('status', WifiCodeBatch::STATUS_PENDING)
            ->groupBy('wifi_network_id')
            ->pluck('aggregate', 'wifi_network_id')
            ->map(static fn ($value) => (int) $value)
            ->all();
    }

    protected function networkLastSyncedAt(Collection $networkIds, Collection $networks): array
    {
        if ($networkIds->isEmpty()) {
            return [];
        }

        $codeTimestamps = WifiCode::query()
            ->selectRaw('wifi_network_id, MAX(updated_at) as last_seen')
            ->whereIn('wifi_network_id', $networkIds)
            ->groupBy('wifi_network_id')
            ->pluck('last_seen', 'wifi_network_id');

        $batchTimestamps = WifiCodeBatch::query()
            ->selectRaw('wifi_network_id, MAX(COALESCE(processed_at, updated_at)) as last_seen')
            ->whereIn('wifi_network_id', $networkIds)
            ->groupBy('wifi_network_id')
            ->pluck('last_seen', 'wifi_network_id');

        $results = [];

        foreach ($networkIds as $networkId) {
            $timestamps = [];

            if ($codeTimestamps->has($networkId) && $codeTimestamps[$networkId]) {
                $timestamps[] = Carbon::parse($codeTimestamps[$networkId]);
            }

            if ($batchTimestamps->has($networkId) && $batchTimestamps[$networkId]) {
                $timestamps[] = Carbon::parse($batchTimestamps[$networkId]);
            }

            $network = $networks->firstWhere('id', $networkId);

            if ($network && $network->updated_at) {
                $timestamps[] = Carbon::parse($network->updated_at);
            }

            if ($timestamps === []) {
                continue;
            }

            $latest = collect($timestamps)->max();
            $results[$networkId] = $latest ? $latest->toDateTimeString() : null;
        }

        return $results;
    }

    protected function canViewAll(?Authenticatable $user): bool
    {
        if (! $user instanceof User) {
            return false;
        }

        if ($user->can('wifi-cabin-manage-all')) {
            return true;
        }

        if (method_exists($user, 'hasRole') && $user->hasRole('super-admin')) {
            return true;
        }

        return false;
    }
}
