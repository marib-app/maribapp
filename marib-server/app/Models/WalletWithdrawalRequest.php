<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class WalletWithdrawalRequest extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_REJECTED = 'rejected';

    protected $fillable = [
        'wallet_account_id',
        'wallet_transaction_id',
        'resolution_transaction_id',
        'status',
        'amount',
        'preferred_method',
        'wallet_reference',
        'notes',
        'review_notes',
        'meta',
        'reviewed_by',
        'reviewed_at',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'meta' => 'array',
        'reviewed_at' => 'datetime',
    ];

    public static function statuses(): array
    {
        return [
            self::STATUS_PENDING,
            self::STATUS_APPROVED,
            self::STATUS_REJECTED,
        ];
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(WalletAccount::class, 'wallet_account_id');
    }

    public function transaction(): BelongsTo
    {
        return $this->belongsTo(WalletTransaction::class, 'wallet_transaction_id');
    }

    public function resolutionTransaction(): BelongsTo
    {
        return $this->belongsTo(WalletTransaction::class, 'resolution_transaction_id');
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function isApproved(): bool
    {
        return $this->status === self::STATUS_APPROVED;
    }

    public function isRejected(): bool
    {
        return $this->status === self::STATUS_REJECTED;
    }

    public function statusLabel(): string
    {
        return match ($this->status) {
            self::STATUS_APPROVED => __('merchant_wallet.withdrawals.status.approved'),
            self::STATUS_REJECTED => __('merchant_wallet.withdrawals.status.rejected'),
            default => __('merchant_wallet.withdrawals.status.pending'),
        };
    }

    public function buildIdempotencyKey(string $action): string
    {
        return sprintf(
            'wallet:withdrawal:%d:%d:%s',
            $this->getKey(),
            $this->wallet_account_id,
            Str::slug($action)
        );
    }
}
