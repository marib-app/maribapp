<?php

namespace App\Services;

use App\Data\Notifications\NotificationPayload;

class FcmClient
{
    /**
     * @return array<string,mixed>
     */
    public function send(array $tokens, NotificationPayload $payload): array
    {
        if (empty($tokens)) {
            return [
                'error' => true,
                'message' => 'No registration tokens supplied.',
            ];
        }

        $customFields = [
            'deeplink' => $payload->deeplink,
            'collapse_key' => $payload->collapseKey,
            'priority' => $payload->priority,
            'ttl_seconds' => $payload->ttl,
            'payload_version' => config('notification.payload_version'),
            'payload_id' => $payload->deliveryId,
        ];

        foreach ($payload->data as $key => $value) {
            $customFields[$key] = $value;
        }

        return NotificationService::sendFcmNotification(
            $tokens,
            $payload->title,
            $payload->body,
            $payload->type,
            $customFields,
            true
        );
    }
}
