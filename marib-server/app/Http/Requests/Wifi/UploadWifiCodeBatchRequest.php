<?php

namespace App\Http\Requests\Wifi;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class UploadWifiCodeBatchRequest extends FormRequest
{
    public function authorize(): bool
    {
        $plan = $this->route('plan');

        return $plan !== null && $this->user()?->can('update', $plan);
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'label' => ['required', 'string', 'max:255'],
            'source_file' => ['required', 'file', 'mimes:csv,txt,xlsx'],
            'notes' => ['nullable', 'string'],
            'total_codes' => ['nullable', 'integer', 'min:1', 'max:50000'],
            'available_codes' => ['nullable', 'integer', 'min:0'],
            'meta' => ['nullable', 'array'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $total = (int) $this->input('total_codes', 0);
            $available = (int) $this->input('available_codes', 0);

            if ($total > 0 && $available > $total) {
                $validator->errors()->add('available_codes', __('Available codes cannot exceed the total uploaded codes.'));
            }
        });
    }
}
