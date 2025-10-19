<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Governorate extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function currencyQuotes(): HasMany
    {
        return $this->hasMany(CurrencyRateQuote::class);
    }
    public function metalQuotes(): HasMany
    {
        return $this->hasMany(MetalRateQuote::class);
    }

}