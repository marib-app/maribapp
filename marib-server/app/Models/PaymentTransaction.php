<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Order;
use App\Models\WalletTransaction;
use App\Models\ManualPaymentRequest;
use App\Services\Payments\ManualPaymentRequestService;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Support\Str;
use App\Models\Concerns\HasPaymentLabels;
use App\Support\Payments\PaymentLabelService;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

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
        'payment_gateway_name',
        'gateway_label',
        'channel_label',
        'payment_gateway_label',
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

    protected $appends = [
        'receipt_no',
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
        return $this->belongsTo(Order::class);
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
        $foreignKey = Schema::hasColumn($this->getTable(), 'wallet_transaction_id')
            ? 'wallet_transaction_id'
            : 'payable_id';

        return $this->belongsTo(WalletTransaction::class, $foreignKey);
    
    }

    public function payableIsWalletTransaction(): bool
    {
        return $this->payable_type === WalletTransaction::class;
    }

    public function scopeForPayable(Builder $query, string $payableType, int $payableId): Builder
    {
        $normalized = ltrim($payableType, '\\');

        if (! class_exists($normalized) && ! str_starts_with($normalized, 'App\\')) {
            $candidate = 'App\\Models\\' . $normalized;
            if (class_exists($candidate)) {
                $normalized = $candidate;
            }
        }

        return $query
            ->where('payable_type', $normalized)
            ->where('payable_id', $payableId);
    }

    public function scopeActive(Builder $query): Builder
    {
        $statuses = ['pending', 'initiated', 'processing'];

        return $query->whereIn(DB::raw('LOWER(payment_status)'), $statuses);
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


    public function getReceiptNoAttribute(): string
    {
        $manualNumber = optional($this->manualPaymentRequest)->number;

        if (is_string($manualNumber) && trim($manualNumber) !== '') {
            return trim($manualNumber);
        }

        $walletNumber = optional($this->walletTransaction)->number;

        if (is_string($walletNumber) && trim($walletNumber) !== '') {
            return trim($walletNumber);
        }

        $year = optional($this->created_at)->format('Y') ?? date('Y');

        if (strtolower((string) $this->payment_gateway) === 'wallet') {
            return sprintf('WAL-%s-%06d', $year, $this->getKey());
        }

        return sprintf('PT-%s-%06d', $year, $this->getKey());
    }

}
