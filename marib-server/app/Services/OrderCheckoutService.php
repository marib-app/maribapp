<?php

namespace App\Services;
use App\Exceptions\CheckoutValidationException;

use App\Models\Address;
use App\Models\CartItem;
use App\Models\Coupon;
use App\Models\Item;
use App\Models\ManualPaymentRequest;
use App\Models\ManualBank;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\PaymentTransaction;
use App\Models\Store;
use App\Models\StoreGatewayAccount;
use App\Models\User;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use App\Services\TelemetryService;
use App\Support\OrderNumberGenerator;
use App\Support\DepositCalculator;
use App\Services\LegalNumberingService;
use App\Services\ItemPurchaseOptionsService;

use App\Services\DelegateNotificationService;
use App\Services\Payments\ManualPaymentRequestService;
use App\Services\Store\StoreStatusService;

use Throwable;



class OrderCheckoutService
{


    public const DELIVERY_TIMING_PAY_NOW = 'pay_now';
    public const DELIVERY_TIMING_PAY_ON_DELIVERY = 'pay_on_delivery';
    public const DELIVERY_TIMING_PUBLIC_NOW = 'now';
    public const DELIVERY_TIMING_PUBLIC_ON_DELIVERY = 'on_delivery';

    /**
     * @var array<string, string>
     */
    private const PUBLIC_TIMING_ALIASES = [
        self::DELIVERY_TIMING_PUBLIC_NOW => self::DELIVERY_TIMING_PAY_NOW,
        self::DELIVERY_TIMING_PUBLIC_ON_DELIVERY => self::DELIVERY_TIMING_PAY_ON_DELIVERY,
    ];


    /**
     * @var array<string, string>
     */
    private const PAYMENT_METHOD_ALIASES = [
        'manual' => 'manual_bank',
        'manual_bank' => 'manual_bank',
        'manualbanks' => 'manual_bank',
        'manual_banks' => 'manual_bank',
        'manualbank' => 'manual_bank',
        'manualpayment' => 'manual_bank',
        'manual_payment' => 'manual_bank',
        'manualtransfer' => 'manual_bank',
        'manual_transfer' => 'manual_bank',
        'manualgateway' => 'manual_bank',
        'manual_gateway' => 'manual_bank',
        'manualmethod' => 'manual_bank',
        'manual_method' => 'manual_bank',
        'bank' => 'manual_bank',
        'banks' => 'manual_bank',
        'banktransfer' => 'manual_bank',
        'bank_transfer' => 'manual_bank',
        'bankpayment' => 'manual_bank',
        'bank_payment' => 'manual_bank',
        'manualpayments' => 'manual_bank',
        'manual_payments' => 'manual_bank',
        'manualbanking' => 'manual_bank',
        'manual_banking' => 'manual_bank',
        'bankmanual' => 'manual_bank',
        'bank_manual' => 'manual_bank',
        'bankmanualtransfer' => 'manual_bank',
        'bank_manual_transfer' => 'manual_bank',
        'east' => 'east_yemen_bank',
        'east_yemen_bank' => 'east_yemen_bank',
        'eastyemenbank' => 'east_yemen_bank',
        'east_yemen' => 'east_yemen_bank',
        'bankalsharq' => 'east_yemen_bank',
        'bank_alsharq' => 'east_yemen_bank',
        'bankalsharqbank' => 'east_yemen_bank',
        'bank_alsharq_bank' => 'east_yemen_bank',
        'wallet' => 'wallet',
        'walletpayment' => 'wallet',
        'wallet_payment' => 'wallet',
        'walletgateway' => 'wallet',
        'wallet_gateway' => 'wallet',
        'walletbalance' => 'wallet',
        'wallet_balance' => 'wallet',
        'walletpay' => 'wallet',
        'wallet_pay' => 'wallet',
        'wallettopup' => 'wallet',
        'wallet_top_up' => 'wallet',
        'walletdeposit' => 'wallet',
        'wallet_deposit' => 'wallet',
        'cash' => 'cash',
        'cashondelivery' => 'cash',
        'cash_on_delivery' => 'cash',
        'cashdelivery' => 'cash',
        'cash_delivery' => 'cash',
        'cashpayment' => 'cash',
        'cash_payment' => 'cash',
        'cashondeliveryfee' => 'cash',
        'cash_on_delivery_fee' => 'cash',
        'cod' => 'cash',
        'payondelivery' => 'cash',
        'pay_on_delivery' => 'cash',
        'deliverycash' => 'cash',
        'delivery_cash' => 'cash',
    ];



    /**
     * @var array<int, string>
     */
    private const INTERNAL_DELIVERY_TIMINGS = [
        self::DELIVERY_TIMING_PAY_NOW,
        self::DELIVERY_TIMING_PAY_ON_DELIVERY,
    ];

    private bool $defaultManualBankResolved = false;

    private ?int $defaultManualBankId = null;

    /**
     * @return array<int, string>
     */
    public static function allowedDeliveryPaymentTimingTokens(): array
    {
        return array_values(array_unique(array_merge(
            self::INTERNAL_DELIVERY_TIMINGS,
            array_keys(self::PUBLIC_TIMING_ALIASES)
        )));
    }


    public function __construct(
        private readonly CartShippingQuoteService $shippingQuoteService,
        private readonly DatabaseManager $db,
        private readonly TelemetryService $telemetry,
        private readonly LegalNumberingService $legalNumbering,
        private readonly ItemPurchaseOptionsService $itemPurchaseOptionsService,
        private readonly DelegateNotificationService $delegateNotificationService,
        private readonly StoreStatusService $storeStatusService,
        private readonly ManualPaymentRequestService $manualPaymentRequestService,

    ) {
    }

