<?php

namespace App\Listeners;
use App\Models\Order;

use App\Events\OrderStatusChanged;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use Illuminate\Support\Facades\Log;

class SendOrderStatusChangedNotification
{
    public function handle(OrderStatusChanged $event): void
    {
        $order = $event->order;

        $tokens = UserFcmToken::query()
            ->where('user_id', $order->user_id)
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $title = __('تحديث حالة الطلب');
        $statusLabel = Order::statusLabel($order->order_status);

        $body = __('تم تحديث حالة طلبك إلى :status.', [
            'status' => $statusLabel,
        ]);

        $trackingPath = sprintf('orders/%s', $order->getKey());



        try {
            NotificationService::sendFcmNotification(
                $tokens,
                $title,
                $body,
                'order-status-update',
                [
                    'order_id' => $order->getKey(),
                    'status' => $order->order_status,
                    'status_label' => $statusLabel,
                    'status_icon' => Order::statusIcon($order->order_status),
                    'status_message' => Order::statusTimelineMessage($order->order_status),


                    'deeplink' => $trackingPath,
                    'click_action' => $trackingPath,
                ]
            );
        } catch (\Throwable $exception) {
            Log::error('orders.status_change_notification_failed', [
                'order_id' => $order->getKey(),
                'error' => $exception->getMessage(),
            ]);
        }
    }
}