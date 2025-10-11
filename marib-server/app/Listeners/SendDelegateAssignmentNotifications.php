<?php

namespace App\Listeners;

use App\Events\DelegateAssignmentsUpdated;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Collection;

class SendDelegateAssignmentNotifications implements ShouldQueue
{
    use InteractsWithQueue;

    public function handle(DelegateAssignmentsUpdated $event): void
    {
        $sectionLabel = $this->resolveSectionLabel($event->section);
        $reason = trim($event->reason) !== '' ? $event->reason : null;

        $this->notifyUsers(
            $event->assignedUsers,
            __('تم تعيينك كمندوب لقسم :section', ['section' => $sectionLabel]),
            __('تمت إضافتك إلى قائمة مندوبي قسم :section.', ['section' => $sectionLabel]),
            'delegate_assigned',
            $event->section,
            'assigned',
            $reason
        );

        $this->notifyUsers(
            $event->removedUsers,
            __('تمت إزالتك من مندوبي قسم :section', ['section' => $sectionLabel]),
            __('تمت إزالتك من قائمة مندوبي قسم :section.', ['section' => $sectionLabel]),
            'delegate_removed',
            $event->section,
            'removed',
            $reason
        );
    }

    /**
     * @param Collection<int, User> $users
     */
    protected function notifyUsers(Collection $users, string $title, string $message, string $type, string $section, string $status, ?string $reason): void
    {
        if ($users->isEmpty()) {
            return;
        }

        foreach ($users as $user) {
            $tokens = $user->fcm_tokens->pluck('fcm_token')->filter()->values()->all();

            if (empty($tokens)) {
                continue;
            }

            $payload = [
                'section' => $section,
                'status'  => $status,
            ];

            if ($reason !== null) {
                $payload['reason'] = $reason;
            }

            NotificationService::sendFcmNotification($tokens, $title, $message, $type, $payload);
        }
    }

    protected function resolveSectionLabel(string $section): string
    {
        return match ($section) {
            'shein' => __('قسم شي إن'),
            'computer' => __('قسم الكمبيوتر'),
            default => $section,
        };
    }
}