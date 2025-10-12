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

        return is_string($department) && $department !== '' ? $department : null;
    }
}