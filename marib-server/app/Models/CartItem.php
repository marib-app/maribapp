<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CartItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'item_id',
        'store_id',
        'variant_id',
        'variant_key',
        'department',
        'quantity',
        'unit_price',
        'unit_price_locked',
        'currency',
        'attributes',
        'stock_snapshot',

    ];

    protected $casts = [
        'store_id' => 'integer',
        'variant_id' => 'integer',
        'variant_key' => 'string',
        'quantity' => 'integer',
        'unit_price' => 'float',
        'unit_price_locked' => 'float',
        'attributes' => 'array',
        'stock_snapshot' => 'array',

    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class);
    }

    public function getSubtotalAttribute(): float
    {
        return $this->quantity * $this->getLockedUnitPrice();
    }
    public function getLockedUnitPrice(): float
    {
        return $this->unit_price_locked ?? $this->unit_price ?? 0.0;
    }
}
