<?php

namespace App\Enums\Wifi;

enum WifiPlanStatus: string
{
    case UPLOADED = 'uploaded';
    case VALIDATED = 'validated';
    case ACTIVE = 'active';
    case ARCHIVED = 'archived';

    public function label(): string
    {
        return match ($this) {
            self::UPLOADED => __('Uploaded'),
            self::VALIDATED => __('Validated'),
            self::ACTIVE => __('Active'),
            self::ARCHIVED => __('Archived'),
        };
    }
}