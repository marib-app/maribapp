<?php

namespace App\Http\Controllers\Concerns;

use App\Models\Item;
use App\Models\ManualPaymentRequest;
use App\Models\ManualPaymentRequestHistory;
use App\Models\Order;
use App\Models\PaymentTransaction;
use App\Models\WalletTransaction;
use App\Support\ManualPayments\ManualPaymentPresentationHelpers;
use App\Support\ManualPayments\TransferDetailsResolver;
use App\Support\Payments\PaymentLabelService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;

trait ManualPaymentViewHelpers
{
    use ManualPaymentPresentationHelpers;

    protected function manualPaymentRequestPresentationData(ManualPaymentRequest $manualPaymentRequest): array
    {
        $manualPaymentRequest->loadMissing('manualBank');

        $paymentGatewayCanonical = $this->resolveManualPaymentGatewayKey($manualPaymentRequest);
        $paymentGatewayKey = $paymentGatewayCanonical;

        $labels = PaymentLabelService::forManualPaymentRequest($manualPaymentRequest);
        $paymentGatewayLabel = $labels['gateway_label'];
        $manualBankName = $labels['bank_name'];

        if (! empty($labels['gateway_key'])) {
            $paymentGatewayKey = $labels['gateway_key'];
            $paymentGatewayCanonical = $labels['gateway_key'];
        }

        $departmentLabel = $this->paymentRequestDepartmentLabel($manualPaymentRequest->department ?? null);
        $transferDetails = TransferDetailsResolver::forManualPaymentRequest($manualPaymentRequest)->toArray();

        return compact(
            'paymentGatewayKey',
            'paymentGatewayCanonical',
            'paymentGatewayLabel',
            'departmentLabel'
        ) + [
            'manualBankName' => $manualBankName,
            'transferDetails' => $transferDetails,
        ];
    }

