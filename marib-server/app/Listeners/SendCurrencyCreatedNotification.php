<?php

namespace App\Listeners;

use App\Events\CurrencyCreated;
use App\Services\CurrencyWatchlistNotificationService;

class SendCurrencyCreatedNotification
{
    public function __construct(
        private readonly CurrencyWatchlistNotificationService $notificationService
    ) {
    }

    public function handle(CurrencyCreated $event): void
    {
        $this->notificationService->notifyCurrencyCreated(
            $event->currencyId,
            $event->defaultGovernorateId
        );
    }
}