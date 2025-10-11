<?php

namespace App\Events;

use App\Models\User;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Collection;

class DelegateAssignmentsUpdated
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    /**
     * @param Collection<int, User> $assignedUsers
     * @param Collection<int, User> $removedUsers
     */
    public function __construct(
        public ?User $actor,
        public string $section,
        Collection $assignedUsers,
        Collection $removedUsers,
        public array $difference,
        public string $reason
    ) {
        $this->assignedUsers = $assignedUsers;
        $this->removedUsers = $removedUsers;
    }

    /**
     * @var Collection<int, User>
     */
    public Collection $assignedUsers;

    /**
     * @var Collection<int, User>
     */
    public Collection $removedUsers;
}