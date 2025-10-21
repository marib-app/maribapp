<?php

namespace App\Http\Requests\Wifi;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class StoreWifiNetworkRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        $slugRules = ['nullable', 'string', 'max:255'];

        if (Schema::hasColumn('wifi_networks', 'slug')) {
            $slugRules[] = Rule::unique('wifi_networks', 'slug');
        }

        return [
            'name' => ['required', 'string', 'min:2', 'max:255'],
            'slug' => $slugRules,
            'description' => ['nullable', 'string'],
            'wallet_id' => ['required', 'numeric', Rule::exists('wallet_accounts', 'id')],
            'location_name' => ['nullable', 'string', 'max:255'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'commission_rate' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'commission_flat' => ['nullable', 'numeric', 'min:0'],
            'contacts' => ['nullable', 'array', 'min:1'],
            'contacts.*' => ['nullable', 'string'],
            'notes' => ['nullable', 'string'],
            'is_active' => ['nullable', 'boolean'],
            'meta' => ['nullable', 'array'],
            'meta.*' => ['nullable'],
            'logo' => ['nullable', 'image', 'max:4096'],
            'login_screenshot' => ['nullable', 'image', 'max:4096'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $input = $this->all();

        if (array_key_exists('contacts', $input) && $input['contacts'] !== null && ! is_array($input['contacts'])) {
            if (is_string($input['contacts'])) {
                $chunks = preg_split('/[\r\n,;]+/', $input['contacts']);
                $input['contacts'] = $chunks !== false ? array_filter($chunks, static fn ($value) => $value !== '') : [$input['contacts']];
            } else {
                $input['contacts'] = Arr::wrap($input['contacts']);
            }
        }

        if (array_key_exists('meta', $input) && is_string($input['meta'])) {
            $decoded = json_decode($input['meta'], true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $input['meta'] = $decoded;
            }
        }

        $this->replace($input);
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $payload = $this->all();

            $numericKeys = array_filter(array_keys($payload), static fn ($key) => is_int($key));
            if ($numericKeys !== []) {
                $validator->errors()->add('payload', __('The request payload must be an associative array.'));
            }

            $meta = $this->input('meta');
            if (is_array($meta) && ! Arr::isAssoc($meta)) {
                $validator->errors()->add('meta', __('The meta field must use string keys.'));
            }
        });
    }

    protected function failedValidation(Validator $validator)
    {
        throw new ValidationException($validator);
    }
}