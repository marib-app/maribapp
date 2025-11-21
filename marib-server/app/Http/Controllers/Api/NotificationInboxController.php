<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\NotificationDelivery;
use App\Services\NotificationInboxService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationInboxController extends Controller
{
    public function __construct(private NotificationInboxService $inboxService)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:50'],
            'since' => ['sometimes', 'integer', 'min:1'],
        ]);

        $perPage = $validated['per_page'] ?? 20;
        $sinceId = $validated['since'] ?? null;

        $pagination = $this->inboxService->paginate($request->user(), $perPage, $sinceId);

        return response()->json([
            'data' => $pagination['items']->map(fn (NotificationDelivery $delivery) => $this->inboxService->transform($delivery))->values(),
            'pagination' => [
                'has_more' => $pagination['has_more'],
                'next_since' => $pagination['next_since'],
                'per_page' => $perPage,
            ],
            'unread_count' => $this->inboxService->unreadCount($request->user()),
        ]);
    }

    public function unreadCount(Request $request): JsonResponse
    {
        return response()->json([
            'unread_count' => $this->inboxService->unreadCount($request->user()),
        ]);
    }

    public function markRead(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => ['integer', 'min:1'],
            'mark_clicked' => ['sometimes', 'boolean'],
        ]);

        $user = $request->user();
        $ids = array_values(array_unique($validated['ids']));

        if (empty($ids)) {
            return response()->json([
                'updated' => 0,
                'unread_count' => $this->inboxService->unreadCount($user),
            ]);
        }

        $now = now();
        $updated = NotificationDelivery::query()
            ->where('user_id', $user->id)
            ->whereIn('id', $ids)
            ->whereNull('opened_at')
            ->update(['opened_at' => $now]);

        if (!empty($validated['mark_clicked'])) {
            NotificationDelivery::query()
                ->where('user_id', $user->id)
                ->whereIn('id', $ids)
                ->whereNull('clicked_at')
                ->update(['clicked_at' => $now]);
        }

        $unread = $this->inboxService->refreshUnreadCount($user);

        return response()->json([
            'updated' => $updated,
            'unread_count' => $unread,
        ]);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        $user = $request->user();
        $now = now();

        $updated = NotificationDelivery::query()
            ->where('user_id', $user->id)
            ->whereNull('opened_at')
            ->update(['opened_at' => $now]);

        $unread = $this->inboxService->refreshUnreadCount($user);

        return response()->json([
            'updated' => $updated,
            'unread_count' => $unread,
        ]);
    }
}
