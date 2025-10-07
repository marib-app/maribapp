<?php

namespace App\Exceptions;

use RuntimeException;

class CheckoutValidationException extends RuntimeException
{
    public function __construct(string $message, private readonly string $errorCode)
    {
        parent::__construct($message);
    }

    public function getErrorCode(): string
    {
        return $this->errorCode;
    }
}