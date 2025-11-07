@php
    $manualPayment = $request instanceof \App\Models\ManualPaymentRequest ? $request : null;
    $paymentTransaction = $transaction instanceof \App\Models\PaymentTransaction ? $transaction : null;

    $reference = \App\Support\Payments\ReferencePresenter::forManualRequest($manualPayment, $paymentTransaction)
        ?? ($manualPayment?->getKey() ? __('Manual Payment #:id', ['id' => $manualPayment->getKey()]) : __('Manual Payment'));

    $submittedAt = $manualPayment?->created_at ?? $paymentTransaction?->created_at;

    $amountRaw = $manualPayment?->amount ?? $expectedAmount ?? null;
    $currencyRaw = $manualPayment?->currency
        ?? $expectedCurrency
        ?? config('app.currency', 'SAR');

    $amountDisplay = $amountRaw !== null
        ? number_format((float) $amountRaw, 2) . ' ' . $currencyRaw
        : __('N/A');

    $gatewayDisplay = null;
    foreach (['gateway_label', 'channel_label', 'bank_label'] as $labelKey) {
        $candidate = $paymentLabels[$labelKey] ?? null;
        if (is_string($candidate) && trim($candidate) !== '') {
            $gatewayDisplay = trim($candidate);
            break;
        }
    }

    $bankName = $paymentLabels['bank_name'] ?? null;

    $normalizedStatus = \App\Models\ManualPaymentRequest::normalizeStatus($manualPayment?->status ?? null)
        ?? \App\Models\ManualPaymentRequest::STATUS_PENDING;
    $statusBadgeClass = match ($normalizedStatus) {
        \App\Models\ManualPaymentRequest::STATUS_APPROVED => 'badge bg-success',
        \App\Models\ManualPaymentRequest::STATUS_REJECTED => 'badge bg-danger',
        \App\Models\ManualPaymentRequest::STATUS_UNDER_REVIEW => 'badge bg-info text-dark',
        default => 'badge bg-warning text-dark',
    };

    $statusDisplay = $paymentStatusLabel ?? __('Pending');

    $transactionIdDisplay = $transactionId ?? \App\Support\Payments\ReferencePresenter::forTransaction($paymentTransaction);
@endphp

<div class="row g-3">
    <div class="col-lg-4">
        <label class="form-label fw-semibold text-muted">{{ __('Reference') }}</label>
        <div class="fw-semibold">{{ $reference }}</div>
        @if($submittedAt)
            <div class="small text-muted">
                {{ __('Submitted :date', ['date' => $submittedAt->format('Y-m-d H:i')]) }}
            </div>
        @endif
    </div>
    <div class="col-lg-4">
        <label class="form-label fw-semibold text-muted">{{ __('Amount') }}</label>
        <div class="fw-semibold">{{ $amountDisplay }}</div>
        <div class="d-flex flex-wrap gap-2 mt-2">
            @if($gatewayDisplay)
                <span class="badge bg-light text-dark border">{{ $gatewayDisplay }}</span>
            @endif
            @if($bankName && $bankName !== $gatewayDisplay)
                <span class="badge bg-light text-dark border">{{ $bankName }}</span>
            @endif
        </div>
    </div>
    <div class="col-lg-4">
        <label class="form-label fw-semibold text-muted">{{ __('Status') }}</label>
        <div>
            <span class="{{ $statusBadgeClass }}">{{ $statusDisplay }}</span>
        </div>
        @if($transactionIdDisplay)
            <div class="small text-muted mt-1">
                {{ __('Transaction') }}: {{ $transactionIdDisplay }}
            </div>
        @endif
    </div>
</div>

@if(!empty($manualPaymentReviewUrl))
    <div class="d-flex flex-wrap gap-2 mt-3">
        <a href="{{ $manualPaymentReviewUrl }}" class="btn btn-outline-secondary btn-sm" target="_blank" rel="noopener">
            <i class="fa fa-up-right-from-square me-1"></i>{{ __('Open in Payment Review') }}
        </a>
    </div>
@endif
