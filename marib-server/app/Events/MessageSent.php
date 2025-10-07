<?php

namespace App\Events;

use App\Models\Chat;
use App\Models\ChatMessage;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public int $conversationId;

    /**
     * @var array<string, mixed>
     */
    public array $message;

    public function __construct(public Chat $conversation, public ChatMessage $chatMessage)
    {
        $this->conversationId = $conversation->id;
        $this->message = $chatMessage->load('sender')->toArray();
        $this->message['conversation_id'] = $conversation->id;
    }

    public function broadcastOn(): PresenceChannel
    {
        return new PresenceChannel('chat.conversation.' . $this->conversationId);
    }

    public function broadcastWith(): array
    {
        return [
            'conversation_id' => $this->conversationId,
            'message' => $this->message,
        ];
    }
}