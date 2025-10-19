<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\ValidatesMetalRates;
use App\Http\Controllers\Controller;
use App\Http\Resources\MetalRateResource;
use App\Models\MetalRate;
use App\Services\MetalIconStorageService;
use App\Services\MetalRateQuoteService;
use App\Models\MetalRateUpdate;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Arr;

class MetalRateManagementController extends Controller
{
    use ValidatesMetalRates;


    public function __construct(
        private readonly MetalIconStorageService $iconStorageService,
        private readonly MetalRateQuoteService $metalRateQuoteService
    )
    
    {
    }


    public function index()
    {
        MetalRateUpdate::applyDueUpdates();

        $rates = MetalRate::query()
            ->with(['pendingUpdates', 'quotes.governorate'])
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
        $validated = $this->validateMetalRatePayload($request);

        $metalAttributes = Arr::only($validated['metal'], ['metal_type', 'karat']);


        $iconPayload = $this->resolveMetalIconPayload($request, $this->iconStorageService);

        /** @var MetalRate $rate */
        $rate = MetalRate::create(array_merge($metalAttributes, $iconPayload));

        $this->metalRateQuoteService->syncQuotes(
            $rate,
            $validated['quotes'],
            $validated['default_governorate_id'],
            Auth::id()
        );



        $rate->refresh();
        $rate->load('quotes.governorate');


        return ResponseService::successResponse(
            __('تم إضافة سعر المعدن بنجاح.'),
            new MetalRateResource($rate)
        );
    }

    public function show(MetalRate $metalRate)
    {
        $metalRate->refreshDueSchedules();


        $metalRate->refresh();
        $metalRate->load(['pendingUpdates', 'quotes.governorate']);



        return ResponseService::successResponse(
            __('تم جلب سعر المعدن بنجاح.'),
            new MetalRateResource($metalRate)
        );
    }

    public function update(Request $request, MetalRate $metalRate)
    {
        $validated = $this->validateMetalRatePayload($request, $metalRate);
        $metalAttributes = Arr::only($validated['metal'], ['metal_type', 'karat']);


        $iconPayload = $this->resolveMetalIconPayload($request, $this->iconStorageService, $metalRate);

        $metalRate->update(array_merge($metalAttributes, $iconPayload));

        $this->metalRateQuoteService->syncQuotes(
            $metalRate,
            $validated['quotes'],
            $validated['default_governorate_id'],
            Auth::id()
        );



        $metalRate->refresh();
        $metalRate->load(['pendingUpdates', 'quotes.governorate']);

        
        return ResponseService::successResponse(
            __('تم تحديث سعر المعدن بنجاح.'),
            new MetalRateResource($metalRate)
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