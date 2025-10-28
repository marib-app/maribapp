<?php

namespace App\Services\Logging;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class PaymentTrace
{
    public static function trace(string $event, array $context = [], ?Request $request = null): void
    {
        if ($request instanceof Request) {
            $correlationId = $request->headers->get('X-Correlation-Id');
            if ($correlationId) {
                $context['correlation_id'] = $correlationId;
            }
        }

        Log::info($event, $context);
    }
}

