<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MetalRateResource;
use App\Models\MetalRate;
use App\Models\MetalRateUpdate;
use App\Services\ResponseService;
use Illuminate\Http\Request;

class MetalRateController extends Controller
{
    public function index(Request $request)
    {
        MetalRateUpdate::applyDueUpdates();

        $rates = MetalRate::query()
            ->orderBy('metal_type')
            ->orderBy('karat')
            ->get();

        $meta = [
            'last_updated_at' => optional($rates->max('updated_at'))->toIso8601String(),
        ];

        return ResponseService::successResponse(
            __('تم جلب أسعار المعادن بنجاح.'),
            MetalRateResource::collection($rates),
            ['meta' => $meta]
        );
    }
}