<?php

namespace App\Http\Requests\Store;

use App\Enums\StoreClosureMode;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class StoreOnboardingRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $payloadForLog = $this->all();
        if (isset($payloadForLog['credentials']['password'])) {
            $payloadForLog['credentials']['password'] = '[hidden]';
        }
        if (isset($payloadForLog['staff']['password'])) {
            $payloadForLog['staff']['password'] = '[hidden]';
        }

        Log::info('store_onboarding.request_payload', [
            'user_id' => $this->user()?->id,
            'payload' => $payloadForLog,
        ]);

        $store = $this->user()?->stores()->latest()->first();

        $passwordRule = Password::min(8)
            ->letters()
            ->numbers();

        return [
            'name' => [
                'required',
                'string',
                'max:255',
                Rule::unique('stores', 'name')->ignore(optional($store)->id),
            ],
            'description' => ['nullable', 'string'],
            'slug' => ['nullable', 'string', 'max:255'],
            'contact_email' => ['nullable', 'email'],
            'contact_phone' => ['nullable', 'string', 'max:32'],
            'contact_whatsapp' => ['nullable', 'string', 'max:32'],
            'address' => ['nullable', 'string', 'max:500'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'city' => ['nullable', 'string', 'max:120'],
            'state' => ['nullable', 'string', 'max:120'],
            'country' => ['nullable', 'string', 'size:2'],
            'location_notes' => ['nullable', 'string'],
            'logo' => ['nullable', 'string'],
            'banner' => ['nullable', 'string'],

            'settings' => ['nullable', 'array'],
            'settings.closure_mode' => ['nullable', Rule::in(StoreClosureMode::values())],
            'settings.is_manually_closed' => ['nullable', 'boolean'],
            'settings.manual_closure_reason' => ['nullable', 'string'],
            'settings.manual_closure_expires_at' => ['nullable', 'date'],
            'settings.min_order_amount' => ['nullable', 'numeric', 'min:0'],
            'settings.allow_pickup' => ['nullable', 'boolean'],
            'settings.allow_delivery' => ['nullable', 'boolean'],
            'settings.allow_manual_payments' => ['nullable', 'boolean'],
            'settings.allow_wallet' => ['nullable', 'boolean'],
            'settings.allow_cod' => ['nullable', 'boolean'],
            'settings.auto_accept_orders' => ['nullable', 'boolean'],
            'settings.order_acceptance_buffer_minutes' => ['nullable', 'integer', 'min:0', 'max:1440'],
            'settings.delivery_radius_km' => ['nullable', 'numeric', 'min:0'],
            'settings.checkout_notice' => ['nullable', 'string'],

            'working_hours' => ['nullable', 'array'],
            'working_hours.*.weekday' => ['required_with:working_hours', 'integer', 'min:0', 'max:6'],
            'working_hours.*.is_open' => ['nullable', 'boolean'],
            'working_hours.*.opens_at' => ['nullable', 'date_format:H:i'],
            'working_hours.*.closes_at' => ['nullable', 'date_format:H:i'],

            'policies' => ['nullable', 'array'],
            'policies.*.policy_type' => ['required_with:policies', 'string', 'max:32'],
            'policies.*.title' => ['nullable', 'string', 'max:255'],
            'policies.*.content' => ['required_with:policies', 'string'],
            'policies.*.is_required' => ['nullable', 'boolean'],
            'policies.*.is_active' => ['nullable', 'boolean'],
            'policies.*.display_order' => ['nullable', 'integer'],

            'credentials' => ['required_without:staff', 'array'],
            'credentials.handle' => [
                'required_without:staff.invited_email',
                'string',
                'min:' . (int) config('store.staff_email_min_length', 3),
                'max:' . (int) config('store.staff_email_max_length', 48),
                'regex:/^[A-Za-z0-9._-]+$/',
            ],
            'credentials.password' => [
                'required_without:staff.password',
                'string',
                $passwordRule,
            ],

            'staff' => ['nullable', 'array'],
            'staff.invited_email' => [
                'required_without:credentials.handle',
                'string',
                'min:' . (int) config('store.staff_email_min_length', 3),
                'max:' . (int) config('store.staff_email_max_length', 48),
                'regex:/^[A-Za-z0-9._-]+$/',
            ],
            'staff.password' => [
                'required_without:credentials.password',
                'string',
                $passwordRule,
            ],

            'financial' => ['nullable', 'array'],
            'financial.policy_type' => ['nullable', 'string', 'max:32'],
            'financial.policy_payload' => ['nullable', 'array'],

            'meta' => ['nullable', 'array'],
            'meta.categories' => ['nullable', 'array'],
            'meta.categories.*' => ['integer'],
            'meta.payment_methods' => ['nullable', 'array'],
            'meta.payment_methods.*' => ['string'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.unique' => 'اسم المتجر مستخدم بالفعل، يرجى اختيار اسم مختلف.',
        ];
    }

    /**
     * Log validation errors so we can debug failing submissions easily.
     */
    protected function failedValidation(Validator $validator)
    {
        $logPayload = $this->all();
        if (isset($logPayload['credentials']['password'])) {
            $logPayload['credentials']['password'] = '[hidden]';
        }
        if (isset($logPayload['staff']['password'])) {
            $logPayload['staff']['password'] = '[hidden]';
        }

        Log::warning('store_onboarding.validation_failed', [
            'user_id' => $this->user()?->id,
            'errors' => $validator->errors()->toArray(),
            'payload' => $logPayload,
        ]);

        parent::failedValidation($validator);
    }
}
