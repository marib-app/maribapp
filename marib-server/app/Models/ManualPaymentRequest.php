<?php

namespace App\Models;


use App\Events\ManualPaymentRequestCreated;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;
use App\Models\Concerns\HasPaymentLabels;
use App\Models\ServiceRequest;
use App\Models\Store;


class ManualPaymentRequest extends Model
{
    use HasFactory;
    use Concerns\NotifiesAdminOnApprovalStatus;
    use HasPaymentLabels;

    /**
     * @var array<string, class-string>
     */
    protected $dispatchesEvents = [
        'created' => ManualPaymentRequestCreated::class,
    ];

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
     * Canonical representation of supported gateways.
     */
    private const GATEWAY_ALIASES = [
        'east_yemen_bank' => [
            'east',
            'east_yemen_bank',
            'east-yemen-bank',
            'eastyemenbank',
            'bankalsharq',
            'bank_alsharq',
            'bank-alsharq',
            'bank alsharq',
            'bankalsharqbank',
            'bank_alsharq_bank',
            'bank-alsharq-bank',
            'bank alsharq bank',
            'alsharq',
            'al-sharq',
            'al sharq',
        ],
        'manual_banks' => [
            'manual',
            'manual-bank',
            'manual_bank',
            'manualbank',
            'manualbanking',
            'manual_payment',
            'manual-payment',
            'manual payment',
            'manualpayment',
            'manualpayments',
            'manualbanks',
            'manual banks',
            'manual_transfer',
            'manual-transfer',
            'manual_transfers',
            'manual-transfers',
            'manual transfers',
            'manualtransfers',
            'manualtransfer',
            'offline',
            'internal',
            'bank',
            'bank_transfer',
            'bank-transfer',
            'bank transfer',
            'banktransfer',
        ],
        'wallet' => [
            'wallet',
            'wallet_balance',
            'wallet-balance',
            'wallet balance',
            'wallet_gateway',
            'wallet-gateway',
            'wallet gateway',
            'wallet_top_up',
            'wallet-top-up',
            'wallet top up',
            'walletpayment',
            'wallet_payment',
            'wallet-payment',
            'wallet payment',
            'wallettopup',
        ],
        'cash' => [
            'cash',
            'cod',
            'cash_on_delivery',
            'cashcollection',
            'cash_collect',
        ],
    ];

    /**
     * Canonical mapping for the different status variations we might receive.
     */
    private const STATUS_ALIASES = [
        self::STATUS_PENDING => [
            self::STATUS_PENDING,
            'processing',
            'initiated',
            'open',
            'waiting',
            'awaiting',
            'new',
            'in_progress',
            'in-progress',
            'in progress',
            'on-hold',
            'on_hold',
            'on hold',
        ],
        self::STATUS_UNDER_REVIEW => [
            self::STATUS_UNDER_REVIEW,
            'in_review',
            'in-review',
            'in review',
            'review',
            'reviewing',
            'under-review',
            'under review',
        ],
        self::STATUS_APPROVED => [
            self::STATUS_APPROVED,
            'accepted',
            'completed',
            'done',
            'settled',
            'paid',
        ],
        self::STATUS_REJECTED => [
            self::STATUS_REJECTED,
            'declined',
            'canceled',
            'cancelled',
            'void',
        ],
    ];

    public static function normalizeStatus(?string $status): ?string
    {
        if (! is_string($status)) {
            return null;
        }

        $normalized = strtolower(trim($status));

        if ($normalized === '' || $normalized === 'null') {
            return null;
        }

        foreach (self::STATUS_ALIASES as $canonical => $aliases) {
            if (in_array($normalized, $aliases, true)) {
                return $canonical;
            }
        }

        return in_array($normalized, [
            self::STATUS_PENDING,
            self::STATUS_UNDER_REVIEW,
            self::STATUS_APPROVED,
            self::STATUS_REJECTED,
        ], true) ? $normalized : null;
    }

    public static function canonicalGateway(?string $gateway): ?string
    {
        if (! is_string($gateway)) {
            return null;
        }

        $normalized = strtolower(trim($gateway));

        if ($normalized === '' || $normalized === 'null') {
            return null;
        }

        foreach (self::GATEWAY_ALIASES as $canonical => $aliases) {
            if (in_array($normalized, $aliases, true)) {
                return $canonical;
            }
        }

        return $normalized;
    }



