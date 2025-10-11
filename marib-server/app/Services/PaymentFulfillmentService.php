<?php

namespace App\Services;

use App\Models\FeaturedItems;
use App\Models\Item;
use App\Models\ManualPaymentRequest;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\Package;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Services\DepartmentPolicyService;

use App\Models\WalletTransaction;
use App\Services\Payments\TransactionAmountResolver;
use App\Models\User;
use App\Models\WifiPlan;
use App\Services\Wifi\WifiCodeAssignmentService;

use App\Models\PaymentTransaction;
use App\Models\UserFcmToken;
use App\Models\UserPurchasedPackage;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use App\Support\DepositCalculator;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;
use InvalidArgumentException;
use Throwable;

class PaymentFulfillmentService
{
    /**
     * @param PaymentTransaction $transaction
     * @param string $payableType
     * @param int|null $payableId
     * @param int $userId
     * @param array $options
     * @return array{error:bool,message:string,transaction?:PaymentTransaction}
     */
    public function fulfill(PaymentTransaction $transaction, string $payableType, ?int $payableId, int $userId, array $options = []): array
    {
        try {

            $normalizedType = $this->normalizePayableType($payableType);
            $paymentGateway = $options['payment_gateway'] ?? null;
            $manualPaymentRequestId = $options['manual_payment_request_id'] ?? null;

            $this->mergeTransactionMeta($transaction, $options['meta'] ?? []);

            if (!empty($manualPaymentRequestId)) {
                $transaction->manual_payment_request_id = $manualPaymentRequestId;
            }

            if ($paymentGateway === 'wallet') {
                $this->synchronizeWalletMeta($transaction, $options);
            } elseif (!empty($paymentGateway)) {
                $transaction->payment_gateway = $paymentGateway;
            }


            if (strtolower($transaction->payment_status) === 'succeed') {

                if ($transaction->isDirty()) {
                    $transaction->save();
                }

                return [
                    'error' => false,
                    'message' => 'Transaction already processed',
                    'transaction' => $transaction->fresh(),
                ];
            }

            return DB::transaction(function () use (
                $transaction,
                $normalizedType,
                $payableId,
                $userId,
                $options,
                $paymentGateway,
                $manualPaymentRequestId
            ) {




                $transaction->fill([
                    'payable_type' => $normalizedType,
                    'payable_id' => $payableId,
                    'payment_status' => 'succeed',
                ]);

                if (!empty($manualPaymentRequestId)) {
                    $transaction->manual_payment_request_id = $manualPaymentRequestId;
                }

                $this->mergeTransactionMeta($transaction, $options['meta'] ?? []);

                if ($paymentGateway === 'wallet') {
                    $this->synchronizeWalletMeta($transaction, $options);
                } elseif (!empty($paymentGateway)) {
                    $transaction->payment_gateway = $paymentGateway;


                }

                $transaction->save();

                switch ($normalizedType) {
                    case Package::class:
                        $this->handlePackagePurchase($transaction, $payableId, $userId, $options);
                        break;
                    case Item::class:
                        $this->handleAdvertisementHighlight($transaction, $payableId, $userId, $options);
                        break;
                    case Order::class:
                        $this->handleOrderPayment($transaction, $payableId, $userId, $options);
                        break;
                    case Service::class:
                        $this->handleServicePayment($transaction, $payableId, $userId, $options);
                        break;

                    case WifiPlan::class:
                        $this->handleWifiPlanPurchase($transaction, $payableId, $userId, $options);
                        break;


                    default:
                        throw new InvalidArgumentException('Unsupported payable type provided.');
                }

                if (($options['notify'] ?? true) === true) {
                    $this->sendDefaultNotification($transaction, $normalizedType, $userId, $options);
                }

                return [
                    'error' => false,
                    'message' => 'Transaction processed successfully',
                    'transaction' => $transaction->fresh(),
                ];
            });
        } catch (Throwable $throwable) {
            Log::error('PaymentFulfillmentService error: ' . $throwable->getMessage(), [
                'file' => $throwable->getFile(),
                'line' => $throwable->getLine(),
            ]);

            return [
                'error' => true,
                'message' => 'Unable to process the payment',
            ];
        }
    }

