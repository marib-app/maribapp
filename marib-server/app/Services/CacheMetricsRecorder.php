<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;

class CacheMetricsRecorder
{
    /**
     * @var array<string, array{hits: int, misses: int}>
     */
    private array $metrics = [];

    public function __construct(private readonly TelemetryService $telemetry)
    {
    }

    /**
     * @param array<string, mixed> $context
     */
    public function recordHit(array $context): void
    {
        $this->increment($context, 'hits');

        Log::info('cache.hit', $context);
    }

    /**
     * @param array<string, mixed> $context
     */
    public function recordMiss(array $context): void
    {
        $this->increment($context, 'misses');

        Log::notice('cache.miss', $context);
    }

    public function flush(): void
    {
        if ($this->metrics === []) {
            return;
        }

        foreach ($this->metrics as $store => $data) {
            $hits = $data['hits'];
            $misses = $data['misses'];
            $total = $hits + $misses;

            $this->telemetry->record('cache.metrics', [
                'store' => $store,
                'hits' => $hits,
                'misses' => $misses,
                'hit_rate' => $total > 0 ? round($hits / $total, 4) : null,
            ]);
        }

        $this->metrics = [];
    }

    /**
     * @param array<string, mixed> $context
     */
    private function increment(array $context, string $field): void
    {
        $store = (string) ($context['store'] ?? config('cache.default'));

        if (! isset($this->metrics[$store])) {
            $this->metrics[$store] = [
                'hits' => 0,
                'misses' => 0,
            ];
        }

        $this->metrics[$store][$field]++;
    }
}
