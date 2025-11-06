<?php

namespace App\Http\Requests\Wifi;

use Illuminate\Foundation\Http\FormRequest;

class SearchWifiPlansRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'q' => ['nullable', 'string', 'max:120'],
            'network_id' => ['nullable', 'integer', 'exists:wifi_networks,id'],
            'status' => ['nullable', 'string', 'in:active,validated'],
            'currency' => ['nullable', 'string', 'size:3'],
            'price_min' => ['nullable', 'numeric', 'min:0'],
            'price_max' => ['nullable', 'numeric', 'min:0'],
            'duration_min' => ['nullable', 'integer', 'min:1'],
            'duration_max' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('currency')) {
            $this->merge(['currency' => strtoupper((string) $this->input('currency'))]);
        }
    }
}