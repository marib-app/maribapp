<?php

namespace App\Jobs;

use App\Data\Notifications\NotificationPayload;
use App\Models\NotificationDelivery;
use App\Models\UserFcmToken;
use App\Services\FcmClient;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendFcmMessageJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 3;

    public function __construct(public int $deliveryId)
    {
    }

    public function backoff(): array
    {
        return [30, 180, 600];
    }

    public function handle(FcmClient $client): void
    {
        $delivery = NotificationDelivery::query()->find($this->deliveryId);

        if (!$delivery) {
            Log::warning('SendFcmMessageJob: delivery not found', ['delivery_id' => $this->deliveryId]);

            return;
        }

        if (empty($delivery->payload) || !is_array($delivery->payload)) {
            Log::warning('SendFcmMessageJob: delivery missing payload', ['delivery_id' => $this->deliveryId]);

            $delivery->update([
                'status' => NotificationDelivery::STATUS_FAILED,
                'meta' => $this->mergeMeta($delivery, ['error' => 'missing_payload']),
            ]);

            return;
        }

        $payload = NotificationPayload::fromArray($delivery->payload);

        $tokens = UserFcmToken::query()
            ->where('user_id', $delivery->user_id)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if (empty($tokens)) {
            Log::info('SendFcmMessageJob: no tokens found for user', ['user_id' => $delivery->user_id]);
            $delivery->update([
                'status' => NotificationDelivery::STATUS_FAILED,
                'meta' => $this->mergeMeta($delivery, ['error' => 'missing_tokens']),
            ]);

            return;
        }

        $delivery->update([
            'status' => NotificationDelivery::STATUS_SENT,
        ]);

        $result = $client->send($tokens, $payload);
        $isError = (bool) ($result['error'] ?? false);

        $delivery->update([
            'status' => $isError ? NotificationDelivery::STATUS_FAILED : NotificationDelivery::STATUS_DELIVERED,
            'delivered_at' => $isError ? null : now(),
            'meta' => $this->mergeMeta($delivery, ['send_result' => $result]),
        ]);
    }

    protected function mergeMeta(NotificationDelivery $delivery, array $context): array
    {
        $meta = is_array($delivery->meta) ? $delivery->meta : [];

        return array_merge($meta, $context);
    }
}
