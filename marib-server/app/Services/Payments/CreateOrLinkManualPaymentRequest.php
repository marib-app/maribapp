<?php

namespace App\Services\Payments;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Database\QueryException;

class CreateOrLinkManualPaymentRequest
{
    public function __construct(private readonly ManualPaymentRequestService $manualPaymentRequestService)
    {
    }

    /**
     * @param array<string, mixed> $data
     */
    public function handle(
        User $user,
        string $payableType,
        ?int $payableId,
        PaymentTransaction $transaction,
        array $data = []
    ): ManualPaymentRequest {
        $manualRequest = $transaction->manualPaymentRequest;

        if (! $manualRequest instanceof ManualPaymentRequest) {
            $manualRequest = $this->manualPaymentRequestService->findOpenManualPaymentRequestForPayable(
                $payableType,
                $payableId
            );

            if ($manualRequest instanceof ManualPaymentRequest) {
                $transaction->forceFill([
                    'manual_payment_request_id' => $manualRequest->getKey(),
                ])->saveQuietly();

                $transaction->setRelation('manualPaymentRequest', $manualRequest);
            }
        }

        if (! $manualRequest instanceof ManualPaymentRequest) {
            $manualRequest = $this->createManualPaymentRequestFromTransaction(
                
                $user,
                $payableType,
                $payableId,
                $transaction,
                $data
            );

            $transaction->forceFill([
                'manual_payment_request_id' => $manualRequest->getKey(),
            ])->saveQuietly();
            $transaction->setRelation('manualPaymentRequest', $manualRequest);
        }

        $manualRequest = $this->manualPaymentRequestService->createOrUpdateForManualTransaction(
            $user,
            $payableType,
            $payableId,
            $transaction,
            $data
        );

        $manualMeta = is_array($manualRequest->meta) ? $manualRequest->meta : [];
        $transactionMeta = is_array($transaction->meta) ? $transaction->meta : [];

        $senderName = $this->normalizeString(
            Arr::get($data, 'sender_name')
                ?? Arr::get($data, 'transfer.sender_name')
                ?? Arr::get($data, 'metadata.sender_name')
                ?? Arr::get($data, 'metadata.transfer.sender_name')
                ?? Arr::get($data, 'metadata.transfer_details.sender_name')
                ?? Arr::get($data, 'manual.sender_name')
                ?? Arr::get($data, 'manual.metadata.sender_name')
                ?? Arr::get($data, 'manual.transfer_details.sender_name')
        );

        $transferReference = null;

        $transferReferenceKeys = [
            'transfer_reference',
            'transfer_code',
            'reference',
            'reference_number',
            'metadata.transfer_reference',
            'metadata.transfer_code',
            'metadata.reference',
            'metadata.reference_number',
            'metadata.transfer.transfer_reference',
            'metadata.transfer.transfer_code',
            'metadata.transfer.reference_number',
            'metadata.transfer_details.transfer_reference',
            'metadata.transfer_details.transfer_code',
            'metadata.transfer_details.reference_number',
            'transfer.transfer_reference',
            'transfer.transfer_code',
            'transfer.reference_number',
            'transfer_details.transfer_reference',
            'transfer_details.transfer_code',
            'transfer_details.reference_number',
            'manual.transfer_reference',
            'manual.transfer_code',
            'manual.reference_number',
            'manual.metadata.transfer_reference',
            'manual.metadata.transfer_code',
            'manual.metadata.reference_number',
            'manual.transfer_details.transfer_reference',
            'manual.transfer_details.transfer_code',
            'manual.transfer_details.reference_number',
        ];

        foreach ($transferReferenceKeys as $key) {
            $transferReference = $this->normalizeString(Arr::get($data, $key));

            if ($transferReference !== null) {
                break;
            }
        }

        $note = $this->normalizeMultiline(
            Arr::get($data, 'note')
                ?? Arr::get($data, 'metadata.note')
                ?? Arr::get($data, 'metadata.notes')
        );

        if ($senderName !== null) {
            data_set($manualMeta, 'manual.sender_name', $senderName);
            data_set($manualMeta, 'manual.metadata.sender_name', $senderName);
            data_set($transactionMeta, 'manual.sender_name', $senderName);
            data_set($transactionMeta, 'manual.metadata.sender_name', $senderName);
        }


        if ($transferReference !== null) {
            data_set($manualMeta, 'manual.transfer_reference', $transferReference);
            data_set($manualMeta, 'manual.metadata.transfer_reference', $transferReference);
            data_set($manualMeta, 'manual.transfer_code', $transferReference);
            data_set($manualMeta, 'manual.metadata.transfer_code', $transferReference);
            data_set($transactionMeta, 'manual.transfer_reference', $transferReference);
            data_set($transactionMeta, 'manual.metadata.transfer_reference', $transferReference);
            data_set($transactionMeta, 'manual.transfer_code', $transferReference);
            data_set($transactionMeta, 'manual.metadata.transfer_code', $transferReference);
        }

        if ($note !== null) {
            data_set($manualMeta, 'manual.note', $note);
            data_set($manualMeta, 'manual.metadata.note', $note);
            data_set($transactionMeta, 'manual.note', $note);
        }

        $manualRequest->meta = $this->filterArrayRecursive($manualMeta);
        $manualRequest->saveQuietly();

        $transaction->forceFill([
            'manual_payment_request_id' => $manualRequest->getKey(),
            'meta' => $this->filterArrayRecursive($transactionMeta),
        ])->saveQuietly();

        return $manualRequest->fresh();
    }



