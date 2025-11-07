<?php

namespace App\Models;


use App\Enums\OrderStatus as OrderStatusEnum;
use App\Events\OrderStatusChanged;
use App\Services\DeliveryPricingService;

use App\Services\DeliveryPricingResult;
use App\Services\Exceptions\DeliveryPricingException;
use App\Services\LegalNumberingService;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;

use Carbon\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use App\Exceptions\PaymentUnderReviewException;
use App\Support\Payments\PaymentLabelService;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Facades\DB;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Support\Arr;
use InvalidArgumentException;
use Throwable;

class Order extends Model
{
    use HasFactory, SoftDeletes;




    /**
     * الحقول القابلة للتعبئة الجماعية
     *
     * @var array
     */
    protected $fillable = [
        'user_id',
        'seller_id',
        'store_id',
        'department',
        'invoice_no',
        'order_number',
        'shein_batch_id',
        'total_amount',
        'tax_amount',
        'discount_amount',
        'final_amount',
        'payment_method',
        'payment_status',
        'order_status',
        'shipping_address',
        'billing_address',
        'tracking_number',
        'carrier_name',
        'tracking_url',
        'delivery_proof_image_path',
        'delivery_proof_signature_path',
        'delivery_proof_otp_code',

        'address_snapshot',
        'notes',
        'completed_at',
        'delivery_distance',
        'delivery_size',
        'delivery_price',
        'delivery_price_breakdown',
        'delivery_payment_timing',
        'delivery_payment_status',
        'delivery_online_payable',
        'delivery_cod_fee',
        'delivery_cod_due',


        'coupon_code',
        'coupon_id',
        'cart_snapshot',
        'pricing_snapshot',
        'status_timestamps',
        'status_history',
        'payment_reference',
        'payment_payload',
        'payment_due_at',
        'payment_collected_at',
        'delivery_fee',
        'delivery_surcharge',
        'delivery_discount',
        'delivery_total',
        'delivery_collected_amount',
        'delivery_collected_at',
        'last_quoted_at',

        'deposit_minimum_amount',
        'deposit_ratio',
        'deposit_amount_paid',
        'deposit_remaining_balance',
        'deposit_includes_shipping',
    ];

    /**
     * الحقول التي يجب تحويلها إلى تواريخ
     *
     * @var array
     */
    protected $dates = [
        'completed_at',
        'created_at',
        'updated_at',
        'deleted_at',
        
        'payment_due_at',
        'payment_collected_at',
        'delivery_collected_at',
        'last_quoted_at',

    ];

    /**
     * الحقول التي يجب تحويلها إلى أنواع محددة
     *
     * @var array
     */
    protected $casts = [
        'total_amount' => 'float',
        'tax_amount' => 'float',
        'discount_amount' => 'float',
        'final_amount' => 'float',
        'delivery_distance' => 'float',
        'delivery_price' => 'float',
        'delivery_fee' => 'float',
        'delivery_surcharge' => 'float',
        'delivery_discount' => 'float',
        'delivery_total' => 'float',
        'delivery_online_payable' => 'float',
        'delivery_cod_fee' => 'float',
        'delivery_cod_due' => 'float',
        'delivery_collected_amount' => 'float',
        'cart_snapshot' => 'array',
        'pricing_snapshot' => 'array',
        'status_timestamps' => 'array',
        'status_history' => 'array',
        'address_snapshot' => 'array',
        'delivery_price_breakdown' => 'array',
        'tracking_number' => 'string',
        'carrier_name' => 'string',
        'tracking_url' => 'string',
        'delivery_proof_image_path' => 'string',
        'delivery_proof_signature_path' => 'string',
        'delivery_proof_otp_code' => 'string',

        'payment_payload' => 'array',
        'completed_at' => 'datetime',
        'payment_due_at' => 'datetime',
        'payment_collected_at' => 'datetime',
        'delivery_collected_at' => 'datetime',
        'last_quoted_at' => 'datetime',

        'deposit_minimum_amount' => 'float',
        'deposit_ratio' => 'float',
        'deposit_amount_paid' => 'float',
        'deposit_remaining_balance' => 'float',
        'deposit_includes_shipping' => 'bool',






    ];

    protected $attributes = [
        'status_timestamps' => '[]',
        'payment_payload' => '[]',
        'status_history' => '[]',
        'delivery_price_breakdown' => '[]',



    ];


    protected $appends = [
        'delivery_payment_summary',
        'payment_summary',
        'tracking_details',
        'actions',
        'resolved_payment_gateway_label',
        'resolved_payment_gateway_key',
        'resolved_payment_gateway_bank_name',


    ];



    private ?array $paymentGatewayLabelsCache = null;



    /**
     * قائمة حالات الدفع المتاحة مع التسميات العربية الخاصة بها.
     *
     * @var array<string, string>
     */
    public const PAYMENT_STATUS_LABELS = [
        'pending' => 'قيد الانتظار',
        'payment_pending' => 'قيد الدفع',
        'paid' => 'مدفوع',
        'partial' => 'مدفوع جزئياً',
        'payment_partial' => 'مدفوع جزئياً',
        'refunded' => 'مسترجع',
        'failed' => 'فشل الدفع',
        'cancelled' => 'ملغي',
    ];



    /**
     * قائمة حالات الدفع التي تعتبر سداداً ناجحاً للطلب.
     *
     * @var array<int, string>
     */
    public const SUCCESSFUL_PAYMENT_STATUSES = [
        'paid',
    ];



