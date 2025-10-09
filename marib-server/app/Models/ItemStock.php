<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ItemStock extends Model
{
    use HasFactory;

    protected $fillable = [
        'item_id',
        'variant_key',
        'stock',
        'reserved_stock',
    ];

    protected $casts = [
        'stock' => 'integer',
        'reserved_stock' => 'integer',
    ];

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class);
    }

    public function getAvailableAttribute(): int
    {
        return max(0, (int) $this->stock - (int) $this->reserved_stock);
    }
}