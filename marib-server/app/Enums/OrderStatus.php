<?php

namespace App\Enums;

enum OrderStatus: string
{

    case PENDING = 'pending';
    case DEPOSIT_PAID = 'deposit_paid';
    case UNDER_REVIEW = 'under_review';
    case CONFIRMED = 'confirmed';
    case PROCESSING = 'processing';
    case PREPARING = 'preparing';
    case READY_FOR_DELIVERY = 'ready_for_delivery';
    case OUT_FOR_DELIVERY = 'out_for_delivery';
    case DELIVERED = 'delivered';
    case FINAL_SETTLEMENT = 'final_settlement';
    case FAILED = 'failed';
    case CANCELED = 'canceled';
    case ON_HOLD = 'on_hold';
    case RETURNED = 'returned';
    /**
     * @return array<int, string>
     */
    public static function values(): array
    {
        return array_map(static fn (self $status) => $status->value, self::cases());
    }
}