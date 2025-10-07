<?php

namespace App\Events;

use App\Models\Order;
use Carbon\Carbon;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class OrderStatusChanged
{
    use Dispatchable;
    use SerializesModels;

    public Carbon $recordedAt;

    public function __construct(
        public Order $order,
        public ?string $previousStatus,
        public string $currentStatus,
        ?Carbon $recordedAt = null,
    ) {
        $this->recordedAt = $recordedAt ?? now();
    }
}