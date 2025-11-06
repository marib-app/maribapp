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
        $validator->after(function (Validator $validator): void {
            $network = $this->route('network');
            if (! $network) {
                return;
            }

            $target = WifiNetworkStatus::from($this->input('status'));

            if ($network->status === $target) {
                $validator->errors()->add('status', __('The network already has this status.'));
            }
        });
    }
}