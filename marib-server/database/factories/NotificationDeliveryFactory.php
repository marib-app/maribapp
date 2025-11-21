<?php

namespace Database\Factories;

use App\Models\NotificationDelivery;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class NotificationDeliveryFactory extends Factory
{
    protected $model = NotificationDelivery::class;

    public function configure()
    {
        return $this->afterCreating(function (NotificationDelivery $delivery): void {
            $payload = $delivery->payload ?? [];
            $payload['id'] = (string) $delivery->id;
            $delivery->forceFill(['payload' => $payload])->save();
        });
    }

    public function definition(): array
    {
        $type = $this->faker->randomElement(['payment.request', 'order.status', 'wallet.alert']);
        $entity = $this->faker->randomElement(['order', 'wallet']);
        $entityId = (string) $this->faker->numberBetween(1, 99999);
        $fingerprint = hash('sha256', implode(':', [$this->faker->randomNumber(), $type, $entity, $entityId]));

        return [
            'user_id' => User::factory(),
            'type' => $type,
            'fingerprint' => $fingerprint,
            'collapse_key' => sprintf('%s:%s', $entity, $entityId),
            'deeplink' => 'marib://inbox',
            'priority' => 'high',
            'ttl' => 1800,
            'status' => NotificationDelivery::STATUS_QUEUED,
            'meta' => [],
            'payload' => [
                'id' => null,
                'type' => $type,
                'title' => $this->faker->sentence(3),
                'body' => $this->faker->sentence(8),
                'deeplink' => 'marib://inbox',
                'collapse_key' => sprintf('%s:%s', $entity, $entityId),
                'ttl' => 1800,
                'priority' => 'high',
                'data' => [
                    'entity' => $entity,
                    'entity_id' => $entityId,
                ],
            ],
        ];
    }
}
