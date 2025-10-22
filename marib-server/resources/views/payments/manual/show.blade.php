@php
    use App\Models\ManualPaymentRequest;
    use Illuminate\Support\Arr;
    use Illuminate\Support\Str;
    $statusHtml = match ($request->status) {


        ManualPaymentRequest::STATUS_APPROVED => '<span class="badge bg-success">' . __('Approved') . '</span>',
        ManualPaymentRequest::STATUS_REJECTED => '<span class="badge bg-danger">' . __('Rejected') . '</span>',
        default => '<span class="badge bg-warning text-dark">' . __('Pending') . '</span>',
    };

    $paymentTransaction = $request->paymentTransaction;
    $paymentGatewayKey = $paymentGatewayKey ?? $paymentTransaction?->payment_gateway;
    $paymentGatewayCanonical = $paymentGatewayCanonical
        ?? ManualPaymentRequest::canonicalGateway($paymentGatewayKey);

        
    if ($paymentGatewayCanonical === 'manual_bank') {
        $paymentGatewayCanonical = 'manual_banks';
    }

    $paymentGatewayLabel = $paymentGatewayLabel ?? __('Bank Transfer');
    $departmentLabel = $departmentLabel ?? __('Unknown Department');


    $eastYemenMeta = data_get($request->meta, 'east_yemen_bank', []);
    $defaultVoucherNumber = data_get($eastYemenMeta, 'request_payment.response.voucher_number')
        ?? data_get($eastYemenMeta, 'confirm_payment.payload.voucher_number')
        ?? data_get($eastYemenMeta, 'check_voucher.payload.voucher_number');


    $walletTransaction = $paymentTransaction?->walletTransaction;
    $walletAccount = $walletTransaction?->walletAccount;
    $walletOwner = $walletAccount?->user;

    $orderPayable = $request->payable instanceof \App\Models\Order
        ? $request->payable
        : ($paymentTransaction?->order);

    $orderCurrency = $orderPayable?->currency ?? $request->currency;
    $depositPaidAmount = $orderPayable ? (float) ($orderPayable->deposit_amount_paid ?? 0) : 0.0;
    $depositRemainingAmount = $orderPayable ? (float) ($orderPayable->deposit_remaining_balance ?? 0) : 0.0;

    $orderPaymentSummary = $orderPayable?->payment_summary;
    if (! is_array($orderPaymentSummary) && $orderPayable) {
        $orderPaymentSummary = data_get($orderPayable->payment_payload, 'payment_summary', []);
    }

    $orderRemainingBalance = 0.0;
    $rawRemaining = is_array($orderPaymentSummary)
        ? data_get($orderPaymentSummary, 'remaining_balance')
        : null;

    if (is_numeric($rawRemaining)) {
        $orderRemainingBalance = (float) $rawRemaining;
    }

    if ($orderRemainingBalance <= 0 && $depositRemainingAmount > 0) {
        $orderRemainingBalance = $depositRemainingAmount;
    }

@endphp

