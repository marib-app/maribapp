<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MetalRateResource;
use App\Models\Governorate;
use App\Models\MetalRate;
use App\Models\MetalRateUpdate;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;

class MetalRateController extends Controller
{
    public function index(Request $request)
    {
        MetalRateUpdate::applyDueUpdates();

        $requestedCode = $request->query('governorate_code');
        $requestedGovernorate = null;

        if ($requestedCode) {
            $requestedGovernorate = Governorate::query()
                ->where('code', $requestedCode)
                ->where('is_active', true)
                ->first();
        }

        $rates = MetalRate::query()
            ->with('quotes.governorate')
            ->orderBy('metal_type')
            ->orderBy('karat')
            ->get();

        $usedFallback = false;
        $appliedGovernorate = null;

        foreach ($rates as $rate) {
            [$resolvedQuote, $governorate, $rateFallback] = $rate->resolveQuoteForGovernorate($requestedGovernorate);

            if ($rateFallback) {
                $usedFallback = true;
            }

            if ($governorate && !$appliedGovernorate) {
                $appliedGovernorate = $governorate;
            }

            $rate->setRelation('resolvedQuote', $resolvedQuote);
            $rate->setRelation('resolvedGovernorate', $governorate);

            $rate->setAttribute('resolved_quote_used_fallback', $rateFallback);
        }

        $meta = [
            'last_updated_at' => optional($rates->max('updated_at'))->toIso8601String(),
            'requested_governorate_code' => $requestedCode,
            'requested_governorate' => $requestedGovernorate
                ? Arr::only($requestedGovernorate->toArray(), ['code', 'name'])
                : null,
            'applied_governorate' => $appliedGovernorate
                ? Arr::only($appliedGovernorate->toArray(), ['code', 'name'])
                : null,
            'used_fallback' => $usedFallback,
        ];

        return ResponseService::successResponse(
            __('تم جلب أسعار المعادن بنجاح.'),
            MetalRateResource::collection($rates)->additional(['meta' => $meta]),
            ['meta' => $meta]
        );
    }
}