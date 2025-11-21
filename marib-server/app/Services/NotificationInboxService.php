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
    private const CATEGORY_MARKETING = 'marketing';
    private const CATEGORY_ACCOUNT = 'account';
    private const CATEGORY_WALLET = 'wallet';
    private const CATEGORY_SYSTEM = 'system';
    private const CATEGORY_UPDATES = 'updates';

    private const MARKETING_KEYWORDS = [
        'broadcast',
        'broadcast.marketing',
        'campaign',
        'ads',
        'promo',
    ];

    private const ACCOUNT_KEYWORDS = [
        'action',
        'action.request',
        'kyc',
        'kyc.request',
        'account',
        'security',
        'auth',
    ];

    private const WALLET_KEYWORDS = [
        'wallet',
        'wallet.alert',
        'payment',
        'payment.request',
        'payout',
        'transfer',
        'withdrawal',
    ];

    private const UPDATE_KEYWORDS = [
        'order',
        'order.status',
        'delivery',
        'shipping',
        'booking',
        'chat',
        'chat.message',
        'store',
        'merchant',
    ];

    private ?Repository $cache = null;

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
        $deeplink = $delivery->deeplink ?? (string) ($payload['deeplink'] ?? 'marib://inbox');
        $category = $this->resolveCategory(
            $delivery->type ?? (string) ($payload['type'] ?? ''),
            $data,
            [
                'deeplink' => $deeplink,
                'title' => $payload['title'] ?? '',
            ],
        );

        return [
            'id' => (string) $delivery->id,
            'type' => $delivery->type,
            'title' => (string) ($payload['title'] ?? ''),
            'body' => (string) ($payload['body'] ?? ''),
            'deeplink' => $deeplink,
            'collapse_key' => $delivery->collapse_key,
            'priority' => $delivery->priority,
            'ttl' => $delivery->ttl,
            'category' => $category,
            'data' => array_merge(['category' => $category], $data),
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

        if (!$refresh && $cache !== null) {
            try {
                $cached = $cache->get($key);
                if ($cached !== null) {
                    return (int) $cached;
                }
            } catch (Throwable $exception) {
                Log::warning('NotificationInboxService: failed to read unread cache', [
                    'user_id' => $user->id,
                    'exception' => $exception->getMessage(),
                ]);
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

        $cache = $this->cacheStore();
        if ($cache !== null) {
            try {
                $cache->put(
                    $this->unreadCountKey($user->id),
                    $count,
                    now()->addMinute()
                );
            } catch (Throwable $exception) {
                Log::warning('NotificationInboxService: failed to write unread cache', [
                    'user_id' => $user->id,
                    'exception' => $exception->getMessage(),
                ]);
            }
        }

        return (int) $count;
    }

    public function incrementUnreadCount(int $userId, int $amount = 1): void
    {
        $cache = $this->cacheStore();
        if ($cache === null) {
            return;
        }
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

    protected function cacheStore(): ?Repository
    {
        if ($this->cache instanceof Repository) {
            return $this->cache;
        }

        $preferred = config('notification.cache_store', config('cache.default'));
        $fallback = config('cache.default');
        $candidates = array_values(array_unique(array_filter([
            $preferred,
            $fallback,
            'array',
        ])));

        foreach ($candidates as $store) {
            try {
                $repository = Cache::store($store);
                $this->cache = $repository;
                return $repository;
            } catch (Throwable $exception) {
                Log::warning('NotificationInboxService: cache store unavailable', [
                    'store' => $store,
                    'exception' => $exception->getMessage(),
                ]);
            }
        }

        return null;
    }

    protected function resolveCategory(string $type, array $data, array $context = []): string
    {
        $type = strtolower($type);
        $entity = strtolower((string) ($data['entity'] ?? ''));
        $deeplink = strtolower((string) ($context['deeplink'] ?? ''));
        $title = strtolower((string) ($context['title'] ?? ''));

        if ($this->matchesKeywords([$type, $entity, $deeplink, $title], self::MARKETING_KEYWORDS)) {
            return self::CATEGORY_MARKETING;
        }

        if ($this->matchesKeywords([$type, $entity, $deeplink, $title], self::ACCOUNT_KEYWORDS)) {
            return self::CATEGORY_ACCOUNT;
        }

        if ($this->matchesKeywords([$type, $entity, $deeplink, $title], self::WALLET_KEYWORDS)) {
            return self::CATEGORY_WALLET;
        }

        if ($this->matchesKeywords([$type, $entity, $deeplink, $title], self::UPDATE_KEYWORDS)) {
            return self::CATEGORY_UPDATES;
        }

        return self::CATEGORY_SYSTEM;
    }

    protected function matchesKeywords(array $haystacks, array $keywords): bool
    {
        foreach ($haystacks as $haystack) {
            if (!is_string($haystack) || $haystack === '') {
                continue;
            }
            foreach ($keywords as $keyword) {
                if ($keyword !== '' && str_contains($haystack, $keyword)) {
                    return true;
                }
            }
        }

        return false;
    }
}
