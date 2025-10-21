<?php

namespace App\Services\Payments;

use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Throwable;


class ManualPaymentRequestService
{
    private ?bool $supportsBankNameColumn = null;

    private ?bool $supportsBankAccountNameColumn = null;

    
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
        $manualBankId = Arr::get($data, 'bank_id') ?? Arr::get($data, 'manual_bank_id');
        $bankAccountId = Arr::get($data, 'bank_account_id');
        $reference = Arr::get($data, 'reference');
        $note = Arr::get($data, 'note');

        $metadata = Arr::get($data, 'metadata');
        if (! is_array($metadata)) {
            $metadata = null;
        }

        $manualBank = null;
        if ($manualBankId) {
            $manualBank = ManualBank::query()->find($manualBankId);
        }


        if (! $manualBank) {
            throw ValidationException::withMessages([
                'manual_bank_id' => __('الرجاء اختيار الحساب البنكي للتحويل اليدوي.'),
            ]);
        }


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

        if ($manualBankId) {
            $normalizedManualBankId = (int) $manualBankId;

            data_set($metaUpdates, 'bank.id', $normalizedManualBankId);
            data_set($metaUpdates, 'manual_bank.id', $normalizedManualBankId);
        
        }

        if ($bankAccountId) {
            data_set($metaUpdates, 'bank.account_id', $bankAccountId);
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

            $existingRequest->fill([
                'manual_bank_id' => $manualBank?->getKey(),
                'payable_type' => $payableType,
                'payable_id' => $payableId,
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
                if ($this->manualPaymentSupportsBankNameColumn()) {
                    $existingRequest->bank_name = $manualBank->name;
                }

                if ($this->manualPaymentSupportsBankAccountNameColumn()) {
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

        if ($manualBank && $this->manualPaymentSupportsBankNameColumn()) {

            $attributes['bank_name'] = $manualBank->name;
        }

        if ($manualBank && $this->manualPaymentSupportsBankAccountNameColumn()) {
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

        $manualBankId = Arr::get($data, 'manual_bank_id');

        if ($manualBankId === null) {
            $manualBankId = Arr::get($data, 'bank_id');
        }
        $manualBank = null;

        if ($manualBankId !== null && $manualBankId !== '') {
            $manualBankId = (int) $manualBankId;

            if ($manualBankId <= 0) {
                $manualBankId = null;
            }
        } else {
            $manualBankId = null;
        }


        if ($manualBankId !== null) {
            $manualBank = ManualBank::query()->find($manualBankId);
        }


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




        if ($manualBankId !== null) {
            data_set($meta, 'bank.id', $manualBankId);
            data_set($meta, 'manual_bank.id', $manualBankId);
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


        $meta = $this->filterArrayRecursive($meta);

        $department = $this->determineDepartmentForOrderPayable($payableType, $payableId, null);

        $attributes = [
            'user_id' => $user->getKey(),
            'manual_bank_id' => $manualBankId,
            'payable_type' => $payableType,
            'payable_id' => $payableId,
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


        if ($this->manualPaymentSupportsBankNameColumn() && $bankName !== null) {
            $attributes['bank_name'] = $bankName;
        }


        return ManualPaymentRequest::create(array_filter(
            $attributes,
            static function ($value) {
                if (is_array($value)) {
                    return true;
                }

                return $value !== null && $value !== '';
            }
        ));
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

        $manualBank = $manualBankId !== null
            ? ManualBank::query()->find($manualBankId)
            : null;

        if ($manualBank && $bankName === null) {
            $bankName = $normalizeString($manualBank->name);
        }

        $bankBeneficiary = $manualBank && $manualBank->beneficiary_name
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
        data_set($metaPayload, 'auto_linked_at', now()->toIso8601String());

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

        if ($existingRequest instanceof ManualPaymentRequest) {
            $existingMeta = $existingRequest->meta;

            if (! is_array($existingMeta)) {
                $existingMeta = [];
            }

            $mergedMeta = $this->filterArrayRecursive(array_replace_recursive($existingMeta, $metaPayload));

            $existingRequest->forceFill(array_filter([
                'manual_bank_id' => $manualBank?->getKey() ?? $manualBankId,
                'payable_type' => $transactionPayableType,
                'payable_id' => $payableId,
                'amount' => $transaction->amount,
                'currency' => $transaction->currency,
                'reference' => $reference ?? $existingRequest->reference,
                'user_note' => $note ?? $existingRequest->user_note,
                'receipt_path' => $receiptPath ?? $existingRequest->receipt_path,
                'payment_transaction_id' => $transaction->getKey(),
            ], static fn ($value) => $value !== null && $value !== ''));

            if ($bankName !== null && $this->manualPaymentSupportsBankNameColumn()) {

                $existingRequest->bank_name = $bankName;
            }

            if ($bankBeneficiary !== null && $this->manualPaymentSupportsBankAccountNameColumn()) {

                $existingRequest->bank_account_name = $bankBeneficiary;
            }

            $existingRequest->meta = $mergedMeta === [] ? null : $mergedMeta;
            $existingRequest->saveQuietly();

            $manualPaymentRequest = $existingRequest->fresh();
        } else {
            $manualPaymentRequest = $this->createFromTransaction(
                $user,
                $transactionPayableType,
                $payableId,
                $transaction,
                $payload
            );

            $manualPaymentRequest->forceFill([
                'payment_transaction_id' => $transaction->getKey(),
                'manual_bank_id' => $manualBank?->getKey() ?? $manualBankId,
            ]);

            if ($bankName !== null && $this->manualPaymentSupportsBankNameColumn()) {
                $manualPaymentRequest->bank_name = $bankName;
            }

            if (
                $bankBeneficiary !== null
                && $this->manualPaymentSupportsBankAccountNameColumn()
                && $manualPaymentRequest->bank_account_name === null
            ) {
                
                $manualPaymentRequest->bank_account_name = $bankBeneficiary;
            }

            $manualPaymentRequest->saveQuietly();
        }

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

        $transaction->forceFill([
            'manual_payment_request_id' => $manualPaymentRequest->getKey(),
            'meta' => $this->filterArrayRecursive($transactionMeta),
        ])->saveQuietly();

        $transaction->refresh();
        $manualPaymentRequest->setRelation('paymentTransaction', $transaction);

        $this->syncTransactionManualBankPayload($transaction, $manualPaymentRequest);

        return $manualPaymentRequest;
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


    private function determineDepartmentForOrderPayable(
        mixed $payableType,
        mixed $payableId,
        ?ManualPaymentRequest $existingRequest
    ): ?string {
        if (! ManualPaymentRequest::isOrderPayableType($payableType)) {
            return null;
        }

        $orderId = is_numeric($payableId) ? (int) $payableId : null;

        if ($orderId !== null) {
            $department = $this->resolveOrderDepartment($orderId);

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




    private function resolveReceiptPath(array $data, ?ManualPaymentRequest $existing): string
    {
        $path = Arr::get($data, 'receipt_path');

        if (is_string($path)) {
            $trimmed = trim($path);

            if ($trimmed !== '') {
                return $trimmed;
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

    private function manualPaymentSupportsBankNameColumn(): bool
    {
        if ($this->supportsBankNameColumn !== null) {
            return $this->supportsBankNameColumn;
        }

        $this->supportsBankNameColumn = $this->manualPaymentRequestHasColumn('bank_name');

        return $this->supportsBankNameColumn;
    }

    private function manualPaymentSupportsBankAccountNameColumn(): bool
    
    {
        if ($this->supportsBankAccountNameColumn !== null) {
            return $this->supportsBankAccountNameColumn;
        }

        $this->supportsBankAccountNameColumn = $this->manualPaymentRequestHasColumn('bank_account_name');

        return $this->supportsBankAccountNameColumn;
    }

    private function manualPaymentRequestHasColumn(string $column): bool
    {

        try {
            $connection = (new ManualPaymentRequest())->getConnectionName();

            if (is_string($connection)) {
                $connection = trim($connection);


                if ($connection === '') {
                    $connection = null;
                }
            }

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
}