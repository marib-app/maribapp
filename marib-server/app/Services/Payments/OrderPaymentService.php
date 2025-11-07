<?php

namespace App\Services\Payments;
use App\Services\Payments\ManualPaymentRequestService;
use App\Models\Order;
use App\Models\ManualPaymentRequest;
use App\Services\OrderCheckoutService;
use App\Services\Payments\Concerns\HandlesManualBankConfirmation;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Services\PaymentFulfillmentService;
use App\Services\WalletService;
use App\Support\ManualPayments\TransferDetailsResolver;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Arr;
use App\Support\InputSanitizer;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use App\Services\Payments\TransactionAmountResolver;
use App\Services\Payments\CreateOrLinkManualPaymentRequest;

use RuntimeException;
use Throwable;

class OrderPaymentService
{
    use HandlesManualBankConfirmation;

    /**
     * @var array<int, string>
     */
    private const SUPPORTED_METHODS = [
        'manual_bank',
        'east_yemen_bank',
        'wallet',
        'cash',
    ];

    /**
     * @var array<string, array<int, string>>
     */
    private const LEGACY_METHOD_ALIASES = [
        'manual_bank' => ['manual'],
        'east_yemen_bank' => ['bank_alsharq', 'bank_alsharq_bank'],
    ];

    /**
     * @return array<int, string>
     */
    public static function supportedMethods(): array
    {
        return self::SUPPORTED_METHODS;
    }


    public function __construct(
        private readonly DatabaseManager $db,
        private readonly WalletService $walletService,
        private readonly PaymentFulfillmentService $fulfillmentService,
        private readonly ManualPaymentRequestService $manualPaymentRequestService,
        private readonly CreateOrLinkManualPaymentRequest $manualPaymentLinker
        
        ) {
    }

    /**
     * @param array<string, mixed> $data
     */
    public function initiate(User $user, Order $order, string $method, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        // sanitize client input: strip any *_number fields
        $data = InputSanitizer::stripNumberFields($data);

        $method = $this->normalizePaymentMethod($method);

        $data['payment_method'] = $method;

        return $this->db->transaction(function () use ($user, $order, $method, $idempotencyKey, $data) {
            $transaction = $this->findOrCreateTransaction($user, $order, $method, $idempotencyKey, $data);

            if ($transaction instanceof PaymentTransaction && $method === 'manual_bank') {
                $this->attachManualTransferData($user, $order, $transaction, $method, $idempotencyKey, $data);
            }

            return $transaction;


        });
    }

