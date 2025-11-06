<?php

namespace App\Http\Requests\Wifi;

use Illuminate\Foundation\Http\FormRequest;

class UpsertReputationCounterRequest extends FormRequest
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
            'metric' => ['required', 'string', 'max:120'],
            'score' => ['required', 'numeric', 'between:-1000,1000'],
            'value' => ['required', 'integer', 'between:-1000000,1000000'],
            'period_start' => ['nullable', 'date'],
            'period_end' => ['nullable', 'date', 'after_or_equal:period_start'],
            'meta' => ['nullable', 'array'],
        ];
    }
}