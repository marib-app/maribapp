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
            'source_file' => ['required', 'file', 'mimes:csv,txt,xls,xlsx'],
            'notes' => ['nullable', 'string'],
            'total_codes' => ['nullable', 'integer', 'min:1', 'max:50000'],
            'available_codes' => ['nullable', 'integer', 'min:0'],
            'meta' => ['nullable', 'array'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if ($this->hasFile('file') && ! $this->hasFile('source_file')) {
            $this->files->set('source_file', $this->file('file'));
        }

        if (! $this->filled('label') && $this->hasFile('source_file')) {
            $this->merge([
                'label' => $this->file('source_file')->getClientOriginalName(),
            ]);
        }

        $meta = $this->input('meta');
        if (is_string($meta)) {
            $decodedMeta = json_decode($meta, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decodedMeta)) {
                $this->merge(['meta' => $decodedMeta]);
            }
        }
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
