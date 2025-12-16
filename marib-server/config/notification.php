<?php

use App\Enums\NotificationType;

return [
    'policy_version' => env('NOTIFICATION_POLICY_VERSION', '2024-11-20'),
    'payload_version' => (int) env('NOTIFICATION_PAYLOAD_VERSION', 1),
    'cache_store' => env('NOTIFICATION_CACHE_STORE', 'redis'),
    'max_data_bytes' => 3800,
    'defaults' => [
        'queue' => env('NOTIFICATIONS_QUEUE', 'notifications'),
        'ttl' => 1800,
        'priority' => 'normal',
        'collapse_key' => 'entity:{entity_id}',
        'throttle_ttl' => 0,
        'dedupe_ttl' => 900,
    ],
    'types' => [
        NotificationType::PaymentRequest->value => [
            'collapse_key' => 'wallet:{entity_id}',
            'ttl' => 1800,
            'priority' => 'high',
            'queue' => 'notifications-high',
            'throttle_ttl' => 60,
            'dedupe_ttl' => 3600,
        ],
        NotificationType::KycRequest->value => [
            'collapse_key' => 'verification:{entity_id}',
            'ttl' => 86400,
            'priority' => 'high',
            'queue' => 'notifications-high',
            // تحديث حالة التوثيق يجب أن يصل في كل مرة، لذلك نلغي منع التكرار والخنق
            'throttle_ttl' => 0,
            'dedupe_ttl' => 0,
        ],
        NotificationType::OrderStatus->value => [
            'collapse_key' => 'order:{entity_id}',
            'ttl' => 14400,
            'priority' => 'normal',
            'throttle_ttl' => 60,
            'dedupe_ttl' => 900,
        ],
        NotificationType::WalletAlert->value => [
            'collapse_key' => 'wallet:{entity_id}',
            'ttl' => 3600,
            'priority' => 'high',
            'queue' => 'notifications-high',
            'throttle_ttl' => 120,
            'dedupe_ttl' => 1800,
        ],
        NotificationType::BroadcastMarketing->value => [
            'collapse_key' => 'campaign:{entity_id}',
            'ttl' => 43200,
            'priority' => 'normal',
            'queue' => 'notifications',
            'throttle_ttl' => 0,
            'dedupe_ttl' => 0,
        ],
        NotificationType::ActionRequest->value => [
            'collapse_key' => 'action:{entity_id}',
            'ttl' => 1800,
            'priority' => 'high',
            'queue' => 'notifications-high',
            'throttle_ttl' => 60,
            'dedupe_ttl' => 3600,
        ],
        NotificationType::ChatMessage->value => [
            'collapse_key' => 'chat:{entity_id}',
            'ttl' => 900,
            'priority' => 'high',
            'queue' => 'notifications-high',
            'throttle_ttl' => 0,
            'dedupe_ttl' => 0,
        ],
    ],
];
