<?php

namespace App\Http\Resources;

use ArrayAccess;
use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Models\Order;
use App\Models\PaymentTransaction;
use App\Models\ServiceRequest;
use App\Models\WalletTransaction;
use App\Support\Payments\PaymentLabelService;
use App\Support\ManualPayments\TransferDetailsResolver;
use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Http\Resources\MissingValue;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

class ManualPaymentRequestResource extends JsonResource
{
    public function toArray($request): array
    {
        $paymentTransaction = $this->whenLoaded('paymentTransaction');

        if ($paymentTransaction instanceof MissingValue) {
            $paymentTransaction = null;
        }

        if ($paymentTransaction instanceof EloquentModel && ! $paymentTransaction->relationLoaded('order')) {
            $paymentTransaction->load('order');
        }

        if ($paymentTransaction instanceof EloquentModel) {
            $paymentTransaction->loadMissing('manualPaymentRequest.manualBank');
        }

        $manualPaymentRequestModel = $this->resource instanceof ManualPaymentRequest
            ? $this->resource
            : null;

        if ($manualPaymentRequestModel instanceof ManualPaymentRequest) {
            $manualPaymentRequestModel->loadMissing('manualBank', 'store');
        }

        $manualBank = $manualPaymentRequestModel?->manualBank;
                $manualBankPayload = $manualBank instanceof ManualBank
            ? array_merge($manualBank->toArray(), [
                'logo_url' => $this->generateSignedUrl($manualBank->logo ?? null),
                'qr_code_url' => $this->generateSignedUrl($manualBank->qr_code ?? null),
            ])
            : null;

        $payable = $this->whenLoaded('payable');

        if ($payable instanceof MissingValue) {
            $payable = null;
        }

        if (
            $paymentTransaction instanceof EloquentModel
            && $paymentTransaction->payableIsWalletTransaction()
            && ! $paymentTransaction->relationLoaded('walletTransaction')
        ) {
            
            $paymentTransaction->load('walletTransaction');
        }



        $order = $paymentTransaction?->order;
        $walletTransaction = ($paymentTransaction instanceof EloquentModel
            && $paymentTransaction->payableIsWalletTransaction())
            ? $paymentTransaction->walletTransaction
            : null;
            
        $gatewayKey = $paymentTransaction?->payment_gateway
            ?? data_get($this->meta, 'gateway')
            ?? data_get($this->meta, 'payment_gateway')
            ?? 'manual_bank';

        $canonicalGateway = ManualPaymentRequest::canonicalGateway($gatewayKey) ?? 'manual_banks';
        $labels = $manualPaymentRequestModel instanceof ManualPaymentRequest
            ? PaymentLabelService::forManualPaymentRequest($manualPaymentRequestModel)
            : ['channel_label' => null, 'bank_label' => null];

        $transactionLabels = $paymentTransaction instanceof PaymentTransaction
            ? PaymentLabelService::forPaymentTransaction($paymentTransaction)
            : ['channel_label' => null, 'bank_label' => null];

        $manualBankName = $labels['bank_label'];
        $channelLabel = $labels['channel_label'];

        $meta = null;

        if ($manualPaymentRequestModel instanceof ManualPaymentRequest && is_array($manualPaymentRequestModel->meta)) {
            $meta = $manualPaymentRequestModel->meta;
        } elseif (is_array($this->meta)) {
            $meta = $this->meta;
        }

        if (! is_array($meta) || $meta === []) {
            $meta = null;
        }

        $paymentTransactionMeta = null;

        if ($paymentTransaction instanceof PaymentTransaction && is_array($paymentTransaction->meta)) {
            $paymentTransactionMeta = $paymentTransaction->meta;
        }

        if (! is_array($paymentTransactionMeta) || $paymentTransactionMeta === []) {
            $paymentTransactionMeta = null;
        }

        $paymentStatus = $this->normalizePaymentStatus($paymentTransaction?->payment_status);
        $manualReference = $this->reference
            ?? data_get($this->meta, 'reference')
            ?? data_get($paymentTransaction?->meta, 'manual.reference');
        $walletMeta = $paymentTransaction?->meta ?? [];
        if (empty($walletMeta)) {
            $walletMeta = is_array($this->meta) ? $this->meta : [];
        }

        $walletSnapshot = array_filter([
            'transaction_id' => data_get($walletMeta, 'wallet.transaction_id'),
            'idempotency_key' => data_get($walletMeta, 'wallet.idempotency_key'),
            'balance_after' => data_get($walletMeta, 'wallet.balance_after'),
        ], static fn ($value) => $value !== null && $value !== '');

        if ($walletTransaction instanceof WalletTransaction) {
            $walletSnapshot = array_merge([
                'transaction_id' => $walletTransaction->getKey(),
                'wallet_account_id' => $walletTransaction->wallet_account_id,
                'amount' => (float) $walletTransaction->amount,
                'currency' => $walletTransaction->currency,
            ], $walletSnapshot);
        }

        if ($manualPaymentRequestModel instanceof ManualPaymentRequest) {
            $transferDetails = TransferDetailsResolver::forManualPaymentRequest($manualPaymentRequestModel)->toArray();
        } elseif ($paymentTransaction instanceof PaymentTransaction) {
            $transferDetails = TransferDetailsResolver::forPaymentTransaction($paymentTransaction)->toArray();
        } else {
            $transferDetails = TransferDetailsResolver::forRow($this->resource)->toArray();
        }


        $serviceRequestRelation = $this->resolveServiceRequestRelation(
            $manualPaymentRequestModel,
            $paymentTransaction,
            $payable
        );

        $orderRelation = $this->resolveOrderRelation(
            $manualPaymentRequestModel,
            $paymentTransaction
        );

        $serviceRequestId = $this->resolveServiceRequestId(
            $manualPaymentRequestModel,
            $serviceRequestRelation,
            $meta,
            $paymentTransactionMeta
        );

        $attachmentsPayload = $this->resolveAttachmentPayload(
            $manualPaymentRequestModel,
            $meta,
            $paymentTransactionMeta
        );

        $manualPaymentSnapshot = array_filter([
            'id' => $this->id,
            'manual_payment_id' => (string) $this->id,
            'reference' => $this->reference,
            'manual_reference' => $manualReference,
            'status' => $this->status,
            'payment_status' => $paymentStatus,
            'amount' => $this->amount !== null ? (float) $this->amount : null,
            'currency' => $this->currency,
            'notes' => $this->user_note,
            'admin_note' => $this->admin_note,
            'payment_gateway' => $gatewayKey,
            'payment_gateway_key' => $canonicalGateway,
            'payment_gateway_label' => $channelLabel,
            'manual_bank_name' => $manualBankName,
            'receipt_url' => $this->generateSignedUrl($this->receipt_path),
            'meta' => $meta,
            'metadata' => $meta,
            'manual_bank' => $manualBankPayload,
            'context' => is_array($meta) ? ($meta['context'] ?? null) : null,
            'payable_type' => $this->payable_type,
            'payable_id' => $this->payable_id,
            'payment_transaction_id' => $paymentTransaction?->id,
            'receipt_no' => $paymentTransaction?->receipt_no,
            'transfer_details' => $transferDetails,
            'store_id' => $this->store_id,
            'store' => $manualPaymentRequestModel?->store ? [
                'id' => $manualPaymentRequestModel->store->id,
                'name' => $manualPaymentRequestModel->store->name,
                'status' => $manualPaymentRequestModel->store->status,
            ] : null,


        ], static fn ($value) => $value !== null && $value !== '');



        return [
            'id' => $this->id,
            'manual_payment_id' => (string) $this->id,


            'user_id' => $this->user_id,
            'manual_bank' => $manualBankPayload,

            'manual_bank_name' => $manualBankName,
            'bank_label' => $manualBankName,
            'amount' => $this->whenNotNull($this->amount, fn () => (float) $this->amount),
            
            'currency' => $this->currency,
            'payment_gateway' => $gatewayKey,

            'payment_gateway_key' => $canonicalGateway,
            'payment_gateway_canonical' => $canonicalGateway,
            'payment_gateway_normalized' => $canonicalGateway,
            'payment_gateway_label' => $channelLabel,
            'payment_gateway_name' => $channelLabel,
            'channel_label' => $channelLabel,


            'reference' => $this->reference,
            'manual_reference' => $manualReference,
            'user_note' => $this->user_note,
            'admin_note' => $this->admin_note,
            'status' => $this->status,
            'payment_status' => $paymentStatus,
            'transaction_status' => $paymentStatus,

            'receipt_url' => $this->generateSignedUrl($this->receipt_path),
            'transaction_id' => $paymentTransaction?->id,
            'payment_transaction_id' => $paymentTransaction?->id,
            'receipt_no' => $paymentTransaction?->receipt_no,
            'service_request_id' => $serviceRequestId,
            'transaction_identifier' => $paymentTransaction?->payment_id
                ?? $paymentTransaction?->payment_signature
                ?? $paymentTransaction?->idempotency_key,
            'meta' => $meta,
            'metadata' => $meta,
            'context' => is_array($meta) ? ($meta['context'] ?? null) : null,
            'manual_payment' => $manualPaymentSnapshot !== [] ? $manualPaymentSnapshot : null,
            'order' => OrderResource::make($orderRelation),
            'order_number' => $this->when(
                $orderRelation instanceof Order,
                static fn () => $orderRelation->order_number
            ),
            'service_request' => ServiceRequestResource::make($serviceRequestRelation),
            'attachments' => AttachmentResource::collection(collect($attachmentsPayload)),
            'transfer_details' => $transferDetails,

            'payable' => $payable ? [
                'id' => $this->payable_id,
                'type' => class_basename($this->payable_type),
                'name' => $payable->name ?? null,
            ] : ($this->payable_id ? [
                'id' => $this->payable_id,
                'type' => class_basename((string) $this->payable_type),
            ] : null),
            'payment_transaction' => $paymentTransaction ? [
                'id' => $paymentTransaction->id,
                'status' => $paymentStatus,
                'amount' => (float) $paymentTransaction->amount,
                'currency' => $paymentTransaction->currency,
                'payment_method' => $paymentTransaction->payment_method,
                'payment_gateway' => $paymentTransaction->payment_gateway,
                'receipt_no' => $paymentTransaction->receipt_no,
                'manual_payment_request_id' => $paymentTransaction->manual_payment_request_id,

                'receipt_url' => $this->generateSignedUrl($paymentTransaction->receipt_path ?? $this->receipt_path),
                'gateway_label' => $transactionLabels['channel_label'],
                'channel_label' => $transactionLabels['channel_label'],
                
                'bank_label' => $transactionLabels['bank_label'],
                'meta' => $paymentTransactionMeta,
                'metadata' => $paymentTransactionMeta,

                'order' => $this->when($order instanceof Order, static function () use ($order) {
                    return [
                        'id' => $order->id,
                        'order_number' => $order->order_number,
                        'payment_status' => $order->payment_status,
                    ];
                }),

                'wallet_transaction' => $walletTransaction instanceof WalletTransaction ? [
                    'id' => $walletTransaction->getKey(),
                    'wallet_account_id' => $walletTransaction->wallet_account_id,
                    'amount' => (float) $walletTransaction->amount,
                    'currency' => $walletTransaction->currency,
                ] : null,


            ] : null,
            'wallet' => empty($walletSnapshot) ? null : $walletSnapshot,
            'reviewed_by' => $this->reviewed_by,
            'reviewed_at' => optional($this->reviewed_at)->toIso8601String(),
            'created_at' => optional($this->created_at)->toIso8601String(),
            'updated_at' => optional($this->updated_at)->toIso8601String(),
            'department' => $this->department ?? null,


        ];
    }

