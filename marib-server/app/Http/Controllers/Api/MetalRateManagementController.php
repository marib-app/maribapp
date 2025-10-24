<?php

namespace App\Http\Controllers\Api;

use App\Events\MetalRateCreated;
use App\Events\MetalRateUpdated;
use App\Http\Controllers\Concerns\ValidatesMetalRates;
use App\Http\Controllers\Controller;
use App\Http\Resources\MetalRateResource;
use App\Models\MetalRate;
use App\Services\MetalIconStorageService;
use App\Services\MetalRateQuoteService;
use App\Models\MetalRateUpdate;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;


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

        $quotesPayload = $this->buildQuoteEventPayload($rate);
        $defaultGovernorateId = $this->resolveDefaultGovernorateId($rate);

        if ($defaultGovernorateId !== null) {
            MetalRateCreated::dispatch(
                $rate->getKey(),
                $quotesPayload,
                $defaultGovernorateId
            );
        }


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

        
        $quotesPayload = $this->buildQuoteEventPayload($metalRate);
        $defaultGovernorateId = $this->resolveDefaultGovernorateId($metalRate);

        if ($defaultGovernorateId !== null) {
            MetalRateUpdated::dispatch(
                $metalRate->getKey(),
                $quotesPayload,
                $defaultGovernorateId
            );
        }


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



    
    /**
     * @return array<int, array{
     *     governorate_id: int,
     *     governorate_code: string|null,
     *     governorate_name: string|null,
     *     sell_price: string|null,
     *     buy_price: string|null,
     *     is_default: bool
     * }>
     */
    private function buildQuoteEventPayload(MetalRate $metalRate): array
    {
        return $metalRate->quotes
            ->map(static function ($quote) {
                $governorate = $quote->relationLoaded('governorate')
                    ? $quote->governorate
                    : $quote->governorate()->first();

                return [
                    'governorate_id' => (int) $quote->governorate_id,
                    'governorate_code' => $governorate?->code
                        ? Str::upper((string) $governorate->code)
                        : null,
                    'governorate_name' => $governorate?->name,
                    'sell_price' => $quote->sell_price !== null
                        ? (string) $quote->sell_price
                        : null,
                    'buy_price' => $quote->buy_price !== null
                        ? (string) $quote->buy_price
                        : null,
                    'is_default' => (bool) $quote->is_default,
                ];
            })
            ->values()
            ->all();
    }

    private function resolveDefaultGovernorateId(MetalRate $metalRate): ?int
    {
        $defaultQuote = $metalRate->quotes->firstWhere('is_default', true)
            ?? $metalRate->quotes->first();

        return $defaultQuote ? (int) $defaultQuote->governorate_id : null;
    }
}