    /**
     * @param array<string, mixed> $data
     */
    public function checkout(User $user, array $data): Order
    {
        return $this->db->transaction(function () use ($user, $data) {
            $cartItems = $this->loadCartItems($user);

            if ($cartItems->isEmpty()) {
                throw ValidationException::withMessages([
                    'cart' => __('سلة التسوق فارغة.'),
                ]);
            }

            $department = $this->resolveDepartment($cartItems, $data['department'] ?? null);
            $address = $this->resolveAddress($user, $data['address_id'] ?? null);

            $this->ensureItemsAreAvailable($cartItems);
            $this->ensureCartItemsMatchLockedPricing($cartItems);

            $storeId = $this->resolveStoreId($cartItems);
            $storeModel = null;
            $storeStatus = null;

            if ($storeId !== null) {
                $storeModel = $this->loadCheckoutStore($storeId);
                $storeStatus = $this->storeStatusService->resolve($storeModel);
            }


            $cartCurrencies = $cartItems->pluck('currency')
                ->map(fn (?string $currency) => $this->normalizeCurrency($currency))
                ->filter()
                ->unique()
                ->values();

            if ($cartCurrencies->count() > 1) {
                throw ValidationException::withMessages([
                    'cart' => __('cart.currency_conflict_summary', [
                        'currencies' => $cartCurrencies->implode(', '),
                    ]),
                
                ]);
            }
            $orderCurrency = $cartCurrencies->first() ?? config('app.currency', 'SAR');


            $requestedDeliveryTiming = $data['delivery_payment_timing'] ?? null;
            $storedDeliveryTiming = $requestedDeliveryTiming
                ?? $this->shippingQuoteService->getStoredDeliveryPaymentTiming($user, $department);
            $normalizedPreferredTiming = self::normalizeTimingToken($storedDeliveryTiming);



            $quoteOptions = [
                'force_refresh' => (bool) ($data['force_requote'] ?? false),
                'deposit_enabled' => (bool) ($data['deposit_enabled'] ?? false),

            ];


            if ($normalizedPreferredTiming !== null) {
                $quoteOptions['timing'] = $normalizedPreferredTiming;
            }


            $quote = $this->shippingQuoteService->quote(
                $user,
                (string) $address->getKey(),
                $department,
                $quoteOptions
            );

            $cartMetrics = $this->shippingQuoteService->computeCartMetrics($cartItems);
            $subTotal = round($cartMetrics['cart_value'], 2);

            $storeGatewayAccountModel = null;

            if ($storeModel !== null && $storeStatus !== null) {
                $this->guardStoreCheckout($storeStatus, $subTotal);
            }

            $taxRate = (float) ($data['tax_rate'] ?? 0);
            $taxAmount = round($subTotal * $taxRate, 2);

            $coupon = $this->resolveCoupon($user, $data['coupon_code'] ?? null, $storeId);
            $discountAmount = $coupon?->calculateDiscount($subTotal) ?? 0.0;
            $couponCode = $coupon?->code;

            $deliveryTotal = (float) ($quote['amount'] ?? $quote['total'] ?? 0.0);




            $availableDeliveryTimings = $this->resolveAvailableDeliveryTimings($quote);
            $deliveryTiming = $this->resolveDeliveryPaymentTiming(
                $requestedDeliveryTiming ?? $storedDeliveryTiming,
                $availableDeliveryTimings,
                $quote,
            );


            $this->shippingQuoteService->rememberDeliveryPaymentTiming($user, $department, $deliveryTiming);

            $depositContext = $this->buildDepositContext($quote, $cartItems, $subTotal, $deliveryTotal);
            $depositOrderFields = $depositContext['order_fields'];
            $depositPayload = $depositContext['payload'];
            $itemDepositPolicies = $depositContext['item_policies'];


            $deliveryPaymentSnapshot = $this->buildDeliveryPaymentSnapshot(
                $quote,
                $deliveryTiming,
                $availableDeliveryTimings,
                $deliveryTotal,
                $data['delivery_user_note'] ?? null,
                $user,
                $subTotal,
                $discountAmount,
                $taxAmount,
                $depositContext,

            );

            $quote = $this->appendDeliveryPaymentToQuote($quote, $deliveryPaymentSnapshot);

            $quoteReference = $this->extractQuoteReference($quote);

            $finalAmount = round($subTotal - $discountAmount + $taxAmount + $deliveryTotal, 2);

            $telemetryContext = $this->buildCheckoutTelemetryContext($user, $cartItems, [
                'department' => $department,
                'delivery_total' => $deliveryTotal,
                'discount_amount' => $discountAmount,
                'tax_amount' => $taxAmount,
                'final_amount' => $finalAmount,
                'coupon_id' => $coupon?->getKey(),
                'coupon_code' => $couponCode,
            ]);



            $this->telemetry->record('checkout.begin_checkout', $telemetryContext);

            $paymentDetails = $this->normalizePaymentPayload($data['payment'] ?? null);
            $manualTransferDetails = $this->normalizeManualTransferPayload($data['manual_transfer'] ?? null);

            $normalizedPaymentMethod = self::normalizePaymentMethod($data['payment_method'] ?? null);

            if ($storeModel !== null && $storeStatus !== null) {
                $storeTransferContext = $this->prepareStoreManualTransfer(
                    $storeModel,
                    $storeStatus,
                    $paymentDetails,
                    $manualTransferDetails,
                    $normalizedPaymentMethod
                );

                $paymentDetails = $storeTransferContext['payment'];
                $manualTransferDetails = $storeTransferContext['manual_transfer'];
                $storeGatewayAccountModel = $storeTransferContext['store_gateway_account'] ?? null;
            }


            $addressSnapshot = $this->addressToArray($address);
            $deliveryPaymentTiming = $deliveryPaymentSnapshot['timing'] ?? null;
            $deliveryPaymentStatus = $deliveryPaymentSnapshot['delivery_payment_status'] ?? null;
            $deliveryOnlinePayable = round((float) ($deliveryPaymentSnapshot['online_payable'] ?? 0), 2);
            $deliveryCodFee = round((float) ($deliveryPaymentSnapshot['cod_fee'] ?? 0), 2);
            $deliveryCodDue = round((float) ($deliveryPaymentSnapshot['cod_due'] ?? 0), 2);
            $createdAt = now();
            $statusHistory = [[
                'status' => Order::STATUS_PROCESSING,
                'recorded_at' => $createdAt->toIso8601String(),
                'user_id' => $user->getKey(),
                'comment' => __('تم إنشاء الطلب من خلال واجهة برمجة التطبيقات.'),
                'display' => Order::statusTimelineMessage(Order::STATUS_PROCESSING),
                'icon' => Order::statusIcon(Order::STATUS_PROCESSING),

            ]];

            foreach ($cartItems as $cartItem) {
                $itemModel = $cartItem->item;

                if (! $itemModel instanceof Item) {
                    continue;
                }

                $attributes = is_array($cartItem->attributes) ? $cartItem->attributes : [];
                $variantKey = $cartItem->variant_key ?? '';

                if ($variantKey === '' && $attributes !== []) {
                    $variantKey = $this->itemPurchaseOptionsService->generateVariantKey($itemModel, $attributes);
                }

                try {
                    $this->itemPurchaseOptionsService->reserveStock($itemModel, $variantKey, (int) $cartItem->quantity);
                } catch (ValidationException $exception) {
                    throw new CheckoutValidationException(
                        __('الكمية المطلوبة غير متوفرة حالياً لأحد عناصر السلة.'),
                        'out_of_stock',
                        $exception
                    );
                }
            }

            $assuranceSnapshot = $this->resolveTradeAssuranceSnapshot($cartItems);
            $cartSnapshot = $this->buildCartSnapshot($cartItems, $cartMetrics);

            if ($assuranceSnapshot !== null) {
                $cartSnapshot['assurance'] = $assuranceSnapshot;
                if (is_array($quote)) {
                    $quote['assurance'] = $assuranceSnapshot;
                }
            }

            $order = Order::create([
                'user_id' => $user->getKey(),
                'seller_id' => $this->resolveSellerId($cartItems),
                'store_id' => $storeModel?->getKey() ?? $storeId,
                'department' => $department,
                'order_number' => $this->generateProvisionalOrderNumber(),
                'invoice_no' => $this->generateInvoiceNumber($department),

                'total_amount' => $subTotal,
                'tax_amount' => $taxAmount,
                'discount_amount' => $discountAmount,
                'final_amount' => $finalAmount,
                'payment_method' => $normalizedPaymentMethod,
                'payment_status' => 'pending',
                'order_status' => Order::STATUS_PROCESSING,
                'shipping_address' => json_encode($addressSnapshot, JSON_UNESCAPED_UNICODE),
                'billing_address' => $data['billing_address'] ?? null,
                'notes' => $data['notes'] ?? null,
                'address_snapshot' => $addressSnapshot,
                'delivery_price' => $deliveryTotal,
                'delivery_price_breakdown' => $quote['breakdown'] ?? null,
                'delivery_payment_timing' => $deliveryPaymentTiming,
                'delivery_payment_status' => $deliveryPaymentStatus,
                'delivery_online_payable' => $deliveryOnlinePayable,
                'delivery_cod_fee' => $deliveryCodFee,
                'delivery_cod_due' => $deliveryCodDue,
                'delivery_fee' => $deliveryTotal,
                'delivery_surcharge' => $this->resolveSurcharge($quote),
                'delivery_discount' => $this->resolveDiscount($quote),
                'delivery_total' => $deliveryTotal,
                'delivery_collected_amount' => 0,
                'cart_snapshot' => $cartSnapshot,
                'pricing_snapshot' => $quote,

                'deposit_minimum_amount' => $depositOrderFields['deposit_minimum_amount'],
                'deposit_ratio' => $depositOrderFields['deposit_ratio'],
                'deposit_amount_paid' => $depositOrderFields['deposit_amount_paid'],
                'deposit_remaining_balance' => $depositOrderFields['deposit_remaining_balance'],
                'deposit_includes_shipping' => $depositOrderFields['deposit_includes_shipping'],


                'status_timestamps' => [
                    Order::STATUS_PROCESSING => $createdAt->toIso8601String(),
                ],
                'status_history' => $statusHistory,
                'payment_payload' => array_filter([
                    'requested_method' => $normalizedPaymentMethod,
                    'quote_id' => $quoteReference['id'] ?? ($quote['id'] ?? null),
                    'quote_reference' => $quoteReference !== [] ? $quoteReference : null,
                    'quote_expires_at' => $quoteReference['expires_at'] ?? null,


                    'delivery_payment' => $deliveryPaymentSnapshot,
                    'delivery_payment_status' => $deliveryPaymentSnapshot['delivery_payment_status'] ?? null,
                    'delivery_payment_timing' => $deliveryPaymentSnapshot['timing'] ?? null,
                    'delivery_note_snapshot' => $deliveryPaymentSnapshot['note_snapshot'] ?? null,
                    'deposit' => $depositPayload,
                    'payment' => $paymentDetails,
                    'manual_transfer' => $manualTransferDetails,

                ], static fn ($value) => $value !== null),




                'payment_due_at' => $createdAt,
                'last_quoted_at' => $createdAt,
                'coupon_code' => $couponCode,
                'coupon_id' => $coupon?->getKey(),
            ]);



            
            $order = $order->refreshOrderNumber();
            $this->delegateNotificationService->notifyNewOrder($order);

            if ($coupon) {
                $coupon->recordUsage($user->getKey(), $order->getKey());
                $user->cartCouponSelection()
                    ->where('coupon_id', $coupon->getKey())
                    ->delete();
            }

            foreach ($cartItems as $cartItem) {
                $item = $cartItem->item;
                $weightKg = $this->resolveWeightInKilograms($cartItem);
                $weightGrams = $weightKg === null ? 0.0 : round($weightKg * 1000, 3);
                $weightKgValue = $weightKg === null ? 0.0 : round($weightKg, 3);
                $cartItemId = $cartItem->getKey();
                $orderItemDeposit = $itemDepositPolicies[$cartItemId] ?? null;

                $pricingSnapshot = [
                    'unit_price' => $cartItem->unit_price,
                    'unit_price_locked' => $cartItem->unit_price_locked,
                    'currency' => $cartItem->currency,
                ];

                if (isset($orderItemDeposit['pricing_snapshot'])) {
                    $pricingSnapshot['deposit'] = $orderItemDeposit['pricing_snapshot'];
                }

                $depositMinimum = $orderItemDeposit['deposit_minimum_amount'] ?? 0.0;
                $depositRatio = $orderItemDeposit['deposit_ratio'] ?? null;
                $depositRemaining = $orderItemDeposit['deposit_remaining_balance'] ?? 0.0;
                $depositIncludesShipping = $orderItemDeposit['deposit_includes_shipping'] ?? false;


                OrderItem::create([
                    'order_id' => $order->getKey(),
                    'item_id' => $item?->getKey(),
                    'variant_id' => $cartItem->variant_id,
                    'item_name' => $item?->name ?? $cartItem->item_id,
                    'price' => $cartItem->getLockedUnitPrice(),
                    'quantity' => $cartItem->quantity,
                    'subtotal' => round($cartItem->quantity * $cartItem->getLockedUnitPrice(), 2),
                    'options' => $cartItem->attributes,
                    'attributes' => $cartItem->attributes,
                    'item_snapshot' => $this->buildItemSnapshot($cartItem),
                    'pricing_snapshot' => $pricingSnapshot,

                    'weight_grams' => $weightGrams,
                    'weight_kg' => $weightKgValue,
                
                
                    'deposit_minimum_amount' => round((float) $depositMinimum, 2),
                    'deposit_ratio' => $depositRatio !== null ? round((float) $depositRatio, 4) : null,
                    'deposit_amount_paid' => 0.0,
                    'deposit_remaining_balance' => round((float) $depositRemaining, 2),
                    'deposit_includes_shipping' => (bool) $depositIncludesShipping,
                    
                ]);
            }

            OrderHistory::create([
                'order_id' => $order->getKey(),
                'user_id' => $user->getKey(),
                'status_from' => null,
                'status_to' => Order::STATUS_PROCESSING,
                'comment' => __('تم إنشاء الطلب من خلال واجهة برمجة التطبيقات.'),
                'notify_customer' => false,
            ]);



            $this->telemetry->record('checkout.purchase', array_merge($telemetryContext, [
                'order_id' => $order->getKey(),
                'order_number' => $order->order_number,
            ]));

            CartItem::where('user_id', $user->getKey())->delete();
            $this->shippingQuoteService->clearCachedQuotes($user);

            return $order->fresh(['items']);
        });
    }



