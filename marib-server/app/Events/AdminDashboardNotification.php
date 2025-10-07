<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class AdminDashboardNotification implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * @var array<string, mixed>
     */
    public array $notification;

    /**
     * Create a new event instance.
     *
     * @param  array<string, mixed>  $notification
     */
    public function __construct(array $notification)
    {
        $this->notification = $notification;
    }

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel('admin.notifications');
    }

    public function broadcastWith(): array
    {
        return [
            'notification' => $this->notification,
        ];
    }
}