@extends('layouts.main')

@php
    use App\Models\ManualPaymentRequest;
    use App\Models\PaymentTransaction;

    $manualPayment = $manualPaymentRequest instanceof ManualPaymentRequest ? $manualPaymentRequest : null;
    $transaction = $paymentTransaction instanceof PaymentTransaction ? $paymentTransaction : null;

    $displayReference = $manualPayment?->reference
        ?? $transaction?->payment_id
        ?? __('Service Request #:id', ['id' => $serviceRequest->id]);

    $submittedAt = $manualPayment?->created_at
        ?? $transaction?->created_at
        ?? $serviceRequest->created_at;

    $submittedLabel = $submittedAt
        ? __('Submitted :date', ['date' => $submittedAt->format('Y-m-d H:i')])
        : __('Submitted :date', ['date' => __('N/A')]);

    $requesterName = $applicant?->name ?? __('Unknown User');

    $normalizedStatus = $manualPayment
        ? ManualPaymentRequest::normalizeStatus($manualPayment->status) ?? $manualPayment->status
        : null;

    $statusBadge = match ($normalizedStatus) {
        ManualPaymentRequest::STATUS_APPROVED => '<span class="badge bg-success">' . __('Approved') . '</span>',
        ManualPaymentRequest::STATUS_REJECTED => '<span class="badge bg-danger">' . __('Rejected') . '</span>',
        ManualPaymentRequest::STATUS_UNDER_REVIEW => '<span class="badge bg-info text-dark">' . __('Under Review') . '</span>',
        ManualPaymentRequest::STATUS_PENDING => '<span class="badge bg-warning text-dark">' . __('Pending') . '</span>',
        default => $manualPayment
            ? '<span class="badge bg-secondary">' . e($manualPayment->status ?? __('Pending')) . '</span>'
            : '<span class="badge bg-secondary">' . __('Pending') . '</span>',
    };

    $amountValue = $manualPayment?->amount ?? $transaction?->amount;
    $amountDisplay = is_numeric($amountValue)
        ? number_format((float) $amountValue, 2)
        : null;
    $currencyCode = $manualPayment?->currency
        ?? $transaction?->currency
        ?? config('app.currency', 'SAR');

    $paymentReviewUrl = ($manualPayment instanceof ManualPaymentRequest && $manualPayment->exists)
        ? route('payment-requests.review', $manualPayment)
        : null;
@endphp

@section('title')
    {{ __('Service Payment Review') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted mb-0">
                    {{ __('Review the payment details associated with this service request.') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                <nav aria-label="breadcrumb" class="breadcrumb-header float-end float-lg-end">
                    <ol class="breadcrumb mb-0">
                        <li class="breadcrumb-item">
                            <a href="{{ route('service.requests.show', $serviceRequest->id) }}" class="btn btn-outline-primary">
                                <i class="bi bi-arrow-left"></i> {{ __('Back to Request') }}
                            </a>
                        </li>
                        <li class="breadcrumb-item">
                            <span class="badge bg-light text-dark border">{{ __('Request #:id', ['id' => $serviceRequest->id]) }}</span>
                        </li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card shadow-sm">
            <div class="card-header bg-white d-flex flex-wrap justify-content-between align-items-start gap-3">
                <div>
                    <h5 class="card-title mb-1">{{ $displayReference }}</h5>
                    <div class="text-muted small">
                        {{ $submittedLabel }}
                        &bull;
                        {{ __('By :name', ['name' => $requesterName]) }}
                    </div>
                </div>
                <div class="text-end">
                    {!! $statusBadge !!}
                    <div class="mt-2 fw-semibold">
                        @if($amountDisplay !== null)
                            {{ $amountDisplay }} {{ $currencyCode }}
                        @else
                            {{ __('N/A') }}
                        @endif
                    </div>
                    @if($paymentReviewUrl)
                        <a href="{{ $paymentReviewUrl }}" class="btn btn-sm btn-outline-secondary mt-2">
                            <i class="fa fa-up-right-from-square me-1"></i>{{ __('Open in Payment Review') }}
                        </a>
                    @endif
                </div>
            </div>
            <div class="card-body">
                @if($hasPaymentContext && isset($manualPayment) && $manualPayment instanceof ManualPaymentRequest && filled($serviceRequest->payment_status))
                    @include('payments.manual.show', [
                        'request' => $manualPayment,
                        'canReview' => $canReviewPayment,
                        'timelineData' => $timelineData ?? [],
                        'paymentGatewayKey' => $presentation['paymentGatewayKey'] ?? null,
                        'paymentGatewayCanonical' => $presentation['paymentGatewayCanonical'] ?? null,
                        'paymentGatewayLabel' => $presentation['paymentGatewayLabel'] ?? null,
                        'departmentLabel' => $presentation['departmentLabel'] ?? null,
                        'manualBankName' => $presentation['manualBankName'] ?? null,
                        'transferDetails' => $presentation['transferDetails'] ?? null,
                        'paymentTransaction' => $transaction,
                        'readOnly' => ! $canReviewPayment,
                    ])

                    @include('payments.manual.partials.payable-summary', [
                        'request' => $manualPayment,
                    ])

                    @include('payments.manual.partials.receipt', [
                        'request' => $manualPayment,
                        'paymentTransaction' => $transaction,
                    ])

                    @include('payments.manual.partials.status-timeline', [
                        'request' => $manualPayment,
                        'timelineData' => $timelineData ?? [],
                        'timelineEndpoint' => $timelineEndpoint,
                    ])
                @elseif($hasPaymentContext && filled($serviceRequest->payment_status))
                    <div class="alert alert-info mb-0" role="alert">
                        <i class="fa fa-circle-info me-2"></i>{{ __('تم تأكيد الدفع لهذه الخدمة، لكن تفاصيل التحويل اليدوي غير متاحة حالياً.') }}
                    </div>
                @else
                    <div class="alert alert-warning mb-0" role="alert">
                        <i class="fa fa-circle-info me-2"></i>{{ __('لا يوجد دفع مرتبط.') }}
                    </div>
                @endif
            </div>
        </div>
    </section>
@endsection

@push('scripts')
    <script>
        $(document).on('submit', '.manual-payment-action', function (event) {
            event.preventDefault();

            const form = $(this);
            const submitButton = form.find('button[type="submit"]');
            const url = form.attr('action');
            const formData = new FormData(this);
            const shouldReload = form.data('reload-on-success') === true || form.data('reload-on-success') === 'true';

            ajaxRequest('POST', url, formData, function () {
                submitButton.prop('disabled', true).addClass('disabled');
            }, function (response) {
                showSuccessToast(response.message);

                if (shouldReload) {
                    setTimeout(function () {
                        window.location.reload();
                    }, 600);
                }
            }, function (error) {
                showErrorToast(error.message || '{{ __('Something went wrong') }}');
            }, function () {
                if (!shouldReload) {
                    submitButton.prop('disabled', false).removeClass('disabled');
                }
            });
        });
    </script>
@endpush