    /**
     * @param array<string, mixed> $quote
     * @param \Illuminate\Support\Collection<int, CartItem> $cartItems
     * @return array{
     *     order_fields: array<string, mixed>,
     *     payload: array<string, mixed>|null,
     *     item_policies: array<int, array<string, mixed>>
     * }
     */
    private function buildDepositContext(array $quote, Collection $cartItems, float $goodsTotal, float $deliveryTotal): array
    {
        $default = [
            'deposit_minimum_amount' => 0.0,
            'deposit_ratio' => null,
            'deposit_amount_paid' => 0.0,
            'deposit_remaining_balance' => 0.0,
            'deposit_includes_shipping' => false,
        ];

        $deposit = $quote['deposit'] ?? null;

        if (! is_array($deposit)) {
            return [
                'order_fields' => $default,
                'payload' => null,
                'item_policies' => [],
            ];
        }

        $enabled = (bool) ($deposit['enabled'] ?? false);
        if (! $enabled) {
            return [
                'order_fields' => $default,
                'payload' => null,
                'item_policies' => [],
            ];
        }

        $details = $deposit['details'] ?? null;
        $ratio = isset($deposit['ratio']) ? (float) $deposit['ratio'] : (float) ($details['ratio'] ?? 0.0);
        
        if ($ratio <= 0.0) {
            return [
                'order_fields' => $default,
                'payload' => null,
                'item_policies' => [],
            ];
        }

        $policy = is_array($deposit['policy'] ?? null)
            ? $deposit['policy']
            : (is_array($details['policy'] ?? null) ? $details['policy'] : null);

        $returnPolicyText = $deposit['return_policy_text']
            ?? ($details['return_policy_text'] ?? null);



        $summary = [
            'ratio' => $ratio,
            'policy' => $policy,
            'return_policy_text' => $returnPolicyText,
        ];

        if (is_array($details)) {
            $required = (float) ($details['required_amount'] ?? DepositCalculator::calculateRequiredAmount($summary, $goodsTotal, $deliveryTotal));
        } else {
            $required = DepositCalculator::calculateRequiredAmount($summary, $goodsTotal, $deliveryTotal);
        }



        $ratioValue = $ratio > 0.0 ? round($ratio, 4) : null;
        $requiredValue = round(max($required, 0.0), 2);


        $orderTotal = round($goodsTotal + $deliveryTotal, 2);
        $remainingOrderBalance = round(max($orderTotal - $requiredValue, 0.0), 2);
        $remainingGoodsBalance = round(max($goodsTotal - $requiredValue, 0.0), 2);

        $orderFields = [
            'deposit_minimum_amount' => 0.0,
            'deposit_ratio' => $ratioValue,
            'deposit_amount_paid' => 0.0,
            'deposit_remaining_balance' => $requiredValue,
            'deposit_includes_shipping' => false,
        ];

        $payload = [
            'enabled' => true,
            'ratio' => $ratioValue,
            'required_amount' => $requiredValue,
            'paid_amount' => 0.0,
            'remaining_amount' => $requiredValue,
            'goods_total' => round($goodsTotal, 2),
            'delivery_total' => round($deliveryTotal, 2),
            'total_order_amount' => $orderTotal,
            'remaining_order_balance' => $remainingOrderBalance,
            'remaining_goods_balance' => $remainingGoodsBalance,

            'status' => $requiredValue > 0.0 ? 'pending' : 'waived',
            'policy' => $policy,
        ];

        if ($returnPolicyText !== null && $returnPolicyText !== '') {
            $payload['return_policy_text'] = $returnPolicyText;
        }


        $allocations = $this->allocateDepositAcrossCartItems($cartItems, $requiredValue);
        $itemPolicies = [];

        foreach ($cartItems as $cartItem) {
            $cartItemId = $cartItem->getKey();

            if ($cartItemId === null) {
                continue;
            }

            $itemSubtotal = round($cartItem->quantity * $cartItem->getLockedUnitPrice(), 2);
            $itemRequired = round($allocations[$cartItemId] ?? 0.0, 2);
            $itemBalance = round(max($itemSubtotal - $itemRequired, 0.0), 2);

            $pricingSnapshot = [
                'ratio' => $ratioValue,
                'required_amount' => $itemRequired,
                    'policy' => $policy,
                'subtotal' => $itemSubtotal,
                'remaining_balance' => $itemBalance,


            ];

            if ($returnPolicyText !== null && $returnPolicyText !== '') {
                $pricingSnapshot['return_policy_text'] = $returnPolicyText;
            }


            $pricingSnapshot = array_filter($pricingSnapshot, static fn ($value) => $value !== null);


            $itemPolicies[$cartItemId] = [
                'deposit_minimum_amount' => 0.0,
                'deposit_ratio' => $ratioValue,

                'deposit_remaining_balance' => $itemRequired,
                'deposit_includes_shipping' => false,
                'remaining_balance' => $itemBalance,
                'pricing_snapshot' => $pricingSnapshot,
            ];
        }

        return [
            'order_fields' => $orderFields,
            'payload' => $payload,
            'item_policies' => $itemPolicies,
        ];
    }


    /**
     * @param Collection<int, CartItem> $cartItems
     * @return array<int, float>
     */
    private function allocateDepositAcrossCartItems(Collection $cartItems, float $requiredAmount): array
    {
        $requiredAmount = round(max($requiredAmount, 0.0), 2);

        if ($requiredAmount <= 0.0) {
            return [];
        }

        $subtotals = [];
        $totalSubtotal = 0.0;

        foreach ($cartItems as $cartItem) {
            $cartItemId = $cartItem->getKey();

            if ($cartItemId === null) {
                continue;
            }

            $subtotal = round($cartItem->quantity * $cartItem->getLockedUnitPrice(), 2);
            $subtotal = max($subtotal, 0.0);
            $subtotals[$cartItemId] = $subtotal;
            $totalSubtotal += $subtotal;
        }

        if ($subtotals === []) {
            return [];
        }

        $allocations = [];
        $remainingRequired = $requiredAmount;
        $remainingSubtotal = $totalSubtotal;
        $ids = array_keys($subtotals);
        $count = count($ids);

        foreach ($ids as $index => $cartItemId) {
            $itemsLeft = $count - $index;
            $subtotal = $subtotals[$cartItemId];

            if ($itemsLeft <= 1) {
                $allocation = round($remainingRequired, 2);
            } else {
                if ($remainingSubtotal > 0.0 && $subtotal > 0.0) {
                    $weight = $subtotal / $remainingSubtotal;
                } elseif ($remainingSubtotal > 0.0) {
                    $weight = 0.0;
                } else {
                    $weight = 1.0 / $itemsLeft;
                }

                if ($weight <= 0.0) {
                    $weight = 1.0 / $itemsLeft;
                }

                $allocation = round($remainingRequired * $weight, 2);
                $allocation = min($allocation, $remainingRequired);
            }

            $allocations[$cartItemId] = $allocation;
            $remainingRequired = max(round($remainingRequired - $allocation, 2), 0.0);
            $remainingSubtotal = max(round($remainingSubtotal - $subtotal, 2), 0.0);
        }

        if ($remainingRequired > 0.0) {
            $lastId = end($ids);

            if ($lastId !== false) {
                $allocations[$lastId] = round(($allocations[$lastId] ?? 0.0) + $remainingRequired, 2);
            }
        }

        return $allocations;
    }



