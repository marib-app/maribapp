<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CurrencyRateDailyHistory extends Model
{
    use HasFactory;

    protected $fillable = [
        'currency_rate_id',
        'governorate_id',
        'day_start',
        'open_sell',
        'close_sell',
        'high_sell',
        'low_sell',
        'open_buy',
        'close_buy',
        'high_buy',
        'low_buy',
        'change_sell',
        'change_sell_percent',
        'change_buy',
        'change_buy_percent',
        'samples_count',
        'last_sample_at',
    ];

    protected $casts = [
        'day_start' => 'date',
        'open_sell' => 'decimal:4',
        'close_sell' => 'decimal:4',
        'high_sell' => 'decimal:4',
        'low_sell' => 'decimal:4',
        'open_buy' => 'decimal:4',
        'close_buy' => 'decimal:4',
        'high_buy' => 'decimal:4',
        'low_buy' => 'decimal:4',
        'change_sell' => 'decimal:4',
        'change_sell_percent' => 'decimal:4',
        'change_buy' => 'decimal:4',
        'change_buy_percent' => 'decimal:4',
        'last_sample_at' => 'datetime',
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