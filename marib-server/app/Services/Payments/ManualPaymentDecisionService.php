<?php

namespace App\Services\Payments;

use App\Models\DeliveryRequest;
use App\Models\ManualPaymentRequest;
use App\Models\ManualPaymentRequestHistory;
use App\Models\Order;
use App\Models\PaymentTransaction;
use App\Models\Store;
use App\Models\StoreStaff;
use App\Models\User;
use App\Models\UserFcmToken;
use App\Models\WalletTransaction;
use App\Services\NotificationService;
use App\Services\PaymentFulfillmentService;
use App\Services\ResponseService;
use App\Services\WalletService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Throwable;

class ManualPaymentDecisionService
{
    public function __construct(
        private readonly PaymentFulfillmentService $paymentFulfillmentService,
        private readonly WalletService $walletService
    ) {
    }

    /**
     * @param array{note?: string|null, notify?: bool, attachment_path?: string|null, attachment_name?: string|null, document_valid_until?: ?string, actor_id?: int|null} $context
     */
    public function decide(ManualPaymentRequest $manualPaymentRequest, string $decision, array $context = []): ManualPaymentRequestHistory
    {
        if (! $manualPaymentRequest->isOpen()) {
            throw new RuntimeException(trans('manual_payment.decide.only_pending'));
        }

        $note = $context['note'] ?? null;
        $shouldNotify = (bool) ($context['notify'] ?? false);
        $attachmentPath = $context['attachment_path'] ?? null;
        $attachmentOriginalName = $context['attachment_name'] ?? null;
        $documentValidUntil = $context['document_valid_until'] ?? null;
        $actorId = $context['actor_id'] ?? null;

        $transaction = $this->resolveTransaction($manualPaymentRequest);

        if (! $transaction) {
            throw new RuntimeException(trans('manual_payment.decide.unable_to_resolve_transaction'));
        }

        DB::beginTransaction();

        try {
            $manualPaymentRequest->update([
                'status' => $decision,
                'admin_note' => $note,
                'reviewed_by' => $actorId,
                'reviewed_at' => now(),
            ]);

            $historyMeta = array_filter([
                'attachment_path' => $attachmentPath,
                'attachment_disk' => $attachmentPath ? 'public' : null,
                'attachment_name' => $attachmentOriginalName,
                'notification_sent' => $shouldNotify,
                'document_valid_until' => $documentValidUntil,
            ], static fn ($value) => $value !== null && $value !== '' && $value !== false);

            $history = ManualPaymentRequestHistory::create([
                'manual_payment_request_id' => $manualPaymentRequest->id,
                'user_id' => $actorId,
                'status' => $decision,
                'note' => $note,
                'meta' => empty($historyMeta) ? null : $historyMeta,
            ]);

            if ($decision === ManualPaymentRequest::STATUS_APPROVED) {
                $this->approveRequest($manualPaymentRequest, $transaction);
            } else {
                $transaction->update([
                    'payment_status' => 'failed',
                    'manual_payment_request_id' => $manualPaymentRequest->id,
                ]);
            }

            DB::commit();

            if ($shouldNotify) {
                $attachmentUrl = null;

                if ($attachmentPath) {
                    try {
                        $attachmentUrl = Storage::disk('public')->url($attachmentPath);
                    } catch (Throwable) {
                        $attachmentUrl = null;
                    }
                }

                $this->sendDecisionNotification(
                    $manualPaymentRequest,
                    $transaction,
                    $decision,
                    $note,
                    $attachmentUrl
                );
            }

            if ($manualPaymentRequest->store_id !== null) {
                $this->notifyStoreTeam(
                    $manualPaymentRequest,
                    $transaction,
                    $decision,
                    $note,
                    $actorId
                );
            }

            $deliveryRequest = null;

            if ($decision === ManualPaymentRequest::STATUS_APPROVED
                && $manualPaymentRequest->payable_type === Order::class
                && $manualPaymentRequest->payable_id
            ) {
                $order = Order::query()->find($manualPaymentRequest->payable_id);
                if ($order) {
                    $deliveryRequest = DeliveryRequest::recordHandoff($order, 'manual_payment_approved');
                }
            }

            $this->notifyAdministrators(
                $manualPaymentRequest,
                $transaction,
                $decision,
                $note,
                $actorId
            );

            if ($deliveryRequest) {
                Log::info('delivery_request.handoff_recorded', [
                    'delivery_request_id' => $deliveryRequest->getKey(),
                    'order_id' => $deliveryRequest->order_id,
                ]);
            }

            return $history;
        } catch (Throwable $throwable) {
            DB::rollBack();

            if ($attachmentPath) {
                Storage::disk('public')->delete($attachmentPath);
            }

            Log::error('Manual payment decision error: ' . $throwable->getMessage(), [
                'request_id' => $manualPaymentRequest->id,
            ]);

            throw new RuntimeException(trans('manual_payment.decide.unable_to_process'));
        }
    }