    private function buildCheckoutTelemetryContext(User $user, Collection $cartItems, array $overrides = []): array
    {
        $subtotal = round($cartItems->sum(static fn (CartItem $cartItem) => $cartItem->subtotal), 2);
        $departments = $cartItems->pluck('department')->filter()->unique()->values()->all();
        $currency = $cartItems->pluck('currency')->filter()->unique()->values()->first();

        $items = $cartItems->map(static function (CartItem $cartItem): array {
            return [
                'cart_item_id' => $cartItem->getKey(),
                'item_id' => $cartItem->item_id,
                'quantity' => $cartItem->quantity,
                'subtotal' => round($cartItem->subtotal, 2),
            ];
        })->values()->all();

        $context = [
            'user_id' => $user->getKey(),
            'cart_item_count' => $cartItems->count(),
            'cart_total_quantity' => (int) $cartItems->sum('quantity'),
            'cart_subtotal' => $subtotal,
            'departments' => $departments,
            'cart_currency' => $currency,
            'items' => $items,
        ];

        if ($overrides !== []) {
            $context = array_merge($context, array_filter($overrides, static fn ($value) => $value !== null));
        }

        return $context;
    }


    private function loadCartItems(User $user): Collection
    {
        return CartItem::query()
            ->with('item')
            ->where('user_id', $user->getKey())
            ->get();
    }



    private function normalizeCurrency(?string $currency): ?string
    {
        if ($currency === null) {
            return null;
        }

        return strtoupper($currency);
    }


    private function resolveDepartment(Collection $cartItems, ?string $requested): string
    {
        $departments = $cartItems->pluck('department')->filter()->unique();

        if ($departments->count() > 1) {
            throw ValidationException::withMessages([
                'cart' => __('لا يمكن إتمام الطلب بسبب اختلاف الأقسام داخل السلة.'),
            ]);
        }

        $department = $departments->first();

        if ($requested !== null && $department !== null && $requested !== $department) {
            throw ValidationException::withMessages([
                'department' => __('القسم المحدد لا يتطابق مع عناصر السلة.'),
            ]);
        }

        if ($requested !== null) {
            return $requested;
        }

        if ($department === null) {
            throw ValidationException::withMessages([
                'department' => __('تعذر تحديد القسم المرتبط بالسلة.'),
            ]);
        }

        return $department;
    }

    private function resolveAddress(User $user, $addressId): Address
    {
        if ($addressId === null) {
            throw ValidationException::withMessages([
                'address_id' => __('يجب اختيار عنوان صالح لإتمام الطلب.'),
            ])->errorBag('address_required');
        }

        $address = Address::query()
            ->where('user_id', $user->getKey())
            ->find($addressId);

        if (! $address) {
            throw ValidationException::withMessages([
                'address_id' => __('لم يتم العثور على العنوان المطلوب.'),
            ])->errorBag('address_required');
        }

        $distance = $address->distanceInKm();

        if ($address->latitude === null || $address->longitude === null || $distance === null || $distance < 0) {
            throw ValidationException::withMessages([
                'address_id' => __('يجب اختيار عنوان صالح لإتمام الطلب.'),
            ])->errorBag('address_required');
        }

        return $address;
    }

    private function ensureItemsAreAvailable(Collection $cartItems): void
    {
        $missing = [];

        foreach ($cartItems as $cartItem) {
            $item = $cartItem->item;

            if (! $item instanceof Item) {
                $missing[] = $cartItem->item_id;
                continue;
            }

            if ($item->status !== 'approved') {
                $missing[] = $item->name;
            }
        }

        if (! empty($missing)) {
            throw ValidationException::withMessages([
                'cart' => __('بعض العناصر لم تعد متاحة: :items', ['items' => implode(', ', $missing)]),
            ]);
        }
    }



    private function ensureCartItemsMatchLockedPricing(Collection $cartItems): void
    {
        foreach ($cartItems as $cartItem) {
            $currentPrice = $this->resolveCartItemCurrentUnitPrice($cartItem);

            if ($currentPrice !== null) {
                $lockedPrice = round($cartItem->getLockedUnitPrice(), 2);

                if (round($currentPrice, 2) !== $lockedPrice) {
                    throw new CheckoutValidationException(
                        __('تم تغيير سعر أحد عناصر السلة. يرجى تحديث السلة قبل المتابعة.'),
                        'price_changed'
                    );
                }
            }

            $availableQuantity = $this->resolveCartItemAvailableQuantity($cartItem);

            if ($availableQuantity !== null && (int) $cartItem->quantity > $availableQuantity) {
                throw new CheckoutValidationException(
                    __('الكمية المطلوبة غير متوفرة حالياً لأحد عناصر السلة.'),
                    'out_of_stock'
                );
            }
        }
    }

    private function resolveCartItemCurrentUnitPrice(CartItem $cartItem): ?float
    {
        $item = $cartItem->item;

        if ($item instanceof Item) {
            return $item->calculateDiscountedPrice();

        }

        $snapshot = is_array($cartItem->stock_snapshot) ? $cartItem->stock_snapshot : [];
        $priceKeys = [
            'unit_price',
            'price',
            'current_price',
            'selling_price',
            'sale_price',
            'stock.price',
            'pricing.unit_price',
        ];

        foreach ($priceKeys as $key) {
            $value = Arr::get($snapshot, $key);

            if ($value !== null && is_numeric($value)) {
                return (float) $value;
            }
        }

        return null;
    }

    private function resolveCartItemAvailableQuantity(CartItem $cartItem): ?int
    {

        $item = $cartItem->item;

        if ($item instanceof Item) {
            $attributes = is_array($cartItem->attributes) ? $cartItem->attributes : [];
            $variantKey = $cartItem->variant_key ?? '';

            if ($variantKey === '' && $attributes !== []) {
                $variantKey = $this->itemPurchaseOptionsService->generateVariantKey($item, $attributes);
            }

            $stock = $this->itemPurchaseOptionsService->resolveAvailableStock($item, $variantKey);

            if ($stock !== null) {
                return $stock;
            }
        }


        $snapshot = is_array($cartItem->stock_snapshot) ? $cartItem->stock_snapshot : [];
        $quantityKeys = [
            'available_quantity',
            'available',
            'stock_available',
            'stock',
            'quantity_available',
            'quantity',
            'qty_available',
            'remaining',
            'stock.available',
            'stock.remaining',
        ];

        foreach ($quantityKeys as $key) {
            $value = Arr::get($snapshot, $key);

            if ($value !== null && is_numeric($value)) {
                return max(0, (int) $value);
            }
        }



        if ($item instanceof Item) {
            $attributes = $item->getAttributes();
            $itemQuantityKeys = [
                'available_quantity',
                'stock',
                'stock_available',
                'quantity',
                'remaining_quantity',
            ];

            foreach ($itemQuantityKeys as $key) {
                $value = Arr::get($attributes, $key);

                if ($value !== null && is_numeric($value)) {
                    return max(0, (int) $value);
                }
            }
        }

        return null;
    }







    private function resolveCoupon(User $user, ?string $code, ?int $storeId): ?Coupon
    {
        if ($code === null || trim($code) === '') {
            return null;
        }

        $normalized = Str::upper(trim($code));

        $couponQuery = Coupon::query()
            ->whereRaw('upper(code) = ?', [$normalized])
            ->active()
            ->forStore($storeId);

        $coupon = $couponQuery->first();

        if (! $coupon) {
            throw ValidationException::withMessages([
                'coupon_code' => __('رمز القسيمة غير صالح.'),
            ]);
        }

        if (! $coupon->isWithinUsageLimits($user->getKey())) {
            throw ValidationException::withMessages([
                'coupon_code' => __('تم تجاوز الحد الأقصى لاستخدام هذه القسيمة.'),
            ]);
        }

        return $coupon;
    }

    private function resolveSellerId(Collection $cartItems): ?int
    {
        foreach ($cartItems as $cartItem) {
            $item = $cartItem->item;

            if ($item instanceof Item && $item->user_id) {
                return (int) $item->user_id;
            }
        }

        return null;
    }

    private function resolveStoreId(Collection $cartItems): ?int
    {
        $storeIds = $cartItems->pluck('store_id')->filter()->unique()->values();

        if ($storeIds->count() > 1) {
            throw new CheckoutValidationException(
                __('لا يمكن دمج منتجات متاجر متعددة في طلب واحد.'),
                'mixed_store_cart'
            );
        }

        $hasStoreItems = $storeIds->isNotEmpty();
        $hasGeneralItems = $cartItems->contains(static fn (CartItem $cartItem) => $cartItem->store_id === null);

        if ($hasStoreItems && $hasGeneralItems) {
            throw new CheckoutValidationException(
                __('يرجى إكمال أو تفريغ السلة قبل الانتقال إلى متاجر أخرى.'),
                'store_cart_conflict'
            );
        }

        return $storeIds->first() ?: null;
    }

