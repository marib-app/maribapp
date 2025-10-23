<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\WalletTransaction;
use App\Models\ManualPaymentRequest;
use App\Services\Payments\ManualPaymentRequestService;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Support\Str;
use App\Models\Concerns\HasPaymentLabels;
use App\Support\Payments\PaymentLabelService;

use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Log;

class PaymentTransaction extends Model
{
    use HasFactory;
    use HasPaymentLabels;


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


    protected static function booted(): void
    {
        static::saved(static function (PaymentTransaction $transaction): void {
            $canonicalGateway = ManualPaymentRequest::canonicalGateway($transaction->payment_gateway);

            if (! in_array($canonicalGateway, ['manual_bank', 'manual_banks'], true)) {
                return;
            }

            if ($transaction->user_id === null) {
                return;
            }

            try {
                /** @var ManualPaymentRequestService $service */
                $service = App::make(ManualPaymentRequestService::class);

                $manualRequest = $transaction->manualPaymentRequest;

                if (! $manualRequest instanceof ManualPaymentRequest && $transaction->manual_payment_request_id) {
                    $manualRequest = ManualPaymentRequest::query()->find($transaction->manual_payment_request_id);
                }

                if (! $manualRequest instanceof ManualPaymentRequest) {
                    $manualRequest = $service->ensureManualPaymentRequestForTransaction($transaction);
                }

                if ($manualRequest instanceof ManualPaymentRequest) {
                    $service->syncTransactionManualBankPayload($transaction->fresh(), $manualRequest->fresh());
                }
            
            
            } catch (\Throwable $exception) {
                Log::error('Failed to ensure manual payment request or sync bank metadata for manual bank transaction.', [
                    'payment_transaction_id' => $transaction->getKey(),
                    'exception' => $exception,
                ]);
            }
        });
    }


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



    public function getGatewayCodeAttribute(): ?string
    {
        $rawGateway = $this->payment_gateway;

        if ($rawGateway === null) {
            return null;
        }

        $canonical = ManualPaymentRequest::canonicalGateway($rawGateway);

        if ($canonical !== null) {
            return $canonical === 'manual_bank' ? 'manual_banks' : $canonical;
        }

        $normalized = Str::of($rawGateway)->trim()->lower()->value();

        if ($normalized !== '') {
            return $normalized;
        }

        if ($this->manual_payment_request_id !== null) {
            return 'manual_banks';
        }

        return null;
    }
    public function getGatewayDisplayAttribute(): string
    {
        $label = $this->gateway_label;

        return is_string($label) ? $label : '';
    }
}