    private function approveRequest(ManualPaymentRequest $manualPaymentRequest, PaymentTransaction $transaction): void
    {
        if ($manualPaymentRequest->isWalletTopUp()) {
            $manualPaymentRequest->loadMissing('user');

            if (! $manualPaymentRequest->user) {
                throw new RuntimeException('The requester is no longer associated with this wallet top-up.');
            }

            $walletTransaction = $this->walletService->credit(
                $manualPaymentRequest->user,
                $this->walletIdempotencyKey($manualPaymentRequest),
                (float) $manualPaymentRequest->amount,
                [
                    'manual_payment_request' => $manualPaymentRequest,
                    'payment_transaction' => $transaction,
                    'meta' => [
                        'reason' => ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
                    ],
                ]
            );

            $transactionMeta = $transaction->meta ?? [];
            data_set($transactionMeta, 'wallet.transaction_id', $walletTransaction->getKey());
            data_set($transactionMeta, 'wallet.account_id', $walletTransaction->wallet_account_id);

            $transaction->fill([
                'payment_status' => 'succeed',
                'payable_type' => WalletTransaction::class,
                'payable_id' => $walletTransaction->getKey(),
                'manual_payment_request_id' => $manualPaymentRequest->id,
                'meta' => $transactionMeta,
            ])->save();

            $requestMeta = $manualPaymentRequest->meta ?? [];
            data_set($requestMeta, 'wallet.purpose', ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP);
            data_set($requestMeta, 'wallet.transaction_id', $walletTransaction->getKey());
            data_set($requestMeta, 'wallet.idempotency_key', $walletTransaction->idempotency_key);

            $manualPaymentRequest->forceFill([
                'payable_id' => $walletTransaction->wallet_account_id,
                'meta' => $requestMeta,
            ])->save();

            $transaction->refresh();

            return;
        }

        $fulfillment = $this->paymentFulfillmentService->fulfill(
            $transaction,
            $manualPaymentRequest->payable_type,
            $manualPaymentRequest->payable_id,
            $manualPaymentRequest->user_id,
            [
                'manual_payment_request_id' => $manualPaymentRequest->id,
                'notify' => false,
            ]
        );

        if ($fulfillment['error']) {
            throw new RuntimeException($fulfillment['message']);
        }

        $transaction->refresh();
    }

