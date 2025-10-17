<?php

namespace App\Notifications\Channels;

use App\Services\NotificationService;
use Illuminate\Notifications\Notification;

class FcmChannel
{
    public function send(object $notifiable, Notification $notification): void
    {
        if (!method_exists($notification, 'toFcm')) {
            return;
        }

        $message = $notification->toFcm($notifiable);

        $tokens = $this->resolveTokens($notifiable);

        if (empty($tokens)) {
            return;
        }

        $title = (string) ($message['title'] ?? '');
        $body = (string) ($message['body'] ?? '');
        $type = (string) ($message['type'] ?? 'default');
        $data = (array) ($message['data'] ?? []);

        NotificationService::sendFcmNotification($tokens, $title, $body, $type, $data);
    }

    private function resolveTokens(object $notifiable): array
    {
        $tokens = collect();

        if (method_exists($notifiable, 'relationLoaded') && $notifiable->relationLoaded('fcm_tokens')) {
            $tokens = $notifiable->fcm_tokens->pluck('fcm_token');
        } elseif (method_exists($notifiable, 'fcm_tokens')) {
            $tokens = $notifiable->fcm_tokens()->pluck('fcm_token');
        }

        return $tokens
            ->filter()
            ->unique()
            ->values()
            ->all();
    }
}