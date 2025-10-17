<?php

namespace App\Http\Requests;

use App\Enums\NotificationFrequency;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateUserPreferenceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    protected function prepareForValidation(): void
    {
        foreach (['currency_watchlist', 'metal_watchlist'] as $key) {
            $value = $this->input($key);
            if (is_string($value)) {
                $decoded = json_decode($value, true);
                if (is_array($decoded)) {
                    $this->merge([$key => $decoded]);
                }
            }
        }


        $regions = $this->input('currency_notification_regions');
        if (is_string($regions)) {
            $decoded = json_decode($regions, true);
            if (is_array($decoded)) {
                $this->merge(['currency_notification_regions' => $decoded]);
            }
        }

    }

    public function rules(): array
    {
        return [
            'favorite_governorate_code' => ['nullable', 'string', 'exists:governorates,code'],
            'currency_watchlist' => ['sometimes', 'array'],
            'currency_watchlist.*' => ['integer', 'exists:currency_rates,id'],
            'metal_watchlist' => ['sometimes', 'array'],
            'metal_watchlist.*' => ['integer', 'exists:metal_rates,id'],
            'notification_frequency' => ['nullable', 'string', Rule::in(NotificationFrequency::values())],

            'currency_notification_regions' => ['sometimes', 'array'],
            'currency_notification_regions.*' => ['nullable', 'string', 'exists:governorates,code'],

        ];
    }
}