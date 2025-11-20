<?php

namespace Tests\Unit\Notifications;

use App\Jobs\SendFcmMessageJob;
use App\Models\NotificationDelivery;
use App\Models\User;
use App\Models\UserFcmToken;
use App\Services\FcmClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

class SendFcmMessageJobTest extends TestCase
{
    use RefreshDatabase;

    public function test_job_sends_payload_and_marks_delivery(): void
    {
        $user = User::factory()->create();
        $delivery = NotificationDelivery::factory()->create([
            'user_id' => $user->id,
            'payload' => [
                'id' => null,
                'type' => 'payment.request',
                'title' => 'Test',
                'body' => 'Body',
                'deeplink' => 'marib://wallet/request',
                'collapse_key' => 'wallet:123',
                'ttl' => 1800,
                'priority' => 'high',
                'data' => [
                    'entity' => 'wallet',
                    'entity_id' => '123',
                ],
            ],
        ]);

        $payload = $delivery->payload;
        $payload['id'] = (string) $delivery->id;
        $delivery->payload = $payload;
        $delivery->save();

        UserFcmToken::create([
            'user_id' => $user->id,
            'fcm_token' => 'test-token',
        ]);

        $client = Mockery::mock(FcmClient::class);
        $client->shouldReceive('send')
            ->once()
            ->andReturn(['error' => false, 'message' => 'ok']);

        app()->instance(FcmClient::class, $client);

        $job = new SendFcmMessageJob($delivery->id);
        $job->handle(app(FcmClient::class));

        $delivery->refresh();
        $this->assertEquals(NotificationDelivery::STATUS_DELIVERED, $delivery->status);
        $this->assertNotNull($delivery->delivered_at);
        $this->assertEquals('ok', $delivery->meta['send_result']['message'] ?? null);
    }
}
