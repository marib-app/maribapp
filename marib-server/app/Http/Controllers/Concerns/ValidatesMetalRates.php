<?php

namespace App\Http\Controllers\Concerns;

use App\Models\MetalRate;
use App\Services\MetalIconStorageService;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;


trait ValidatesMetalRates
{
    protected function validateMetalRatePayload(Request $request, ?MetalRate $metalRate = null): array
    {
        $data = Validator::make($request->all(), [
            'metal_type' => ['required', 'in:' . implode(',', [MetalRate::TYPE_GOLD, MetalRate::TYPE_SILVER])],
            'karat' => ['nullable', 'numeric', 'min:0', 'max:999'],
            'quotes' => ['required', 'array'],
            'quotes.*.governorate_id' => ['required', 'exists:governorates,id'],
            'quotes.*.sell_price' => ['nullable', 'numeric', 'min:0'],
            'quotes.*.buy_price' => ['nullable', 'numeric', 'min:0'],
            'quotes.*.source' => ['nullable', 'string', 'max:255'],
            'quotes.*.quoted_at' => ['nullable', 'date'],
            'default_governorate_id' => ['required', 'exists:governorates,id'],
            'icon' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp,svg', 'max:2048'],
            'icon_alt' => ['nullable', 'string', 'max:255'],
            'remove_icon' => ['sometimes', 'boolean'],
        ]);

        $data->after(function ($validator) use ($request, $metalRate) {
            $metalType = $request->input('metal_type');
            $karat = $request->input('karat');

            if ($metalType === MetalRate::TYPE_GOLD && blank($karat)) {
                $validator->errors()->add('karat', __('حقل العيار مطلوب للذهب.'));
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
            $quotes = $request->input('quotes', []);
            $hasDefault = false;
            $hasCompleteQuote = false;
            $defaultGovernorateId = (int) $request->input('default_governorate_id');

            foreach ($quotes as $index => $quote) {
                $sell = Arr::get($quote, 'sell_price');
                $buy = Arr::get($quote, 'buy_price');
                $governorateId = (int) Arr::get($quote, 'governorate_id');

                if ($sell !== null && $buy !== null) {
                    $hasCompleteQuote = true;

                    if ((float) $sell < (float) $buy) {
                        $validator->errors()->add(
                            'quotes.' . $index . '.sell_price',
                            __('يجب أن يكون سعر البيع أعلى من أو يساوي سعر الشراء لكل محافظة.')
                        );
                    }
                }

                if ($governorateId === $defaultGovernorateId && $sell !== null && $buy !== null) {
                    $hasDefault = true;
                }
            }



            if (!$hasCompleteQuote) {
                $validator->errors()->add('quotes', __('يرجى إدخال سعر بيع وشراء على الأقل لمحافظة واحدة.'));
            }

            if (!$hasDefault) {
                $validator->errors()->add(
                    'default_governorate_id',
                    __('يجب تحديد محافظة افتراضية تحتوي على سعر بيع وشراء.')
                );
            }
        });

        $payload = $data->validate();

        $payload['quotes'] = array_values($payload['quotes']);

        $payload['karat'] = $payload['metal_type'] === MetalRate::TYPE_SILVER
            ? null
            : $payload['karat'];

        return [
            'metal' => Arr::only($payload, [
                'metal_type',
                'karat',
                'icon',
                'icon_alt',
                'remove_icon',
            ]),
            'quotes' => $payload['quotes'],
            'default_governorate_id' => (int) $payload['default_governorate_id'],
        ];
    }


    protected function resolveMetalIconPayload(Request $request, MetalIconStorageService $iconStorageService, ?MetalRate $metalRate = null): array
    {
        $payload = [];
        $hasNewIcon = $request->hasFile('icon');
        $removeIcon = $request->boolean('remove_icon');
        $hasAltField = $request->has('icon_alt');
        $rawAlt = $hasAltField ? (string) $request->input('icon_alt') : null;
        $iconAlt = $rawAlt !== null ? trim($rawAlt) : null;

        if ($iconAlt === '') {
            $iconAlt = null;
        }

        if ($hasNewIcon) {
            $payload['icon_path'] = $iconStorageService->storeIcon($request->file('icon'), $metalRate?->icon_path);
            $payload['icon_alt'] = $iconAlt;
            $payload['icon_uploaded_by'] = Auth::id();
            $payload['icon_uploaded_at'] = now();
            $payload['icon_removed_by'] = null;
            $payload['icon_removed_at'] = null;

            return $payload;
        }

        if ($removeIcon && $metalRate) {
            $iconStorageService->deleteIcon($metalRate->icon_path);

            $payload['icon_path'] = null;
            $payload['icon_alt'] = null;
            $payload['icon_uploaded_by'] = null;
            $payload['icon_uploaded_at'] = null;
            $payload['icon_removed_by'] = Auth::id();
            $payload['icon_removed_at'] = now();

            return $payload;
        }

        if ($metalRate && $hasAltField) {
            $payload['icon_alt'] = $iconAlt;
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