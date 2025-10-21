<?php

namespace App\Services;

use App\Models\Governorate;
use App\Models\MetalRate;
use App\Models\MetalRateChangeLog;
use App\Models\MetalRateQuote;
use Carbon\Carbon;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class MetalRateQuoteService
{
    public const CHANGE_CREATED = 'created';
    public const CHANGE_UPDATED = 'updated';
    public const CHANGE_DELETED = 'deleted';

    public function resolveDefaultGovernorateId(): int
    {
        /** @var Governorate|null $governorate */
        $governorate = Governorate::query()->where('code', 'NATL')->first();

        if ($governorate) {
            return (int) $governorate->id;
        }

        $governorate = Governorate::query()->create([
            'code' => 'NATL',
            'name' => 'National Market Average',
            'is_active' => true,
        ])->id;

        return (int) $governorate;
    }

    /**
     * @param array<int, array<string, mixed>> $quotesPayload
     */
    public function syncQuotes(
        MetalRate $metalRate,
        array $quotesPayload,
        int $defaultGovernorateId,
        ?int $userId = null
    ): void {
        /** @var Collection<int, array<string, mixed>> $quotes */
        $quotes = collect($quotesPayload)
            ->map(function (array $quote): array {

                if (!array_key_exists('governorate_id', $quote) || $quote['governorate_id'] === null || $quote['governorate_id'] === '') {
                    throw ValidationException::withMessages([
                        'quotes' => __('Each quote must include a governorate.'),
                    ]);
                }

                $governorateId = (int) Arr::get($quote, 'governorate_id');

                $sell = $this->normalizeNumber(Arr::get($quote, 'sell_price'));
                $buy = $this->normalizeNumber(Arr::get($quote, 'buy_price'));

                $source = $this->normalizeString(Arr::get($quote, 'source'));
                $quotedAtRaw = Arr::get($quote, 'quoted_at');
                $quotedAt = $quotedAtRaw ? Carbon::parse($quotedAtRaw) : now();

                return [
                    'governorate_id' => $governorateId,
                    'sell_price' => $sell,
                    'buy_price' => $buy,
                    'source' => $source,
                    'quoted_at' => $quotedAt,
                ];
            })
            ->filter(function (array $quote): bool {
                return $quote['sell_price'] !== null && $quote['buy_price'] !== null;
            })
            ->map(function (array $quote): array {
                if ($quote['sell_price'] < $quote['buy_price']) {
                    throw ValidationException::withMessages([
                        'quotes' => __('Sell price must be greater than or equal to buy price for all quotes.'),
                    ]);
                }

                return $quote;
            });

        if ($quotes->isEmpty()) {
            throw ValidationException::withMessages([
                'quotes' => __('Please provide at least one governorate rate with both buy and sell prices.'),
            ]);
        }

        if (!$quotes->contains('governorate_id', $defaultGovernorateId)) {
            throw ValidationException::withMessages([
                'default_governorate_id' => __('Default governorate must have both buy and sell prices.'),
            ]);
        }

        DB::transaction(function () use ($metalRate, $quotes, $defaultGovernorateId, $userId): void {
            /** @var Collection<int, MetalRateQuote> $existingQuotes */
            $existingQuotes = $metalRate->quotes()->get()->keyBy('governorate_id');
            $incomingGovernorateIds = $quotes->pluck('governorate_id')->map(fn ($id) => (int) $id)->all();

            $logs = [];
            $timestamp = now();

            $quotesToDelete = $existingQuotes->filter(
                fn (MetalRateQuote $quote) => !in_array((int) $quote->governorate_id, $incomingGovernorateIds, true)
            );

            if ($quotesToDelete->isNotEmpty()) {
                $metalRate->quotes()->whereIn('id', $quotesToDelete->pluck('id'))->delete();

                foreach ($quotesToDelete as $quote) {
                    $logs[] = [
                        'metal_rate_id' => $metalRate->id,
                        'governorate_id' => $quote->governorate_id,
                        'change_type' => self::CHANGE_DELETED,
                        'previous_values' => $this->formatLogValues($quote),
                        'new_values' => null,
                        'changed_by' => $userId,
                        'changed_at' => $timestamp,
                    ];
                }
            }

            $existingQuotes = $existingQuotes->except($quotesToDelete->keys());

            $defaultQuote = null;

            foreach ($quotes as $quote) {
                $isDefault = (int) $quote['governorate_id'] === $defaultGovernorateId;

                /** @var MetalRateQuote|null $existingQuote */
                $existingQuote = $existingQuotes->get($quote['governorate_id']);
                $previousSnapshot = $this->formatLogValues($existingQuote);

                $stored = $metalRate->quotes()->updateOrCreate(
                    [
                        'governorate_id' => $quote['governorate_id'],
                    ],
                    [
                        'sell_price' => $quote['sell_price'],
                        'buy_price' => $quote['buy_price'],
                        'source' => $quote['source'],
                        'quoted_at' => $quote['quoted_at'],
                        'is_default' => $isDefault,
                    ]
                );

                $newSnapshot = $this->formatLogValues($stored);

                if ($existingQuote) {
                    if ($previousSnapshot !== $newSnapshot) {
                        $logs[] = [
                            'metal_rate_id' => $metalRate->id,
                            'governorate_id' => $stored->governorate_id,
                            'change_type' => self::CHANGE_UPDATED,
                            'previous_values' => $previousSnapshot,
                            'new_values' => $newSnapshot,
                            'changed_by' => $userId,
                            'changed_at' => $timestamp,
                        ];
                    }
                } else {
                    $logs[] = [
                        'metal_rate_id' => $metalRate->id,
                        'governorate_id' => $stored->governorate_id,
                        'change_type' => self::CHANGE_CREATED,
                        'previous_values' => null,
                        'new_values' => $newSnapshot,
                        'changed_by' => $userId,
                        'changed_at' => $timestamp,
                    ];
                }

                if ($isDefault) {
                    $defaultQuote = $stored;
                }
            }

            $metalRate->quotes()
                ->where('governorate_id', '!=', $defaultGovernorateId)
                ->where('is_default', true)
                ->update(['is_default' => false]);

            if (!empty($logs)) {
                foreach ($logs as $entry) {
                    MetalRateChangeLog::create($entry);
                }
            }

            if (!$defaultQuote) {
                $defaultQuote = $metalRate->quotes()->where('governorate_id', $defaultGovernorateId)->first();
            }

            $metalRate->applyDefaultQuoteSnapshot($defaultQuote);
        });
    }

    private function normalizeNumber($value): ?float
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (is_string($value)) {
            $value = str_replace(',', '', $value);
        }

        if (!is_numeric($value)) {
            return null;
        }

        return (float) $value;
    }

    private function normalizeString($value): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim((string) $value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function formatLogValues(?MetalRateQuote $quote): ?array
    {
        if (!$quote) {
            return null;
        }

        return [
            'sell_price' => $quote->sell_price !== null ? (string) $quote->sell_price : null,
            'buy_price' => $quote->buy_price !== null ? (string) $quote->buy_price : null,
            'source' => $quote->source,
            'quoted_at' => $quote->quoted_at?->toIso8601String(),
            'is_default' => (bool) $quote->is_default,
        ];
    }
}