    protected function handlePackagePurchase(PaymentTransaction $transaction, ?int $packageId, int $userId, array $options = []): void
    {
        if (empty($packageId)) {
            throw new InvalidArgumentException('Package id is required to activate the package.');
        }

        $package = Package::findOrFail($packageId);

        $purchased = UserPurchasedPackage::create([
            'package_id' => $package->id,
            'user_id' => $userId,
            'start_date' => Carbon::now(),
            'end_date' => $package->duration === 'unlimited' ? null : Carbon::now()->addDays($package->duration),
            'total_limit' => $package->item_limit === 'unlimited' ? null : $package->item_limit,
            'used_limit' => 0,
            'payment_transactions_id' => $transaction->id,
        ]);

        if (!empty($options['manual_payment_request_id'])) {
            ManualPaymentRequest::whereKey($options['manual_payment_request_id'])->update([
                'meta->user_purchased_package_id' => $purchased->id,
            ]);
        }
    }

    protected function handleAdvertisementHighlight(PaymentTransaction $transaction, ?int $itemId, int $userId, array $options = []): void
    {
        if (empty($itemId)) {
            throw new InvalidArgumentException('Item id is required to highlight advertisement.');
        }

        $item = Item::findOrFail($itemId);

        FeaturedItems::updateOrCreate(
            ['item_id' => $item->id],
            [
                'package_id' => $options['package_id'] ?? null,
                'user_purchased_package_id' => $options['user_purchased_package_id'] ?? null,
                'start_date' => Carbon::now()->toDateString(),
                'end_date' => $options['end_date'] ?? null,
            ]
        );

        if (empty($options['end_date']) && !empty($options['highlight_duration_days'])) {
            FeaturedItems::where('item_id', $item->id)->update([
                'end_date' => Carbon::now()->addDays((int) $options['highlight_duration_days'])->toDateString(),
            ]);
        }
    }

