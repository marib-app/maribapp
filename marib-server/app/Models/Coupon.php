<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builders\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class Coupon extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'code',
        'name',
        'description',
        'discount_type',
        'discount_value',
        'minimum_order_amount',
        'max_uses',
        'max_uses_per_user',
        'starts_at',
        'ends_at',
        'metadata',
        'is_active',
    ];

    protected $casts = [
        'discount_value' => 'float',
        'max_uses' => 'integer',
        'max_uses_per_user' => 'integer',
        'metadata' => 'array',
        'is_active' => 'boolean',
        'starts_at' => 'datetime',
        'ends_at' => 'datetime',
        'minimum_order_amount' => 'float',


    ];

    public function scopeActive(Builder $query): Builder
    {
        $now = Carbon::now();

        return $query->where('is_active', true)
            ->where(function (Builder $builder) use ($now) {
                $builder->whereNull('starts_at')->orWhere('starts_at', '<=', $now);
            })
            ->where(function (Builder $builder) use ($now) {
                $builder->whereNull('ends_at')->orWhere('ends_at', '>=', $now);
            });
    }

    public function isWithinUsageLimits(?int $userId = null): bool
    {
        if ($this->max_uses !== null) {
            $totalUses = Order::query()->where('coupon_id', $this->getKey())->count();

            if ($totalUses >= $this->max_uses) {
                return false;
            }
        }

        if ($userId !== null && $this->max_uses_per_user !== null) {
            $userUses = Order::query()
                ->where('coupon_id', $this->getKey())
                ->where('user_id', $userId)
                ->count();

            if ($userUses >= $this->max_uses_per_user) {
                return false;
            }
        }

        return true;
    }

    public function calculateDiscount(float $amount): float
    {
        $discount = $this->discount_type === 'percentage'
            ? $amount * ($this->discount_value / 100)
            : $this->discount_value;

        if ($discount > $amount) {
            return round($amount, 2);
        }

        return round($discount, 2);
    }

    public function isCurrentlyActive(): bool
    {
        if (! $this->is_active) {
            return false;
        }

        $now = Carbon::now();

        if ($this->starts_at !== null && $this->starts_at->isFuture()) {
            return false;
        }

        if ($this->ends_at !== null && $this->ends_at->lt($now)) {
            return false;
        }

        return true;
    }

    public function meetsMinimumOrder(float $amount): bool
    {
        if ($this->minimum_order_amount === null) {
            return true;
        }

        return $amount >= (float) $this->minimum_order_amount;
    }

    public function recordUsage(int $userId, int $orderId): void
    {
        $now = now();

        $exists = DB::table('coupon_usages')
            ->where('coupon_id', $this->getKey())
            ->where('user_id', $userId)
            ->where('order_id', $orderId)
            ->exists();

        $payload = [
            'used_at' => $now,
            'updated_at' => $now,
        ];

        if (! $exists) {
            $payload['created_at'] = $now;

            DB::table('coupon_usages')->insert(array_merge([
                'coupon_id' => $this->getKey(),
                'user_id' => $userId,
                'order_id' => $orderId,
            ], $payload));

            return;
        }

        DB::table('coupon_usages')
            ->where('coupon_id', $this->getKey())
            ->where('user_id', $userId)
            ->where('order_id', $orderId)
            ->update($payload);
    }

}