<div class="manual-payment-review-content py-2">
    <div class="row g-4">
        <div class="col-lg-4 col-md-6">
            <div class="card h-100 shadow-sm">
                <div class="card-header bg-light">
                    <h6 class="mb-0"><i class="fa fa-user me-2"></i>{{ __('User Details') }}</h6>
                </div>
                <div class="card-body">
                    <dl class="row mb-0">
                        <dt class="col-5 text-muted">{{ __('Name') }}</dt>
                        <dd class="col-7">{{ $request->user?->name ?? __('N/A') }}</dd>

                        <dt class="col-5 text-muted">{{ __('Email') }}</dt>
                        <dd class="col-7">{{ $request->user?->email ?? __('N/A') }}</dd>

                        <dt class="col-5 text-muted">{{ __('Mobile') }}</dt>
                        <dd class="col-7">{{ $request->user?->mobile ?? __('N/A') }}</dd>

                        <dt class="col-5 text-muted">{{ __('Submitted At') }}</dt>
                        <dd class="col-7">{{ $request->created_at?->format('Y-m-d H:i') ?? __('N/A') }}</dd>
                    </dl>
                </div>
            </div>
        </div>

        <div class="col-lg-4 col-md-6">
            <div class="card h-100 shadow-sm">
                <div class="card-header bg-light d-flex justify-content-between align-items-center">
                    <h6 class="mb-0"><i class="fa fa-info-circle me-2"></i>{{ __('Payment Information') }}</h6>
                    {!! $statusHtml !!}
                </div>
                <div class="card-body">
                    <dl class="row mb-0">
                        <dt class="col-5 text-muted">{{ __('Reference') }}</dt>
                        <dd class="col-7">{{ $request->reference ?? __('N/A') }}</dd>

                        <dt class="col-5 text-muted">{{ __('Amount') }}</dt>
                        <dd class="col-7">{{ number_format($request->amount, 2) }} {{ $request->currency }}</dd>

                        @if($depositPaidAmount > 0)
                            <dt class="col-5 text-muted">{{ __('Manual Payment Advance Paid') }}</dt>
                            <dd class="col-7">{{ number_format($depositPaidAmount, 2) }} {{ $orderCurrency }}</dd>
                        @endif

                        @if($orderRemainingBalance > 0)
                            <dt class="col-5 text-muted">{{ __('Manual Payment Outstanding Balance') }}</dt>
                            <dd class="col-7">{{ number_format($orderRemainingBalance, 2) }} {{ $orderCurrency }}</dd>
                        @endif


                        <dt class="col-5 text-muted">{{ __('Payable Type') }}</dt>
                        <dd class="col-7">
                            {{ filled($request->payable_type)
                                ? Str::title(class_basename($request->payable_type))
                                : __('N/A') }}
                        </dd>




                        <dt class="col-5 text-muted">{{ __('Payment Gateway') }}</dt>
                        <dd class="col-7">{{ $paymentGatewayLabel }}</dd>

                        @if($paymentGatewayCanonical === 'wallet')
                            <dt class="col-5 text-muted">{{ __('Wallet Transaction ID') }}</dt>
                            <dd class="col-7">{{ $walletTransaction?->id ?? __('N/A') }}</dd>

                            <dt class="col-5 text-muted">{{ __('Wallet Account Owner') }}</dt>
                            <dd class="col-7">{{ $walletOwner?->name ?? __('N/A') }}</dd>
                        @endif

                        
                        <dt class="col-5 text-muted">{{ __('Department') }}</dt>
                        <dd class="col-7">{{ $departmentLabel }}</dd>


                        <dt class="col-5 text-muted">{{ __('Transaction ID') }}</dt>
                        <dd class="col-7">{{ $request->paymentTransaction?->id ?? __('Not generated') }}</dd>
                    </dl>
                </div>
            </div>
        </div>

        <div class="col-lg-4 col-md-12">
            <div class="card h-100 shadow-sm">
                <div class="card-header bg-light">
                    <h6 class="mb-0"><i class="fa fa-exchange-alt me-2"></i>{{ __('Transfer Information') }}</h6>
                </div>
                <div class="card-body">
                    @php
                        $rawMeta = is_array($request->meta) ? $request->meta : [];
                        $metadata = Arr::get($rawMeta, 'metadata', []);

                        if (! is_array($metadata)) {
                            $metadata = [];
                        }

                        $valueFromMetadata = static function (array $keys) use ($metadata) {
                            foreach ($keys as $key) {
                                $value = data_get($metadata, $key);

                                if ($value instanceof \DateTimeInterface) {
                                    return $value;
                                }

                                if (is_string($value)) {
                                    $value = trim($value);
                                } elseif (is_numeric($value)) {
                                    $value = trim((string) $value);
                                } else {
                                    continue;
                                }

                                if ($value !== '') {
                                    return $value;
                                }
                            }

                            return null;
                        };

                        $senderName = $valueFromMetadata(['sender_name', 'sender']);

                        $rawUserNote = is_string($request->user_note) ? $request->user_note : '';
                        $noteLines = [];
                        $senderFromNote = null;

                        if ($rawUserNote !== '') {
                            $lines = preg_split("/\r\n|\n|\r/", $rawUserNote) ?: [];

                            foreach ($lines as $line) {
                                $trimmedLine = trim($line);

                                if ($trimmedLine === '') {
                                    continue;
                                }

                                if ($senderFromNote === null) {
                                    $normalizedLine = Str::lower($trimmedLine);

                                    if (Str::contains($normalizedLine, 'اسم المرسل')) {
                                        $parts = preg_split('/[:：]/u', $trimmedLine, 2);

                                        if (isset($parts[1])) {
                                            $candidate = trim($parts[1]);

                                            if ($candidate !== '') {
                                                $senderFromNote = $candidate;
                                                continue;
                                            }
                                        }
                                    }
                                }

                                $noteLines[] = $trimmedLine;
                            }
                        }

                        if (! $senderName && $senderFromNote) {
                            $senderName = $senderFromNote;
                        }

                        $transferReference = $valueFromMetadata([
                            'transfer_reference',
                            'transfer_number',
                            'reference_number',
                            'transaction_reference',
                            'reference',
                            'voucher_number',
                        ]);

                        if (! $transferReference && filled($request->reference)) {
                            $transferReference = trim((string) $request->reference);
                        }

                        $transferDate = $valueFromMetadata(['transferred_at', 'transfer_date']);

                        if ($transferDate instanceof \DateTimeInterface) {
                            $transferDate = $transferDate->format('Y-m-d H:i');
                        } elseif (is_string($transferDate) && $transferDate !== '') {
                            try {
                                $parsedDate = \Carbon\Carbon::parse($transferDate);
                                $transferDate = $parsedDate->format('Y-m-d H:i');
                            } catch (\Exception $exception) {
                                // Keep the original string when parsing fails.
                            }
                        } else {
                            $transferDate = null;
                        }

                        $noteFromMetadata = $valueFromMetadata(['notes', 'note', 'additional_note', 'message']);

                        if (! $noteFromMetadata) {
                            $noteFromMetadata = $noteLines !== []
                                ? implode("\n", $noteLines)
                                : ($rawUserNote !== '' ? $rawUserNote : null);
                        }

                        $transferDetails = [];

                        if ($senderName) {
                            $transferDetails[__('Sender Name')] = $senderName;
                        }

                        if ($transferReference) {
                            $transferDetails[__('Transfer Reference')] = $transferReference;
                        }

                        if ($transferDate) {
                            $transferDetails[__('Transfer Date')] = $transferDate;
                        }

                        if ($noteFromMetadata) {
                            $transferDetails[__('Additional Notes')] = $noteFromMetadata;
                        }
                    @endphp

                    @if($transferDetails !== [])
                        <dl class="row mb-0">
                            @foreach($transferDetails as $label => $value)
                                <dt class="col-5 text-muted">{{ $label }}</dt>
                                <dd class="col-7">
                                    @php
                                        $stringValue = is_string($value) ? $value : (is_numeric($value) ? (string) $value : '');
                                    @endphp
                                    @if($stringValue !== '' && Str::contains($stringValue, "\n"))
                                        {!! nl2br(e($stringValue)) !!}
                                    @else
                                        {{ $stringValue !== '' ? $stringValue : __('N/A') }}
                                    @endif
                                </dd>
                            @endforeach
                        </dl>
                    @else
                        <p class="text-muted mb-0">{{ __('No transfer information provided.') }}</p>
                    @endif

                    
                </div>
            </div>
        </div>
    </div>


        @include('payments.manual.partials.payable-summary', ['request' => $request])


    <div class="card shadow-sm mt-4">
        <div class="card-header bg-light">
            <h6 class="mb-0"><i class="fa fa-file-invoice-dollar me-2"></i>{{ __('Receipt') }}</h6>
        </div>
        <div class="card-body">
            @include('payments.manual.partials.receipt', ['request' => $request])
        </div>
    </div>

    <div class="card shadow-sm mt-4">
        <div class="card-header bg-light d-flex justify-content-between align-items-center">
            <h6 class="mb-0"><i class="fa fa-sticky-note me-2"></i>{{ __('Notes') }}</h6>
            <span class="badge bg-secondary">{{ __('Status') }}: {!! $statusHtml !!}</span>
        </div>
        <div class="card-body">
            <div class="mb-3">
                <strong>{{ __('User Note') }}:</strong>
                <p class="mb-0">{{ $request->user_note ?? __('No note provided by the user.') }}</p>
            </div>
            @if($request->admin_note)
                <div>
                    <strong>{{ __('Admin Note') }}:</strong>
                    <p class="mb-0">{{ $request->admin_note }}</p>
                </div>
            @endif
        </div>
    </div>



        @if($paymentGatewayKey === 'east_yemen_bank')
        <div class="card shadow-sm mt-4">
            <div class="card-header bg-light d-flex justify-content-between align-items-center">
                <h6 class="mb-0"><i class="fa fa-exchange-alt me-2"></i>{{ __('East Yemen Bank Actions') }}</h6>
                <span class="badge bg-primary">{{ __('Gateway Active') }}</span>
            </div>
            <div class="card-body">
                @can('manual-payments-review')
                    <div class="row g-3">
                        <div class="col-lg-4 col-md-6">
                            <div class="border rounded p-3 h-100">
                                <h6 class="mb-3">{{ __('Initiate Voucher') }}</h6>
                                <form action="{{ route('payment-requests.east-yemen.request', $request) }}" method="post" class="manual-payment-action">
                                    @csrf
                                    <div class="mb-3">
                                        <label for="east-yemen-customer-identifier" class="form-label">{{ __('Customer Identifier') }}</label>
                                        <input type="text" id="east-yemen-customer-identifier" name="customer_identifier" class="form-control" placeholder="{{ __('Enter customer identifier') }}" required>
                                    </div>
                                    <div class="mb-3">
                                        <label for="east-yemen-description" class="form-label">{{ __('Description (optional)') }}</label>
                                        <input type="text" id="east-yemen-description" name="description" value="{{ $request->reference }}" class="form-control" placeholder="{{ __('Voucher description') }}">
                                    </div>
                                    <button type="submit" class="btn btn-outline-primary w-100">{{ __('Request Payment') }}</button>
                                </form>
                            </div>
                        </div>
                        <div class="col-lg-4 col-md-6">
                            <div class="border rounded p-3 h-100">
                                <h6 class="mb-3">{{ __('Confirm Voucher') }}</h6>
                                <form action="{{ route('payment-requests.east-yemen.confirm', $request) }}" method="post" class="manual-payment-action">
                                    @csrf
                                    <div class="mb-3">
                                        <label for="east-yemen-confirm-voucher" class="form-label">{{ __('Voucher Number') }}</label>
                                        <input type="text" id="east-yemen-confirm-voucher" name="voucher_number" class="form-control" value="{{ $defaultVoucherNumber }}" placeholder="{{ __('Enter voucher number') }}" required>
                                    </div>
                                    <div class="mb-3">
                                        <label for="east-yemen-otp" class="form-label">{{ __('OTP (optional)') }}</label>
                                        <input type="text" id="east-yemen-otp" name="otp" class="form-control" placeholder="{{ __('Enter one-time password if required') }}">
                                    </div>
                                    <button type="submit" class="btn btn-outline-success w-100">{{ __('Confirm Payment') }}</button>
                                </form>
                            </div>
                        </div>
                        <div class="col-lg-4 col-md-12">
                            <div class="border rounded p-3 h-100">
                                <h6 class="mb-3">{{ __('Check Voucher Status') }}</h6>
                                <form action="{{ route('payment-requests.east-yemen.check', $request) }}" method="post" class="manual-payment-action">
                                    @csrf
                                    <div class="mb-3">
                                        <label for="east-yemen-check-voucher" class="form-label">{{ __('Voucher Number') }}</label>
                                        <input type="text" id="east-yemen-check-voucher" name="voucher_number" class="form-control" value="{{ $defaultVoucherNumber }}" placeholder="{{ __('Enter voucher number') }}" required>
                                    </div>
                                    <button type="submit" class="btn btn-outline-secondary w-100">{{ __('Check Status') }}</button>
                                </form>
                            </div>
                        </div>
                    </div>
                @else
                    <p class="text-muted mb-0">{{ __('You do not have permission to interact with the East Yemen Bank gateway.') }}</p>
                @endcan

                @if(!empty($eastYemenMeta))
                    <hr class="my-4">
                    <h6 class="mb-2">{{ __('Recent Gateway Activity') }}</h6>
                    <pre class="bg-light border rounded p-3 small mb-0">@json($eastYemenMeta, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)</pre>
                @endif
            </div>
        </div>
    @endif



    @if($canReview)
        <div class="card border-primary shadow-sm mt-4">
            <div class="card-header bg-primary text-white d-flex flex-wrap justify-content-between align-items-center gap-2">
                <h6 class="mb-0"><i class="fa fa-clipboard-check me-2"></i>{{ __('Review Decision') }}</h6>
                <small class="fw-light">{{ __('Choose the final status, add notes, and optionally alert the requester.') }}</small>
            </div>
            <div class="card-body">
                <form action="{{ route('payment-requests.decision', $request) }}" method="post" class="manual-payment-action" data-reload-on-success="true" enctype="multipart/form-data">
                    @csrf
                    <div class="mb-3">
                        <label class="form-label fw-semibold">{{ __('Decision') }}</label>
                        <div class="d-flex flex-wrap gap-3">
                            <div class="form-check">
                                <input class="form-check-input" type="radio" name="decision" id="decision-approved" value="{{ \App\Models\ManualPaymentRequest::STATUS_APPROVED }}">
                                <label class="form-check-label" for="decision-approved">
                                    <i class="fa fa-check text-success me-1"></i>{{ __('Verified') }}
                                </label>









                            </div>
                            <div class="form-check">
                                <input class="form-check-input" type="radio" name="decision" id="decision-rejected" value="{{ \App\Models\ManualPaymentRequest::STATUS_REJECTED }}">
                                <label class="form-check-label" for="decision-rejected">
                                    <i class="fa fa-times text-danger me-1"></i>{{ __('Not verified') }}
                                </label>


                            </div>



                        </div>
                    <div class="mb-3">
                        <label for="decision-note" class="form-label fw-semibold">{{ __('Internal note (optional)') }}</label>
                        <textarea class="form-control" name="admin_note" id="decision-note" rows="3" placeholder="{{ __('Add any context for this decision (visible to admins).') }}"></textarea>
                        <div class="form-text">{{ __('Notes are stored with the history and can be shared in notifications if enabled.') }}</div>


                    </div>
                    <div class="mb-3">
                        <label for="decision-document-valid-until" class="form-label fw-semibold">{{ __('Document valid until') }}</label>
                        <input type="date" class="form-control" name="document_valid_until" id="decision-document-valid-until" value="{{ old('document_valid_until') }}">
                        <div class="form-text">{{ __('Leave blank if there is no expiry date.') }}</div>


                    </div>
                    <div class="mb-3">
                        <label for="decision-attachment" class="form-label fw-semibold">{{ __('Attach image (optional)') }}</label>
                        <input class="form-control" type="file" name="attachment" id="decision-attachment" accept="image/*">
                        <div class="form-text">{{ __('Accepted formats: JPG, PNG. Maximum size 5 MB.') }}</div>


                </div>

                    <div class="mb-4">
                        <div class="form-check form-switch">
                            <input class="form-check-input" type="checkbox" role="switch" id="decision-notify" name="notify_user" value="1" checked>
                            <label class="form-check-label" for="decision-notify">{{ __('Send notification to requester') }}</label>
                        </div>
                        <div class="form-text">{{ __('Disable this option to save without alerting the user.') }}</div>
                    </div>

                    <div class="d-flex justify-content-end">
                        <button type="submit" class="btn btn-primary">
                            <i class="fa fa-save me-1"></i>{{ __('Submit decision') }}
                        </button>
                    </div>
                </form>


            </div>
        </div>
    @else
        <div class="alert alert-info mt-3" role="alert">
            <i class="fa fa-lock me-2"></i>{{ __('This request has already been reviewed or you do not have permission to update it.') }}
        </div>
    @endif

    @include('payments.manual.partials.status-timeline', [
        'timelineData' => $timelineData ?? [],
        'timelineEndpoint' => route('payment-requests.timeline', $request),
    ])

    
        </div>
    </div>
</div>