    protected function manualPaymentTimelinePayload(ManualPaymentRequest $manualPaymentRequest): array
    {
        $manualPaymentRequest->loadMissing(['histories.user', 'user']);

        $iconMap = $this->manualPaymentStatusIconMap();
        $timeline = [];

        $submissionDocumentValidUntil = data_get($manualPaymentRequest->meta, 'document.valid_until');
        $submissionDocumentDate = $this->parseDateOrNull($submissionDocumentValidUntil);

        $timeline[] = [
            'id' => 'submission-' . $manualPaymentRequest->id,
            'status' => ManualPaymentRequest::STATUS_PENDING,
            'status_label' => trans('Awaiting review'),
            'icon' => $iconMap['submitted'] ?? $iconMap[ManualPaymentRequest::STATUS_PENDING],
            'note' => $manualPaymentRequest->user_note,
            'document_valid_until' => $submissionDocumentDate?->toDateString(),
            'document_valid_until_human' => $submissionDocumentDate?->format('Y-m-d'),
            'document_valid_label' => $submissionDocumentDate
                ? trans('Document valid until :date', ['date' => $submissionDocumentDate->format('Y-m-d')])
                : null,
            'created_at' => $manualPaymentRequest->created_at?->toIso8601String(),
            'created_at_human' => $manualPaymentRequest->created_at?->format('Y-m-d H:i'),
            'actor' => $manualPaymentRequest->user?->name ?? trans('Requester'),
            'attachment_url' => null,
            'attachment_name' => null,
            'attachment_label' => null,
            'notification_sent' => false,
            'notification_label' => null,
            'is_current' => false,
        ];

        $manualPaymentRequest->histories
            ->sortBy('created_at')
            ->each(function (ManualPaymentRequestHistory $history) use (&$timeline, $iconMap) {
                $normalizedStatus = $this->normalizeManualPaymentStatus($history->status) ?? $history->status;
                $documentValidUntil = data_get($history->meta, 'document_valid_until');
                $documentDate = $this->parseDateOrNull($documentValidUntil);
                $attachmentUrl = $history->attachment_url;
                $attachmentName = data_get($history->meta, 'attachment_name');
                $notificationSent = (bool) data_get($history->meta, 'notification_sent');

                $timeline[] = [
                    'id' => 'history-' . $history->id,
                    'status' => $normalizedStatus,
                    'status_label' => $this->manualPaymentStatusLabel($normalizedStatus),
                    'icon' => $iconMap[$normalizedStatus] ?? $iconMap['default'],
                    'note' => $history->note,
                    'document_valid_until' => $documentDate?->toDateString(),
                    'document_valid_until_human' => $documentDate?->format('Y-m-d'),
                    'document_valid_label' => $documentDate
                        ? trans('Document valid until :date', ['date' => $documentDate->format('Y-m-d')])
                        : null,
                    'created_at' => $history->created_at?->toIso8601String(),
                    'created_at_human' => $history->created_at?->format('Y-m-d H:i'),
                    'actor' => $history->user?->name ?? trans('System'),
                    'attachment_url' => $attachmentUrl,
                    'attachment_name' => $attachmentName,
                    'attachment_label' => $attachmentUrl
                        ? ($attachmentName ? Str::limit($attachmentName, 40) : trans('View attachment'))
                        : null,
                    'notification_sent' => $notificationSent,
                    'notification_label' => $notificationSent ? trans('Notification sent') : null,
                    'is_current' => false,
                ];
            });

        $currentStatus = $this->normalizeManualPaymentStatus($manualPaymentRequest->status)
            ?? ManualPaymentRequest::STATUS_PENDING;
        $lastMatchingIndex = null;

        foreach ($timeline as $index => $entry) {
            if (($entry['status'] ?? null) === $currentStatus) {
                $lastMatchingIndex = $index;
            }
        }

        if ($lastMatchingIndex === null && $currentStatus === ManualPaymentRequest::STATUS_PENDING) {
            $lastMatchingIndex = 0;
        }

        if ($lastMatchingIndex !== null) {
            $timeline[$lastMatchingIndex]['is_current'] = true;
        }

        $lastUpdatedAt = collect([
            $manualPaymentRequest->created_at,
            ...$manualPaymentRequest->histories->pluck('created_at')->all(),
        ])->filter()->sortDesc()->first();

        return [
            'request_id' => $manualPaymentRequest->id,
            'current_status' => $currentStatus,
            'current_status_label' => $this->manualPaymentStatusLabel($currentStatus),
            'current_status_icon' => $this->manualPaymentStatusIcon($currentStatus),
            'current_status_badge' => $this->manualPaymentStatusBadge($currentStatus),
            'timeline' => $timeline,
            'last_updated_at' => $lastUpdatedAt?->toIso8601String(),
            'last_updated_at_human' => $lastUpdatedAt?->format('Y-m-d H:i'),
            'poll_interval' => 8000,
            'empty_message' => trans('No status updates yet.'),
            'error_message' => trans('Unable to refresh the status timeline right now.'),
        ];
    }

    protected function loadManualPaymentRequestRelations(ManualPaymentRequest $manualPaymentRequest): ManualPaymentRequest
    {
        $manualPaymentRequest->load([
            'user',
            'manualBank',
            'paymentTransaction.order.user',
            'paymentTransaction.order.coupon',
            'paymentTransaction.walletTransaction.walletAccount.user',
            'paymentTransaction.payable',
            'histories.user',
            'reviewer',
            'payable',
        ]);

        $paymentTransaction = $manualPaymentRequest->paymentTransaction;
        $payable = $manualPaymentRequest->payable;

        if ($payable === null && $paymentTransaction) {
            if ($paymentTransaction->order) {
                $manualPaymentRequest->setRelation('payable', $paymentTransaction->order);
                $payable = $paymentTransaction->order;
            } elseif ($paymentTransaction->payable instanceof Model) {
                $manualPaymentRequest->setRelation('payable', $paymentTransaction->payable);
                $payable = $paymentTransaction->payable;
            }
        }

        if ($payable instanceof Order) {
            $payable->loadMissing(['user', 'seller', 'coupon']);
        } elseif ($payable instanceof Item) {
            $payable->loadMissing(['user', 'category']);
        } elseif ($payable instanceof WalletTransaction) {
            $payable->loadMissing(['walletAccount.user']);
        }

        return $manualPaymentRequest;
    }

