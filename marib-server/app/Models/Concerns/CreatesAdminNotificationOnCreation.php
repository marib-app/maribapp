<?php

namespace App\Models\Concerns;

use App\Models\AdminNotification;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Schema;

trait CreatesAdminNotificationOnCreation
{
    protected static function bootCreatesAdminNotificationOnCreation(): void
    {
        static::created(static function (Model $model): void {
            $model->createAdminNotificationRecord();
        });

        static::deleted(static function (Model $model): void {
            if ($model->shouldResolveAdminNotificationOnDelete()) {
                AdminNotification::resolveFor(
                    $model,
                    $model->getAdminNotificationType()
                );
            }
        });
    }

    protected function createAdminNotificationRecord(): void
    {
        if (!Schema::hasTable('admin_notifications')) {
            return;
        }

        AdminNotification::storePendingFor(
            $this,
            $this->getAdminNotificationType(),
            $this->getAdminNotificationTitle(),
            $this->getAdminNotificationLink(),
            $this->getAdminNotificationMeta()
        );
    }

    protected function shouldResolveAdminNotificationOnDelete(): bool
    {
        return true;
    }

    abstract protected function getAdminNotificationType(): string;

    abstract protected function getAdminNotificationTitle(): string;

    protected function getAdminNotificationLink(): ?string
    {
        return null;
    }

    protected function getAdminNotificationMeta(): array
    {
        return [];
    }
}