    private function loadCheckoutStore(int $storeId): Store
    {
        $store = Store::with(['settings', 'workingHours'])->find($storeId);

        if (! $store) {
            throw new CheckoutValidationException(
                __('المتجر غير متاح حالياً.'),
                'store_unavailable'
            );
        }

        return $store;
    }

    private function guardStoreCheckout(array $status, float $subTotal): void
    {
        $isOpen = (bool) ($status['is_open_now'] ?? false);
        $closureMode = $status['closure_mode'] ?? 'full';

        if (! $isOpen || $closureMode === 'browse_only') {
            throw new CheckoutValidationException(
                __('لا يمكن إكمال الطلب لأن المتجر مغلق حالياً.'),
                'store_closed'
            );
        }

        $minOrderAmount = (float) ($status['min_order_amount'] ?? 0);
        if ($minOrderAmount > 0 && $subTotal + 0.0001 < $minOrderAmount) {
            throw new CheckoutValidationException(
                __('قيمة الطلب أقل من الحد الأدنى المسموح به للمتجر.'),
                'store_min_order'
            );
        }
    }



    private function generateProvisionalOrderNumber(): string
    {
        try {
            $orderNumber = OrderNumberGenerator::provisional();
        } catch (Throwable $exception) {
            $this->telemetry->record('checkout.order_number_generation_failed', [
                'stage' => 'exception',
                'message' => $exception->getMessage(),
            ]);

            throw new CheckoutValidationException(
                __('تعذر إنشاء رقم مؤقت للطلب. يرجى المحاولة لاحقاً.'),
                'order_number_unavailable'
            );
        }

        if (! is_string($orderNumber) || trim($orderNumber) === '') {
            $this->telemetry->record('checkout.order_number_generation_failed', [
                'stage' => 'empty',
            ]);

            throw new CheckoutValidationException(
                __('تعذر إنشاء رقم مؤقت للطلب. يرجى المحاولة لاحقاً.'),
                'order_number_unavailable'
            );
        }

        return $orderNumber;
    
    }

    /**
     * @param array<string, mixed>|null $paymentDetails
     * @param array<string, mixed>|null $manualTransferDetails
     * @return array{
     *     payment: ?array<string, mixed>,
     *     manual_transfer: ?array<string, mixed>,
     *     store_gateway_account?: StoreGatewayAccount
     * }
     */
    private function prepareStoreManualTransfer(
        Store $store,
        array $storeStatus,
        ?array $paymentDetails,
        ?array $manualTransferDetails,
        ?string $paymentMethod
    ): array {
        if ($paymentMethod !== 'manual_bank') {
            return [
                'payment' => $paymentDetails,
                'manual_transfer' => $manualTransferDetails,
            ];
        }

        $allowsManual = (bool) ($storeStatus['allow_manual_payments'] ?? true);

        if (! $allowsManual) {
            throw new CheckoutValidationException(
                __('لا يمكن قبول الحوالات اليدوية لهذا المتجر حالياً.'),
                'store_manual_payments_disabled'
            );
        }

        $paymentDetails = $paymentDetails ?? [];

        $accountId = $this->normalizeNullableInt(
            $paymentDetails['store_gateway_account_id']
                ?? $paymentDetails['store_bank_id']
                ?? $paymentDetails['bank_id']
                ?? null
        );

        if ($accountId === null) {
            throw new CheckoutValidationException(
                __('يرجى اختيار الحساب البنكي الخاص بالمتجر قبل الإرسال.'),
                'store_gateway_account_required'
            );
        }

        $gatewayAccount = $this->resolveStoreGatewayAccount($store, $accountId);

        if ($manualTransferDetails === null) {
            throw new CheckoutValidationException(
                __('أدخل بيانات الحوالة اليدوية قبل المتابعة.'),
                'store_manual_transfer_required'
            );
        }

        $senderName = $this->normalizeNullableString($manualTransferDetails['sender_name'] ?? null);
        $transferReference = $this->normalizeNullableString(
            $manualTransferDetails['transfer_reference']
                ?? $manualTransferDetails['transfer_code']
                ?? null
        );

        if ($senderName === null) {
            throw new CheckoutValidationException(
                __('اكتب اسم صاحب الحوالة كما يظهر في الإيصال.'),
                'store_manual_transfer_sender_required'
            );
        }

        if ($transferReference === null) {
            throw new CheckoutValidationException(
                __('الرجاء إدخال رقم أو مرجع الحوالة البنكية.'),
                'store_manual_transfer_reference_required'
            );
        }

        $attachments = $manualTransferDetails['attachments'] ?? [];
        if (! is_array($attachments) || $attachments === []) {
            throw new CheckoutValidationException(
                __('صورة الإيصال مطلوبة لتأكيد الحوالة.'),
                'store_manual_transfer_receipt_required'
            );
        }

        $gateway = $gatewayAccount->storeGateway;
        $accountSnapshot = [
            'id' => $gatewayAccount->getKey(),
            'store_id' => $store->getKey(),
            'gateway' => $gateway ? [
                'id' => $gateway->getKey(),
                'name' => $gateway->name,
                'logo_url' => $gateway->logo_url,
            ] : null,
            'beneficiary_name' => $gatewayAccount->beneficiary_name,
            'account_number' => $gatewayAccount->account_number,
        ];

        if ($gatewayAccount->account_number === null) {
            unset($accountSnapshot['account_number']);
        }

        $paymentDetails['bank_id'] = $gatewayAccount->getKey();
        $paymentDetails['store_gateway_account_id'] = $gatewayAccount->getKey();
        $paymentDetails['bank_name'] = $gateway?->name ?? $gatewayAccount->beneficiary_name;
        $paymentDetails['account_number'] = $gatewayAccount->account_number;
        $paymentDetails['store_gateway_account'] = array_filter(
            $accountSnapshot,
            static fn ($value) => $value !== null && $value !== ''
        );

        $fallbackManualBankId = $this->resolveFallbackManualBankId();
        if ($fallbackManualBankId !== null) {
            $paymentDetails['manual_bank_id'] = $fallbackManualBankId;
        } else {
            unset($paymentDetails['manual_bank_id']);
        }

        $manualTransferDetails['sender_name'] = $senderName;
        $manualTransferDetails['transfer_reference'] = $transferReference;
        $manualTransferDetails['store_gateway_account_id'] = $gatewayAccount->getKey();
        $manualTransferDetails['store_gateway_account'] = $paymentDetails['store_gateway_account'];
        $manualTransferDetails['store'] = [
            'id' => $store->getKey(),
            'name' => $store->name,
            'slug' => $store->slug,
        ];

        return [
            'payment' => $paymentDetails,
            'manual_transfer' => $manualTransferDetails,
            'store_gateway_account' => $gatewayAccount,
        ];
    }

    private function resolveStoreGatewayAccount(Store $store, int $accountId): StoreGatewayAccount
    {
        $account = StoreGatewayAccount::query()
            ->where('store_id', $store->getKey())
            ->where('is_active', true)
            ->where('id', $accountId)
            ->whereHas('storeGateway', static fn ($query) => $query->where('is_active', true))
            ->with('storeGateway')
            ->first();

        if (! $account) {
            throw new CheckoutValidationException(
                __('الحساب البنكي المحدد غير متاح لهذا المتجر.'),
                'store_gateway_account_unavailable'
            );
        }

        return $account;
    }

    private function createManualPaymentRequestForOrder(
        Order $order,
        User $user,
        ?array $paymentDetails,
        array $manualTransferDetails,
        ?StoreGatewayAccount $storeGatewayAccount,
        float $finalAmount,
        string $currency
    ): void {
        try {
            $storeGatewayAccountSnapshot = $manualTransferDetails['store_gateway_account']
                ?? $this->normalizeStoreGatewayAccountSnapshot($storeGatewayAccount);

            $transactionMeta = array_filter([
                'payment' => $paymentDetails,
                'manual_transfer' => $manualTransferDetails,
                'store_gateway_account' => $storeGatewayAccountSnapshot,
            ], static fn ($value) => $value !== null && $value !== [] && $value !== '');

            $transaction = PaymentTransaction::create([
                'user_id' => $user->getKey(),
                'order_id' => $order->getKey(),
                'payable_type' => Order::class,
                'payable_id' => $order->getKey(),
                'amount' => $finalAmount,
                'currency' => $currency,
                'payment_gateway' => 'manual_bank',
                'payment_status' => 'pending',
                'meta' => $transactionMeta === [] ? null : $transactionMeta,
                'idempotency_key' => sprintf('checkout:manual:%d:%s', $order->getKey(), Str::uuid()),
            ]);

            $manualBankId = $paymentDetails['manual_bank_id']
                ?? $paymentDetails['bank_id']
                ?? $this->resolveFallbackManualBankId();

            $storeGatewayAccountId = $manualTransferDetails['store_gateway_account_id']
                ?? ($storeGatewayAccount?->getKey());

            $manualRequestPayload = array_filter([
                'manual_bank_id' => $manualBankId,
                'bank_id' => $manualBankId,
                'bank_name' => $paymentDetails['bank_name'] ?? null,
                'sender_name' => $manualTransferDetails['sender_name'] ?? null,
                'reference' => $manualTransferDetails['transfer_reference']
                    ?? $manualTransferDetails['transfer_code']
                    ?? null,
                'note' => $manualTransferDetails['note'] ?? null,
                'manual_transfer' => $manualTransferDetails,
                'attachments' => $manualTransferDetails['attachments'] ?? null,
                'receipt_path' => $manualTransferDetails['receipt_path'] ?? null,
                'receipt_url' => $manualTransferDetails['receipt_url'] ?? null,
                'store_gateway_account_id' => $storeGatewayAccountId,
                'store_gateway_account' => $storeGatewayAccountSnapshot,
                'store' => $manualTransferDetails['store'] ?? null,
                'metadata' => ['manual_transfer' => $manualTransferDetails],
            ], static fn ($value) => $value !== null && $value !== '');

            $manualRequest = $this->manualPaymentRequestService->createOrUpdateForManualTransaction(
                $user,
                Order::class,
                $order->getKey(),
                $transaction,
                $manualRequestPayload
            );

            if ($manualRequest instanceof ManualPaymentRequest
                && $transaction->manual_payment_request_id !== $manualRequest->getKey()
            ) {
                $transaction->manual_payment_request_id = $manualRequest->getKey();
                $transaction->save();
            }
        } catch (Throwable $exception) {
            $this->telemetry->record('checkout.manual_transfer.draft_failed', [
                'order_id' => $order->getKey(),
                'message' => $exception->getMessage(),
            ]);
        }
    }

