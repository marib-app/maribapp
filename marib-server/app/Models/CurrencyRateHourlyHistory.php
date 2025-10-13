<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CurrencyRateHourlyHistory extends Model
{
    use HasFactory;

    protected $fillable = [
        'currency_rate_id',
        'governorate_id',
        'hour_start',
        'sell_price',
        'buy_price',
        'source',
        'captured_at',
    ];

    protected $casts = [
        'hour_start' => 'datetime',
        'sell_price' => 'decimal:4',
        'buy_price' => 'decimal:4',
        'captured_at' => 'datetime',
    ];

    public function currencyRate(): BelongsTo
    {
        return $this->belongsTo(CurrencyRate::class);
    }

    public function governorate(): BelongsTo
    {
        return $this->belongsTo(Governorate::class);
    }
}