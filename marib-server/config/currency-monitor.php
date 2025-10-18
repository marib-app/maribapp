<?php

return [
    'freshness' => [
        'warning_hours' => (int) env('CURRENCY_MONITOR_WARNING_HOURS', 3),
        'critical_hours' => (int) env('CURRENCY_MONITOR_CRITICAL_HOURS', 12),
    ],

    'quality_alerts' => [
        'fresh' => null,
        'unknown' => env('CURRENCY_MONITOR_ALERT_UNKNOWN', true) ? 'warning' : null,
        'warning' => env('CURRENCY_MONITOR_ALERT_WARNING', true) ? 'warning' : null,
        'stale' => env('CURRENCY_MONITOR_ALERT_STALE', true) ? 'critical' : null,
    ],

    'channels' => [
        'admin_notification' => env('CURRENCY_MONITOR_CHANNEL_ADMIN', true),
        'fcm' => env('CURRENCY_MONITOR_CHANNEL_FCM', false),
    ],
];