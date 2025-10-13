<?php

namespace App\Http\Controllers\Concerns;

use App\Models\MetalRate;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

trait ValidatesMetalRates
{
    protected function validateMetalRatePayload(Request $request, ?MetalRate $metalRate = null): array
    {
        $data = Validator::make($request->all(), [
            'metal_type' => ['required', 'in:' . implode(',', [MetalRate::TYPE_GOLD, MetalRate::TYPE_SILVER])],
            'karat' => ['nullable', 'numeric', 'min:0', 'max:999'],
            'buy_price' => ['required', 'numeric', 'min:0'],
            'sell_price' => ['required', 'numeric', 'min:0'],
            'source' => ['nullable', 'string', 'max:255'],
            'quoted_at' => ['nullable', 'date'],
        ]);

        $data->after(function ($validator) use ($request, $metalRate) {
            $metalType = $request->input('metal_type');
            $karat = $request->input('karat');

            if ($metalType === MetalRate::TYPE_GOLD && blank($karat)) {
                $validator->errors()->add('karat', __('حقل العيار مطلوب للذهب.'));
            }

            $buy = (float) $request->input('buy_price');
            $sell = (float) $request->input('sell_price');

            if ($sell < $buy) {
                $validator->errors()->add('sell_price', __('يجب أن يكون سعر البيع أعلى من أو يساوي سعر الشراء.'));
            }

            $existsQuery = MetalRate::query()
                ->where('metal_type', $metalType)
                ->when($metalType === MetalRate::TYPE_GOLD, function ($query) use ($karat) {
                    $query->where('karat', $karat);
                }, function ($query) {
                    $query->whereNull('karat');
                });

            if ($metalRate) {
                $existsQuery->where('id', '!=', $metalRate->id);
            }

            if ($existsQuery->exists()) {
                $validator->errors()->add('karat', __('تم تسجيل هذا المعدن مسبقًا.'));
            }
        });

        $payload = $data->validate();

        if ($payload['metal_type'] === MetalRate::TYPE_SILVER) {
            $payload['karat'] = null;
        }

        if (empty($payload['quoted_at'])) {
            $payload['quoted_at'] = now();
        }

        return $payload;
    }

    protected function validateMetalRateSchedule(Request $request): array
    {
        $data = Validator::make($request->all(), [
            'buy_price' => ['required', 'numeric', 'min:0'],
            'sell_price' => ['required', 'numeric', 'min:0'],
            'source' => ['nullable', 'string', 'max:255'],
            'scheduled_for' => ['required', 'date', 'after:now'],
        ]);

        $data->after(function ($validator) use ($request) {
            $buy = (float) $request->input('buy_price');
            $sell = (float) $request->input('sell_price');

            if ($sell < $buy) {
                $validator->errors()->add('sell_price', __('يجب أن يكون سعر البيع أعلى من أو يساوي سعر الشراء.'));
            }
        });

        return $data->validate();
    }
}