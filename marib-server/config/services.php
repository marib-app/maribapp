<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'mailgun' => [
        'domain' => env('MAILGUN_DOMAIN'),
        'secret' => env('MAILGUN_SECRET'),
        'endpoint' => env('MAILGUN_ENDPOINT', 'api.mailgun.net'),
        'scheme' => 'https',
    ],

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'whatsapp' => [
        'token' => env('ENJAZATIK_API_TOKEN'),
    ],


    'sms' => [
        'driver' => env('SMS_DRIVER', 'log'),
        'http' => [
            'endpoint' => env('SMS_HTTP_ENDPOINT'),
            'method' => env('SMS_HTTP_METHOD', 'POST'),
            'token' => env('SMS_HTTP_TOKEN'),
            'timeout' => env('SMS_HTTP_TIMEOUT', 10),
        ],
    ],


    'pusher' => [
        'app_id' => env('PUSHER_APP_ID'),
        'key' => env('PUSHER_APP_KEY'),
        'secret' => env('PUSHER_APP_SECRET'),
        'cluster' => env('PUSHER_APP_CLUSTER', 'mt1'),
        'host' => env('PUSHER_HOST'),
        'port' => env('PUSHER_PORT'),
        'scheme' => env('PUSHER_SCHEME', 'https'),
    ],

    'east_yemen_bank' => [
        'base_url' => env('EAST_YEMEN_BANK_BASE_URL', 'https://api.eastyemenbank.test/'),

    ],

    'delivery_pricing' => [
        'base_url' => env('DELIVERY_PRICING_BASE_URL'),
        'calculate_endpoint' => env('DELIVERY_PRICING_CALCULATE_ENDPOINT', '/api/delivery-prices/calculate'),
        'timeout' => env('DELIVERY_PRICING_TIMEOUT', 10),
        'size_weight_map' => [
            'small' => env('DELIVERY_PRICING_SMALL_WEIGHT', 3),
            'medium' => env('DELIVERY_PRICING_MEDIUM_WEIGHT', 7),
            'large' => env('DELIVERY_PRICING_LARGE_WEIGHT', 12),
        ],
    ],






    'fcm' => [
        'verify_ssl' => env('FCM_VERIFY_SSL', true),
        'ca_path'    => env('FCM_CA_PATH') ?: base_path('certs/cacert.pem'),
        'ttl'        => env('FCM_TTL', '3600s'),
        'project_id' => env('FCM_PROJECT_ID'),
        'service_file' => env('FCM_SERVICE_ACCOUNT'),
    ],





    'mobile' => [
        'wallet_deeplink' => env('MOBILE_WALLET_DEEPLINK', 'maribsrv://wallet'),
    ],

];
