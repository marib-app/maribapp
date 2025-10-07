<?php

namespace App\Models\Concerns;

use App\Models\AdminNotification;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Schema;

trait NotifiesAdminOnApprovalStatus
{
    protected static function bootNotifiesAdminOnApprovalStatus(): void
    {
        static::created(static function (Model $model): void {
            $model->syncAdminNotificationState();
        });

        static::updated(static function (Model $model): void {
            if ($model->wasChanged($model->getAdminNotificationStatusColumn())) {
                $model->syncAdminNotificationState();
            }
        });
    }

    protected function syncAdminNotificationState(): void
    {
        if (!Schema::hasTable('admin_notifications')) {
            return;
        }

        $statusColumn = $this->getAdminNotificationStatusColumn();
        $status = $this->getAttribute($statusColumn);

        if ($status === null) {
            return;
        }

        if (in_array($status, $this->getAdminNotificationPendingStatuses(), true)) {
            AdminNotification::storePendingFor(
                $this,
                $this->getAdminNotificationType(),
                $this->getAdminNotificationTitle(),
                $this->getAdminNotificationLink(),
                $this->getAdminNotificationMeta()
            );
        }

        if (in_array($status, $this->getAdminNotificationResolvedStatuses(), true)) {
            AdminNotification::resolveFor(
                $this,
                $this->getAdminNotificationType()
            );
        }
    }

    protected function getAdminNotificationStatusColumn(): string
    {
        return 'status';
    }

    protected function getAdminNotificationPendingStatuses(): array
    {
        return [$this->getAdminNotificationPendingStatus()];
    }

    protected function getAdminNotificationPendingStatus(): string
    {
        return AdminNotification::STATUS_PENDING;
    }

    protected function getAdminNotificationResolvedStatuses(): array
    {
        return ['approved'];
    }

    protected function getAdminNotificationMeta(): array
    {
        return [];
    }

    abstract protected function getAdminNotificationType(): string;

    abstract protected function getAdminNotificationTitle(): string;

    protected function getAdminNotificationLink(): ?string
    {
        return null;
    }
}