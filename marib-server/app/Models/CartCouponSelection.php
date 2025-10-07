<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CartCouponSelection extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'coupon_id',
        'department',
        'applied_at',
        'metadata',
    ];

    protected $casts = [
        'applied_at' => 'datetime',
        'metadata' => 'array',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function coupon(): BelongsTo
    {
        return $this->belongsTo(Coupon::class);
    }
}