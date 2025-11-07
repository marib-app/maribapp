<?php

namespace App\Services\Payments;

use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\Order;
use App\Models\User;
use App\Models\ServiceRequest;
use App\Services\DepartmentReportService;
use Illuminate\Database\QueryException;
use Illuminate\Database\UniqueConstraintViolationException;
use App\Support\ManualPayments\TransferDetailsResolver;
use Illuminate\Support\Arr;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Throwable;


class ManualPaymentRequestService
{
    private ?bool $supportsBankNameColumn = null;


    private ?bool $supportsBankAccountNameColumn = null;



    private ?string $manualPaymentRequestConnection = null;

    private bool $manualPaymentRequestConnectionResolved = false;

    private bool $defaultManualBankResolved = false;

    private ?ManualBank $defaultManualBank = null;

    




    public function findOpenManualPaymentRequestForPayable(string $payableType, ?int $payableId): ?ManualPaymentRequest
    {
        if ($payableId === null || trim($payableType) === '') {
            return null;
        }

        return ManualPaymentRequest::query()
            ->where('payable_type', $payableType)
            ->where('payable_id', $payableId)
            ->whereIn('status', ManualPaymentRequest::OPEN_STATUSES)
            ->orderByDesc('id')
            ->first();
    }


    /**
     * @param array<string, mixed> $data
     */
    public function createOrUpdateForManualTransaction(
        User $user,
        string $payableType,
        ?int $payableId,
        PaymentTransaction $transaction,
        array $data = []
    ): ManualPaymentRequest {
        $manualBankId = $this->normalizeManualBankIdentifier(
            Arr::get($data, 'bank_id') ?? Arr::get($data, 'manual_bank_id')
        );
        $bankAccountId = Arr::get($data, 'bank_account_id');
        $reference = Arr::get($data, 'reference');
        $note = Arr::get($data, 'note');

        $metadata = Arr::get($data, 'metadata');
        if (! is_array($metadata)) {
            $metadata = null;
        }

        $manualBank = null;
        $supportsBankNameColumn = $this->manualPaymentSupportsBankNameColumn();
        $supportsBankAccountNameColumn = $this->manualPaymentSupportsBankAccountNameColumn();

        if ($manualBankId !== null) {
            $manualBank = ManualBank::query()->find($manualBankId);
        }


        if (! $manualBank) {
            throw ValidationException::withMessages([
                'manual_bank_id' => __('الرجاء اختيار الحساب البنكي للتحويل اليدوي.'),
            ]);
        }

        $serviceRequestId = $this->resolveServiceRequestId($payableType, $payableId);

        $metaUpdates = [
            'source' => 'payments.manual',
            'idempotency_key' => $transaction->idempotency_key,
            'transaction' => array_filter([
                'id' => $transaction->getKey(),
                'amount' => $transaction->amount !== null ? (float) $transaction->amount : null,
                'currency' => $transaction->currency,
                'status' => $transaction->payment_status,
            ], static fn ($value) => $value !== null && $value !== ''),
            'submitted_at' => now()->toIso8601String(),
        ];

        if ($manualBank instanceof ManualBank) {
            $normalizedManualBankId = $manualBank->getKey();
            data_set($metaUpdates, 'bank.id', $normalizedManualBankId);
            data_set($metaUpdates, 'manual_bank.id', $normalizedManualBankId);
        }

        if ($bankAccountId) {
            data_set($metaUpdates, 'bank.account_id', $bankAccountId);
        }

        $storeGatewayAccountId = Arr::get($data, 'store_gateway_account_id');
        if ($storeGatewayAccountId !== null) {
            data_set($metaUpdates, 'store_gateway_account.id', (int) $storeGatewayAccountId);
        }

        $storeGatewayAccountSnapshot = Arr::get($data, 'store_gateway_account');
        if (is_array($storeGatewayAccountSnapshot) && $storeGatewayAccountSnapshot !== []) {
            data_set($metaUpdates, 'store_gateway_account.snapshot', $storeGatewayAccountSnapshot);
        }

        $storeSnapshot = Arr::get($data, 'store');
        if (is_array($storeSnapshot) && $storeSnapshot !== []) {
            data_set($metaUpdates, 'store', $storeSnapshot);
        }


        if ($manualBank) {
            $normalizedBankName = $manualBank->name !== null ? trim((string) $manualBank->name) : null;
            $normalizedBeneficiary = $manualBank->beneficiary_name !== null
                ? trim((string) $manualBank->beneficiary_name)
                : null;

            if ($normalizedBankName !== null && $normalizedBankName !== '') {
                data_set($metaUpdates, 'bank.name', $normalizedBankName);
                data_set($metaUpdates, 'manual_bank.name', $normalizedBankName);
            }

            if ($normalizedBeneficiary !== null && $normalizedBeneficiary !== '') {
                data_set($metaUpdates, 'bank.beneficiary_name', $normalizedBeneficiary);
                data_set($metaUpdates, 'manual_bank.beneficiary_name', $normalizedBeneficiary);
            }
        }



        if ($reference) {
            $metaUpdates['reference'] = $reference;
        }

        if ($note) {
            $metaUpdates['note'] = $note;
        }



        $existingRequest = null;


        if ($transaction->manual_payment_request_id) {
            $existingRequest = ManualPaymentRequest::query()
                ->lockForUpdate()
                ->find($transaction->manual_payment_request_id);
        }


        $department = $this->determineDepartmentForOrderPayable($payableType, $payableId, $existingRequest);


        $duplicateRequest = null;

        if ($payableId !== null && $payableType !== '') {
            $duplicateRequest = ManualPaymentRequest::query()
                ->lockForUpdate()
                ->where('payable_type', $payableType)
                ->where('payable_id', $payableId)
                ->whereIn('status', ManualPaymentRequest::OPEN_STATUSES)
                ->when(
                    $existingRequest,
                    static fn ($query) => $query->whereKeyNot($existingRequest->getKey())
                )
                ->first();
        }

        if ($duplicateRequest !== null) {
            throw ValidationException::withMessages([
                'manual_payment_request' => trans('manual_payment_request_already_open', [
                    'id' => $duplicateRequest->getKey(),
                ]),
            ]);
        }



        $receiptPath = $this->resolveReceiptPath($data, $existingRequest);
        $attachments = $this->normalizeAttachments(Arr::get($data, 'attachments'), $receiptPath);

        if ($existingRequest === null && $receiptPath === '') {
            throw ValidationException::withMessages([
                'receipt' => __('يُرجى إرفاق إيصال التحويل.'),
            ]);
        }

        if (!empty($attachments)) {
            $metaUpdates['attachments'] = $attachments;
        }

        if ($receiptPath !== null && $receiptPath !== '') {
            $metaUpdates['receipt'] = array_filter([
                'path' => $receiptPath,
                'disk' => 'public',
            ], static fn ($value) => $value !== null && $value !== '');
        }

        if ($metadata) {
            $metaUpdates['metadata'] = $metadata;
        }


        if ($existingRequest) {
            $mergedMeta = $existingRequest->meta ?? [];
            if (! is_array($mergedMeta)) {
                $mergedMeta = [];
            }

            $mergedMeta = array_replace_recursive($mergedMeta, $metaUpdates);

            if ($storeId !== null && $existingRequest->store_id !== $storeId) {
                $existingRequest->store_id = $storeId;
            }

            $existingRequest->fill([
                'manual_bank_id' => $manualBank?->getKey(),
                'payable_type' => $payableType,
                'payable_id' => $payableId,
                'service_request_id' => $serviceRequestId,
                'amount' => $transaction->amount,
                'currency' => $transaction->currency,
                'reference' => $reference ?? $existingRequest->reference,
                'user_note' => $note ?? $existingRequest->user_note,
                'status' => ManualPaymentRequest::STATUS_PENDING,
                'receipt_path' => $receiptPath !== '' ? $receiptPath : ($existingRequest->receipt_path ?? ''),
                'department' => $department,
                'payment_transaction_id' => $transaction->getKey(),


            ]);

            if ($manualBank) {
                if ($supportsBankNameColumn) {
                    $existingRequest->bank_name = $manualBank->name;
                }

                if ($supportsBankAccountNameColumn) {
                    $existingRequest->bank_account_name = $manualBank->beneficiary_name;
                }

            }

            $existingRequest->meta = empty($mergedMeta) ? null : $mergedMeta;
            $existingRequest->save();

            return $existingRequest;
        }

        $attributes = [
            'user_id' => $user->getKey(),
            'manual_bank_id' => $manualBank?->getKey(),
            'payable_type' => $payableType,
            'payable_id' => $payableId,
            'store_id' => $storeId,
            'service_request_id' => $serviceRequestId,
            'amount' => $transaction->amount,
            'currency' => $transaction->currency,
            'reference' => $reference,
            'user_note' => $note,
            'status' => ManualPaymentRequest::STATUS_PENDING,
            'meta' => empty($metaUpdates) ? null : $metaUpdates,
            'receipt_path' => $receiptPath,
            'department' => $department,
            'payment_transaction_id' => $transaction->getKey(),

        ];

        if ($manualBank && $supportsBankNameColumn) {

            $attributes['bank_name'] = $manualBank->name;
        }

        if ($manualBank && $supportsBankAccountNameColumn) {
            $attributes['bank_account_name'] = $manualBank->beneficiary_name;
        }



        return ManualPaymentRequest::create($attributes);
    }




