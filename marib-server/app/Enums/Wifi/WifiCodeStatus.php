<?php

namespace App\Enums\Wifi;

enum WifiCodeStatus: string
{
    case AVAILABLE = 'available';
    case RESERVED = 'reserved';
    case SOLD = 'sold';
    case EXPIRED = 'expired';

    public function label(): string
    {
        return match ($this) {
            self::AVAILABLE => __('Available'),
            self::RESERVED => __('Reserved'),
            self::SOLD => __('Sold'),
            self::EXPIRED => __('Expired'),
        };
    }
}