<?php

namespace App\Jobs;

use App\Models\Campaign;
use App\Models\CampaignEvent;
use App\Services\MarketingNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class DispatchCampaignNotifications implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public function __construct(public Campaign $campaign, public ?CampaignEvent $event = null)
    {
    }

    public function handle(MarketingNotificationService $marketingNotificationService): void
    {
        $marketingNotificationService->dispatchCampaign(
            $this->campaign->fresh(),
            $this->event?->fresh()
        );
    }
}