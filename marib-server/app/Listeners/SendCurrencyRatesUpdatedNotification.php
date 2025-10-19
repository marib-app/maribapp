<?php

namespace App\Listeners;

use App\Events\CurrencyRatesUpdated;
use App\Services\CurrencyWatchlistNotificationService;

class SendCurrencyRatesUpdatedNotification
{
    public function __construct(
        private readonly CurrencyWatchlistNotificationService $notificationService
    ) {
    }

    public function handle(CurrencyRatesUpdated $event): void
    {
        $this->notificationService->notifyCurrencyUpdated(
            $event->currencyId,
            $event->quotes
        );
    }
}