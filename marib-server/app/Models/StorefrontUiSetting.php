<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StorefrontUiSetting extends Model
{
    use HasFactory;

    protected $fillable = [
        'store_id',
        'featured_categories',
        'promotion_slots',
        'new_offers_items',
        'discount_items',
        'enabled',
    ];

    protected $casts = [
        'featured_categories' => 'array',
        'promotion_slots' => 'array',
        'new_offers_items' => 'array',
        'discount_items' => 'array',
        'enabled' => 'boolean',
    ];
}
