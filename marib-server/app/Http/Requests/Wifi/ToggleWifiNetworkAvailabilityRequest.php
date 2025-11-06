<?php

namespace App\Http\Requests\Wifi;

use App\Enums\Wifi\WifiNetworkStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class ToggleWifiNetworkAvailabilityRequest extends FormRequest
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
            'status' => ['required', 'string', 'in:active,inactive'],
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

            if ($network->status === WifiNetworkStatus::SUSPENDED) {
                $validator->errors()->add('status', __('Suspended networks must be reinstated by an administrator.'));
                return;
            }

            if ($network->status === $target) {
                $validator->errors()->add('status', __('The network is already in the requested state.'));
            }
        });
    }
}