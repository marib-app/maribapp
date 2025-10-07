<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalletAudit extends Model
{
    use HasFactory;

    protected $fillable = [
        'wallet_transaction_id',
        'performed_by',
        'difference',
        'notes',
        'meta',
    ];

    protected $casts = [
        'difference' => 'decimal:2',
        'meta' => 'array',
    ];

    public function transaction(): BelongsTo
    {
        return $this->belongsTo(WalletTransaction::class, 'wallet_transaction_id');
    }

    public function performer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'performed_by');
    }
}