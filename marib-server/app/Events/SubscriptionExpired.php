<?php

namespace App\Events;

use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class SubscriptionExpired
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    public function __construct(public User $user, public ?string $packageName = null, public ?CarbonInterface $expiredAt = null)
    {
    }

    public function context(): array
    {
        return [
            'user_id' => $this->user->id,
            'package' => $this->packageName,
            'expired_at' => $this->expiredAt?->toDateTimeString(),
        ];
    }
}