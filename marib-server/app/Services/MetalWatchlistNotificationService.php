<?php

namespace App\Services;

use App\Enums\NotificationFrequency;
use App\Models\MetalRate;
use App\Models\UserPreference;
use App\Notifications\MetalRateCreatedNotification;
use App\Notifications\MetalRateUpdatedNotification;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Str;

class MetalWatchlistNotificationService
{
    /**
     * @param array<int, array{
     *     governorate_id: int,
     *     governorate_code: string|null,
     *     governorate_name: string|null,
     *     sell_price: string|null,
     *     buy_price: string|null,
     *     is_default: bool
     * }> $quotes
     */
    public function notifyMetalCreated(int $metalId, array $quotes, int $defaultGovernorateId): void
    {
        $metal = MetalRate::query()->find($metalId);

        if (!$metal) {
            return;
        }

        $preferences = $this->resolveWatchPreferences($metalId);

        if ($preferences->isEmpty()) {
            return;
        }

        $quoteCollection = $this->normalizeQuotes($quotes);

        if ($quoteCollection->isEmpty()) {
            return;
        }

        $defaultQuote = $this->resolveDefaultQuote($quoteCollection, $defaultGovernorateId);

        if (!$defaultQuote) {
            return;
        }

        $watchers = $preferences
            ->pluck('user')
            ->filter()
            ->values();

        if ($watchers->isEmpty()) {
            return;
        }

        Notification::send($watchers, new MetalRateCreatedNotification(
            metalId: $metal->getKey(),
            metalName: $metal->display_name,
            governorateId: $defaultQuote['governorate_id'],
            governorateName: $defaultQuote['governorate_name'],
            sellPrice: $defaultQuote['sell_price'],
            buyPrice: $defaultQuote['buy_price']
        ));
    }

    /**
     * @param array<int, array{
     *     governorate_id: int,
     *     governorate_code: string|null,
     *     governorate_name: string|null,
     *     sell_price: string|null,
     *     buy_price: string|null,
     *     is_default: bool
     * }> $quotes
     */
    public function notifyMetalUpdated(int $metalId, array $quotes, int $defaultGovernorateId): void
    {
        $metal = MetalRate::query()->find($metalId);

        if (!$metal) {
            return;
        }

        $preferences = $this->resolveWatchPreferences($metalId);

        if ($preferences->isEmpty()) {
            return;
        }

        $quoteCollection = $this->normalizeQuotes($quotes);

        if ($quoteCollection->isEmpty()) {
            return;
        }

        $defaultQuote = $this->resolveDefaultQuote($quoteCollection, $defaultGovernorateId);

        if (!$defaultQuote) {
            return;
        }

        $preferences->each(function (UserPreference $preference) use ($metal, $defaultQuote, $metalId): void {
            $user = $preference->user;

            if (!$user) {
                return;
            }

            $frequency = NotificationFrequency::tryFrom($preference->notification_frequency)
                ?? NotificationFrequency::DAILY;

            if ($frequency === NotificationFrequency::NEVER) {
                return;
            }

            if (!$this->frequencyAllows($frequency, $user->getKey(), $metalId)) {
                return;
            }

            Notification::send($user, new MetalRateUpdatedNotification(
                metalId: $metal->getKey(),
                metalName: $metal->display_name,
                governorateId: $defaultQuote['governorate_id'],
                governorateName: $defaultQuote['governorate_name'],
                sellPrice: $defaultQuote['sell_price'],
                buyPrice: $defaultQuote['buy_price']
            ));

            $this->rememberNotification($frequency, $user->getKey(), $metalId);
        });
    }

    /**
     * @return Collection<int, UserPreference>
     */
    private function resolveWatchPreferences(int $metalId): Collection
    {
        return UserPreference::query()
            ->whereJsonContains('metal_watchlist', $metalId)
            ->with(['user' => static function ($query) {
                $query->with(['fcm_tokens' => static function ($query) {
                    $query->select('id', 'user_id', 'fcm_token');
                }]);
            }])
            ->get()
            ->filter(static function (UserPreference $preference): bool {
                $user = $preference->user;

                if (!$user) {
                    return false;
                }

                return $user->fcm_tokens
                    ->pluck('fcm_token')
                    ->filter()
                    ->isNotEmpty();
            })
            ->unique(static fn (UserPreference $preference) => $preference->user?->getKey())
            ->values();
    }

    /**
     * @param array<int, array{
     *     governorate_id: int,
     *     governorate_code: string|null,
     *     governorate_name: string|null,
     *     sell_price: string|null,
     *     buy_price: string|null,
     *     is_default: bool
     * }> $quotes
     * @return Collection<int, array{
     *     governorate_id: int,
     *     governorate_code: string|null,
     *     governorate_name: string|null,
     *     sell_price: string|null,
     *     buy_price: string|null,
     *     is_default: bool
     * }>
     */
    private function normalizeQuotes(array $quotes): Collection
    {
        return collect($quotes)
            ->map(static function (array $quote): array {
                return [
                    'governorate_id' => (int) ($quote['governorate_id'] ?? 0),
                    'governorate_code' => isset($quote['governorate_code'])
                        ? Str::upper((string) $quote['governorate_code'])
                        : null,
                    'governorate_name' => $quote['governorate_name'] ?? null,
                    'sell_price' => array_key_exists('sell_price', $quote) && $quote['sell_price'] !== null
                        ? (string) $quote['sell_price']
                        : null,
                    'buy_price' => array_key_exists('buy_price', $quote) && $quote['buy_price'] !== null
                        ? (string) $quote['buy_price']
                        : null,
                    'is_default' => (bool) ($quote['is_default'] ?? false),
                ];
            })
            ->filter(static fn (array $quote): bool => $quote['governorate_id'] > 0)
            ->values();
    }

    /**
     * @param Collection<int, array{
     *     governorate_id: int,
     *     governorate_code: string|null,
     *     governorate_name: string|null,
     *     sell_price: string|null,
     *     buy_price: string|null,
     *     is_default: bool
     * }> $quotes
     * @return array{
     *     governorate_id: int,
     *     governorate_code: string|null,
     *     governorate_name: string|null,
     *     sell_price: string|null,
     *     buy_price: string|null,
     *     is_default: bool
     * }|null
     */
    private function resolveDefaultQuote(Collection $quotes, int $defaultGovernorateId): ?array
    {
        if ($defaultGovernorateId > 0) {
            $preferred = $quotes->firstWhere('governorate_id', $defaultGovernorateId);

            if ($preferred) {
                return $preferred;
            }
        }

        $fallback = $quotes->firstWhere('is_default', true);

        if ($fallback) {
            return $fallback;
        }

        return $quotes->first();
    }

    private function frequencyAllows(NotificationFrequency $frequency, int $userId, int $metalId): bool
    {
        return !Cache::has($this->makeThrottleKey($userId, $metalId));
    }

    private function rememberNotification(NotificationFrequency $frequency, int $userId, int $metalId): void
    {
        $ttl = match ($frequency) {
            NotificationFrequency::HOURLY => now()->addHour(),
            NotificationFrequency::DAILY => now()->addDay(),
            default => now()->addHours(6),
        };

        Cache::put($this->makeThrottleKey($userId, $metalId), now(), $ttl);
    }

    private function makeThrottleKey(int $userId, int $metalId): string
    {
        return sprintf('metal-watchlist:%d:%d', $userId, $metalId);
    }
}