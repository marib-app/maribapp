<?php

namespace App\Http\Requests\Wifi;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateWifiNetworkRequest extends FormRequest
{
    public function authorize(): bool
    {
        $network = $this->route('network');

        return $network !== null && $this->user()?->can('update', $network);
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $network = $this->route('network');

        return [
            'wallet_account_id' => ['nullable', 'integer', 'exists:wallet_accounts,id'],
            'name' => ['sometimes', 'string', 'max:255'],
            'slug' => [
                'sometimes',
                'string',
                'max:255',
                'alpha_dash',
                Rule::unique('wifi_networks', 'slug')->ignore($network?->id),
            ],
            'latitude' => ['nullable', 'numeric', 'min:-90', 'max:90'],
            'longitude' => ['nullable', 'numeric', 'min:-180', 'max:180'],
            'coverage_radius_km' => ['nullable', 'numeric', 'min:0', 'max:500'],
            'address' => ['nullable', 'string', 'max:255'],
            'icon_path' => ['nullable', 'string', 'max:255'],
            'login_screenshot_path' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'notes' => ['nullable', 'string'],
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
    }
}