    private function resolveServiceRequestRelation(
        ?ManualPaymentRequest $manualPaymentRequest,
        ?EloquentModel $paymentTransaction,
        mixed $payable
    ): ?ServiceRequest {
        if ($this->relationLoaded('serviceRequest')) {
            $relation = $this->resource->getRelation('serviceRequest');

            if (! $relation instanceof MissingValue && $relation instanceof ServiceRequest) {
                return $relation;
            }
        }

        if ($manualPaymentRequest instanceof ManualPaymentRequest && $manualPaymentRequest->relationLoaded('serviceRequest')) {
            $relation = $manualPaymentRequest->getRelation('serviceRequest');

            if ($relation instanceof ServiceRequest) {
                return $relation;
            }
        }

        if ($payable instanceof ServiceRequest) {
            return $payable;
        }

        if ($paymentTransaction instanceof PaymentTransaction && $paymentTransaction->relationLoaded('payable')) {
            $candidate = $paymentTransaction->payable;

            if ($candidate instanceof ServiceRequest) {
                return $candidate;
            }
        }

        return null;
    }

    private function resolveOrderRelation(
        ?ManualPaymentRequest $manualPaymentRequest,
        ?EloquentModel $paymentTransaction
    ): ?Order {
        if ($this->relationLoaded('order')) {
            $relation = $this->resource->getRelation('order');

            if (! $relation instanceof MissingValue && $relation instanceof Order) {
                return $relation;
            }
        }

        if ($manualPaymentRequest instanceof ManualPaymentRequest && $manualPaymentRequest->relationLoaded('order')) {
            $relation = $manualPaymentRequest->getRelation('order');

            if ($relation instanceof Order) {
                return $relation;
            }
        }

        if ($manualPaymentRequest instanceof ManualPaymentRequest && $manualPaymentRequest->relationLoaded('paymentTransaction')) {
            $transaction = $manualPaymentRequest->getRelation('paymentTransaction');

            if ($transaction instanceof PaymentTransaction && $transaction->relationLoaded('order')) {
                $order = $transaction->order;

                if ($order instanceof Order) {
                    return $order;
                }
            }
        }

        if ($paymentTransaction instanceof PaymentTransaction && $paymentTransaction->relationLoaded('order')) {
            $order = $paymentTransaction->order;

            if ($order instanceof Order) {
                return $order;
            }
        }

        return null;
    }

