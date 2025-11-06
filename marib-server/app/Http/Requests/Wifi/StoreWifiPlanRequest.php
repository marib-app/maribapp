<?php

namespace App\Http\Requests\Wifi;

use App\Enums\Wifi\WifiPlanStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreWifiPlanRequest extends FormRequest
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
        return [
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255', 'alpha_dash', Rule::unique('wifi_plans', 'slug')],
            'status' => ['nullable', 'string', Rule::in([
                WifiPlanStatus::UPLOADED->value,
                WifiPlanStatus::VALIDATED->value,
                WifiPlanStatus::ACTIVE->value,
            ])],
            'price' => ['required', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],
            'duration_days' => ['nullable', 'integer', 'min:1', 'max:365'],
            'data_cap_gb' => ['nullable', 'numeric', 'min:0'],
            'is_unlimited' => ['nullable', 'boolean'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'description' => ['nullable', 'string'],
            'notes' => ['nullable', 'string'],
            'benefits' => ['nullable', 'array'],
            'benefits.*' => ['string', 'max:255'],
            'meta' => ['nullable', 'array'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('currency')) {
            $this->merge(['currency' => strtoupper((string) $this->input('currency'))]);
        }
    }
}