<?php

namespace App\Data\Notifications;

use App\Enums\NotificationType;

final class NotificationIntent
{
    public function __construct(
        public int $userId,
        public NotificationType|string $type,
        public string $title,
        public string $body,
        public string $deeplink,
        public ?string $entity = null,
        public string|int|null $entityId = null,
        public array $data = [],
        public array $meta = [],
        public ?int $notificationId = null,
        public ?int $campaignId = null,
        public ?int $segmentId = null,
        public ?string $requestId = null,
    ) {
    }

    public function typeValue(): string
    {
        return $this->type instanceof NotificationType
            ? $this->type->value
            : (string) $this->type;
    }
}
