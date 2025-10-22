<?php

namespace App\Services\Payments\Concerns;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Services\Payments\ManualPaymentRequestService;
use Illuminate\Support\Arr;

/**
 * @property-read ManualPaymentRequestService $manualPaymentRequestService
 */
trait HandlesManualBankConfirmation
{
    /**
     * Prepare the manual payment request context for a confirmation payload.
     *
     * @param array<string, mixed> $data
     * @return array{data: array<string, mixed>, manual_payment_request: ManualPaymentRequest}|null
     */
    protected function prepareManualBankConfirmationPayload(
        User $user,
        PaymentTransaction $transaction,
        string $payableType,
        ?int $payableId,
        string $paymentGateway,
        string $idempotencyKey,
        array $data
    ): ?array {
        $manualRequest = $transaction->manualPaymentRequest instanceof ManualPaymentRequest
            ? $transaction->manualPaymentRequest
            : null;

        if (! $manualRequest) {
            $manualRequest = $this->manualPaymentRequestService->createFromTransaction(
                $user,
                $payableType,
                $payableId,
                $transaction,
                array_merge($data, [
                    'payment_gateway' => $paymentGateway,
                    'idempotency_key' => $transaction->idempotency_key ?? $idempotencyKey,
                ])
            );

            $transaction->manual_payment_request_id = $manualRequest->getKey();
            $transaction->save();
        }

        $manualBankId = $this->resolveManualBankIdentifierForConfirmation($data, $manualRequest);

        if ($manualBankId !== null) {
            $data['manual_bank_id'] = $manualBankId;

            $manualRequest = $this->manualPaymentRequestService->createOrUpdateForManualTransaction(
                $user,
                $payableType,
                $payableId,
                $transaction,
                array_merge($data, [
                    'manual_bank_id' => $manualBankId,
                    'payment_gateway' => $paymentGateway,
                    'idempotency_key' => $transaction->idempotency_key ?? $idempotencyKey,
                ])
            );

            if ((int) $transaction->manual_payment_request_id !== $manualRequest->getKey()) {
                $transaction->manual_payment_request_id = $manualRequest->getKey();
                $transaction->save();
            }
        } else {
            $manualRequest->refresh();
        }

        $manualRequest->loadMissing('manualBank');
        $data['manual_payment_request_id'] = $manualRequest->getKey();

        return [
            'data' => $data,
            'manual_payment_request' => $manualRequest,
        ];
    }

    /**
     * Merge manual bank metadata into the confirmation meta payload.
     *
     * @param array<string, mixed> $meta
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    protected function mergeManualConfirmationMeta(
        array $meta,
        array $data,
        ManualPaymentRequest $manualPaymentRequest,
        PaymentTransaction $transaction,
        string $idempotencyKey
    ): array {
        $manualMeta = Arr::get($meta, 'manual');
        if (! is_array($manualMeta)) {
            $manualMeta = [];
        }

        $manualMetaUpdates = [];

        if (array_key_exists('note', $data)) {
            $note = $this->normalizeNullableString($data['note']);
            if ($note !== null) {
                $manualMetaUpdates['note'] = $note;
            } elseif (array_key_exists('note', $manualMeta)) {
                $manualMetaUpdates['note'] = null;
            }
        }

        if (array_key_exists('reference', $data)) {
            $reference = $this->normalizeNullableString($data['reference']);
            if ($reference !== null) {
                $manualMetaUpdates['reference'] = $reference;
            } elseif (array_key_exists('reference', $manualMeta)) {
                $manualMetaUpdates['reference'] = null;
            }
        }

        if (array_key_exists('receipt_path', $data)) {
            $receiptPath = $this->normalizeNullableString($data['receipt_path']);
            if ($receiptPath !== null) {
                $manualMetaUpdates['receipt_path'] = $receiptPath;
            } elseif (array_key_exists('receipt_path', $manualMeta)) {
                $manualMetaUpdates['receipt_path'] = null;
            }
        }

        if (array_key_exists('attachments', $data)) {
            $attachments = $this->coerceAttachments($data['attachments']);
            $manualMetaUpdates['attachments'] = $attachments;
        }

        $metadata = Arr::get($data, 'metadata');
        if (is_array($metadata)) {
            $manualMetaUpdates['metadata'] = $metadata;
        }

        $manualMetaUpdates['idempotency_key'] = $transaction->idempotency_key ?? $idempotencyKey;

        $bankDetails = $this->resolveManualBankDetailsForMeta($data, $manualPaymentRequest);
        if ($bankDetails !== []) {
            $manualMetaUpdates['bank'] = $bankDetails;
            $manualMetaUpdates['manual_bank'] = $bankDetails;
        }

        $manualMeta = array_replace_recursive($manualMeta, $manualMetaUpdates);
        $manualMeta = $this->filterArrayRecursive($manualMeta);

        if ($manualMeta === []) {
            unset($meta['manual']);
        } else {
            $meta['manual'] = $manualMeta;
        }

        $manualPaymentMeta = Arr::get($meta, 'manual_payment_request');
        if (! is_array($manualPaymentMeta)) {
            $manualPaymentMeta = [];
        }

        $manualPaymentMetaUpdates = array_filter([
            'id' => $manualPaymentRequest->getKey(),
            'status' => $manualPaymentRequest->status,
            'manual_bank_id' => $manualPaymentRequest->manual_bank_id,
            'manual_bank' => $bankDetails !== [] ? $bankDetails : null,
        ], static fn ($value) => $value !== null && $value !== '');

        $manualPaymentMeta = array_replace_recursive($manualPaymentMeta, $manualPaymentMetaUpdates);
        $manualPaymentMeta = $this->filterArrayRecursive($manualPaymentMeta);

        if ($manualPaymentMeta === []) {
            unset($meta['manual_payment_request']);
        } else {
            $meta['manual_payment_request'] = $manualPaymentMeta;
        }


        if (isset($bankDetails['id']) && $bankDetails['id'] !== null && $bankDetails['id'] !== '') {
            $normalizedBankId = is_numeric($bankDetails['id']) ? (int) $bankDetails['id'] : null;

            if ($normalizedBankId !== null && $normalizedBankId > 0) {
                data_set($meta, 'payload.manual_bank_id', $normalizedBankId);
            }
        }

        if (isset($bankDetails['name']) && is_string($bankDetails['name']) && trim($bankDetails['name']) !== '') {
            data_set($meta, 'payload.bank_name', trim($bankDetails['name']));
        }


        return $meta;
    }

    /**
     * @param array<string, mixed> $data
     */
    private function resolveManualBankIdentifierForConfirmation(array $data, ManualPaymentRequest $manualPaymentRequest): ?int
    {
        $identifier = Arr::get($data, 'manual_bank_id');

        if ($identifier === null || $identifier === '') {
            $identifier = Arr::get($data, 'bank_id');
        }

        if ($identifier === null || $identifier === '') {
            $identifier = $manualPaymentRequest->manual_bank_id;
        }

        if ($identifier === null || $identifier === '') {
            $meta = $manualPaymentRequest->meta;
            if (is_array($meta)) {
                $identifier = Arr::get($meta, 'manual_bank.id') ?? Arr::get($meta, 'bank.id');
            }
        }

        if ($identifier === null || $identifier === '') {
            return null;
        }

        if (! is_numeric($identifier)) {
            return null;
        }

        $normalized = (int) $identifier;

        return $normalized > 0 ? $normalized : null;
    }