    protected function handleOrderPayment(PaymentTransaction $transaction, ?int $orderId, int $userId, array $options = []): void
    {
        if (empty($orderId)) {
            throw new InvalidArgumentException('Order id is required to mark order as paid.');
        }

        $order = Order::findOrFail($orderId);
        $orderCurrency = $this->resolveOrderCurrency($order);

        $previousPaymentStatus = $order->payment_status;
        $previousDeliveryStatus = $order->delivery_payment_status;


        $paymentGateway = $options['payment_gateway'] ?? $transaction->payment_gateway;
        $paymentMethod = $options['order_payment_method'] ?? ($paymentGateway ?? 'manual');
        $reference = $options['payment_reference']
            ?? $transaction->payment_id
            ?? $transaction->order_id;

        $timestamp = Carbon::now();

        $transactionAmount = TransactionAmountResolver::resolveForOrder($transaction, $orderCurrency);
        $depositRequired = $this->resolveDepositRequired($order);
        $previousDepositPaid = (float) ($order->deposit_amount_paid ?? 0.0);
        $previousDepositRemaining = max(round($depositRequired - $previousDepositPaid, 2), 0.0);
        $depositAllocation = DepositCalculator::allocatePayment($transactionAmount, $previousDepositRemaining);
        $depositApplied = $depositAllocation['deposit_applied'];
        $depositPaidAfter = min($depositRequired, round($previousDepositPaid + $depositApplied, 2));
        $depositRemainingAfter = max(round($depositRequired - $depositPaidAfter, 2), 0.0);


        $snapshot = $order->payment_payload['delivery_payment'] ?? [];
        $onlineBreakdown = $this->resolveOnlineBreakdown($order, is_array($snapshot) ? $snapshot : []);
        $onlineGoodsPayable = $onlineBreakdown['goods'];
        $onlineDeliveryPayable = $onlineBreakdown['delivery'];
        $totalOnlinePayable = round($onlineGoodsPayable + $onlineDeliveryPayable, 2);


        $totalPaidOnline = $order->paymentTransactions()
            ->where('payment_status', 'succeed')
            ->get(['amount', 'currency', 'meta'])
            ->sum(static fn (PaymentTransaction $paymentTransaction) => TransactionAmountResolver::resolveForOrder($paymentTransaction, $orderCurrency));
        $totalPaidOnline = round((float) $totalPaidOnline, 2);


        $onlinePaid = min(round($totalPaidOnline, 2), $totalOnlinePayable);
        $goodsPaid = min($onlinePaid, $onlineGoodsPayable);
        $deliveryPaid = min(max(round($onlinePaid - $goodsPaid, 2), 0.0), $onlineDeliveryPayable);

        $goodsOutstanding = max(round($onlineGoodsPayable - $goodsPaid, 2), 0.0);
        $deliveryOnlineOutstanding = max(round($onlineDeliveryPayable - $deliveryPaid, 2), 0.0);
        $onlineOutstanding = round($goodsOutstanding + $deliveryOnlineOutstanding, 2);

        $codDue = $this->resolveOrderCodDue($order);

        $codCollected = round((float) ($order->delivery_collected_amount ?? 0), 2);
        $codOutstanding = max(round($codDue - $codCollected, 2), 0.0);
        $overallDue = max(round($onlineOutstanding + $codOutstanding, 2), 0.0);



        $this->updateDepositState(
            $order,
            $depositApplied,
            $depositPaidAfter,
            $depositRemainingAfter,
            $depositRequired,
            $timestamp,
            $transaction,
            (string) ($paymentGateway ?? $transaction->payment_gateway ?? 'manual'),
            (string) $reference,
            $orderCurrency,
        );




        if ($overallDue <= 0.0 && ($totalOnlinePayable > 0.0 || $codDue > 0.0)) {
            $paymentStatus = 'paid';
            $order->recordStatusTimestamp('paid', $timestamp);
        } elseif ($overallDue <= 0.0) {
            $paymentStatus = 'paid';
        } elseif (($totalOnlinePayable - $onlineOutstanding) > 0.0 || $codCollected > 0.0) {
            
            $paymentStatus = 'partial';
            $order->recordStatusTimestamp('payment_partial', $timestamp);
        } else {
            $paymentStatus = 'pending';
        }

        if ($totalOnlinePayable <= 0.0 && $codDue <= 0.0) {
            $deliveryPaymentStatus = 'waived';
        } elseif ($overallDue <= 0.0) {
            $deliveryPaymentStatus = 'paid';

        } else {
            $deliveryPaymentStatus = 'pending';
        }

        $order->delivery_payment_status = $deliveryPaymentStatus;
        $order->delivery_online_payable = $onlineOutstanding;
        $order->delivery_cod_due = $codOutstanding;



        $order->mergePaymentPayload([
            'transaction_id' => $transaction->getKey(),
            'gateway' => $paymentGateway,
            'reference' => $reference,
            'confirmation' => [
                'idempotency_key' => $options['meta']['confirmation_idempotency_key'] ?? null,
            ],
            'delivery_payment' => array_filter([

                'online_outstanding' => $onlineOutstanding,
                'online_goods_outstanding' => $goodsOutstanding,
                'online_delivery_outstanding' => $deliveryOnlineOutstanding,

                'cod_due' => $codDue,
         
                'cod_outstanding' => $codOutstanding,
            ], static fn ($value) => $value !== null),



            'delivery_payment_status' => $deliveryPaymentStatus,
            'payment_summary' => [
                'online_total' => $totalOnlinePayable,
                'online_paid_total' => round($goodsPaid + $deliveryPaid, 2),
                'online_outstanding' => $onlineOutstanding,
                'goods_online_payable' => $onlineGoodsPayable,
                'goods_online_outstanding' => $goodsOutstanding,
                'delivery_online_payable' => $onlineDeliveryPayable,
                'delivery_online_outstanding' => $deliveryOnlineOutstanding,
                'cod_due' => $codDue,
                'cod_outstanding' => $codOutstanding,
                'remaining_balance' => $overallDue,
            ],


            
        ]);



        $order->forceFill([
            'payment_status' => $paymentStatus,
            'payment_method' => $paymentMethod,
            'payment_reference' => $reference,
            'payment_collected_at' => $timestamp,
            'payment_payload' => $order->payment_payload,
            'status_timestamps' => $order->status_timestamps,
            'delivery_payment_status' => $order->delivery_payment_status,
            'delivery_online_payable' => $order->delivery_online_payable,
            'delivery_cod_due' => $order->delivery_cod_due,
            'deposit_amount_paid' => $order->deposit_amount_paid,
            'deposit_remaining_balance' => $order->deposit_remaining_balance,






        ])->save();


        $historyComment = $options['order_history_comment'] ?? $this->buildOrderPaymentHistoryComment(
            $transaction->id,
            $previousPaymentStatus,
            $paymentStatus,
            $previousDeliveryStatus,
            $deliveryPaymentStatus
        );


        OrderHistory::create([
            'order_id' => $order->id,
            'user_id' => $userId,
            'status_from' => $order->order_status,
            'status_to' => $order->order_status,
            'comment' => $historyComment,

            'notify_customer' => false,
        ]);
    }


