<?php

namespace App\Services\Payments;

use App\Enums\Wifi\WifiCodeStatus;
use App\Enums\Wifi\WifiNetworkStatus;
use App\Enums\Wifi\WifiPlanStatus;
use Carbon\Carbon;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Models\WalletAccount;
use App\Models\WalletTransaction;
use App\Models\Wifi\WifiCode;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiPlan;
use App\Services\Payments\CreateOrLinkManualPaymentRequest;
use App\Services\Payments\ManualPaymentRequestService;
use App\Services\Payments\Concerns\HandlesManualBankConfirmation;
use App\Services\PaymentFulfillmentService;
use App\Services\WalletService;
use App\Support\InputSanitizer;
use Illuminate\Database\DatabaseManager;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\QueryException;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use RuntimeException;

class WifiPlanPaymentService
{
    use HandlesManualBankConfirmation;

    /**
     * @var array<int, string>
     */
    private const SUPPORTED_METHODS = ['manual_bank', 'east_yemen_bank', 'wallet'];
    /**
     * @var array<int, string>
     */
    private const ACTIVE_GATEWAY_INDEXES = [
        'payment_transactions_active_gateway_unique',
        'payment_transactions_payable_gateway_active_unique',
    ];
    /**
     * @var array<int, string>
     */
    private const ACTIVE_PAYMENT_STATUSES = ['pending', 'initiated', 'processing'];

    /**
     * @var array<string, array<int, string>>
     */
    private const LEGACY_METHOD_ALIASES = [
        'manual_bank' => ['manual'],
        'east_yemen_bank' => [
            'east',
            'alsharq',
            'al-sharq',
            'bank_alsharq',
        ],
    ];

    public function __construct(
        private readonly DatabaseManager $db,
        private readonly WalletService $walletService,
        private readonly PaymentFulfillmentService $fulfillmentService,
        private readonly ManualPaymentRequestService $manualPaymentRequestService,
        private readonly CreateOrLinkManualPaymentRequest $manualPaymentLinker
    ) {
    }

    /**
     * @return array<int, string>
     */
    public static function supportedMethods(): array
    {
        return self::SUPPORTED_METHODS;
    }

    /**
     * @param array<string, mixed> $data
     */
    public function initiate(User $user, WifiPlan $plan, string $method, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        $data = InputSanitizer::stripNumberFields($data);

        $method = $this->normalizePaymentMethod($method);

        // For WiFi plans we do not support creating manual_bank transactions without a linked manual request.
        // Front-end cabin flow only allows wallet + east_yemen_bank.
        if ($method === 'manual_bank') {
            throw ValidationException::withMessages([
                'payment_method' => __('طھط­ظˆظٹظ„ ط§ظ„ط¨ظ†ظƒ ط§ظ„ظٹط¯ظˆظٹ طºظٹط± ظ…طھط§ط­ ظ‡ط°ط§ ط§ظ„ط®ط·ط©.'),
            ]);
        }

        $data['payment_method'] = $method;

        return $this->db->transaction(function () use ($user, $plan, $method, $idempotencyKey, $data) {
            $this->ensurePlanIsPurchasable($plan);

            return $this->findOrCreateTransaction($user, $plan, $method, $idempotencyKey, $data);
        });
    }