    /**
     * @param array<string, mixed> $data
     */
    private function createManualPaymentRequestFromTransaction(
        User $user,
        string $payableType,
        ?int $payableId,
        PaymentTransaction $transaction,
        array $data
    ): ManualPaymentRequest {
        try {
            return $this->manualPaymentRequestService->createFromTransaction(
                $user,
                $payableType,
                $payableId,
                $transaction,
                $data
            );
        } catch (QueryException $exception) {
            if (! $this->isUniqueConstraintViolation($exception)) {
                throw $exception;
            }

            $manualRequest = $this->manualPaymentRequestService->findOpenManualPaymentRequestForPayable(
                $payableType,
                $payableId
            );

            if (! $manualRequest instanceof ManualPaymentRequest) {
                $manualRequest = ManualPaymentRequest::query()
                    ->where('payment_transaction_id', $transaction->getKey())
                    ->first();
            }

            if (! $manualRequest instanceof ManualPaymentRequest) {
                throw $exception;
            }

            return $manualRequest;
        }
    }

    private function isUniqueConstraintViolation(QueryException $exception): bool
    {
        $sqlState = $exception->getCode();

        if (in_array($sqlState, ['23000', '23505'], true)) {
            return true;
        }

        $errorInfo = $exception->errorInfo ?? [];

        if (is_array($errorInfo) && isset($errorInfo[0]) && in_array($errorInfo[0], ['23000', '23505'], true)) {
            return true;
        }

        return false;
    }



    private function normalizeString($value): ?string
    {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if ($value === null || $value === '' || $value === []) {
            return null;
        }

        if (is_bool($value)) {
            return null;
        }

        if (is_numeric($value) && ! is_string($value)) {
            $value = (string) $value;
        }

        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function normalizeMultiline($value): ?string
    {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if ($value === null || $value === '') {
            return null;
        }

        if (is_bool($value)) {
            return null;
        }

        if (is_numeric($value) && ! is_string($value)) {
            return (string) $value;
        }

        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $value;
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

            if (is_string($value)) {
                $value = trim($value);

                if ($value === '') {
                    continue;
                }
            }

            $filtered[$key] = $value;
        }

        return $filtered;
    }
}