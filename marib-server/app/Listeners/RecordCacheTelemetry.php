<?php

namespace App\Listeners;

use Illuminate\Cache\Events\CacheEvent;
use Illuminate\Cache\Events\CacheHit;
use Illuminate\Cache\Events\CacheMissed;
use App\Services\CacheMetricsRecorder;


class RecordCacheTelemetry
{

    public function __construct(private readonly CacheMetricsRecorder $metrics)
    {
    }

    public function handle(CacheEvent $event): void
    {
        $context = [
            'key' => $event->key ?? null,
            'store' => $event->storeName ?? config('cache.default'),
        ];

        if (property_exists($event, 'tags') && ! empty($event->tags)) {
            $context['tags'] = $event->tags;
        }

        if ($event instanceof CacheHit) {
            $this->metrics->recordHit($context);


            return;
        }

        if ($event instanceof CacheMissed) {
            $this->metrics->recordMiss($context);
        }
    }
}