    /**
     * Create a minimal manual payment request associated with a payment transaction.
     *
     * @param array<string, mixed> $data
     */
    public function createFromTransaction(
        User $user,
        string $payableType,
        ?int $payableId,
        PaymentTransaction $transaction,
        array $data = []
    ): ManualPaymentRequest {
        $normalizeString = static function ($value): ?string {
            if (! is_string($value)) {
                return null;
            }

            $trimmed = trim($value);

            return $trimmed === '' ? null : $trimmed;
        };

        $manualBankId = $this->normalizeManualBankIdentifier(
            Arr::get($data, 'manual_bank_id') ?? Arr::get($data, 'bank_id')
        );
        $manualBank = null;

        if ($manualBankId !== null) {
            $manualBank = ManualBank::query()->find($manualBankId);

            if (! $manualBank instanceof ManualBank) {
                $manualBankId = null;
            }
        }

        if (! $manualBank instanceof ManualBank && $manualBankId === null) {
            $manualBank = $this->resolveDefaultManualBank();

            if ($manualBank instanceof ManualBank) {
                $manualBankId = $manualBank->getKey();
            }
        }

        $supportsBankNameColumn = $this->manualPaymentSupportsBankNameColumn();
        $supportsBankAccountNameColumn = $this->manualPaymentSupportsBankAccountNameColumn();


        $bankName = $normalizeString(Arr::get($data, 'bank.name'))
            ?? $normalizeString(Arr::get($data, 'bank_name'));

        if ($bankName === null && $manualBank) {
            $bankName = $normalizeString($manualBank->name);
        }


        $currency = $normalizeString(Arr::get($data, 'currency'))
            ?? $normalizeString($transaction->currency);

        $reference = $normalizeString(Arr::get($data, 'reference'));
        $userNote = $normalizeString(Arr::get($data, 'note'));
        $receiptPath = $normalizeString(Arr::get($data, 'receipt_path'));

        $meta = Arr::get($data, 'meta');

        if (! is_array($meta)) {
            $meta = [];
        }

        $gateway = $normalizeString(Arr::get($data, 'payment_gateway')) ?? 'manual_bank';
        data_set($meta, 'gateway', $gateway);

        if ($bankName !== null) {
            data_set($meta, 'bank.name', $bankName);
            data_set($meta, 'manual_bank.name', $bankName);
        }

        $beneficiaryName = null;



        $idempotencyKey = $normalizeString(Arr::get($data, 'idempotency_key'))
            ?? $normalizeString($transaction->idempotency_key);

        if ($idempotencyKey !== null) {
            data_set($meta, 'idempotency_key', $idempotencyKey);
        }

        data_set($meta, 'source', Arr::get($data, 'source', 'payments.manual'));

        $transactionMeta = array_filter([
            'id' => $transaction->getKey(),
            'amount' => $transaction->amount !== null ? (float) $transaction->amount : null,
            'currency' => $transaction->currency,
            'status' => $transaction->payment_status,
        ], static fn ($value) => $value !== null && $value !== '');

        if ($transactionMeta !== []) {
            data_set($meta, 'transaction', $transactionMeta);
        }




        if ($manualBank instanceof ManualBank) {
            data_set($meta, 'bank.id', $manualBank->getKey());
            data_set($meta, 'manual_bank.id', $manualBank->getKey());
        }

        if ($bankName !== null) {
            data_set($meta, 'bank.name', $bankName);
            data_set($meta, 'manual_bank.name', $bankName);
        }

        if ($manualBank && $manualBank->beneficiary_name) {
            $beneficiaryName = $normalizeString($manualBank->beneficiary_name);

            if ($beneficiaryName !== null) {
                data_set($meta, 'bank.beneficiary_name', $beneficiaryName);
                data_set($meta, 'manual_bank.beneficiary_name', $beneficiaryName);
            }
        }

        $storeGatewayAccountId = Arr::get($data, 'store_gateway_account_id');
        if ($storeGatewayAccountId !== null) {
            data_set($meta, 'store_gateway_account.id', (int) $storeGatewayAccountId);
        }

        $storeGatewayAccountSnapshot = Arr::get($data, 'store_gateway_account');
        if (is_array($storeGatewayAccountSnapshot) && $storeGatewayAccountSnapshot !== []) {
            data_set($meta, 'store_gateway_account.snapshot', $storeGatewayAccountSnapshot);
        }

        $storeSnapshot = Arr::get($data, 'store');
        if (is_array($storeSnapshot) && $storeSnapshot !== []) {
            data_set($meta, 'store', $storeSnapshot);
        }


        $meta = $this->filterArrayRecursive($meta);

        $department = $this->determineDepartmentForOrderPayable($payableType, $payableId, null);
        $serviceRequestId = $this->resolveServiceRequestId($payableType, $payableId);
        $storeId = $this->resolveStoreIdForPayable($payableType, $payableId);

        $attributes = [
            'user_id' => $user->getKey(),
            'manual_bank_id' => $manualBank?->getKey(),
            'payable_type' => $payableType,
            'payable_id' => $payableId,
            'store_id' => $storeId,
            'service_request_id' => $serviceRequestId,
            'amount' => $transaction->amount,
            'currency' => $currency ?? $transaction->currency,
            'reference' => $reference,
            'user_note' => $userNote,
            'receipt_path' => $receiptPath,
            'status' => ManualPaymentRequest::STATUS_PENDING,
            'department' => $department,
            'meta' => $meta === [] ? null : $meta,
            'payment_transaction_id' => $transaction->getKey(),


        ];


        if ($supportsBankNameColumn && $bankName !== null) {
            $attributes['bank_name'] = $bankName;
        }

        if ($supportsBankAccountNameColumn && $beneficiaryName !== null) {
            $attributes['bank_account_name'] = $beneficiaryName;
        }


        $filteredAttributes = array_filter(
            $attributes,
            static function ($value) {
                if (is_array($value)) {
                    return true;
                }

                return $value !== null && $value !== '';
            }
        );

        if ($payableType && $payableId) {
            $existingOpen = $this->findOpenManualPaymentRequestForPayable($payableType, $payableId);

            if ($existingOpen instanceof ManualPaymentRequest) {
                $existingOpen->fill($filteredAttributes);
                $existingOpen->payment_transaction_id = $transaction->getKey();
                $existingOpen->status = ManualPaymentRequest::STATUS_PENDING;
                if ($storeId !== null && $existingOpen->store_id !== $storeId) {
                    $existingOpen->store_id = $storeId;
                }
                $existingOpen->save();

                return $existingOpen;
            }
        }

        try {
            return ManualPaymentRequest::create($filteredAttributes);
        } catch (QueryException $exception) {
            if ($this->isDuplicateManualPaymentRequestException($exception, $payableType, $payableId)) {
                $conflicting = $this->findOpenManualPaymentRequestForPayable($payableType, $payableId);
                if ($conflicting instanceof ManualPaymentRequest) {
                    return $conflicting;
                }
            }

            throw $exception;
        }
    }






