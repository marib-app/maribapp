<?php

namespace App\Events;

use App\Models\Chat;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class UserPresenceUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public int $conversationId;

    /**
     * @var array<string, mixed>
     */
    public array $user;

    public bool $isOnline;

    public string $lastSeenAt;

    public function __construct(public Chat $conversation, public User $userModel, public bool $online, public Carbon $timestamp)
    {
        $this->conversationId = $conversation->id;
        $this->user = [
            'id' => $userModel->id,
            'name' => $userModel->name,
            'profile' => $userModel->profile,
        ];
        $this->isOnline = $online;
        $this->lastSeenAt = $timestamp->toISOString();
    }

    public function broadcastOn(): PresenceChannel
    {
        return new PresenceChannel('chat.conversation.' . $this->conversationId);
    }

    public function broadcastWith(): array
    {
        return [
            'conversation_id' => $this->conversationId,
            'user' => $this->user,
            'is_online' => $this->isOnline,
            'last_seen_at' => $this->lastSeenAt,
        ];
    }
}