    private function resolveTransaction(ManualPaymentRequest $manualPaymentRequest, bool $required = true): ?PaymentTransaction
    {
        $transaction = $manualPaymentRequest->paymentTransaction;

        $isOrderRequest = ManualPaymentRequest::isOrderPayableType((string) $manualPaymentRequest->payable_type);
        $resolvedOrderId = $isOrderRequest && $manualPaymentRequest->payable_id
            ? (int) $manualPaymentRequest->payable_id
            : null;

        $gatewayKey = ManualPaymentRequest::canonicalGateway(
            data_get($manualPaymentRequest->meta, 'gateway') ?? 'manual_bank'
        ) ?? 'manual_bank';

        $transactionGateway = $gatewayKey === 'manual_banks' ? 'manual_bank' : $gatewayKey;

        if (! $transaction && $required) {
            $attributes = [
                'user_id' => $manualPaymentRequest->user_id,
                'amount' => $manualPaymentRequest->amount,
                'payment_gateway' => $transactionGateway,
                'order_id' => $resolvedOrderId,
                'payable_type' => $isOrderRequest ? Order::class : $manualPaymentRequest->payable_type,
                'payable_id' => $manualPaymentRequest->payable_id,
                'manual_payment_request_id' => $manualPaymentRequest->id,
                'payment_status' => 'pending',
            ];

            $transaction = PaymentTransaction::create($attributes);
        }

        if ($transaction) {
            $updates = [];

            if (empty($transaction->manual_payment_request_id)) {
                $updates['manual_payment_request_id'] = $manualPaymentRequest->id;
            }

            if (empty($transaction->payment_gateway) && $transactionGateway) {
                $updates['payment_gateway'] = $transactionGateway;
            }

            if ($resolvedOrderId !== null && empty($transaction->order_id)) {
                $updates['order_id'] = $resolvedOrderId;
            }

            if (empty($transaction->payable_type)) {
                $updates['payable_type'] = $isOrderRequest ? Order::class : $manualPaymentRequest->payable_type;
            }

            if (empty($transaction->payable_id) && ! empty($manualPaymentRequest->payable_id)) {
                $updates['payable_id'] = $manualPaymentRequest->payable_id;
            }

            if (! empty($updates)) {
                $transaction->fill($updates)->save();
            }
        }

        return $transaction;
    }

    private function walletIdempotencyKey(ManualPaymentRequest $manualPaymentRequest): string
    {
        return sprintf('manual-payment-request:%d:wallet-credit', $manualPaymentRequest->getKey());
    }

