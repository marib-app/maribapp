<?php

namespace Tests\Feature;

use App\Jobs\DispatchCampaignNotifications;
use App\Models\Campaign;
use App\Services\MarketingNotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Tests\TestCase;

class TriggerEventCampaignTest extends TestCase
{
    use RefreshDatabase;

    public function test_draft_event_campaigns_are_not_triggered_until_active(): void


    {
        Bus::fake();

        $campaign = Campaign::create([
            'name' => 'Draft Event Campaign',
            'status' => Campaign::STATUS_DRAFT,
            'trigger_type' => Campaign::TRIGGER_EVENT,
            'event_key' => 'user.registered',
            'notification_title' => 'Welcome',
            'notification_body' => 'Hello there!',
        ]);

        app(MarketingNotificationService::class)->triggerEventCampaigns('user.registered');

        Bus::assertNotDispatched(DispatchCampaignNotifications::class);
        $this->assertDatabaseCount('campaign_events', 0);


        $campaign->update(['status' => Campaign::STATUS_ACTIVE]);

        app(MarketingNotificationService::class)->triggerEventCampaigns('user.registered');

        Bus::assertDispatched(DispatchCampaignNotifications::class);
        $this->assertDatabaseHas('campaign_events', [
            'campaign_id' => $campaign->id,
            'event_type' => 'user.registered',
        ]);

    }

    public function test_active_event_campaigns_are_triggered(): void
    {
        Bus::fake();

        $campaign = Campaign::create([
            'name' => 'Active Event Campaign',
            'status' => Campaign::STATUS_ACTIVE,
            'trigger_type' => Campaign::TRIGGER_EVENT,
            'event_key' => 'user.registered',
            'notification_title' => 'Welcome',
            'notification_body' => 'Hello there!',
        ]);

        app(MarketingNotificationService::class)->triggerEventCampaigns('user.registered', ['foo' => 'bar']);

        Bus::assertDispatched(function (DispatchCampaignNotifications $job) use ($campaign) {
            return (int) $job->campaign->id === (int) $campaign->id
                && $job->event !== null
                && $job->event->event_type === 'user.registered';
        });

        $this->assertDatabaseHas('campaign_events', [
            'campaign_id' => $campaign->id,
            'event_type' => 'user.registered',
        ]);
    }
}