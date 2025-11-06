<?php

namespace App\Http\Controllers\Wifi;

use App\Http\Controllers\Controller;
use App\Http\Requests\Wifi\StoreWifiPlanRequest;
use App\Http\Requests\Wifi\UpdateWifiPlanRequest;
use App\Http\Resources\Wifi\WifiPlanResource;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiPlan;
use App\Services\Audit\AuditLogger;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class OwnerPlanController extends Controller
{
    public function __construct(private AuditLogger $auditLogger)
    {
    }

    public function index(Request $request, WifiNetwork $network): AnonymousResourceCollection
    {
        $this->authorize('view', $network);

        $plans = $network->plans()
            ->orderBy('sort_order')
            ->orderBy('created_at', 'desc')
            ->paginate((int) $request->integer('per_page', 15))
            ->appends($request->query());

        return WifiPlanResource::collection($plans);
    }

    public function store(StoreWifiPlanRequest $request, WifiNetwork $network): JsonResponse
    {
        $data = $request->validated();
        $plan = new WifiPlan($data);
        $plan->wifi_network_id = $network->id;

        $plan->save();
        $plan->refresh();

        $this->auditLogger->logChanges($plan, 'wifi.plan.created', array_keys($data), $request->user(), [
            'description' => 'Wifi plan created by owner',
        ]);

        return WifiPlanResource::make($plan)->response()->setStatusCode(201);
    }

    public function show(WifiPlan $plan): WifiPlanResource
    {
        $this->authorize('view', $plan);

        return WifiPlanResource::make($plan->load('codeBatches'));
    }

    public function update(UpdateWifiPlanRequest $request, WifiPlan $plan): WifiPlanResource
    {
        $plan->fill($request->validated());

        $dirty = array_keys($plan->getDirty());
        if ($dirty === []) {
            return WifiPlanResource::make($plan->refresh());
        }

        $this->auditLogger->logChanges($plan, 'wifi.plan.updated', $dirty, $request->user(), [
            'description' => 'Wifi plan updated by owner',
        ]);

        $plan->save();

        return WifiPlanResource::make($plan->refresh());
    }

    public function destroy(Request $request, WifiPlan $plan)
    {
        $this->authorize('delete', $plan);

        $this->auditLogger->logChanges($plan, 'wifi.plan.deleted', ['status'], $request->user(), [
            'description' => 'Wifi plan deleted by owner',
        ]);

        $plan->delete();

        return response()->noContent();
    }
}