<?php

namespace App\Http\Controllers;

use App\Models\CurrencyRate;
use App\Models\CurrencyRateDailyHistory;
use App\Models\CurrencyRateHourlyHistory;
use App\Models\Governorate;
use App\Services\CurrencyRateHistoryService;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use JsonException;

class CurrencyHistoryController extends Controller
{
    public function __construct(private readonly CurrencyRateHistoryService $historyService)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $ids = $this->normalizeIds($request->input('ids'));

        if ($ids->isEmpty()) {
            return response()->json([
                'error' => false,
                'message' => 'No currency IDs supplied.',
                'data' => [
                    'currency_histories' => [],
                ],
            ]);
        }

        $governorate = null;
        $governorateCode = $request->input('governorate_code');
        if ($governorateCode) {
            $governorate = Governorate::query()
                ->where('code', $governorateCode)
                ->where('is_active', true)
                ->first();
        }

        $currencies = CurrencyRate::query()
            ->with(['quotes.governorate'])
            ->whereIn('id', $ids)
            ->get();

        $ranges = [1, 3, 7];
        $payload = [];
        $lastModifiedTimestamps = [];

        foreach ($currencies as $currency) {
            [$quote] = $currency->resolveQuoteForGovernorate($governorate);
            $governorateId = $quote?->governorate_id;

            if (!$governorateId) {
                $governorateId = $currency->quotes->first()?->governorate_id;
            }

            if (!$governorateId) {
                continue;
            }

            $series = [];
            $etagSeedParts = [$currency->id, $governorateId];

            foreach ($ranges as $days) {
                $seriesPayload = $this->buildSeries($currency->id, $governorateId, $days);
                $series[(string) $days] = $seriesPayload;
                $etagSeedParts[] = $seriesPayload['hash_seed'];
                if ($seriesPayload['last_updated_at']) {
                    $lastModifiedTimestamps[] = $seriesPayload['last_updated_at'];
                }
            }

            $latestHourly = CurrencyRateHourlyHistory::query()
                ->with('governorate')
                ->where('currency_rate_id', $currency->id)
                ->where('governorate_id', $governorateId)
                ->orderByDesc('hour_start')
                ->first();

            $capturedAt = $latestHourly?->captured_at ?? $latestHourly?->hour_start;
            $sourceQuality = $this->historyService->determineSourceQuality($capturedAt);

            $payload[] = [
                'currency_id' => $currency->id,
                'currency_name' => $currency->currency_name,
                'governorate_id' => $governorateId,
                'governorate_code' => $latestHourly?->governorate?->code,
                'ranges' => Arr::map($series, static fn ($entry) => Arr::except($entry, ['hash_seed'])),
                'last_hourly_at' => $latestHourly?->hour_start?->toIso8601String(),
                'last_captured_at' => $capturedAt?->toIso8601String(),
                'source_quality' => $sourceQuality,
                'source' => $latestHourly?->source,
            ];
        }

        try {
            $etag = sha1(json_encode($payload, JSON_THROW_ON_ERROR));
        } catch (JsonException $exception) {
            $etag = sha1(serialize($payload));
        }
        $lastModified = !empty($lastModifiedTimestamps)
            ? max($lastModifiedTimestamps)
            : null;

        $response = response()->json([
            'error' => false,
            'data' => [
                'currency_histories' => $payload,
            ],
        ]);

        $response->setEtag($etag);
        if ($lastModified) {
            $response->setLastModified(CarbonImmutable::createFromTimestamp($lastModified));
        }

        if ($response->isNotModified($request)) {
            return $response;
        }

