<?php

namespace App\Listeners;

use App\Events\DelegateAssignmentsUpdated;
use App\Jobs\UpdateDelegateBadge;

class DispatchDelegateBadgeUpdate
{
    public function handle(DelegateAssignmentsUpdated $event): void
    {
        foreach ($event->assignedUsers as $user) {
            UpdateDelegateBadge::dispatch($user->getKey(), $event->section, true);
        }

        foreach ($event->removedUsers as $user) {
            UpdateDelegateBadge::dispatch($user->getKey(), $event->section, false);
        }
    }
}