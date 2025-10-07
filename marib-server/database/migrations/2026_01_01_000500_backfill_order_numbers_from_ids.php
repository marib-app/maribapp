<?php

use App\Models\Order;
use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    public function up(): void
    {
        Order::query()
            ->select(['id', 'order_number', 'department'])
            ->orderBy('id')
            ->chunkById(500, function ($orders): void {
                foreach ($orders as $order) {
                    $expected = Order::formatOrderNumber((int) $order->id, $order->department, $order->order_number);

                    if ($order->order_number === $expected) {
                        continue;
                    }

                    Order::query()
                        ->whereKey($order->id)
                        ->update(['order_number' => $expected]);
                }
            });
    }

    public function down(): void
    {
        // لا توجد حاجة للتراجع عن تصحيح البيانات هذا.
    }
    };