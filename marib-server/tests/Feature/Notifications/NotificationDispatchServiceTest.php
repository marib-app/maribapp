<?php

namespace Tests\Feature\Notifications;

use App\Data\Notifications\NotificationIntent;
use App\Enums\NotificationDispatchStatus;
use App\Enums\NotificationType;
use App\Jobs\SendFcmMessageJob;
use App\Models\NotificationDelivery;
use App\Models\User;
use App\Services\NotificationDispatchService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

class NotificationDispatchServiceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['notification.cache_store' => 'array']);
        Cache::store('array')->flush();
    }

    public function test_it_queues_delivery_and_job(): void
    {
        Bus::fake();
        $user = User::factory()->create();

        $intent = new NotificationIntent(
            userId: $user->id,
            type: NotificationType::PaymentRequest,
            title: 'طلب دفع',
            body: 'الرجاء إكمال الدفع.',
            deeplink: 'marib://wallet/request',
            entity: 'wallet',
            entityId: 'tx-100',
            data: ['amount' => 25000, 'currency' => 'YER']
        );

        $service = app(NotificationDispatchService::class);
        $result = $service->dispatch($intent);

        $this->assertEquals(NotificationDispatchStatus::Queued, $result->status);
        $this->assertNotNull($result->delivery);
        $this->assertDatabaseHas('notification_deliveries', [
            'id' => $result->delivery->id,
            'user_id' => $user->id,
            'type' => NotificationType::PaymentRequest->value,
            'collapse_key' => 'wallet:tx-100',
        ]);

        Bus::assertDispatched(SendFcmMessageJob::class, function (SendFcmMessageJob $job) use ($result) {
            return $job->deliveryId === $result->delivery?->id;
        });
    }

    public function test_dedupe_prevents_duplicate_deliveries(): void
    {
        Bus::fake();
        config(['notification.types.' . NotificationType::PaymentRequest->value . '.dedupe_ttl' => 3600]);

        $user = User::factory()->create();
        $intent = new NotificationIntent(
            userId: $user->id,
            type: NotificationType::PaymentRequest,
            title: 'طلب دفع',
            body: 'مرحباً',
            deeplink: 'marib://wallet/request',
            entity: 'wallet',
            entityId: 'tx-200',
            data: ['amount' => 1000]
        );

        $service = app(NotificationDispatchService::class);
        $first = $service->dispatch($intent);
        $this->assertEquals(NotificationDispatchStatus::Queued, $first->status);

        $second = $service->dispatch($intent);
        $this->assertEquals(NotificationDispatchStatus::Deduplicated, $second->status);

        $this->assertEquals(1, NotificationDelivery::query()->count());
    }

    public function test_throttle_prevents_rapid_repeats(): void
    {
        Bus::fake();
        config(['notification.types.' . NotificationType::PaymentRequest->value . '.throttle_ttl' => 600]);
        config(['notification.types.' . NotificationType::PaymentRequest->value . '.dedupe_ttl' => 0]);

        $user = User::factory()->create();
        $intent = new NotificationIntent(
            userId: $user->id,
            type: NotificationType::PaymentRequest,
            title: 'طلب دفع',
            body: 'مرحباً',
            deeplink: 'marib://wallet/request',
            entity: 'wallet',
            entityId: 'tx-300',
            data: ['amount' => 1200]
        );

        $service = app(NotificationDispatchService::class);
        $first = $service->dispatch($intent);
        $this->assertEquals(NotificationDispatchStatus::Queued, $first->status);

        $secondIntent = new NotificationIntent(
            userId: $user->id,
            type: NotificationType::PaymentRequest,
            title: 'طلب دفع',
            body: 'مرحباً',
            deeplink: 'marib://wallet/request',
            entity: 'wallet',
            entityId: 'tx-301',
            data: ['amount' => 1300]
        );

        $second = $service->dispatch($secondIntent);
        $this->assertEquals(NotificationDispatchStatus::Throttled, $second->status);

        $this->assertEquals(1, NotificationDelivery::query()->count());
    }
}
