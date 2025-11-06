<?php

namespace App\Http\Requests\Wifi;

use Illuminate\Foundation\Http\FormRequest;

class SetWifiCommissionRequest extends FormRequest
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
            'commission_rate' => ['required', 'numeric', 'min:0', 'max:0.5'],
        ];
    }
}