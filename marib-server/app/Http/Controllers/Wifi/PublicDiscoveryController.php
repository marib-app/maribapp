<?php

namespace App\Http\Controllers\Wifi;

use App\Enums\Wifi\WifiNetworkStatus;
use App\Enums\Wifi\WifiPlanStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Wifi\SearchWifiNetworksRequest;
use App\Http\Requests\Wifi\SearchWifiPlansRequest;
use App\Http\Resources\Wifi\WifiNetworkResource;
use App\Http\Resources\Wifi\WifiPlanResource;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiPlan;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

class PublicDiscoveryController extends Controller
{
    public function networks(SearchWifiNetworksRequest $request)
    {
        $validated = $request->validated();
        $perPage = $validated['per_page'] ?? 15;

        $query = WifiNetwork::query()
            ->where('status', WifiNetworkStatus::ACTIVE->value)
            ->withCount('plans');

        if (! empty($validated['q'])) {
            $term = strtolower($validated['q']);
            $query->where(static function (Builder $query) use ($term): void {
                $query->whereRaw('LOWER(name) LIKE ?', ['%' . $term . '%'])
                    ->orWhereRaw('LOWER(address) LIKE ?', ['%' . $term . '%']);
            });
        }

        if (! empty($validated['currency'])) {
            $query->whereJsonContains('currencies', strtoupper($validated['currency']));
        }

        if (! empty($validated['owner_id'])) {
            $query->where('user_id', $validated['owner_id']);
        }

        if (isset($validated['latitude'], $validated['longitude'], $validated['radius_km'])) {
            $radius = (float) $validated['radius_km'];
            $lat = (float) $validated['latitude'];
            $lng = (float) $validated['longitude'];
            $latDiff = $radius / 111.0;
            $lngDiff = $radius / max(cos(deg2rad($lat)) * 111.0, 0.0001);

            $query->whereBetween('latitude', [$lat - $latDiff, $lat + $latDiff])
                ->whereBetween('longitude', [$lng - $lngDiff, $lng + $lngDiff]);
        }

        if (! empty($validated['with_plans'])) {
            $query->with(['plans' => function (Builder $planQuery): void {
                $planQuery->where('status', WifiPlanStatus::ACTIVE->value)
                    ->orderBy('sort_order')
                    ->with('codeBatches:id,wifi_plan_id,total_codes,available_codes,status');
            }]);
        }

        $networks = $query->orderByDesc('plans_count')
            ->paginate($perPage)
            ->appends($request->query());

        return WifiNetworkResource::collection($networks);
    }

    public function plans(SearchWifiPlansRequest $request)
    {
        $validated = $request->validated();
        $perPage = $validated['per_page'] ?? 15;

        $query = WifiPlan::query()
            ->whereIn('status', [WifiPlanStatus::ACTIVE->value, WifiPlanStatus::VALIDATED->value])
            ->with([
                'network:id,name,slug,status,user_id',
                'codeBatches:id,wifi_plan_id,total_codes,available_codes,status',
            ]);

        if (! empty($validated['q'])) {
            $term = strtolower($validated['q']);
            $query->where(static function (Builder $query) use ($term): void {
                $query->whereRaw('LOWER(name) LIKE ?', ['%' . $term . '%'])
                    ->orWhereRaw('LOWER(description) LIKE ?', ['%' . $term . '%']);
            });
        }

        if (! empty($validated['network_id'])) {
            $query->where('wifi_network_id', $validated['network_id']);
        }

        if (! empty($validated['currency'])) {
            $query->where('currency', strtoupper($validated['currency']));
        }

        if (! empty($validated['price_min'])) {
            $query->where('price', '>=', $validated['price_min']);
        }

        if (! empty($validated['price_max'])) {
            $query->where('price', '<=', $validated['price_max']);
        }

        if (! empty($validated['duration_min'])) {
            $query->where('duration_days', '>=', $validated['duration_min']);
        }

        if (! empty($validated['duration_max'])) {
            $query->where('duration_days', '<=', $validated['duration_max']);
        }

        $query->orderBy('sort_order')->orderBy('price');

        $plans = $query->paginate($perPage)->appends($request->query());

        return WifiPlanResource::collection($plans);
    }
}
