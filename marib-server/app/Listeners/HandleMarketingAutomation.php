<?php

namespace App\Listeners;

use App\Events\CompetitionAnnounced;
use App\Events\SubscriptionExpired;
use App\Events\UserWentInactive;
use App\Services\MarketingNotificationService;

class HandleMarketingAutomation
{
    public function __construct(private MarketingNotificationService $marketingNotificationService)
    {
    }

    public function handle(object $event): void
    {
        if ($event instanceof UserWentInactive) {
            $this->marketingNotificationService->triggerEventCampaigns('user.inactive', $event->context());
            return;
        }

        if ($event instanceof SubscriptionExpired) {
            $this->marketingNotificationService->triggerEventCampaigns('subscription.expired', $event->context());
            return;
        }

        if ($event instanceof CompetitionAnnounced) {
            $this->marketingNotificationService->triggerEventCampaigns('competition.announced', $event->context());
        }
    }
}