    /**
     * @param array<string, mixed> $data
     * @return array{transaction: PaymentTransaction, delivery?: array<string, mixed>}
     */
    public function confirm(User $user, PaymentTransaction $transaction, string $idempotencyKey, array $data = []): array
    {
        $data = InputSanitizer::stripNumberFields($data);

        if (strtolower((string) $transaction->payment_status) === 'succeed') {
            return ['transaction' => $transaction];
        }

        if ((int) $transaction->user_id !== $user->getKey()) {
            throw ValidationException::withMessages([
                'transaction' => __('المعاملة المحددة لا تخص المستخدم.'),
            ]);
        }

        if ($transaction->payable_type !== WifiPlan::class) {
            throw ValidationException::withMessages([
                'transaction' => __('لا يمكن تأكيد هذه المعاملة للنوع المحدد.'),
            ]);
        }

        $plan = WifiPlan::query()->with('network')->findOrFail($transaction->payable_id);
        $this->ensurePlanIsPurchasable($plan);

        $rawMethod = $data['payment_method'] ?? $transaction->payment_gateway;
        $method = $this->normalizePaymentMethod(is_string($rawMethod) ? $rawMethod : null);

        if ($transaction->payment_gateway !== $method) {
            $transaction->payment_gateway = $method;
            $transaction->save();
        }

        $data['payment_method'] = $method;

        $manualContext = null;

        if (in_array($method, ['manual_bank', 'east_yemen_bank'], true)) {
            $manualContext = $this->prepareManualBankConfirmationPayload(
                $user,
                $transaction,
                WifiPlan::class,
                $plan->getKey(),
                $method,
                $idempotencyKey,
                $data
            );

            if ($manualContext !== null) {
                $data = $manualContext['data'];
            }
        }

        $options = [
            'payment_gateway' => $method,
            'payment_reference' => $data['reference'] ?? null,
            'meta' => $this->buildConfirmationMeta($transaction, $plan, $data),
        ];

        $manualPaymentRequestId = $data['manual_payment_request_id'] ?? $transaction->manual_payment_request_id;

        if ($manualContext !== null) {
            $manualPaymentRequest = $manualContext['manual_payment_request'];

            $options['meta'] = $this->mergeManualConfirmationMeta(
                $options['meta'],
                $data,
                $manualPaymentRequest,
                $transaction,
                $idempotencyKey
            );

            $manualPaymentRequestId = $manualPaymentRequest->getKey();
            $transaction->manual_payment_request_id = $manualPaymentRequestId;
            $transaction->meta = $options['meta'];
            $transaction->save();
        }

        if ($manualPaymentRequestId) {
            $options['manual_payment_request_id'] = $manualPaymentRequestId;
        }

        if ($method === 'wallet') {
            $currency = $this->walletService->getPrimaryCurrency();
            $requiredAmount = (float) ($transaction->amount ?? $plan->price);
            $walletAccount = $this->walletService->findAccount($user, $currency);
            $balance = $walletAccount instanceof WalletAccount ? (float) $walletAccount->balance : 0.0;

            if ($balance + 0.0001 < $requiredAmount) {
                throw ValidationException::withMessages([
                    'wallet' => __('رصيد المحفظة غير كافٍ لإتمام العملية.'),
                ]);
            }

            $walletTransaction = $this->debitWallet(
                $user,
                $transaction,
                $idempotencyKey,
                (float) $transaction->amount,
                [
                    'currency' => $currency,
                    'meta' => [
                        'context' => 'wifi_plan_purchase',
                        'wifi_plan_id' => $plan->getKey(),
                        'wifi_network_id' => $plan->wifi_network_id,
                    ],
                ]
            );

            $options['wallet_transaction'] = $walletTransaction;
            $options['meta']['wallet'] = array_replace_recursive($options['meta']['wallet'] ?? [], [
                'transaction_id' => $walletTransaction->getKey(),
                'idempotency_key' => $walletTransaction->idempotency_key,
            ]);
        }

        $result = $this->fulfillmentService->fulfill(
            $transaction,
            WifiPlan::class,
            $plan->getKey(),
            $user->getKey(),
            $options
        );

        if ($result['error'] ?? true) {
            Log::warning('wifi_plan.payment.confirm_failed', [
                'transaction_id' => $transaction->getKey(),
                'message' => $result['message'] ?? null,
            ]);

            throw ValidationException::withMessages([
                'payment' => __('تعذر إكمال عملية الدفع حالياً.'),
            ]);
        }

        /** @var PaymentTransaction $freshTransaction */
        $freshTransaction = $result['transaction'];

        $payload = ['transaction' => $freshTransaction];

        if (! empty($result['wifi_delivery'])) {
            $payload['delivery'] = $result['wifi_delivery'];
        }

        return $payload;
    }