    private function normalizeStoreGatewayAccountSnapshot(?StoreGatewayAccount $account): ?array
    {
        if (! $account) {
            return null;
        }

        $snapshot = array_filter([
            'id' => $account->getKey(),
            'store_id' => $account->store_id,
            'store_gateway_id' => $account->store_gateway_id,
            'beneficiary_name' => $account->beneficiary_name,
            'account_number' => $account->account_number,
        ], static fn ($value) => $value !== null && $value !== '');

        return $snapshot === [] ? null : $snapshot;
    }

    private function resolveFallbackManualBankId(): ?int
    {
        if ($this->defaultManualBankResolved) {
            return $this->defaultManualBankId;
        }

        $this->defaultManualBankResolved = true;

        $configuredId = config('payments.default_manual_bank_id');
        if (is_numeric($configuredId)) {
            $candidate = (int) $configuredId;
            if ($candidate > 0) {
                return $this->defaultManualBankId = $candidate;
            }
        }

        try {
            $manualBank = ManualBank::query()
                ->orderBy('display_order')
                ->orderBy('id')
                ->first();
        } catch (\Throwable) {
            $manualBank = null;
        }

        $this->defaultManualBankId = $manualBank?->getKey();

        return $this->defaultManualBankId;
    }



    private function generateInvoiceNumber(?string $department = null): string
    {
        return $this->legalNumbering->generateInvoiceNumber($department);

    }

    private function buildCartSnapshot(Collection $cartItems, array $metrics): array
    {
        return [
            'items' => $cartItems->map(function (CartItem $item) {
                return $this->buildItemSnapshot($item);
            })->values()->all(),
            'metrics' => $metrics,
        ];
    }

    private function resolveTradeAssuranceSnapshot(Collection $cartItems): ?array
    {
        $storeId = $cartItems->pluck('store_id')->filter()->unique()->first();

        if (! $storeId) {
            return null;
        }

        $store = Store::with(['owner.latestApprovedVerificationRequest'])->find($storeId);

        if (! $store || ! $store->owner) {
            return null;
        }

        $owner = $store->owner;

        if ($owner->account_type !== User::ACCOUNT_TYPE_SELLER || ! $owner->hasActiveVerification()) {
            return null;
        }

        return [
            'status' => 'active',
            'store_id' => $store->id,
            'owner_id' => $owner->id,
            'policy' => 'payment_protection',
            'verification_expires_at' => $owner->verification_expires_at,
        ];
    }

    private function buildItemSnapshot(CartItem $cartItem): array
    {
        return [
            'item_id' => $cartItem->item_id,
            'variant_id' => $cartItem->variant_id,
            'quantity' => $cartItem->quantity,
            'unit_price' => $cartItem->unit_price,
            'unit_price_locked' => $cartItem->unit_price_locked,
            'currency' => $cartItem->currency,
            'attributes' => $cartItem->attributes,
            'stock_snapshot' => $cartItem->stock_snapshot,
        ];
    }

    private function resolveWeightInGrams(CartItem $cartItem): float
    {
        $weightKg = $this->resolveWeightInKilograms($cartItem);

        if ($weightKg === null) {
            return 0.0;
        }

        return round($weightKg * 1000, 3);
    }

    private function resolveWeightInKilograms(CartItem $cartItem): ?float
    {
        $snapshot = is_array($cartItem->stock_snapshot) ? $cartItem->stock_snapshot : [];

        if (array_key_exists('weight_total', $snapshot)) {
            return (float) $snapshot['weight_total'];
        }

        $weight = $this->extractWeight($snapshot);

        if ($weight !== null) {
            return $weight * max(1, (int) $cartItem->quantity);
        }

        if (is_array($cartItem->attributes)) {
            $weight = $this->extractWeight($cartItem->attributes);

            if ($weight !== null) {
                return $weight * max(1, (int) $cartItem->quantity);
            }
        }

        return null;
    }

    private function extractWeight(array $data): ?float
    {
        if (array_key_exists('weight_total', $data)) {
            return (float) $data['weight_total'];
        }

        if (array_key_exists('weight_kg', $data)) {
            return (float) $data['weight_kg'];
        }

        if (array_key_exists('weight_g', $data)) {
            return ((float) $data['weight_g']) / 1000;
        }

        if (array_key_exists('weight', $data)) {
            $unit = strtolower((string) ($data['weight_unit'] ?? 'kg'));
            $value = (float) $data['weight'];

            return $unit === 'g' || $unit === 'gram' || $unit === 'grams'
                ? $value / 1000
                : $value;
        }

        if (array_key_exists('weight_per_unit', $data)) {
            return (float) $data['weight_per_unit'];
        }

        return null;
    }





    /**
     * @param array<string, mixed> $quote
     * @return array<int, string>
     */
    private function resolveAvailableDeliveryTimings(array $quote): array
    {
        $options = [];

        $allowPayNow = Arr::get($quote, 'allow_pay_now');

        if ($allowPayNow === null) {
            $allowPayNow = Arr::get($quote, 'payment.allow_pay_now');
        }

        if ($this->boolFrom($allowPayNow)) {
            $options[] = self::DELIVERY_TIMING_PAY_NOW;
        }

        $allowPayOnDelivery = Arr::get($quote, 'allow_pay_on_delivery');

        if ($allowPayOnDelivery === null) {
            $allowPayOnDelivery = Arr::get($quote, 'payment.allow_pay_on_delivery');
        }

        if ($this->boolFrom($allowPayOnDelivery)) {
            $options[] = self::DELIVERY_TIMING_PAY_ON_DELIVERY;
        }

        $timingCodes = Arr::get($quote, 'timing_codes', Arr::get($quote, 'payment.timing_codes', []));

        if (is_array($timingCodes)) {
            foreach ($timingCodes as $key => $value) {
                if (is_string($key)) {
                    $normalizedKey = $this->normalizeTiming($key);

                    if (in_array($normalizedKey, self::INTERNAL_DELIVERY_TIMINGS, true)) {
                        $options[] = $normalizedKey;
                    }
                }

                if (is_string($value)) {
                    $normalizedValue = $this->normalizeTiming($value);

                    if (in_array($normalizedValue, self::INTERNAL_DELIVERY_TIMINGS, true)) {
                        $options[] = $normalizedValue;
                    }
                }

                if (is_bool($value) && $value === true && is_string($key)) {
                    $normalizedKey = $this->normalizeTiming($key);

                    if ($normalizedKey !== null) {
                        $options[] = $normalizedKey;
                    }
                }
            }
        }

        $options = array_values(array_unique(array_filter($options)));

        if ($options === []) {
            $requiresPrepay = $this->boolFrom(Arr::get($quote, 'payment.prepaid_required') ?? Arr::get($quote, 'prepaid_required'));
            $options[] = $requiresPrepay ? self::DELIVERY_TIMING_PAY_NOW : self::DELIVERY_TIMING_PAY_ON_DELIVERY;
        }

        return $options;
    }

    /**
     * @param array<int, string> $availableTimings
     * @param array<string, mixed> $quote
     */
    private function resolveDeliveryPaymentTiming(?string $requestedTiming, array $availableTimings, array $quote): ?string
    {
        $normalizedRequested = $this->normalizeTiming($requestedTiming);

        if ($normalizedRequested !== null) {
            if (! in_array($normalizedRequested, $availableTimings, true)) {
                throw ValidationException::withMessages([
                    'delivery_payment_timing' => __('التوقيت المحدد لدفع التوصيل غير متاح.'),
                ]);
            }

            return $normalizedRequested;
        }

        $suggested = $this->normalizeTiming(
            Arr::get($quote, 'suggested_timing')
                ?? Arr::get($quote, 'payment.suggested_timing')
        );

        if ($suggested !== null && in_array($suggested, $availableTimings, true)) {
            return $suggested;
        }

        return $availableTimings[0] ?? null;
    }