    private function resolveOrderCodDue(Order $order): float
    {
        $payloadCodDue = data_get($order->payment_payload, 'delivery_payment.cod_due');

        if ($payloadCodDue !== null) {
            return max((float) $payloadCodDue, 0.0);
        }

        if ($order->delivery_cod_due !== null) {
            return max((float) $order->delivery_cod_due, 0.0);
        }

        return 0.0;
    }




    private function resolveDepositRequired(Order $order): float
    {
        $payloadRequired = Arr::get($order->payment_payload, 'deposit.required_amount');

        if ($payloadRequired !== null) {
            return max(round((float) $payloadRequired, 2), 0.0);
        }

        $paid = (float) ($order->deposit_amount_paid ?? 0.0);
        $remaining = (float) ($order->deposit_remaining_balance ?? 0.0);

        if ($paid > 0.0 || $remaining > 0.0) {
            return max(round($paid + $remaining, 2), 0.0);
        }

        $minimum = (float) ($order->deposit_minimum_amount ?? 0.0);
        $ratio = $order->deposit_ratio !== null ? (float) $order->deposit_ratio : 0.0;

        if ($ratio > 0.0) {
            $goodsTotal = (float) ($order->final_amount ?? 0.0) - (float) ($order->delivery_total ?? 0.0);
            $ratioAmount = round(max($goodsTotal, 0.0) * $ratio, 2);

            return max($ratioAmount, round($minimum, 2));
        }

        return max(round($minimum, 2), 0.0);
    }

    private function updateDepositState(
        Order $order,
        float $depositApplied,
        float $depositPaidAfter,
        float $depositRemainingAfter,
        float $depositRequired,
        Carbon $timestamp,
        PaymentTransaction $transaction,
        string $paymentGateway,
        string $reference,
        string $orderCurrency
    ): void {
        if ($depositRequired <= 0.0 && $depositApplied <= 0.0 && (float) ($order->deposit_amount_paid ?? 0.0) <= 0.0) {
            return;
        }

        $order->deposit_amount_paid = round($depositPaidAfter, 2);
        $order->deposit_remaining_balance = round($depositRemainingAfter, 2);

        $payload = $order->payment_payload ?? [];
        $depositPayload = Arr::get($payload, 'deposit', []);

        if (! is_array($depositPayload)) {
            $depositPayload = [];
        }

        $receipts = [];

        if (isset($depositPayload['receipts']) && is_array($depositPayload['receipts'])) {
            $receipts = $depositPayload['receipts'];
        }

        if ($depositApplied > 0.0) {
            $receipts[] = [
                'transaction_id' => $transaction->getKey(),
                'amount' => round($depositApplied, 2),
                'currency' => $orderCurrency,
                'paid_at' => $timestamp->toIso8601String(),
                'gateway' => $paymentGateway,
                'reference' => $reference,
            ];
        }

        $depositPayload = array_replace($depositPayload, [
            'required_amount' => round($depositRequired, 2),
            'paid_amount' => round($depositPaidAfter, 2),
            'remaining_amount' => round($depositRemainingAfter, 2),
            'status' => $depositRemainingAfter <= 0.0 ? 'settled' : 'pending',
        ]);

        if (! array_key_exists('minimum_amount', $depositPayload) && $order->deposit_minimum_amount !== null) {
            $depositPayload['minimum_amount'] = round((float) $order->deposit_minimum_amount, 2);
        }


        $depositPayload['receipts'] = $receipts;

        Arr::set($payload, 'deposit', $depositPayload);
        $order->payment_payload = $payload;
    }