    /**
     * @param array<string, mixed> $data
     */
    public function createManual(User $user, WifiPlan $plan, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        $data = InputSanitizer::stripNumberFields($data);

        return $this->db->transaction(function () use ($user, $plan, $idempotencyKey, $data) {
            $method = 'manual_bank';
            $data['payment_method'] = $method;

            $this->ensurePlanIsPurchasable($plan);

            $transaction = $this->findOrCreateTransaction($user, $plan, $method, $idempotencyKey, $data);

            $manualPaymentRequest = $this->manualPaymentLinker->handle(
                $user,
                WifiPlan::class,
                $plan->getKey(),
                $transaction,
                $data
            );

            $manualMeta = array_filter(
                Arr::only($data, ['note', 'reference', 'attachments', 'receipt_path']),
                static function ($value) {
                    if (is_array($value)) {
                        return $value !== [];
                    }

                    return $value !== null && $value !== '';
                }
            );

            $manualMeta['bank'] = array_filter([
                'id' => $data['manual_bank_id'] ?? $data['bank_id'] ?? null,
                'account_id' => $data['bank_account_id'] ?? null,
                'name' => $data['bank_name'] ?? Arr::get($data, 'bank.name'),
            ], static fn ($value) => $value !== null && $value !== '');

            if ($manualMeta['bank'] === []) {
                unset($manualMeta['bank']);
            }

            if (isset($data['metadata']) && is_array($data['metadata']) && $data['metadata'] !== []) {
                $manualMeta['metadata'] = $data['metadata'];
            }

            $manualMeta['idempotency_key'] = $transaction->idempotency_key ?? $idempotencyKey;

            $transaction->payment_status = Arr::get($data, 'auto_confirm') ? 'succeed' : 'pending';
            $transaction->payment_id = $data['reference'] ?? $transaction->payment_id;

            $meta = $transaction->meta ?? [];
            if (! is_array($meta)) {
                $meta = [];
            }

            $transaction->meta = array_replace_recursive($meta, [
                'manual' => $manualMeta,
                'manual_payment_request' => [
                    'id' => $manualPaymentRequest->getKey(),
                    'status' => $manualPaymentRequest->status,
                ],
            ]);

            $transaction->manual_payment_request_id = $manualPaymentRequest->getKey();
            $transaction->save();

            $transaction->setRelation('manualPaymentRequest', $manualPaymentRequest->fresh(['manualBank']));

            if (Arr::get($data, 'auto_confirm')) {
                $dataWithManual = $data;
                $dataWithManual['manual_payment_request_id'] = $manualPaymentRequest->getKey();

                $result = $this->confirm($user, $transaction->fresh(), $idempotencyKey, $dataWithManual);

                return $result['transaction'];
            }

            return $transaction;
        });
    }