    /**
     * @param array<string, mixed> $quote
     * @param array<int, string> $availableTimings
     * @return array<string, mixed>
     */
    private function buildDeliveryPaymentSnapshot(
        array $quote,
        ?string $timing,
        array $availableTimings,
        float $deliveryTotal,
        ?string $userNote,
        User $user,
        float $subTotal,
        float $discountAmount,
        float $taxAmount,
        ?array $depositContext = null
        
        
        ): array {
        $normalizedTiming = $this->normalizeTiming($timing);

        if ($normalizedTiming === null && $availableTimings !== []) {
            $normalizedTiming = $availableTimings[0];
        }

        $deliveryAmount = round($deliveryTotal, 2);
        $codFee = $this->resolveCodFee($quote);
        $goodsPayable = max(round($subTotal - $discountAmount + $taxAmount, 2), 0.0);
        $onlineGoodsPayable = $goodsPayable;
        $onlineDeliveryPayable = $normalizedTiming === self::DELIVERY_TIMING_PAY_NOW ? $deliveryAmount : 0.0;
        $onlineDeliveryPayable = round($onlineDeliveryPayable, 2);
        if (is_array($depositContext)) {
            $depositPayload = $depositContext['payload'] ?? null;
            $depositOrderFields = $depositContext['order_fields'] ?? null;

            if (is_array($depositPayload) && ($depositPayload['enabled'] ?? false)) {
                $depositRequired = round((float) ($depositPayload['required_amount'] ?? 0.0), 2);

                if ($depositRequired > 0.0) {
                    $depositIncludesShipping = is_array($depositOrderFields)
                        ? (bool) ($depositOrderFields['deposit_includes_shipping'] ?? false)
                        : false;

                    $goodsContribution = min($depositRequired, $onlineGoodsPayable);
                    $deliveryContribution = 0.0;

                    if ($depositIncludesShipping && $depositRequired > $goodsContribution) {
                        $remainingForDelivery = round($depositRequired - $goodsContribution, 2);
                        $deliveryCap = $onlineDeliveryPayable > 0.0 ? $onlineDeliveryPayable : $deliveryAmount;
                        $deliveryContribution = min($remainingForDelivery, $deliveryCap);
                    }

                    $onlineGoodsPayable = round($goodsContribution, 2);

                    if ($deliveryContribution > 0.0) {
                        $onlineDeliveryPayable = round($deliveryContribution, 2);
                    }
                }
            }
        }

        $onlinePayable = round($onlineGoodsPayable + $onlineDeliveryPayable, 2);
        
        
        $codDue = $normalizedTiming === self::DELIVERY_TIMING_PAY_ON_DELIVERY
            ? round($deliveryAmount + $codFee, 2)
            : 0.0;

        $status = $onlinePayable <= 0.0 && $codDue <= 0.0 ? 'waived' : 'pending';


        $snapshot = [
            'timing' => $normalizedTiming,
            'available_timings' => $availableTimings,
            'online_payable' => $onlinePayable,
            'online_goods_payable' => round($onlineGoodsPayable, 2),
            'online_delivery_payable' => $onlineDeliveryPayable,

            'cod_fee' => $codFee,
            'cod_due' => $codDue,
            'delivery_payment_status' => $status,
            'quoted_amount' => $deliveryAmount,
        ];

        $timingCodes = Arr::get($quote, 'timing_codes', Arr::get($quote, 'payment.timing_codes', []));

        if (is_array($timingCodes) && $timingCodes !== []) {
            $snapshot['timing_codes'] = $timingCodes;
        }

        $suggestedTiming = $this->normalizeTiming(
            Arr::get($quote, 'suggested_timing')
                ?? Arr::get($quote, 'payment.suggested_timing')
        );

        if ($suggestedTiming !== null) {
            $snapshot['suggested_timing'] = $suggestedTiming;
        }

        if ($userNote !== null && trim($userNote) !== '') {
            $snapshot['note_snapshot'] = [
                'body' => $userNote,
                'recorded_at' => now()->toIso8601String(),
                'recorded_by' => $user->getKey(),
            ];
        }

        return $snapshot;
    }

    /**
     * @param array<string, mixed> $quote
     * @param array<string, mixed> $snapshot
     * @return array<string, mixed>
     */
    private function appendDeliveryPaymentToQuote(array $quote, array $snapshot): array
    {
        $quote['delivery_payment'] = $snapshot;
        $quote['delivery_payment_timing'] = $snapshot['timing'] ?? null;

        if (isset($snapshot['note_snapshot'])) {
            $quote['delivery_note_snapshot'] = $snapshot['note_snapshot'];
        }

        return $quote;
    }



    /**
     * @param array<string, mixed> $quote
     * @return array<string, mixed>
     */
    private function extractQuoteReference(array $quote): array
    {
        $id = Arr::get($quote, 'quote_id')
            ?? Arr::get($quote, 'id')
            ?? Arr::get($quote, 'meta.quote.id');

        $expiresAt = Arr::get($quote, 'expires_at')
            ?? Arr::get($quote, 'meta.quote.expires_at');

        $metadata = Arr::get($quote, 'meta.quote.metadata');

        if (! is_array($metadata)) {
            $metadata = [];
        }

        $reference = [];

        if (is_string($id) && $id !== '') {
            $reference['id'] = $id;
        }

        if (is_string($expiresAt) && $expiresAt !== '') {
            $reference['expires_at'] = $expiresAt;
        }

        if ($metadata !== []) {
            $reference['metadata'] = $metadata;
        }

        return $reference;
    }




    private function normalizePaymentPayload($value): ?array
    {
        if ($value === null || ! is_array($value)) {
            return null;
        }

        $method = $this->normalizeNullableString($value['method'] ?? $value['payment_method'] ?? null);
        $bankId = $this->normalizeNullableInt($value['bank_id'] ?? $value['manual_bank_id'] ?? null);
        $bankName = $this->normalizeNullableString($value['bank_name'] ?? null);
        $accountNumber = $this->normalizeNullableString($value['account_number'] ?? null);

        $normalized = array_filter([
            'method' => $method,
            'bank_id' => $bankId,
            'manual_bank_id' => $bankId,
            'bank_name' => $bankName,
            'account_number' => $accountNumber,
        ], static fn ($entry) => $entry !== null && $entry !== '');

        if ($normalized === []) {
            return null;
        }

        if ($bankId === null) {
            unset($normalized['manual_bank_id']);
        }

        return $normalized;
    }

