<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class PerformanceMetricController extends Controller
{
    private const STORAGE_FILE = 'performance-metrics.json';
    private const METRIC_HISTORY_LIMIT = 500;

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'screen' => ['required', 'string', 'max:255'],
            'ttff' => ['required', 'numeric', 'min:0'],
            'fmp' => ['required', 'numeric', 'min:0'],
            'fps' => ['required', 'numeric', 'min:0'],
            'droppedFrames' => ['required', 'numeric', 'min:0'],
            'sampleDuration' => ['nullable', 'numeric', 'min:0'],
            'device' => ['nullable', 'array'],
        ]);

        $screen = $validated['screen'];
        $metrics = [
            'ttff' => (float) $validated['ttff'],
            'fmp' => (float) $validated['fmp'],
            'fps' => (float) $validated['fps'],
            'droppedFrames' => (float) $validated['droppedFrames'],
        ];

        $history = $this->readHistory();

        if (!array_key_exists($screen, $history)) {
            $history[$screen] = [
                'metrics' => [
                    'ttff' => [],
                    'fmp' => [],
                    'fps' => [],
                    'droppedFrames' => [],
                ],
                'last_device' => null,
                'last_sample_duration' => null,
            ];
        }

        foreach ($metrics as $metricName => $value) {
            $history[$screen]['metrics'][$metricName][] = $value;
            $history[$screen]['metrics'][$metricName] = $this->trimValues($history[$screen]['metrics'][$metricName]);
        }

        $history[$screen]['last_device'] = $validated['device'] ?? null;
        $history[$screen]['last_sample_duration'] = $validated['sampleDuration'] ?? null;

        $this->writeHistory($history);

        $summary = [
            'screen' => $screen,
            'samples' => count($history[$screen]['metrics']['ttff']),
            'metrics' => [],
        ];

        foreach ($metrics as $metricName => $value) {
            $values = $history[$screen]['metrics'][$metricName];
            $summary['metrics'][$metricName] = [
                'latest' => $value,
                'p50' => $this->percentile($values, 0.50),
                'p95' => $this->percentile($values, 0.95),
            ];
        }

        if ($history[$screen]['last_device']) {
            $summary['device'] = $history[$screen]['last_device'];
        }

        if ($history[$screen]['last_sample_duration']) {
            $summary['sample_duration_ms'] = (float) $history[$screen]['last_sample_duration'];
        }

        Log::channel('performance')->info('Screen performance summary', $summary);

        return response()->json([
            'status' => 'ok',
            'summary' => $summary,
        ]);
    }

    private function readHistory(): array
    {
        if (!Storage::disk('local')->exists(self::STORAGE_FILE)) {
            return [];
        }

        $raw = Storage::disk('local')->get(self::STORAGE_FILE);
        $decoded = json_decode($raw, true);

        if (!is_array($decoded)) {
            return [];
        }

        foreach ($decoded as $screen => $payload) {
            if (!isset($payload['metrics'])) {
                $decoded[$screen]['metrics'] = [
                    'ttff' => [],
                    'fmp' => [],
                    'fps' => [],
                    'droppedFrames' => [],
                ];
            }
        }

        return $decoded;
    }

    private function writeHistory(array $history): void
    {
        Storage::disk('local')->put(
            self::STORAGE_FILE,
            json_encode($history, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
        );
    }

    private function trimValues(array $values): array
    {
        $count = count($values);
        if ($count <= self::METRIC_HISTORY_LIMIT) {
            return $values;
        }

        return array_slice($values, $count - self::METRIC_HISTORY_LIMIT);
    }

    private function percentile(array $values, float $ratio): float
    {
        $count = count($values);
        if ($count === 0) {
            return 0.0;
        }

        sort($values);

        if ($count === 1) {
            return (float) $values[0];
        }

        $index = ($count - 1) * $ratio;
        $lowerIndex = (int) floor($index);
        $upperIndex = (int) ceil($index);

        if ($lowerIndex === $upperIndex) {
            return (float) $values[$lowerIndex];
        }

        $weight = $index - $lowerIndex;
        $lower = (float) $values[$lowerIndex];
        $upper = (float) $values[$upperIndex];

        return $lower + ($upper - $lower) * $weight;
    }
}