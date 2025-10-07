<?php

namespace App\Events;

use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class AdminEvent implements ShouldBroadcastNow
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    /**
     * @var array<string, mixed>
     */
    public array $payload;

    /**
     * @param  array<string, mixed>  $payload
     */
    public function __construct(array $payload)
    {
        $this->payload = $payload;
    }

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel('admin.dashboard');
    }

    public function broadcastAs(): string
    {
        return 'AdminEvent';
    }

    public function broadcastWith(): array
    {
        return $this->payload;
    }
}