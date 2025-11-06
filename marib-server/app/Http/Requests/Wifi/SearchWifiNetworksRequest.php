<?php

namespace App\Http\Requests\Wifi;

use Illuminate\Foundation\Http\FormRequest;

class SearchWifiNetworksRequest extends FormRequest
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
            'status' => ['nullable', 'string', 'in:active,inactive,suspended'],
            'currency' => ['nullable', 'string', 'size:3'],
            'latitude' => ['nullable', 'numeric', 'min:-90', 'max:90'],
            'longitude' => ['nullable', 'numeric', 'min:-180', 'max:180'],
            'radius_km' => ['nullable', 'numeric', 'min:0', 'max:500'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
            'owner_id' => ['nullable', 'integer', 'min:1'],
            'with_plans' => ['nullable', 'boolean'],
        ];
    }
}