    private function resolveServiceRequestId(
        ?ManualPaymentRequest $manualPaymentRequest,
        ?ServiceRequest $serviceRequest,
        ?array $meta,
        ?array $paymentTransactionMeta
    ): ?int {
        if ($serviceRequest instanceof ServiceRequest) {
            return (int) $serviceRequest->getKey();
        }

        $direct = $this->service_request_id ?? null;
        if (is_numeric($direct)) {
            return (int) $direct;
        }

        if ($manualPaymentRequest instanceof ManualPaymentRequest) {
            $payableId = $manualPaymentRequest->payable_id;
            $payableType = $manualPaymentRequest->payable_type;

            if (is_numeric($payableId) && is_string($payableType)) {
                $normalized = strtolower(trim($payableType));

                if (str_contains($normalized, 'service')) {
                    return (int) $payableId;
                }
            }
        }

        $metaCandidate = data_get($meta, 'service_request_id')
            ?? data_get($meta, 'service_request.id')
            ?? data_get($paymentTransactionMeta, 'service_request_id')
            ?? data_get($paymentTransactionMeta, 'service.request_id');

        if (is_numeric($metaCandidate)) {
            return (int) $metaCandidate;
        }

        return null;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function resolveAttachmentPayload(
        ?ManualPaymentRequest $manualPaymentRequest,
        ?array $meta,
        ?array $paymentTransactionMeta
    ): array {
        $sources = [
            data_get($meta, 'attachments'),
            data_get($paymentTransactionMeta, 'attachments'),
            data_get($paymentTransactionMeta, 'manual.attachments'),
        ];

        if ($manualPaymentRequest instanceof ManualPaymentRequest && $manualPaymentRequest->relationLoaded('attachments')) {
            $sources[] = $manualPaymentRequest->getRelation('attachments');
        }

        $normalized = [];

        foreach ($sources as $source) {
            $normalized = array_merge($normalized, $this->normalizeAttachmentEntries($source));
        }

        if ($normalized === [] && $manualPaymentRequest instanceof ManualPaymentRequest) {
            $receiptPath = $manualPaymentRequest->receipt_path ?? null;

            if (is_string($receiptPath) && trim($receiptPath) !== '') {
                $normalized[] = array_filter([
                    'type' => 'receipt',
                    'path' => $receiptPath,
                    'disk' => 'public',
                    'url' => $this->generateSignedUrl($receiptPath),
                ], static fn ($value) => $value !== null && $value !== '');
            }
        }

        return $this->deduplicateAttachments($normalized);
    }

    /**
     * @param mixed $attachments
     * @return array<int, array<string, mixed>>
     */
    private function normalizeAttachmentEntries(mixed $attachments): array
    {
        if ($attachments instanceof MissingValue) {
            return [];
        }

        if ($attachments instanceof \Illuminate\Support\Collection) {
            $attachments = $attachments->all();
        }

        if (! is_iterable($attachments)) {
            return [];
        }

        $normalized = [];

        foreach ($attachments as $attachment) {
            $path = $this->stringFromData($attachment, 'path');
            $url = $this->stringFromData($attachment, 'url');

            if ($path === null && $url === null) {
                continue;
            }

            if ($url === null && $path !== null) {
                $url = $this->generateSignedUrl($path);
            }

            $normalized[] = array_filter([
                'type'        => $this->stringFromData($attachment, 'type') ?? 'receipt',
                'name'        => $this->stringFromData($attachment, 'name'),
                'path'        => $path,
                'disk'        => $this->stringFromData($attachment, 'disk'),
                'mime_type'   => $this->stringFromData($attachment, 'mime_type'),
                'size'        => $this->numericFromData($attachment, 'size'),
                'uploaded_at' => $this->stringFromData($attachment, 'uploaded_at'),
                'url'         => $url,
            ], static fn ($value) => $value !== null && $value !== '');
        }

        return $normalized;
    }

    /**
     * @param array<int, array<string, mixed>> $attachments
     * @return array<int, array<string, mixed>>
     */
    private function deduplicateAttachments(array $attachments): array
    {
        $seen = [];
        $unique = [];

        foreach ($attachments as $attachment) {
            $key = $this->attachmentIdentityKey($attachment);

            if ($key !== null) {
                if (isset($seen[$key])) {
                    continue;
                }

                $seen[$key] = true;
            }

            $unique[] = $attachment;
        }

        return $unique;
    }

    /**
     * @param array<string, mixed> $attachment
     */
    private function attachmentIdentityKey(array $attachment): ?string
    {
        $rawPath = $attachment['url'] ?? $attachment['path'] ?? null;

        if (! is_string($rawPath)) {
            return null;
        }

        $path = trim(strtolower($rawPath));

        if ($path === '') {
            return null;
        }

        $type = isset($attachment['type']) && is_string($attachment['type'])
            ? trim(strtolower($attachment['type']))
            : 'attachment';

        return $type . '|' . $path;
    }

    private function stringFromData(mixed $data, string $key): ?string
    {
        $value = data_get($data, $key);

        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function numericFromData(mixed $data, string $key): ?float
    {
        $value = data_get($data, $key);

        if (! is_numeric($value)) {
            return null;
        }

        return (float) $value;
    }

    protected function generateSignedUrl(?string $path): ?string
    {
        if (empty($path)) {
            return null;
        }

        $disk = Storage::disk('public');

        try {
            if (method_exists($disk, 'temporaryUrl')) {
                return $disk->temporaryUrl($path, now()->addMinutes(10));
            }
        } catch (Throwable) {
            // Driver may not support temporary URLs; fall back to standard URL below.
        }

        return url($disk->url($path));
    }



    private function normalizePaymentStatus(?string $status): ?string
    {
        if ($status === null) {
            return null;
        }

        $normalized = strtolower(trim($status));

        return match ($normalized) {
            'pending', 'processing', 'in_progress', 'in-progress', 'awaiting', 'waiting', 'on-hold' => 'pending',
            'succeed', 'success', 'succeeded', 'successful', 'approved', 'completed', 'complete', 'paid', 'done', 'captured' => 'approved',
            'failed', 'fail', 'failure', 'rejected', 'declined', 'denied', 'canceled', 'cancelled', 'void', 'refunded', 'error' => 'rejected',
            default => 'pending',
        };
    }




    /**
     * @param  EloquentModel|null  $manualBank
     * @param  EloquentModel|null  $paymentTransaction
     */
    private function resolveManualBankName($manualBank, $paymentTransaction): ?string
    {
        $aliases = $this->manualBankAliases();

        $meta = is_array($this->meta) ? $this->meta : [];
        $transactionMeta = $paymentTransaction instanceof EloquentModel && is_array($paymentTransaction->meta)
            ? $paymentTransaction->meta
            : [];

        $candidates = [

            data_get($this, 'gateway_display_name'),
            data_get($meta, 'gateway_display_name'),
            data_get($meta, 'manual.gateway_display_name'),
            data_get($transactionMeta, 'gateway_display_name'),
            data_get($transactionMeta, 'manual.gateway_display_name'),
            data_get($this, 'manual_bank_name'),
            data_get($this, 'bank_name'),
            data_get($this, 'bank_account_name'),
            data_get($meta, 'manual.bank.name'),
            data_get($meta, 'manual.bank.bank_name'),
            data_get($meta, 'manual.bank.beneficiary_name'),
            data_get($meta, 'manual_bank.name'),
            data_get($meta, 'manual_bank.bank_name'),
            data_get($meta, 'manual_bank.beneficiary_name'),
            data_get($meta, 'payload.bank_name'),
            data_get($meta, 'payload.bank.name'),
            data_get($transactionMeta, 'manual.bank.name'),
            data_get($transactionMeta, 'manual.bank.bank_name'),
            data_get($transactionMeta, 'manual.bank.beneficiary_name'),
            data_get($meta, 'bank.name'),
            data_get($meta, 'bank.bank_name'),
            data_get($meta, 'bank.beneficiary_name'),
            data_get($transactionMeta, 'manual_bank.name'),
            data_get($transactionMeta, 'manual_bank.bank_name'),
            data_get($transactionMeta, 'manual_bank.beneficiary_name'),
            data_get($transactionMeta, 'bank.name'),
            data_get($transactionMeta, 'bank.bank_name'),
            data_get($transactionMeta, 'bank.beneficiary_name'),
            data_get($transactionMeta, 'payload.bank_name'),
            data_get($transactionMeta, 'payload.bank.name'),
            data_get($manualBank, 'name'),
            data_get($manualBank, 'bank_name'),
            data_get($manualBank, 'beneficiary_name'),
        ];

        foreach ($candidates as $candidate) {
            $resolved = $this->sanitizeManualBankName($candidate, $aliases);

            if ($resolved !== null) {
                return $resolved;
            }
        }

        return null;
    }

    /**
     * @param  EloquentModel|null  $paymentTransaction
     */
    private function resolvePaymentGatewayLabel(
        ?string $canonicalGateway,
        ?string $manualBankName,
        mixed $rawGateway,
        $paymentTransaction
    ): string {
        $canonicalGateway = $canonicalGateway ?? 'manual_banks';
        $aliases = $this->manualBankAliases();

        $meta = is_array($this->meta) ? $this->meta : [];
        $transactionMeta = $paymentTransaction instanceof EloquentModel && is_array($paymentTransaction->meta)
            ? $paymentTransaction->meta
            : [];

        $candidates = [];

        if ($manualBankName !== null) {
            $candidates[] = $manualBankName;
        }

        $candidates = array_merge($candidates, [
            data_get($this, 'gateway_display_name'),
            data_get($this, 'payment_gateway_label'),
            data_get($this, 'payment_gateway_name'),
            data_get($this, 'gateway_name'),
            data_get($meta, 'gateway_display_name'),
            data_get($meta, 'payment_gateway_label'),
            data_get($meta, 'payment_gateway_name'),
            data_get($meta, 'gateway_name'),
            data_get($meta, 'manual.gateway_display_name'),
            data_get($meta, 'manual.gateway_name'),
            data_get($meta, 'payload.bank_name'),
            data_get($transactionMeta, 'gateway_display_name'),
            data_get($transactionMeta, 'payment_gateway_label'),
            data_get($transactionMeta, 'payment_gateway_name'),
            data_get($transactionMeta, 'gateway_name'),
            data_get($transactionMeta, 'manual.gateway_display_name'),
            data_get($transactionMeta, 'manual.gateway_name'),
            data_get($transactionMeta, 'payload.bank_name'),
        ]);

        foreach ($candidates as $candidate) {
            $resolved = $this->sanitizeManualBankName($candidate, $aliases);

            if ($resolved !== null) {
                return $resolved;
            }
        }

        return match ($canonicalGateway) {
            'manual_banks' => $manualBankName ?? ManualBank::defaultDisplayName(),
            'east_yemen_bank' => $manualBankName ?? __('East Yemen Bank'),
            'wallet' => $manualBankName ?? __('Wallet'),
            'cash' => __('Cash'),
            default => $this->fallbackGatewayLabel($rawGateway),
        };
    }

    private function fallbackGatewayLabel(mixed $rawGateway): string
    {
        if (is_string($rawGateway) && trim($rawGateway) !== '') {
            return Str::of($rawGateway)
                ->replace(['_', '-'], ' ')
                ->trim()
                ->title()
                ->value();
        }

        return __('Bank Transfer');
    }

    private function sanitizeManualBankName(mixed $value, array $aliases): ?string
    {
        if ($value === null) {
            return null;
        }

        if (! is_string($value) && ! is_numeric($value)) {
            return null;
        }

        $string = trim((string) $value);

        if ($string === '') {
            return null;
        }

        $normalized = strtolower($string);

        if (in_array($normalized, $aliases, true)) {
            return null;
        }

        return $string;
    }

    /**
     * @return array<int, string>
     */
    private function manualBankAliases(): array
    {
        $aliases = array_merge(
            (array) ManualPaymentRequest::manualBankGatewayAliases(),
            (array) ManualPaymentRequest::walletGatewayAliases(),
            
            [
                'manual bank',
                'manual banks',
                'manual bank transfer',
                'manual banks transfer',
                'bank manual',
                'bank manual transfer',
                'manual transfer',
                'manual transfers',
                'bank transfer',
                'bank transfers',
                'wallet',
                'المحفظة',
                'تحويل بنكي',

            ]
        );

        $normalized = array_values(array_filter(array_map(static function ($alias) {
            if (! is_string($alias)) {
                return null;
            }

            $value = strtolower(trim($alias));


            return $value === '' ? null : $value;
        }, $aliases)));

        if ($normalized === []) {
            return ['manual_bank', 'manual_banks'];
        }

        return array_values(array_unique($normalized));
    
    }

    public function offsetExists($offset): bool
    {
        if (! is_string($offset) && ! is_int($offset)) {
            return false;
        }

        $resource = $this->resource;

        if (is_array($resource)) {
            return array_key_exists($offset, $resource);
        }

        if ($resource instanceof ArrayAccess) {
            try {
                return $resource->offsetExists($offset);
            } catch (Throwable) {
                return false;
            }
        }

        if (is_object($resource)) {
            try {
                return isset($resource->{$offset});
            } catch (Throwable) {
                return false;
            }
        }

        return false;
    }

    public function offsetGet($offset): mixed
    {
        if (! is_string($offset) && ! is_int($offset)) {
            return null;
        }

        $resource = $this->resource;

        if (is_array($resource)) {
            return $resource[$offset] ?? null;
        }

        if ($resource instanceof ArrayAccess) {
            try {
                return $resource[$offset];
            } catch (Throwable) {
                return null;
            }
        }

        if (is_object($resource)) {
            try {
                return $resource->{$offset} ?? null;
            } catch (Throwable) {
                return null;
            }
        }

        return null;
    }

}
