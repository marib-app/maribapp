<?php

namespace App\Support\Payments;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;

class ReferencePresenter
{
    /**
     * Return a display-friendly reference for a payment transaction.
     */
    public static function forTransaction(?PaymentTransaction $tx): ?string
    {
        if (! $tx instanceof PaymentTransaction) {
            return null;
        }

        $ref = $tx->payment_id ?? $tx->payment_signature ?? null;

        if (is_string($ref) && trim($ref) !== '') {
            return trim($ref);
        }


        $receipt = $tx->receipt_no ?? null;

        if (is_string($receipt) && trim($receipt) !== '') {
            return trim($receipt);
        }

        return 'TX-' . $tx->getKey();
    }

    /**
     * Return the best display reference for a manual payment request or its linked transaction.
     */
    public static function forManualRequest(?ManualPaymentRequest $mpr, ?PaymentTransaction $tx = null): ?string
    {
        if ($tx instanceof PaymentTransaction) {
            return self::forTransaction($tx);
        }

        if ($mpr instanceof ManualPaymentRequest) {
            $ref = $mpr->reference ?? null;

            if (is_string($ref) && trim($ref) !== '') {
                return trim($ref);
            }

            return 'MPR-' . $mpr->getKey();
        }

        return null;
    }
}
