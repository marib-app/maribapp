<?php

namespace App\Http\Requests\Wifi;

use App\Enums\Wifi\WifiNetworkStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class AdminUpdateWifiNetworkStatusRequest extends FormRequest
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
            'status' => ['required', 'string', Rule::in(array_map(static fn (WifiNetworkStatus $status) => $status->value, WifiNetworkStatus::cases()))],
            'reason' => ['nullable', 'string', 'max:255'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        // Allow re-applying the same status (e.g., to add a reason or re-send notifications).
    }
}
