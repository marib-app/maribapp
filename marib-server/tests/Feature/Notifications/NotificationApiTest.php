<?php

namespace Tests\Feature\Notifications;

use App\Models\ActionRequest;
use App\Models\NotificationDelivery;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['notification.cache_store' => 'array']);
        Cache::store('array')->flush();
    }

    public function test_notifications_index_returns_paginated_list(): void
    {
        $user = User::factory()->create();
        $deliveries = NotificationDelivery::factory()->count(3)->create([
            'user_id' => $user->id,
        ]);
        $deliveries->first()->update(['opened_at' => now()]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/notifications?per_page=2');
        $response->assertOk()
            ->assertJsonStructure([
                'data',
                'pagination' => ['has_more', 'next_since', 'per_page'],
                'unread_count',
            ]);

        $this->assertEquals(2, $response->json('pagination.per_page'));
        $this->assertEquals(2, $response->json('unread_count'));
        $this->assertCount(2, $response->json('data'));
    }

    public function test_mark_read_updates_opened_at_and_unread_count(): void
    {
        $user = User::factory()->create();
        $deliveries = NotificationDelivery::factory()->count(2)->create([
            'user_id' => $user->id,
        ]);

        Sanctum::actingAs($user);

        $ids = $deliveries->pluck('id')->all();
        $response = $this->postJson('/api/notifications/mark-read', [
            'ids' => $ids,
            'mark_clicked' => true,
        ]);

        $response->assertOk();
        $this->assertEquals(2, $response->json('updated'));
        $this->assertEquals(0, $response->json('unread_count'));

        $this->assertDatabaseMissing('notification_deliveries', [
            'id' => $ids[0],
            'opened_at' => null,
        ]);
        $this->assertDatabaseMissing('notification_deliveries', [
            'id' => $ids[1],
            'clicked_at' => null,
        ]);
    }

    public function test_mark_all_read_clears_unread_count(): void
    {
        $user = User::factory()->create();
        NotificationDelivery::factory()->count(3)->create([
            'user_id' => $user->id,
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/notifications/mark-all-read');
        $response->assertOk();
        $this->assertEquals(3, $response->json('updated'));
        $this->assertEquals(0, $response->json('unread_count'));
    }

    public function test_notification_preferences_can_be_upserted(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $payload = [
            'preferences' => [
                [
                    'type' => 'payment.request',
                    'enabled' => false,
                    'sound' => false,
                    'channel' => 'push',
                    'frequency' => 'instant',
                ],
            ],
        ];

        $response = $this->postJson('/api/notification-preferences', $payload);
        $response->assertOk();
        $this->assertDatabaseHas('notification_preferences', [
            'user_id' => $user->id,
            'type' => 'payment.request',
            'enabled' => false,
        ]);

        $listResponse = $this->getJson('/api/notification-preferences');
        $listResponse->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_topic_subscription_endpoints(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $subscribe = $this->postJson('/api/topics/subscribe', ['topic' => 'cur-USD']);
        $subscribe->assertOk()->assertJson([
            'subscribed' => true,
            'topic' => 'cur-usd',
        ]);

        $this->assertDatabaseHas('notification_topic_subscriptions', [
            'user_id' => $user->id,
            'topic' => 'cur-usd',
        ]);

        $unsubscribe = $this->postJson('/api/topics/unsubscribe', ['topic' => 'cur-usd']);
        $unsubscribe->assertOk()->assertJson([
            'subscribed' => false,
        ]);

        $this->assertDatabaseMissing('notification_topic_subscriptions', [
            'user_id' => $user->id,
            'topic' => 'cur-usd',
        ]);
    }

    public function test_action_request_show_and_perform(): void
    {
        $user = User::factory()->create();
        $actionRequest = ActionRequest::create([
            'id' => (string) Str::uuid(),
            'user_id' => $user->id,
            'kind' => 'payment.request',
            'entity' => 'wallet',
            'entity_id' => 'tx-123',
            'amount' => 1200,
            'currency' => 'YER',
            'status' => 'pending',
            'due_at' => now()->addHour(),
            'expires_at' => now()->addHours(2),
            'meta' => ['note' => 'test'],
            'hmac_token' => 'secure-token',
        ]);

        Sanctum::actingAs($user);

        $show = $this->getJson('/api/action-requests/' . $actionRequest->id . '?token=secure-token');
        $show->assertOk()->assertJsonPath('data.id', $actionRequest->id);

        $perform = $this->postJson(
            '/api/action-requests/' . $actionRequest->id . '/perform?token=secure-token',
            [],
            ['Idempotency-Key' => 'unique-key-1']
        );
        $perform->assertOk()->assertJson(['success' => true]);

        $this->assertDatabaseHas('action_requests', [
            'id' => $actionRequest->id,
            'status' => 'completed',
        ]);

        $duplicate = $this->postJson(
            '/api/action-requests/' . $actionRequest->id . '/perform?token=secure-token',
            [],
            ['Idempotency-Key' => 'unique-key-1']
        );
        $duplicate->assertStatus(409);
    }
}
