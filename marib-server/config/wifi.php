<?php

return [
    'alerts' => [
        'low_stock_threshold' => (int) env('WIFI_LOW_STOCK_THRESHOLD', 10),
        'low_stock_cooldown_minutes' => (int) env('WIFI_LOW_STOCK_COOLDOWN_MINUTES', 180),
    ],

    'reports' => [
        'auto_suspend_threshold' => (int) env('WIFI_REPORTS_AUTO_SUSPEND_THRESHOLD', 3),
        'auto_suspend_window_hours' => (int) env('WIFI_REPORTS_AUTO_SUSPEND_WINDOW_HOURS', 24),
        'response_deadline_hours' => (int) env('WIFI_REPORTS_RESPONSE_DEADLINE_HOURS', 12),
    ],
];