        return $response;
    }

    private function buildSeries(int $currencyId, int $governorateId, int $days): array
    {
        $now = CarbonImmutable::now();

        if ($days === 1) {
            $from = $now->subDay();
            $entries = CurrencyRateHourlyHistory::query()
                ->where('currency_rate_id', $currencyId)
                ->where('governorate_id', $governorateId)
                ->where('hour_start', '>=', $from)
                ->orderBy('hour_start')
                ->get();

            return $this->formatSeries($entries, 'hourly', $days);
        }

        $from = $now->subDays($days - 1)->startOfDay();

        $entries = CurrencyRateDailyHistory::query()
            ->where('currency_rate_id', $currencyId)
            ->where('governorate_id', $governorateId)
            ->whereDate('day_start', '>=', $from->toDateString())
            ->orderBy('day_start')
            ->get();

        return $this->formatSeries($entries, 'daily', $days);
    }

    /**
     * @param Collection<int, CurrencyRateHourlyHistory|CurrencyRateDailyHistory> $entries
     */
    private function formatSeries(Collection $entries, string $interval, int $days): array
    {
        $points = [];
        $lastUpdatedAt = null;

        foreach ($entries as $entry) {
            if ($entry instanceof CurrencyRateHourlyHistory) {
                $points[] = [
                    'timestamp' => $entry->hour_start?->toIso8601String(),
                    'sell_price' => (float) $entry->sell_price,
                    'buy_price' => (float) $entry->buy_price,
                ];
                $lastUpdatedAt = max($lastUpdatedAt ?? 0, optional($entry->updated_at)->getTimestamp() ?? 0);
            } elseif ($entry instanceof CurrencyRateDailyHistory) {
                $points[] = [
                    'timestamp' => CarbonImmutable::parse($entry->day_start)->toIso8601String(),
                    'sell_price' => (float) $entry->close_sell,
                    'buy_price' => (float) $entry->close_buy,
                    'high_sell' => (float) $entry->high_sell,
                    'low_sell' => (float) $entry->low_sell,
                    'high_buy' => (float) $entry->high_buy,
                    'low_buy' => (float) $entry->low_buy,
                ];
                $lastUpdatedAt = max($lastUpdatedAt ?? 0, optional($entry->updated_at)->getTimestamp() ?? 0);
            }
        }

        $summary = $this->summarizeSeries($points);

        $hashSource = [$interval, $days, $points, $summary];

        try {
            $hashSeed = sha1(json_encode($hashSource, JSON_THROW_ON_ERROR));
        } catch (JsonException $exception) {
            $hashSeed = sha1(serialize($hashSource));
        }

        return [
            'interval' => $interval,
            'range_days' => $days,
            'points' => $points,
            'summary' => $summary,
            'last_updated_at' => $lastUpdatedAt,
            'hash_seed' => $hashSeed,
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $points
     */
    private function summarizeSeries(array $points): array
    {
        if (count($points) === 0) {
            return [
                'latest_sell' => null,
                'latest_buy' => null,
                'change_sell' => null,
                'change_sell_percent' => null,
                'change_buy' => null,
                'change_buy_percent' => null,
                'trend' => 'flat',
                'high_sell' => null,
                'low_sell' => null,
                'high_buy' => null,
                'low_buy' => null,
            ];
        }

        $latest = end($points);
        $first = reset($points);

        $latestSell = $latest['sell_price'] ?? null;
        $firstSell = $first['sell_price'] ?? null;
        $latestBuy = $latest['buy_price'] ?? null;
        $firstBuy = $first['buy_price'] ?? null;

        $changeSell = ($latestSell !== null && $firstSell !== null)
            ? $latestSell - $firstSell
            : null;
        $changeBuy = ($latestBuy !== null && $firstBuy !== null)
            ? $latestBuy - $firstBuy
            : null;

        $changeSellPercent = ($changeSell !== null && $firstSell !== null)
            ? ($firstSell != 0.0 ? ($changeSell / $firstSell) * 100 : null)
            : null;
        $changeBuyPercent = ($changeBuy !== null && $firstBuy !== null)
            ? ($firstBuy != 0.0 ? ($changeBuy / $firstBuy) * 100 : null)
            : null;

        $sellValues = array_filter(array_column($points, 'sell_price'), static fn ($value) => $value !== null);
        $buyValues = array_filter(array_column($points, 'buy_price'), static fn ($value) => $value !== null);

        $trend = 'flat';
        if ($changeSell !== null) {
            if ($changeSell > 0) {
                $trend = 'up';
            } elseif ($changeSell < 0) {
                $trend = 'down';
            }
        }

        return [
            'latest_sell' => $latestSell,
            'latest_buy' => $latestBuy,
            'change_sell' => $changeSell,
            'change_sell_percent' => $changeSellPercent,
            'change_buy' => $changeBuy,
            'change_buy_percent' => $changeBuyPercent,
            'trend' => $trend,
            'high_sell' => !empty($sellValues) ? max($sellValues) : null,
            'low_sell' => !empty($sellValues) ? min($sellValues) : null,
            'high_buy' => !empty($buyValues) ? max($buyValues) : null,
            'low_buy' => !empty($buyValues) ? min($buyValues) : null,
        ];
    }

    /**
     * @return Collection<int, int>
     */
    private function normalizeIds(mixed $input): Collection
    {
        if (is_string($input)) {
            $input = explode(',', $input);
        }

        if (!is_array($input)) {
            return collect();
        }

        return collect($input)
            ->map(static function ($value) {
                if (is_numeric($value)) {
                    return (int) $value;
                }

                if (is_string($value)) {
                    return (int) trim($value);
                }

                return null;
            })
            ->filter(static fn ($value) => $value !== null && $value > 0)
            ->unique()
            ->values();
    }
}