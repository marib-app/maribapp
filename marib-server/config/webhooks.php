<?php

return [
    'default' => [
        'signature_header' => 'X-Webhook-Signature',
        'timestamp_header' => 'X-Webhook-Timestamp',
        'hash_algorithm' => 'sha256',
        'tolerance' => env('WEBHOOK_SIGNATURE_TOLERANCE', 300),
    ],

    'providers' => [
        'stripe' => [
            'secret' => env('STRIPE_WEBHOOK_SECRET'),
        ],

        'razorpay' => [
            'secret' => env('RAZORPAY_WEBHOOK_SECRET'),
        ],

        'paystack' => [
            'secret' => env('PAYSTACK_WEBHOOK_SECRET'),
        ],

        'phonepe' => [
            'secret' => env('PHONEPE_WEBHOOK_SECRET'),
        ],
    ],
];