    /**
     * @param array<string, mixed> $data
     */
    public function confirm(User $user, PaymentTransaction $transaction, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        // sanitize client input: strip any *_number fields
        $data = InputSanitizer::stripNumberFields($data);

        if ($transaction->payment_status === 'succeed') {
            return $transaction;
        }

        if ((int) $transaction->user_id !== $user->getKey()) {
            throw ValidationException::withMessages([
                'transaction' => __('المعاملة المحددة لا تخص المستخدم.'),
            ]);
        }

        if ($transaction->payable_type !== Order::class) {
            throw ValidationException::withMessages([
                'transaction' => __('لا يمكن تأكيد هذه المعاملة للنوع المحدد.'),
            ]);
        }

        /** @var Order|null $order */
        $order = $transaction->payable instanceof Order
            ? $transaction->payable
            : Order::find($transaction->payable_id);

        if (! $order) {
            throw ValidationException::withMessages([
                'transaction' => __('تعذر العثور على الطلب المرتبط بالمعاملة.'),
            ]);
        }

        $rawMethod = Arr::get($data, 'payment_method');

        if (! is_string($rawMethod) || $rawMethod === '') {
            $rawMethod = $transaction->payment_gateway;
        }

        $method = $this->normalizePaymentMethod(is_string($rawMethod) ? $rawMethod : null);


        if ($transaction->payment_gateway !== $method) {
            $transaction->payment_gateway = $method;
            $transaction->save();

        }

        $data['payment_method'] = $method;

        $manualContext = null;

        if ($method === 'manual_bank') {
            $manualContext = $this->prepareManualBankConfirmationPayload(
                $user,
                $transaction,
                Order::class,
                $order->getKey(),
                $method,
                $idempotencyKey,
                $data
            );

            if ($manualContext !== null) {
                $data = $manualContext['data'];
            }
        }


        $options = [
            'payment_gateway' => $method,
            'order_payment_method' => $method,
            'meta' => $this->mergeTransactionMeta($transaction, $data, $idempotencyKey),
            'payment_reference' => $data['reference'] ?? null,
        ];

        $manualPaymentRequestId = $data['manual_payment_request_id'] ?? $transaction->manual_payment_request_id;


        if ($manualContext !== null) {
            $manualPaymentRequest = $manualContext['manual_payment_request'];
            $options['meta'] = $this->mergeManualConfirmationMeta(
                $options['meta'],
                $data,
                $manualPaymentRequest,
                $transaction,
                $idempotencyKey
            );

            $manualPaymentRequestId = $manualPaymentRequest->getKey();
            $transaction->manual_payment_request_id = $manualPaymentRequestId;
            $transaction->meta = $options['meta'];
            $transaction->save();
        }


        if ($manualPaymentRequestId) {
            $options['manual_payment_request_id'] = $manualPaymentRequestId;
        }


        if ($method === 'wallet') {
            $transactionCurrency = strtoupper((string) ($transaction->currency ?? $this->resolveOrderCurrency($order)));
            $this->assertWalletCurrencyCompatibility($user, $order, $transactionCurrency, false);
            $dataWithCurrency = $data;
            $dataWithCurrency['currency'] = $transactionCurrency;
            $walletTransaction = $this->debitWallet($user, $transaction, $idempotencyKey, $dataWithCurrency);


            $options['wallet_transaction'] = $walletTransaction;
        }

        $result = $this->fulfillmentService->fulfill(
            $transaction,
            Order::class,
            $order->getKey(),
            $user->getKey(),
            $options
        );

        if ($result['error'] ?? true) {
            Log::warning('order_payment.confirm_failed', [
                'transaction_id' => $transaction->getKey(),
                'message' => $result['message'] ?? null,
            ]);

            throw ValidationException::withMessages([
                'payment' => __('تعذر إكمال عملية الدفع حالياً.'),
            ]);
        }

        if (! empty($options['payment_reference'])) {
            $transaction->payment_id = $options['payment_reference'];
        }

        $transaction->payment_status = 'succeed';
        $transaction->meta = $options['meta'];
        $transaction->save();

        $order->refresh();

        return $transaction->fresh();
    }

