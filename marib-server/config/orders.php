<?php
use App\Services\OrderCheckoutService;

return [
    'default_payment_method' => (function () {
        $normalized = OrderCheckoutService::normalizePaymentMethod(
            env('ORDERS_DEFAULT_PAYMENT_METHOD', 'east_yemen_bank')
        );

        if (! is_string($normalized) || $normalized === '') {
            return 'east_yemen_bank';
        }

        return mb_strtolower($normalized);
    })(),
    
    'default_payment_intent' => [
        'ttl_minutes' => (int) env('ORDERS_DEFAULT_PAYMENT_INTENT_TTL_MINUTES', 60 * 24),
        'department_overrides' => array_filter([
            // 'shein' => 180,
        ]),
    ],
    'deposit' => [
        'departments' => [
            'shein' => [
                'ratio' => (float) env('ORDERS_DEPOSIT_SHEIN_RATIO', 0.3),
                'minimum_amount' => (float) env('ORDERS_DEPOSIT_SHEIN_MINIMUM', 0.0),
            ],
            'computer' => [
                'ratio' => (float) env('ORDERS_DEPOSIT_COMPUTER_RATIO', 0.2),
                'minimum_amount' => (float) env('ORDERS_DEPOSIT_COMPUTER_MINIMUM', 0.0),
            ],
        ],
    ],
];