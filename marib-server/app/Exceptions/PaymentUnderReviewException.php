<?php

namespace App\Exceptions;

use App\Models\ManualPaymentRequest;
use RuntimeException;

class PaymentUnderReviewException extends RuntimeException
{
    public function __construct(
        public readonly ?int $manualPaymentRequestId = null,
        string $message = 'payment_under_review',
        public readonly ?ManualPaymentRequest $manualPaymentRequest = null
    ) {
        parent::__construct($message);
    }

    public static function forManualPayment(?ManualPaymentRequest $manualPaymentRequest = null): self
    {
        return new self(
            $manualPaymentRequest?->getKey(),
            'payment_under_review',
            $manualPaymentRequest
        );
    }
}