    /**
     * @param array<string, mixed> $data
     */
    public function createManual(User $user, Order $order, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        // sanitize client input: strip any *_number fields
        $data = InputSanitizer::stripNumberFields($data);

        return $this->db->transaction(function () use ($user, $order, $idempotencyKey, $data) {
            $method = $this->normalizePaymentMethod('manual_bank');
            $data['payment_method'] = $method;
            $transaction = $this->findOrCreateTransaction($user, $order, $method, $idempotencyKey, $data);

            $transactionCurrency = (string) ($transaction->currency ?? $this->resolveOrderCurrency($order));

            $rawBankName = Arr::get($data, 'bank.name');

            if (! is_string($rawBankName) || trim($rawBankName) === '') {
                $rawBankName = Arr::get($data, 'bank_name');
            }

            $bankName = is_string($rawBankName) ? trim($rawBankName) : null;
            if ($bankName === '') {
                $bankName = null;
            }

            $manualPaymentRequest = $transaction->manualPaymentRequest;

            $manualBankIdentifier = Arr::get($data, 'manual_bank_id') ?? Arr::get($data, 'bank_id');
            if ($bankName !== null) {
                data_set($data, 'bank.name', $bankName);
            }


            $receiptContext = $this->resolveManualReceiptContext($data);

            if ($receiptContext['attachments'] !== []) {
                $data['attachments'] = $receiptContext['attachments'];
            }

            if ($receiptContext['receipt_path'] !== null) {
                $data['receipt_path'] = $receiptContext['receipt_path'];
            }

            if ($receiptContext['receipt_url'] !== null) {
                $data['receipt_url'] = $receiptContext['receipt_url'];
            }

            if ($receiptContext['receipt_path'] !== null || $receiptContext['receipt_url'] !== null) {
                $data['receipt'] = array_filter([
                    'path' => $receiptContext['receipt_path'],
                    'disk' => 'public',
                    'url' => $receiptContext['receipt_url'],
                ], static fn ($value) => $value !== null && $value !== '');
            }


            $manualPaymentRequest = $this->manualPaymentLinker->handle(
                $user,
                Order::class,
                $order->getKey(),
                $transaction,
                $data
            );



            $manualMeta = array_filter(
                [
                    'note' => Arr::get($data, 'note'),
                    'reference' => Arr::get($data, 'reference'),
                    'attachments' => $receiptContext['attachments'],
                    'receipt_path' => $receiptContext['receipt_path'],
                    'receipt_url' => $receiptContext['receipt_url'],
                ],
                
                static function ($value) {
                    if (is_array($value)) {
                        return $value !== [];
                    }

                    return $value !== null && $value !== '';
                }
            );


            if ($receiptContext['receipt_path'] !== null || $receiptContext['receipt_url'] !== null) {
                $manualMeta['receipt'] = array_filter([
                    'path' => $receiptContext['receipt_path'],
                    'disk' => 'public',
                    'url' => $receiptContext['receipt_url'],
                ], static fn ($value) => $value !== null && $value !== '');
            }


            $resolvedBankName = $bankName
                ?? $manualPaymentRequest->bank_name
                ?? $manualPaymentRequest->manualBank?->name;

            $resolvedBeneficiary = $manualPaymentRequest->bank_account_name
                ?? $manualPaymentRequest->manualBank?->beneficiary_name;



            $manualMeta['bank'] = array_filter([
                'id' => $manualBankIdentifier ?? null,
                'account_id' => $data['bank_account_id'] ?? null,
                'name' => is_string($resolvedBankName) && trim($resolvedBankName) !== '' ? trim($resolvedBankName) : null,
                'beneficiary_name' => is_string($resolvedBeneficiary) && trim($resolvedBeneficiary) !== ''
                    ? trim($resolvedBeneficiary)
                    : null,
                
                
                ], static fn ($value) => $value !== null && $value !== '');

            if ($manualMeta['bank'] === []) {
                unset($manualMeta['bank']);

            }


            $metadata = Arr::get($data, 'metadata');
            if (is_array($metadata) && ! empty($metadata)) {
                $manualMeta['metadata'] = $metadata;
            }

            $manualMeta['idempotency_key'] = $transaction->idempotency_key ?? $idempotencyKey;

            $transaction->payment_status = Arr::get($data, 'auto_confirm') ? 'succeed' : 'pending';
            $transaction->payment_id = $data['reference'] ?? $transaction->payment_id;
            $meta = $transaction->meta ?? [];
            if (! is_array($meta)) {
                $meta = [];
            }

            $manualBankIdForPayload = $manualBankIdentifier ?? $manualPaymentRequest->manual_bank_id;
            if (is_string($manualBankIdForPayload) && trim($manualBankIdForPayload) === '') {
                $manualBankIdForPayload = null;
            }

            if ($manualBankIdForPayload !== null && $manualBankIdForPayload !== '') {
                $normalizedBankId = is_numeric($manualBankIdForPayload) ? (int) $manualBankIdForPayload : null;

                if ($normalizedBankId !== null && $normalizedBankId > 0) {
                    data_set($meta, 'payload.manual_bank_id', $normalizedBankId);
                }
            }

            if (is_string($resolvedBankName) && trim($resolvedBankName) !== '') {
                data_set($meta, 'payload.bank_name', trim($resolvedBankName));
            }

            $transaction->meta = array_replace_recursive($meta, [
                
                'manual' => $manualMeta,
                'manual_payment_request' => [
                    'id' => $manualPaymentRequest->getKey(),
                    'status' => $manualPaymentRequest->status,
                ],
            ]);
            $transaction->save();

            $manualPaymentRequest = $this->syncOrderManualTransferPayload($order, $manualPaymentRequest);


            $transaction->setRelation('manualPaymentRequest', $manualPaymentRequest->loadMissing('manualBank'));

            if (Arr::get($data, 'auto_confirm')) {
                $dataWithManualRequest = $data;
                $dataWithManualRequest['manual_payment_request_id'] = $manualPaymentRequest->getKey();

                return $this->confirm($user, $transaction->fresh(), $idempotencyKey, $dataWithManualRequest);
            }

            return $transaction->fresh();
        });
    }

