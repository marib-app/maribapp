<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CurrencyRateChangeLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'currency_rate_id',
        'governorate_id',
        'change_type',
        'previous_values',
        'new_values',
        'changed_by',
        'changed_at',
    ];

    protected $casts = [
        'previous_values' => 'array',
        'new_values' => 'array',
        'changed_at' => 'datetime',
    ];

    public function currencyRate(): BelongsTo
    {
        return $this->belongsTo(CurrencyRate::class);
    }

    public function governorate(): BelongsTo
    {
        return $this->belongsTo(Governorate::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'changed_by');
    }
}