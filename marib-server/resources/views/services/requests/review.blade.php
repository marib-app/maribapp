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



    $presentation = is_array($presentation ?? null) ? $presentation : [];
    $paymentGatewayKey = $presentation['paymentGatewayKey'] ?? ($paymentLabels['gateway_key'] ?? null);
    $paymentGatewayCanonical = $presentation['paymentGatewayCanonical'] ?? $paymentGatewayKey;
    $paymentGatewayLabelDetailed = $presentation['paymentGatewayLabel']
        ?? $gatewayLabel
        ?? ($paymentLabels['gateway_label'] ?? null);
    $manualBankName = $presentation['manualBankName'] ?? ($paymentLabels['bank_name'] ?? null);
    $departmentLabel = $presentation['departmentLabel'] ?? null;
    $transferDetails = is_array($presentation['transferDetails'] ?? null)
        ? $presentation['transferDetails']
        : [];
    $transferReceiptUrl = $transferDetails['receipt_url'] ?? null;


    $paymentInstruction = is_string($paymentInstruction ?? null) ? trim($paymentInstruction) : null;
    if ($paymentInstruction === '') {
        $paymentInstruction = null;
    }

    $paymentStatusLabel = $paymentStatusLabel
        ?? ($serviceRequest->payment_status ? __($serviceRequest->payment_status) : __('Not provided'));

    $actionFlags = is_array($actionFlags ?? null) ? $actionFlags : [];
    $canApprove = $actionFlags['approve'] ?? false;
    $canReject = $actionFlags['reject'] ?? false;


    $canReviewPayment = (bool) ($canReviewPayment ?? false);

    $manualPaymentStatusLabel = null;
    $manualPaymentStatusBadgeClass = 'badge bg-warning text-dark';

    if ($manualPayment) {
        $normalizedManualStatus = ManualPaymentRequest::normalizeStatus($manualPayment->status ?? null);

        $manualPaymentStatusLabel = match ($normalizedManualStatus) {
            ManualPaymentRequest::STATUS_APPROVED => __('Approved'),
            ManualPaymentRequest::STATUS_REJECTED => __('Rejected'),
            ManualPaymentRequest::STATUS_UNDER_REVIEW => __('Under Review'),
            default => __('Pending'),
        };

        $manualPaymentStatusBadgeClass = match ($normalizedManualStatus) {
            ManualPaymentRequest::STATUS_APPROVED => 'badge bg-success',
            ManualPaymentRequest::STATUS_REJECTED => 'badge bg-danger',
            ManualPaymentRequest::STATUS_UNDER_REVIEW => 'badge bg-info text-dark',
            default => 'badge bg-warning text-dark',
        };
    }

    $normalizeDisplayString = static function ($value): ?string {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            return $trimmed === '' ? null : $trimmed;
        }

        if (is_numeric($value)) {
            return (string) $value;
        }

        return null;
    };

    $formatMoney = static function ($value, ?string $currency = null): string {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if (is_string($value)) {
            $trimmed = trim($value);
            if ($trimmed === '') {
                return __('N/A');
            }

            if (! is_numeric($trimmed)) {
                return $trimmed;
            }

            $value = (float) $trimmed;
        }

        if (! is_numeric($value)) {
            return __('N/A');
        }

        $formatted = number_format((float) $value, 2);

        return $currency ? $formatted . ' ' . $currency : $formatted;
    };

    $paymentInfoRows = [];

    if ($manualPayment) {
        $paymentInfoRows[] = [
            'label' => __('Reference'),
            'value' => $normalizeDisplayString($manualPayment->reference) ?? __('N/A'),
        ];

        $paymentInfoRows[] = [
            'label' => __('Amount'),
            'value' => $amountDisplay,
        ];

        if ($manualPayment->payable_type) {
            $paymentInfoRows[] = [
                'label' => __('Payable Type'),
                'value' => \Illuminate\Support\Str::title(class_basename($manualPayment->payable_type)),
            ];
        }

        $gatewayParts = array_filter([
            $paymentGatewayLabelDetailed,
            $manualBankName && $manualBankName !== $paymentGatewayLabelDetailed ? $manualBankName : null,
        ], static fn ($part) => $normalizeDisplayString($part) !== null);

        $paymentInfoRows[] = [
            'label' => __('Payment Gateway'),
            'value' => $gatewayParts !== []
                ? implode(' — ', array_map(static fn ($part) => $normalizeDisplayString($part), $gatewayParts))
                : ($gatewayLabel ?? __('Not provided')),
        ];

        if ($departmentLabel) {
            $paymentInfoRows[] = [
                'label' => __('Department'),
                'value' => $departmentLabel,
            ];
        }

        if ($paymentGatewayCanonical === 'wallet') {
            $walletTransaction = $manualPayment->paymentTransaction?->walletTransaction;
            $walletOwner = $walletTransaction?->walletAccount?->user;

            $paymentInfoRows[] = [
                'label' => __('Wallet Transaction ID'),
                'value' => $normalizeDisplayString($walletTransaction?->id) ?? __('N/A'),
            ];

            $paymentInfoRows[] = [
                'label' => __('Wallet Account Owner'),
                'value' => $normalizeDisplayString($walletOwner?->name) ?? __('N/A'),
            ];
        }

        $paymentInfoRows[] = [
            'label' => __('Transaction ID'),
            'value' => $transactionIdDisplay ?? __('Not provided'),
        ];

        $documentValidUntil = data_get($manualPayment->meta, 'document.valid_until');
        if ($documentValidUntil) {
            try {
                $documentDate = \Carbon\Carbon::parse($documentValidUntil);
                $documentDisplay = $documentDate->format('Y-m-d');
            } catch (\Throwable) {
                $documentDisplay = $documentValidUntil;
            }

            $paymentInfoRows[] = [
                'label' => __('Document valid until'),
                'value' => $documentDisplay,
            ];
        }

        if (is_array($manualPayment->payment_summary)) {
            $remaining = data_get($manualPayment->payment_summary, 'remaining_balance');
            if ($remaining !== null) {
                $paymentInfoRows[] = [
                    'label' => __('Manual Payment Outstanding Balance'),
                    'value' => $formatMoney($remaining, $manualPayment->currency ?? $expectedCurrency),
                ];
            }
        }
    }

    $transferDisplay = [];

    if ($transferDetails !== []) {
        $transferDisplay = [
            __('Bank Name') => $transferDetails['bank_name'] ?? null,
            __('Sender Bank') => $transferDetails['sender_bank_name'] ?? null,
            __('Sender Name') => $transferDetails['sender_name'] ?? null,
            __('Transfer Reference') => $transferDetails['transfer_reference'] ?? null,
            __('Transfer Amount') => $transferDetails['transfer_amount'] ?? null,
            __('Transfer Date') => $transferDetails['transfer_date'] ?? null,
            __('Additional Notes') => $transferDetails['note'] ?? null,
        ];

        $transferDisplay = array_filter($transferDisplay, static function ($value) use ($normalizeDisplayString) {
            return $normalizeDisplayString($value) !== null;
        });
    }

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
                    <div class="card-body">

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

                            @if(!empty($paymentInfoRows))
                                <hr class="my-4">
                                <div class="row g-4">
                                    @foreach($paymentInfoRows as $row)
                                        <div class="col-md-6 col-xl-4">
                                            <label class="form-label fw-semibold text-muted">{{ $row['label'] }}</label>
                                            <div class="fw-semibold text-break">{{ $row['value'] }}</div>
                                        </div>
                                    @endforeach
                                </div>
                            @endif
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


                @isset($manualPayment)
                    @include('payments.manual.partials.payable-summary', ['request' => $manualPayment])

                    <div class="card mb-4">
                        <div class="card-header border-bottom d-flex justify-content-between align-items-center">
                            <h5 class="card-title mb-0"><i class="fa fa-exchange-alt me-2"></i>{{ __('Transfer Information') }}</h5>
                            @if($paymentGatewayLabelDetailed)
                                <span class="badge bg-light text-dark border">{{ $paymentGatewayLabelDetailed }}</span>
                            @endif
                        </div>
                        <div class="card-body">
                            @if($transferDisplay !== [])
                                <div class="table-responsive">
                                    <table class="table table-sm table-bordered align-middle mb-0">
                                        <thead class="table-light">
                                            <tr>
                                                @foreach(array_keys($transferDisplay) as $label)
                                                    <th class="text-muted text-uppercase small">{{ $label }}</th>
                                                @endforeach
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <tr>
                                                @foreach($transferDisplay as $value)
                                                    @php($displayValue = $normalizeDisplayString($value))
                                                    <td class="text-break text-body">
                                                        @if($displayValue !== null && str_contains($displayValue, "\n"))
                                                            {!! nl2br(e($displayValue)) !!}
                                                        @else
                                                            {{ $displayValue ?? __('N/A') }}
                                                        @endif
                                                    </td>
                                                @endforeach
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            @else
                                <p class="text-muted mb-0">{{ __('No transfer information provided.') }}</p>
                            @endif
                        </div>
                    </div>

                    <div class="card mb-4">
                        <div class="card-header border-bottom">
                            <h5 class="card-title mb-0"><i class="fa fa-receipt me-2"></i>{{ __('Receipt') }}</h5>
                        </div>
                        <div class="card-body">
                            @include('payments.manual.partials.receipt', [
                                'request' => $manualPayment,
                                'paymentTransaction' => $transaction,
                                'receiptUrl' => $transferReceiptUrl,
                            ])
                        </div>
                    </div>

                    <div class="card mb-4">
                        <div class="card-header border-bottom d-flex justify-content-between align-items-center">
                            <h5 class="card-title mb-0"><i class="fa fa-sticky-note me-2"></i>{{ __('Notes') }}</h5>
                            @if($manualPaymentStatusLabel)
                                <span class="{{ $manualPaymentStatusBadgeClass }}">{{ $manualPaymentStatusLabel }}</span>
                            @endif
                        </div>
                        <div class="card-body d-grid gap-3">
                            <div>
                                <strong>{{ __('User Note') }}:</strong>
                                <p class="mb-0">{{ $manualPayment->user_note ?? __('No note provided by the user.') }}</p>
                            </div>
                            <div>
                                <strong>{{ __('Admin Note') }}:</strong>
                                <p class="mb-0">{{ $manualPayment->admin_note ?? __('No notes provided.') }}</p>
                            </div>
                        </div>
                    </div>

                    @if($canReviewPayment)
                        <div class="card mb-4 border-primary">
                            <div class="card-header bg-primary text-white d-flex flex-wrap justify-content-between align-items-center gap-2">
                                <h5 class="card-title mb-0"><i class="fa fa-clipboard-check me-2"></i>{{ __('Review Decision') }}</h5>
                                <small class="fw-light">{{ __('Choose the final status, add notes, and optionally alert the requester.') }}</small>
                            </div>
                            <div class="card-body">
                                <form action="{{ route('payment-requests.decision', $manualPayment) }}" method="post" class="manual-payment-action" data-reload-on-success="true" enctype="multipart/form-data">
                                    @csrf
                                    <div class="mb-3">
                                        <label class="form-label fw-semibold">{{ __('Decision') }}</label>
                                        <div class="d-flex flex-wrap gap-3">
                                            <div class="form-check">
                                                <input class="form-check-input" type="radio" name="decision" id="manual-payment-decision-approved" value="{{ \App\Models\ManualPaymentRequest::STATUS_APPROVED }}">
                                                <label class="form-check-label" for="manual-payment-decision-approved">
                                                    <i class="fa fa-check text-success me-1"></i>{{ __('Verified') }}
                                                </label>
                                            </div>
                                            <div class="form-check">
                                                <input class="form-check-input" type="radio" name="decision" id="manual-payment-decision-rejected" value="{{ \App\Models\ManualPaymentRequest::STATUS_REJECTED }}">
                                                <label class="form-check-label" for="manual-payment-decision-rejected">
                                                    <i class="fa fa-times text-danger me-1"></i>{{ __('Not verified') }}
                                                </label>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="mb-3">
                                        <label for="manual-payment-decision-note" class="form-label fw-semibold">{{ __('Internal note (optional)') }}</label>
                                        <textarea class="form-control" name="admin_note" id="manual-payment-decision-note" rows="3" placeholder="{{ __('Add any context for this decision (visible to admins).') }}"></textarea>
                                        <div class="form-text">{{ __('Notes are stored with the history and can be shared in notifications if enabled.') }}</div>
                                    </div>

                                    <div class="mb-3">
                                        <label for="manual-payment-decision-document" class="form-label fw-semibold">{{ __('Document valid until') }}</label>
                                        <input type="date" class="form-control" name="document_valid_until" id="manual-payment-decision-document" value="{{ old('document_valid_until') }}">
                                        <div class="form-text">{{ __('Leave blank if there is no expiry date.') }}</div>
                                    </div>

                                    <div class="mb-3">
                                        <label for="manual-payment-decision-attachment" class="form-label fw-semibold">{{ __('Attach image (optional)') }}</label>
                                        <input class="form-control" type="file" name="attachment" id="manual-payment-decision-attachment" accept="image/*">
                                        <div class="form-text">{{ __('Accepted formats: JPG, PNG. Maximum size 5 MB.') }}</div>
                                    </div>

                                    <div class="form-check form-switch mb-3">
                                        <input class="form-check-input" type="checkbox" role="switch" id="manual-payment-decision-notify" name="notify_user" value="1" checked>
                                        <label class="form-check-label" for="manual-payment-decision-notify">{{ __('Send notification to requester') }}</label>
                                    </div>

                                    <div class="text-end">
                                        <button type="submit" class="btn btn-primary">
                                            <i class="fa fa-save me-1"></i>{{ __('Submit decision') }}
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    @endif

                    <div class="mb-4">
                        @include('payments.manual.partials.status-timeline', [
                            'request' => $manualPayment,
                            'timelineData' => $timelineData,
                            'timelineEndpoint' => $timelineEndpoint,
                        ])
                    </div>
                @endisset


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