    public const CUSTOMER_CANCELLABLE_STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_DEPOSIT_PAID,
        self::STATUS_UNDER_REVIEW,
        self::STATUS_CONFIRMED,
        self::STATUS_PROCESSING,


    ];


    protected ?string $statusTransitionFrom = null;

    protected ?Carbon $statusTransitionRecordedAt = null;

    protected ?array $statusHistoryContext = null;
    protected ?int $couponReleaseId = null;

    protected static function booted(): void
    {
        static::updating(function (self $order): void {
            $order->couponReleaseId = null;


            if (! $order->isDirty('order_status')) {
                return;
            }

            $newStatus = $order->order_status;

            if (! is_string($newStatus) || OrderStatusEnum::tryFrom($newStatus) === null) {
                throw new InvalidArgumentException(sprintf('Invalid order status [%s]', (string) $newStatus));
            }

            $openManualPaymentRequest = $order->latestPendingManualPaymentRequest();

            if ($openManualPaymentRequest !== null) {
                throw PaymentUnderReviewException::forManualPayment($openManualPaymentRequest);
            }


            $previousStatus = $order->getOriginal('order_status');


            if (in_array($newStatus, [self::STATUS_CANCELED, self::STATUS_FAILED], true)) {
                $order->couponReleaseId = $order->getOriginal('coupon_id');
            }



            if (! self::isValidStatusTransition($previousStatus, $newStatus)) {
                throw new InvalidArgumentException(sprintf(
                    'Invalid order status transition from [%s] to [%s]',
                    (string) $previousStatus,
                    $newStatus
                ));
            }

            $order->statusTransitionFrom = $previousStatus;
            
            $timestamp = now();
            $order->statusTransitionRecordedAt = $timestamp;

            [$userId, $comment, $metadata, $display, $icon] = $order->consumeStatusHistoryContext();

            $order->recordStatusTimestamp($newStatus, $timestamp);
            $order->appendStatusHistorySnapshot(
                $newStatus,
                $timestamp,
                $userId ?? Auth::id(),
                $comment,
                
                $metadata,
                $display,
                $icon
            );
        });

        static::updated(function (self $order): void {
            if (! $order->wasChanged('order_status') && $order->statusTransitionFrom === null) {
                return;
            }

            $previousStatus = $order->statusTransitionFrom;
            $order->statusTransitionFrom = null;

            $recordedAt = $order->statusTransitionRecordedAt ?? now();
            $order->statusTransitionRecordedAt = null;

            event(new OrderStatusChanged(
                $order->fresh(),
                $previousStatus,
                $order->order_status,
                $recordedAt
            ));

            if ($order->couponReleaseId !== null) {
                $order->releaseCouponReservation($order->couponReleaseId);
            }

        });
    }


    /**
     * علاقة مع المستخدم (العميل)
     *
     * @return BelongsTo
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * علاقة مع التاجر
     *
     * @return BelongsTo
     */
    public function seller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'seller_id');
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function sheinBatch(): BelongsTo
    {
        return $this->belongsTo(SheinOrderBatch::class, 'shein_batch_id');
    }




    public function coupon(): BelongsTo
    {
        return $this->belongsTo(Coupon::class);
    }


    /**
     * علاقة مع عناصر الطلب
     *
     * @return HasMany
     */
    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function paymentGroups(): BelongsToMany
    {
        return $this->belongsToMany(OrderPaymentGroup::class, 'order_payment_group_order', 'order_id', 'group_id')
            ->withTimestamps();
    }


    /**
     * علاقة مع سجل الطلب
     *
     * @return HasMany
     */
    public function history(): HasMany
    {
        return $this->hasMany(OrderHistory::class)->orderBy('created_at', 'desc');
    }

    /**
     * علاقة مع معاملات الدفع
     *
     * @return HasMany
     */
    public function paymentTransactions()
    {
        return $this->hasMany(PaymentTransaction::class, 'payable_id')
            ->whereIn(
                DB::raw('LOWER(payment_transactions.payable_type)'),
                ManualPaymentRequest::orderPayableTypeTokens()
            );
    }

    public function latestPaymentTransaction(): HasOne
    {
        return $this->hasOne(PaymentTransaction::class, 'payable_id')
            ->whereIn(
                DB::raw('LOWER(payment_transactions.payable_type)'),
                ManualPaymentRequest::orderPayableTypeTokens()
            )
            ->latestOfMany('id');
    }


    public function hasSuccessfulPayment(): bool
    {
        $status = Str::lower((string) $this->payment_status);

        if (in_array($status, ['paid', 'partial', 'payment_partial'], true)) {
            return true;
        }

        if ($this->relationLoaded('paymentTransactions')) {
            return $this->paymentTransactions
                ->contains(static function (PaymentTransaction $transaction): bool {
                    return Str::lower((string) $transaction->payment_status) === 'succeed';
                });
        }

        return $this->paymentTransactions()
            ->whereRaw('LOWER(payment_status) = ?', ['succeed'])
            ->exists();
    }


    public function resolvePaymentGatewayLabels(): array
    {
        if ($this->paymentGatewayLabelsCache !== null) {
            return $this->paymentGatewayLabelsCache;
        }

        $this->loadMissing([
            'latestManualPaymentRequest.manualBank',
            'latestPaymentTransaction.manualPaymentRequest.manualBank',
        ]);

        $defaultLabel = is_string($this->payment_method) && trim($this->payment_method) !== ''
            ? trim($this->payment_method)
            : null;

        $default = [
            'gateway_key' => ManualPaymentRequest::canonicalGateway($this->payment_method) ?? null,
            'gateway_label' => $defaultLabel,
            'bank_name' => null,
            'channel_label' => $defaultLabel,
            'bank_label' => null,
        ];

        $manualRequest = null;

        if ($this->relationLoaded('latestManualPaymentRequest')) {
            $manualRequest = $this->latestManualPaymentRequest;
        }

        if (! $manualRequest && $this->relationLoaded('manualPaymentRequests')) {
            $manualRequest = $this->manualPaymentRequests
                ->sortByDesc('id')
                ->first();
        }

        if (! $manualRequest) {
            $manualRequest = $this->latestManualPaymentRequest()
                ->with('manualBank')
                ->first();
        }

        if ($manualRequest instanceof ManualPaymentRequest) {
            $manualRequest->loadMissing('manualBank');
            $labels = PaymentLabelService::forManualPaymentRequest($manualRequest);
            $this->paymentGatewayLabelsCache = array_merge($default, $labels);

            return $this->paymentGatewayLabelsCache;
        }

        $transaction = null;

        if ($this->relationLoaded('latestPaymentTransaction')) {
            $transaction = $this->latestPaymentTransaction;
        }

        if (! $transaction && $this->relationLoaded('paymentTransactions')) {
            $transaction = $this->paymentTransactions
                ->sortByDesc('id')
                ->first();
        }

        if (! $transaction) {
            $transaction = $this->latestPaymentTransaction()
                ->with('manualPaymentRequest.manualBank')
                ->first();
        }

        if ($transaction instanceof PaymentTransaction) {
            $transaction->loadMissing('manualPaymentRequest.manualBank');
            $labels = PaymentLabelService::forPaymentTransaction($transaction);
            $this->paymentGatewayLabelsCache = array_merge($default, $labels);

            return $this->paymentGatewayLabelsCache;
        }

        $labels = PaymentLabelService::forPayload([
            'payment_gateway' => $this->payment_method,
            'payment_method' => $this->payment_method,
        ]);
        $this->paymentGatewayLabelsCache = array_merge($default, $labels);

        return $this->paymentGatewayLabelsCache;
    }

    public function getResolvedPaymentGatewayLabelAttribute(): ?string
    {
        return $this->resolvePaymentGatewayLabels()['gateway_label'] ?? null;
    }

    public function getResolvedPaymentGatewayKeyAttribute(): ?string
    {
        return $this->resolvePaymentGatewayLabels()['gateway_key'] ?? null;
    }

    public function getResolvedPaymentGatewayBankNameAttribute(): ?string
    {
        return $this->resolvePaymentGatewayLabels()['bank_name'] ?? null;
    }


    public function manualPaymentRequests(): HasMany
    {
        return $this->hasMany(ManualPaymentRequest::class, 'payable_id')
            ->whereIn(
                DB::raw('LOWER(manual_payment_requests.payable_type)'),
                ManualPaymentRequest::orderPayableTypeTokens()
            )
            ->orderByDesc('id');
    }


    public function latestManualPaymentRequest(): HasOne
    {
        return $this->hasOne(ManualPaymentRequest::class, 'payable_id')
            ->whereIn(
                DB::raw('LOWER(manual_payment_requests.payable_type)'),
                ManualPaymentRequest::orderPayableTypeTokens()
            )
            ->latestOfMany('id');
    }


    public function openManualPaymentRequests(): HasMany
    {
        return $this->manualPaymentRequests()->whereIn('status', ManualPaymentRequest::OPEN_STATUSES);
    }


    public function pendingManualPaymentRequests(): HasMany
    {
        return $this->openManualPaymentRequests();
    }

    public function hasPendingManualPaymentRequests(): bool
    {
        if ($this->relationLoaded('manualPaymentRequests')) {
            return $this->manualPaymentRequests
                ->contains(static fn (ManualPaymentRequest $request) => $request->isOpen());
        }

        if ($this->relationLoaded('openManualPaymentRequests')) {
            return $this->openManualPaymentRequests->isNotEmpty();
        }

        return $this->openManualPaymentRequests()->exists();
    
    }

    public function latestPendingManualPaymentRequest(): ?ManualPaymentRequest
    {
        if ($this->relationLoaded('manualPaymentRequests')) {
            return $this->manualPaymentRequests
                ->filter(static fn (ManualPaymentRequest $request) => $request->isOpen())
                ->sortByDesc('id')
                ->first();
        }

        if ($this->relationLoaded('openManualPaymentRequests')) {
            return $this->openManualPaymentRequests
            
            
            ->sortByDesc('id')
                ->first();
        }

        return $this->openManualPaymentRequests()->first();

    }


    /**
     * نطاق البحث
     *
     * @param $query
     * @param $search
     * @return mixed
     */
    public function scopeSearch($query, $search)
    {
        $search = "%" . $search . "%";
        return $query->where(function ($q) use ($search) {
            $q->where('order_number', 'LIKE', $search)
                ->orWhere('payment_method', 'LIKE', $search)
                ->orWhere('payment_status', 'LIKE', $search)
                ->orWhere('order_status', 'LIKE', $search)
                ->orWhereHas('user', function ($q) use ($search) {
                    $q->where('name', 'LIKE', $search)
                        ->orWhere('mobile', 'LIKE', $search);
                });
        });
    }

    /**
     * نطاق الطلبات حسب الحالة
     *
     * @param $query
     * @param $status
     * @return mixed
     */
    public function scopeStatus($query, $status)
    {
        return $query->where('order_status', $status);
    }

    /**
     * نطاق الطلبات حسب حالة الدفع
     *
     * @param $query
     * @param $status
     * @return mixed
     */
    public function scopePaymentStatus($query, $status)
    {
        return $query->where('payment_status', $status);
    }

    /**
     * نطاق الطلبات المكتملة
     *
     * @param $query
     * @return mixed
     */
    public function scopeCompleted($query)
    {
        return $query->whereNotNull('completed_at');
    }

    /**
     * نطاق الطلبات غير المكتملة
     *
     * @param $query
     * @return mixed
     */
    public function scopeIncomplete($query)
    {
        return $query->whereNull('completed_at');
    }

    /**
     * حالات الطلب
     */

    public const STATUS_PENDING = OrderStatusEnum::PENDING->value;
    public const STATUS_DEPOSIT_PAID = OrderStatusEnum::DEPOSIT_PAID->value;
    public const STATUS_UNDER_REVIEW = OrderStatusEnum::UNDER_REVIEW->value;

    public const STATUS_CONFIRMED = OrderStatusEnum::CONFIRMED->value;
    public const STATUS_PROCESSING = OrderStatusEnum::PROCESSING->value;
    public const STATUS_DELIVERED = OrderStatusEnum::DELIVERED->value;
    public const STATUS_PREPARING = OrderStatusEnum::PREPARING->value;
    public const STATUS_READY_FOR_DELIVERY = OrderStatusEnum::READY_FOR_DELIVERY->value;
    public const STATUS_OUT_FOR_DELIVERY = OrderStatusEnum::OUT_FOR_DELIVERY->value;
    public const STATUS_FINAL_SETTLEMENT = OrderStatusEnum::FINAL_SETTLEMENT->value;

    public const STATUS_FAILED = OrderStatusEnum::FAILED->value;
    public const STATUS_CANCELED = OrderStatusEnum::CANCELED->value;
    public const STATUS_ON_HOLD = OrderStatusEnum::ON_HOLD->value;
    public const STATUS_RETURNED = OrderStatusEnum::RETURNED->value;

    
    /**
     * الحصول على مصفوفة حالات الطلب
     */
    public static function getStatusList()


    {
        return Arr::mapWithKeys(
            self::statusDisplayMap(),
            static fn (array $config, string $status) => [$status => $config['label']]
        );
    }

    /**
     * بيانات العرض لكل حالة طلب.
     *
     * @return array<string, array{label: string, icon: ?string, timeline: ?string, reserve: bool}>
     */
    public static function statusDisplayMap(): array

    {
        return [


            self::STATUS_PENDING => [
                'label' => 'قيد الانتظار',
                'icon' => 'bi bi-hourglass-split',
                'timeline' => 'تم استلام الطلب وينتظر المراجعة.',
                'reserve' => false,



            ],
            self::STATUS_DEPOSIT_PAID => [
                'label' => 'تم سداد العربون',
                'icon' => 'bi bi-wallet2',
                'timeline' => 'تم استلام الدفعة المبدئية وجارٍ تجهيز الطلب للمراجعة.',
                'reserve' => false,
            ],
            self::STATUS_UNDER_REVIEW => [
                'label' => 'قيد المراجعة',
                'icon' => 'bi bi-search',
                'timeline' => 'يتم التحقق من تفاصيل الطلب ومراجعة المعلومات اللازمة.',
                'reserve' => false,



            ],
            self::STATUS_CONFIRMED => [
                'label' => 'تم التأكيد',
                'icon' => 'bi bi-check2-square',
                'timeline' => 'تم تأكيد الطلب وسيتم البدء في معالجته.',
                'reserve' => false,



            ],
            self::STATUS_PROCESSING => [
                'label' => 'قيد المعالجة',
                'icon' => 'bi bi-gear',
                'timeline' => 'يتم الآن معالجة تفاصيل الطلب.',
                'reserve' => false,


            ],
            self::STATUS_PREPARING => [
                'label' => 'جارٍ التحضير',
                'icon' => 'bi bi-box-seam',
                'timeline' => 'يتم تجهيز الطلب للشحن.',
                'reserve' => false,


            ],
            self::STATUS_READY_FOR_DELIVERY => [
                'label' => 'جاهز للتسليم',
                'icon' => 'bi bi-clipboard-check',
                'timeline' => 'الطلب جاهز للتسليم إلى شركة الشحن.',
                'reserve' => false,


            ],
            self::STATUS_OUT_FOR_DELIVERY => [
                'label' => 'خرج للتسليم',
                'icon' => 'bi bi-truck',
                'timeline' => 'الطلب في طريقه إلى العميل.',
                'reserve' => false,


            ],
            self::STATUS_DELIVERED => [
                'label' => 'تم التسليم',
                'icon' => 'bi bi-check-circle',
                'timeline' => 'تم تسليم الطلب بنجاح.',
                'reserve' => false,
            ],


            self::STATUS_FINAL_SETTLEMENT => [
                'label' => 'تسوية نهائية',
                'icon' => 'bi bi-cash-coin',
                'timeline' => 'تمت التسوية النهائية للطلب وجميع المبالغ مقفلة.',
                'reserve' => false,
            ],



            self::STATUS_RETURNED => [
                'label' => 'تم الإرجاع',
                'icon' => 'bi bi-arrow-counterclockwise',
                'timeline' => 'تم إعادة الطلب إلى نقطة الاستلام أو المستودع.',
                'reserve' => true,

            ],
            self::STATUS_FAILED => [
                'label' => 'فشل التسليم',
                'icon' => 'bi bi-exclamation-octagon',
                'timeline' => 'تعذر إتمام عملية التسليم.',
                'reserve' => true,
            ],
            self::STATUS_CANCELED => [
                'label' => 'ملغي',
                'icon' => 'bi bi-x-circle',
                'timeline' => 'تم إلغاء الطلب.',
                'reserve' => true,
            ],
            self::STATUS_ON_HOLD => [
                'label' => 'معلّق مؤقتًا',
                'icon' => 'bi bi-pause-circle',
                'timeline' => 'تم تعليق الطلب مؤقتًا لحين معالجة مسألة أو استكمال المعلومات.',
                'reserve' => true,

            ],
        ];
    }

    public static function paymentStatusIsSuccessful(?string $status): bool
    {
        if (! is_string($status) || $status === '') {
            return false;
        }

        return in_array(strtolower($status), self::SUCCESSFUL_PAYMENT_STATUSES, true);
    }


    

    public static function statusLabel(OrderStatusEnum|string|null $status): string
    {
        if ($status instanceof OrderStatusEnum) {
            $status = $status->value;
        }

        if (! is_string($status) || $status === '') {
            return '';
        }

        $labels = self::getStatusList();

        return $labels[$status] ?? Str::of($status)->replace('_', ' ')->headline();
    }

    public static function statusIcon(OrderStatusEnum|string|null $status): ?string
    {
        if ($status instanceof OrderStatusEnum) {
            $status = $status->value;
        }

        if (! is_string($status) || $status === '') {
            return null;
        }


        return self::statusDisplayMap()[$status]['icon'] ?? null;
    }

    public static function statusTimelineMessage(OrderStatusEnum|string|null $status): ?string
    {
        if ($status instanceof OrderStatusEnum) {
            $status = $status->value;
        }

        if (! is_string($status) || $status === '') {
            return null;
        }

        return self::statusDisplayMap()[$status]['timeline'] ?? null;
    }


    public function getStatusDisplayAttribute(): ?array
    {
        $status = is_string($this->order_status) ? trim($this->order_status) : '';

        if ($status === '') {
            return null;
        }

        $map = self::statusDisplayMap();

        if (! array_key_exists($status, $map)) {
            return [
                'code' => $status,
                'label' => Str::of($status)->replace('_', ' ')->headline(),
                'icon' => null,
                'timeline' => null,
                'reserve' => false,
            ];
        }

        $config = $map[$status];

        return [
            'code' => $status,
            'label' => $config['label'] ?? Str::of($status)->replace('_', ' ')->headline(),
            'icon' => $config['icon'] ?? null,
            'timeline' => $config['timeline'] ?? null,
            'reserve' => (bool) ($config['reserve'] ?? false),
        ];
    }

    public function getStatusReserveOptionsAttribute(): array
    {
        $reserveStatuses = [];

        foreach (self::statusDisplayMap() as $code => $config) {
            if (! empty($config['reserve'])) {
                $reserveStatuses[] = [
                    'code' => $code,
                    'label' => $config['label'] ?? Str::of($code)->replace('_', ' ')->headline(),
                    'icon' => $config['icon'] ?? null,
                    'timeline' => $config['timeline'] ?? null,
                    'reserve' => true,
                ];
            }
        }

        return $reserveStatuses;
    }



    /**
     * خريطة الانتقالات المسموح بها بين حالات الطلب.
     *
     * @return array<string, array<int, string>>
     */
    public static function statusTransitionGraph(): array
    {
        return [
            self::STATUS_PENDING => [
                self::STATUS_DEPOSIT_PAID,
                self::STATUS_UNDER_REVIEW,
                self::STATUS_CONFIRMED,
                self::STATUS_PROCESSING,
                self::STATUS_PREPARING,
                self::STATUS_READY_FOR_DELIVERY,
                self::STATUS_OUT_FOR_DELIVERY,
                self::STATUS_DELIVERED,
                self::STATUS_CANCELED,
                self::STATUS_ON_HOLD,



            ],
            self::STATUS_DEPOSIT_PAID => [
                self::STATUS_UNDER_REVIEW,
                self::STATUS_CONFIRMED,
                self::STATUS_PROCESSING,
                self::STATUS_PREPARING,
                self::STATUS_READY_FOR_DELIVERY,
                self::STATUS_OUT_FOR_DELIVERY,
                self::STATUS_DELIVERED,
                self::STATUS_CANCELED,
                self::STATUS_ON_HOLD,
            ],
            self::STATUS_UNDER_REVIEW => [
                self::STATUS_CONFIRMED,
                self::STATUS_PROCESSING,
                self::STATUS_PREPARING,
                self::STATUS_READY_FOR_DELIVERY,
                self::STATUS_OUT_FOR_DELIVERY,
                self::STATUS_DELIVERED,
                self::STATUS_FAILED,
                self::STATUS_CANCELED,
                self::STATUS_ON_HOLD,


            ],
            self::STATUS_CONFIRMED => [
                self::STATUS_PROCESSING,
                self::STATUS_PREPARING,
                self::STATUS_READY_FOR_DELIVERY,
                self::STATUS_OUT_FOR_DELIVERY,
                self::STATUS_DELIVERED,
                self::STATUS_CANCELED,
                self::STATUS_ON_HOLD,


            ],
            self::STATUS_PROCESSING => [
                self::STATUS_CONFIRMED,
                self::STATUS_PREPARING,
                self::STATUS_READY_FOR_DELIVERY,
                self::STATUS_OUT_FOR_DELIVERY,
                self::STATUS_DELIVERED,
                self::STATUS_FAILED,
                self::STATUS_CANCELED,
                self::STATUS_ON_HOLD,


            ],
            self::STATUS_PREPARING => [
                self::STATUS_READY_FOR_DELIVERY,
                self::STATUS_OUT_FOR_DELIVERY,
                self::STATUS_DELIVERED,
                self::STATUS_FAILED,
                self::STATUS_CANCELED,
                self::STATUS_ON_HOLD,


            ],
            self::STATUS_READY_FOR_DELIVERY => [
                self::STATUS_OUT_FOR_DELIVERY,
                self::STATUS_DELIVERED,
                self::STATUS_FAILED,
                self::STATUS_CANCELED,
                self::STATUS_ON_HOLD,


            ],
            self::STATUS_OUT_FOR_DELIVERY => [
                self::STATUS_DELIVERED,
                self::STATUS_FAILED,
                self::STATUS_CANCELED,
                self::STATUS_RETURNED,
                self::STATUS_ON_HOLD,
            ],
            self::STATUS_ON_HOLD => [

                self::STATUS_DEPOSIT_PAID,
                self::STATUS_UNDER_REVIEW,
                self::STATUS_CONFIRMED,

                self::STATUS_PROCESSING,
                self::STATUS_PREPARING,
                self::STATUS_READY_FOR_DELIVERY,
                self::STATUS_OUT_FOR_DELIVERY,
                self::STATUS_DELIVERED,
                self::STATUS_FAILED,
                self::STATUS_CANCELED,
                self::STATUS_RETURNED,

            ],

            self::STATUS_DELIVERED => [
                self::STATUS_FINAL_SETTLEMENT,
            ],
            self::STATUS_RETURNED => [
                self::STATUS_FINAL_SETTLEMENT,
            ],
            self::STATUS_FAILED => [
                self::STATUS_FINAL_SETTLEMENT,
            ],
            self::STATUS_CANCELED => [
                self::STATUS_FINAL_SETTLEMENT,
            ],
            self::STATUS_FINAL_SETTLEMENT => [],

        ];
    }






    public static function isFinalStatus(OrderStatusEnum|string|null $status): bool
    {
        if ($status instanceof OrderStatusEnum) {
            $status = $status->value;
        }

        if (! is_string($status) || $status === '') {
            return false;
        }

        return in_array($status, [
            self::STATUS_DELIVERED,
            self::STATUS_RETURNED,
            self::STATUS_FAILED,
            self::STATUS_CANCELED,
            self::STATUS_FINAL_SETTLEMENT,
        ], true);
    }

    public static function isValidStatusTransition(?string $from, string $to): bool
    {
        $to = Str::of($to)->trim()->toString();

        if ($to === '') {
            return false;
        }

        if ($from === null || $from === '') {
            return true;
        }

        if ($from === $to) {
            return true;
        }

        if (self::isFinalStatus($from)) {
            if ($from !== self::STATUS_FINAL_SETTLEMENT && $to === self::STATUS_FINAL_SETTLEMENT) {
                // السماح بالانتقال إلى التسوية النهائية حتى من الحالات النهائية السابقة.
            } else {
                return false;
            }

            
        }

        $graph = self::statusTransitionGraph();

        if (! array_key_exists($from, $graph)) {
            return false;
        }

        return in_array($to, $graph[$from], true);
    }







    /**
     * قائمة بقيم حالات الطلب المتاحة.
     *
     * @return array<int, string>
     */
    public static function statusValues(): array
    {
        return OrderStatusEnum::values();
    }


    /**
     * إرجاع التسميات العربية لحالات الدفع المدعومة.
     *
     * @return array<string, string>
     */
    public static function paymentStatusLabels(): array
    {
        return self::PAYMENT_STATUS_LABELS;
    }

    /**
     * إرجاع قائمة قيم حالات الدفع المدعومة.
     *
     * @return array<int, string>
     */
    public static function paymentStatusValues(): array
    {
        return array_keys(self::PAYMENT_STATUS_LABELS);
    }

    /**
     * @return array<int, string>
     */
    public static function cancellableStatuses(): array
    {
        return self::CUSTOMER_CANCELLABLE_STATUSES;
    }

    public function canBeCancelled(): bool
    {
        $status = $this->order_status;

        if (! is_string($status) || $status === '') {
            return false;
        }

        return in_array($status, self::cancellableStatuses(), true);
    }

    public function canRefundDeposit(): bool
    {
        if (! $this->canBeCancelled()) {
            return false;
        }

        $depositPaid = (float) ($this->deposit_amount_paid ?? 0.0);

        return $depositPaid > 0.0;
    }

    public function getActionsAttribute(): array
    {
        return [
            'can_cancel' => $this->canBeCancelled(),
            'can_refund_deposit' => $this->canRefundDeposit(),
        ];
    }

    public function withStatusContext(
        ?int $userId = null,
        ?string $comment = null,
        array $metadata = [],
        ?string $display = null,
        ?string $icon = null
    ): static
    
    {
        $this->statusHistoryContext = [
            'user_id' => $userId,
            'comment' => $comment,
            'meta' => $metadata,
            'display' => $display,
            'icon' => $icon,

        ];

        return $this;
    }

    public function appendStatusHistorySnapshot(
        string|OrderStatusEnum $status,
        ?Carbon $timestamp = null,
        ?int $userId = null,
        ?string $comment = null,
        array $metadata = [],
        ?string $display = null,
        ?string $icon = null
        
        ): void {
        $statusValue = $status instanceof OrderStatusEnum ? $status->value : (string) $status;


        if ($statusValue === '') {
            return;
        }

        $recordedAt = ($timestamp ?? now())->toIso8601String();

        $defaults = self::statusDisplayMap()[$statusValue] ?? [];

        $display = $display !== null && trim($display) !== ''
            ? trim($display)
            : ($defaults['timeline'] ?? null);

        $icon = $icon !== null && trim($icon) !== ''
            ? trim($icon)
            : ($defaults['icon'] ?? null);


        $entry = [
            'status' => $statusValue,
            'recorded_at' => $recordedAt,
        ];

        if ($userId !== null) {
            $entry['user_id'] = $userId;
        }

        $comment = $comment !== null ? trim($comment) : null;

        if ($comment !== null && $comment !== '') {
            $entry['comment'] = $comment;
        }


        if ($display !== null && $display !== '') {
            $entry['display'] = $display;
        }

        if ($icon !== null && $icon !== '') {
            $entry['icon'] = $icon;
        }



        if ($metadata !== []) {
            $entry['meta'] = $metadata;
        }

        $history = $this->status_history ?? [];
        $history[] = $entry;
        usort($history, static function (array $a, array $b): int {
            return strcmp($a['recorded_at'] ?? '', $b['recorded_at'] ?? '');
        });

        $this->status_history = array_values($history);
    
    }

    protected function consumeStatusHistoryContext(): array
    {
        $context = $this->statusHistoryContext ?? [];
        $this->statusHistoryContext = null;

        return [
            $context['user_id'] ?? null,
            $context['comment'] ?? null,
            $context['meta'] ?? [],
            $context['display'] ?? null,
            $context['icon'] ?? null,
            
        ];
    }
    


    protected function releaseCouponReservation(?int $couponId): void
    {
        if ($couponId === null) {
            $this->couponReleaseId = null;
            return;
        }

        $orderId = $this->getKey();
        $userId = $this->user_id;

        $coupon = Coupon::query()->find($couponId);

        if ($coupon !== null) {
            $coupon->releaseUsage($orderId, $userId);
        } else {
            $usageQuery = DB::table('coupon_usages')
                ->where('coupon_id', $couponId)
                ->where('order_id', $orderId);

            if ($userId !== null) {
                $usageQuery->where('user_id', $userId);
            }

            $usageQuery->delete();
        }

        static::withoutEvents(function () use ($orderId): void {
            self::query()
                ->whereKey($orderId)
                ->update([
                    'coupon_id' => null,
                    'coupon_code' => null,
                ]);
        });

        $this->coupon_id = null;
        $this->coupon_code = null;
        $this->couponReleaseId = null;
    }

    /**
     * التحقق مما إذا كان الطلب في حالة معينة
     */
    public function isStatus($status)
    {
        return $this->order_status === $status;
    }

    /**
     * حساب سعر التوصيل بناءً على المسافة والحجم
     *
     * @param float $distance المسافة بالكيلومترات
     * @param string $size حجم الطلب
     * @return float|null
     */



    public static function calculateDeliveryPrice($distance, $size, ?string $department = null, ?float $orderTotal = null): ?DeliveryPricingResult
    {
        $service = app(DeliveryPricingService::class);


        $payload = [
            'order_total' => $orderTotal ?? 0.0,
            'distance_km' => (float) $distance,
            'currency' => config('app.currency', 'SAR'),
        ];

        if ($department !== null) {
            $payload['department'] = $department;
        }

        $numericSize = self::normalizeDeliverySizeWeight($size);
        if ($numericSize !== null) {
            $payload['weight_total'] = $numericSize;
        } else {
            $sizeWeightMap = config('services.delivery_pricing.size_weight_map', []);

            if (is_array($sizeWeightMap) && array_key_exists($size, $sizeWeightMap)) {
                $payload['weight_total'] = (float) $sizeWeightMap[$size];
            }
        }


        try {
            return $service->calculate($payload);

        } catch (DeliveryPricingException $exception) {
            Log::warning('فشل حساب تكلفة التوصيل للطلب.', [
                'distance' => $distance,
                'size' => $size,
                'department' => $department,
                'error' => $exception->getMessage(),
            ]);




            return null;
        }
    }


    private static function normalizeDeliverySizeWeight(mixed $value): ?float
    {
        if ($value === null) {
            return null;
        }

        if (is_numeric($value)) {
            $weight = (float) $value;
        } elseif (is_string($value)) {
            $normalized = strtr($value, [
                '٠' => '0',
                '١' => '1',
                '٢' => '2',
                '٣' => '3',
                '٤' => '4',
                '٥' => '5',
                '٦' => '6',
                '٧' => '7',
                '٨' => '8',
                '٩' => '9',
                '۰' => '0',
                '۱' => '1',
                '۲' => '2',
                '۳' => '3',
                '۴' => '4',
                '۵' => '5',
                '۶' => '6',
                '۷' => '7',
                '۸' => '8',
                '۹' => '9',
                '٫' => '.',
                '،' => '.',
            ]);

            $normalized = str_replace(',', '.', trim($normalized));

            
            if ($normalized === '') {
                return null;
            }

            if (str_starts_with($normalized, '.')) {
                $normalized = '0' . $normalized;
            }

            if (!preg_match('/^(?:\d+)(?:\.\d+)?$/', $normalized)) {
                return null;
            }

            $weight = (float) $normalized;
        } else {
            return null;
        }

        if ($weight <= 0) {
            return null;
        }

        return round($weight, 3);
    }


    /**
     * تحديث سعر التوصيل للطلب
     *
     * @param float $distance المسافة بالكيلومترات
     * @param string $size حجم الطلب
     * @return bool
     */
    public function updateDeliveryPrice($distance, $size)
    {
        $this->delivery_distance = $distance;
        $this->delivery_size = $size;
        $result = self::calculateDeliveryPrice($distance, $size, null, $this->total_amount);

        if (!$result) {
            $this->delivery_price = null;
            $this->delivery_price_breakdown = null;
            $this->delivery_fee = 0.0;
            $this->delivery_surcharge = 0.0;
            $this->delivery_discount = 0.0;
            $this->delivery_total = 0.0;
            $this->pricing_snapshot = null;


            return false;


        }



         $this->delivery_price = $result->getTotal();
        $this->delivery_price_breakdown = $result->getBreakdown();
        $total = (float) $result->getTotal();
        $breakdown = $result->getBreakdown();
        $this->delivery_price = $total;
        $this->delivery_price_breakdown = $breakdown;
        $this->delivery_fee = $total;
        $this->delivery_surcharge = $this->extractSurcharge($breakdown);
        $this->delivery_discount = $this->extractDiscount($breakdown);
        $this->delivery_total = $total;
        $this->pricing_snapshot = [
            'total' => $total,
            'breakdown' => $breakdown,
        ];


        $totalAmount = (float) ($this->total_amount ?? 0);
        $taxAmount = (float) ($this->tax_amount ?? 0);
        $discountAmount = (float) ($this->discount_amount ?? 0);

        $this->final_amount = $totalAmount + $taxAmount - $discountAmount + $this->delivery_total;

        return $this->save();

    }

    public function recordStatusTimestamp(string $status, ?Carbon $timestamp = null): void
    {
        $status = Str::of($status)->trim()->lower()->replace(' ', '_')->toString();

        if ($status === '') {
            return;
        }

        $timestamps = $this->status_timestamps ?? [];
        $timestamps[$status] = ($timestamp ?? now())->toIso8601String();
        $this->status_timestamps = $timestamps;
    }




    public function getDeliveryPaymentSummaryAttribute(): ?array
    {
        $payload = $this->payment_payload;

        if (! is_array($payload)) {
            return null;
        }

        $summary = Arr::get($payload, 'delivery_payment');

        if (! is_array($summary) || $summary === []) {
            return null;
        }

        return [
            'timing' => Arr::get($summary, 'timing'),
            'status' => Arr::get($summary, 'delivery_payment_status'),
            'online_payable' => Arr::has($summary, 'online_payable')
                ? (float) Arr::get($summary, 'online_payable')
                : null,
            'online_goods_payable' => Arr::has($summary, 'online_goods_payable')
                ? (float) Arr::get($summary, 'online_goods_payable')
                : null,
            'online_delivery_payable' => Arr::has($summary, 'online_delivery_payable')
                ? (float) Arr::get($summary, 'online_delivery_payable')
                : null,
            'online_outstanding' => Arr::has($summary, 'online_outstanding')
                ? (float) Arr::get($summary, 'online_outstanding')
                : null,
            'online_goods_outstanding' => Arr::has($summary, 'online_goods_outstanding')
                ? (float) Arr::get($summary, 'online_goods_outstanding')
                : null,
            'online_delivery_outstanding' => Arr::has($summary, 'online_delivery_outstanding')
                ? (float) Arr::get($summary, 'online_delivery_outstanding')
                : null,

            'cod_fee' => Arr::has($summary, 'cod_fee')
                ? (float) Arr::get($summary, 'cod_fee')
                : null,
            'cod_due' => Arr::has($summary, 'cod_due')
                ? (float) Arr::get($summary, 'cod_due')
                : null,
            'cod_outstanding' => Arr::has($summary, 'cod_outstanding')
                ? (float) Arr::get($summary, 'cod_outstanding')
                : null,

            'note' => Arr::get($summary, 'note_snapshot.body'),
            'note_recorded_at' => Arr::get($summary, 'note_snapshot.recorded_at'),
            'note_recorded_by' => Arr::get($summary, 'note_snapshot.recorded_by'),
            'available_timings' => Arr::get($summary, 'available_timings'),
            'timing_codes' => Arr::get($summary, 'timing_codes'),
        ];
    }


    public function getPaymentSummaryAttribute(): ?array
    {
        $payload = $this->payment_payload;

        if (! is_array($payload)) {
            return null;
        }

        $summary = Arr::get($payload, 'payment_summary');

        if (! is_array($summary) || $summary === []) {
            return null;
        }

        return [
            'online_total' => $this->castPaymentSummaryValue($summary, 'online_total'),
            'online_paid_total' => $this->castPaymentSummaryValue($summary, 'online_paid_total'),
            'online_outstanding' => $this->castPaymentSummaryValue($summary, 'online_outstanding'),
            'goods_online_payable' => $this->castPaymentSummaryValue($summary, 'goods_online_payable'),
            'goods_online_outstanding' => $this->castPaymentSummaryValue($summary, 'goods_online_outstanding'),
            'delivery_online_payable' => $this->castPaymentSummaryValue($summary, 'delivery_online_payable'),
            'delivery_online_outstanding' => $this->castPaymentSummaryValue($summary, 'delivery_online_outstanding'),
            'cod_due' => $this->castPaymentSummaryValue($summary, 'cod_due'),
            'cod_outstanding' => $this->castPaymentSummaryValue($summary, 'cod_outstanding'),
            'remaining_balance' => $this->castPaymentSummaryValue($summary, 'remaining_balance'),
        ];
    }




    public function hasOutstandingBalance(): bool
    {
        if ($this->deposit_remaining_balance !== null && $this->isPositiveAmount((float) $this->deposit_remaining_balance)) {
            return true;
        }

        $summary = $this->payment_summary;

        if (! is_array($summary)) {
            $summary = Arr::get($this->payment_payload, 'payment_summary');
        }

        if (is_array($summary)) {
            foreach ([
                'remaining_balance',
                'online_outstanding',
                'goods_online_outstanding',
                'delivery_online_outstanding',
                'cod_outstanding',
            ] as $key) {
                $value = Arr::get($summary, $key);

                if ($value !== null && $this->isPositiveAmount((float) $value)) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function getDepositReceiptsAttribute(): array
    {
        $payload = $this->payment_payload;

        if (! is_array($payload)) {
            return [];
        }

        $receipts = Arr::get($payload, 'deposit.receipts');

        if (! is_array($receipts)) {
            return [];
        }

        return collect($receipts)
            ->filter(static fn ($receipt) => is_array($receipt))
            ->map(function (array $receipt): array {
                $amount = Arr::has($receipt, 'amount')
                    ? (float) Arr::get($receipt, 'amount')
                    : null;

                $currency = Arr::get(
                    $receipt,
                    'currency',
                    $this->currency ?? config('app.currency', 'SAR')
                );

                $explicitUrl = $this->normalizeReceiptUrlComponent(Arr::get($receipt, 'receipt_url'))
                    ?? $this->normalizeReceiptUrlComponent(Arr::get($receipt, 'receipt'));
                $receiptPath = $this->normalizeReceiptComponent(Arr::get($receipt, 'receipt_path'));
                $receiptDisk = $this->normalizeReceiptComponent(Arr::get($receipt, 'receipt_disk'));
                $attachments = $this->normalizeDepositReceiptAttachments(Arr::get($receipt, 'attachments'));

                if ($explicitUrl === null) {
                    $explicitUrl = $this->resolveDepositReceiptUrl($receiptPath, $receiptDisk, $attachments);
                }

                $entry = [
                    'transaction_id' => Arr::get($receipt, 'transaction_id'),
                    'amount' => $amount,
                    'currency' => $currency,
                    'paid_at' => Arr::get($receipt, 'paid_at'),
                    'gateway' => Arr::get($receipt, 'gateway'),
                    'reference' => Arr::get($receipt, 'reference'),
                ];

                if ($explicitUrl !== null) {
                    $entry['receipt_url'] = $explicitUrl;
                    $entry['receipt'] = $explicitUrl;
                }

                if ($receiptPath !== null) {
                    $entry['receipt_path'] = $receiptPath;
                }

                if ($receiptDisk !== null) {
                    $entry['receipt_disk'] = $receiptDisk;
                }

                if ($attachments !== []) {
                    $entry['attachments'] = $attachments;
                }

                return $entry;

            })
            ->values()
            ->all();
    }


    /**
     * @param mixed $attachments
     * @return array<int, array<string, mixed>>
     */
    private function normalizeDepositReceiptAttachments(mixed $attachments): array
    {
        if (! is_iterable($attachments)) {
            return [];
        }

        $normalized = [];

        foreach ($attachments as $attachment) {
            if (! is_array($attachment)) {
                continue;
            }

            $normalizedEntry = [
                'type' => $this->normalizeReceiptComponent(Arr::get($attachment, 'type')),
                'path' => $this->normalizeReceiptComponent(Arr::get($attachment, 'path')),
                'disk' => $this->normalizeReceiptComponent(Arr::get($attachment, 'disk')),
                'name' => $this->normalizeReceiptComponent(Arr::get($attachment, 'name')),
                'mime_type' => $this->normalizeReceiptComponent(Arr::get($attachment, 'mime_type')),
                'size' => $this->normalizeReceiptSize(Arr::get($attachment, 'size')),
                'uploaded_at' => $this->normalizeReceiptComponent(Arr::get($attachment, 'uploaded_at')),
                'url' => $this->normalizeReceiptUrlComponent(Arr::get($attachment, 'url')),
            ];

            $normalized[] = array_filter(
                $normalizedEntry,
                static fn ($value) => $value !== null
            );
        }

        return $normalized;
    }

    private function normalizeReceiptComponent(mixed $value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function normalizeReceiptUrlComponent(mixed $value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        if ($trimmed === '') {
            return null;
        }

        return filter_var($trimmed, FILTER_VALIDATE_URL) ? $trimmed : null;
    }

    private function normalizeReceiptSize(mixed $value): ?float
    {
        if (is_int($value) || is_float($value)) {
            $floatValue = (float) $value;

            return $floatValue >= 0 ? $floatValue : null;
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            if ($trimmed === '') {
                return null;
            }

            if (is_numeric($trimmed)) {
                $floatValue = (float) $trimmed;

                return $floatValue >= 0 ? $floatValue : null;
            }
        }

        return null;
    }

    /**
     * @param array<int, array<string, mixed>> $attachments
     */
    private function resolveDepositReceiptUrl(?string $receiptPath, ?string $receiptDisk, array $attachments): ?string
    {
        $pathCandidates = [];

        if ($receiptPath !== null) {
            $pathCandidates[] = [
                'path' => $receiptPath,
                'disk' => $receiptDisk,
            ];
        }

        foreach ($attachments as $attachment) {
            $attachmentPath = $this->normalizeReceiptComponent($attachment['path'] ?? null);

            if ($attachmentPath === null) {
                continue;
            }

            $pathCandidates[] = [
                'path' => $attachmentPath,
                'disk' => $this->normalizeReceiptComponent($attachment['disk'] ?? null) ?? $receiptDisk,
            ];
        }

        if ($pathCandidates === []) {
            return null;
        }

        foreach ($pathCandidates as $candidate) {
            $diskCandidates = [];

            if (isset($candidate['disk']) && $candidate['disk'] !== null) {
                $diskCandidates[] = $candidate['disk'];
            }

            if ($receiptDisk !== null) {
                $diskCandidates[] = $receiptDisk;
            }

            $defaultDisk = config('filesystems.default');

            if (is_string($defaultDisk) && trim($defaultDisk) !== '') {
                $diskCandidates[] = trim($defaultDisk);
            }

            $diskCandidates[] = 'public';

            foreach ($diskCandidates as $diskName) {
                if (! is_string($diskName) || $diskName === '') {
                    continue;
                }

                try {
                    $disk = Storage::disk($diskName);
                } catch (Throwable) {
                    continue;
                }

                try {
                    $resolved = $disk->url($candidate['path']);
                } catch (Throwable) {
                    continue;
                }

                if (! is_string($resolved) || $resolved === '') {
                    continue;
                }

                if (filter_var($resolved, FILTER_VALIDATE_URL)) {
                    return $resolved;
                }

                return url($resolved);
            }
        }

        return null;
    }




    public function getTrackingDetailsAttribute(): ?array
    {
        $tracking = [
            'tracking_number' => $this->tracking_number,
            'carrier_name' => $this->carrier_name,
            'tracking_url' => $this->tracking_url,
        ];

        $hasTracking = array_filter($tracking, static fn ($value) => $value !== null && $value !== '') !== [];

        $proof = array_filter([
            'image_path' => $this->delivery_proof_image_path,
            'signature_path' => $this->delivery_proof_signature_path,
            'otp_code' => $this->delivery_proof_otp_code,
        ], static fn ($value) => $value !== null && $value !== '');

        if (! $hasTracking && $proof === []) {
            return null;
        }

        $details = $tracking;

        if ($proof !== []) {
            $details['proof'] = $proof;
        }

        return $details;
    }



    public function mergePaymentPayload(array $payload): void
    {
        $current = $this->payment_payload ?? [];
        $this->payment_payload = array_replace_recursive($current, $payload);
    }

    public function appendPricingSnapshot(array $snapshot): void
    {
        $current = $this->pricing_snapshot ?? [];

        $mergedSnapshot = $snapshot;

        $currentMeta = is_array($current['meta'] ?? null) ? $current['meta'] : [];
        $incomingMeta = is_array($snapshot['meta'] ?? null) ? $snapshot['meta'] : [];

        if ($currentMeta !== [] || $incomingMeta !== []) {
            $mergedSnapshot['meta'] = $this->mergePricingMeta($currentMeta, $incomingMeta);
        }

        if (! array_key_exists('quote_id', $mergedSnapshot) && array_key_exists('quote_id', $current)) {
            $mergedSnapshot['quote_id'] = $current['quote_id'];
        }

        if (! array_key_exists('expires_at', $mergedSnapshot) && array_key_exists('expires_at', $current)) {
            $mergedSnapshot['expires_at'] = $current['expires_at'];
        }

        if (! array_key_exists('id', $mergedSnapshot) && array_key_exists('id', $current)) {
            $mergedSnapshot['id'] = $current['id'];
        }

        $this->pricing_snapshot = array_replace_recursive($current, $mergedSnapshot);
    }

    /**
     * @param array<string, mixed> $current
     * @param array<string, mixed> $incoming
     * @return array<string, mixed>
     */
    private function mergePricingMeta(array $current, array $incoming): array
    {
        $merged = array_replace_recursive($current, $incoming);

        if (isset($current['quote']) || isset($incoming['quote'])) {
            $currentQuote = is_array($current['quote'] ?? null) ? $current['quote'] : [];
            $incomingQuote = is_array($incoming['quote'] ?? null) ? $incoming['quote'] : [];

            $merged['quote'] = $this->mergeQuoteMeta($currentQuote, $incomingQuote);
        }

        return $this->removeEmptyMetaValues($merged);
    }

    /**
     * @param array<string, mixed> $current
     * @param array<string, mixed> $incoming
     * @return array<string, mixed>
     */
    private function mergeQuoteMeta(array $current, array $incoming): array
    {
        $merged = array_replace_recursive($current, $incoming);

        if (! array_key_exists('id', $incoming) && array_key_exists('id', $current)) {
            $merged['id'] = $current['id'];
        }

        if (! array_key_exists('expires_at', $incoming) && array_key_exists('expires_at', $current)) {
            $merged['expires_at'] = $current['expires_at'];
        }

        if (isset($current['metadata']) && isset($incoming['metadata']) && is_array($current['metadata']) && is_array($incoming['metadata'])) {
            $merged['metadata'] = array_replace_recursive($current['metadata'], $incoming['metadata']);
        } elseif (! array_key_exists('metadata', $incoming) && array_key_exists('metadata', $current)) {
            $merged['metadata'] = $current['metadata'];
        }

        return $this->removeEmptyMetaValues($merged);
    }

    /**
     * @param array<string, mixed> $meta
     * @return array<string, mixed>
     */
    private function removeEmptyMetaValues(array $meta): array
    {
        foreach ($meta as $key => $value) {
            if ($value === null) {
                unset($meta[$key]);

                continue;
            }

            if (is_array($value)) {
                $cleaned = $this->removeEmptyMetaValues($value);

                if ($cleaned === []) {
                    unset($meta[$key]);

                    continue;
                }

                $meta[$key] = $cleaned;
            }
        }

        return $meta;
    
    
    }


    public static function formatOrderNumber(int $id, ?string $department = null, ?string $currentNumber = null): string


    {
        /** @var LegalNumberingService $service */
        $service = app(LegalNumberingService::class);

        return $service->formatOrderNumber($id, $department, $currentNumber);

    }

    public function refreshOrderNumber(): self
    {


        $orderId = $this->getKey();

        if ($orderId === null) {
            return $this;
        }


        $this->forceFill([
            'order_number' => self::formatOrderNumber((int) $orderId, $this->department, $this->order_number),
        ])->save();

        return $this->refresh();
    }




    private function castPaymentSummaryValue(array $summary, string $key): ?float
    {
        if (! Arr::has($summary, $key)) {
            return null;
        }

        $value = Arr::get($summary, $key);

        return $value !== null ? (float) $value : null;
    }


    protected function extractSurcharge(array $breakdown): float
    {
        $surcharge = 0.0;

        foreach ($breakdown as $line) {
            $amount = $this->resolveBreakdownAmount($line);

            if ($amount > 0) {
                $surcharge += $amount;
            }
        }

        return round($surcharge, 2);
    }

    protected function extractDiscount(array $breakdown): float
    {
        $discount = 0.0;

        foreach ($breakdown as $line) {
            $amount = $this->resolveBreakdownAmount($line);

            if ($amount < 0) {
                $discount += abs($amount);
            }
        }

        return round($discount, 2);
    }

    private function resolveBreakdownAmount(mixed $line): float
    {
        if (is_array($line) && array_key_exists('amount', $line)) {
            return (float) $line['amount'];
        }

        if (is_numeric($line)) {
            return (float) $line;
        }
        return 0.0;


    }






    private function isPositiveAmount(float $amount): bool
    {
        return round($amount, 2) > 0.0;
    }



}
