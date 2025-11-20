<?php

namespace App\Services\Payments;


use App\Services\Payments\Concerns\HandlesManualBankConfirmation;
use App\Services\Payments\CreateOrLinkManualPaymentRequest;
use App\Models\Package;
use App\Services\OrderCheckoutService;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\PaymentFulfillmentService;
use App\Services\WalletService;
use App\Services\Payments\ManualPaymentRequestService;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Arr;
use App\Support\InputSanitizer;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use RuntimeException;

class PackagePaymentService
{
    use HandlesManualBankConfirmation;

    /**
     * @var array<int, string>
     */
    private const SUPPORTED_METHODS = ['manual_bank', 'wallet'];

    /**
     * @return array<int, string>
     */
    public static function supportedMethods(): array
    {
        return array_values(array_unique(self::SUPPORTED_METHODS));
    }

    /**
     * @var array<string, array<int, string>>
     */
    private const LEGACY_METHOD_ALIASES = [
        'manual_bank' => ['manual'],
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
     * @param array<string, mixed> $data
     */
    public function initiate(User $user, Package $package, string $method, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        // sanitize client input: strip any *_number fields
        $data = InputSanitizer::stripNumberFields($data);

        $method = $this->normalizePaymentMethod($method);


        $data['payment_method'] = $method;

        return $this->db->transaction(function () use ($user, $package, $method, $idempotencyKey, $data) {
            return $this->findOrCreateTransaction($user, $package, $method, $idempotencyKey, $data);


        });
    }

    /**
     * @param array<string, mixed> $data
     */
    public function confirm(User $user, PaymentTransaction $transaction, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        // sanitize client input: strip any *_number fields
        $data = InputSanitizer::stripNumberFields($data);

        if ($transaction->payment_status === 'succeed') {
            return $transaction;
        }

        if ((int) $transaction->user_id !== $user->getKey()) {
            throw ValidationException::withMessages([
                'transaction' => __('المعاملة المحددة لا تخص المستخدم.'),
            ]);
        }

        if ($transaction->payable_type !== Package::class) {
            throw ValidationException::withMessages([
                'transaction' => __('لا يمكن تأكيد هذه المعاملة للنوع المحدد.'),
            ]);
        }

        $package = Package::findOrFail($transaction->payable_id);

        $rawMethod = Arr::get($data, 'payment_method', $transaction->payment_gateway);

        if (! is_string($rawMethod) || $rawMethod === '') {
            $rawMethod = $transaction->payment_gateway;
        }


        $method = $this->normalizePaymentMethod(is_string($rawMethod) ? $rawMethod : null);


        if ($transaction->payment_gateway !== $method) {
            $transaction->payment_gateway = $method;
            $transaction->save();
        }

        $data['payment_method'] = $method;

        $manualContext = null;

        if ($method === 'manual_bank') {
            $manualContext = $this->prepareManualBankConfirmationPayload(
                $user,
                $transaction,
                Package::class,
                $package->getKey(),
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
            'meta' => $this->buildMetaForConfirmation($transaction, $data),
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
            $walletTransaction = $this->debitWallet($user, $transaction, $idempotencyKey, (float) $transaction->amount, [
                'currency' => strtoupper((string) ($transaction->currency ?? config('app.currency', 'SAR'))),
                'meta' => [
                    'context' => 'package_purchase',
                    'package_id' => $package->getKey(),
                ],
            ]);

            $options['wallet_transaction'] = $walletTransaction;
            $options['meta']['wallet'] = array_replace_recursive($options['meta']['wallet'] ?? [], [
                'transaction_id' => $walletTransaction->getKey(),
                'idempotency_key' => $walletTransaction->idempotency_key,
            ]);
        }

        $result = $this->fulfillmentService->fulfill(
            $transaction,
            Package::class,
            $package->getKey(),
            $user->getKey(),
            $options
        );

        if ($result['error'] ?? true) {
            Log::warning('package_payment.confirm_failed', [
                'transaction_id' => $transaction->getKey(),
                'message' => $result['message'] ?? null,
            ]);

            throw ValidationException::withMessages([
                'payment' => __('تعذر إكمال عملية الدفع حالياً.'),
            ]);
        }

        return $transaction->fresh();
    }

    /**
     * @param array<string, mixed> $data
     */
    public function createManual(User $user, Package $package, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        // sanitize client input: strip any *_number fields
        $data = InputSanitizer::stripNumberFields($data);

        return $this->db->transaction(function () use ($user, $package, $idempotencyKey, $data) {
            $method = 'manual_bank';
            $data['payment_method'] = $method;
            $transaction = $this->findOrCreateTransaction($user, $package, $method, $idempotencyKey, $data);
            $transactionCurrency = (string) ($transaction->currency ?? Arr::get($data, 'currency'));


            $rawBankName = Arr::get($data, 'bank.name');
            if (! is_string($rawBankName) || trim($rawBankName) === '') {
                $rawBankName = Arr::get($data, 'bank_name');
            }

            $bankName = is_string($rawBankName) ? trim($rawBankName) : null;
            if ($bankName === '') {
                $bankName = null;
            }

            $manualPaymentRequest = $transaction->manualPaymentRequest;
            $manualBankIdentifier = Arr::get($data, 'manual_bank_id') ?? Arr::get($data, 'bank_id');
            if ($bankName !== null) {
                data_set($data, 'bank.name', $bankName);


            }

            $manualPaymentRequest = $this->manualPaymentLinker->handle(
                $user,
                Package::class,
                $package->getKey(),
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
                'id' => $manualBankIdentifier ?? null,
                'account_id' => $data['bank_account_id'] ?? null,
                'name' => $bankName,
            ], static fn ($value) => $value !== null && $value !== '');

            if ($manualMeta['bank'] === []) {
                unset($manualMeta['bank']);
            }


            $metadata = Arr::get($data, 'metadata');
            if (is_array($metadata) && ! empty($metadata)) {
                $manualMeta['metadata'] = $metadata;
            }

            $manualMeta['idempotency_key'] = $transaction->idempotency_key ?? $idempotencyKey;


            $transaction->payment_status = Arr::get($data, 'auto_confirm') ? 'succeed' : 'pending';
            $transaction->payment_id = $data['reference'] ?? $transaction->payment_id;
            $meta = $transaction->meta ?? [];
            if (! is_array($meta)) {
                $meta = [];
            }

            $manualBankIdForPayload = $manualBankIdentifier ?? $manualPaymentRequest->manual_bank_id;
            if (is_string($manualBankIdForPayload) && trim($manualBankIdForPayload) === '') {
                $manualBankIdForPayload = null;
            }

            if ($manualBankIdForPayload !== null && $manualBankIdForPayload !== '') {
                $normalizedBankId = is_numeric($manualBankIdForPayload) ? (int) $manualBankIdForPayload : null;

                if ($normalizedBankId !== null && $normalizedBankId > 0) {
                    data_set($meta, 'payload.manual_bank_id', $normalizedBankId);
                }
            }

            if (is_string($bankName) && trim($bankName) !== '') {
                data_set($meta, 'payload.bank_name', trim($bankName));
            }

            $transaction->meta = array_replace_recursive($meta, [
                
                'manual' => $manualMeta,
                'manual_payment_request' => [
                    'id' => $manualPaymentRequest->getKey(),
                    'status' => $manualPaymentRequest->status,
                ],
            ]);
            $transaction->save();



            $transaction->setRelation('manualPaymentRequest', $manualPaymentRequest->fresh(['manualBank']));


            if (Arr::get($data, 'auto_confirm')) {
                $dataWithManualRequest = $data;
                $dataWithManualRequest['manual_payment_request_id'] = $manualPaymentRequest->getKey();

                return $this->confirm($user, $transaction->fresh(), $idempotencyKey, $dataWithManualRequest);
            }

            return $transaction->fresh();
        });
    
    }

    /**
     * @param array<string, mixed> $data
     */
    private function resolveAmount(Package $package, array $data): float
    {
        $defaultAmount = (float) ($package->final_price ?? $package->price ?? 0);
        $requestedAmount = isset($data['amount']) ? (float) $data['amount'] : null;

        if ($requestedAmount !== null && $requestedAmount > 0) {
            $amount = $defaultAmount > 0 ? min($defaultAmount, $requestedAmount) : $requestedAmount;
        } else {
            $amount = $defaultAmount;
        }

        $amount = round($amount, 2);

        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => __('لا يوجد رصيد مستحق لهذه الحزمة.'),
            ]);
        }

        return $amount;
    }

    /**
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function buildMetaForConfirmation(PaymentTransaction $transaction, array $data): array
    {
        $meta = $transaction->meta ?? [];

        if (!empty($data['reference'])) {
            $meta['payment_reference'] = $data['reference'];
        }

        if (!empty($data['note'])) {
            $meta['manual'] = array_replace_recursive($meta['manual'] ?? [], [
                'note' => $data['note'],
            ]);
        }

        return array_replace_recursive($meta, [
            'purpose' => 'package',
        ]);
    }

    /**
     * @param array<string, mixed> $options
     */
    private function debitWallet(User $user, PaymentTransaction $transaction, string $idempotencyKey, float $amount, array $options = []): WalletTransaction
    {
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
                    Log::notice('package_payment.wallet_idempotency_mismatch', [
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


    private function normalizePaymentMethod(?string $method): string
    {
        $normalizedMethod = OrderCheckoutService::normalizePaymentMethod($method);

        if (! is_string($normalizedMethod) || $normalizedMethod === '') {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع المحددة غير مدعومة لهذه العملية.'),
            ]);
        }

        $canonicalMethod = $this->canonicalizePaymentMethod($normalizedMethod);

        $this->assertSupportedMethod($canonicalMethod);

        return $canonicalMethod;
    }

    private function canonicalizePaymentMethod(string $method): string
    {
        $canonical = OrderCheckoutService::normalizePaymentMethod($method);

        if (! is_string($canonical) || $canonical === '') {
            return $method;
        }

        return $canonical;
    }

    /**
     * @return array<int, string>
     */
    private function expandLegacyMethods(string $method): array
    {
        return array_values(array_unique(array_merge([
            $method,
        ], self::LEGACY_METHOD_ALIASES[$method] ?? [])));
    }



    private function assertSupportedMethod(string $method): void
    {
        if (! in_array($method, self::SUPPORTED_METHODS, true)) {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع المحددة غير مدعومة لهذه العملية.'),
            ]);
        }
    }


    /**
     * @param array<string, mixed> $data
     */
    private function findOrCreateTransaction(
        User $user,
        Package $package,
        string $method,
        string $idempotencyKey,
        array $data = []
    ): PaymentTransaction {
        $method = $this->canonicalizePaymentMethod($method);
        $data['payment_method'] = $method;
        $existing = PaymentTransaction::query()
            ->where('user_id', $user->getKey())
            ->whereIn('payment_gateway', $this->expandLegacyMethods($method))
            ->where('idempotency_key', $idempotencyKey)
            ->lockForUpdate()
            ->first();

        if ($existing) {
            if ($existing->payable_type !== Package::class || (int) $existing->payable_id !== $package->getKey()) {
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

        $amount = $this->resolveAmount($package, $data);
        $currency = strtoupper((string) ($data['currency'] ?? config('app.currency', 'SAR')));

        $meta = $this->buildBaseMeta($package);

        if (!empty($data['meta']) && is_array($data['meta'])) {
            $meta = array_replace_recursive($meta, $data['meta']);
        }

        if ($method === 'wallet') {
            $meta['wallet'] = array_replace_recursive($meta['wallet'] ?? [], [
                'idempotency_key' => $idempotencyKey,
            ]);
        }

        if (!empty($data['reference'])) {
            $meta['payment_reference'] = $data['reference'];
        }

        return PaymentTransaction::create([
            'user_id' => $user->getKey(),
            'amount' => $amount,
            'currency' => $currency,
            'payment_gateway' => $method,
            'payment_status' => 'pending',
            'payable_type' => Package::class,
            'payable_id' => $package->getKey(),
            'idempotency_key' => $idempotencyKey,
            'meta' => $meta,
        ]);
    }
    
    /**
     * @return array<string, mixed>
     */
    private function buildBaseMeta(Package $package): array
    {
        return [
            'purpose' => 'package',
            'package' => [
                'id' => $package->getKey(),
                'name' => $package->name,
            ],
        ];
    }
}
