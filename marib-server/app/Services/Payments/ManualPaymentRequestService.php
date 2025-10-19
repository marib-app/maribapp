<?php

namespace App\Services\Payments;

use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Validation\ValidationException;


class ManualPaymentRequestService
{
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
            data_set($metaUpdates, 'bank.id', (int) $manualBankId);
        }

        if ($bankAccountId) {
            data_set($metaUpdates, 'bank.account_id', $bankAccountId);
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
            ]);

            if ($manualBank) {
                $existingRequest->bank_name = $manualBank->name;
                $existingRequest->bank_account_name = $manualBank->beneficiary_name;
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

        ];

        if ($manualBank) {
            $attributes['bank_name'] = $manualBank->name;
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

        if ($manualBankId !== null && $manualBankId !== '') {
            $manualBankId = (int) $manualBankId;

            if ($manualBankId <= 0) {
                $manualBankId = null;
            }
        } else {
            $manualBankId = null;
        }

        $bankName = $normalizeString(Arr::get($data, 'bank.name'))
            ?? $normalizeString(Arr::get($data, 'bank_name'));

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
            'bank_name' => $bankName,
            'meta' => $meta === [] ? null : $meta,
        ];

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

}