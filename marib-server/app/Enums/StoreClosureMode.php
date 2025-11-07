<?php

namespace App\Enums;

enum StoreClosureMode: string
{
    case FULL = 'full';
    case BROWSE_ONLY = 'browse_only';

    /**
     * @return array<int, string>
     */
    public static function values(): array
    {
        return array_map(static fn (self $mode) => $mode->value, self::cases());
    }
}