    /**
     * Canonical aliases representing the manual bank gateway values.
     *
     * @return array<int, string>
     */
    public static function manualBankGatewayAliases(): array
    {
        $aliases = array_merge(
            [
                'manual_bank',
                'manual_banks',
                'manual bank',
                'manual banks',
                'manual-bank',
                'manual-banks',
            ],
            self::GATEWAY_ALIASES['manual_banks'] ?? []
        );

        $normalized = array_map(
            static function ($alias) {
                if (! is_string($alias)) {
                    return null;
                }

                $trimmed = trim($alias);

                if ($trimmed === '') {
                    return null;
                }

                return strtolower($trimmed);
            },
            $aliases
        );

        return array_values(array_unique(array_filter($normalized)));
    }



    /**
     * Retrieve the known aliases for a canonical payment gateway identifier.
     *
     * @return array<int, string>
     */
    public static function gatewayAliasesFor(string $canonical): array
    {
        $normalized = strtolower(trim($canonical));

        if ($normalized === '' || $normalized === 'null') {
            return [];
        }

        $lookupKey = $normalized === 'manual_bank' ? 'manual_banks' : $normalized;
        $aliases = self::GATEWAY_ALIASES[$lookupKey] ?? [];

        if ($lookupKey === 'manual_banks') {
            $aliases = array_merge($aliases, [
                'manual_bank',
                'manual_banks',
                'manual bank',
                'manual banks',
                'manual-bank',
                'manual-banks',
            ]);
        } elseif ($lookupKey === 'wallet') {
            $aliases[] = 'wallet';
        } elseif ($lookupKey === 'east_yemen_bank') {
            $aliases[] = 'east_yemen_bank';
        } elseif ($lookupKey === 'cash') {
            $aliases[] = 'cash';
        }

        $aliases[] = $normalized;

        if ($lookupKey !== $normalized) {
            $aliases[] = $lookupKey;
        }

        $normalizedAliases = array_map(
            static function ($alias) {
                if (! is_string($alias)) {
                    return null;
                }

                $trimmed = trim($alias);

                return $trimmed === '' ? null : $trimmed;
            },
            $aliases
        );

        return array_values(array_unique(array_filter($normalizedAliases)));
    }

    /**
     * Canonical aliases representing the wallet gateway values.
     *
     * @return array<int, string>
     */
    public static function walletGatewayAliases(): array
    {
        $aliases = array_merge(
            [
                'wallet',
            ],
            self::GATEWAY_ALIASES['wallet'] ?? []
        );

        $normalized = array_map(
            static function ($alias) {
                if (! is_string($alias)) {
                    return null;
                }

                $trimmed = trim($alias);

                if ($trimmed === '') {
                    return null;
                }

                return strtolower($trimmed);
            },
            $aliases
        );

        return array_values(array_unique(array_filter($normalized)));
    }

    
     /**
     * @var array<int, string>
     */


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
            'cart',
            'carts',
            'cart_order',
            'cart_orders',
            'cart-order',
            'cart-orders',
            'cartorder',
            'cartorders',
            'cart order',
            'cart orders',
            'App\\CartOrder',
            '\\App\\CartOrder',
            'app\\cartorder',

