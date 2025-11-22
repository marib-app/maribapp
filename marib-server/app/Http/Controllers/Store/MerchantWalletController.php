<?php

namespace App\Http\Controllers\Store;

use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Models\WalletAccount;
use App\Models\WalletWithdrawalRequest;
use App\Services\WalletService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\View\View;
use Throwable;

class MerchantWalletController extends Controller
{
    public function index(Request $request): View
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');

        return view('store.wallet.index', [
            'store' => $store,
            'wallet' => $this->buildWalletContext($request),
        ]);
    }

    public function submitWithdrawal(Request $request, WalletService $walletService): RedirectResponse
    {
        $methods = $this->getWalletWithdrawalMethods();
        $minimumAmount = max(0.01, (float) config('wallet.withdrawals.minimum_amount', 1));

        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:' . $minimumAmount],
            'preferred_method' => ['required', Rule::in(array_keys($methods))],
            'notes' => ['nullable', 'string', 'max:500'],
        ], [], [
            'preferred_method' => __('merchant_wallet.form.method'),
        ]);

        $methodKey = $validated['preferred_method'];
        $method = $methods[$methodKey];
        $withdrawalMeta = $this->validateWithdrawalMetaFromRequest($request, $method);

        $user = $request->user();
        $defaultCurrency = strtoupper((string) config('app.currency', 'SAR'));

        $walletAccount = WalletAccount::query()->firstOrCreate(
            ['user_id' => $user->id],
            [
                'balance' => 0,
                'currency' => $defaultCurrency,
            ]
        );

        $amount = round((float) $validated['amount'], 2);

        if ($amount > (float) $walletAccount->balance) {
            return redirect()
                ->route('merchant.wallet.index', ['tab' => 'request'])
                ->withErrors(['amount' => __('merchant_wallet.messages.insufficient')])
                ->withInput();
        }

        $idempotencyKey = sprintf('wallet:withdrawal-request:%d:%s', $user->id, Str::uuid()->toString());

        $transactionMeta = [
            'context' => 'wallet_withdrawal_request',
            'withdrawal_request_reference' => $idempotencyKey,
            'withdrawal_method' => $methodKey,
        ];

        if (! empty($validated['notes'])) {
            $transactionMeta['withdrawal_notes'] = $validated['notes'];
        }

        if ($withdrawalMeta !== null) {
            $transactionMeta['withdrawal_meta'] = $withdrawalMeta;
        }

        try {
            $transaction = $walletService->debit($user, $idempotencyKey, $amount, [
                'meta' => $transactionMeta,
            ]);
        } catch (Throwable $th) {
            report($th);

            return redirect()
                ->route('merchant.wallet.index', ['tab' => 'request'])
                ->withErrors(['amount' => __('merchant_wallet.messages.error')])
                ->withInput();
        }

        WalletWithdrawalRequest::create([
            'wallet_account_id' => $walletAccount->getKey(),
            'wallet_transaction_id' => $transaction->getKey(),
            'status' => WalletWithdrawalRequest::STATUS_PENDING,
            'amount' => $amount,
            'preferred_method' => $methodKey,
            'wallet_reference' => $idempotencyKey,
            'notes' => $validated['notes'] ?? null,
            'meta' => $withdrawalMeta,
        ]);

        return redirect()
            ->route('merchant.wallet.index', ['tab' => 'request'])
            ->with('success', __('merchant_wallet.messages.success'));
    }

    private function buildWalletContext(Request $request): array
    {
        $user = $request->user();
        $defaultCurrency = strtoupper((string) config('app.currency', 'SAR'));

        $walletAccount = WalletAccount::query()->firstOrCreate(
            ['user_id' => $user->id],
            [
                'balance' => 0,
                'currency' => $defaultCurrency,
            ]
        );

        $currency = strtoupper((string) ($walletAccount->currency ?? $defaultCurrency));

        $transactions = $walletAccount->transactions()
            ->with([
                'manualPaymentRequest',
                'paymentTransaction.walletTransaction',
            ])
            ->latest('created_at')
            ->limit(10)
            ->get();

        $withdrawals = $walletAccount->withdrawalRequests()
            ->latest('created_at')
            ->limit(5)
            ->get();

        return [
            'account' => $walletAccount,
            'currency' => $currency,
            'balance' => (float) $walletAccount->balance,
            'transactions' => $transactions,
            'withdrawals' => $withdrawals,
            'methods' => $this->getWalletWithdrawalMethods(),
            'minimum_amount' => max(0.01, (float) config('wallet.withdrawals.minimum_amount', 1)),
        ];
    }

    protected function getWalletWithdrawalMethods(): array
    {
        $configuredMethods = config('wallet.withdrawals.methods', []);

        $methods = [];

        foreach ($configuredMethods as $method) {
            $key = (string) ($method['key'] ?? '');

            if ($key === '') {
                continue;
            }

            $methods[$key] = [
                'key' => $key,
                'name' => __($method['name'] ?? Str::headline(str_replace('_', ' ', $key))),
                'description' => $method['description'] ?? null,
                'fields' => $this->normalizeWithdrawalMethodFields($method['fields'] ?? []),
            ];
        }

        return $methods;
    }

    /**
     * @param array<int, array<string, mixed>> $fields
     * @return array<int, array{key: string, label: string, required: bool, rules: array<int, string>}>
     */
    private function normalizeWithdrawalMethodFields(array $fields): array
    {
        $normalized = [];

        foreach ($fields as $field) {
            $key = (string) ($field['key'] ?? '');

            if ($key === '') {
                continue;
            }

            $rules = $field['rules'] ?? [];

            if (empty($rules)) {
                $rules = $field['required'] ?? false ? ['required'] : [];
            }

            $normalized[] = [
                'key' => $key,
                'label' => __($field['label'] ?? Str::headline(str_replace('_', ' ', $key))),
                'required' => (bool) ($field['required'] ?? false),
                'rules' => $rules,
            ];
        }

        return $normalized;
    }

    private function validateWithdrawalMetaFromRequest(Request $request, array $method): ?array
    {
        $fields = $method['fields'] ?? [];

        if (empty($fields)) {
            return null;
        }

        $metaRules = [];
        $attributeNames = [];

        foreach ($fields as $field) {
            $fieldKey = $field['key'];
            $rules = $field['rules'] ?? [];

            if (empty($rules)) {
                $rules = $field['required'] ? ['required'] : [];
            }

            $metaRules[$fieldKey] = $rules;
            $attributeNames[$fieldKey] = $field['label'] ?? Str::headline(str_replace('_', ' ', $fieldKey));
        }

        $metaData = $request->input('meta', []);

        if (! is_array($metaData)) {
            $metaData = [];
        }

        $validator = Validator::make($metaData, $metaRules, [], $attributeNames);

        $validator->validate();

        $validatedMeta = $validator->validated();

        $sanitizedMeta = [];

        foreach ($fields as $field) {
            $fieldKey = $field['key'];

            if (array_key_exists($fieldKey, $validatedMeta)) {
                $sanitizedMeta[$fieldKey] = $validatedMeta[$fieldKey];
            }
        }

        return $sanitizedMeta === [] ? null : $sanitizedMeta;
    }
}
