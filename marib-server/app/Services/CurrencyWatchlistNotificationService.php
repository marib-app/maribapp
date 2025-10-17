<?php

namespace App\Services;

use App\Models\CurrencyRate;
use App\Models\CurrencyRateQuote;
use App\Models\User;
use App\Models\UserPreference;
use App\Notifications\CurrencyCreatedNotification;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\Notification;

class CurrencyWatchlistNotificationService
{
    public function notifyCurrencyCreated(int $currencyId, int $defaultGovernorateId): void
    {
        $currency = CurrencyRate::query()->find($currencyId);

        if (!$currency) {
            return;
        }

        $watcherIds = UserPreference::query()
            ->whereJsonContains('currency_watchlist', $currencyId)
            ->pluck('user_id')
            ->filter()
            ->unique();

        if ($watcherIds->isEmpty()) {
            return;
        }

        /** @var Collection<int, User> $watchers */
        $watchers = User::query()
            ->whereIn('id', $watcherIds)
            ->with(['fcm_tokens' => static function ($query) {
                $query->select('id', 'user_id', 'fcm_token');
            }])
            ->get();

        $watchers = $watchers->filter(static function (User $user) {
            return $user->fcm_tokens
                ->pluck('fcm_token')
                ->filter()
                ->isNotEmpty();
        })->values();

        if ($watchers->isEmpty()) {
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

        Notification::send($watchers, $notification);
    }
}