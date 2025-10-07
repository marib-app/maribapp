<?php

namespace App\Exceptions;

use RuntimeException;

class PaymentWebhookException extends RuntimeException
{
    public function __construct(string $message, public int $status = 400, ?\Throwable $previous = null)
    {
        parent::__construct($message, 0, $previous);
    }
}