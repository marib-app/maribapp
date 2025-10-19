<?php

namespace App\Services;

use App\Enums\NotificationFrequency;
use App\Models\CurrencyRate;
use App\Models\CurrencyRateQuote;
use App\Notifications\CurrencyRateUpdatedNotification;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use App\Models\UserPreference;
use App\Notifications\CurrencyCreatedNotification;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Str;



class CurrencyWatchlistNotificationService
{
    public function notifyCurrencyCreated(int $currencyId, int $defaultGovernorateId): void
    {
        $currency = CurrencyRate::query()->find($currencyId);

        if (!$currency) {
            return;
        }

        $preferences = $this->resolveWatchPreferences($currencyId);


        if ($preferences->isEmpty()) {
            return;
        }

        $defaultQuote = CurrencyRateQuote::query()
            ->with('governorate:id,name')
            ->where('currency_rate_id', $currencyId)
            ->where('governorate_id', $defaultGovernorateId)
            ->first();

        $notification = new CurrencyCreatedNotification(
            currencyId: $currency->getKey(),
            currencyName: $currency->currency_name,
            defaultGovernorateId: $defaultGovernorateId,
            defaultGovernorateName: $defaultQuote?->governorate?->name,
            sellPrice: $defaultQuote?->sell_price,
            buyPrice: $defaultQuote?->buy_price
        );


        $watchers = $preferences
            ->pluck('user')
            ->filter()
            ->values();

        if ($watchers->isEmpty()) {
            return;
        }


        Notification::send($watchers, $notification);
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
    public function notifyCurrencyUpdated(int $currencyId, array $quotes): void
    {
        $currency = CurrencyRate::query()->find($currencyId);

        if (!$currency) {
            return;
        }

        $preferences = $this->resolveWatchPreferences($currencyId);

        if ($preferences->isEmpty()) {
            return;
        }

        $quoteCollection = collect($quotes)
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

        if ($quoteCollection->isEmpty()) {
            return;
        }

        $quotesByCode = $quoteCollection
            ->filter(static fn (array $quote): bool => !empty($quote['governorate_code']))
            ->keyBy(static fn (array $quote): string => $quote['governorate_code']);

        $defaultQuote = $quoteCollection->firstWhere('is_default', true) ?? $quoteCollection->first();

        $preferences->each(function (UserPreference $preference) use ($currency, $quotesByCode, $defaultQuote, $currencyId): void {
            $user = $preference->user;

            if (!$user) {
                return;
            }

            $frequency = NotificationFrequency::tryFrom($preference->notification_frequency)
                ?? NotificationFrequency::DAILY;

            if ($frequency === NotificationFrequency::NEVER) {
                return;
            }

            if (!$this->frequencyAllows($frequency, $user->getKey(), $currencyId)) {
                return;
            }

            $regions = $preference->currency_notification_regions ?? [];
            $selectedQuote = null;

            $preferredCode = $regions[$currencyId] ?? null;
            if (is_string($preferredCode) && $preferredCode !== '') {
                $selectedQuote = $quotesByCode->get(Str::upper($preferredCode));
            }

            if (!$selectedQuote) {
                $selectedQuote = $defaultQuote;
            }

            if (!$selectedQuote) {
                return;
            }

            Notification::send($user, new CurrencyRateUpdatedNotification(
                currencyId: $currency->getKey(),
                currencyName: $currency->currency_name,
                governorateId: $selectedQuote['governorate_id'],
                governorateName: $selectedQuote['governorate_name'],
                sellPrice: $selectedQuote['sell_price'],
                buyPrice: $selectedQuote['buy_price']
            ));

            $this->rememberNotification($frequency, $user->getKey(), $currencyId);
        });
    }

    /**
     * @return Collection<int, UserPreference>
     */
    private function resolveWatchPreferences(int $currencyId): Collection
    {
        return UserPreference::query()
            ->whereJsonContains('currency_watchlist', $currencyId)
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

    private function frequencyAllows(NotificationFrequency $frequency, int $userId, int $currencyId): bool
    {
        return !Cache::has($this->makeThrottleKey($userId, $currencyId));
    }

    private function rememberNotification(NotificationFrequency $frequency, int $userId, int $currencyId): void
    {
        $ttl = match ($frequency) {
            NotificationFrequency::HOURLY => now()->addHour(),
            NotificationFrequency::DAILY => now()->addDay(),
            default => now()->addHours(6),
        };

        Cache::put($this->makeThrottleKey($userId, $currencyId), now(), $ttl);
    }

    private function makeThrottleKey(int $userId, int $currencyId): string
    {
        return sprintf('currency-watchlist:%d:%d', $userId, $currencyId);
    }


}