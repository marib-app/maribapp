<?php

namespace App\Data\Notifications;

use App\Enums\NotificationDispatchStatus;
use App\Models\NotificationDelivery;

final class NotificationDispatchResult
{
    public function __construct(
        public NotificationDispatchStatus $status,
        public ?NotificationDelivery $delivery = null,
        public ?string $fingerprint = null,
        public array $context = [],
    ) {
    }

    public static function queued(NotificationDelivery $delivery, ?string $fingerprint = null): self
    {
        return new self(NotificationDispatchStatus::Queued, $delivery, $fingerprint);
    }

    public static function deduplicated(?string $fingerprint = null): self
    {
        return new self(NotificationDispatchStatus::Deduplicated, null, $fingerprint);
    }

    public static function throttled(?string $fingerprint = null): self
    {
        return new self(NotificationDispatchStatus::Throttled, null, $fingerprint);
    }
}