    private function sendDecisionNotification(
        ManualPaymentRequest $manualPaymentRequest,
        PaymentTransaction $transaction,
        string $status,
        ?string $note = null,
        ?string $attachmentUrl = null
    ): void {
        $tokens = UserFcmToken::where('user_id', $manualPaymentRequest->user_id)
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $title = $status === ManualPaymentRequest::STATUS_APPROVED
            ? trans('Manual payment approved')
            : trans('Manual payment rejected');

        $body = trans('Reference #:ref - Amount: :amount', [
            'ref' => $manualPaymentRequest->reference ?? $manualPaymentRequest->id,
            'amount' => number_format($manualPaymentRequest->amount, 2) . ($manualPaymentRequest->currency ? ' ' . $manualPaymentRequest->currency : ''),
        ]);

        $deepLink = route('payment-requests.deep-link', $transaction);

        $data = [
            'transaction_id' => $transaction->id,
            'manual_payment_request_id' => $manualPaymentRequest->id,
            'status' => $status,
            'deep_link' => $deepLink,
        ];

        if ($note) {
            $data['note'] = $note;
        }

        if ($attachmentUrl) {
            $data['attachment'] = $attachmentUrl;
        }

        NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'payment-transaction',
            $data
        );
    }

    private function notifyStoreTeam(
        ManualPaymentRequest $manualPaymentRequest,
        PaymentTransaction $transaction,
        string $status,
        ?string $note,
        ?int $actorId
    ): void {
        if (! $manualPaymentRequest->store_id) {
            return;
        }

        $store = $manualPaymentRequest->store ?? Store::query()->find($manualPaymentRequest->store_id);

        if (! $store) {
            return;
        }

        $userIds = collect([$store->user_id])
            ->filter()
            ->values();

        $staffUserIds = StoreStaff::query()
            ->where('store_id', $store->getKey())
            ->whereNull('revoked_at')
            ->whereNotNull('user_id')
            ->pluck('user_id');

        $recipientIds = $userIds
            ->merge($staffUserIds)
            ->filter(static fn ($id) => $id !== null && $id !== $actorId)
            ->unique()
            ->values();

        if ($recipientIds->isEmpty()) {
            return;
        }

        $tokens = UserFcmToken::query()
            ->whereIn('user_id', $recipientIds)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $title = $status === ManualPaymentRequest::STATUS_APPROVED
            ? __('تم تأكيد حوالة أحد العملاء')
            : __('تم رفض حوالة أحد العملاء');

        $reference = $manualPaymentRequest->reference ?? $manualPaymentRequest->id;
        $orderId = $transaction->order_id ?? $manualPaymentRequest->payable_id;

        $body = __('الحوالة رقم :ref أصبحت :status.', [
            'ref' => $reference,
            'status' => $this->humanReadableStatus($status),
        ]);

        $deeplink = $this->resolveStoreManualPaymentRoute($manualPaymentRequest);

        $payload = [
            'manual_payment_request_id' => $manualPaymentRequest->id,
            'order_id' => $orderId,
            'store_id' => $store->getKey(),
            'status' => $status,
            'reference' => $reference,
            'note' => $note,
            'deeplink' => $deeplink,
            'click_action' => $deeplink,
            'type' => 'store_manual_payment_decision',
        ];

        NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'store_manual_payment_decision',
            $payload
        );
    }

    private function notifyAdministrators(
        ManualPaymentRequest $manualPaymentRequest,
        PaymentTransaction $transaction,
        string $status,
        ?string $note,
        ?int $actorId
    ): void {
        $adminRoles = ['admin', 'Admin', 'super-admin', 'Super Admin'];

        $adminIds = User::role($adminRoles)
            ->pluck('id')
            ->filter(static fn ($id) => $id !== $actorId)
            ->unique()
            ->values();

        if ($adminIds->isEmpty()) {
            return;
        }

        $tokens = UserFcmToken::query()
            ->whereIn('user_id', $adminIds)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $reference = $manualPaymentRequest->reference ?? $manualPaymentRequest->id;
        $orderId = $transaction->order_id ?? $manualPaymentRequest->payable_id;

        $title = $status === ManualPaymentRequest::STATUS_APPROVED
            ? __('تم اعتماد حوالة يدويـة')
            : __('تم رفض حوالة يدويـة');

        $body = __('الحوالة رقم :ref للطلب :order أصبحت :status.', [
            'ref' => $reference,
            'order' => $orderId ?? '-',
            'status' => $this->humanReadableStatus($status),
        ]);

        $deeplink = $this->resolveAdminManualPaymentRoute($manualPaymentRequest);

        $payload = [
            'manual_payment_request_id' => $manualPaymentRequest->id,
            'order_id' => $orderId,
            'reference' => $reference,
            'status' => $status,
            'store_id' => $manualPaymentRequest->store_id,
            'note' => $note,
            'deeplink' => $deeplink,
            'click_action' => $deeplink,
            'type' => 'manual_payment_decision_admin',
        ];

        NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'manual_payment_decision_admin',
            $payload
        );
    }

    private function humanReadableStatus(string $status): string
    {
        return match ($status) {
            ManualPaymentRequest::STATUS_APPROVED => __('مقبولة'),
            ManualPaymentRequest::STATUS_REJECTED => __('مرفوضة'),
            ManualPaymentRequest::STATUS_UNDER_REVIEW => __('قيد المراجعة'),
            default => __('قيد المعالجة'),
        };
    }

    private function resolveStoreManualPaymentRoute(ManualPaymentRequest $manualPaymentRequest): ?string
    {
        if (! Route::has('merchant.manual-payments.show')) {
            return null;
        }

        try {
            return route('merchant.manual-payments.show', $manualPaymentRequest);
        } catch (Throwable) {
            return null;
        }
    }

    private function resolveAdminManualPaymentRoute(ManualPaymentRequest $manualPaymentRequest): ?string
    {
        if (! Route::has('payment-requests.review')) {
            return null;
        }

        try {
            return route('payment-requests.review', $manualPaymentRequest);
        } catch (Throwable) {
            return null;
        }
    }
}
