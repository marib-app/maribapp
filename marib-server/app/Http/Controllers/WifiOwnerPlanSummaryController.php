<?php

namespace App\Http\Controllers;


use App\Models\WifiCodeBatch;
use App\Models\WifiNetwork;
use App\Models\WifiPlan;
use App\Services\Wifi\WifiCodeSummaryService;
use App\Services\Wifi\WifiOwnerRequestService;
use Illuminate\Contracts\Auth\Authenticatable;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WifiOwnerPlanSummaryController extends WifiCabinApiController
{

    protected bool $requiresManagePermission = false;


    public function __construct(
        WifiCodeSummaryService $codeSummaryService,
        WifiOwnerRequestService $ownerRequestService
    ) {
        $this->codeSummaryService = $codeSummaryService;
        $this->ownerRequestService = $ownerRequestService;
    }

    public function __invoke(Request $request): JsonResponse
    {
        $this->authorizeOwner($request);

        return parent::plans($request);
    }

    protected function authorizeOwner(Request $request): void
    {
        $user = $request->user();

        if (! $user) {
            abort(401, __('You must be logged in to view Wi-Fi plans.'));
        }

        if ($this->canViewAll($user)) {
            return;
        }

        if ($this->ownsNetwork($user)) {
            return;
        }

        if ($this->hasPendingOwnerRequest($user)) {
            return;
        }

        if ($user->can('wifi-cabin-manage')) {
            return;
        }

        abort(403, __('You are not allowed to view Wi-Fi plans.'));
    }

    protected function ownsNetwork(Authenticatable $user): bool
    {
        return WifiNetwork::query()
        
        
        ->where('user_id', $user->getKey())
            ->exists();
    }


    protected function hasPendingOwnerRequest(Authenticatable $user): bool
    {
        return WifiCodeBatch::query()
            ->where('uploaded_by', $user->getKey())
            ->where('status', WifiCodeBatch::STATUS_PENDING)
            ->where(function (Builder $builder) {
                $builder->where('meta->owner_request->status', 'pending')
                    ->orWhere(function (Builder $inner) {
                        $inner->whereNull('meta->owner_request->status')
                            ->whereNotNull('meta->owner_request');
                    });
            })
            ->exists();
    }

    public function available(Request $request): JsonResponse
    {
        $plans = WifiPlan::query()
            ->where('is_active', true)
            ->whereHas('network', static function (Builder $builder) {
                $builder->where('is_active', true);
            })
            ->with(['network:id,name,slug'])
            ->select([
                'id',
                'wifi_network_id',
                'name',
                'slug',
                'description',
                'duration_minutes',
                'data_allowance_mb',
                'validity_days',
                'speed_mbps',
                'price',
                'currency',
                'meta',
            ])
            ->orderBy('name')
            ->orderBy('id')
            ->get();

        $data = $plans->map(static function (WifiPlan $plan) {
            return [
                'id' => $plan->getKey(),
                'network_id' => $plan->wifi_network_id,
                'name' => $plan->name,
                'slug' => $plan->slug,
                'description' => $plan->description,
                'duration_minutes' => $plan->duration_minutes !== null ? (int) $plan->duration_minutes : null,
                'data_allowance_mb' => $plan->data_allowance_mb !== null ? (int) $plan->data_allowance_mb : null,
                'validity_days' => $plan->validity_days !== null ? (int) $plan->validity_days : null,
                'speed_mbps' => $plan->speed_mbps !== null ? (float) $plan->speed_mbps : null,
                'price' => $plan->price !== null ? (float) $plan->price : null,
                'currency' => $plan->currency,
                'meta' => $plan->meta ?? [],
                'network' => $plan->network ? [
                    'id' => $plan->network->getKey(),
                    'name' => $plan->network->name,
                    'slug' => $plan->network->slug,
                ] : null,
            ];
        })->values();

        return response()->json(['data' => $data]);

    }

    protected function visibleNetworksQuery(Request $request): Builder
    {
        if ($this->canViewAll($request->user())) {
            return parent::visibleNetworksQuery($request);
        }

        $query = WifiNetwork::query();
        $user = $request->user();

        if ($user) {
            $query->where(function (Builder $builder) use ($user) {
                $builder->where('user_id', $user->getKey())
                    ->orWhereIn('id', function ($subQuery) use ($user) {
                        $subQuery->select('wifi_network_id')
                            ->from((new WifiCodeBatch())->getTable())
                            ->where('uploaded_by', $user->getKey())
                            ->where('status', WifiCodeBatch::STATUS_PENDING)
                            ->where(function (Builder $batchBuilder) {
                                $batchBuilder->where('meta->owner_request->status', 'pending')
                                    ->orWhere(function (Builder $inner) {
                                        $inner->whereNull('meta->owner_request->status')
                                            ->whereNotNull('meta->owner_request');
                                    });
                            });
                    });
            });
        
        } else {
            $query->whereRaw('1 = 0');
        }

        return $query;
    }
}