<?php

namespace App\Events;

use App\Models\ManualPaymentRequest;
use App\Models\Order;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ManualPaymentRequestCreated
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    public function __construct(public ManualPaymentRequest $manualPaymentRequest)
    {
    }

    public function department(): ?string
    {
        $department = $this->manualPaymentRequest->department;
        $department = $this->normalizeDepartment($this->manualPaymentRequest->department);

        if ($department !== null) {
            return $department;
        }

        $payable = $this->manualPaymentRequest->payable;

        if ($payable instanceof Order) {
            $department = $this->normalizeDepartment($payable->department);

            if ($department !== null) {
                return $department;
            }
        }

        $payableType = $this->manualPaymentRequest->payable_type;

        if (! ManualPaymentRequest::isOrderPayableType($payableType)) {
            return null;
        }

        $payableId = $this->manualPaymentRequest->payable_id;

        if (! is_numeric($payableId)) {
            return null;
        }

        $department = Order::query()
            ->whereKey((int) $payableId)
            ->value('department');

        return $this->normalizeDepartment($department);
    }

    private function normalizeDepartment(mixed $value): ?string
    {
        if (! is_string($value)) {
            return null;

        
        }
        
        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }
}