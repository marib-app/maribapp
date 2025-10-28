@extends('layouts.main')

@php
    use App\Models\ManualPaymentRequest;
    use App\Models\PaymentTransaction;

    $manualPayment = $manualPaymentRequest instanceof ManualPaymentRequest ? $manualPaymentRequest : null;
    $transaction = $paymentTransaction instanceof PaymentTransaction ? $paymentTransaction : null;

    $serviceTitle = $service?->title ?? __('Service #:id', ['id' => $serviceRequest->service_id]);
    $statusMap = [
        'review'   => ['label' => __('Under Review'), 'class' => 'badge bg-warning text-dark'],
        'approved' => ['label' => __('Approved'), 'class' => 'badge bg-success'],
        'rejected' => ['label' => __('Rejected'), 'class' => 'badge bg-danger'],
        'sold out' => ['label' => __('Sold Out'), 'class' => 'badge bg-secondary'],
    ];

    $statusInfo = $statusMap[$serviceRequest->status] ?? [
        'label' => \Illuminate\Support\Str::of($serviceRequest->status ?? '')->replace('_', ' ')->headline(),
        'class' => 'badge bg-secondary',
    ];

    $amountDisplay = $expectedAmount !== null
        ? number_format((float) $expectedAmount, 2) . ' ' . ($expectedCurrency ?? '')
        : __('N/A');

    $gatewayLabel = null;
    foreach (['gateway_label', 'channel_label', 'bank_label'] as $labelKey) {
        $candidate = $paymentLabels[$labelKey] ?? null;
        if (is_string($candidate) && trim($candidate) !== '') {
            $gatewayLabel = trim($candidate);
            break;
        }
    }

    $manualPaymentReviewUrl = $manualPayment && $manualPayment->exists
        ? route('payment-requests.review', $manualPayment)
        : null;

    $transactionIdDisplay = $transaction?->payment_id
        ?? $transaction?->payment_signature
        ?? ($serviceRequest->payment_transaction_id ? ('#' . $serviceRequest->payment_transaction_id) : null);

    $fieldEntries = is_array($fieldEntries ?? null) ? $fieldEntries : [];
    $attachmentEntries = is_array($attachmentEntries ?? null) ? $attachmentEntries : [];
    $timelineData = is_array($timelineData ?? null) ? $timelineData : [];

    $paymentInstruction = is_string($paymentInstruction ?? null) ? trim($paymentInstruction) : null;
    if ($paymentInstruction === '') {
        $paymentInstruction = null;
    }

    $paymentStatusLabel = $paymentStatusLabel
        ?? ($serviceRequest->payment_status ? __($serviceRequest->payment_status) : __('Not provided'));

    $actionFlags = is_array($actionFlags ?? null) ? $actionFlags : [];
    $canApprove = $actionFlags['approve'] ?? false;
    $canReject = $actionFlags['reject'] ?? false;
@endphp