    protected function normalizePaymentMethod(?string $method): string
    {
        $normalized = $method !== null ? strtolower(trim($method)) : '';

        if ($normalized === '') {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع غير مدعومة.'),
            ]);
        }

        $normalized = $this->canonicalizePaymentMethod($normalized);

        if (! in_array($normalized, self::SUPPORTED_METHODS, true)) {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع غير مدعومة.'),
            ]);
        }

        return $normalized;
    }

    protected function canonicalizePaymentMethod(string $method): string
    {
        foreach (self::LEGACY_METHOD_ALIASES as $canonical => $aliases) {
            if ($method === $canonical || in_array($method, $aliases, true)) {
                return $canonical;
            }
        }

        return $method;
    }

    /**
     * @param array<string, mixed> $data
     */
    protected function findOrCreateTransaction(
        User $user,
        WifiPlan $plan,
        string $method,
        string $idempotencyKey,
        array $data = []
    ): PaymentTransaction {
        $existing = PaymentTransaction::query()
            ->where('user_id', $user->getKey())
            ->whereIn('payment_gateway', $this->expandLegacyMethods($method))
            ->where('idempotency_key', $idempotencyKey)
            ->lockForUpdate()
            ->first();

        if ($existing) {
            if ($existing->payable_type !== WifiPlan::class || (int) $existing->payable_id !== $plan->getKey()) {
                throw ValidationException::withMessages([
                    'idempotency' => __('المعاملة المرتبطة بالمفتاح المرسل تتعلق بعملية مختلفة.'),
                ]);
            }

            if ($existing->payment_gateway !== $method) {
                $existing->payment_gateway = $method;
                $existing->save();
            }

            return $existing;
        }

        $active = $this->activeTransactionQuery($plan, $method)
            ->lockForUpdate()
            ->first();

        if ($active) {
            $dirty = false;

            if ((int) $active->user_id !== $user->getKey()) {
                if ($this->pendingTransactionIsStale($active)) {
                    $this->expirePendingTransaction($active);

                    return $this->findOrCreateTransaction(
                        $user,
                        $plan,
                        $method,
                        $idempotencyKey,
                        $data
                    );
                }

                $dirty = $this->takeOverPendingTransaction($active, $user) || $dirty;
            }

            if ($active->payment_gateway !== $method) {
                $active->payment_gateway = $method;
                $dirty = true;
            }

            if ($active->idempotency_key !== $idempotencyKey) {
                $meta = $active->meta ?? [];
                if ($method === 'wallet') {
                    $meta['wallet'] = array_replace_recursive($meta['wallet'] ?? [], [
                        'idempotency_key' => $idempotencyKey,
                    ]);
                }
                $active->idempotency_key = $idempotencyKey;
                $active->meta = $meta;
                $dirty = true;
            }

            if ($dirty) {
                $active->save();
            }

            return $active->fresh();
        }

        $amount = $this->resolveAmount($plan, $data);
        $currency = strtoupper((string) ($plan->currency ?? $data['currency'] ?? config('app.currency', 'SAR')));

        if ($method === 'wallet') {
            $currency = $this->walletService->getPrimaryCurrency();
        }

        if ($method === 'wallet') {
            $currency = $this->walletService->getPrimaryCurrency();
        }

        $meta = $this->buildBaseMeta($plan);

        if (! empty($data['meta']) && is_array($data['meta'])) {
            $meta = array_replace_recursive($meta, $data['meta']);
        }

        if ($method === 'wallet') {
            $meta['wallet'] = array_replace_recursive($meta['wallet'] ?? [], [
                'idempotency_key' => $idempotencyKey,
            ]);
        }

        if (! empty($data['reference'])) {
            $meta['payment_reference'] = $data['reference'];
        }

        try {
            return PaymentTransaction::create([
                'user_id' => $user->getKey(),
                'amount' => $amount,
                'currency' => $currency,
                'payment_gateway' => $method,
                'payment_status' => 'pending',
                'payable_type' => WifiPlan::class,
                'payable_id' => $plan->getKey(),
                'idempotency_key' => $idempotencyKey,
                'meta' => $meta,
            ]);
        } catch (UniqueConstraintViolationException $exception) {
            if (! $this->isActiveGatewayConstraint($exception)) {
                throw $exception;
            }

            $pending = $this->activeTransactionQuery($plan, $method)
                ->lockForUpdate()
                ->first();

            if (! $pending) {
                throw $exception;
            }

            if ((int) $pending->user_id !== $user->getKey()) {
                if ($this->pendingTransactionIsStale($pending)) {
                    $this->expirePendingTransaction($pending);

                    return $this->findOrCreateTransaction(
                        $user,
                        $plan,
                        $method,
                        $idempotencyKey,
                        $data
                    );
                }

                $this->takeOverPendingTransaction($pending, $user);
            }

            $meta = $pending->meta ?? [];
            if ($method === 'wallet') {
                $meta['wallet'] = array_replace_recursive($meta['wallet'] ?? [], [
                    'idempotency_key' => $idempotencyKey,
                ]);
            }

            $pending->idempotency_key = $idempotencyKey;
            $pending->meta = $meta;
            $pending->amount = $pending->amount ?? $amount;
            $pending->currency = $pending->currency ?? $currency;
            $pending->save();

            return $pending->fresh();
        } catch (QueryException $exception) {
            if ($exception->getCode() === '23000'
                && $this->isActiveGatewayConstraint($exception)) {
                return $this->reusePendingTransaction(
                    $user,
                    $plan,
                    $method,
                    $idempotencyKey,
                    $data,
                    $exception
                );
            }

            throw $exception;
        }
    }

    protected function reusePendingTransaction(
        User $user,
        WifiPlan $plan,
        string $method,
        string $idempotencyKey,
        array $data,
        QueryException $exception
    ): PaymentTransaction {
        $pending = $this->activeTransactionQuery($plan, $method)
            ->lockForUpdate()
            ->first();

        if (! $pending) {
            throw $exception;
        }

        $amount = $this->resolveAmount($plan, $data);
        $currency = strtoupper((string) ($plan->currency ?? $data['currency'] ?? config('app.currency', 'SAR')));

        if ((int) $pending->user_id !== $user->getKey()) {
            if ($this->pendingTransactionIsStale($pending)) {
                $this->expirePendingTransaction($pending);

                return $this->findOrCreateTransaction(
                    $user,
                    $plan,
                    $method,
                    $idempotencyKey,
                    $data
                );
            }

            $this->takeOverPendingTransaction($pending, $user);
        }

        $meta = $pending->meta ?? [];
        if ($method === 'wallet') {
            $meta['wallet'] = array_replace_recursive($meta['wallet'] ?? [], [
                'idempotency_key' => $idempotencyKey,
            ]);
        }

        $pending->idempotency_key = $idempotencyKey;
        $pending->meta = $meta;
        $pending->amount = $pending->amount ?? $amount;
        $pending->currency = $pending->currency ?? $currency;
        $pending->save();

        return $pending->fresh();
    }

    /**
     * @return array<int, string>
     */
    protected function expandLegacyMethods(string $method): array
    {
        $methods = [$method];

        foreach (self::LEGACY_METHOD_ALIASES as $canonical => $aliases) {
            if ($canonical === $method) {
                $methods = array_merge($methods, $aliases);
                break;
            }
        }

        return array_unique($methods);
    }

    protected function activeTransactionQuery(WifiPlan $plan, string $method): Builder
    {
        $query = PaymentTransaction::query()
            ->where('payable_type', WifiPlan::class)
            ->where('payable_id', $plan->getKey())
            ->whereIn('payment_gateway', $this->expandLegacyMethods($method));

        return $this->applyActiveGatewayConstraints($query);
    }

    protected function applyActiveGatewayConstraints(Builder $query): Builder
    {
        return $query->where(function (Builder $constraints): void {
            $constraints->whereIn('payment_status', self::ACTIVE_PAYMENT_STATUSES)
                ->orWhereNull('payment_status')
                ->orWhere('is_active', true);
        });
    }

    /**
     * @param array<string, mixed> $data
     */
    protected function resolveAmount(WifiPlan $plan, array $data = []): float
    {
        $amount = Arr::get($data, 'amount');

        if (is_numeric($amount) && (float) $amount > 0) {
            return round((float) $amount, 4);
        }

        return round((float) $plan->price, 4);
    }

    /**
     * @return array<string, mixed>
     */
    protected function buildBaseMeta(WifiPlan $plan): array
    {
        $network = $plan->relationLoaded('network') ? $plan->getRelation('network') : $plan->network;

        return array_filter([
            'purpose' => 'wifi_plan',
            'wifi_plan' => [
                'id' => $plan->getKey(),
                'name' => $plan->name,
                'price' => (float) $plan->price,
                'currency' => $plan->currency,
            ],
            'wifi_network' => $network instanceof WifiNetwork ? [
                'id' => $network->getKey(),
                'name' => $network->name,
            ] : null,
        ]);
    }

    protected function pendingTransactionIsStale(PaymentTransaction $transaction): bool
    {
        $lastTouched = $transaction->updated_at ?? $transaction->created_at;

        if ($lastTouched instanceof Carbon) {
            $timestamp = $lastTouched;
        } elseif (is_string($lastTouched) && trim($lastTouched) !== '') {
            try {
                $timestamp = Carbon::parse($lastTouched);
            } catch (\Throwable) {
                return false;
            }
        } else {
            return false;
        }

        return $timestamp->lessThan(Carbon::now()->subMinutes(3));
    }

    protected function expirePendingTransaction(PaymentTransaction $transaction): void
    {
        $transaction->payment_status = 'expired';
        $transaction->is_active = false;
        $transaction->save();
    }

    protected function takeOverPendingTransaction(PaymentTransaction $transaction, User $user): bool
    {
        $changed = false;

        if ((int) $transaction->user_id !== $user->getKey()) {
            $transaction->user_id = $user->getKey();
            $changed = true;
        }

        if ((bool) $transaction->is_active !== true) {
            $transaction->is_active = true;
            $changed = true;
        }

        if ($transaction->manual_payment_request_id !== null) {
            $transaction->manual_payment_request_id = null;
            $changed = true;
        }

        if ($transaction->relationLoaded('manualPaymentRequest')) {
            $transaction->unsetRelation('manualPaymentRequest');
        }

        $meta = $transaction->meta ?? [];
        if (! is_array($meta)) {
            $meta = [];
        }

        if (array_key_exists('manual', $meta)) {
            unset($meta['manual']);
            $transaction->meta = $meta;
            $changed = true;
        }

        return $changed;
    }

    protected function isActiveGatewayConstraint(\Throwable $exception): bool
    {
        $message = $exception->getMessage();

        foreach (self::ACTIVE_GATEWAY_INDEXES as $index) {
            if ($message !== '' && str_contains($message, $index)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    protected function buildConfirmationMeta(PaymentTransaction $transaction, WifiPlan $plan, array $data): array
    {
        $meta = $transaction->meta ?? [];
        if (! is_array($meta)) {
            $meta = [];
        }

        $meta = array_replace_recursive($meta, $this->buildBaseMeta($plan));

        if (! empty($data['note'])) {
            $meta['manual'] = array_replace_recursive($meta['manual'] ?? [], [
                'note' => $data['note'],
            ]);
        }

        if (! empty($data['reference'])) {
            $meta['payment_reference'] = $data['reference'];
        }

        return $meta;
    }

    protected function ensurePlanIsPurchasable(WifiPlan $plan): void
    {
        $plan->loadMissing('network');

        if (! $plan->network instanceof WifiNetwork) {
            throw ValidationException::withMessages([
                'plan' => __('تعذر العثور على الشبكة المرتبطة بالخطة.'),
            ]);
        }

        if ($plan->network->status !== WifiNetworkStatus::ACTIVE) {
            throw ValidationException::withMessages([
                'plan' => __('الشبكة غير متاحة حالياً للشراء.'),
            ]);
        }

        if ($plan->status !== WifiPlanStatus::ACTIVE && $plan->status !== WifiPlanStatus::VALIDATED) {
            throw ValidationException::withMessages([
                'plan' => __('الخطة غير متاحة حالياً للشراء.'),
            ]);
        }

        $hasCodes = WifiCode::query()
            ->where('wifi_plan_id', $plan->getKey())
            ->where('status', WifiCodeStatus::AVAILABLE->value)
            ->exists();

        if (! $hasCodes) {
            throw ValidationException::withMessages([
                'plan' => __('لا توجد أكواد متاحة لهذه الفئة حالياً.'),
            ]);
        }
    }

    /**
     * @param array<string, mixed> $options
     */
    private function debitWallet(
        User $user,
        PaymentTransaction $transaction,
        string $idempotencyKey,
        float $amount,
        array $options = []
    ): WalletTransaction {
        $walletTransactionId = Arr::get($transaction->meta, 'wallet.transaction_id');

        if ($walletTransactionId) {
            $existing = WalletTransaction::query()
                ->whereKey($walletTransactionId)
                ->lockForUpdate()
                ->first();

            if ($existing) {
                return $existing;
            }
        }

        try {
            $existingIdempotency = is_string($transaction->idempotency_key)
                ? trim($transaction->idempotency_key)
                : '';
            $normalizedIdempotencyKey = trim($idempotencyKey);

            if ($existingIdempotency === '' && $normalizedIdempotencyKey !== '') {
                $transaction->idempotency_key = $normalizedIdempotencyKey;
                $transaction->saveQuietly();
                $walletIdempotencyKey = $normalizedIdempotencyKey;
            } else {
                if ($existingIdempotency !== '' && $normalizedIdempotencyKey !== '' && $existingIdempotency !== $normalizedIdempotencyKey) {
                    Log::notice('wifi_plan.wallet_idempotency_mismatch', [
                        'transaction_id' => $transaction->getKey(),
                        'stored_idempotency_key' => $existingIdempotency,
                        'incoming_idempotency_key' => $normalizedIdempotencyKey,
                    ]);
                }

                $walletIdempotencyKey = $existingIdempotency !== ''
                    ? $existingIdempotency
                    : $normalizedIdempotencyKey;
            }

            return $this->walletService->debit($user, $walletIdempotencyKey, $amount, array_merge($options, [
                'payment_transaction' => $transaction,
            ]));
        } catch (RuntimeException $exception) {
            $normalizedMessage = mb_strtolower($exception->getMessage());

            if (str_contains($normalizedMessage, 'insufficient wallet balance')) {
                throw ValidationException::withMessages([
                    'wallet' => __('الرصيد في المحفظة غير كافٍ لإتمام العملية.'),
                ]);
            }

            $walletTransaction = WalletTransaction::query()
                ->where('idempotency_key', $idempotencyKey)
                ->whereHas('account', static function ($query) use ($user) {
                    $query->where('user_id', $user->getKey());
                })
                ->lockForUpdate()
                ->first();

            if ($walletTransaction) {
                return $walletTransaction;
            }

            throw $exception;
        }
    }
}
