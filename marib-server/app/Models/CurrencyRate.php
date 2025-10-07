<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CurrencyRate extends Model
{
    use HasFactory;
    protected $table = 'currency_rates'; // <-- make sure this is correct

    protected $fillable = [
        'currency_name',
        'sell_price',
        'buy_price',
        'last_updated_at'
    ];

    protected $casts = [
        'last_updated_at' => 'datetime',
        'sell_price' => 'decimal:2',
        'buy_price' => 'decimal:2'
    ];
}
