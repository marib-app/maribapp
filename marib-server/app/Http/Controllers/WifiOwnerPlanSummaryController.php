<?php

namespace App\Http\Controllers;

use App\Models\WifiNetwork;
use App\Services\Wifi\WifiCodeSummaryService;
use App\Services\Wifi\WifiOwnerRequestService;
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

        $ownsNetwork = WifiNetwork::query()
            ->where('user_id', $user->getKey())
            ->exists();

        if (! $ownsNetwork) {
            abort(403, __('You are not allowed to view Wi-Fi plans.'));
        }
    }

    protected function visibleNetworksQuery(Request $request): Builder
    {
        if ($this->canViewAll($request->user())) {
            return parent::visibleNetworksQuery($request);
        }

        $query = WifiNetwork::query();
        $user = $request->user();

        if ($user) {
            $query->where('user_id', $user->getKey());
        } else {
            $query->whereRaw('1 = 0');
        }

        return $query;
    }
}