@section('title')
    {{ __('Service Request Review') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted mb-0">
                    {{ __('Review the submitted information, confirm payment, and respond to the requester.') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                <div class="d-flex flex-wrap justify-content-md-end gap-2">
                    <a href="{{ route('service.requests.index') }}" class="btn btn-outline-primary">
                        <i class="bi bi-arrow-left"></i> {{ __('Back to Requests') }}
                    </a>
                    @if($manualPaymentReviewUrl)
                        <a href="{{ $manualPaymentReviewUrl }}" class="btn btn-outline-secondary" target="_blank" rel="noopener">
                            <i class="fa fa-up-right-from-square me-1"></i>{{ __('Open Payment Review') }}
                        </a>
                    @endif
                </div>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-4">
            <div class="col-12 col-xl-8">
                <div class="card mb-4">
                    <div class="card-header border-bottom">
                        <h5 class="card-title mb-0">{{ __('Request Summary') }}</h5>
                    </div>
                    <div class="card-body">
                        <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center gap-3">
                            <div>
                                <h4 class="mb-1">{{ $serviceTitle }}</h4>
                                <div class="small text-muted">
                                    {{ __('Request ID') }}: {{ $serviceRequest->id }}
                                    @if($serviceRequest->service_id)
                                        &nbsp;•&nbsp; {{ __('Service ID') }}: {{ $serviceRequest->service_id }}
                                    @endif
                                </div>
                                @if($category)
                                    <div class="small text-muted mt-1">
                                        {{ __('Category') }}: {{ $category->name }}
                                        @if($category->id)
                                            <span class="text-muted">(ID: {{ $category->id }})</span>
                                        @endif
                                    </div>
                                @endif
                            </div>
                            <div class="text-md-end">
                                <span class="{{ $statusInfo['class'] }}">{{ $statusInfo['label'] }}</span>
                                @if($serviceRequest->trashed())
                                    <span class="badge bg-dark ms-1">{{ __('Archived') }}</span>
                                @endif
                                <div class="mt-3">
                                    <div class="fw-semibold fs-5">{{ $amountDisplay }}</div>
                                    <div class="small text-muted">{{ __('Amount Due') }}</div>
                                    @if($gatewayLabel)
                                        <div class="mt-2">
                                            <span class="badge bg-light text-dark border">{{ $gatewayLabel }}</span>
                                        </div>
                                    @endif
                                </div>
                                <div class="small text-muted mt-2">
                                    {{ __('Payment Status') }}: {{ $paymentStatusLabel }}
                                </div>
                            </div>
                        </div>

                        <div class="row g-3 mt-3">
                            <div class="col-md-6">
                                <label class="form-label fw-semibold text-muted">{{ __('Created At') }}</label>
                                <div>{{ optional($serviceRequest->created_at)->format('Y-m-d H:i') ?? '—' }}</div>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold text-muted">{{ __('Last Updated') }}</label>
                                <div>{{ optional($serviceRequest->updated_at)->format('Y-m-d H:i') ?? '—' }}</div>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold text-muted">{{ __('Payment Transaction') }}</label>
                                <div>
                                    @if($transactionIdDisplay)
                                        {{ $transactionIdDisplay }}
                                    @else
                                        <span class="text-muted">—</span>
                                    @endif
                                </div>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold text-muted">{{ __('Note from Applicant') }}</label>
                                <div>
                                    @if($serviceRequest->note)
                                        <span class="text-wrap">{!! nl2br(e($serviceRequest->note)) !!}</span>
                                    @else
                                        <span class="text-muted">—</span>
                                    @endif
                                </div>
                            </div>
                        </div>

                        @if($serviceRequest->rejected_reason)
                            <div class="alert alert-danger mt-4 mb-0" role="alert">
                                <i class="fa fa-circle-info me-2"></i>
                                {{ __('Rejected Reason') }}: {!! nl2br(e($serviceRequest->rejected_reason)) !!}
                            </div>
                        @endif

                        @if($paymentInstruction)
                            <div class="alert alert-info mt-4 mb-0" role="alert">
                                <i class="fa fa-info-circle me-2"></i>{{ $paymentInstruction }}
                            </div>
                        @endif
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header border-bottom d-flex flex-wrap justify-content-between align-items-center gap-2">
                        <h5 class="card-title mb-0">{{ __('Payment Details') }}</h5>
                        <span class="badge bg-light text-dark border">{{ $paymentStatusLabel }}</span>
                    </div>
                    <div class="card-body d-grid gap-4">
                        <div class="row g-3">
                            <div class="col-md-4">
                                <label class="form-label fw-semibold text-muted">{{ __('Amount') }}</label>
                                <div class="fw-semibold">{{ $amountDisplay }}</div>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label fw-semibold text-muted">{{ __('Payment Method') }}</label>
                                <div>{{ $gatewayLabel ?? __('Not provided') }}</div>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label fw-semibold text-muted">{{ __('Transaction') }}</label>
                                <div>{{ $transactionIdDisplay ?? __('Not provided') }}</div>
                            </div>
                        </div>

                        @isset($manualPayment)
                            @include('payments.manual.partials.summary', [
                                'request' => $manualPayment,
                                'transaction' => $transaction,
                                'paymentLabels' => $paymentLabels,
                                'expectedAmount' => $expectedAmount,
                                'expectedCurrency' => $expectedCurrency,
                                'paymentStatusLabel' => $paymentStatusLabel,
                                'manualPaymentReviewUrl' => $manualPaymentReviewUrl,
                                'transactionId' => $transactionIdDisplay,
                            ])

                            @include('payments.manual.partials.payable-summary', [
                                'request' => $manualPayment,
                            ])

                            <div>
                                <h6 class="fw-semibold mb-3">
                                    <i class="fa fa-receipt me-2"></i>{{ __('Receipt') }}
                                </h6>
                                @include('payments.manual.partials.receipt', [
                                    'request' => $manualPayment,
                                    'paymentTransaction' => $transaction,
                                ])
                            </div>

                            <div>
                                <h6 class="fw-semibold mb-3">
                                    <i class="fa fa-stream me-2"></i>{{ __('Timeline') }}
                                </h6>
                                @include('payments.manual.partials.status-timeline', [
                                    'request' => $manualPayment,
                                    'timelineData' => $timelineData,
                                    'timelineEndpoint' => $timelineEndpoint,
                                ])
                            </div>
                        @elseif($hasPaymentContext)
                            <div class="alert alert-info mb-0" role="alert">
                                <i class="fa fa-circle-info me-2"></i>
                                {{ __('Payment data exists, but the manual payment request details are unavailable.') }}
                            </div>
                        @else
                            <div class="alert alert-warning mb-0" role="alert">
                                <i class="fa fa-circle-info me-2"></i>
                                {{ __('No payment has been submitted yet. Share these details with the requester to proceed.') }}
                                <div class="mt-2 small text-muted">
                                    {{ __('Amount') }}: {{ $amountDisplay }}
                                    @if($paymentInstruction)
                                        <br>{{ __('Instruction') }}: {{ $paymentInstruction }}
                                    @endif
                                </div>
                            </div>
                        @endisset
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header border-bottom">
                        <h5 class="card-title mb-0">{{ __('Filled Fields') }}</h5>
                    </div>
                    <div class="card-body">
                        @if(!empty($fieldEntries))
                            <div class="table-responsive">
                                <table class="table table-sm table-bordered align-middle mb-0">
                                    <thead class="table-light">
                                        <tr>
                                            <th style="width: 30%">{{ __('Field') }}</th>
                                            <th>{{ __('Value') }}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        @foreach($fieldEntries as $entry)
                                            <tr>
                                                <th scope="row">
                                                    <div>{{ $entry['label'] }}</div>
                                                    @if(!empty($entry['note']))
                                                        <div class="small text-muted mt-1">{{ $entry['note'] }}</div>
                                                    @endif
                                                </th>
                                                <td>
                                                    @if(!empty($entry['is_file']) && !empty($entry['file_url']))
                                                        <a href="{{ $entry['file_url'] }}" class="btn btn-sm btn-outline-primary" target="_blank" rel="noopener">
                                                            <i class="bi bi-box-arrow-up-right"></i> {{ $entry['file_name'] ?? $entry['display'] }}
                                                        </a>
                                                        @if(!empty($entry['display']) && ($entry['file_name'] ?? null) !== $entry['display'])
                                                            <div class="small text-muted mt-1">{{ $entry['display'] }}</div>
                                                        @endif
                                                    @elseif(!empty($entry['value_list']) && count($entry['value_list']) > 1)
                                                        <ul class="list-unstyled mb-0">
                                                            @foreach($entry['value_list'] as $value)
                                                                <li><i class="bi bi-check2"></i> {{ $value }}</li>
                                                            @endforeach
                                                        </ul>
                                                    @else
                                                        <div>{!! nl2br(e($entry['display'] ?? '-')) !!}</div>
                                                        @if(!empty($entry['value_list']) && count($entry['value_list']) === 1)
                                                            <div class="small text-muted mt-1">{{ $entry['value_list'][0] }}</div>
                                                        @endif
                                                    @endif
                                                </td>
                                            </tr>
                                        @endforeach
                                    </tbody>
                                </table>
                            </div>
                        @else
                            <div class="text-muted">{{ __('No custom fields were submitted for this request.') }}</div>
                        @endif
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header border-bottom">
                        <h5 class="card-title mb-0">{{ __('Attachments') }}</h5>
                    </div>
                    <div class="card-body">
                        @if(!empty($attachmentEntries))
                            <ul class="list-group list-group-flush">
                                @foreach($attachmentEntries as $attachment)
                                    <li class="list-group-item d-flex justify-content-between align-items-start gap-3">
                                        <div>
                                            <div class="fw-semibold">{{ $attachment['label'] }}</div>
                                            @if(!empty($attachment['note']))
                                                <div class="small text-muted">{{ $attachment['note'] }}</div>
                                            @endif
                                        </div>
                                        @if(!empty($attachment['file_url']))
                                            <a href="{{ $attachment['file_url'] }}" class="btn btn-sm btn-outline-primary" target="_blank" rel="noopener">
                                                <i class="bi bi-download"></i> {{ $attachment['file_name'] ?? __('Download') }}
                                            </a>
                                        @else
                                            <span class="badge bg-light text-muted">{{ __('Unavailable') }}</span>
                                        @endif
                                    </li>
                                @endforeach
                            </ul>
                        @else
                            <div class="text-muted">{{ __('No files were uploaded for this request.') }}</div>
                        @endif
                    </div>
                </div>
            </div>

            <div class="col-12 col-xl-4">
                <div class="card mb-4">
                    <div class="card-header border-bottom">
                        <h5 class="card-title mb-0">{{ __('Applicant') }}</h5>
                    </div>
                    <div class="card-body">
                        @if($applicant)
                            <div class="d-flex align-items-center gap-3 mb-3">
                                @if($applicant->profile)
                                    <img src="{{ $applicant->profile }}" alt="{{ $applicant->name }}" class="rounded-circle" style="width:64px;height:64px;object-fit:cover;">
                                @else
                                    <div class="rounded-circle bg-light d-flex align-items-center justify-content-center" style="width:64px;height:64px;">
                                        <i class="bi bi-person text-muted fs-3"></i>
                                    </div>
                                @endif
                                <div>
                                    <div class="fw-semibold">{{ $applicant->name }}</div>
                                    <div class="small text-muted">{{ __('User ID') }}: {{ $applicant->id }}</div>
                                </div>
                            </div>
                            <dl class="row mb-0">
                                @if($applicant->email)
                                    <dt class="col-5 text-muted">{{ __('Email') }}</dt>
                                    <dd class="col-7">{{ $applicant->email }}</dd>
                                @endif
                                @if($applicant->mobile)
                                    <dt class="col-5 text-muted">{{ __('Mobile') }}</dt>
                                    <dd class="col-7">{{ $applicant->mobile }}</dd>
                                @endif
                                <dt class="col-5 text-muted">{{ __('Account Type') }}</dt>
                                <dd class="col-7">{{ method_exists($applicant, 'getAccountTypeName') ? $applicant->getAccountTypeName() : __('Customer') }}</dd>
                                <dt class="col-5 text-muted">{{ __('Status') }}</dt>
                                <dd class="col-7">
                                    @if($applicant->is_verified)
                                        <span class="badge bg-success">{{ __('Verified') }}</span>
                                    @else
                                        <span class="badge bg-secondary">{{ __('Pending Verification') }}</span>
                                    @endif
                                </dd>
                            </dl>
                        @else
                            <div class="text-muted">{{ __('The applicant account is no longer available.') }}</div>
                        @endif
                    </div>
                </div>

                @can('service-requests-update')
                    <div class="card">
                        <div class="card-header border-bottom">
                            <h5 class="card-title mb-0">{{ __('Update Status') }}</h5>
                        </div>
                        <div class="card-body">
                            <form method="POST" action="{{ route('service.requests.approval', $serviceRequest->id) }}">
                                @csrf
                                <div class="mb-3">
                                    <label for="rejected_reason" class="form-label">{{ __('Internal Note / Rejection Reason') }}</label>
                                    <textarea name="rejected_reason" id="rejected_reason" class="form-control" rows="3" placeholder="{{ __('Explain the decision when rejecting the request.') }}"></textarea>
                                    <div class="form-text">{{ __('This note will only be stored when the request is rejected.') }}</div>
                                </div>
                                <div class="d-flex gap-2">
                                    <button type="submit"
                                            name="status"
                                            value="approved"
                                            class="btn btn-success flex-grow-1"
                                            @if(!$canApprove) disabled @endif>
                                        <i class="bi bi-check-circle"></i> {{ __('Approve') }}
                                    </button>
                                    <button type="submit"
                                            name="status"
                                            value="rejected"
                                            class="btn btn-danger flex-grow-1"
                                            @if(!$canReject) disabled @endif>
                                        <i class="bi bi-x-circle"></i> {{ __('Reject') }}
                                    </button>
                                </div>
                                @if(!$canApprove && !$canReject)
                                    <p class="text-muted small mt-3 mb-0">
                                        <i class="fa fa-circle-info me-1"></i>{{ __('Status changes are disabled for this request.') }}
                                    </p>
                                @endif
                            </form>
                        </div>
                    </div>
                @endcan
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
