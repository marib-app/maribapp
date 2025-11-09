<?php

namespace App\Http\Requests\Wifi;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreWifiNetworkRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'wallet_account_id' => ['nullable', 'integer', 'exists:wallet_accounts,id'],
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255', 'alpha_dash', Rule::unique('wifi_networks', 'slug')],
            'latitude' => ['nullable', 'numeric', 'min:-90', 'max:90'],
            'longitude' => ['nullable', 'numeric', 'min:-180', 'max:180'],
            'coverage_radius_km' => ['nullable', 'numeric', 'min:0', 'max:500'],
            'address' => ['nullable', 'string', 'max:255'],
            'icon_path' => ['nullable', 'string', 'max:255'],
            'login_screenshot_path' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'notes' => ['nullable', 'string'],
            'logo' => ['nullable', 'image', 'max:5120'],
            'login_screenshot' => ['nullable', 'image', 'max:5120'],
            'currencies' => ['nullable', 'array'],
            'currencies.*' => ['string', 'size:3'],
            'contacts' => ['nullable', 'array'],
            'contacts.*.type' => ['required_with:contacts', 'string', 'max:40'],
            'contacts.*.value' => ['required_with:contacts', 'string', 'max:255'],
            'meta' => ['nullable', 'array'],
            'settings' => ['nullable', 'array'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('currencies')) {
            $this->merge([
                'currencies' => collect($this->input('currencies', []))
                    ->filter()
                    ->map(static fn ($currency) => strtoupper((string) $currency))
                    ->unique()
                    ->values()
                    ->all(),
            ]);
        }

        if (is_string($this->input('meta'))) {
            $decodedMeta = json_decode($this->input('meta'), true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decodedMeta)) {
                $this->merge(['meta' => $decodedMeta]);
            }
        }
    }
}
