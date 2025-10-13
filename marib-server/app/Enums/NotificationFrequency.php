<?php

namespace App\Enums;

enum NotificationFrequency: string
{
    case NEVER = 'never';
    case DAILY = 'daily';
    case HOURLY = 'hourly';

    public static function values(): array
    {
        return array_map(static fn (self $case) => $case->value, self::cases());
    }

    public function label(): string
    {
        return match ($this) {
            self::NEVER => 'بدون تنبيهات',
            self::DAILY => 'مرة يومياً',
            self::HOURLY => 'كل ساعة',
        };
    }
}