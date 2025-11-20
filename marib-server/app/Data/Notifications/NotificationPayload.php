<?php

namespace App\Data\Notifications;

final class NotificationPayload
{
    public function __construct(
        public string $type,
        public string $title,
        public string $body,
        public string $deeplink,
        public string $collapseKey,
        public int $ttl,
        public string $priority,
        public array $data = [],
        public ?int $deliveryId = null,
    ) {
    }

    public static function fromIntent(NotificationIntent $intent, string $collapseKey, int $ttl, string $priority): self
    {
        $data = $intent->data;
        $data['entity'] ??= $intent->entity;
        if ($intent->entityId !== null) {
            $data['entity_id'] ??= (string) $intent->entityId;
        }

        if ($intent->requestId) {
            $data['request_id'] = $intent->requestId;
        }

        return new self(
            $intent->typeValue(),
            $intent->title,
            $intent->body,
            $intent->deeplink,
            $collapseKey,
            $ttl,
            $priority,
            $data
        );
    }

    public static function fromArray(array $payload): self
    {
        $instance = new self(
            (string) ($payload['type'] ?? 'default'),
            (string) ($payload['title'] ?? ''),
            (string) ($payload['body'] ?? ''),
            (string) ($payload['deeplink'] ?? 'marib://inbox'),
            (string) ($payload['collapse_key'] ?? 'generic'),
            (int) ($payload['ttl'] ?? 1800),
            (string) ($payload['priority'] ?? 'normal'),
            is_array($payload['data'] ?? null) ? $payload['data'] : []
        );

        if (isset($payload['id'])) {
            $instance->deliveryId = (int) $payload['id'];
        }

        return $instance;
    }

    public function withDeliveryId(int $deliveryId): self
    {
        $clone = clone $this;
        $clone->deliveryId = $deliveryId;

        return $clone;
    }

    public function toArray(): array
    {
        return [
            'id' => $this->deliveryId ? (string) $this->deliveryId : null,
            'type' => $this->type,
            'title' => $this->title,
            'body' => $this->body,
            'deeplink' => $this->deeplink,
            'collapse_key' => $this->collapseKey,
            'ttl' => $this->ttl,
            'priority' => $this->priority,
            'data' => $this->data,
        ];
    }
}