    /**
     * @param array<string, mixed> $snapshot
     * @return array{goods: float, delivery: float}
     */
    private function resolveOnlineBreakdown(Order $order, array $snapshot): array
    {
        $goodsPayable = null;
        $deliveryPayable = null;

        if (array_key_exists('online_goods_payable', $snapshot)) {
            $goodsPayable = (float) $snapshot['online_goods_payable'];
        }

        if (array_key_exists('online_delivery_payable', $snapshot)) {
            $deliveryPayable = (float) $snapshot['online_delivery_payable'];
        }

        $normalizedTiming = OrderCheckoutService::normalizeTimingToken(
            $snapshot['timing'] ?? $order->delivery_payment_timing
        );

        $deliveryTotal = round((float) ($order->delivery_total ?? 0), 2);

        if ($goodsPayable === null) {
            $goodsPayable = round((float) ($order->final_amount - $deliveryTotal), 2);
        }

        if ($deliveryPayable === null) {
            $deliveryPayable = $normalizedTiming === OrderCheckoutService::DELIVERY_TIMING_PAY_ON_DELIVERY
                ? 0.0
                : $deliveryTotal;
        }

        return [
            'goods' => max(round($goodsPayable, 2), 0.0),
            'delivery' => max(round($deliveryPayable, 2), 0.0),
        ];
    }

    private function buildOrderPaymentHistoryComment(
        int $transactionId,
        ?string $previousPaymentStatus,
        string $currentPaymentStatus,
        ?string $previousDeliveryStatus,
        string $currentDeliveryStatus
    ): string {
        $segments = [
            sprintf('Payment processed (transaction #%s).', $transactionId),
            sprintf(
                'Payment status: %s → %s',
                $previousPaymentStatus ?? 'unknown',
                $currentPaymentStatus
            ),
        ];

        if ($previousDeliveryStatus !== $currentDeliveryStatus) {
            $segments[] = sprintf(
                'Delivery payment status: %s → %s',
                $previousDeliveryStatus ?? 'unknown',
                $currentDeliveryStatus
            );
        }

        return implode(' ', $segments);
    }



