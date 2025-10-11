<?php

namespace App\Services;
use App\Events\OrderNoteUpdated;

use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\SheinOrderBatch;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SheinOrderBatchService
{
    public function createBatch(array $data, int $userId): SheinOrderBatch
    {
        return DB::transaction(function () use ($data, $userId) {
            $payload = Arr::only($data, [
                'reference',
                'batch_date',
                'status',
                'deposit_amount',
                'outstanding_amount',
                'notes',
                'closed_at',
            ]);

            $payload['created_by'] = $userId;

            return SheinOrderBatch::create($payload);
        });
    }

    public function assignOrders(SheinOrderBatch $batch, array $orderIds): int
    {
        $ids = $this->sanitizeOrderIds($orderIds);

        if ($ids->isEmpty()) {
            return 0;
        }

        return (int) Order::query()
            ->whereIn('id', $ids)
            ->where('department', 'shein')
            ->update(['shein_batch_id' => $batch->id]);
    }

    public function bulkUpdateOrders(
        SheinOrderBatch $batch,
        array $orderIds,
        array $payload,
        int $userId,
        bool $notifyCustomer = false
    ): int {
        $ids = $this->sanitizeOrderIds($orderIds);

        if ($ids->isEmpty()) {
            return 0;
        }

        $orders = Order::query()
            ->where('shein_batch_id', $batch->id)
            ->whereIn('id', $ids)
            ->with('paymentTransactions')

            ->get();

        if ($orders->isEmpty()) {
            return 0;
        }

        $updates = [];

        if (array_key_exists('order_status', $payload) && filled($payload['order_status'])) {
            $updates['order_status'] = (string) $payload['order_status'];
        }

        if (array_key_exists('notes', $payload)) {
            $updates['notes'] = $payload['notes'];
        }

        if ($updates === []) {
            return 0;
        }


       if (isset($updates['order_status'])) {
            $unpaidOrders = $orders->filter(static function (Order $order): bool {
                return ! $order->hasSuccessfulPayment();
            });

            if ($unpaidOrders->isNotEmpty()) {
                $orderIdentifiers = $unpaidOrders
                    ->map(static function (Order $order) {
                        return $order->order_number ?? $order->getKey();
                    })
                    ->unique()
                    ->values()
                    ->implode('، ');

                throw ValidationException::withMessages([
                    'order_status' => __('لا يمكن تحديث حالة الطلب للطلبات التالية قبل إتمام الدفع بنجاح: :orders.', [
                        'orders' => $orderIdentifiers,
                    ]),
                ]);
            }
        }


        $comment = $payload['comment'] ?? null;

        if (isset($updates['order_status'])) {
            $unpaidOrders = $orders->filter(static function (Order $order): bool {
                return ! $order->hasSuccessfulPayment();
            });

            if ($unpaidOrders->isNotEmpty()) {
                $orderIdentifiers = $unpaidOrders
                    ->map(static function (Order $order) {
                        return $order->order_number ?? $order->getKey();
                    })
                    ->unique()
                    ->values()
                    ->implode('، ');

                throw ValidationException::withMessages([
                    'order_status' => __('لا يمكن تحديث حالة الطلب قبل تأكيد الدفع بنجاح للطلبات التالية: :orders.', [
                        'orders' => $orderIdentifiers,
                    ]),
                ]);
            }
        }

        DB::transaction(function () use ($orders, $updates, $comment, $userId, $notifyCustomer) {
            foreach ($orders as $order) {
                $previousStatus = $order->order_status;

                if (isset($updates['order_status'])) {
                    $order->withStatusContext($userId, $comment);
                }

                $order->fill($updates);


                $noteWasUpdated = $order->isDirty('notes');
                $updatedNote = $order->notes;


                if (($updates['order_status'] ?? null) === Order::STATUS_DELIVERED) {
                    $order->completed_at = $order->completed_at ?? now();
                }

                $order->save();


                if ($noteWasUpdated && filled($updatedNote)) {
                    event(new OrderNoteUpdated(
                        $order->fresh('user'),
                        $updatedNote,
                        $userId,
                        'order_note'
                    ));
                }


                if (isset($updates['order_status']) && $previousStatus !== $updates['order_status']) {
                    OrderHistory::create([
                        'order_id' => $order->id,
                        'user_id' => $userId,
                        'status_from' => $previousStatus,
                        'status_to' => $updates['order_status'],
                        'comment' => $comment,
                        'notify_customer' => $notifyCustomer,
                    ]);


                    if ($notifyCustomer && filled($comment)) {
                        event(new OrderNoteUpdated(
                            $order->fresh('user'),
                            $comment,
                            $userId,
                            'history_comment'
                        ));
                    }

                }
            }
        });

        return $orders->count();
    }

    protected function sanitizeOrderIds(array $orderIds): Collection
    {
        return collect($orderIds)
            ->filter(static fn ($id) => is_numeric($id) && (int) $id > 0)
            ->map(static fn ($id) => (int) $id)
            ->unique();
    }
}