<?php

namespace App\Services;

use App\Models\NotificationDelivery;
use App\Models\User;
use Illuminate\Contracts\Cache\Repository;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Throwable;

class NotificationInboxService
{
    public function paginate(User $user, int $perPage, ?int $sinceId = null): array
    {
        $query = NotificationDelivery::query()
            ->where('user_id', $user->id)
            ->orderByDesc('id');

        if ($sinceId !== null && $sinceId > 0) {
            $query->where('id', '<', $sinceId);
        }

        $records = $query->limit($perPage + 1)->get();

        $hasMore = $records->count() > $perPage;
        $items = $hasMore ? $records->slice(0, $perPage)->values() : $records;
        $nextSince = $hasMore ? (string) optional($items->last())->id : null;

        return [
            'items' => $items,
            'has_more' => $hasMore,
            'next_since' => $nextSince,
        ];
    }

    public function transform(NotificationDelivery $delivery): array
    {
        $payload = is_array($delivery->payload) ? $delivery->payload : [];
        $data = is_array($payload['data'] ?? null) ? $payload['data'] : [];

        return [
            'id' => (string) $delivery->id,
            'type' => $delivery->type,
            'title' => (string) ($payload['title'] ?? ''),
            'body' => (string) ($payload['body'] ?? ''),
            'deeplink' => $delivery->deeplink ?? (string) ($payload['deeplink'] ?? 'marib://inbox'),
            'collapse_key' => $delivery->collapse_key,
            'priority' => $delivery->priority,
            'ttl' => $delivery->ttl,
            'data' => $data,
            'delivered_at' => optional($delivery->delivered_at)->toIso8601String(),
            'opened_at' => optional($delivery->opened_at)->toIso8601String(),
            'clicked_at' => optional($delivery->clicked_at)->toIso8601String(),
            'meta' => $delivery->meta,
        ];
    }

    public function unreadCount(User $user, bool $refresh = false): int
    {
        $key = $this->unreadCountKey($user->id);
        $cache = $this->cacheStore();

        if (!$refresh) {
            $cached = $cache->get($key);
            if ($cached !== null) {
                return (int) $cached;
            }
        }

        return $this->refreshUnreadCount($user);
    }

    public function refreshUnreadCount(User $user): int
    {
        $count = NotificationDelivery::query()
            ->where('user_id', $user->id)
            ->whereNull('opened_at')
            ->count();

        $this->cacheStore()->put(
            $this->unreadCountKey($user->id),
            $count,
            now()->addMinute()
        );

        return (int) $count;
    }

    public function incrementUnreadCount(int $userId, int $amount = 1): void
    {
        $cache = $this->cacheStore();
        $key = $this->unreadCountKey($userId);

        try {
            if ($cache->add($key, $amount, now()->addMinute())) {
                return;
            }
            $cache->increment($key, $amount);
        } catch (Throwable $exception) {
            Log::debug('NotificationInboxService: failed to increment unread cache', [
                'user_id' => $userId,
                'exception' => $exception->getMessage(),
            ]);
        }
    }

    protected function unreadCountKey(int $userId): string
    {
        return sprintf('notifications:unread:%s', $userId);
    }

    protected function cacheStore(): Repository
    {
        $store = config('notification.cache_store', config('cache.default'));

        return Cache::store($store);
    }
}
