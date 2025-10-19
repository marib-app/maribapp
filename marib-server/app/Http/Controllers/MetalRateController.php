<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\ValidatesMetalRates;
use App\Models\Governorate;
use App\Models\MetalRate;
use App\Models\MetalRateUpdate;
use App\Services\MetalRateQuoteService;
use App\Services\MetalIconStorageService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Arr;


class MetalRateController extends Controller
{
    use ValidatesMetalRates;

    public function __construct(
        private readonly MetalIconStorageService $iconStorageService,
        private readonly MetalRateQuoteService $metalRateQuoteService
    )
    
    {
    }

    public function index(): View
    {
        MetalRateUpdate::applyDueUpdates();

        $metalRates = MetalRate::query()
            ->with([
                'pendingUpdates' => function ($query) {
                    $query->orderBy('scheduled_for');
                },
                'quotes.governorate',
            ])


            ->orderBy('metal_type')
            ->orderBy('karat')
            ->get();

        return view('metal_rates.index', [
            'metalRates' => $metalRates,
            'governorates' => Governorate::query()->orderBy('name')->get(),
            'defaultGovernorateId' => $this->metalRateQuoteService->resolveDefaultGovernorateId(),

        ]);
    }


    public function create(): View
    {
        return view('metal_rates.create', [
            'governorates' => Governorate::query()->orderBy('name')->get(),
            'defaultGovernorateId' => $this->metalRateQuoteService->resolveDefaultGovernorateId(),
        ]);
    
    }


    public function store(Request $request): RedirectResponse
    {
        $validated = $this->validateMetalRatePayload($request);

        $metalAttributes = Arr::only($validated['metal'], ['metal_type', 'karat']);


        $iconPayload = $this->resolveMetalIconPayload($request, $this->iconStorageService);

        /** @var MetalRate $metal */
        $metal = MetalRate::create(array_merge($metalAttributes, $iconPayload));


        $this->metalRateQuoteService->syncQuotes(
            $metal,
            $validated['quotes'],
            $validated['default_governorate_id'],
            Auth::id()
        );

        return redirect()
            ->route('metal-rates.index')
            ->with('success', __('تم إضافة سعر المعدن بنجاح.'));
    }

    public function update(Request $request, MetalRate $metalRate): RedirectResponse
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

        
        return redirect()
            ->route('metal-rates.index')
            ->with('success', __('تم تحديث سعر المعدن بنجاح.'));
    }

    public function destroy(MetalRate $metalRate): RedirectResponse
    {
        $metalRate->delete();

        return redirect()
            ->route('metal-rates.index')
            ->with('success', __('تم حذف سعر المعدن بنجاح.'));
    }

    public function schedule(Request $request, MetalRate $metalRate): RedirectResponse
    {
        $payload = $this->validateMetalRateSchedule($request);

        $metalRate->pendingUpdates()->create($payload + [
            'created_by' => Auth::id(),
        ]);

        return redirect()
            ->route('metal-rates.index')
            ->with('success', __('تمت جدولة التحديث بنجاح.'));
    }

    public function cancelSchedule(MetalRateUpdate $metalRateUpdate): RedirectResponse
    {
        $metalRateUpdate->cancel();

        return redirect()
            ->route('metal-rates.index')
            ->with('success', __('تم إلغاء الجدولة بنجاح.'));
    }
}