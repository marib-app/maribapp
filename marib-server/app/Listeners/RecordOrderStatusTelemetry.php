<?php

namespace App\Listeners;

use App\Events\OrderStatusChanged;
use App\Models\Order;
use App\Services\TelemetryService;

class RecordOrderStatusTelemetry
{


    public function __construct(private readonly TelemetryService $telemetry)
    {
    }


    public function handle(OrderStatusChanged $event): void
    {
        $this->telemetry->record('orders.status_changed', [
            'order_id' => $event->order->getKey(),
            'user_id' => $event->order->user_id,
            'status_from' => $event->previousStatus,
            'status_from_label' => $event->previousStatus ? Order::statusLabel($event->previousStatus) : null,
            'status_to' => $event->currentStatus,
            'status_to_label' => Order::statusLabel($event->currentStatus),
            'recorded_at' => $event->recordedAt->toIso8601String(),
        ]);
    }
}