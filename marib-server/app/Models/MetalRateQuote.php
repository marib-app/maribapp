<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MetalRateQuote extends Model
{
    use HasFactory;

    protected $fillable = [
        'metal_rate_id',
        'governorate_id',
        'sell_price',
        'buy_price',
        'source',
        'quoted_at',
        'is_default',
    ];

    protected $casts = [
        'sell_price' => 'decimal:3',
        'buy_price' => 'decimal:3',
        'is_default' => 'boolean',
        'quoted_at' => 'datetime',
    ];

    public function metalRate(): BelongsTo
    {
        return $this->belongsTo(MetalRate::class);
    }

    public function governorate(): BelongsTo
    {
        return $this->belongsTo(Governorate::class);
    }
}