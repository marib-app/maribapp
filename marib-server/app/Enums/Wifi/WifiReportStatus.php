<?php

namespace App\Enums\Wifi;

enum WifiReportStatus: string
{
    case OPEN = 'open';
    case INVESTIGATING = 'investigating';
    case RESOLVED = 'resolved';
    case DISMISSED = 'dismissed';

    public function label(): string
    {
        return match ($this) {
            self::OPEN => __('Open'),
            self::INVESTIGATING => __('Investigating'),
            self::RESOLVED => __('Resolved'),
            self::DISMISSED => __('Dismissed'),
        };
    }
}