    /**
     * Ensure that a payment transaction processed via manual bank gateway has a corresponding manual payment request.
     *
     * @param array<string, mixed> $data
     */
    public function ensureManualPaymentRequestForTransaction(
        PaymentTransaction $transaction,
        array $data = []
    ): ?ManualPaymentRequest {
        $gateway = ManualPaymentRequest::canonicalGateway($transaction->payment_gateway);

        if ($gateway !== 'manual_banks' && $gateway !== 'manual_bank') {
            return null;
        }

        if ($transaction->manual_payment_request_id) {
            return $transaction->manualPaymentRequest instanceof ManualPaymentRequest
                ? $transaction->manualPaymentRequest
                : ManualPaymentRequest::query()->find($transaction->manual_payment_request_id);
        }

        $user = $transaction->relationLoaded('user') ? $transaction->getRelation('user') : null;

        if (! $user instanceof User) {
            $user = $transaction->user()->first();
        }

        if (! $user instanceof User) {
            Log::warning('Unable to backfill manual payment request without associated user.', [
                'payment_transaction_id' => $transaction->getKey(),
            ]);

            return null;
        }

        $normalizeString = static function ($value): ?string {
            if (! is_string($value)) {
                return null;
            }

            $trimmed = trim($value);

            return $trimmed === '' ? null : $trimmed;
        };

        $meta = $transaction->meta;
        if (! is_array($meta)) {
            $meta = [];
        }

        $manualMeta = Arr::get($meta, 'manual');
        if (! is_array($manualMeta)) {
            $manualMeta = [];
        }

        $manualRequestMeta = Arr::get($meta, 'manual_payment_request');
        if (! is_array($manualRequestMeta)) {
            $manualRequestMeta = [];
        }


        $skippedReason = $normalizeString(Arr::get($manualRequestMeta, 'skipped.reason'));

        if ($skippedReason !== null && in_array($skippedReason, ['missing_manual_bank', 'manual_request_already_linked'], true)) {
            return null;
        }



        $walletMeta = Arr::get($meta, 'wallet');
        if (! is_array($walletMeta)) {
            $walletMeta = [];
        }

        $manualBankId = Arr::get($data, 'manual_bank_id')
            ?? Arr::get($manualMeta, 'bank.id')
            ?? Arr::get($manualMeta, 'manual_bank.id')
            ?? Arr::get($manualMeta, 'bank_id')
            ?? Arr::get($manualMeta, 'manual_bank_id')
            ?? Arr::get($manualRequestMeta, 'manual_bank_id')
            ?? Arr::get($manualRequestMeta, 'bank_id');

        if (is_string($manualBankId)) {
            $manualBankId = trim($manualBankId);
        }

        if ($manualBankId !== null && $manualBankId !== '') {
            $manualBankId = (int) $manualBankId;

            if ($manualBankId <= 0) {
                $manualBankId = null;
            }
        } else {
            $manualBankId = null;
        }

        $bankNameCandidates = [
            Arr::get($data, 'bank.name'),
            Arr::get($data, 'bank_name'),
            Arr::get($manualMeta, 'bank.name'),
            Arr::get($manualMeta, 'bank.bank_name'),
            Arr::get($manualMeta, 'bank.beneficiary_name'),
            Arr::get($manualMeta, 'manual_bank.name'),
            Arr::get($manualMeta, 'manual_bank.bank_name'),
            Arr::get($manualMeta, 'manual_bank.beneficiary_name'),
            Arr::get($manualRequestMeta, 'bank.name'),
            Arr::get($manualRequestMeta, 'manual_bank.name'),
            Arr::get($manualRequestMeta, 'bank.bank_name'),
            Arr::get($manualRequestMeta, 'manual_bank.bank_name'),
            Arr::get($manualRequestMeta, 'bank.beneficiary_name'),
            Arr::get($manualRequestMeta, 'manual_bank.beneficiary_name'),
        ];

        $bankName = null;

        foreach ($bankNameCandidates as $candidate) {
            $normalized = $normalizeString($candidate);

            if ($normalized !== null) {
                $bankName = $normalized;
                break;
            }
        }

        $manualBankMissing = false;



        $manualBank = $manualBankId !== null
            ? ManualBank::query()->find($manualBankId)
            : null;



        if (! $manualBank instanceof ManualBank && $manualBankId === null && $bankName === null) {
            $manualBank = $this->resolveDefaultManualBank();

            if ($manualBank instanceof ManualBank) {
                $manualBankId = $manualBank->getKey();
                $bankName = $normalizeString($manualBank->name) ?? $bankName;
            }
        }


        if (! $manualBank instanceof ManualBank && $bankName !== null) {
            $normalizedBankName = Str::of($bankName)->trim()->lower()->value();

            if ($normalizedBankName !== '') {
                $manualBank = ManualBank::query()
                    ->whereRaw('LOWER(TRIM(name)) = ?', [$normalizedBankName])
                    ->orWhereRaw('LOWER(TRIM(beneficiary_name)) = ?', [$normalizedBankName])
                    ->first();
            }
        }

        if (! $manualBank instanceof ManualBank) {
            $manualBankMissing = $manualBankId !== null || $bankName !== null;
            $manualBankId = null;
        } else {
            $manualBankId = $manualBank->getKey();

            if ($bankName === null) {
                $bankName = $normalizeString($manualBank->name);
            }


        }

        $supportsBankNameColumn = $this->manualPaymentSupportsBankNameColumn();
        $supportsBankAccountNameColumn = $this->manualPaymentSupportsBankAccountNameColumn();


        $bankBeneficiary = $manualBank instanceof ManualBank && $manualBank->beneficiary_name
            ? $normalizeString($manualBank->beneficiary_name)
            : null;

        $reference = $normalizeString(Arr::get($data, 'reference'))
            ?? $normalizeString(Arr::get($manualMeta, 'reference'))
            ?? $normalizeString(Arr::get($manualRequestMeta, 'reference'));

        $note = $normalizeString(Arr::get($data, 'note'))
            ?? $normalizeString(Arr::get($manualMeta, 'note'))
            ?? $normalizeString(Arr::get($manualRequestMeta, 'note'))
            ?? $normalizeString(Arr::get($manualRequestMeta, 'user_note'));

        $receiptPath = $normalizeString(Arr::get($data, 'receipt_path'))
            ?? $normalizeString(Arr::get($manualMeta, 'receipt.path'))
            ?? $normalizeString(Arr::get($manualMeta, 'receipt_path'))
            ?? $normalizeString(Arr::get($manualRequestMeta, 'receipt.path'))
            ?? $normalizeString(Arr::get($manualRequestMeta, 'receipt_path'));

        $transactionPayableType = $normalizeString(Arr::get($manualRequestMeta, 'payable_type'))
            ?? $normalizeString($transaction->payable_type);

        $payableId = Arr::get($manualRequestMeta, 'payable_id', $transaction->payable_id);

        if ($payableId !== null && ! is_int($payableId)) {
            $payableId = is_numeric($payableId) ? (int) $payableId : null;
        }

        if ($transactionPayableType === null) {
            $orderId = $normalizeString((string) $transaction->order_id);

            if ($orderId !== null && is_numeric($orderId)) {
                $transactionPayableType = Order::class;
                $payableId = (int) $orderId;
            }
        }

        $walletPurpose = $normalizeString(Arr::get($walletMeta, 'purpose'));

        if ($walletPurpose === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            $transactionPayableType = ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP;
        }

        if ($transaction->payableIsWalletTransaction()) {
            $transactionPayableType = ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP;
            $payableId = $transaction->payable_id !== null ? (int) $transaction->payable_id : null;
        }

        if ($transactionPayableType === null) {
            $transactionPayableType = ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP;
        }

        if ($transactionPayableType === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            $payableId = $payableId !== null ? (int) $payableId : null;
        }

        $existingRequest = $transaction->relationLoaded('manualPaymentRequest')
            ? $transaction->getRelation('manualPaymentRequest')
            : null;

        if (! $existingRequest instanceof ManualPaymentRequest) {
            $metaRequestId = Arr::get($manualRequestMeta, 'id');

            if (is_numeric($metaRequestId)) {
                $existingRequest = ManualPaymentRequest::query()->find((int) $metaRequestId);
            }
        }

        if (! $existingRequest instanceof ManualPaymentRequest) {
            $existingRequest = ManualPaymentRequest::query()
                ->where('payment_transaction_id', $transaction->getKey())
                ->first();
        }

        if (! $existingRequest instanceof ManualPaymentRequest && $payableId !== null) {
            $existingRequest = ManualPaymentRequest::query()
                ->where('user_id', $transaction->user_id)
                ->where('payable_id', $payableId)
                ->where('payable_type', $transactionPayableType)
                ->orderByDesc('id')
                ->first();
        }



        if ($existingRequest instanceof ManualPaymentRequest) {
            $linkedTransactionId = $existingRequest->payment_transaction_id;

            if ($linkedTransactionId === null) {
                $linkedTransactionId = PaymentTransaction::query()
                    ->where('manual_payment_request_id', $existingRequest->getKey())
                    ->value('id');
            }

            if ($linkedTransactionId !== null && $linkedTransactionId !== $transaction->getKey()) {
                if (! $manualBank instanceof ManualBank) {
                    $candidateManualBank = $existingRequest->relationLoaded('manualBank')
                        ? $existingRequest->getRelation('manualBank')
                        : $existingRequest->manualBank;

                    if ($candidateManualBank instanceof ManualBank) {
                        $manualBank = $candidateManualBank;
                        $manualBankId = $manualBank->getKey();
                        $manualBankMissing = false;

                        if ($bankName === null) {
                            $bankName = $normalizeString($manualBank->name);
                        }

                        if ($bankBeneficiary === null && $manualBank->beneficiary_name) {
                            $bankBeneficiary = $normalizeString($manualBank->beneficiary_name);
                        }
                    }
                }

                Log::info('Manual payment request already linked to a different transaction. Skipping reuse.', [
                    'payment_transaction_id' => $transaction->getKey(),
                    'manual_payment_request_id' => $existingRequest->getKey(),
                    'existing_payment_transaction_id' => $linkedTransactionId,
                ]);

                $existingRequest = null;
            }
        }



        if ($manualBankMissing && $existingRequest instanceof ManualPaymentRequest) {
            $existingManualBank = $existingRequest->relationLoaded('manualBank')
                ? $existingRequest->getRelation('manualBank')
                : $existingRequest->manualBank;

            if ($existingManualBank instanceof ManualBank) {
                $manualBank = $existingManualBank;
                $manualBankId = $manualBank->getKey();
                $manualBankMissing = false;

                if ($bankName === null) {
                    $bankName = $normalizeString($manualBank->name);
                }

                if ($bankBeneficiary === null && $manualBank->beneficiary_name) {
                    $bankBeneficiary = $normalizeString($manualBank->beneficiary_name);
                }
            }
        }


        $autoLinkedAt = now()->toIso8601String();

        $buildPayload = function () use (
            &$manualMeta,
            &$data,
            $transaction,
            &$manualBankId,
            &$bankName,
            &$bankBeneficiary,
            &$reference,
            &$note,
            &$receiptPath,
            $autoLinkedAt
        ): array {
            $metaPayload = [];

            if ($manualMeta !== []) {
                $metaPayload = array_replace_recursive($metaPayload, $manualMeta);
            }

            $providedMeta = Arr::get($data, 'meta');

            if (is_array($providedMeta)) {
                $metaPayload = array_replace_recursive($metaPayload, $providedMeta);
            }

            $transactionMetaPayload = array_filter([
                'id' => $transaction->getKey(),
                'amount' => $transaction->amount !== null ? (float) $transaction->amount : null,
                'currency' => $transaction->currency,
                'status' => $transaction->payment_status,
                'created_at' => $transaction->created_at?->toIso8601String(),
            ], static fn ($value) => $value !== null && $value !== '');

            if ($transactionMetaPayload !== []) {
                data_set($metaPayload, 'transaction', $transactionMetaPayload);
            }

            data_set($metaPayload, 'source', Arr::get($manualMeta, 'source', 'auto-from-transaction'));
            data_set($metaPayload, 'auto_linked_at', $autoLinkedAt);

            if ($manualBankId !== null) {
                data_set($metaPayload, 'bank.id', $manualBankId);
                data_set($metaPayload, 'manual_bank.id', $manualBankId);
            }

            if ($bankName !== null) {
                data_set($metaPayload, 'bank.name', $bankName);
                data_set($metaPayload, 'manual_bank.name', $bankName);
            }

            if ($bankBeneficiary !== null) {
                data_set($metaPayload, 'bank.beneficiary_name', $bankBeneficiary);
                data_set($metaPayload, 'manual_bank.beneficiary_name', $bankBeneficiary);
            }

            $metaPayload = $this->filterArrayRecursive($metaPayload);

            $payload = array_filter([
                'payment_gateway' => $transaction->payment_gateway,
                'currency' => $transaction->currency,
                'reference' => $reference,
                'note' => $note,
                'manual_bank_id' => $manualBankId,
                'receipt_path' => $receiptPath,
                'meta' => $metaPayload,
            ], static fn ($value) => $value !== null && $value !== '');

            if ($bankName !== null) {
                $payload['bank'] = ['name' => $bankName];
            }

            return [$payload, $metaPayload];
        };

        [$payload, $metaPayload] = $buildPayload();

        
        $manualPaymentRequest = $existingRequest;

        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            if ($manualBankMissing && $manualBankId === null) {
                $providedManualBankId = Arr::get($data, 'manual_bank_id')
                    ?? Arr::get($manualMeta, 'manual_bank.id')
                    ?? Arr::get($manualRequestMeta, 'manual_bank_id')
                    ?? Arr::get($manualRequestMeta, 'bank_id');



                Log::warning('Unable to determine manual bank while creating manual payment request from transaction.', [
                    'payment_transaction_id' => $transaction->getKey(),
                    'provided_manual_bank_id' => $providedManualBankId,

                    'provided_manual_bank_name' => $bankName,
                ]);

                $this->markTransactionManualPaymentRequestSkipped(
                    $transaction,
                    'missing_manual_bank',
                    [
                        'manual_bank_id' => is_scalar($providedManualBankId) ? (string) $providedManualBankId : null,
                        'manual_bank_name' => $bankName,
                    ]
                );

                return null;
            }

            try {
                $manualPaymentRequest = $this->createFromTransaction(
                    $user,
                    $transactionPayableType,
                    $payableId,
                    $transaction,
                    $payload
                );
            } catch (Throwable $exception) {
                if (! $this->isManualPaymentRequestDuplicateKeyException($exception) || $payableId === null) {
                    throw $exception;
                }

                $manualPaymentRequest = $this->findOpenManualPaymentRequestForPayable(
                    $transactionPayableType,
                    $payableId
                );

                if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
                    throw $exception;
                }
            }