    private function normalizeManualTransferPayload($value): ?array
    {
        if ($value === null || ! is_array($value)) {
            return null;
        }

        $senderName = $this->normalizeNullableString($value['sender_name'] ?? null);
        $transferReference = $this->normalizeNullableString(
            $value['transfer_reference']
                ?? $value['transfer_code']
                ?? $value['reference']
        );
        $note = $this->normalizeNullableMultiline($value['note'] ?? null);

        $normalized = [];


        if ($senderName !== null) {
            $normalized['sender_name'] = $senderName;
        }

        if ($transferReference !== null) {
            $normalized['transfer_reference'] = $transferReference;
        }

        if ($note !== null) {
            $normalized['note'] = $note;
        }

        $receiptData = $value['receipt'] ?? null;
        $receiptUrl = null;
        $receiptPath = $this->normalizeNullableString($value['receipt_path'] ?? null);
        $receiptDisk = $this->normalizeNullableString($value['receipt_disk'] ?? null);
        $providedUrl = $this->normalizeNullableString($value['url'] ?? null);

        if (is_array($receiptData)) {
            $sanitizedReceipt = $this->normalizeManualTransferArrayValue($receiptData);

            if ($sanitizedReceipt !== []) {
                $normalized['receipt'] = $sanitizedReceipt;
                $receiptUrl = $this->normalizeNullableString($sanitizedReceipt['receipt_url'] ?? $sanitizedReceipt['url'] ?? null);

                $receiptPathFromReceipt = $this->normalizeNullableString($sanitizedReceipt['receipt_path'] ?? $sanitizedReceipt['path'] ?? null);
                if ($receiptPathFromReceipt !== null) {
                    $receiptPath = $receiptPathFromReceipt;
                }

                $receiptDiskFromReceipt = $this->normalizeNullableString($sanitizedReceipt['receipt_disk'] ?? $sanitizedReceipt['disk'] ?? null);
                if ($receiptDiskFromReceipt !== null) {
                    $receiptDisk = $receiptDiskFromReceipt;
                }

                if (! isset($normalized['attachments']) && isset($sanitizedReceipt['attachments'])) {
                    $receiptAttachments = $this->normalizeManualTransferAttachments($sanitizedReceipt['attachments']);
                    if ($receiptAttachments !== []) {
                        $normalized['attachments'] = $receiptAttachments;
                    }
                }
            }
        } else {
            $receiptString = $this->normalizeNullableString($receiptData);
            if ($receiptString !== null) {
                $normalized['receipt'] = $receiptString;
                $receiptUrl = $receiptString;
            }
        }

        $directAttachments = $this->normalizeManualTransferAttachments($value['attachments'] ?? null);
        if ($directAttachments !== []) {
            $normalized['attachments'] = $directAttachments;
        }

        $explicitReceiptUrl = $this->normalizeNullableString(
            $value['receipt_url']
                ?? Arr::get($value, 'receipt.url')
                ?? Arr::get($value, 'receipt.receipt_url')
        );

        if ($explicitReceiptUrl !== null) {
            $receiptUrl = $explicitReceiptUrl;
        }

        if ($receiptUrl !== null) {
            $normalized['receipt_url'] = $receiptUrl;

            if (! isset($normalized['url'])) {
                $normalized['url'] = $receiptUrl;
            }

            if (! isset($normalized['receipt']) || $normalized['receipt'] === []) {
                $normalized['receipt'] = $receiptUrl;
            }
        }

        if ($providedUrl !== null) {
            $normalized['url'] = $providedUrl;

            if (! isset($normalized['receipt_url'])) {
                $normalized['receipt_url'] = $providedUrl;
            }

            if (! isset($normalized['receipt'])) {
                $normalized['receipt'] = $providedUrl;
            }
        }

        if ($receiptPath !== null) {
            $normalized['receipt_path'] = $receiptPath;
        }

        if ($receiptDisk !== null) {
            $normalized['receipt_disk'] = $receiptDisk;
        }

        foreach ($value as $rawKey => $rawEntry) {
            if (! is_int($rawKey) && ! is_string($rawKey)) {
                continue;
            }

            $key = is_int($rawKey) ? (string) $rawKey : $rawKey;

            if (in_array($key, ['sender_name', 'transfer_reference', 'transfer_code', 'note', 'receipt', 'receipt_url', 'url', 'receipt_path', 'receipt_disk', 'attachments'], true)) {
                continue;
            }

            if (array_key_exists($key, $normalized)) {
                continue;
            }

            if ($rawEntry === null) {
                continue;
            }

            if (is_string($rawEntry)) {
                $trimmed = trim($rawEntry);
                if ($trimmed === '') {
                    continue;
                }

                $normalized[$key] = $trimmed;
                continue;
            }

            if (is_array($rawEntry)) {
                $sanitized = $this->normalizeManualTransferArrayValue($rawEntry);
                if ($sanitized !== []) {
                    $normalized[$key] = $sanitized;
                }

                continue;
            }

            if (is_scalar($rawEntry)) {
                $normalized[$key] = $rawEntry;
            }
        }

        if ($transferReference !== null) {
            $normalized['transfer_code'] = $transferReference;
        }


        return $normalized === [] ? null : $normalized;
    }

    /**
     * @param mixed $value
     * @return array<int, array<int|string, mixed>>
     */
    private function normalizeManualTransferAttachments($value): array
    {
        if ($value === null) {
            return [];
        }

        if (is_array($value) && Arr::isAssoc($value)) {
            $value = [$value];
        }

        if (! is_iterable($value)) {
            return [];
        }

        $normalized = [];

        foreach ($value as $attachment) {
            if (! is_array($attachment)) {
                continue;
            }

            $sanitized = [];

            foreach ($attachment as $rawKey => $rawEntry) {
                if (! is_int($rawKey) && ! is_string($rawKey)) {
                    continue;
                }

                $key = is_int($rawKey) ? (string) $rawKey : $rawKey;

                if ($rawEntry === null) {
                    continue;
                }

                if (is_string($rawEntry)) {
                    $trimmed = trim($rawEntry);
                    if ($trimmed === '') {
                        continue;
                    }

                    $sanitized[$key] = $trimmed;
                    continue;
                }

                if (is_scalar($rawEntry) || is_array($rawEntry)) {
                    $sanitized[$key] = $rawEntry;
                }
            }

            if ($sanitized !== []) {
                $normalized[] = $sanitized;
            }
        }

        return $normalized;
    }

    /**
     * @param mixed $value
     * @return array<int|string, mixed>
     */
    private function normalizeManualTransferArrayValue($value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $normalized = [];

        foreach ($value as $rawKey => $rawEntry) {
            if (! is_int($rawKey) && ! is_string($rawKey)) {
                continue;
            }

            $key = is_int($rawKey) ? (string) $rawKey : $rawKey;

            if ($rawEntry === null) {
                continue;
            }

            if (is_string($rawEntry)) {
                $trimmed = trim($rawEntry);
                if ($trimmed === '') {
                    continue;
                }

                $normalized[$key] = $trimmed;
                continue;
            }

            if (is_array($rawEntry)) {
                if ($key === 'attachments') {
                    $attachments = $this->normalizeManualTransferAttachments($rawEntry);
                    if ($attachments !== []) {
                        $normalized[$key] = $attachments;
                    }

                    continue;
                }

                $nested = $this->normalizeManualTransferArrayValue($rawEntry);
                if ($nested !== []) {
                    $normalized[$key] = $nested;
                }

                continue;
            }

            if (is_scalar($rawEntry)) {
                $normalized[$key] = $rawEntry;
            }
        }


        return $normalized;
    }

    private function normalizeNullableString($value): ?string
    {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if ($value === null) {
            return null;
        }

        if (is_bool($value) || is_array($value)) {
            return null;
        }

        if (! is_string($value)) {
            if (is_numeric($value)) {
                $value = (string) $value;
            } else {
                return null;
            }
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function normalizeNullableInt($value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (is_int($value)) {
            return $value > 0 ? $value : null;
        }

        if (is_numeric($value) && ! is_bool($value)) {
            $intValue = (int) $value;

            return $intValue > 0 ? $intValue : null;
        }

        return null;
    }

    private function normalizeNullableMultiline($value): ?string
    {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if ($value === null) {
            return null;
        }

        if (is_bool($value) || is_array($value)) {
            return null;
        }

        if (! is_string($value)) {
            if (is_numeric($value)) {
                return (string) $value;
            }

            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $value;
    }

    private function normalizeTiming(?string $timing): ?string



    {
        return self::normalizeTimingToken($timing);
    }

    public static function normalizeTimingToken(?string $timing): ?string

    {
        if ($timing === null) {
            return null;
        }

        $normalized = Str::of($timing)
            ->trim()
            ->lower()
            ->replace('-', '_')
            ->replace(' ', '_')
            ->value();

        if ($normalized === '') {
            return null;
        }

        return self::PUBLIC_TIMING_ALIASES[$normalized] ?? $normalized;
    }


    public static function normalizePaymentMethod(?string $method): ?string
    {
        if ($method === null) {
            return null;
        }

        $trimmed = trim($method);

        if ($trimmed === '') {
            return null;
        }

        $lower = mb_strtolower($trimmed);

        if ($lower === 'null') {
            return null;
        }

        $sanitized = preg_replace('/[^a-z0-9]+/', '_', $lower) ?? $lower;
        $collapsed = str_replace('_', '', $sanitized);

        return self::PAYMENT_METHOD_ALIASES[$sanitized]
            ?? self::PAYMENT_METHOD_ALIASES[$lower]
            ?? self::PAYMENT_METHOD_ALIASES[$collapsed]
            ?? $trimmed;
    }


    /**
     * @param array<string, mixed> $quote
     */
    private function resolveCodFee(array $quote): float
    {
        $codFee = Arr::get($quote, 'cod_fee');

        if ($codFee === null) {
            $codFee = Arr::get($quote, 'payment.cod_fee');
        }

        if ($codFee === null || $codFee === '') {
            return 0.0;
        }

        return round((float) $codFee, 2);
    }

    private function boolFrom(mixed $value): bool
    {
        if (is_bool($value)) {
            return $value;
        }

        if ($value === null) {
            return false;
        }

        if (is_string($value)) {
            $filtered = filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

            if ($filtered !== null) {
                return $filtered;
            }
        }

        return (bool) $value;
    }






    /**
     * @param array<string, mixed> $quote
     */
    private function resolveSurcharge(array $quote): float
    {
        $breakdown = Arr::get($quote, 'breakdown', []);
        $total = 0.0;

        foreach ((array) $breakdown as $line) {
            $amount = $this->resolveBreakdownAmount($line);

            if ($amount > 0) {
                $total += $amount;
            }
        }

        return round($total, 2);
    }

    /**
     * @param array<string, mixed> $quote
     */
    private function resolveDiscount(array $quote): float
    {
        $breakdown = Arr::get($quote, 'breakdown', []);
        $total = 0.0;

        foreach ((array) $breakdown as $line) {
            $amount = $this->resolveBreakdownAmount($line);

            if ($amount < 0) {
                $total += abs($amount);
            }
        }

        return round($total, 2);
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

    private function addressToArray(Address $address): array
    {
        return [
            'id' => $address->getKey(),
            'label' => $address->label,
            'phone' => $address->phone,
            'latitude' => $address->latitude,
            'longitude' => $address->longitude,
            'distance_km' => $address->distance_km,
            'street' => $address->street,
            'building' => $address->building,
            'note' => $address->note,
            'is_default' => $address->is_default,
        ];
    }
}