    /**
     * @param array<string, mixed> $data
     */
    private function findOrCreateTransaction(
        User $user,
        Order $order,
        string $method,
        string $idempotencyKey,
        array $data = []
    ): PaymentTransaction {
        
        $method = $this->normalizePaymentMethod($method);
        $data['payment_method'] = $method;

        $existing = PaymentTransaction::query()
            ->where('user_id', $user->getKey())
            ->whereIn('payment_gateway', $this->expandLegacyMethods($method))
            ->where('idempotency_key', $idempotencyKey)
            ->lockForUpdate()
            ->first();

        if ($existing) {
            if ((int) $existing->payable_id !== $order->getKey()) {
                throw ValidationException::withMessages([
                    'idempotency' => __('المعاملة المرتبطة بالمفتاح المرسل تتعلق بطلب مختلف.'),
                ]);
            }

            if ($existing->payment_gateway !== $method) {
                // Do not set payment_gateway to 'manual_bank' on an existing transaction
                // if it does not yet reference a ManualPaymentRequest. The DB has a
                // BEFORE UPDATE trigger that will SIGNAL in that case. Defer
                // setting to 'manual_bank' until a manual_payment_request_id exists.
                if ($method === 'manual_bank' && ! $existing->manual_payment_request_id) {
                    // leave existing gateway as-is for now
                } else {
                    $existing->payment_gateway = $method;
                    $existing->save();
                }
            }


            return $existing;


        }

        $overallDue = $this->resolveOverallDue($order);
        $depositDue = $this->resolveDepositOutstanding($order);
        $dueAmount = $this->resolveAmountDue($order, $overallDue, $depositDue);
        $requestedAmount = isset($data['amount']) ? (float) $data['amount'] : null;

        if ($requestedAmount !== null && $requestedAmount > 0) {
            $amount = min($overallDue, round($requestedAmount, 2));
        } else {
            $amount = $dueAmount;
        }

        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => __('لا يوجد رصيد مستحق على هذا الطلب.'),
            ]);
        }

        $orderCurrency = $this->resolveOrderCurrency($order);
        $transactionCurrency = strtoupper((string) ($data['currency'] ?? $orderCurrency));

        if ($method === 'wallet') {
            $transactionCurrency = $this->assertWalletCurrencyCompatibility($user, $order, $transactionCurrency, true);
        }

        $data['currency'] = $transactionCurrency;
        $orderReference = $this->resolveOrderReference($order, $data);

        $meta = $this->buildTransactionMeta('initiated', $data);
        $meta = $this->mergeCurrencyMeta($meta, $order, $method, $amount, $data);

        $meta = array_replace_recursive($meta, [
            'order' => [
                'id' => $order->getKey(),
                'order_number' => $orderReference,
            ],
        ]);



        $gatewayForInsert = $method;

        // If we're creating a manual_bank transaction but no manual_payment_request_id
        // is present in the payload, avoid inserting payment_gateway='manual_bank'
        // because DB triggers will reject that. Insert with an empty gateway and
        // let the manual-linker attach the manual request and then set the gateway.
        if ($method === 'manual_bank' && empty($data['manual_payment_request_id'])) {
            $gatewayForInsert = '';
        }

        return PaymentTransaction::create([
            'user_id' => $user->getKey(),
            'amount' => $amount,
            'currency' => $transactionCurrency,
            'payment_gateway' => $gatewayForInsert,
            'order_id' => $orderReference,

            'payment_status' => 'pending',
            'payable_type' => Order::class,
            'payable_id' => $order->getKey(),
            'idempotency_key' => $idempotencyKey,
            'meta' => $meta,
        ]);
    }


    /**
     * @param array<string, mixed> $data
     */
    private function resolveOrderReference(Order $order, array $data): string
    {
        $legalReference = $this->determineLegalOrderReference($order);
        $rawReference = Arr::get($data, 'order_id');

        if (! is_string($rawReference) || trim($rawReference) === '') {
            return $legalReference;
        }

        $normalizedReference = trim($rawReference);

        if (! $this->referenceMatchesLegalSequence($normalizedReference, $legalReference)) {
            throw ValidationException::withMessages([
                'order_id' => __('The provided order reference does not match the legal numbering sequence.'),
            ]);
        }

        return $normalizedReference;
    }

    private function determineLegalOrderReference(Order $order): string
    {
        $current = trim((string) $order->order_number);

        if ($current !== '') {
            return $current;
        }

        $refreshed = $order->refreshOrderNumber();
        $refreshedNumber = trim((string) $refreshed->order_number);

        if ($refreshedNumber !== '') {
            return $refreshedNumber;
        }

        return (string) $order->getKey();
    }

    private function referenceMatchesLegalSequence(string $incoming, string $legalReference): bool
    {
        if ($incoming === $legalReference) {
            return true;
        }

        return strcasecmp($incoming, $legalReference) === 0;
    }


    
    /**
     * @param array<string, mixed> $data
     */
    private function attachManualTransferData(
        User $user,
        Order $order,
        PaymentTransaction $transaction,
        string $method,
        string $idempotencyKey,
        array $data
    ): void {
        $manualTransfer = Arr::get($data, 'manual_transfer');

        if (! is_array($manualTransfer)) {
            $manualTransfer = [];
        }

        $senderName = $this->normalizeManualString(
            $manualTransfer['sender_name']
                ?? Arr::get($data, 'sender_name')
        );

        $transferReference = $this->normalizeManualString(
            $manualTransfer['transfer_reference']
                ?? Arr::get($data, 'transfer_reference')
                ?? Arr::get($data, 'reference')
        );

        $note = $this->normalizeManualNote(
            $manualTransfer['note']
                ?? Arr::get($data, 'note')
        );

        $bankId = Arr::get($data, 'manual_bank_id')
            ?? Arr::get($data, 'bank_id')
            ?? Arr::get($data, 'payment.manual_bank_id')
            ?? Arr::get($data, 'payment.bank_id');
        $normalizedBankId = $this->normalizeManualBankId($bankId);
        $hasTransferDetails = $senderName !== null
            || $transferReference !== null
            || $note !== null
            || $manualTransfer !== [];

        if ($normalizedBankId === null || ! $hasTransferDetails) {
            return;
        }

        $bankName = $this->normalizeManualString(
            Arr::get($data, 'bank_name')
                ?? Arr::get($data, 'payment.bank_name')
        );

        $storeGatewayAccountId = Arr::get($manualTransfer, 'store_gateway_account_id')
            ?? Arr::get($data, 'store_gateway_account_id');
        $storeGatewayAccountSnapshot = Arr::get($manualTransfer, 'store_gateway_account');
        $storeSnapshot = Arr::get($manualTransfer, 'store');

        $payload = array_filter([
            'manual_bank_id' => $normalizedBankId,
            'bank_id' => $normalizedBankId,
            'bank_name' => $bankName,
            'sender_name' => $senderName,
            'reference' => $transferReference,
            'note' => $note,
            'manual_transfer' => $manualTransfer !== [] ? $manualTransfer : null,
            'metadata' => $manualTransfer !== [] ? ['manual_transfer' => $manualTransfer] : null,
        ], static fn ($value) => $value !== null && $value !== '');

        if ($manualTransfer !== []) {
            $payload['transfer'] = $manualTransfer;

            if ($transferReference !== null) {
                $payload['transfer_reference'] = $transferReference;
                $payload['transfer_code'] = $transferReference;
            }
        }


        $receiptContext = $this->resolveManualReceiptContext($data, $manualTransfer);

        if ($receiptContext['attachments'] !== []) {
            $payload['attachments'] = $receiptContext['attachments'];
        }

        if ($receiptContext['receipt_path'] !== null) {
            $payload['receipt_path'] = $receiptContext['receipt_path'];
        }

        if ($receiptContext['receipt_url'] !== null) {
            $payload['receipt_url'] = $receiptContext['receipt_url'];
        }

        if ($receiptContext['receipt_path'] !== null || $receiptContext['receipt_url'] !== null) {
            $payload['receipt'] = array_filter([
                'path' => $receiptContext['receipt_path'],
                'disk' => 'public',
                'url' => $receiptContext['receipt_url'],
            ], static fn ($value) => $value !== null && $value !== '');
        }

        if ($order->store_id !== null) {
            $payload['store_id'] = $order->store_id;
        }

        if ($storeSnapshot) {
            if (! isset($storeSnapshot['id']) && $order->store_id !== null) {
                $storeSnapshot['id'] = $order->store_id;
            }

            $payload['store'] = $storeSnapshot;
        } elseif ($order->store_id !== null) {
            $payload['store'] = ['id' => $order->store_id];
        }

        if ($storeGatewayAccountId !== null) {
            $payload['store_gateway_account_id'] = (int) $storeGatewayAccountId;
        }

        if (is_array($storeGatewayAccountSnapshot) && $storeGatewayAccountSnapshot !== []) {
            $payload['store_gateway_account'] = $storeGatewayAccountSnapshot;
        }


        $payload['payment_gateway'] = $method;
        $payload['idempotency_key'] = $transaction->idempotency_key ?? $idempotencyKey;

        try {
            $manualPaymentRequest = $this->manualPaymentLinker->handle(
                $user,
                Order::class,
                $order->getKey(),
                $transaction,
                $payload
            );
            $this->syncOrderManualTransferPayload($order, $manualPaymentRequest);


        } catch (ValidationException $exception) {
            Log::info('order_payment.manual_linker.skipped', [
                'order_id' => $order->getKey(),
                'transaction_id' => $transaction->getKey(),
                'message' => $exception->getMessage(),
            ]);
        } catch (Throwable $throwable) {
            Log::warning('order_payment.manual_linker.failed', [
                'order_id' => $order->getKey(),
                'transaction_id' => $transaction->getKey(),
                'message' => $throwable->getMessage(),
            ]);
        }
    }


    private function syncOrderManualTransferPayload(Order $order, ManualPaymentRequest $manualPaymentRequest): ManualPaymentRequest
    {
        try {
            $syncedManualRequest = $this->manualPaymentRequestService->syncTransferDetails($manualPaymentRequest);

            $transferDetails = TransferDetailsResolver::forManualPaymentRequest($syncedManualRequest)->toArray();
            $meta = $syncedManualRequest->meta;

            if (! is_array($meta)) {
                $meta = [];
            }

            $attachments = $this->normalizeManualTransferAttachments(Arr::get($meta, 'attachments'));

            if ($attachments !== []) {
                $transferDetails['attachments'] = $attachments;
            }

            $receiptPath = $transferDetails['receipt_path'] ?? null;
            $receiptUrl = $transferDetails['receipt_url'] ?? null;
            $receiptDisk = 'public';

            $receiptMeta = Arr::get($meta, 'receipt');
            if (is_array($receiptMeta)) {
                $candidateDisk = Arr::get($receiptMeta, 'disk');

                if (is_string($candidateDisk) && trim($candidateDisk) !== '') {
                    $receiptDisk = trim($candidateDisk);
                }
            }

            if ((is_string($receiptPath) && $receiptPath !== '') || (is_string($receiptUrl) && $receiptUrl !== '')) {
                $transferDetails['receipt'] = array_filter([
                    'path' => is_string($receiptPath) && $receiptPath !== '' ? $receiptPath : null,
                    'disk' => $receiptDisk,
                    'url' => is_string($receiptUrl) && $receiptUrl !== '' ? $receiptUrl : null,
                ], static fn ($value) => $value !== null && $value !== '');
            }

            $filteredDetails = array_filter($transferDetails, static function ($value) {
                if (is_array($value)) {
                    return $value !== [];
                }

                return $value !== null && $value !== '';
            });

            if ($filteredDetails !== []) {
                $order->mergePaymentPayload([
                    'manual_transfer' => $filteredDetails,
                ]);

                if ($order->isDirty('payment_payload')) {
                    $order->save();
                }
            }

            return $syncedManualRequest;
        } catch (Throwable $throwable) {
            Log::warning('order_payment.manual_transfer.sync_failed', [
                'order_id' => $order->getKey(),
                'manual_payment_request_id' => $manualPaymentRequest->getKey(),
                'message' => $throwable->getMessage(),
            ]);

            return $manualPaymentRequest->loadMissing('manualBank', 'paymentTransaction.walletTransaction');
        }
    }

    /**
     * @param array<string, mixed> $data
     * @param array<string, mixed> $manualTransfer
     * @return array{attachments: array<int, array<string, mixed>>, receipt_path: ?string, receipt_url: ?string}
     */
    private function resolveManualReceiptContext(array $data, array $manualTransfer = []): array
    {
        $attachments = $this->normalizeManualTransferAttachments(
            Arr::get($data, 'attachments')
                ?? Arr::get($manualTransfer, 'attachments')
        );

        $receiptPath = Arr::get($data, 'receipt_path');
        if ($receiptPath === null) {
            $receiptPath = Arr::get($manualTransfer, 'receipt_path');
        }
        $receiptPath = $this->normalizeManualString($receiptPath);

        $receiptUrl = Arr::get($data, 'receipt_url');
        if ($receiptUrl === null) {
            $receiptUrl = Arr::get($manualTransfer, 'receipt_url')
                ?? Arr::get($manualTransfer, 'receipt.url');
        }
        $receiptUrl = $this->normalizeManualString($receiptUrl);

        if ($receiptUrl === null) {
            foreach ($attachments as $attachment) {
                $candidate = Arr::get($attachment, 'url');

                if (! is_string($candidate)) {
                    continue;
                }

                $trimmed = trim($candidate);

                if ($trimmed === '') {
                    continue;
                }

                $receiptUrl = $trimmed;
                break;
            }
        }

        if ($receiptPath === null) {
            foreach ($attachments as $attachment) {
                $candidate = Arr::get($attachment, 'path');

                if (! is_string($candidate)) {
                    continue;
                }

                $trimmed = trim($candidate);

                if ($trimmed === '') {
                    continue;
                }

                $receiptPath = $trimmed;
                break;
            }
        }

        return [
            'attachments' => $attachments,
            'receipt_path' => $receiptPath,
            'receipt_url' => $receiptUrl,
        ];
    }

    /**
     * @param mixed $attachments
     * @return array<int, array<string, mixed>>
     */
    private function normalizeManualTransferAttachments(mixed $attachments): array
    {
        if (! is_iterable($attachments)) {
            return [];
        }

        $normalized = [];

        foreach ($attachments as $attachment) {
            if (! is_array($attachment)) {
                continue;
            }

            $normalized[] = $attachment;
        }

        return array_values($normalized);
    }


    private function normalizeManualString($value): ?string
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

    private function normalizeManualNote($value): ?string
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

    private function normalizeManualBankId($value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (is_numeric($value) && ! is_bool($value)) {
            $intValue = (int) $value;

            return $intValue > 0 ? $intValue : null;
        }

        return null;
    }

    private function resolveAmountDue(Order $order, ?float $overallDue = null, ?float $depositDue = null): float    {



        $overallDue ??= $this->resolveOverallDue($order);
        $depositDue ??= $this->resolveDepositOutstanding($order);

        if ($depositDue > 0.0 && ($overallDue <= 0.0 || $depositDue < $overallDue)) {
            return $depositDue;
        }

        return $overallDue;
    }

    private function resolveOverallDue(Order $order): float
    {


        $onlinePayable = $this->resolveOnlinePayable($order);

        if ($onlinePayable !== null) {
            return max(round($onlinePayable, 2), 0.0);
        }
        $orderCurrency = $this->resolveOrderCurrency($order);

        $paid = $order->paymentTransactions()
            ->where('payment_status', 'succeed')
            ->get(['amount', 'currency', 'meta'])
            ->sum(static fn (PaymentTransaction $transaction) => TransactionAmountResolver::resolveForOrder($transaction, $orderCurrency));

        return max(round((float) $order->final_amount - (float) $paid, 2), 0.0);
    }



    private function resolveDepositOutstanding(Order $order): float
    {
        $payloadRemaining = Arr::get($order->payment_payload, 'deposit.remaining_amount');

        if ($payloadRemaining !== null) {
            return max(round((float) $payloadRemaining, 2), 0.0);
        }

        $remaining = $order->deposit_remaining_balance;

        if ($remaining !== null) {
            return max(round((float) $remaining, 2), 0.0);
        }

        return 0.0;
    }


    private function resolveOnlinePayable(Order $order): ?float
    {
        $payloadOnline = data_get($order->payment_payload, 'delivery_payment.online_payable');

        if ($payloadOnline !== null) {
            return (float) $payloadOnline;
        }

        if ($order->delivery_online_payable !== null) {
            return (float) $order->delivery_online_payable;
        }

        return null;
    }

    private function assertSupportedMethod(string $method): void
    {
        if (! in_array($method, self::SUPPORTED_METHODS, true)) {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع غير مدعومة.'),
            ]);
        }
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function buildTransactionMeta(string $status, array $payload): array
    {
        return [
            'status' => $status,
            'payload' => $payload,
            'timestamps' => [
                $status => now()->toIso8601String(),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $data
     */
    private function mergeTransactionMeta(PaymentTransaction $transaction, array $data, string $idempotencyKey): array
    {
        $meta = $transaction->meta ?? [];
        $meta['status'] = 'confirmed';
        $meta['payload'] = array_replace_recursive($meta['payload'] ?? [], $data);
        $meta['timestamps'] = array_replace($meta['timestamps'] ?? [], [
            'confirmed' => now()->toIso8601String(),
        ]);
        $meta['confirmation_idempotency_key'] = $idempotencyKey;

        return $meta;
    }

    /**
     * @param array<string, mixed> $data
     */
    private function debitWallet(User $user, PaymentTransaction $transaction, string $idempotencyKey, array $data = [])
    {
        try {

            $existingIdempotency = is_string($transaction->idempotency_key)
                ? trim($transaction->idempotency_key)
                : '';
            $normalizedIdempotencyKey = trim($idempotencyKey);

            if ($existingIdempotency === '' && $normalizedIdempotencyKey !== '') {
                $transaction->idempotency_key = $normalizedIdempotencyKey;
                $transaction->saveQuietly();
                $walletIdempotencyKey = $normalizedIdempotencyKey;
            } else {
                if ($existingIdempotency !== '' && $normalizedIdempotencyKey !== '' && $existingIdempotency !== $normalizedIdempotencyKey) {
                    Log::notice('order_payment.wallet_idempotency_mismatch', [
                        'transaction_id' => $transaction->getKey(),
                        'stored_idempotency_key' => $existingIdempotency,
                        'incoming_idempotency_key' => $normalizedIdempotencyKey,
                    ]);
                }

                $walletIdempotencyKey = $existingIdempotency !== ''
                    ? $existingIdempotency
                    : $normalizedIdempotencyKey;
            }


            $currency = strtoupper((string) ($data['currency'] ?? $transaction->currency ?? config('app.currency', 'SAR')));


            return $this->walletService->debit($user, $walletIdempotencyKey, (float) $transaction->amount, [
                'payment_transaction' => $transaction,
                'meta' => array_merge($transaction->meta ?? [], [
                    'order_id' => $transaction->payable_id,
                ]),
                'currency' => $currency,


            ]);
        } catch (RuntimeException $exception) {
            throw ValidationException::withMessages([
                'payment' => $exception->getMessage(),
            ]);
        }
    }


    private function mergeCurrencyMeta(array $meta, Order $order, string $method, float $amount, array $data): array
    {
        if ($method === 'wallet') {
            return $meta;
        }

        $orderCurrency = $this->resolveOrderCurrency($order);
        $paymentCurrency = strtoupper((string) ($data['currency'] ?? $orderCurrency));
        $exchangeRate = isset($data['exchange_rate']) ? (float) $data['exchange_rate'] : null;
        $conversionDifference = isset($data['conversion_difference']) ? (float) $data['conversion_difference'] : null;
        $convertedAmount = isset($data['converted_amount'])
            ? (float) $data['converted_amount']
            : ($paymentCurrency === $orderCurrency ? $amount : null);

        $meta['order_currency'] = $orderCurrency;
        $meta['payment_currency'] = $paymentCurrency;

        if ($exchangeRate !== null) {
            $meta['exchange_rate'] = $exchangeRate;
        }

        if ($conversionDifference !== null) {
            $meta['conversion_difference'] = $conversionDifference;
        }

        if ($convertedAmount !== null) {
            $meta['converted_amount'] = $convertedAmount;
        } else {
            unset($meta['converted_amount']);
        }

        return $meta;
    }


    private function normalizePaymentMethod(?string $method): string
    {
        $normalizedMethod = OrderCheckoutService::normalizePaymentMethod($method);

        if (! is_string($normalizedMethod) || $normalizedMethod === '') {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع غير مدعومة.'),
            ]);
        }

        $normalizedMethod = mb_strtolower($normalizedMethod);


        $this->assertSupportedMethod($normalizedMethod);


        return $normalizedMethod;

    }

    /**
     * @return array<int, string>
     */
    private function expandLegacyMethods(string $method): array
    {
        return array_values(array_unique(array_merge([
            $method,
        ], self::LEGACY_METHOD_ALIASES[$method] ?? [])));
    }


    private function assertWalletCurrencyCompatibility(User $user, Order $order, string $requestedCurrency, bool $allowAccountCreation): string

    {
        $currency = strtoupper($requestedCurrency);
        $orderCurrency = $this->resolveOrderCurrency($order);

        if ($currency !== $orderCurrency) {
            throw ValidationException::withMessages([
                'currency' => __('لا يمكن الدفع بالمحفظة بعملة تختلف عن الطلب.'),
            ]);
        }

        $hasMatchingAccount = $this->walletService->hasAccount($user, $currency);
        $hasAnyAccount = $this->walletService->hasAccount($user);

        if (! $hasMatchingAccount) {
            if ($hasAnyAccount || ! $allowAccountCreation) {
                throw ValidationException::withMessages([
                    'currency' => __('لا تملك المحفظة حساباً بهذه العملة.'),
                ]);
            }
        }

        return $currency;

    }

    private function resolveOrderCurrency(Order $order): string
    {
        $orderCurrency = $order->currency_code ?? $order->currency ?? null;

        return strtoupper((string) ($orderCurrency ?: config('app.currency', 'SAR')));
    }



}
