<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\WalletTransaction;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;



class PaymentTransaction extends Model
{
    use HasFactory;


    protected $fillable = [
        'user_id',
        'manual_payment_request_id',
        'amount',
        'currency',
        'payment_gateway',
        'order_id',
        'payment_id',
        'payment_signature',
        'receipt_path',
        'payment_status',
        'created_at',
        'payable_type',
        'payable_id',
        'meta',
        'manual_payment_request_id',
        'updated_at',
        'idempotency_key',


    ];

    protected $casts = [
        'meta' => 'array',
        'amount' => 'decimal:2',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function manualPaymentRequest(): BelongsTo
    {
        return $this->belongsTo(ManualPaymentRequest::class);
    }

    public function order(): BelongsTo
    {

        return $this->belongsTo(Order::class)->withTrashed();


    }

    public function manualRequest()
    {
        
        return $this->belongsTo(ManualPaymentRequest::class, 'manual_payment_request_id');
    }

    public function payable(): MorphTo
    {
        return $this->morphTo();
    }

    public function walletTransaction(): BelongsTo
    {
        return $this->belongsTo(WalletTransaction::class, 'payable_id');
    }

    public function payableIsWalletTransaction(): bool
    {
        return $this->payable_type === WalletTransaction::class;
    }

    
    public function scopeSearch($query, $search)
    {
        $search = "%" . $search . "%";
        return $query->where(function ($q) use ($search) {
            $q->orWhere('id', 'LIKE', $search)
                ->orWhere('payment_gateway', 'LIKE', $search)
                ->orWhereHas('user', function ($q) use ($search) {
                    $q->where('name', 'LIKE', $search);
                });
        });
    }
}
