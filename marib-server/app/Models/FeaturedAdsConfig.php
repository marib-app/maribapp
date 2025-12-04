<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FeaturedAdsConfig extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'title',
        'root_category_id',
        'interface_type',
        'root_identifier',
        'slug',
        'enabled',
        'enable_ad_slider',
        'style_key',
        'order_mode',
        'position',
    ];

    protected $casts = [
        'enabled' => 'boolean',
        'enable_ad_slider' => 'boolean',
        'root_category_id' => 'integer',
        'position' => 'integer',
    ];
}
