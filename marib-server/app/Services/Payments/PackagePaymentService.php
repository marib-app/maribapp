<?php

namespace App\Services\Payments;

use App\Models\Package;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\PaymentFulfillmentService;
use App\Services\WalletService;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use RuntimeException;

class PackagePaymentService
{
    public function __construct(
        private readonly DatabaseManager $db,
        private readonly WalletService $walletService,
        private readonly PaymentFulfillmentService $fulfillmentService
    ) {
    }

    /**
     * @param array<string, mixed> $data
     */
    public function initiate(User $user, Package $package, string $method, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        $method = strtolower($method);
        $this->assertSupportedMethod($method);

        return $this->db->transaction(function () use ($user, $package, $method, $idempotencyKey, $data) {
            $existing = PaymentTransaction::query()
                ->where('user_id', $user->getKey())
                ->where('payment_gateway', $method)
                ->where('idempotency_key', $idempotencyKey)
                ->lockForUpdate()
                ->first();

            if ($existing) {
                if ($existing->payable_type !== Package::class || (int) $existing->payable_id !== $package->getKey()) {
                    throw ValidationException::withMessages([
                        'idempotency' => __('المعاملة المرتبطة بالمفتاح المرسل تتعلق بعملية مختلفة.'),
                    ]);
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
        });
    }

    /**
     * @param array<string, mixed> $data
     */
    public function confirm(User $user, PaymentTransaction $transaction, string $idempotencyKey, array $data = []): PaymentTransaction
    {
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

        $method = strtolower((string) ($transaction->payment_gateway ?? $data['payment_method'] ?? ''));
        $this->assertSupportedMethod($method);

        $options = [
            'payment_gateway' => $method,
            'payment_reference' => $data['reference'] ?? null,
            'meta' => $this->buildMetaForConfirmation($transaction, $data),
        ];

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
        $transaction = $this->initiate($user, $package, 'manual', $idempotencyKey, $data);

        $transaction->meta = array_replace_recursive($transaction->meta ?? [], [
            'manual' => Arr::only($data, ['note', 'reference', 'attachments']),
        ]);

        if (!empty($data['reference'])) {
            $transaction->payment_id = $data['reference'];
        }

        $transaction->payment_status = Arr::get($data, 'auto_confirm') ? 'succeed' : 'pending';
        $transaction->save();

        if (Arr::get($data, 'auto_confirm')) {
            return $this->confirm($user, $transaction->fresh(), $idempotencyKey, $data);
        }

        return $transaction->fresh();
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
            return $this->walletService->debit($user, $idempotencyKey, $amount, array_merge($options, [
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

    private function assertSupportedMethod(string $method): void
    {
        if (!in_array($method, ['wallet', 'manual'], true)) {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع المحددة غير مدعومة لهذه العملية.'),
            ]);
        }
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