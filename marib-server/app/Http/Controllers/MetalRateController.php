<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\ValidatesMetalRates;
use App\Models\MetalRate;
use App\Models\MetalRateUpdate;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class MetalRateController extends Controller
{
    use ValidatesMetalRates;

    public function index(): View
    {
        MetalRateUpdate::applyDueUpdates();

        $metalRates = MetalRate::query()
            ->with(['pendingUpdates' => function ($query) {
                $query->orderBy('scheduled_for');
            }])
            ->orderBy('metal_type')
            ->orderBy('karat')
            ->get();

        return view('metal_rates.index', [
            'metalRates' => $metalRates,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $payload = $this->validateMetalRatePayload($request);

        MetalRate::create($payload);

        return redirect()
            ->route('metal-rates.index')
            ->with('success', __('تم إضافة سعر المعدن بنجاح.'));
    }

    public function update(Request $request, MetalRate $metalRate): RedirectResponse
    {
        $payload = $this->validateMetalRatePayload($request, $metalRate);

        $metalRate->update($payload);

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