    protected function handleServicePayment(PaymentTransaction $transaction, ?int $serviceId, int $userId, array $options = []): void
    {
        if (empty($serviceId)) {
            throw new InvalidArgumentException('Service id is required to mark service as paid.');
        }

        $service = Service::query()->findOrFail($serviceId);
        $walletTransaction = $options['wallet_transaction'] ?? null;
        $manualPaymentRequestId = $options['manual_payment_request_id'] ?? null;

        $serviceUpdates = [];

        if (Schema::hasColumn($service->getTable(), 'payment_status')) {
            $serviceUpdates['payment_status'] = 'paid';
        }

        if (Schema::hasColumn($service->getTable(), 'payment_transaction_id')) {
            $serviceUpdates['payment_transaction_id'] = $transaction->getKey();
        }

        if ($walletTransaction instanceof WalletTransaction && Schema::hasColumn($service->getTable(), 'wallet_transaction_id')) {
            $serviceUpdates['wallet_transaction_id'] = $walletTransaction->getKey();
        }

        if (!empty($serviceUpdates)) {
            $service->forceFill($serviceUpdates)->save();
        }

        $latestRequest = null;

        $requestTable = null;

        if (Schema::hasTable('service_requests')) {
            $requestModel = new ServiceRequest();
            $requestTable = $requestModel->getTable();

            $requestQuery = ServiceRequest::query()
                ->where('service_id', $service->getKey())
                ->orderByDesc('id');

            if (Schema::hasColumn($requestTable, 'user_id')) {
                $requestQuery->where('user_id', $userId);
            }

            $latestRequest = $requestQuery->first();
        }

        if ($latestRequest) {
            $requestTable ??= $latestRequest->getTable();
            $requestUpdates = [];

            if (Schema::hasColumn($requestTable, 'payment_status')) {
                $requestUpdates['payment_status'] = 'paid';
            } elseif (Schema::hasColumn($requestTable, 'status')) {
                $requestUpdates['status'] = 'paid';
            }

            if (Schema::hasColumn($requestTable, 'payment_transaction_id')) {
                $requestUpdates['payment_transaction_id'] = $transaction->getKey();
            }

            if ($walletTransaction instanceof WalletTransaction && Schema::hasColumn($requestTable, 'wallet_transaction_id')) {
                $requestUpdates['wallet_transaction_id'] = $walletTransaction->getKey();
            }

            foreach (['payment_note', 'payment_comment', 'notes', 'comment'] as $commentColumn) {
                if (Schema::hasColumn($requestTable, $commentColumn)) {
                    $existingComment = (string) $latestRequest->getAttribute($commentColumn);
                    $comment = sprintf('Paid via manual transaction #%d', $transaction->getKey());
                    $requestUpdates[$commentColumn] = trim($existingComment === '' ? $comment : $existingComment . PHP_EOL . $comment);
                    break;
                }
            }

            if (!empty($requestUpdates)) {
                $latestRequest->forceFill($requestUpdates)->save();
            }
        }

        $metaUpdates = [];

        if ($manualPaymentRequestId !== null) {
            data_set($metaUpdates, 'service.manual_payment_request_id', $manualPaymentRequestId);
        }

        if ($latestRequest) {
            data_set($metaUpdates, 'service.request_id', $latestRequest->getKey());
        }

        if ($walletTransaction instanceof WalletTransaction) {
            data_set($metaUpdates, 'service.wallet_transaction_id', $walletTransaction->getKey());
        }

        if (!empty($metaUpdates)) {
            $this->mergeTransactionMeta($transaction, $metaUpdates);
            $transaction->save();
        }
    }


    protected function handleWifiPlanPurchase(PaymentTransaction $transaction, ?int $planId, int $userId, array $options = []): void
    {
        if (empty($planId)) {
            throw new InvalidArgumentException('Wi-Fi plan id is required to fulfill the transaction.');
        }

        $plan = WifiPlan::findOrFail($planId);
        $buyer = User::findOrFail($userId);

        /** @var WifiCodeAssignmentService $assignmentService */
        $assignmentService = app(WifiCodeAssignmentService::class);

        $assignment = $assignmentService->assign($plan, $buyer, $transaction, [
            'amount' => (float) ($options['amount'] ?? $transaction->amount ?? $plan->price),
        ]);

        $meta = $transaction->meta ?? [];

        $meta['wifi_code_id'] = $assignment['code']->getKey();
        $meta['wifi_plan_id'] = $plan->getKey();
        $meta['wifi_network_id'] = $plan->wifi_network_id;
        $meta['wifi_purchase'] = array_merge($meta['wifi_purchase'] ?? [], [
            'gross_amount' => $assignment['gross_amount'],
            'commission_amount' => $assignment['commission_amount'],
            'net_amount' => $assignment['net_amount'],
        ]);

        $transaction->forceFill([
            'meta' => $meta,
        ])->save();
    }


    protected function sendDefaultNotification(PaymentTransaction $transaction, string $normalizedType, int $userId, array $options = []): void
    {
        $tokens = UserFcmToken::where('user_id', $userId)->pluck('fcm_token')->filter()->values()->all();

        if (empty($tokens)) {
            return;
        }

        $notification = $options['notification'] ?? $this->resolveDefaultNotificationPayload($transaction, $normalizedType);

        if (empty($notification)) {
            return;
        }

        $response = NotificationService::sendFcmNotification(
            $tokens,
            $notification['title'] ?? 'Payment Updated',
            $notification['body'] ?? 'Your payment has been processed successfully.',
            $notification['type'] ?? 'payment',
            $notification['data'] ?? []
        );

        if (is_array($response) && ($response['error'] ?? false)) {
            Log::warning('PaymentFulfillmentService: Failed to send payment notification', [
                'transaction_id' => $transaction->getKey(),
                'message' => $response['message'] ?? null,
                'code' => $response['code'] ?? null,
            ]);
        }

    }

