<?php

namespace App\Listeners;

use App\Events\OrderNoteUpdated;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class SendOrderNoteNotification
{
    public function handle(OrderNoteUpdated $event): void
    {
        $order = $event->order;
        $user = $order->user;

        if ($user === null) {
            return;
        }

        $note = trim((string) $event->note);

        if ($note === '') {
            return;
        }

        $tokens = UserFcmToken::query()
            ->where('user_id', $user->getKey())
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        $title = __('تحديث على ملاحظات طلبك');
        $body = $note;
        $data = [
            'order_id' => $order->getKey(),
            'note' => $note,
            'origin' => $event->origin,
        ];

        if ($tokens !== []) {
            try {
                NotificationService::sendFcmNotification(
                    $tokens,
                    $title,
                    $body,
                    'order-note-update',
                    $data
                );
            } catch (\Throwable $exception) {
                Log::error('orders.note_notification_failed', [
                    'order_id' => $order->getKey(),
                    'error' => $exception->getMessage(),
                ]);
            }

            return;
        }

        if (filled($user->email)) {
            Mail::raw($body, static function ($message) use ($user, $title) {
                $message->to($user->email, $user->name ?? null)
                    ->subject($title);
            });
        }
    }
}