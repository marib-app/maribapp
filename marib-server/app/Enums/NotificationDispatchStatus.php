<?php

namespace App\Enums;

enum NotificationDispatchStatus: string
{
    case Queued = 'queued';
    case Deduplicated = 'deduplicated';
    case Throttled = 'throttled';
}
