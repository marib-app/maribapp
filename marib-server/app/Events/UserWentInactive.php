<?php

namespace App\Events;

use App\Models\User;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class UserWentInactive
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    public function __construct(public User $user, public ?int $daysInactive = null)
    {
    }

    public function context(): array
    {
        return [
            'user_id' => $this->user->id,
            'days_inactive' => $this->daysInactive,
        ];
    }
}