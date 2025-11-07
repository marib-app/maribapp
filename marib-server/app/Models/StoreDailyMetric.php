<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StoreDailyMetric extends Model
{
    use HasFactory;

    protected $fillable = [
        'store_id',
        'metric_date',
        'visits',
        'product_views',
        'add_to_cart',
        'orders',
        'revenue',
        'conversion_rate',
        'payload',
    ];

    protected $casts = [
        'metric_date' => 'date',
        'revenue' => 'float',
        'conversion_rate' => 'float',
        'payload' => 'array',
    ];

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }
}
