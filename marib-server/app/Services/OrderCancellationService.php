<?php

namespace App\Services;

use App\Models\Order;
use App\Models\OrderHistory;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class OrderCancellationService
{
    public const HISTORY_COMMENT = 'تم إلغاء الطلب بناءً على طلب العميل.';

    public function __construct(private readonly OrderDepositRefundService $depositRefundService)
    {
    }

    public function cancel(Order $order, ?int $userId = null, ?string $comment = null): Order
    {
        return DB::transaction(function () use ($order, $userId, $comment) {
            $order->loadMissing(['items', 'user']);
            $previousStatus = $order->order_status;

            foreach ($order->items as $orderItem) {
                try {
                    $this->depositRefundService->compensateOrderItem($orderItem, 'order_canceled');
                } catch (Throwable $exception) {
                    Log::error('orders.cancellation.deposit_refund_failed', [
                        'order_id' => $order->getKey(),
                        'order_item_id' => $orderItem->getKey(),
                        'error' => $exception->getMessage(),
                    ]);

                    throw $exception;
                }
            }

            $order->refresh();

            $payload = $order->payment_payload;

            if (! is_array($payload)) {
                $payload = [];
            }

            unset($payload['default_intent']);

            $summary = Arr::get($payload, 'payment_summary');

            if (! is_array($summary)) {
                $summary = [];
            }

            foreach ([
                'online_outstanding',
                'goods_online_outstanding',
                'delivery_online_outstanding',
                'cod_due',
                'cod_outstanding',
                'remaining_balance',
            ] as $field) {
                $summary[$field] = 0.0;
            }

            $payload['payment_summary'] = $summary;

            $order->payment_payload = $payload;

            $historyComment = $comment ?? __(self::HISTORY_COMMENT);

            $order->withStatusContext($userId, $historyComment);
            $order->order_status = Order::STATUS_CANCELED;
            $order->payment_status = 'cancelled';
            $order->save();

            OrderHistory::create([
                'order_id' => $order->getKey(),
                'user_id' => $userId,
                'status_from' => $previousStatus,
                'status_to' => Order::STATUS_CANCELED,
                'comment' => $historyComment,
                'notify_customer' => true,
            ]);

            return $order->fresh([
                'items',
                'items.item',
                'seller',
                'coupon',
                'history.user',
                'paymentTransactions',
            ]);
        });
    }
}