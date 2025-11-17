<?php

namespace App\Http\Controllers\Store;

use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Models\StoreGateway;
use App\Models\StoreGatewayAccount;
use App\Models\StorePolicy;
use App\Models\StoreSetting;
use App\Models\StoreStaff;
use App\Models\StoreWorkingHour;
use App\Models\User;
use App\Services\Store\StoreStatusService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class StoreSettingsController extends Controller
{
    public function index(Request $request, StoreStatusService $storeStatusService): View
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');

        $store->loadMissing(['settings', 'workingHours', 'policies', 'staff', 'gatewayAccounts.storeGateway']);

        $settings = $store->settings ?? new StoreSetting([
            'closure_mode' => 'full',
            'is_manually_closed' => false,
            'allow_delivery' => true,
            'allow_pickup' => true,
        ]);

        $workingHours = $this->buildWorkingHoursMatrix($store);
        $policies = $this->buildPolicyMap($store);
        $staff = $store->staff->first();
        $storeGateways = StoreGateway::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->get();
        $gatewayAccounts = $store->gatewayAccounts()
            ->with('storeGateway')
            ->latest()
            ->get();

        $weekdays = [
            0 => __('Sunday'),
            1 => __('Monday'),
            2 => __('Tuesday'),
            3 => __('Wednesday'),
            4 => __('Thursday'),
            5 => __('Friday'),
            6 => __('Saturday'),
        ];

        $statusSummary = $storeStatusService->resolve($store);

        return view('store.settings.index', [
            'store' => $store,
            'settings' => $settings,
            'workingHours' => $workingHours,
            'policies' => $policies,
            'staff' => $staff,
            'storeGateways' => $storeGateways,
            'gatewayAccounts' => $gatewayAccounts,
            'weekdays' => $weekdays,
            'statusSummary' => $statusSummary,
        ]);
    }

    public function updateGeneral(Request $request): RedirectResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');

        $validated = $request->validate([
            'min_order_amount' => ['nullable', 'numeric', 'min:0'],
            'closure_mode' => ['required', Rule::in(['full', 'browse'])],
            'is_manually_closed' => ['nullable', 'boolean'],
            'manual_closure_reason' => [
                Rule::requiredIf(static fn () => $request->boolean('is_manually_closed')),
                'nullable',
                'string',
                'max:500',
            ],
            'manual_closure_expires_at' => ['nullable', 'date'],
            'allow_manual_payments' => ['nullable', 'boolean'],
            'allow_wallet' => ['nullable', 'boolean'],
            'allow_cod' => ['nullable', 'boolean'],
            'auto_accept_orders' => ['nullable', 'boolean'],
            'order_acceptance_buffer_minutes' => ['nullable', 'integer', 'min:0', 'max:1440'],
            'checkout_notice' => ['nullable', 'string', 'max:1000'],
        ]);

        $payload = [
            'closure_mode' => $validated['closure_mode'],
            'is_manually_closed' => (bool) ($validated['is_manually_closed'] ?? false),
            'manual_closure_reason' => $validated['manual_closure_reason'] ?? null,
            'manual_closure_expires_at' => $validated['manual_closure_expires_at'] ?? null,
            'min_order_amount' => $validated['min_order_amount'] ?? null,
            'allow_manual_payments' => (bool) ($validated['allow_manual_payments'] ?? false),
            'allow_wallet' => (bool) ($validated['allow_wallet'] ?? false),
            'allow_cod' => (bool) ($validated['allow_cod'] ?? false),
            'auto_accept_orders' => (bool) ($validated['auto_accept_orders'] ?? false),
            'order_acceptance_buffer_minutes' => $validated['order_acceptance_buffer_minutes'] ?? null,
            'checkout_notice' => $validated['checkout_notice'] ?? null,
        ];

        StoreSetting::updateOrCreate(
            ['store_id' => $store->id],
            $payload
        );

        return redirect()
            ->route('merchant.settings', ['tab' => 'general'])
            ->with('success', __('Store preferences updated successfully.'));
    }

    public function storeGatewayAccount(Request $request): RedirectResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');

        $validated = $request->validate([
            'store_gateway_id' => [
                'required',
                'integer',
                Rule::exists('store_gateways', 'id')->where('is_active', true),
            ],
            'beneficiary_name' => ['required', 'string', 'max:255'],
            'account_number' => ['required', 'string', 'max:255'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $request->user()
            ->storeGatewayAccounts()
            ->create([
                'store_gateway_id' => $validated['store_gateway_id'],
                'store_id' => $store->id,
                'beneficiary_name' => $validated['beneficiary_name'],
                'account_number' => $validated['account_number'],
                'is_active' => array_key_exists('is_active', $validated)
                    ? (bool) $validated['is_active']
                    : true,
            ]);

        return redirect()
            ->route('merchant.settings', ['tab' => 'payments'])
            ->with('success', __('تم إضافة الحساب البنكي بنجاح.'));
    }

    public function updateGatewayAccount(Request $request, StoreGatewayAccount $storeGatewayAccount): RedirectResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');
        abort_unless($storeGatewayAccount->store_id === $store->id, 404);

        $validated = $request->validate([
            'store_gateway_id' => [
                'sometimes',
                'integer',
                Rule::exists('store_gateways', 'id')->where('is_active', true),
            ],
            'beneficiary_name' => ['sometimes', 'string', 'max:255'],
            'account_number' => ['sometimes', 'string', 'max:255'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        if (array_key_exists('is_active', $validated)) {
            $validated['is_active'] = (bool) $validated['is_active'];
        }

        $storeGatewayAccount->update($validated);

        return redirect()
            ->route('merchant.settings', ['tab' => 'payments'])
            ->with('success', __('تم تحديث بيانات الحساب البنكي.'));
    }

    public function destroyGatewayAccount(Request $request, StoreGatewayAccount $storeGatewayAccount): RedirectResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');
        abort_unless($storeGatewayAccount->store_id === $store->id, 404);

        $storeGatewayAccount->delete();

        return redirect()
            ->route('merchant.settings', ['tab' => 'payments'])
            ->with('success', __('تم حذف الحساب البنكي.'));
    }

    public function updateHours(Request $request): RedirectResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');

        $validated = $request->validate([
            'hours' => ['required', 'array'],
            'hours.*.weekday' => ['required', 'integer', 'between:0,6'],
            'hours.*.is_open' => ['nullable', 'boolean'],
            'hours.*.opens_at' => ['nullable', 'date_format:H:i'],
            'hours.*.closes_at' => ['nullable', 'date_format:H:i'],
        ]);

        $normalized = $this->normalizeWorkingHoursData($validated['hours']);

        DB::transaction(function () use ($store, $normalized): void {
            $store->workingHours()->delete();

            foreach ($normalized as $hour) {
                StoreWorkingHour::create(array_merge($hour, ['store_id' => $store->id]));
            }
        });

        return redirect()
            ->route('merchant.settings', ['tab' => 'hours'])
            ->with('success', __('Working hours updated successfully.'));
    }

    public function updatePolicies(Request $request): RedirectResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');

        $validated = $request->validate([
            'policy_text' => ['required', 'string'],
        ]);

        $policyText = $validated['policy_text'];

        $this->persistPolicy(
            $store,
            'return',
            __('Return / Exchange Policy'),
            $policyText
        );

        $this->persistPolicy(
            $store,
            'exchange',
            __('Return / Exchange Policy'),
            $policyText
        );

        return redirect()
            ->route('merchant.settings', ['tab' => 'policies'])
            ->with('success', __('Policies saved successfully.'));
    }

    public function updateStaff(Request $request): RedirectResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');

        $validated = $request->validate([
            'staff_prefix' => [
                'required',
                'string',
                'min:3',
                'max:32',
                'regex:/^[a-z0-9._-]+$/i',
            ],
        ], [
            'staff_prefix.regex' => __('Only letters, numbers, dots, dashes, and underscores are allowed.'),
        ]);

        $prefix = strtolower($validated['staff_prefix']);
        $email = $prefix . '@maribsrv.com';

        if ($store->staff()->whereRaw('LOWER(email) = ?', [$email])->exists()) {
            // already assigned to this store
            return redirect()
                ->route('merchant.settings', ['tab' => 'staff'])
                ->with('info', __('This staff email is already assigned to your store.'));
        }

        $conflict = StoreStaff::query()
            ->whereRaw('LOWER(email) = ?', [$email])
            ->where('store_id', '!=', $store->id)
            ->exists();

        if ($conflict || User::query()->whereRaw('LOWER(email) = ?', [$email])->exists()) {
            return redirect()
                ->route('merchant.settings', ['tab' => 'staff'])
                ->withErrors(['staff_prefix' => __('This email is already reserved by another user.')]);
        }

        $existing = $store->staff()->first();

        if ($existing) {
            $existing->update([
                'email' => $email,
                'status' => 'pending',
                'invitation_token' => Str::uuid()->toString(),
                'permissions' => $existing->permissions ?? ['full_access' => true],
            ]);
        } else {
            StoreStaff::create([
                'store_id' => $store->id,
                'email' => $email,
                'role' => 'owner',
                'status' => 'pending',
                'permissions' => ['full_access' => true],
                'invitation_token' => Str::uuid()->toString(),
            ]);
        }

        return redirect()
            ->route('merchant.settings', ['tab' => 'staff'])
            ->with('success', __('Staff login email reserved successfully.'));
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function buildWorkingHoursMatrix(Store $store): array
    {
        $byDay = $store->workingHours->keyBy('weekday');
        $matrix = [];

        foreach (range(0, 6) as $weekday) {
            $entry = $byDay->get($weekday);

            $opensAt = $entry?->opens_at;
            $closesAt = $entry?->closes_at;

            $matrix[$weekday] = [
                'weekday' => $weekday,
                'is_open' => (bool) ($entry->is_open ?? false),
                'opens_at' => $opensAt ? substr($opensAt, 0, 5) : null,
                'closes_at' => $closesAt ? substr($closesAt, 0, 5) : null,
            ];
        }

        return $matrix;
    }

    /**
     * @return array<string, StorePolicy|null>
     */
    private function buildPolicyMap(Store $store): array
    {
        $policies = $store->policies->keyBy(static fn (StorePolicy $policy) => strtolower((string) $policy->policy_type));

        return [
            'return' => $policies->get('return'),
            'exchange' => $policies->get('exchange'),
        ];
    }

    /**
     * @param  array<int, array<string, mixed>>  $hours
     * @return array<int, array<string, mixed>>
     */
    private function normalizeWorkingHoursData(array $hours): array
    {
        $result = [];

        foreach ($hours as $payload) {
            $weekday = (int) Arr::get($payload, 'weekday');
            if ($weekday < 0 || $weekday > 6) {
                continue;
            }

            $isOpen = filter_var(Arr::get($payload, 'is_open'), FILTER_VALIDATE_BOOLEAN);
            $opensAt = Arr::get($payload, 'opens_at');
            $closesAt = Arr::get($payload, 'closes_at');

            if (! $isOpen) {
                $opensAt = null;
                $closesAt = null;
            }

            $result[] = [
                'weekday' => $weekday,
                'is_open' => $isOpen,
                'opens_at' => $opensAt,
                'closes_at' => $closesAt,
            ];
        }

        return $result;
    }

    private function persistPolicy(Store $store, string $type, string $title, string $content): void
    {
        StorePolicy::updateOrCreate(
            [
                'store_id' => $store->id,
                'policy_type' => $type,
            ],
            [
                'title' => $title,
                'content' => $content,
                'is_required' => true,
                'is_active' => true,
                'display_order' => $type === 'return' ? 1 : 2,
            ]
        );
    }

}
