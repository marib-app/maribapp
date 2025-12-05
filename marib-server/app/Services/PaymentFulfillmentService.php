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
use App\Models\Wifi\WifiCode;
use App\Models\Wifi\WifiCodeBatch;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiPlan;
use App\Services\DepartmentPolicyService;
use Illuminate\Support\Facades\Storage;

use App\Models\WalletTransaction;
use App\Services\Logging\PaymentTrace;
use App\Services\NotificationService;
use App\Services\SmsService;
use App\Services\Wifi\WifiOperationalService;
use App\Services\WalletService;
use App\Services\Payments\TransactionAmountResolver;
use App\Models\User;


use App\Models\PaymentTransaction;
use App\Models\UserFcmToken;
use App\Models\UserPurchasedPackage;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use App\Support\DepositCalculator;
use App\Enums\Wifi\WifiCodeStatus;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;
use InvalidArgumentException;
use RuntimeException;
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

                $response = [
                    'error' => false,
                    'message' => 'Transaction already processed',
                    'transaction' => $transaction->fresh(),
                ];

                if ($transaction->payable_type === ServiceRequest::class && $transaction->payable_id) {
                    $response['service_request_id'] = (int) $transaction->payable_id;
                }

                return $response;
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

                $serviceRequestModel = null;
                $wifiDelivery = null;

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
                    case ServiceRequest::class:
                        $serviceRequestModel = $this->handleServicePayment($transaction, $payableId, $userId, $options);
                        break;
                        break;
              case WifiPlan::class:
                        $wifiDelivery = $this->handleWifiPlanPurchase($transaction, $payableId, $userId, $options);
                        break;


                    default:
                        throw new InvalidArgumentException('Unsupported payable type provided.');
                }

                if ($normalizedType !== ServiceRequest::class && ($options['notify'] ?? true) === true) {
                    $this->sendDefaultNotification($transaction, $normalizedType, $userId, $options);
                }
                $freshTransaction = $transaction->fresh();

                if ($normalizedType === ServiceRequest::class) {
                    PaymentTrace::trace('payment.fulfillment.service', [
                        'payment_transaction_id' => $freshTransaction->getKey(),
                        'service_request_id' => $serviceRequestModel?->getKey() ?? $payableId,
                        'user_id' => $userId,
                    ]);
                }

                return [
                    'error' => false,
                    'message' => 'Transaction processed successfully',
                    'transaction' => $freshTransaction,
                    'service_request_id' => $serviceRequestModel?->getKey(),
                    'wifi_delivery' => $wifiDelivery,
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
            $receiptMeta = $this->prepareDepositReceiptMetadata($transaction);

            $receiptEntry = [
                'transaction_id' => $transaction->getKey(),
                'amount' => round($depositApplied, 2),
                'currency' => $orderCurrency,
                'paid_at' => $timestamp->toIso8601String(),
                'gateway' => $paymentGateway,
                'reference' => $reference,
            ];

            if ($receiptMeta['receipt_path'] !== null) {
                $receiptEntry['receipt_path'] = $receiptMeta['receipt_path'];
            }

            if ($receiptMeta['receipt_disk'] !== null) {
                $receiptEntry['receipt_disk'] = $receiptMeta['receipt_disk'];
            }

            if ($receiptMeta['receipt_url'] !== null) {
                $receiptEntry['receipt_url'] = $receiptMeta['receipt_url'];
                $receiptEntry['receipt'] = $receiptMeta['receipt_url'];
            }

            if ($receiptMeta['attachments'] !== []) {
                $receiptEntry['attachments'] = $receiptMeta['attachments'];
            }


            if (isset($receiptMeta['manual_note']) && is_string($receiptMeta['manual_note']) && $receiptMeta['manual_note'] !== '') {
                $receiptEntry['note'] = $receiptMeta['manual_note'];
            }

            if (isset($receiptMeta['manual_metadata']) && is_array($receiptMeta['manual_metadata']) && $receiptMeta['manual_metadata'] !== []) {
                $receiptEntry['metadata'] = $receiptMeta['manual_metadata'];
            }

            if (isset($receiptMeta['manual_sender_name']) && is_string($receiptMeta['manual_sender_name']) && $receiptMeta['manual_sender_name'] !== '') {
                $receiptEntry['sender_name'] = $receiptMeta['manual_sender_name'];
            }

            if (isset($receiptMeta['manual_transfer_code']) && is_string($receiptMeta['manual_transfer_code']) && $receiptMeta['manual_transfer_code'] !== '') {
                $receiptEntry['transfer_code'] = $receiptMeta['manual_transfer_code'];
            }

            $receipts[] = $receiptEntry;

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
     * @return array{receipt_path: ?string, receipt_disk: ?string, receipt_url: ?string, attachments: array<int, array<string, mixed>>}
     */
    private function prepareDepositReceiptMetadata(PaymentTransaction $transaction): array
    {
        $manualRequest = $transaction->manualPaymentRequest;

        if (! $manualRequest instanceof ManualPaymentRequest && $transaction->manual_payment_request_id) {
            $manualRequest = ManualPaymentRequest::query()->find($transaction->manual_payment_request_id);
        }

        $manualMeta = $manualRequest instanceof ManualPaymentRequest && is_array($manualRequest->meta)
            ? $manualRequest->meta
            : [];
        $transactionMeta = is_array($transaction->meta) ? $transaction->meta : [];


        $manualNote = $this->firstNonEmptyString([
            $manualRequest instanceof ManualPaymentRequest ? $manualRequest->user_note : null,
            Arr::get($manualMeta, 'user_note'),
            Arr::get($manualMeta, 'note'),
            Arr::get($manualMeta, 'metadata.note'),
            Arr::get($manualMeta, 'metadata.notes'),
            Arr::get($transactionMeta, 'manual.user_note'),
            Arr::get($transactionMeta, 'manual.note'),
            Arr::get($transactionMeta, 'manual.metadata.note'),
            Arr::get($transactionMeta, 'manual.metadata.notes'),
        ]);

        $manualUserNote = $this->firstNonEmptyString([
            Arr::get($manualMeta, 'metadata.user_note'),
            Arr::get($manualMeta, 'metadata.customer_note'),
            Arr::get($transactionMeta, 'manual.metadata.user_note'),
            Arr::get($transactionMeta, 'manual.metadata.customer_note'),
        ]);

        if ($manualNote === null && $manualUserNote !== null) {
            $manualNote = $manualUserNote;
        }

        $senderName = $this->firstNonEmptyString([
            Arr::get($manualMeta, 'metadata.sender_name'),
            Arr::get($manualMeta, 'metadata.sender'),
            Arr::get($manualMeta, 'sender_name'),
            Arr::get($manualMeta, 'sender'),
            Arr::get($transactionMeta, 'manual.metadata.sender_name'),
            Arr::get($transactionMeta, 'manual.metadata.sender'),
            Arr::get($transactionMeta, 'manual.sender_name'),
            Arr::get($transactionMeta, 'manual.sender'),
        ]);

        $transferCode = $this->firstNonEmptyString([
            Arr::get($manualMeta, 'metadata.transfer_code'),
            Arr::get($manualMeta, 'metadata.transfer_number'),
            Arr::get($manualMeta, 'metadata.transfer_reference'),
            Arr::get($manualMeta, 'transfer_code'),
            Arr::get($manualMeta, 'transfer_number'),
            Arr::get($transactionMeta, 'manual.metadata.transfer_code'),
            Arr::get($transactionMeta, 'manual.metadata.transfer_number'),
            Arr::get($transactionMeta, 'manual.metadata.transfer_reference'),
            Arr::get($transactionMeta, 'manual.transfer_code'),
            Arr::get($transactionMeta, 'manual.transfer_number'),
            Arr::get($transactionMeta, 'manual.reference'),
            $manualRequest instanceof ManualPaymentRequest ? $manualRequest->reference : null,
            Arr::get($manualMeta, 'metadata.reference'),
        ]);

        $manualMetadata = array_filter([
            'sender_name' => $senderName,
            'transfer_code' => $transferCode,
            'user_note' => $manualUserNote ?? $manualNote,
        ], static fn ($value) => is_string($value) && $value !== '');



        $attachments = $this->normalizeReceiptAttachments([
            data_get($manualMeta, 'attachments'),
            data_get($transactionMeta, 'attachments'),
        ]);

        $receiptPath = $this->firstNonEmptyString([
            data_get($manualMeta, 'receipt.path'),
            data_get($manualMeta, 'receipt_path'),
            $manualRequest instanceof ManualPaymentRequest ? $manualRequest->receipt_path : null,
            data_get($transactionMeta, 'receipt.path'),
            data_get($transactionMeta, 'receipt_path'),
            $transaction->receipt_path,
        ]);

        $receiptDisk = $this->firstNonEmptyString(array_merge([
            data_get($manualMeta, 'receipt.disk'),
            data_get($manualMeta, 'receipt_disk'),
            data_get($transactionMeta, 'receipt.disk'),
            data_get($transactionMeta, 'receipt_disk'),
        ], array_map(static function (array $attachment): ?string {
            $disk = Arr::get($attachment, 'disk');

            return is_string($disk) && $disk !== '' ? $disk : null;
        }, $attachments)));

        $receiptUrl = $this->firstValidUrl(array_merge([
            data_get($manualMeta, 'receipt.url'),
            data_get($manualMeta, 'receipt_url'),
            data_get($transactionMeta, 'receipt.url'),
            data_get($transactionMeta, 'receipt_url'),
        ], array_map(static function (array $attachment): ?string {
            $url = Arr::get($attachment, 'url');

            return is_string($url) && trim($url) !== '' ? trim($url) : null;
        }, $attachments)));

        if ($receiptUrl === null) {
            $receiptUrl = $this->generateReceiptUrl($receiptPath, $receiptDisk, $attachments);
        }

        return [
            'receipt_path' => $receiptPath,
            'receipt_disk' => $receiptDisk,
            'receipt_url' => $receiptUrl,
            'attachments' => $attachments,

            'manual_note' => $manualNote,
            'manual_metadata' => $manualMetadata,
            'manual_sender_name' => $senderName,
            'manual_transfer_code' => $transferCode,

        ];
    }

    /**
     * @param array<int, mixed> $sources
     * @return array<int, array<string, mixed>>
     */
    private function normalizeReceiptAttachments(array $sources): array
    {
        $normalized = [];

        foreach ($sources as $source) {
            if (! is_iterable($source)) {
                continue;
            }

            foreach ($source as $attachment) {
                if (! is_array($attachment)) {
                    continue;
                }

                $normalized[] = array_filter([
                    'type' => Arr::get($attachment, 'type'),
                    'path' => Arr::get($attachment, 'path'),
                    'disk' => Arr::get($attachment, 'disk'),
                    'name' => Arr::get($attachment, 'name'),
                    'mime_type' => Arr::get($attachment, 'mime_type'),
                    'size' => Arr::get($attachment, 'size'),
                    'uploaded_at' => Arr::get($attachment, 'uploaded_at'),
                    'url' => Arr::get($attachment, 'url'),
                ], static fn ($value) => $value !== null && $value !== '');
            }
        }

        return $normalized;
    }

    /**
     * @param array<int, ?string> $candidates
     */
    private function firstNonEmptyString(array $candidates): ?string
    {
        foreach ($candidates as $candidate) {
            if (! is_string($candidate)) {
                continue;
            }

            $trimmed = trim($candidate);

            if ($trimmed === '') {
                continue;
            }

            return $trimmed;
        }

        return null;
    }

    /**
     * @param array<int, ?string> $candidates
     */
    private function firstValidUrl(array $candidates): ?string
    {
        foreach ($candidates as $candidate) {
            if (! is_string($candidate)) {
                continue;
            }

            $trimmed = trim($candidate);

            if ($trimmed === '') {
                continue;
            }

            if (filter_var($trimmed, FILTER_VALIDATE_URL)) {
                return $trimmed;
            }
        }

        return null;
    }

    /**
     * @param array<int, array<string, mixed>> $attachments
     */
    private function generateReceiptUrl(?string $receiptPath, ?string $preferredDisk, array $attachments): ?string
    {
        $pathCandidates = [];

        if (is_string($receiptPath) && $receiptPath !== '') {
            $pathCandidates[] = [
                'path' => $receiptPath,
                'disk' => $preferredDisk,
            ];
        }

        foreach ($attachments as $attachment) {
            $path = Arr::get($attachment, 'path');

            if (! is_string($path) || trim($path) === '') {
                continue;
            }

            $pathCandidates[] = [
                'path' => trim($path),
                'disk' => $this->firstNonEmptyString([
                    Arr::get($attachment, 'disk'),
                    $preferredDisk,
                ]),
            ];
        }

        if ($pathCandidates === []) {
            return null;
        }

        foreach ($pathCandidates as $candidate) {
            $path = $candidate['path'];
            $diskCandidates = [];

            if (isset($candidate['disk']) && is_string($candidate['disk']) && $candidate['disk'] !== '') {
                $diskCandidates[] = $candidate['disk'];
            }

            if (is_string($preferredDisk) && $preferredDisk !== '') {
                $diskCandidates[] = $preferredDisk;
            }

            $defaultDisk = config('filesystems.default');

            if (is_string($defaultDisk) && $defaultDisk !== '') {
                $diskCandidates[] = $defaultDisk;
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
                    $resolved = $disk->url($path);
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



    protected function handleServicePayment(PaymentTransaction $transaction, ?int $serviceRequestId, int $userId, array $options = []): ServiceRequest
    {
        if (empty($serviceRequestId)) {
            throw new InvalidArgumentException('Service request id is required to mark service as paid.');
        }

        $serviceRequest = ServiceRequest::query()
            ->withTrashed()
            ->with('service')
            ->findOrFail($serviceRequestId);

        if ((int) $serviceRequest->user_id !== $userId) {
            throw new InvalidArgumentException('Service request user mismatch.');
        }

        $service = $serviceRequest->service instanceof Service ? $serviceRequest->service : null;
        $walletTransaction = $options['wallet_transaction'] ?? null;
        $manualPaymentRequestId = $options['manual_payment_request_id'] ?? null;

        $this->ensureServiceTransactionContext($transaction, $serviceRequest);

        if ($service instanceof Service) {
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
        }

        $requestUpdates = [];

        if (Schema::hasColumn($serviceRequest->getTable(), 'payment_status')) {
            $requestUpdates['payment_status'] = 'paid';
        } elseif (Schema::hasColumn($serviceRequest->getTable(), 'status')) {
            $requestUpdates['status'] = 'paid';
        }

        if (Schema::hasColumn($serviceRequest->getTable(), 'payment_transaction_id')) {
            $requestUpdates['payment_transaction_id'] = $transaction->getKey();
        }

        if ($walletTransaction instanceof WalletTransaction && Schema::hasColumn($serviceRequest->getTable(), 'wallet_transaction_id')) {
            $requestUpdates['wallet_transaction_id'] = $walletTransaction->getKey();
        }

        foreach (['payment_note', 'payment_comment', 'notes', 'comment'] as $commentColumn) {
            if (Schema::hasColumn($serviceRequest->getTable(), $commentColumn)) {
                $existingComment = (string) $serviceRequest->getAttribute($commentColumn);
                $comment = sprintf('Paid via manual transaction #%d', $transaction->getKey());
                $requestUpdates[$commentColumn] = trim($existingComment === '' ? $comment : $existingComment . PHP_EOL . $comment);
                break;
            }
        }

        if (!empty($requestUpdates)) {
            $serviceRequest->forceFill($requestUpdates)->save();
        }

        $metaUpdates = [];

        if ($manualPaymentRequestId !== null) {
            data_set($metaUpdates, 'service.manual_payment_request_id', $manualPaymentRequestId);
        }

        data_set($metaUpdates, 'service.request_id', $serviceRequest->getKey());

        if ($service instanceof Service) {
            data_set($metaUpdates, 'service.id', $service->getKey());
        }

        if ($walletTransaction instanceof WalletTransaction) {
            data_set($metaUpdates, 'service.wallet_transaction_id', $walletTransaction->getKey());
        }

        if (!empty($metaUpdates)) {
            $this->mergeTransactionMeta($transaction, $metaUpdates);
            $transaction->save();
        }

        $tokens = UserFcmToken::query()
            ->where('user_id', $serviceRequest->user_id)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if (! empty($tokens)) {
            $title = __('Service payment confirmed');
            $body = __('Your service request #:number has been paid.', [
                'number' => $serviceRequest->request_number ?? $serviceRequest->getKey(),
            ]);

            NotificationService::sendFcmNotification(
                $tokens,
                $title,
                $body,
                'service_payment_confirmed',
                [
                    'data' => json_encode([
                        'service_request_id' => $serviceRequest->getKey(),
                        'request_number' => $serviceRequest->request_number,
                    ], JSON_UNESCAPED_UNICODE),
                ]
            );
        }

        return $serviceRequest;
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
        $notificationData = $this->buildNotificationDataPayload($transaction, $normalizedType);


        if (($notificationData['payable_type_alias'] ?? null) === 'wallet_top_up') {
            $currency = strtoupper((string) ($transaction->currency ?? config('app.currency', 'SAR')));
            $amount = (float) $transaction->amount;

            $title = __('Wallet top-up completed');
            $body = __('Your wallet top-up of :amount :currency has been processed successfully.', [
                'amount' => number_format($amount, 2),
                'currency' => $currency,
            ]);

            $notificationData = array_replace($notificationData, [
                'event' => 'wallet_top_up',
                'category' => 'wallet_top_up',
                'wallet_amount' => $amount,
                'wallet_currency' => $currency,
            ]);

            return [
                'title' => $title,
                'body' => $body,
                'type' => 'wallet',
                'data' => $notificationData,
            ];
        } 


        return [
            'title' => $title,
            'body' => $body,
            'type' => 'payment',
            'data' => $notificationData,

        ];
    }



    /**
     * @return array<string, mixed>
     */
    protected function buildNotificationDataPayload(PaymentTransaction $transaction, string $normalizedType): array
    {
        $data = [
            'transaction_id' => $transaction->id,
        ];

        $rawPayableType = $transaction->payable_type ?: $normalizedType;

        if (is_string($rawPayableType) && $rawPayableType !== '') {
            $data['payable_type'] = $rawPayableType;
        }

        if ($transaction->payable_id !== null) {
            $data['payable_id'] = $transaction->payable_id;
        }

        if ($transaction->manual_payment_request_id !== null) {
            $data['manual_payment_request_id'] = $transaction->manual_payment_request_id;
        }

        $purpose = data_get($transaction->meta, 'purpose');
        if (is_string($purpose) && trim($purpose) !== '') {
            $data['purpose'] = trim($purpose);
        }

        $alias = $this->resolvePayableAlias($rawPayableType, $transaction, $normalizedType, $purpose);
        if ($alias !== null) {
            $data['payable_type_alias'] = $alias;
        }

        if ($alias === 'order') {
            $order = $transaction->relationLoaded('order')
                ? $transaction->getRelation('order')
                : $transaction->order()->withTrashed()->first();

            if ($order instanceof Order) {
                $data['order_id'] = $order->getKey();
                $orderNumber = $order->order_number ?: $order->getKey();
                if (! empty($orderNumber)) {
                    $data['order_number'] = (string) $orderNumber;
                }
            } elseif ($transaction->order_id !== null) {
                $data['order_id'] = $transaction->order_id;
            }
        } elseif ($alias === 'package') {
            $packageId = $transaction->payable_id;
            if ($packageId !== null) {
                $data['package_id'] = $packageId;
            }

            $purchasedId = data_get($transaction->meta, 'manual.user_purchased_package_id')
                ?? data_get($transaction->meta, 'user_purchased_package_id')
                ?? data_get($transaction->meta, 'package.user_purchased_package_id');

            if ($purchasedId !== null && $purchasedId !== '') {
                $data['user_purchased_package_id'] = $purchasedId;
            }


        } elseif ($alias === 'wifi_plan') {
            $planId = $transaction->payable_id ?? data_get($transaction->meta, 'wifi.plan_id');
            if ($planId !== null && $planId !== '') {
                $data['wifi_plan_id'] = (int) $planId;
            }

            $networkId = data_get($transaction->meta, 'wifi.network_id');
            if ($networkId !== null && $networkId !== '') {
                $data['wifi_network_id'] = (int) $networkId;
            }

        } elseif ($alias === 'wallet_top_up') {
            $walletAccountId = data_get($transaction->meta, 'wallet.wallet_account_id')
                ?? data_get($transaction->meta, 'wallet.account_id');
            if ($walletAccountId !== null && $walletAccountId !== '') {
                $data['wallet_account_id'] = $walletAccountId;
            }
        }

        return array_filter(
            $data,
            static function ($value) {
                if ($value === null) {
                    return false;
                }

                if (is_string($value)) {
                    return trim($value) !== '';
                }

                return true;
            }
        );
    }

    protected function resolvePayableAlias(
        ?string $rawPayableType,
        PaymentTransaction $transaction,
        ?string $normalizedType = null,
        ?string $purpose = null
    ): ?string {
        $candidates = array_filter([
            $purpose,
            data_get($transaction->meta, 'manual.purpose'),
            data_get($transaction->meta, 'metadata.purpose'),
            $rawPayableType,
            $normalizedType,
        ], static fn ($candidate) => is_string($candidate) && trim((string) $candidate) !== '');

        foreach ($candidates as $candidate) {
            $alias = $this->normalizeAliasCandidate($candidate);

            if ($alias === null) {
                continue;
            }

            if ($alias === 'order' || ManualPaymentRequest::isOrderPayableType($candidate)) {
                return 'order';
            }

            if (str_contains($alias, 'package') || str_contains($alias, 'listing') || str_contains($alias, 'featured')) {
                return 'package';
            }

            if (str_contains($alias, 'service')) {
                return 'service';
            }


            if (str_contains($alias, 'wifi')) {
                return 'wifi_plan';
            }

            if (str_contains($alias, 'wallet') || str_contains($alias, 'topup') || str_contains($alias, 'top-up')) {
                return 'wallet_top_up';
            }

            if (str_contains($alias, 'item') || str_contains($alias, 'advertisement')) {
                return 'item';
            }
        }

        if (ManualPaymentRequest::isOrderPayableType((string) $rawPayableType)) {
            return 'order';
        }

        if ($normalizedType !== null && ManualPaymentRequest::isOrderPayableType((string) $normalizedType)) {
            return 'order';
        }

        return null;
    }

    protected function normalizeAliasCandidate(?string $candidate): ?string
    {
        if (! is_string($candidate)) {
            return null;
        }

        $normalized = strtolower(trim($candidate));
        if ($normalized === '') {
            return null;
        }

        $normalized = str_replace(['\\', '/', '-', '_'], ' ', $normalized);
        $normalized = preg_replace('/\s+/', ' ', $normalized) ?: $normalized;

        return trim($normalized);
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
            'service_request', 'service_requests', 'app\\models\\servicerequest' => ServiceRequest::class,
            'wifi_plan', 'wifi_plans', 'wifi-plan', 'wifi-plans' => WifiPlan::class,

            default => $payableType,
        };
    }

    private function ensureServiceTransactionContext(PaymentTransaction $transaction, ServiceRequest $serviceRequest): void
    {
        $meta = $transaction->meta;

        if (! is_array($meta)) {
            $meta = [];
        }

        $context = $meta['context'] ?? [];
        if (! is_array($context)) {
            $context = [];
        }

        $updated = false;

        if (($context['type'] ?? null) !== 'service_request') {
            $context['type'] = 'service_request';
            $updated = true;
        }

        if (($context['service_request_id'] ?? null) !== $serviceRequest->getKey()) {
            $context['service_request_id'] = $serviceRequest->getKey();
            $updated = true;
        }

        if (($context['user_id'] ?? null) !== $serviceRequest->user_id) {
            $context['user_id'] = $serviceRequest->user_id;
            $updated = true;
        }

        if (! $updated) {
            return;
        }

        $meta['context'] = $context;
        $transaction->meta = $meta;
        $transaction->saveQuietly();
    }

    protected function mergeTransactionMeta(PaymentTransaction $transaction, array $meta): void
    {
        if (empty($meta)) {
            return;
        }

        $transaction->meta = array_replace_recursive($transaction->meta ?? [], $meta);
    }


    /**
     * @return array<string, mixed>
     */
    protected function handleWifiPlanPurchase(PaymentTransaction $transaction, ?int $planId, int $userId, array $options = []): array
    {
        if ($planId === null) {
            throw new InvalidArgumentException('Wifi plan id is required to deliver wifi codes.');
        }

        $plan = WifiPlan::query()
            ->with('network.owner')
            ->lockForUpdate()
            ->findOrFail($planId);

        $network = $plan->network;

        if (! $network instanceof WifiNetwork) {
            throw new InvalidArgumentException('Wifi network is not associated with the requested plan.');
        }

        $network = WifiNetwork::query()
            ->with('owner')
            ->lockForUpdate()
            ->findOrFail($network->getKey());

        $plan->setRelation('network', $network);

        $code = WifiCode::query()
            ->where('wifi_plan_id', $plan->getKey())
            ->where('status', WifiCodeStatus::AVAILABLE->value)
            ->orderBy('id')
            ->lockForUpdate()
            ->first();

        if (! $code instanceof WifiCode) {
            throw new RuntimeException('No available wifi codes found for the selected plan.');
        }

        $now = Carbon::now();

        $deliveryPayload = [
            'code' => $code->code,
            'username' => $code->username,
            'password' => $code->password,
            'serial_no' => $code->serialNo,
            'expiry_date' => $code->expiry_date?->toDateString(),
        ];

        $code->status = WifiCodeStatus::SOLD;
        $code->sold_at = $now;
        $code->delivered_at = $now;
        $code->meta = array_replace_recursive($code->meta ?? [], [
            'payment_transaction_id' => $transaction->getKey(),
            'sold_to_user_id' => $userId,
        ]);
        $code->save();

        // احفظ معرف الكود داخل ميتا المعاملة لتسهيل كشف الكرت لاحقاً
        $transactionMeta = $transaction->meta ?? [];
        $transactionMeta['wifi_code_id'] = $code->getKey();
        $transactionMeta['wifi']['wifi_code_id'] = $code->getKey();
        $transaction->meta = $transactionMeta;
        $transaction->save();

        if ($code->wifi_code_batch_id !== null) {
            $batch = WifiCodeBatch::query()
                ->whereKey($code->wifi_code_batch_id)
                ->lockForUpdate()
                ->first();

            if ($batch instanceof WifiCodeBatch) {
                $batch->available_codes = max(0, (int) $batch->available_codes - 1);
                $batch->save();
            }
        }

        $planMeta = $plan->meta;
        if (! is_array($planMeta)) {
            $planMeta = [];
        }

        $planMeta['sales'] = array_replace_recursive($planMeta['sales'] ?? [], [
            'last_transaction_id' => $transaction->getKey(),
            'last_sold_at' => $now->toIso8601String(),
        ]);


        /** @var WifiOperationalService $wifiOperationalService */
        $wifiOperationalService = app(WifiOperationalService::class);
        $planMeta = $wifiOperationalService->handlePostSaleInventory($plan, $network, $planMeta);


        $plan->meta = $planMeta;
        $plan->save();

        $transactionMeta = $transaction->meta;
        if (! is_array($transactionMeta)) {
            $transactionMeta = [];
        }

        $transactionMeta = array_replace_recursive($transactionMeta, [
            'wifi' => [
                'plan_id' => $plan->getKey(),
                'network_id' => $network->getKey(),
                'code_id' => $code->getKey(),
                'code_suffix' => $code->code_suffix,
                'delivered_at' => $now->toIso8601String(),
            ],
        ]);

        $transaction->meta = $transactionMeta;
        $transaction->save();

        $currency = strtoupper((string) ($transaction->currency ?? $plan->currency ?? config('app.currency', 'SAR')));
        $grossAmount = round((float) ($transaction->amount ?? $plan->price), 2);
        $commissionRate = $this->resolveWifiCommissionRate($plan);
        $commissionAmount = round($grossAmount * $commissionRate, 2);
        $netAmount = round($grossAmount - $commissionAmount, 2);

        $owner = $network->owner;

        $buyer = User::query()
            ->select(['id', 'name', 'mobile', 'country_code'])
            ->find($userId);
        $buyerPhone = $this->normalizeUserPhoneNumber($buyer);
        $ownerPhone = $this->normalizeUserPhoneNumber($owner);


        if ($owner && $netAmount > 0) {
            /** @var WalletService $walletService */
            $walletService = app(WalletService::class);

            $walletService->credit($owner, 'wifi_plan:' . $transaction->getKey(), $netAmount, [
                'currency' => $currency,
                'meta' => [
                    'context' => 'wifi_plan_sale',
                    'wifi_network_id' => $network->getKey(),
                    'wifi_plan_id' => $plan->getKey(),
                    'wifi_code_id' => $code->getKey(),
                    'payment_transaction_id' => $transaction->getKey(),
                    'commission_rate' => $commissionRate,
                    'commission_amount' => $commissionAmount,
                    'gross_amount' => $grossAmount,
                ],
            ]);
        }

        $statistics = $network->statistics;
        if (! is_array($statistics)) {
            $statistics = [];
        }

        $salesStats = $statistics['wifi_sales'] ?? [];
        if (! is_array($salesStats)) {
            $salesStats = [];
        }

        $salesStats['codes_sold'] = (int) ($salesStats['codes_sold'] ?? 0) + 1;
        $salesStats['gross_amount'] = round(((float) ($salesStats['gross_amount'] ?? 0)) + $grossAmount, 2);
        $salesStats['net_amount'] = round(((float) ($salesStats['net_amount'] ?? 0)) + $netAmount, 2);
        $salesStats['last_sold_at'] = $now->toIso8601String();

        $statistics['wifi_sales'] = $salesStats;
        $network->statistics = $statistics;
        $network->save();

        $deliveryPayload['plan'] = [
            'id' => $plan->getKey(),
            'name' => $plan->name,
            'price' => (float) $plan->price,
            'currency' => $plan->currency ?? $currency,
        ];

        $deliveryPayload['network'] = [
            'id' => $network->getKey(),
            'name' => $network->name,
        ];

        DB::afterCommit(function () use (
            $userId,
            $owner,
            $plan,
            $network,
            $deliveryPayload,
            $currency,
            $grossAmount,
            $netAmount,
            $buyerPhone,
            $ownerPhone
        ): void {
            
            $userTokens = UserFcmToken::query()
                ->where('user_id', $userId)
                ->pluck('fcm_token')
                ->filter()
                ->unique()
                ->values()
                ->all();

            if ($userTokens !== []) {
                $cardCode = $deliveryPayload['code'] ?? null;

                NotificationService::sendFcmNotification(
                    $userTokens,
                    __('تم إصدار كرت الواي فاي'),
                    $cardCode
                        ? __('الكرت الخاص بك هو :code', ['code' => $cardCode])
                        : __('تم تسليم كود شبكة :network.', ['network' => $network->name]),
                    'wifi_purchase',
                    array_filter([
                        'deeplink' => config('services.mobile.wifi_orders_deeplink', 'maribsrv://wifi/orders'),
                        'wifi_plan_id' => $plan->getKey(),
                        'wifi_network_id' => $network->getKey(),
                        'code' => $deliveryPayload['code'],
                        'username' => $deliveryPayload['username'],
                        'password' => $deliveryPayload['password'],
                        'serial_no' => $deliveryPayload['serial_no'],
                        'expiry_date' => $deliveryPayload['expiry_date'],
                    ], static fn ($value) => $value !== null && $value !== '')
                );
            }

            if ($owner) {
                $ownerTokens = UserFcmToken::query()
                    ->where('user_id', $owner->getKey())
                    ->pluck('fcm_token')
                    ->filter()
                    ->unique()
                    ->values()
                    ->all();

                if ($ownerTokens !== []) {
                    NotificationService::sendFcmNotification(
                        $ownerTokens,
                        __('تم بيع كرت واي فاي'),
                        __('تم بيع :plan بمبلغ :amount :currency.', [
                            'plan' => $plan->name,
                            'amount' => number_format($grossAmount, 2),
                            'currency' => $currency,
                        ]),
                        'wifi_sale',
                        [
                            'deeplink' => config('services.mobile.wifi_owner_sales_deeplink', 'maribsrv://wifi/owner/sales'),
                            'wifi_plan_id' => $plan->getKey(),
                            'wifi_network_id' => $network->getKey(),
                            'net_amount' => $netAmount,
                            'currency' => $currency,
                        ]
                    );
                }
            }



            /** @var SmsService $smsService */
            $smsService = app(SmsService::class);

            if ($buyerPhone) {
                $lines = [
                    __('تم تسليم كرت الواي فاي لشبكة :network.', ['network' => $network->name]),
                    __('الكود: :code', ['code' => $deliveryPayload['code']]),
                ];

                if (! empty($deliveryPayload['username'])) {
                    $lines[] = __('اسم المستخدم: :username', ['username' => $deliveryPayload['username']]);
                }

                if (! empty($deliveryPayload['password'])) {
                    $lines[] = __('كلمة المرور: :password', ['password' => $deliveryPayload['password']]);
                }

                if (! empty($deliveryPayload['serial_no'])) {
                    $lines[] = __('الرقم التسلسلي: :serial', ['serial' => $deliveryPayload['serial_no']]);
                }

                if (! empty($deliveryPayload['expiry_date'])) {
                    $lines[] = __('الصلاحية حتى: :date', ['date' => $deliveryPayload['expiry_date']]);
                }

                $lines[] = __('شكراً لاستخدامك كبينة واي فاي.');

                $smsService->send($buyerPhone, implode("\n", $lines));
            }

            if ($ownerPhone) {
                $ownerMessage = __('تم بيع كرت :plan بمبلغ :amount :currency.', [
                    'plan' => $plan->name,
                    'amount' => number_format($grossAmount, 2),
                    'currency' => $currency,
                ]);

                $smsService->send($ownerPhone, $ownerMessage);
            }

        });

        return $deliveryPayload;
    }

    protected function resolveWifiCommissionRate(WifiPlan $plan): float
    {
        $meta = $plan->meta;
        $rate = null;

        if (is_array($meta)) {
            $rate = $meta['commission_rate'] ?? data_get($meta, 'commission.rate');
        }

        if (! is_numeric($rate)) {
            $network = $plan->relationLoaded('network') ? $plan->network : $plan->network()->first();
            if ($network instanceof WifiNetwork) {
                $settings = $network->settings;
                if (is_array($settings) && isset($settings['commission_rate'])) {
                    $rate = $settings['commission_rate'];
                }
            }
        }

        $normalized = is_numeric($rate) ? (float) $rate : 0.0;

        return max(0.0, min(0.5, round($normalized, 4)));
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



    private function normalizeUserPhoneNumber(?User $user): ?string
    {
        if (! $user instanceof User) {
            return null;
        }

        $mobile = trim((string) $user->mobile);

        if ($mobile === '') {
            return null;
        }

        $countryCode = trim((string) $user->country_code);

        if ($countryCode !== '' && ! Str::startsWith($mobile, $countryCode)) {
            return $countryCode . $mobile;
        }

        return $mobile;
    }

}

