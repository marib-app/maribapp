<?php

return [
    /*
    |--------------------------------------------------------------------------
    | API Metrics Configuration
    |--------------------------------------------------------------------------
    |
    | Configure the rolling histogram sample size and cache lifetimes that
    | power the API metrics instrumentation. Samples are stored in the cache
    | to enable percentile aggregation without a dedicated metrics backend.
    |
    */

    'enable_histograms' => env('API_METRICS_ENABLE_HISTOGRAMS', true),

    'histogram_sample_size' => env('API_METRICS_SAMPLE_SIZE', 200),

    'histogram_cache_seconds' => env('API_METRICS_CACHE_SECONDS', 3600),

    'cache_prefix' => env('API_METRICS_CACHE_PREFIX', 'api_metrics'),
];