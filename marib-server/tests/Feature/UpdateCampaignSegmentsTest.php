<?php

namespace Tests\Feature;
use App\Models\NotificationDelivery;
use App\Models\User;
use App\Models\UserFcmToken;
use App\Models\Campaign;
use App\Services\MarketingNotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use Mockery;


class UpdateCampaignSegmentsTest extends TestCase
{
    use RefreshDatabase;


        protected function tearDown(): void
    {
        Mockery::close();

        parent::tearDown();
    }


    public function test_updating_campaign_with_empty_segments_removes_existing_segments(): void
    {
        $service = app(MarketingNotificationService::class);

        $campaign = Campaign::create([
            'name' => 'Initial Campaign',
            'status' => Campaign::STATUS_DRAFT,
            'trigger_type' => Campaign::TRIGGER_MANUAL,
            'notification_title' => 'Initial Title',
            'notification_body' => 'Initial Body',
        ]);

        $service->syncSegments($campaign, [
            [
                'name' => 'First Segment',
                'description' => 'Segment A',
                'filters' => [],
            ],
            [
                'name' => 'Second Segment',
                'filters' => [],
            ],
        ]);

        $this->assertDatabaseCount('campaign_segments', 2);

        $updatedCampaign = $service->updateCampaign($campaign, [
            'name' => 'Updated Campaign',
            'status' => Campaign::STATUS_DRAFT,
            'trigger_type' => Campaign::TRIGGER_MANUAL,
            'notification_title' => 'Updated Title',
            'notification_body' => 'Updated Body',
        ], []);

        $this->assertCount(0, $updatedCampaign->segments);
        $this->assertDatabaseCount('campaign_segments', 0);
    }




        public function test_updating_campaign_with_empty_segments_targets_all_users(): void
    {
        $service = app(MarketingNotificationService::class);

        $campaign = Campaign::create([
            'name' => 'Audience Campaign',
            'status' => Campaign::STATUS_DRAFT,
            'trigger_type' => Campaign::TRIGGER_MANUAL,
            'notification_title' => 'Audience Title',
            'notification_body' => 'Audience Body',
        ]);

        $service->syncSegments($campaign, [[
            'name' => 'Existing Segment',
            'description' => 'Should be removed',
            'filters' => [],
        ]]);

        $targetTokens = [];
        $targetUsers = collect();

        foreach (range(1, 2) as $index) {
            $user = User::factory()->create([
                'type' => 'email',
                'fcm_id' => "legacy-token-{$index}",
                'notification' => 1,
                'account_type' => User::ACCOUNT_TYPE_CUSTOMER,
            ]);

            $token = "device-token-{$index}";

            $targetUsers->push($user);
            $targetTokens[] = $token;

            UserFcmToken::create([
                'user_id' => $user->id,
                'fcm_token' => $token,
                'platform_type' => 'Android',
            ]);
        }

        $excludedUser = User::factory()->create([
            'type' => 'email',
            'fcm_id' => 'legacy-token-excluded',
            'notification' => 0,
            'account_type' => User::ACCOUNT_TYPE_CUSTOMER,
        ]);

        UserFcmToken::create([
            'user_id' => $excludedUser->id,
            'fcm_token' => 'device-token-excluded',
            'platform_type' => 'Android',
        ]);

        $service->updateCampaign($campaign, [
            'name' => 'Audience Campaign Updated',
            'status' => Campaign::STATUS_DRAFT,
            'trigger_type' => Campaign::TRIGGER_MANUAL,
            'notification_title' => 'Audience Title Updated',
            'notification_body' => 'Audience Body Updated',
        ], []);

        $this->assertDatabaseCount('campaign_segments', 0);

        $notificationMock = Mockery::mock('alias:App\\Services\\NotificationService');
        $notificationMock->shouldReceive('sendFcmNotification')
            ->once()
            ->withArgs(function (array $tokens, string $title, string $body, string $type, array $payload) use ($campaign, $targetTokens) {
                $this->assertEqualsCanonicalizing($targetTokens, $tokens);
                $this->assertSame('campaign', $type);
                $this->assertSame('Audience Title Updated', $title);
                $this->assertSame('Audience Body Updated', $body);
                $this->assertSame((string) $campaign->id, $payload['campaign_id'] ?? null);

                return true;
            })
            ->andReturn(['error' => false]);

        $service->dispatchCampaign($campaign->fresh());

        $this->assertDatabaseCount('notification_deliveries', count($targetTokens));

        foreach ($targetUsers as $user) {
            $this->assertDatabaseHas('notification_deliveries', [
                'campaign_id' => $campaign->id,
                'user_id' => $user->id,
                'segment_id' => null,
                'status' => NotificationDelivery::STATUS_SENT,
            ]);
        }

        $this->assertDatabaseMissing('notification_deliveries', [
            'campaign_id' => $campaign->id,
            'user_id' => $excludedUser->id,
        ]);
    }

}