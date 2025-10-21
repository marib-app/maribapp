<?php

namespace App\Listeners;

use App\Events\MetalRateCreated;
use App\Services\MetalWatchlistNotificationService;

class SendMetalRateCreatedNotification
{
    public function __construct(
        private readonly MetalWatchlistNotificationService $notificationService
    ) {
    }

    public function handle(MetalRateCreated $event): void
    {
        $this->notificationService->notifyMetalCreated(
            $event->metalId,
            $event->quotes,
            $event->defaultGovernorateId
        );
    }
}