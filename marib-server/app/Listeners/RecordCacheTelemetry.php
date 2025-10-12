<?php

namespace App\Listeners;

use Illuminate\Cache\Events\CacheEvent;
use Illuminate\Cache\Events\CacheHit;
use Illuminate\Cache\Events\CacheMissed;
use Illuminate\Support\Facades\Log;

class RecordCacheTelemetry
{
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
            Log::info('cache.hit', $context);

            return;
        }

        if ($event instanceof CacheMissed) {
            Log::notice('cache.miss', $context);
        }
    }
}