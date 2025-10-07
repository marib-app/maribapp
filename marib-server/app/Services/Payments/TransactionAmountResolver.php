<?php

namespace App\Services\Payments;

use App\Models\PaymentTransaction;

class TransactionAmountResolver
{
    public static function resolveForOrder(PaymentTransaction $transaction, string $orderCurrency): float
    {
        $orderCurrency = strtoupper($orderCurrency);
        $meta = $transaction->meta ?? [];
        $transactionCurrency = strtoupper((string) ($transaction->currency ?? ''));

        $metaOrderCurrency = strtoupper((string) ($meta['order_currency'] ?? ''));

        if (array_key_exists('converted_amount', $meta)) {
            if ($metaOrderCurrency === '' || $metaOrderCurrency === $orderCurrency) {
                return round((float) $meta['converted_amount'], 2);
            }
        }

        if ($transactionCurrency === $orderCurrency && $transactionCurrency !== '') {
            return round((float) $transaction->amount, 2);
        }

        $exchangeRate = $meta['exchange_rate'] ?? null;
        $paymentCurrency = strtoupper((string) ($meta['payment_currency'] ?? $transactionCurrency));

        if ($exchangeRate !== null && $paymentCurrency === $transactionCurrency && $paymentCurrency !== '') {
            return round((float) $transaction->amount * (float) $exchangeRate, 2);
        }

        return round((float) $transaction->amount, 2);
    }
}