    protected function makeManualPaymentRequestFromTransaction(PaymentTransaction $paymentTransaction): ManualPaymentRequest
    {
        $paymentTransaction->loadMissing([
            'user',
            'order.user',
            'walletTransaction.walletAccount.user',
            'payable',
        ]);

        $manualPaymentRequest = ManualPaymentRequest::make([
            'user_id' => $paymentTransaction->user_id,
            'payable_type' => $paymentTransaction->payable_type,
            'payable_id' => $paymentTransaction->payable_id,
            'amount' => (float) ($paymentTransaction->amount ?? 0),
            'currency' => $paymentTransaction->currency
                ?? ($paymentTransaction->order?->currency ?? config('app.currency', 'SAR')),
            'reference' => $paymentTransaction->payment_id
                ?? $paymentTransaction->payment_signature
                ?? (string) $paymentTransaction->getKey(),
            'status' => $this->mapTransactionStatusToManualPaymentStatus($paymentTransaction->payment_status),
            'meta' => is_array($paymentTransaction->meta) ? $paymentTransaction->meta : [],
        ]);

        $manualPaymentRequest->setAttribute(
            'id',
            $paymentTransaction->manual_payment_request_id ?? $paymentTransaction->getKey()
        );
        $manualPaymentRequest->setAttribute('payment_transaction_id', $paymentTransaction->getKey());
        $manualPaymentRequest->setAttribute('created_at', $paymentTransaction->created_at);
        $manualPaymentRequest->setAttribute('updated_at', $paymentTransaction->updated_at);

        $manualPaymentRequest->setRelation('paymentTransaction', $paymentTransaction);
        $manualPaymentRequest->setRelation('user', $paymentTransaction->user);
        $manualPaymentRequest->setRelation('manualBank', null);
        $manualPaymentRequest->setRelation('histories', Collection::make());

        if ($paymentTransaction->payable instanceof Model) {
            $manualPaymentRequest->setRelation('payable', $paymentTransaction->payable);
        } elseif ($paymentTransaction->order instanceof Model) {
            $manualPaymentRequest->setRelation('payable', $paymentTransaction->order);
        } elseif ($paymentTransaction->walletTransaction instanceof Model) {
            $manualPaymentRequest->setRelation('payable', $paymentTransaction->walletTransaction);
        }

        return $manualPaymentRequest;
    }

    protected function mapTransactionStatusToManualPaymentStatus(?string $status): string
    {
        return match ($this->normalizePaymentRequestStatus($status) ?? 'pending') {
            'succeed' => ManualPaymentRequest::STATUS_APPROVED,
            'failed' => ManualPaymentRequest::STATUS_REJECTED,
            default => ManualPaymentRequest::STATUS_PENDING,
        };
    }

    protected function normalizePaymentRequestStatus($status): ?string
    {
        if (!is_string($status)) {
            return null;
        }

        $normalized = strtolower(trim($status));

        if ($normalized === '' || $normalized === 'null') {
            return null;
        }

        return match ($normalized) {
            'succeed', 'success', 'succeeded', 'paid', 'approved', 'complete', 'completed', 'done', 'settled', 'confirmed' => 'succeed',
            'failed', 'failure', 'error', 'cancelled', 'canceled', 'rejected', 'declined', 'void', 'refunded' => 'failed',
            'pending', 'processing', 'in_review', 'in-review', 'review', 'reviewing', 'under_review', 'under-review', 'awaiting', 'waiting', 'new', 'initiated', 'open' => 'pending',
            default => in_array($normalized, ['pending', 'succeed', 'failed'], true) ? $normalized : null,
        };
    }
}