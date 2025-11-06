<?php

namespace App\Http\Requests\Wifi;

use Illuminate\Foundation\Http\FormRequest;

class OwnerNetworkStatsRequest extends FormRequest
{
    public function authorize(): bool
    {
        $network = $this->route('network');

        return $network !== null && $this->user()?->can('view', $network);
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date', 'after_or_equal:from'],
        ];
    }
}