<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalletUsageLimit extends Model
{
    use HasFactory;

    protected $fillable = [
        'wallet_account_id',
        'period',
        'period_start',
        'total_credit',
        'total_debit',
    ];

    protected $casts = [
        'period_start' => 'date',
        'total_credit' => 'decimal:2',
        'total_debit' => 'decimal:2',
    ];

    public function account(): BelongsTo
    {
        return $this->belongsTo(WalletAccount::class, 'wallet_account_id');
    }
}