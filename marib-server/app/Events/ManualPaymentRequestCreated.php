<?php

namespace App\Events;

use App\Models\ManualPaymentRequest;
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

        if (is_string($department) && trim($department) !== '') {
            return $department;
        }

        $payableDepartment = $this->manualPaymentRequest->payable?->department;

        return is_string($payableDepartment) && trim($payableDepartment) !== ''
            ? $payableDepartment
            : null;
        
        }
}