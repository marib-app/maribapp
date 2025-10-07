<?php

namespace App\Services\Payments;

use App\Models\Order;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Services\PaymentFulfillmentService;
use App\Services\WalletService;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use App\Services\Payments\TransactionAmountResolver;

use RuntimeException;

class OrderPaymentService
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
    public function initiate(User $user, Order $order, string $method, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        $method = strtolower($method);
        $this->assertSupportedMethod($method);

        return $this->db->transaction(function () use ($user, $order, $method, $idempotencyKey, $data) {
            $existing = PaymentTransaction::query()
                ->where('user_id', $user->getKey())
                ->where('payment_gateway', $method)
                ->where('idempotency_key', $idempotencyKey)
                ->first();

            if ($existing) {
                if ((int) $existing->payable_id !== $order->getKey()) {
                    throw ValidationException::withMessages([
                        'idempotency' => __('المعاملة المرتبطة بالمفتاح المرسل تتعلق بطلب مختلف.'),
                    ]);
                }

                return $existing;
            }

            $overallDue = $this->resolveOverallDue($order);
            $depositDue = $this->resolveDepositOutstanding($order);
            $dueAmount = $this->resolveAmountDue($order, $overallDue, $depositDue);            $requestedAmount = isset($data['amount']) ? (float) $data['amount'] : null;

            if ($requestedAmount !== null && $requestedAmount > 0) {
                $amount = min($overallDue, round($requestedAmount, 2));
            } else {
                $amount = $dueAmount;
            }

            if ($amount <= 0) {
                throw ValidationException::withMessages([
                    'amount' => __('لا يوجد رصيد مستحق على هذا الطلب.'),
                ]);
            }


            $orderCurrency = $this->resolveOrderCurrency($order);
            $transactionCurrency = strtoupper((string) ($data['currency'] ?? $orderCurrency));

            if ($method === 'wallet') {
                $transactionCurrency = $this->assertWalletCurrencyCompatibility($user, $order, $transactionCurrency, true);
            }

            $data['currency'] = $transactionCurrency;


            $meta = $this->buildTransactionMeta('initiated', $data);
            $meta = $this->mergeCurrencyMeta($meta, $order, $method, $amount, $data);


            return PaymentTransaction::create([
                'user_id' => $user->getKey(),
                'amount' => $amount,
                'currency' => $transactionCurrency,
                'payment_gateway' => $method,
                'order_id' => $order->order_number,
                'payment_status' => 'pending',
                'payable_type' => Order::class,
                'payable_id' => $order->getKey(),
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

        if ($transaction->payable_type !== Order::class) {
            throw ValidationException::withMessages([
                'transaction' => __('لا يمكن تأكيد هذه المعاملة للنوع المحدد.'),
            ]);
        }

        /** @var Order|null $order */
        $order = $transaction->payable instanceof Order
            ? $transaction->payable
            : Order::find($transaction->payable_id);

        if (! $order) {
            throw ValidationException::withMessages([
                'transaction' => __('تعذر العثور على الطلب المرتبط بالمعاملة.'),
            ]);
        }

        $method = strtolower((string) $transaction->payment_gateway);
        $this->assertSupportedMethod($method);

        $options = [
            'payment_gateway' => $method,
            'order_payment_method' => $method,
            'meta' => $this->mergeTransactionMeta($transaction, $data, $idempotencyKey),
            'payment_reference' => $data['reference'] ?? null,
        ];

        if ($method === 'wallet') {
            $transactionCurrency = strtoupper((string) ($transaction->currency ?? $this->resolveOrderCurrency($order)));
            $this->assertWalletCurrencyCompatibility($user, $order, $transactionCurrency, false);
            $dataWithCurrency = $data;
            $dataWithCurrency['currency'] = $transactionCurrency;
            $walletTransaction = $this->debitWallet($user, $transaction, $idempotencyKey, $dataWithCurrency);


            $options['wallet_transaction'] = $walletTransaction;
        }

        $result = $this->fulfillmentService->fulfill(
            $transaction,
            Order::class,
            $order->getKey(),
            $user->getKey(),
            $options
        );

        if ($result['error'] ?? true) {
            Log::warning('order_payment.confirm_failed', [
                'transaction_id' => $transaction->getKey(),
                'message' => $result['message'] ?? null,
            ]);

            throw ValidationException::withMessages([
                'payment' => __('تعذر إكمال عملية الدفع حالياً.'),
            ]);
        }

        if (! empty($options['payment_reference'])) {
            $transaction->payment_id = $options['payment_reference'];
        }

        $transaction->payment_status = 'succeed';
        $transaction->meta = $options['meta'];
        $transaction->save();

        $order->refresh();

        return $transaction->fresh();
    }

    /**
     * @param array<string, mixed> $data
     */
    public function createManual(User $user, Order $order, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        $transaction = $this->initiate($user, $order, 'manual', $idempotencyKey, $data);

        $transaction->meta = array_replace_recursive($transaction->meta ?? [], [
            'manual' => Arr::only($data, ['note', 'reference', 'attachments']),
        ]);
        $transaction->payment_status = Arr::get($data, 'auto_confirm') ? 'succeed' : 'pending';
        $transaction->payment_id = $data['reference'] ?? $transaction->payment_id;
        $transaction->save();

        if (Arr::get($data, 'auto_confirm')) {
            $this->confirm($user, $transaction, $idempotencyKey, $data);
        }

        return $transaction->fresh();
    }

    private function resolveAmountDue(Order $order, ?float $overallDue = null, ?float $depositDue = null): float    {



        $overallDue ??= $this->resolveOverallDue($order);
        $depositDue ??= $this->resolveDepositOutstanding($order);

        if ($depositDue > 0.0 && ($overallDue <= 0.0 || $depositDue < $overallDue)) {
            return $depositDue;
        }

        return $overallDue;
    }

    private function resolveOverallDue(Order $order): float
    {


        $onlinePayable = $this->resolveOnlinePayable($order);

        if ($onlinePayable !== null) {
            return max(round($onlinePayable, 2), 0.0);
        }
        $orderCurrency = $this->resolveOrderCurrency($order);

        $paid = $order->paymentTransactions()
            ->where('payment_status', 'succeed')
            ->get(['amount', 'currency', 'meta'])
            ->sum(static fn (PaymentTransaction $transaction) => TransactionAmountResolver::resolveForOrder($transaction, $orderCurrency));

        return max(round((float) $order->final_amount - (float) $paid, 2), 0.0);
    }



    private function resolveDepositOutstanding(Order $order): float
    {
        $payloadRemaining = Arr::get($order->payment_payload, 'deposit.remaining_amount');

        if ($payloadRemaining !== null) {
            return max(round((float) $payloadRemaining, 2), 0.0);
        }

        $remaining = $order->deposit_remaining_balance;

        if ($remaining !== null) {
            return max(round((float) $remaining, 2), 0.0);
        }

        return 0.0;
    }


    private function resolveOnlinePayable(Order $order): ?float
    {
        $payloadOnline = data_get($order->payment_payload, 'delivery_payment.online_payable');

        if ($payloadOnline !== null) {
            return (float) $payloadOnline;
        }

        if ($order->delivery_online_payable !== null) {
            return (float) $order->delivery_online_payable;
        }

        return null;
    }

    private function assertSupportedMethod(string $method): void
    {
        if (! in_array($method, ['wallet', 'bank_alsharq', 'manual'], true)) {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع غير مدعومة.'),
            ]);
        }
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function buildTransactionMeta(string $status, array $payload): array
    {
        return [
            'status' => $status,
            'payload' => $payload,
            'timestamps' => [
                $status => now()->toIso8601String(),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $data
     */
    private function mergeTransactionMeta(PaymentTransaction $transaction, array $data, string $idempotencyKey): array
    {
        $meta = $transaction->meta ?? [];
        $meta['status'] = 'confirmed';
        $meta['payload'] = array_replace_recursive($meta['payload'] ?? [], $data);
        $meta['timestamps'] = array_replace($meta['timestamps'] ?? [], [
            'confirmed' => now()->toIso8601String(),
        ]);
        $meta['confirmation_idempotency_key'] = $idempotencyKey;

        return $meta;
    }

    /**
     * @param array<string, mixed> $data
     */
    private function debitWallet(User $user, PaymentTransaction $transaction, string $idempotencyKey, array $data = [])
    {
        try {

            $currency = strtoupper((string) ($data['currency'] ?? $transaction->currency ?? config('app.currency', 'SAR')));


            return $this->walletService->debit($user, $idempotencyKey, (float) $transaction->amount, [
                'payment_transaction' => $transaction,
                'meta' => array_merge($transaction->meta ?? [], [
                    'order_id' => $transaction->payable_id,
                ]),
                'currency' => $currency,


            ]);
        } catch (RuntimeException $exception) {
            throw ValidationException::withMessages([
                'payment' => $exception->getMessage(),
            ]);
        }
    }


    private function mergeCurrencyMeta(array $meta, Order $order, string $method, float $amount, array $data): array
    {
        if ($method === 'wallet') {
            return $meta;
        }

        $orderCurrency = $this->resolveOrderCurrency($order);
        $paymentCurrency = strtoupper((string) ($data['currency'] ?? $orderCurrency));
        $exchangeRate = isset($data['exchange_rate']) ? (float) $data['exchange_rate'] : null;
        $conversionDifference = isset($data['conversion_difference']) ? (float) $data['conversion_difference'] : null;
        $convertedAmount = isset($data['converted_amount'])
            ? (float) $data['converted_amount']
            : ($paymentCurrency === $orderCurrency ? $amount : null);

        $meta['order_currency'] = $orderCurrency;
        $meta['payment_currency'] = $paymentCurrency;

        if ($exchangeRate !== null) {
            $meta['exchange_rate'] = $exchangeRate;
        }

        if ($conversionDifference !== null) {
            $meta['conversion_difference'] = $conversionDifference;
        }

        if ($convertedAmount !== null) {
            $meta['converted_amount'] = $convertedAmount;
        } else {
            unset($meta['converted_amount']);
        }

        return $meta;
    }

    private function assertWalletCurrencyCompatibility(User $user, Order $order, string $requestedCurrency, bool $allowAccountCreation): string

    {
        $currency = strtoupper($requestedCurrency);
        $orderCurrency = $this->resolveOrderCurrency($order);

        if ($currency !== $orderCurrency) {
            throw ValidationException::withMessages([
                'currency' => __('لا يمكن الدفع بالمحفظة بعملة تختلف عن الطلب.'),
            ]);
        }

        $hasMatchingAccount = $this->walletService->hasAccount($user, $currency);
        $hasAnyAccount = $this->walletService->hasAccount($user);

        if (! $hasMatchingAccount) {
            if ($hasAnyAccount || ! $allowAccountCreation) {
                throw ValidationException::withMessages([
                    'currency' => __('لا تملك المحفظة حساباً بهذه العملة.'),
                ]);
            }
        }

        return $currency;

    }

    private function resolveOrderCurrency(Order $order): string
    {
        $orderCurrency = $order->currency_code ?? $order->currency ?? null;

        return strtoupper((string) ($orderCurrency ?: config('app.currency', 'SAR')));
    }



}