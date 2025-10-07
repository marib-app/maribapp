<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class WalletAccount extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'currency',
        'balance',
    ];

    protected $casts = [
        'balance' => 'decimal:2',
        'currency' => 'string',
    ];

    public function setCurrencyAttribute($value): void
    {
        $this->attributes['currency'] = strtoupper((string) $value);
    }



    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class);
    }


    public function withdrawalRequests(): HasMany
    {
        return $this->hasMany(WalletWithdrawalRequest::class);
    }


}