            if (! $manualBank instanceof ManualBank) {
                $candidateManualBank = $manualPaymentRequest->relationLoaded('manualBank')
                    ? $manualPaymentRequest->getRelation('manualBank')
                    : $manualPaymentRequest->manualBank;

                if ($candidateManualBank instanceof ManualBank) {
                    $manualBank = $candidateManualBank;
                    $manualBankId = $manualBank->getKey();
                    $manualBankMissing = false;

                    if ($bankName === null) {
                        $bankName = $normalizeString($manualBank->name);
                    }

                    if ($bankBeneficiary === null && $manualBank->beneficiary_name) {
                        $bankBeneficiary = $normalizeString($manualBank->beneficiary_name);
                    }
                }
            }
        }

        if ($manualPaymentRequest instanceof ManualPaymentRequest && $manualBankId === null && $manualPaymentRequest->manual_bank_id !== null) {
            $manualBankId = (int) $manualPaymentRequest->manual_bank_id;
        }

        if (! $manualBank instanceof ManualBank) {
            $candidateManualBank = $manualPaymentRequest instanceof ManualPaymentRequest
                ? ($manualPaymentRequest->relationLoaded('manualBank')
                    ? $manualPaymentRequest->getRelation('manualBank')
                    : $manualPaymentRequest->manualBank)
                : null;

            if ($candidateManualBank instanceof ManualBank) {
                $manualBank = $candidateManualBank;
                $manualBankMissing = false;
            }
        }


        [$payload, $metaPayload] = $buildPayload();


        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            return null;
        }

        $existingMeta = $manualPaymentRequest->meta;


        if (! is_array($existingMeta)) {
            $existingMeta = [];
        }

        $mergedMeta = $this->filterArrayRecursive(array_replace_recursive($existingMeta, $metaPayload));


        $existingLinkedTransactionId = $this->manualPaymentRequestLinkedTransactionId($manualPaymentRequest);
        $currentTransactionId = $this->normalizeNullableId($transaction->getKey());

        if ($existingLinkedTransactionId !== null && $currentTransactionId !== null && $existingLinkedTransactionId !== $currentTransactionId) {
            Log::warning('Manual payment request already linked to a different transaction. Skipping linkage to prevent duplicate association.', [
                'payment_transaction_id' => $transaction->getKey(),
                'manual_payment_request_id' => $manualPaymentRequest->getKey(),
                'existing_payment_transaction_id' => $existingLinkedTransactionId,
            ]);

            $this->markTransactionManualPaymentRequestSkipped($transaction, 'manual_request_already_linked', [
                'manual_payment_request_id' => (string) $manualPaymentRequest->getKey(),
                'existing_payment_transaction_id' => (string) $existingLinkedTransactionId,
            ]);

            return null;
        }


        $manualPaymentRequest->forceFill(array_filter([
            'manual_bank_id' => $manualBank?->getKey() ?? $manualBankId,
            'payable_type' => $transactionPayableType,
            'payable_id' => $payableId,
            'amount' => $transaction->amount,
            'currency' => $transaction->currency,
            'reference' => $reference ?? $manualPaymentRequest->reference,
            'user_note' => $note ?? $manualPaymentRequest->user_note,
            'receipt_path' => $receiptPath ?? $manualPaymentRequest->receipt_path,
            'payment_transaction_id' => $transaction->getKey(),
        ], static fn ($value) => $value !== null && $value !== ''));

        if ($supportsBankNameColumn && $bankName !== null) {


            $manualPaymentRequest->bank_name = $bankName;
        }

        if ($supportsBankAccountNameColumn && $bankBeneficiary !== null) {


            $manualPaymentRequest->bank_account_name = $bankBeneficiary;
        }

        $manualPaymentRequest->meta = $mergedMeta === [] ? null : $mergedMeta;
        $manualPaymentRequest->saveQuietly();

        $manualPaymentRequest = $manualPaymentRequest->fresh();


        $transactionMeta = $transaction->meta;

        if (! is_array($transactionMeta)) {
            $transactionMeta = [];
        }

        $transactionMeta = array_replace_recursive($transactionMeta, [
            'manual_payment_request' => array_filter([
                'id' => $manualPaymentRequest->getKey(),
                'status' => $manualPaymentRequest->status,
            ], static fn ($value) => $value !== null && $value !== ''),
        ]);

        if ($manualBankId !== null) {
            data_set($transactionMeta, 'manual.bank.id', $manualBankId);
            data_set($transactionMeta, 'manual_bank.id', $manualBankId);
        }

        if ($bankName !== null) {
            data_set($transactionMeta, 'manual.bank.name', $bankName);
            data_set($transactionMeta, 'manual.bank.bank_name', $bankName);
            data_set($transactionMeta, 'manual_bank.name', $bankName);
        }

        if ($bankBeneficiary !== null) {
            data_set($transactionMeta, 'manual.bank.beneficiary_name', $bankBeneficiary);
            data_set($transactionMeta, 'manual_bank.beneficiary_name', $bankBeneficiary);
        }

        $transactionAttributes = [
            'meta' => $this->filterArrayRecursive($transactionMeta),
        ];

        if ($this->normalizeNullableId($transaction->manual_payment_request_id) !== $manualPaymentRequest->getKey()) {
            $transactionAttributes['manual_payment_request_id'] = $manualPaymentRequest->getKey();
        }

        try {
            $transaction->forceFill($transactionAttributes)->saveQuietly();
        } catch (QueryException|UniqueConstraintViolationException $exception) {
            if ($this->isPaymentTransactionManualPaymentDuplicateException($exception)) {
                $existingLinkedTransactionId = $this->manualPaymentRequestLinkedTransactionId($manualPaymentRequest);

                Log::warning('Manual payment request already linked to a different transaction. Skipping linkage to prevent duplicate association.', [
                    'payment_transaction_id' => $transaction->getKey(),
                    'manual_payment_request_id' => $manualPaymentRequest->getKey(),
                    'existing_payment_transaction_id' => $existingLinkedTransactionId,
                ]);

                $this->markTransactionManualPaymentRequestSkipped($transaction, 'manual_request_already_linked', [
                    'manual_payment_request_id' => (string) $manualPaymentRequest->getKey(),
                    'existing_payment_transaction_id' => $existingLinkedTransactionId !== null ? (string) $existingLinkedTransactionId : null,
                ]);

                return $manualPaymentRequest->fresh();
            }

            throw $exception;
        }

        $transaction->refresh();
        $manualPaymentRequest->setRelation('paymentTransaction', $transaction);

        $this->syncTransactionManualBankPayload($transaction, $manualPaymentRequest);

        return $this->syncTransferDetails($manualPaymentRequest);
    }


    public function syncTransferDetails(ManualPaymentRequest $manualPaymentRequest): ManualPaymentRequest
    {
        $manualPaymentRequest->loadMissing(['manualBank', 'paymentTransaction.walletTransaction']);

        $transferDetails = TransferDetailsResolver::forManualPaymentRequest($manualPaymentRequest)->toArray();

        $meta = $manualPaymentRequest->meta;
        if (! is_array($meta)) {
            $meta = [];
        }


        $transferReferenceValue = $transferDetails['transfer_reference'] ?? null;


        $transferMeta = array_filter([
            'sender_name' => $transferDetails['sender_name'] ?? null,
            'transfer_reference' => $transferReferenceValue,
            'transfer_code' => $transferReferenceValue,
            'note' => $transferDetails['note'] ?? null,
            'receipt_url' => $transferDetails['receipt_url'] ?? null,
            'receipt_path' => $transferDetails['receipt_path'] ?? null,
            'source' => $transferDetails['source'] ?? null,
        ], static fn ($value) => $value !== null && $value !== '');

        $senderName = $transferMeta['sender_name'] ?? null;
        $transferReference = $transferMeta['transfer_reference'] ?? null;
        $note = $transferMeta['note'] ?? null;
        $receiptUrl = $transferMeta['receipt_url'] ?? null;
        $receiptPath = $transferMeta['receipt_path'] ?? null;

        if ($transferMeta !== []) {
            data_set($meta, 'transfer_details', $transferMeta);
            data_set($meta, 'transfer', $transferMeta);
            data_set($meta, 'metadata.transfer_details', $transferMeta);
            data_set($meta, 'metadata.transfer', $transferMeta);
        }

        if ($senderName !== null) {
            data_set($meta, 'manual.sender_name', $senderName);
            data_set($meta, 'manual.metadata.sender_name', $senderName);
            data_set($meta, 'metadata.sender_name', $senderName);
        }

        if ($transferReference !== null) {
            data_set($meta, 'manual.transfer_reference', $transferReference);
            data_set($meta, 'manual.transfer_code', $transferReference);
            data_set($meta, 'manual.metadata.transfer_reference', $transferReference);
            data_set($meta, 'manual.metadata.transfer_code', $transferReference);
            data_set($meta, 'metadata.transfer_reference', $transferReference);
            data_set($meta, 'metadata.transfer_code', $transferReference);
        }

        if ($note !== null) {
            data_set($meta, 'manual.note', $note);
            data_set($meta, 'manual.metadata.note', $note);
            data_set($meta, 'metadata.note', $note);
        }

        if ($receiptUrl !== null) {
            data_set($meta, 'receipt_url', $receiptUrl);
        }

        if ($receiptPath !== null) {
            data_set($meta, 'receipt.path', $receiptPath);
            if (data_get($meta, 'receipt.disk') === null) {
                data_set($meta, 'receipt.disk', 'public');
            }
            data_set($meta, 'receipt_path', $receiptPath);
        }

        $manualPaymentRequest->fill(array_filter([
            'reference' => $transferReference,
            'receipt_path' => $receiptPath,
        ], static fn ($value) => $value !== null && $value !== ''));

        $manualPaymentRequest->meta = $this->filterArrayRecursive($meta);
        $manualPaymentRequest->saveQuietly();

        $transaction = $manualPaymentRequest->paymentTransaction instanceof PaymentTransaction
            ? $manualPaymentRequest->paymentTransaction
            : null;

        if ($transaction instanceof PaymentTransaction) {
            $transactionMeta = $transaction->meta;
            if (! is_array($transactionMeta)) {
                $transactionMeta = [];
            }

            if ($transferMeta !== []) {
                data_set($transactionMeta, 'transfer_details', $transferMeta);
                data_set($transactionMeta, 'manual.transfer_details', $transferMeta);
            }

            if ($senderName !== null) {
                data_set($transactionMeta, 'manual.sender_name', $senderName);
                data_set($transactionMeta, 'manual.metadata.sender_name', $senderName);
            }

            if ($transferReference !== null) {
                data_set($transactionMeta, 'manual.transfer_reference', $transferReference);
                data_set($transactionMeta, 'manual.transfer_code', $transferReference);
                data_set($transactionMeta, 'manual.metadata.transfer_reference', $transferReference);
                data_set($transactionMeta, 'manual.metadata.transfer_code', $transferReference);
            }

            if ($note !== null) {
                data_set($transactionMeta, 'manual.note', $note);
            }

            if ($receiptUrl !== null) {
                data_set($transactionMeta, 'receipt_url', $receiptUrl);
            }

            if ($receiptPath !== null) {
                data_set($transactionMeta, 'receipt.path', $receiptPath);
                if (data_get($transactionMeta, 'receipt.disk') === null) {
                    data_set($transactionMeta, 'receipt.disk', 'public');
                }
                data_set($transactionMeta, 'receipt_path', $receiptPath);
            }

            $transaction->forceFill([
                'meta' => $this->filterArrayRecursive($transactionMeta),
            ])->saveQuietly();

            $walletTransaction = $transaction->walletTransaction;
            if ($walletTransaction instanceof \App\Models\WalletTransaction) {
                $walletMeta = $walletTransaction->meta;
                if (! is_array($walletMeta)) {
                    $walletMeta = [];
                }

                if ($transferMeta !== []) {
                    data_set($walletMeta, 'transfer_details', $transferMeta);
                }

                if ($senderName !== null) {
                    data_set($walletMeta, 'sender_name', $senderName);
                    data_set($walletMeta, 'metadata.sender_name', $senderName);
                }

                if ($transferReference !== null) {
                    data_set($walletMeta, 'transfer_reference', $transferReference);
                    data_set($walletMeta, 'transfer_code', $transferReference);
                    data_set($walletMeta, 'metadata.transfer_reference', $transferReference);
                    data_set($walletMeta, 'metadata.transfer_code', $transferReference);
                }

                if ($note !== null) {
                    data_set($walletMeta, 'note', $note);
                    data_set($walletMeta, 'metadata.note', $note);
                }

                if ($receiptUrl !== null) {
                    data_set($walletMeta, 'receipt_url', $receiptUrl);
                }

                if ($receiptPath !== null) {
                    data_set($walletMeta, 'receipt.path', $receiptPath);
                    if (data_get($walletMeta, 'receipt.disk') === null) {
                        data_set($walletMeta, 'receipt.disk', 'public');
                    }
                    data_set($walletMeta, 'receipt_path', $receiptPath);
                }

                $walletTransaction->forceFill([
                    'meta' => $this->filterArrayRecursive($walletMeta),
                ])->saveQuietly();
            }
        }

        return $manualPaymentRequest->fresh(['manualBank', 'paymentTransaction.walletTransaction']);
    
    }



    private function resolveDefaultManualBank(): ?ManualBank
    {
        if ($this->defaultManualBankResolved) {
            return $this->defaultManualBank;
        }

        $this->defaultManualBankResolved = true;

        $manualBank = null;
        $configuredId = config('payments.default_manual_bank_id');

        if ($configuredId !== null && $configuredId !== '') {
            $normalizedId = is_numeric($configuredId) ? (int) $configuredId : null;

            if ($normalizedId !== null && $normalizedId > 0) {
                try {
                    $manualBank = ManualBank::query()->find($normalizedId);
                } catch (Throwable) {
                    $manualBank = null;
                }
            }
        }

        if (! $manualBank instanceof ManualBank) {
            try {
                $model = new ManualBank();
                $table = $model->getTable();

                if (! Schema::hasTable($table)) {
                    $this->defaultManualBank = null;

                    return null;
                }

                $query = ManualBank::query();

                if (Schema::hasColumn($table, 'status')) {
                    $query->where('status', true);
                } elseif (Schema::hasColumn($table, 'is_active')) {
                    $query->where('is_active', true);
                }

                if (Schema::hasColumn($table, 'display_order')) {
                    $query->orderBy('display_order');
                }

                $manualBank = $query->orderBy('name')->orderBy('id')->first();
            } catch (Throwable) {
                $manualBank = null;
            }
        }

        if (! $manualBank instanceof ManualBank) {
            $this->defaultManualBank = null;

            return null;
        }

        return $this->defaultManualBank = $manualBank;
    }



    private function manualPaymentRequestLinkedTransactionId(ManualPaymentRequest $manualPaymentRequest): ?int
    {
        $linkedId = $this->normalizeNullableId($manualPaymentRequest->payment_transaction_id);

        if ($linkedId !== null) {
            return $linkedId;
        }

        $linkedId = PaymentTransaction::query()
            ->where('manual_payment_request_id', $manualPaymentRequest->getKey())
            ->value('id');

        return $this->normalizeNullableId($linkedId);
    }

    private function normalizeNullableId(int|string|null $value): ?int
    {
        if ($value === null) {
            return null;
        }

        if (is_int($value)) {
            return $value;
        }

        if (is_string($value) && is_numeric($value)) {
            return (int) $value;
        }

        return null;
    }



    private function markTransactionManualPaymentRequestSkipped(
        PaymentTransaction $transaction,
        string $reason,
        array $context = []
    ): void {
        $meta = $transaction->meta;

        if (! is_array($meta)) {
            $meta = [];
        }

        $skipPayload = array_filter([
            'reason' => trim($reason) !== '' ? trim($reason) : null,
            'at' => now()->toIso8601String(),
            'manual_bank_id' => $context['manual_bank_id'] ?? null,
            'manual_bank_name' => $context['manual_bank_name'] ?? null,
            'manual_payment_request_id' => $context['manual_payment_request_id'] ?? null,
            'existing_payment_transaction_id' => $context['existing_payment_transaction_id'] ?? null,
        ], static function ($value) {
            if (is_array($value)) {
                return true;
            }

            return $value !== null && $value !== '';
        });

        if ($skipPayload === []) {
            return;
        }

        $meta = array_replace_recursive($meta, [
            'manual_payment_request' => [
                'skipped' => $skipPayload,
            ],
        ]);

        $filteredMeta = $this->filterArrayRecursive($meta);

        if ($filteredMeta !== $transaction->meta) {
            $transaction->forceFill([
                'meta' => $filteredMeta,
            ])->saveQuietly();
        }
    }

 


    public function syncTransactionManualBankPayload(
        PaymentTransaction $transaction,
        ManualPaymentRequest $manualPaymentRequest
    ): void {
        $meta = $transaction->meta;

        if (! is_array($meta)) {
            $meta = [];
        }

        $manualPaymentRequest->loadMissing('manualBank');

        $manualBank = $manualPaymentRequest->manualBank;
        $manualBankId = $manualBank?->getKey() ?? $manualPaymentRequest->manual_bank_id;

        if (is_string($manualBankId)) {
            $manualBankId = trim($manualBankId);
        }

        if ($manualBankId !== null && $manualBankId !== '') {
            $manualBankId = (int) $manualBankId;

            if ($manualBankId <= 0) {
                $manualBankId = null;
            }
        } else {
            $manualBankId = null;
        }

        $bankNameCandidates = [
            $manualPaymentRequest->bank_name,
            $manualPaymentRequest->bank_account_name,
            $manualBank?->name,
            $manualBank?->beneficiary_name,
            data_get($meta, 'manual.bank.name'),
            data_get($meta, 'manual_bank.name'),
            data_get($meta, 'bank.name'),
        ];

        $bankName = null;

        foreach ($bankNameCandidates as $candidate) {
            if (! is_string($candidate)) {
                continue;
            }

            $trimmed = trim($candidate);

            if ($trimmed === '') {
                continue;
            }

            $bankName = $trimmed;
            break;
        }

        if ($manualBankId !== null) {
            data_set($meta, 'payload.manual_bank_id', $manualBankId);
        }

        if ($bankName !== null) {
            data_set($meta, 'payload.bank_name', $bankName);
        }

        $filteredMeta = $this->filterArrayRecursive($meta);

        if ($filteredMeta !== $transaction->meta) {
            $transaction->forceFill([
                'meta' => $filteredMeta,
            ])->saveQuietly();
        }
    }


    private function resolveStoreIdForPayable(mixed $payableType, ?int $payableId): ?int
    {
        if ($payableId === null) {
            return null;
        }

        if (! ManualPaymentRequest::isOrderPayableType($payableType) && $payableType !== Order::class) {
            return null;
        }

        return Order::query()
            ->whereKey($payableId)
            ->value('store_id');
    }

    private function determineDepartmentForOrderPayable(
        mixed $payableType,
        mixed $payableId,
        ?ManualPaymentRequest $existingRequest
    ): ?string {
        $payableInt = is_numeric($payableId) ? (int) $payableId : null;
        $serviceRequestId = $this->resolveServiceRequestId($payableType, $payableInt);

        if ($serviceRequestId !== null) {
            return DepartmentReportService::DEPARTMENT_SERVICES;
        }

        if (! ManualPaymentRequest::isOrderPayableType($payableType)) {
            return null;
        }

        if ($payableInt !== null) {
            $department = $this->resolveOrderDepartment($payableInt);

            if ($department !== null) {
                return $department;
            }
        }

        if ($existingRequest !== null) {
            $fallback = $this->normalizeDepartment($existingRequest->department);

            if ($fallback !== null) {
                return $fallback;
            }
        }

        return null;
    }




    private function resolveServiceRequestId(mixed $payableType, ?int $payableId): ?int
    {
        if ($payableId === null) {
            return null;
        }

        $normalizedType = $this->normalizePayableTypeForComparison($payableType);

        if ($normalizedType === null) {
            return null;
        }

        $serviceAliases = [
            'service',
            'services',
            strtolower(ServiceRequest::class),
            strtolower('\\' . ServiceRequest::class),
            'app\\models\\servicerequest',
            'app\\servicerequest',
            'service_request',
            'service-request',
        ];

        if (! in_array($normalizedType, $serviceAliases, true)) {
            return null;
        }

        return $payableId;
    }

    private function normalizePayableTypeForComparison(mixed $payableType): ?string
    {
        if (! is_string($payableType)) {
            return null;
        }

        $charactersToTrim = " \t\n\r\0\x0B\"'";
        $normalized = strtolower(trim((string) $payableType, $charactersToTrim));

        return $normalized === '' ? null : $normalized;
    }

    private function normalizeManualBankIdentifier(mixed $value): ?int
    {
        if ($value instanceof ManualBank) {
            return $value->getKey();
        }

        if (is_string($value)) {
            $value = trim($value);
        }

        if ($value === null || $value === '' || $value === []) {
            return null;
        }

        if (is_int($value)) {
            return $value > 0 ? $value : null;
        }

        if (is_numeric($value)) {
            $intValue = (int) $value;

            return $intValue > 0 ? $intValue : null;
        }

        return null;
    }

    private function resolveReceiptPath(array $data, ?ManualPaymentRequest $existing): string
    {
        $path = Arr::get($data, 'receipt_path');

        if (is_string($path)) {
            $trimmed = trim($path);

            if ($trimmed !== '') {
                return $trimmed;
            }
        }

        $attachments = Arr::get($data, 'attachments');
        if (is_iterable($attachments)) {
            foreach ($attachments as $attachment) {
                $attachmentPath = Arr::get($attachment, 'path');

                if (! is_string($attachmentPath)) {
                    continue;
                }

                $trimmedAttachment = trim($attachmentPath);

                if ($trimmedAttachment !== '') {
                    return $trimmedAttachment;
                }
            }
        }

        if ($existing && is_string($existing->receipt_path) && $existing->receipt_path !== '') {
            return $existing->receipt_path;
        }

        return '';
    }

    /**
     * @param mixed $attachments
     * @return array<int, array<string, mixed>>
     */
    private function normalizeAttachments(mixed $attachments, ?string $receiptPath): array
    {
        if (! is_iterable($attachments)) {
            $attachments = [];
        }

        $normalized = [];

        foreach ($attachments as $attachment) {
            if (! is_array($attachment)) {
                continue;
            }

            $path = Arr::get($attachment, 'path');

            if (! is_string($path) || trim($path) === '') {
                $path = $receiptPath;
            }

            if (! is_string($path) || trim($path) === '') {
                continue;
            }

            $normalized[] = array_filter([
                'type' => Arr::get($attachment, 'type', 'receipt'),
                'path' => $path,
                'disk' => Arr::get($attachment, 'disk', 'public'),
                'name' => Arr::get($attachment, 'name'),
                'mime_type' => Arr::get($attachment, 'mime_type'),
                'size' => Arr::get($attachment, 'size'),
                'uploaded_at' => Arr::get($attachment, 'uploaded_at'),
                'url' => Arr::get($attachment, 'url'),
            ], static fn ($value) => $value !== null && $value !== '');
        }

        if ($normalized === [] && is_string($receiptPath) && $receiptPath !== '') {
            $normalized[] = [
                'type' => 'receipt',
                'path' => $receiptPath,
                'disk' => 'public',
            ];
        }

        return $normalized;
    }

    private function resolveOrderDepartment(?int $orderId): ?string
    {
        if ($orderId === null) {
            return null;
        }

        $department = Order::query()->whereKey($orderId)->value('department');

        return $this->normalizeDepartment($department);
    }


    private function normalizeDepartment(mixed $department): ?string
    {
        if (! is_string($department)) {
            return null;
        }

        $trimmed = trim($department);

        return $trimmed === '' ? null : $trimmed;
    }







    /**
     * @param array<mixed> $values
     * @return array<mixed>
     */
    private function filterArrayRecursive(array $values): array
    {
        $filtered = [];

        foreach ($values as $key => $value) {
            if (is_array($value)) {
                $value = $this->filterArrayRecursive($value);

                if ($value === []) {
                    continue;
                }

                $filtered[$key] = $value;

                continue;
            }

            if ($value === null) {
                continue;
            }

            if (is_string($value) && trim($value) === '') {
                continue;
            }

            $filtered[$key] = $value;
        }

        return $filtered;
    }

    private function isDuplicateManualPaymentRequestException(QueryException $exception, ?string $payableType, ?int $payableId): bool
    {
        if ($exception->getCode() !== '23000') {
            return false;
        }

        if ($payableType === null || $payableId === null) {
            return false;
        }

        return str_contains($exception->getMessage(), 'manual_payment_requests_open_unique_key_unique');
    }

    private function manualPaymentSupportsBankNameColumn(): bool
    {
        if ($this->supportsBankNameColumn !== null) {
            return $this->supportsBankNameColumn;
        }

        $connection = $this->getManualPaymentRequestConnection();

        $this->supportsBankNameColumn = $this->manualPaymentRequestHasColumn('bank_name', $connection);


        return $this->supportsBankNameColumn;

    }


    private function isManualPaymentRequestDuplicateKeyException(Throwable $exception): bool
    {
        $needle = 'manual_payment_requests_open_unique_key_unique';

        $current = $exception;

        while ($current instanceof Throwable) {
            $message = Str::lower($current->getMessage());

            if (str_contains($message, $needle)) {
                return true;
            }

            if ($current instanceof QueryException || $current instanceof UniqueConstraintViolationException) {
                $errorInfo = $current->errorInfo ?? null;

                if (is_array($errorInfo)) {
                    foreach ($errorInfo as $value) {
                        if (is_string($value) && str_contains(Str::lower($value), $needle)) {
                            return true;
                        }
                    }
                }

                $code = (string) $current->getCode();
                if ($code === '23000' && str_contains($message, 'duplicate entry')) {
                    return true;
                }
            }

            $current = $current->getPrevious();
        }

        return false;
    }

    private function isPaymentTransactionManualPaymentDuplicateException(Throwable $exception): bool
    {
        $needles = [
            'payment_transactions_manual_payment_request_id_unique',
            'manual_payment_request_id_unique',
        ];

        $current = $exception;

        while ($current instanceof Throwable) {
            $message = Str::lower($current->getMessage());

            foreach ($needles as $needle) {
                if (str_contains($message, $needle)) {
                    return true;
                }
            }

            if ($current instanceof QueryException || $current instanceof UniqueConstraintViolationException) {
                $errorInfo = $current->errorInfo ?? null;

                if (is_array($errorInfo)) {
                    foreach ($errorInfo as $value) {
                        if (! is_string($value)) {
                            continue;
                        }

                        $lower = Str::lower($value);

                        foreach ($needles as $needle) {
                            if (str_contains($lower, $needle)) {
                                return true;
                            }
                        }
                    }
                }

                $code = (string) $current->getCode();

                if ($code === '23000' && str_contains($message, 'manual_payment_request_id') && str_contains($message, 'duplicate')) {
                    return true;
                }
            }

            $current = $current->getPrevious();
        }

        return false;
    }



    private function manualPaymentSupportsBankAccountNameColumn(): bool
    
    {
        if ($this->supportsBankAccountNameColumn !== null) {
            return $this->supportsBankAccountNameColumn;

        }

        $connection = $this->getManualPaymentRequestConnection();

        $this->supportsBankAccountNameColumn = $this->manualPaymentRequestHasColumn(
            'bank_account_name',
            $connection
        );


        return $this->supportsBankAccountNameColumn;

    }

    private function manualPaymentRequestHasColumn(string $column, ?string $connection = null): bool
    {
        $connection ??= $this->getManualPaymentRequestConnection();

        try {


            if ($connection !== null) {
                return Schema::connection($connection)->hasColumn('manual_payment_requests', $column);
            }

            return Schema::hasColumn('manual_payment_requests', $column);
        
        } catch (Throwable $exception) {
            Log::warning('Unable to determine manual payment request column support.', [
                'column' => $column,
                'exception' => $exception,
            ]);

            return false;
        }
    }


    

    private function getManualPaymentRequestConnection(): ?string
    {
        if ($this->manualPaymentRequestConnectionResolved) {
            return $this->manualPaymentRequestConnection;
        }

        $connection = (new ManualPaymentRequest())->getConnectionName();

        if (is_string($connection)) {
            $connection = trim($connection);

            if ($connection === '') {
                $connection = null;
            }
        } else {
            $connection = null;
        }

        $this->manualPaymentRequestConnection = $connection;
        $this->manualPaymentRequestConnectionResolved = true;

        return $this->manualPaymentRequestConnection;
    }
}
