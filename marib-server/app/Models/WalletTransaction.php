<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class WalletTransaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'wallet_account_id',
        'type',
        'amount',
        'currency',
        'balance_after',
        'idempotency_key',
        'manual_payment_request_id',
        'payment_transaction_id',
        'meta',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'balance_after' => 'decimal:2',
        'meta' => 'array',
        'currency' => 'string',
    ];

    public function setCurrencyAttribute($value): void
    {
        $this->attributes['currency'] = strtoupper((string) $value);
    }


    public function walletAccount(): BelongsTo
    {
        return $this->belongsTo(WalletAccount::class, 'wallet_account_id');
    }


    public function account(): BelongsTo
    {
        return $this->walletAccount();
    }


    public function manualPaymentRequest(): BelongsTo
    {
        return $this->belongsTo(ManualPaymentRequest::class);
    }

    public function paymentTransaction(): BelongsTo
    {
        return $this->belongsTo(PaymentTransaction::class);
    }
    public function audits(): HasMany
    {
        return $this->hasMany(WalletAudit::class, 'wallet_transaction_id');
    }


        public function withdrawalRequest(): HasOne
    {
        return $this->hasOne(WalletWithdrawalRequest::class, 'wallet_transaction_id');
    }

}