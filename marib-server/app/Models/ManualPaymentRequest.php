<?php

namespace App\Models;
use App\Models\WalletAccount;
use App\Models\AdminNotification;
use App\Models\Concerns\NotifiesAdminOnApprovalStatus;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Support\Facades\Storage;
use Illuminate\Database\Eloquent\Relations\Relation;
use function __;
use function url;


class ManualPaymentRequest extends Model
{
    use HasFactory;
    use NotifiesAdminOnApprovalStatus;

    protected $table = 'manual_payment_requests';

    // حالات الطلب
    public const STATUS_PENDING = 'pending';
    public const STATUS_UNDER_REVIEW = 'under_review';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_REJECTED = 'rejected';
    public const PAYABLE_TYPE_WALLET_TOP_UP = 'wallet_top_up';

    public const OPEN_STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_UNDER_REVIEW,
    ];

    /**
     * Canonical and legacy values stored for order payable types.
     *
     * @return array<int, string>
     */
    public static function orderPayableTypeAliases(): array
    {
        $aliases = [
            Order::class,
            '\\' . Order::class,
            'order',
            'orders',
            'cart_order',
            'cart-orders',
            'App\\Order',
            '\\App\\Order',
            'app\\order',
            'App\\Models\\Order',
            'app\\models\\order',
        ];

        $normalized = [];

        foreach ($aliases as $alias) {
            if (! is_string($alias)) {
                continue;
            }

            $trimmed = trim($alias);

            if ($trimmed === '') {
                continue;
            }

            $normalized[$trimmed] = true;
        }

        return array_keys($normalized);
    }

    /**
     * Determine if the provided value represents an order payable type.
     */
    public static function isOrderPayableType(mixed $value): bool
    {
        if (! is_string($value)) {
            return false;
        }

        $normalizedValue = strtolower(trim($value, " \\t\\n\\r\\0\\x0B\\"'"));

        foreach (self::orderPayableTypeAliases() as $alias) {
            $normalizedAlias = strtolower(trim($alias, " \\t\\n\\r\\0\\x0B\\"'"));

            if ($normalizedAlias === $normalizedValue) {
                return true;
            }
        }

        return false;
    }



    
    protected $fillable = [
        'user_id',
        'manual_bank_id',
        'payable_type',
        'payable_id',
        'amount',
        'currency',
        'department',
        'bank_name',
        'bank_account_name',
        'bank_account_number',
        'bank_iban',
        'bank_swift_code',
        'reference',
        'user_note',
        'receipt_path',
        'admin_note',
        'status',
        'reviewed_by',
        'reviewed_at',
        'meta',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'meta' => 'array',
        'reviewed_at' => 'datetime',
        'is_open' => 'boolean',


    ];

    // ======== العلاقات ========

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** بنك التحويل اليدوي (من النسخة القديمة) */
    public function manualBank(): BelongsTo
    {
        return $this->belongsTo(ManualBank::class, 'manual_bank_id');

    }

    /** قديم: المعاملة تشير للطلب عبر manual_payment_request_id */
    public function paymentTransaction(): HasOne
    {
        return $this->hasOne(PaymentTransaction::class, 'manual_payment_request_id');
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    public function histories(): HasMany
    {
        return $this->hasMany(ManualPaymentRequestHistory::class);
    }


    protected static function booted(): void
    {
        Relation::morphMap([
            self::PAYABLE_TYPE_WALLET_TOP_UP => WalletAccount::class,
        ], true);
    }


   protected function getAdminNotificationType(): string
    {
        return AdminNotification::TYPE_MANUAL_PAYMENT_REQUEST;
    }

    protected function getAdminNotificationTitle(): string
    {
        $owner = $this->user?->name ?? __('User #:id', ['id' => $this->user_id]);

        return __('Manual payment request #:id from :owner', [
            'id'    => $this->getKey(),
            'owner' => $owner,
        ]);
    }

    protected function getAdminNotificationLink(): ?string
    {
        return url(sprintf('/manual-payments/%d/review', $this->getKey()));
    }

    protected function getAdminNotificationMeta(): array
    {
        return [
            'amount'   => $this->amount,
            'currency' => $this->currency,
            'user_id'  => $this->user_id,
            'status'   => $this->status,
        ];
    }

    protected function getAdminNotificationPendingStatus(): string
    {
        return self::STATUS_PENDING;
    }

    protected function getAdminNotificationResolvedStatuses(): array
    {
        return [self::STATUS_APPROVED, self::STATUS_REJECTED];
    }



    public function payable(): MorphTo
    {
        return $this->morphTo()->withTrashed();
    }


    public function isWalletTopUp(): bool
    {
        return $this->payable_type === self::PAYABLE_TYPE_WALLET_TOP_UP;
    }

    // ======== Accessors / Helpers ========

    /** رابط مرفق الإيصال (يدعم مسار التخزين أو رابط كامل) */
    public function getReceiptUrlAttribute(): ?string
    {
        if (empty($this->receipt_path)) {
            return null;
        }

        if (filter_var($this->receipt_path, FILTER_VALIDATE_URL)) {
            return $this->receipt_path;
        }

        return Storage::exists($this->receipt_path)
            ? url(Storage::url($this->receipt_path))
            : $this->receipt_path;
    }





    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }



    public function isUnderReview(): bool
    {
        return $this->status === self::STATUS_UNDER_REVIEW;
    }

    public function isOpen(): bool
    {
        return in_array($this->status, self::OPEN_STATUSES, true);
    }

    // ======== Scopes (تصفية سريعة) ========


        public function isApproved(): bool
    {
        return $this->status === self::STATUS_APPROVED;
    }

    public function isRejected(): bool
    {
        return $this->status === self::STATUS_REJECTED;
    }

    public function scopeStatus($query, ?string $status)
    {
        return !empty($status) ? $query->where('status', $status) : $query;
    }

    public function scopeOpen($query)
    {
        return $query->whereIn('status', self::OPEN_STATUSES);
    }

    public function scopePayableType($query, ?string $type)
    {
        return !empty($type) ? $query->where('payable_type', $type) : $query;
    }


    public function scopePaymentGateway($query, ?string $gateway)
    {
        if (empty($gateway)) {
            return $query;
        }

        return $query->where(function ($builder) use ($gateway) {
            if ($gateway === 'manual_bank') {
                $builder->whereDoesntHave('paymentTransaction')
                    ->orWhereHas('paymentTransaction', function ($transactionQuery) {
                        $transactionQuery->where('payment_gateway', 'manual_bank');
                    });

                return;
            }

            $builder->whereHas('paymentTransaction', function ($transactionQuery) use ($gateway) {
                $transactionQuery->where('payment_gateway', $gateway);
            });

            if ($gateway === 'wallet') {
                $builder->orWhere(function ($inner) {
                    $inner->whereDoesntHave('paymentTransaction')
                        ->where(function ($metaQuery) {
                            $metaQuery->where('payable_type', self::PAYABLE_TYPE_WALLET_TOP_UP)
                                ->orWhereNotNull('meta->wallet');
                        });
                });
            }
            
        });
    }


    public function scopeDateBetween($query, ?string $from, ?string $to)
    {
        if ($from) {
            $query->whereDate('created_at', '>=', Carbon::parse($from)->toDateString());
        }
        if ($to) {
            $query->whereDate('created_at', '<=', Carbon::parse($to)->toDateString());
        }
        return $query;
    }

    public function scopeSearch($query, ?string $term)
    {


        if (!filled($term) || trim($term) === '') {
            return $query;
        }



        $term = trim($term);

        $like = "%{$term}%";

        return $query->where(function ($q) use ($like) {
            $q->where('reference', 'LIKE', $like)

              ->orWhere('amount', 'LIKE', $like)
              ->orWhereHas('user', function ($uq) use ($like) {
                  $uq->where('name', 'LIKE', $like)
                     ->orWhere('email', 'LIKE', $like)
                     ->orWhere('mobile', 'LIKE', $like);
              })
              ->orWhereHas('paymentTransaction', function ($tq) use ($like) {
                  $tq->where('id', 'LIKE', $like)
                     ->orWhere('payment_gateway', 'LIKE', $like);
              });
        });
    }
}
