<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\NotificationTopicSubscription;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

class NotificationTopicController extends Controller
{
    public function subscribe(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'topic' => ['required', 'string', 'max:64', 'regex:/^(cur|metal)-[a-z0-9_\-]+$/i'],
        ]);

        $subscription = NotificationTopicSubscription::query()->firstOrCreate([
            'user_id' => $request->user()->id,
            'topic' => strtolower($validated['topic']),
        ]);

        return response()->json([
            'subscribed' => true,
            'topic' => $subscription->topic,
            'topics' => $this->topics($request),
        ]);
    }

    public function unsubscribe(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'topic' => ['required', 'string', 'max:64', 'regex:/^(cur|metal)-[a-z0-9_\-]+$/i'],
        ]);

        NotificationTopicSubscription::query()
            ->where('user_id', $request->user()->id)
            ->where('topic', strtolower($validated['topic']))
            ->delete();

        return response()->json([
            'subscribed' => false,
            'topic' => strtolower($validated['topic']),
            'topics' => $this->topics($request),
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'topics' => $this->topics($request),
        ]);
    }

    protected function topics(Request $request): array
    {
        if (!Schema::hasTable('notification_topic_subscriptions')) {
            Log::warning('NotificationTopicController: subscriptions table missing, returning empty list');

            return [];
        }

        try {
            return NotificationTopicSubscription::query()
                ->where('user_id', $request->user()->id)
                ->orderBy('topic')
                ->pluck('topic')
                ->all();
        } catch (QueryException $exception) {
            Log::error('NotificationTopicController: failed to fetch topics', [
                'user_id' => $request->user()->id,
                'exception' => $exception->getMessage(),
            ]);

            return [];
        }
    }
}