    /**
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function resolveManualBankDetailsForMeta(array $data, ManualPaymentRequest $manualPaymentRequest): array
    {
        $manualBank = $manualPaymentRequest->relationLoaded('manualBank')
            ? $manualPaymentRequest->getRelation('manualBank')
            : $manualPaymentRequest->manualBank;

        $meta = $manualPaymentRequest->meta;
        if (! is_array($meta)) {
            $meta = [];
        }

        $bankMeta = Arr::get($meta, 'bank');
        if (! is_array($bankMeta)) {
            $bankMeta = [];
        }

        $manualBankMeta = Arr::get($meta, 'manual_bank');
        if (! is_array($manualBankMeta)) {
            $manualBankMeta = [];
        }

        $manualBankId = $this->resolveManualBankIdentifierForConfirmation($data, $manualPaymentRequest);

        $bankName = $this->firstNonEmptyString([
            Arr::get($data, 'bank.name'),
            Arr::get($data, 'bank_name'),
            Arr::get($manualBankMeta, 'name'),
            Arr::get($bankMeta, 'name'),
            $manualPaymentRequest->bank_name,
            $manualBank?->name,
        ]);

        $beneficiaryName = $this->firstNonEmptyString([
            Arr::get($data, 'bank.beneficiary_name'),
            Arr::get($manualBankMeta, 'beneficiary_name'),
            Arr::get($bankMeta, 'beneficiary_name'),
            $manualPaymentRequest->bank_account_name,
            $manualBank?->beneficiary_name,
        ]);

        $accountId = $this->firstNonEmptyString([
            Arr::get($data, 'bank.account_id'),
            Arr::get($data, 'bank_account_id'),
            Arr::get($manualBankMeta, 'account_id'),
            Arr::get($bankMeta, 'account_id'),
        ]);

        return array_filter([
            'id' => $manualBankId,
            'account_id' => $accountId,
            'name' => $bankName,
            'beneficiary_name' => $beneficiaryName,
        ], static fn ($value) => $value !== null && $value !== '');
    }

    private function normalizeNullableString(mixed $value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    /**
     * @param mixed $attachments
     * @return array<int, array<string, mixed>>
     */
    private function coerceAttachments(mixed $attachments): array
    {
        if (! is_iterable($attachments)) {
            return [];
        }

        $normalized = [];

        foreach ($attachments as $attachment) {
            if (is_array($attachment)) {
                $normalized[] = $attachment;
            }
        }

        return $normalized;
    }

    /**
     * @param array<string, mixed> $values
     * @return array<string, mixed>
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

            if (is_string($value)) {
                $normalized = trim($value);

                if ($normalized === '') {
                    continue;
                }

                $filtered[$key] = $normalized;

                continue;
            }

            if ($value === null) {
                continue;
            }

            $filtered[$key] = $value;
        }

        return $filtered;
    }

    private function firstNonEmptyString(iterable $candidates): ?string
    {
        foreach ($candidates as $candidate) {
            if (! is_string($candidate)) {
                continue;
            }

            $trimmed = trim($candidate);

            if ($trimmed !== '') {
                return $trimmed;
            }
        }

        return null;
    }
}