    protected function resolveDefaultNotificationPayload(PaymentTransaction $transaction, string $normalizedType): array
    {
        $title = 'Payment Completed';
        $body = 'Amount :- ' . $transaction->amount;

        if ($normalizedType === Package::class) {
            $title = 'Package Purchased';
        } elseif ($normalizedType === Item::class) {
            $title = 'Advertisement Highlighted';
            $body = 'Your advertisement has been highlighted successfully.';
        } elseif ($normalizedType === Order::class) {
            $title = 'Order Paid';
            $orderNumber = (string) ($transaction->order_id ?? '');
            $body = 'Order #' . $orderNumber . ' marked as paid.';

            $order = $transaction->relationLoaded('order')
                ? $transaction->getRelation('order')
                : $transaction->order()->withTrashed()->first();

            if ($order instanceof Order) {
                $orderNumber = (string) ($order->order_number ?: $order->getKey());
                $body = 'Order #' . $orderNumber . ' marked as paid.';

                $department = $order->department;

                if (is_string($department) && $department !== '') {
                    $policyService = app(DepartmentPolicyService::class);
                    $policy = $policyService->policyFor($department);
                    $policyText = $policy['return_policy_text'] ?? null;

                    if (is_string($policyText)) {
                        $policyText = trim($policyText);
                    } else {
                        $policyText = null;
                    }

                    if ($policyText !== null && $policyText !== '') {
                        $summary = Str::limit($policyText, 200);
                        $body .= ' Return policy: ' . $summary;
                    }
                }
            }
        
        }

        return [
            'title' => $title,
            'body' => $body,
            'type' => 'payment',
            'data' => [
                'transaction_id' => $transaction->id,
            ],
        ];
    }


    private function resolveOrderCurrency(Order $order): string
    {
        $orderCurrency = $order->currency_code ?? $order->currency ?? null;

        return strtoupper((string) ($orderCurrency ?: config('app.currency', 'SAR')));
    }


    protected function normalizePayableType(string $payableType): string
    {
        $payableType = trim($payableType);


        if ($payableType === '') {
            return $payableType;
        }

        if (class_exists($payableType)) {
            return $payableType;
        }

        $normalizedClass = ltrim($payableType, '\\');

        if ($normalizedClass !== $payableType && class_exists($normalizedClass)) {
            return $normalizedClass;
        }

        $normalizedLower = strtolower(trim($normalizedClass));

        if (ManualPaymentRequest::isOrderPayableType($payableType)
            || ManualPaymentRequest::isOrderPayableType($normalizedClass)
            || ManualPaymentRequest::isOrderPayableType($normalizedLower)
        ) {
            return Order::class;
        }

        $normalized = $normalizedLower;

        
        return match ($normalized) {
            
            'package', 'packages' => Package::class,
            'advertisement', 'item', 'items' => Item::class,
            'order', 'orders' => Order::class,
            'service', 'services', 'app\\models\\service' => Service::class,


            default => $payableType,
        };
    }
    protected function mergeTransactionMeta(PaymentTransaction $transaction, array $meta): void
    {
        if (empty($meta)) {
            return;
        }

        $transaction->meta = array_replace_recursive($transaction->meta ?? [], $meta);
    }

    protected function synchronizeWalletMeta(PaymentTransaction $transaction, array $options): void
    {
        $walletMeta = data_get($transaction->meta, 'wallet', []);
        $providedMeta = data_get($options, 'meta.wallet', []);

        if (!empty($providedMeta)) {
            $walletMeta = array_replace_recursive($walletMeta, $providedMeta);
        }

        $walletTransaction = $options['wallet_transaction'] ?? null;

        if ($walletTransaction instanceof WalletTransaction) {
            $walletMeta = array_replace_recursive($walletMeta, [
                'transaction_id' => $walletTransaction->getKey(),
                'balance_after' => (float) $walletTransaction->balance_after,
                'idempotency_key' => $walletTransaction->idempotency_key,
            ]);
        }

        if (!empty($walletMeta)) {
            $this->mergeTransactionMeta($transaction, ['wallet' => $walletMeta]);
        }

        $transaction->payment_gateway = 'wallet';
    }
}