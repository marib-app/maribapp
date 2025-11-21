<?php

namespace App\Services;

use App\Data\Notifications\NotificationDispatchResult;
use App\Data\Notifications\NotificationIntent;
use App\Data\Notifications\NotificationPayload;
use App\Enums\NotificationDispatchStatus;
use App\Jobs\SendFcmMessageJob;
use App\Models\NotificationDelivery;
use Illuminate\Contracts\Cache\Repository;
use Illuminate\Database\QueryException;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use InvalidArgumentException;
use Throwable;

class NotificationDispatchService
{
    public function dispatch(NotificationIntent $intent, bool $sendSynchronously = false): NotificationDispatchResult
    {
        $type = $intent->typeValue();
        $policy = $this->policyFor($type);

        $entityKey = $intent->entity ?? Arr::get($policy, 'entity', 'generic');
        $entityId = (string) ($intent->entityId ?? Arr::get($policy, 'entity_id', 'global'));
        $fingerprint = $this->buildFingerprint($intent->userId, $type, $entityKey, $entityId);

        $dedupeTtl = (int) max(0, Arr::get($policy, 'dedupe_ttl', config('notification.defaults.dedupe_ttl')));
        if ($dedupeTtl > 0 && !$this->acquireDedupeLock($this->dedupeKey($type, $intent->userId, $entityKey, $entityId), $fingerprint, $dedupeTtl)) {
            Log::info('NotificationDispatchService: deduplicated notification attempt', [
                'user_id' => $intent->userId,
                'type' => $type,
                'entity' => $entityKey,
                'entity_id' => $entityId,
            ]);

            return NotificationDispatchResult::deduplicated($fingerprint);
        }

        $throttleTtl = (int) max(0, Arr::get($policy, 'throttle_ttl', config('notification.defaults.throttle_ttl')));
        if ($throttleTtl > 0 && !$this->acquireThrottle($type, $intent->userId, $throttleTtl)) {
            Log::info('NotificationDispatchService: throttled notification attempt', [
                'user_id' => $intent->userId,
                'type' => $type,
            ]);

            return NotificationDispatchResult::throttled($fingerprint);
        }

        $collapsePattern = Arr::get($policy, 'collapse_key', config('notification.defaults.collapse_key'));
        $collapseKey = $this->formatCollapseKey($collapsePattern, $entityKey, $entityId);
        $ttl = (int) Arr::get($policy, 'ttl', config('notification.defaults.ttl'));
        $priority = (string) Arr::get($policy, 'priority', config('notification.defaults.priority', 'normal'));

        if ($ttl <= 0) {
            $ttl = config('notification.defaults.ttl', 1800);
        }

        $this->assertPayloadWithinLimit($intent->data);

        $payload = NotificationPayload::fromIntent($intent, $collapseKey, $ttl, $priority);

        $meta = array_merge(
            $intent->meta,
            [
                'policy_version' => config('notification.policy_version'),
                'payload_version' => config('notification.payload_version'),
            ],
        );

        try {
            $delivery = DB::transaction(function () use ($intent, $payload, $fingerprint, $meta, $collapseKey, $ttl, $priority) {
                $delivery = NotificationDelivery::create([
                    'campaign_id' => $intent->campaignId,
                    'segment_id' => $intent->segmentId,
                    'notification_id' => $intent->notificationId,
                    'user_id' => $intent->userId,
                    'type' => $payload->type,
                    'collapse_key' => $collapseKey,
                    'fingerprint' => $fingerprint,
                    'status' => NotificationDelivery::STATUS_QUEUED,
                    'meta' => $meta,
                    'ttl' => $ttl,
                    'priority' => $priority,
                    'deeplink' => $payload->deeplink,
                ]);

                $delivery->payload = $payload->withDeliveryId($delivery->id)->toArray();
                $delivery->save();

                return $delivery;
            });
        } catch (QueryException $exception) {
            if ($this->isDuplicateFingerprintException($exception)) {
                Log::notice('NotificationDispatchService: duplicate fingerprint prevented new record', [
                    'fingerprint' => $fingerprint,
                    'user_id' => $intent->userId,
                    'type' => $type,
                ]);

                return NotificationDispatchResult::deduplicated($fingerprint);
            }

            throw $exception;
        }

        $queue = Arr::get($policy, 'queue', config('notification.defaults.queue', 'notifications'));

        if ($sendSynchronously) {
            SendFcmMessageJob::dispatchSync($delivery->id);
        } else {
            SendFcmMessageJob::dispatch($delivery->id)->onQueue($queue);
        }

        app(NotificationInboxService::class)->incrementUnreadCount($intent->userId);

        return NotificationDispatchResult::queued($delivery, $fingerprint);
    }

    protected function policyFor(string $type): array
    {
        $policies = config('notification.types', []);

        return $policies[$type] ?? [];
    }

    protected function acquireDedupeLock(string $key, string $fingerprint, int $seconds): bool
    {
        try {
            return $this->cache()->add($key, $fingerprint, $seconds);
        } catch (Throwable $exception) {
            Log::warning('NotificationDispatchService: failed to store dedupe marker, continuing optimistically', [
                'key' => $key,
                'exception' => $exception->getMessage(),
            ]);

            return true;
        }
    }

    protected function acquireThrottle(string $type, int $userId, int $seconds): bool
    {
        if ($seconds <= 0) {
            return true;
        }

        $key = sprintf('throttle:%s:%s', $type, $userId);

        try {
            return $this->cache()->add($key, now()->timestamp, $seconds);
        } catch (Throwable $exception) {
            Log::warning('NotificationDispatchService: failed to store throttle marker, continuing optimistically', [
                'key' => $key,
                'exception' => $exception->getMessage(),
            ]);

            return true;
        }
    }

    protected function cache(): Repository
    {
        $store = config('notification.cache_store', 'redis');

        try {
            return Cache::store($store);
        } catch (Throwable $exception) {
            Log::warning('NotificationDispatchService: falling back to default cache store', [
                'store' => $store,
                'exception' => $exception->getMessage(),
            ]);

            return Cache::store(config('cache.default'));
        }
    }

    protected function dedupeKey(string $type, int $userId, string $entity, string $entityId): string
    {
        return sprintf('dedupe:%s:%s:%s:%s', $type, $userId, $entity, $entityId);
    }

    protected function formatCollapseKey(?string $pattern, string $entity, string $entityId): string
    {
        $pattern = $pattern ?: config('notification.defaults.collapse_key', 'entity:{entity_id}');

        return Str::of($pattern)
            ->replace('{entity}', $entity)
            ->replace('{entity_id}', $entityId)
            ->replace('{entityId}', $entityId)
            ->toString();
    }

    protected function buildFingerprint(int $userId, string $type, string $entity, string $entityId): string
    {
        return hash('sha256', implode(':', [$userId, $type, $entity, $entityId]));
    }

    protected function isDuplicateFingerprintException(QueryException $exception): bool
    {
        return str_contains(strtolower($exception->getMessage()), 'notification_deliveries_fingerprint');
    }

    protected function assertPayloadWithinLimit(array $data): void
    {
        $encoded = json_encode($data, JSON_UNESCAPED_UNICODE);
        if ($encoded === false) {
            throw new InvalidArgumentException('Unable to encode notification data payload.');
        }

        if (strlen($encoded) > (int) config('notification.max_data_bytes', 3800)) {
            throw new InvalidArgumentException('Notification data payload exceeds 4KB. Move large fields to the API.');
        }
    }
}
