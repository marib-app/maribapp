<?php

namespace App\Services;

use App\Models\CurrencyRate;
use App\Models\CurrencyRateDailyHistory;
use App\Models\CurrencyRateHourlyHistory;
use App\Models\CurrencyRateQuote;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class CurrencyRateHistoryService
{
    public function snapshotQuotes(?CarbonInterface $timestamp = null): void
    {
        $now = $timestamp ? CarbonImmutable::instance($timestamp) : CarbonImmutable::now();
        $hourStart = $now->startOfHour();

        /** @var EloquentCollection<int, CurrencyRate> $currencies */
        $currencies = CurrencyRate::query()
            ->with(['quotes' => static function ($query) {
                $query->with('governorate');
            }])
            ->get();

        DB::transaction(function () use ($currencies, $hourStart, $now) {
            foreach ($currencies as $currency) {
                /** @var Collection<int, CurrencyRateQuote> $quotes */
                $quotes = $currency->quotes;

                foreach ($quotes as $quote) {
                    if ($quote->governorate_id === null) {
                        continue;
                    }

                    $history = CurrencyRateHourlyHistory::updateOrCreate(
                        [
                            'currency_rate_id' => $currency->id,
                            'governorate_id' => $quote->governorate_id,
                            'hour_start' => $hourStart,
                        ],
                        [
                            'sell_price' => $quote->sell_price,
                            'buy_price' => $quote->buy_price,
                            'source' => $quote->source,
                            'captured_at' => $now,
                        ]
                    );

                    $this->updateDailyAggregate($history->currency_rate_id, $history->governorate_id, $hourStart);
                }
            }
        });
    }

    public function rebuildDailyAggregates(
        CarbonInterface $startDate,
        CarbonInterface $endDate,
        ?int $currencyRateId = null,
        ?int $governorateId = null
    ): void {
        $start = CarbonImmutable::instance($startDate)->startOfDay();
        $end = CarbonImmutable::instance($endDate)->endOfDay();

        $cursor = $start;
        while ($cursor->lte($end)) {
            $this->rebuildDailyForDate($cursor, $currencyRateId, $governorateId);
            $cursor = $cursor->addDay();
        }
    }

    public function determineSourceQuality(?CarbonInterface $capturedAt): string
    {
        if (!$capturedAt) {
            return 'unknown';
        }

        $hours = $capturedAt->diffInHours(Carbon::now());

        if ($hours <= 3) {
            return 'fresh';
        }

        if ($hours <= 12) {
            return 'warning';
        }

        return 'stale';
    }

    private function rebuildDailyForDate(CarbonImmutable $day, ?int $currencyRateId, ?int $governorateId): void
    {
        $start = $day->copy()->startOfDay();
        $end = $day->copy()->endOfDay();

        $query = CurrencyRateHourlyHistory::query()
            ->whereBetween('hour_start', [$start, $end]);

        if ($currencyRateId !== null) {
            $query->where('currency_rate_id', $currencyRateId);
        }

        if ($governorateId !== null) {
            $query->where('governorate_id', $governorateId);
        }

        /** @var Collection<int, CurrencyRateHourlyHistory> $entries */
        $entries = $query->orderBy('hour_start')->get();

        $grouped = $entries->groupBy(static fn (CurrencyRateHourlyHistory $entry) => sprintf('%d-%d', $entry->currency_rate_id, $entry->governorate_id));

        foreach ($grouped as $group) {
            $this->persistDailyAggregate($group, $day);
        }
    }

    private function updateDailyAggregate(int $currencyRateId, int $governorateId, CarbonImmutable $hourStart): void
    {
        $day = $hourStart->copy()->startOfDay();

        /** @var Collection<int, CurrencyRateHourlyHistory> $entries */
        $entries = CurrencyRateHourlyHistory::query()
            ->where('currency_rate_id', $currencyRateId)
            ->where('governorate_id', $governorateId)
            ->whereBetween('hour_start', [$day, $day->copy()->endOfDay()])
            ->orderBy('hour_start')
            ->get();

        if ($entries->isEmpty()) {
            CurrencyRateDailyHistory::query()
                ->where('currency_rate_id', $currencyRateId)
                ->where('governorate_id', $governorateId)
                ->whereDate('day_start', $day)
                ->delete();

            return;
        }

        $this->persistDailyAggregate($entries, $day);
    }

    /**
     * @param Collection<int, CurrencyRateHourlyHistory> $entries
     */
    private function persistDailyAggregate(Collection $entries, CarbonImmutable $day): void
    {
        if ($entries->isEmpty()) {
            return;
        }

        /** @var CurrencyRateHourlyHistory $first */
        $first = $entries->first();
        /** @var CurrencyRateHourlyHistory $last */
        $last = $entries->last();

        $highSell = $entries->max('sell_price');
        $lowSell = $entries->min('sell_price');
        $highBuy = $entries->max('buy_price');
        $lowBuy = $entries->min('buy_price');

        $openSell = (float) $first->sell_price;
        $closeSell = (float) $last->sell_price;
        $openBuy = (float) $first->buy_price;
        $closeBuy = (float) $last->buy_price;

        $changeSell = $closeSell - $openSell;
        $changeBuy = $closeBuy - $openBuy;

        $changeSellPercent = $openSell != 0.0 ? ($changeSell / $openSell) * 100 : 0.0;
        $changeBuyPercent = $openBuy != 0.0 ? ($changeBuy / $openBuy) * 100 : 0.0;

        CurrencyRateDailyHistory::updateOrCreate(
            [
                'currency_rate_id' => $first->currency_rate_id,
                'governorate_id' => $first->governorate_id,
                'day_start' => $day->toDateString(),
            ],
            [
                'open_sell' => $openSell,
                'close_sell' => $closeSell,
                'high_sell' => $highSell,
                'low_sell' => $lowSell,
                'open_buy' => $openBuy,
                'close_buy' => $closeBuy,
                'high_buy' => $highBuy,
                'low_buy' => $lowBuy,
                'change_sell' => $changeSell,
                'change_sell_percent' => $changeSellPercent,
                'change_buy' => $changeBuy,
                'change_buy_percent' => $changeBuyPercent,
                'samples_count' => $entries->count(),
                'last_sample_at' => $entries->max('captured_at'),
            ]
        );
    }
}