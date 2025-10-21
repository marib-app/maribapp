<?php

namespace App\Listeners;

use App\Events\MetalRateUpdated;
use App\Services\MetalWatchlistNotificationService;

class SendMetalRateUpdatedNotification
{
    public function __construct(
        private readonly MetalWatchlistNotificationService $notificationService
    ) {
    }

    public function handle(MetalRateUpdated $event): void
    {
        $this->notificationService->notifyMetalUpdated(
            $event->metalId,
            $event->quotes,
            $event->defaultGovernorateId
        );
    }
}