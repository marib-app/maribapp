<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\ValidatesMetalRates;
use App\Http\Controllers\Controller;
use App\Http\Resources\MetalRateResource;
use App\Models\MetalRate;
use App\Models\MetalRateUpdate;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class MetalRateManagementController extends Controller
{
    use ValidatesMetalRates;

    public function index()
    {
        MetalRateUpdate::applyDueUpdates();

        $rates = MetalRate::query()
            ->with('pendingUpdates')
            ->orderBy('metal_type')
            ->orderBy('karat')
            ->get();

        return ResponseService::successResponse(
            __('تم جلب أسعار المعادن بنجاح.'),
            MetalRateResource::collection($rates)
        );
    }

    public function store(Request $request)
    {
        $payload = $this->validateMetalRatePayload($request);

        $rate = MetalRate::create($payload);

        return ResponseService::successResponse(
            __('تم إضافة سعر المعدن بنجاح.'),
            new MetalRateResource($rate->fresh())
        );
    }

    public function show(MetalRate $metalRate)
    {
        $metalRate->refreshDueSchedules();

        return ResponseService::successResponse(
            __('تم جلب سعر المعدن بنجاح.'),
            new MetalRateResource($metalRate->fresh('pendingUpdates'))
        );
    }

    public function update(Request $request, MetalRate $metalRate)
    {
        $payload = $this->validateMetalRatePayload($request, $metalRate);

        $metalRate->update($payload);

        return ResponseService::successResponse(
            __('تم تحديث سعر المعدن بنجاح.'),
            new MetalRateResource($metalRate->fresh('pendingUpdates'))
        );
    }

    public function destroy(MetalRate $metalRate)
    {
        $metalRate->delete();

        return ResponseService::successResponse(__('تم حذف سعر المعدن بنجاح.'));
    }

    public function schedule(Request $request, MetalRate $metalRate)
    {
        $payload = $this->validateMetalRateSchedule($request);

        $schedule = $metalRate->pendingUpdates()->create($payload + [
            'created_by' => Auth::id(),
        ]);

        return ResponseService::successResponse(
            __('تمت جدولة التحديث بنجاح.'),
            $schedule->fresh()
        );
    }

    public function cancelSchedule(MetalRateUpdate $metalRateUpdate)
    {
        $metalRateUpdate->cancel();

        return ResponseService::successResponse(__('تم إلغاء الجدولة بنجاح.'));
    }
}