            'App\\Models\\CartOrder',
            'app\\models\\cartorder',
            'App\\Order',
            '\\App\\Order',
            'app\\order',
            'App\\Models\\Order',
            'app\\models\\order',
        ];
        $charactersToTrim = " \t\n\r\0\x0B\"'";

        $normalized = [];

        foreach ($aliases as $alias) {
            if (! is_string($alias)) {
                continue;
            }

            $trimmed = trim($alias, $charactersToTrim);


            if ($trimmed === '') {
                continue;
            }

            $variants = [$trimmed];

            $lower = strtolower($trimmed);
            $variants[] = $lower;
            $variants[] = strtoupper($trimmed);

            if (! str_contains($trimmed, '\\')) {
                $normalizedWords = str_replace(['_', '-', '.'], ' ', $lower);
                $variants[] = Str::title($normalizedWords);
                $variants[] = Str::studly($normalizedWords);
                $variants[] = Str::snake(str_replace(['-', ' '], '_', $lower));
                $variants[] = Str::kebab(str_replace(['_', ' '], '-', $lower));
                $variants[] = str_replace(' ', '', $normalizedWords);
            }

            foreach ($variants as $variant) {
                if (! is_string($variant)) {
                    continue;
                }

                $candidate = trim($variant, $charactersToTrim);

                if ($candidate === '') {
                    continue;
                }

                $normalized[$candidate] = true;
            }

        }

        return array_keys($normalized);
    }



    /**
     * Lowercase tokens for order payable type comparison.
     *
     * @return array<int, string>
     */
    public static function orderPayableTypeTokens(): array
    {
        static $tokens;

        if ($tokens !== null) {
            return $tokens;
        }

        $charactersToTrim = " \t\n\r\0\x0B\"'";

        $tokens = collect(self::orderPayableTypeAliases())
            ->filter(static fn ($alias) => is_string($alias) && trim((string) $alias, $charactersToTrim) !== '')
            ->map(static fn ($alias) => strtolower(trim((string) $alias, $charactersToTrim)))
            ->unique()
            ->values()
            ->all();

        return $tokens;
    }

    /**
     * Determine if the provided value represents an order payable type.
     */
    public static function isOrderPayableType(mixed $value): bool
    {
        if (! is_string($value)) {
            return false;
        }

        $charactersToTrim = " \t\n\r\0\x0B\"'";

        $normalizedValue = strtolower(trim($value, $charactersToTrim));
        foreach (self::orderPayableTypeAliases() as $alias) {
            $normalizedAlias = strtolower(trim($alias, $charactersToTrim));

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
        'store_id',
        'service_request_id',
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


    /**
     * @var array<string, string>
     */


    protected $casts = [
        'amount' => 'decimal:2',
        'meta' => 'array',
        'reviewed_at' => 'datetime',
        'is_open' => 'boolean',
        'service_request_id' => 'integer',


    ];

    // ======== العلاقات ========



    protected static function booted(): void
    {
        $map = [
            self::PAYABLE_TYPE_WALLET_TOP_UP => WalletAccount::class,
        ];

        foreach ([
            'wallet',
            'wallet-top-up',
            'wallet_top_up',
            'wallettopup',
        ] as $alias) {
            $map[$alias] = WalletAccount::class;
        }

        foreach (static::orderPayableTypeAliases() as $alias) {
            $map[$alias] = Order::class;
        }

        foreach ([
            Package::class,
            '\\' . Package::class,
            'package',
            'packages',
            'app\\package',
            'app\\models\\package',
        ] as $alias) {
            $map[$alias] = Package::class;
        }

        foreach ([
            Item::class,
            '\\' . Item::class,
            'item',
            'items',
            'advertisement',
            'advertisements',
            'app\\item',
            'app\\models\\item',
        ] as $alias) {
            $map[$alias] = Item::class;
        }

        Relation::morphMap($map, true);
        }



    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** بنك التحويل اليدوي (من النسخة القديمة) */
    public function manualBank(): BelongsTo
    {
        return $this->belongsTo(ManualBank::class, 'manual_bank_id');

    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function serviceRequest(): BelongsTo
    {
        return $this->belongsTo(ServiceRequest::class);
    }

    /** Payment transaction created for this manual request (manual_payment_request_id foreign key). */
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


    public function payable(): MorphTo
    {
        return $this->morphTo()->withTrashed();

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
        return url(sprintf('/payment-requests/%d/review', $this->getKey()));
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



    public function getReceiptUrlAttribute(): ?string
    {
        $path = $this->receipt_path;

        if (empty($path)) {
            
            return null;
        }

        if (filter_var($path, FILTER_VALIDATE_URL)) {
            return $path;
        }

        $meta = is_array($this->meta) ? $this->meta : [];

        $diskCandidates = [];

        $metaDisk = data_get($meta, 'receipt.disk');
        if (is_string($metaDisk) && $metaDisk !== '') {
            $diskCandidates[] = $metaDisk;
        }

        $attachmentDisks = collect(data_get($meta, 'attachments', []))
            ->filter(static function ($attachment) use ($path) {
                if (! is_array($attachment)) {
                    return false;
                }

                $attachmentPath = data_get($attachment, 'path');

                return is_string($attachmentPath)
                    && trim($attachmentPath) !== ''
                    && trim($attachmentPath) === $path;
            })
            ->map(static fn ($attachment) => data_get($attachment, 'disk'))
            ->filter(static fn ($disk) => is_string($disk) && $disk !== '')
            ->all();

        $diskCandidates = array_merge($diskCandidates, $attachmentDisks);

        $diskCandidates[] = 'public';

        $defaultDisk = config('filesystems.default');
        if (is_string($defaultDisk) && $defaultDisk !== '') {
            $diskCandidates[] = $defaultDisk;
        }

        foreach ($diskCandidates as $diskName) {
            try {
                $disk = Storage::disk($diskName);
            } catch (Throwable) {
                continue;
            }

            try {
                if (method_exists($disk, 'temporaryUrl')) {
                    $temporaryUrl = $disk->temporaryUrl($path, now()->addMinutes(15));

                    if (is_string($temporaryUrl) && $temporaryUrl !== '') {
                        return $temporaryUrl;
                    }
                }
            } catch (Throwable) {
                // ignore and fall back to standard URL generation
            }

            try {
                $resolvedUrl = $disk->url($path);

                if (is_string($resolvedUrl) && $resolvedUrl !== '') {
                    if (filter_var($resolvedUrl, FILTER_VALIDATE_URL)) {
                        return $resolvedUrl;
                    }

                    return url($resolvedUrl);
                }
            } catch (Throwable) {
                continue;
            }

        }

        return $path;
    }

    public function isWalletTopUp(): bool
    {
        return $this->payable_type === self::PAYABLE_TYPE_WALLET_TOP_UP;
    }




    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }



    public function isUnderReview(): bool
    {
        return $this->status === self::STATUS_UNDER_REVIEW;
    }

    public function isApproved(): bool

    {
        return $this->status === self::STATUS_APPROVED;
    }

    public function isRejected(): bool
    {
        return $this->status === self::STATUS_REJECTED;
    }

    public function isOpen(): bool

    {


        $normalized = self::normalizeStatus($this->status);

        if ($normalized !== null) {
            return in_array($normalized, self::OPEN_STATUSES, true);
        }

        return in_array($this->status, self::OPEN_STATUSES, true);
    }

    public function scopeStatus(Builder $query, ?string $status): Builder
    {
        if (empty($status)) {
            return $query;
        }

        return $query->where('status', $status);
    }

    public function scopeOpen(Builder $query): Builder
    {
        return $query->whereIn('status', self::OPEN_STATUSES);
    }

    public function scopePayableType(Builder $query, ?string $type): Builder
    {
        if (empty($type)) {
            return $query;
        }

        return $query->where('payable_type', $type);
    }


    public function scopePaymentGateway(Builder $query, ?string $gateway): Builder

    {
        if (empty($gateway)) {
            return $query;
        }

        $canonical = self::canonicalGateway($gateway);

        if ($canonical === null) {
            return $query;
        }

        return $query->where(function (Builder $builder) use ($canonical): void {
            if ($canonical === 'manual_banks') {


                $builder->whereDoesntHave('paymentTransaction')
                    ->orWhereHas('paymentTransaction', static function (Builder $transactionQuery): void {

                        $transactionQuery->whereIn('payment_gateway', [
                            'manual_bank',
                            'manual',
                            'manual_payment',
                            'offline',
                            'internal',
                            'bank',
                            'bank_transfer',
                            'banktransfer',
                            'bank_alsharq',
                        ]);


                    });

                return;
            }

            $builder->whereHas('paymentTransaction', static function (Builder $transactionQuery) use ($canonical): void {
                $target = $canonical === 'east_yemen_bank' ? 'east_yemen_bank' : $canonical;


                $transactionQuery->where('payment_gateway', $target);
            });

            if ($canonical === 'wallet') {

                $builder->orWhere(static function (Builder $inner): void {

                    $inner->whereDoesntHave('paymentTransaction')
                        ->where(static function (Builder $metaQuery): void {

                            $metaQuery->where('payable_type', self::PAYABLE_TYPE_WALLET_TOP_UP)
                                ->orWhereNotNull('meta->wallet');
                        });
                });
            }
            
        });
    }


    public function scopeDateBetween(Builder $query, ?string $from, ?string $to): Builder
    {
        if ($from) {
            $query->whereDate('created_at', '>=', Carbon::parse($from)->toDateString());
        }
        if ($to) {
            $query->whereDate('created_at', '<=', Carbon::parse($to)->toDateString());
        }
        return $query;
    }

    public function scopeSearch(Builder $query, ?string $term): Builder

    {
        $term = trim((string) $term);


        if ($term === '') {
            return $query;
        }





        $like = "%{$term}%";

        return $query->where(static function (Builder $builder) use ($like): void {
            $builder->where('reference', 'LIKE', $like)
                ->orWhere('amount', 'LIKE', $like)
                ->orWhereHas('user', static function (Builder $userQuery) use ($like): void {
                    $userQuery->where('name', 'LIKE', $like)
                        ->orWhere('email', 'LIKE', $like)
                        ->orWhere('mobile', 'LIKE', $like);
                })
                ->orWhereHas('paymentTransaction', static function (Builder $transactionQuery) use ($like): void {
                    $transactionQuery->where('id', 'LIKE', $like)
                        ->orWhere('payment_gateway', 'LIKE', $like);
                });
        });
    }

    public function getGatewayDisplayAttribute(): string
    {
        $label = $this->gateway_label;

        return is_string($label) ? $label : '';
    }

}
