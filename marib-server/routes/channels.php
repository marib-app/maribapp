<?php

use Illuminate\Support\Facades\Broadcast;
use App\Models\Chat;
use Carbon\Carbon;
/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
|
| Here you may register all of the event broadcasting channels that your
| application supports. The given channel authorization callbacks are
| used to check if an authenticated user can listen to the channel.
|
*/

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});


Broadcast::channel('chat.conversation.{conversationId}', function ($user, int $conversationId) {
    $conversation = Chat::query()
        ->whereKey($conversationId)
        ->whereHas('participants', static function ($query) use ($user) {
            $query->where('user_id', $user->id);
        })
        ->first();

    if (!$conversation) {
        return false;
    }

    $participant = $conversation->participants()
        ->where('users.id', $user->id)
        ->first();

    if (!$participant) {
        return false;
    }

    $lastSeenAt = $participant->pivot->last_seen_at
        ? Carbon::parse($participant->pivot->last_seen_at)->toISOString()
        : null;

    $lastTypingAt = $participant->pivot->last_typing_at
        ? Carbon::parse($participant->pivot->last_typing_at)->toISOString()
        : null;

    return [
        'id' => $user->id,
        'name' => $user->name,
        'profile' => $user->profile,
        'is_online' => (bool) $participant->pivot->is_online,
        'last_seen_at' => $lastSeenAt,
        'is_typing' => (bool) $participant->pivot->is_typing,
        'last_typing_at' => $lastTypingAt,
    ];

});

Broadcast::channel('admin.notifications', function ($user) {
    return $user->can('notification-list');



});

Broadcast::channel('admin.dashboard', function ($user) {
    if (!$user) {
        return false;
    }

    if (method_exists($user, 'tokenCan') && $user->tokenCan('dashboard-view')) {
        return true;
    }

    if (method_exists($user, 'can') && $user->can('dashboard-view')) {
        return true;
    }

    return false;

});