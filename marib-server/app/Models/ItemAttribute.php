<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ItemAttribute extends Model
{
    use HasFactory;

    protected $fillable = [
        'item_id',
        'name',
        'type',
        'required_for_checkout',
        'affects_stock',
        'position',
        'metadata',
    ];

    protected $casts = [
        'required_for_checkout' => 'boolean',
        'affects_stock' => 'boolean',
        'metadata' => 'array',
    ];

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class);
    }

    public function values(): HasMany
    {
        return $this->hasMany(ItemAttributeValue::class)->orderBy('position');
    }
}