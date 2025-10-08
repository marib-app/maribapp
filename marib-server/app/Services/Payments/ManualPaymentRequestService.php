<?php

namespace App\Services\Payments;

use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
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

        if ($metadata) {
            $metaUpdates['metadata'] = $metadata;
        }

        $existingRequest = null;

        if ($transaction->manual_payment_request_id) {
            $existingRequest = ManualPaymentRequest::query()
                ->lockForUpdate()
                ->find($transaction->manual_payment_request_id);
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
        ];

        if ($manualBank) {
            $attributes['bank_name'] = $manualBank->name;
            $attributes['bank_account_name'] = $manualBank->beneficiary_name;
        }

        return ManualPaymentRequest::create($attributes);
    }
}