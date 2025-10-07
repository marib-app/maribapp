<?php

namespace App\Services;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class ApiMetricsService
{
    public const START_TIME_ATTRIBUTE = 'api_metrics.start_time';
    public const ENDPOINT_ATTRIBUTE = 'api_metrics.endpoint';

    public static function startRequest(Request $request): void
    {
        $request->attributes->set(self::START_TIME_ATTRIBUTE, microtime(true));
    }

    public static function forEndpoint(string $endpoint): void
    {
        request()->attributes->set(self::ENDPOINT_ATTRIBUTE, $endpoint);
    }

    public static function record(Response|JsonResponse $response, ?string $endpoint = null): void
    {
        if (App::runningUnitTests() || !App::bound('request')) {
            return;
        }

        $request = request();

        $startTime = (float) ($request->attributes->get(self::START_TIME_ATTRIBUTE) ?? (defined('LARAVEL_START') ? LARAVEL_START : microtime(true)));
        $durationMs = (microtime(true) - $startTime) * 1000;

        $endpointName = $endpoint
            ?? $request->attributes->get(self::ENDPOINT_ATTRIBUTE)
            ?? self::resolveEndpointName();

        $payloadBytes = strlen($response->getContent());

        $status = $response->getStatusCode();
        $method = $request->getMethod();

        Log::info('api.response.metrics', [
            'endpoint' => $endpointName,
            'duration_ms' => round($durationMs, 3),
            'payload_bytes' => $payloadBytes,
            'status' => $status,
            'method' => $method,
        ]);

        self::updateHistograms($endpointName, $durationMs, $payloadBytes);
    }

    protected static function resolveEndpointName(): string
    {
        $request = request();
        $route = $request->route();

        if ($route) {
            $routeName = $route->getName();

            if (!empty($routeName)) {
                return $routeName;
            }

            if (method_exists($route, 'uri')) {
                return $route->uri();
            }
        }

        return $request->path();
    }

    protected static function updateHistograms(string $endpoint, float $durationMs, int $payloadBytes): void
    {
        if (!config('metrics.enable_histograms', true)) {
            return;
        }

        $cacheKey = sprintf('%s:%s', config('metrics.cache_prefix', 'api_metrics'), $endpoint);

        $histogram = Cache::get($cacheKey, [
            'durations' => [],
            'payloads' => [],
        ]);

        $histogram['durations'][] = $durationMs;
        $histogram['payloads'][] = $payloadBytes;

        $histogram['durations'] = self::normalizeSeries($histogram['durations']);
        $histogram['payloads'] = self::normalizeSeries($histogram['payloads']);

        $ttl = (int) config('metrics.histogram_cache_seconds', 3600);

        Cache::put($cacheKey, $histogram, now()->addSeconds($ttl));

        $percentiles = [
            'endpoint' => $endpoint,
            'p50_duration_ms' => self::percentile($histogram['durations'], 0.5),
            'p95_duration_ms' => self::percentile($histogram['durations'], 0.95),
            'p50_payload_bytes' => self::percentile($histogram['payloads'], 0.5),
            'p95_payload_bytes' => self::percentile($histogram['payloads'], 0.95),
        ];

        Log::info('api.response.metrics.percentiles', $percentiles);
    }

    protected static function normalizeSeries(array $series): array
    {
        $maxSamples = (int) config('metrics.histogram_sample_size', 200);

        if (count($series) > $maxSamples) {
            $series = array_slice($series, -$maxSamples);
        }

        sort($series);

        return $series;
    }

    protected static function percentile(array $sortedSeries, float $percentile): ?float
    {
        $count = count($sortedSeries);

        if ($count === 0) {
            return null;
        }

        $index = (int) round($percentile * ($count - 1));

        $value = $sortedSeries[$index] ?? null;

        return $value === null ? null : round((float) $value, 3);
    }
}