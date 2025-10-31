@php
    use App\Models\ManualPaymentRequest;
    use Illuminate\Support\Arr;
    use Illuminate\Support\Str;
    $statusHtml = match ($request->status) {


        ManualPaymentRequest::STATUS_APPROVED => '<span class="badge bg-success">' . __('Approved') . '</span>',
        ManualPaymentRequest::STATUS_REJECTED => '<span class="badge bg-danger">' . __('Rejected') . '</span>',
        default => '<span class="badge bg-warning text-dark">' . __('Pending') . '</span>',
    };
    $readOnly = (bool) ($readOnly ?? false);

    $paymentTransaction = $request->paymentTransaction;
    $paymentGatewayKey = $paymentGatewayKey ?? $paymentTransaction?->payment_gateway;
    $paymentGatewayCanonical = $paymentGatewayCanonical
        ?? ManualPaymentRequest::canonicalGateway($paymentGatewayKey);

        
    if ($paymentGatewayCanonical === 'manual_bank') {
        $paymentGatewayCanonical = 'manual_banks';
    }

    $paymentGatewayLabel = $paymentGatewayLabel ?? ($manualBankName ?? '—');
    $manualBankName = $manualBankName ?? null;

    $transferDetails = $transferDetails ?? null;

    if (! is_array($transferDetails)) {
        $transferDetails = \App\Support\ManualPayments\TransferDetailsResolver::forManualPaymentRequest($request)->toArray();
    }

    $transferDetailsBankName = $transferDetails['bank_name'] ?? null;
    $transferReceiptUrl = $transferDetails['receipt_url'] ?? null;

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

    $normalizeDepositRatio = static function ($value): ?float {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            if ($trimmed === '') {
                return null;
            }

            $percentageDetected = false;

            if (Str::contains($trimmed, '%')) {
                $percentageDetected = true;
                $trimmed = str_replace('%', '', $trimmed);
            }

            if (! is_numeric($trimmed)) {
                return null;
            }

            $value = (float) $trimmed;

            if ($percentageDetected) {
                $value = $value / 100;
            }
        } elseif (is_bool($value) || $value === null) {
            return null;
        } elseif (! is_numeric($value)) {
            return null;
        } else {
            $value = (float) $value;
        }

        if (! is_finite($value) || $value <= 0.0) {
            return null;
        }

        if ($value > 1.0) {
            if ($value <= 100.0) {
                $value = $value / 100.0;
            } else {
                return null;
            }
        }

        return round($value, 6);
    };

    $extractDepositRatioFromArray = static function (array $source) use ($normalizeDepositRatio): ?float {
        $preferredKeys = [
            'deposit_ratio',
            'depositRatio',
            'deposit.ratio',
            'deposit.details.ratio',
            'deposit.percentage',
            'depositPercentage',
            'deposit.details.percentage',
            'deposit_ratio_percentage',
            'deposit_percentage',
            'manual.deposit_ratio',
            'manual.deposit.ratio',
            'manual.deposit.percentage',
            'manual.deposit_percentage',
            'payment_summary.deposit_ratio',
            'payment_summary.deposit.ratio',
            'summary.deposit_ratio',
            'summary.deposit.ratio',
        ];

        foreach ($preferredKeys as $key) {
            $candidate = data_get($source, $key);
            $normalized = $normalizeDepositRatio($candidate);

            if ($normalized !== null) {
                return $normalized;
            }
        }

        foreach (Arr::dot($source) as $dotKey => $dotValue) {
            if (! is_string($dotKey)) {
                continue;
            }

            $normalizedKey = Str::slug($dotKey, '_');

            if ($normalizedKey === '') {
                continue;
            }

            if (! Str::contains($normalizedKey, ['deposit_ratio', 'deposit_percentage'])) {
                continue;
            }

            $normalized = $normalizeDepositRatio($dotValue);

            if ($normalized !== null) {
                return $normalized;
            }
        }

        return null;
    };

    $depositRatio = $normalizeDepositRatio($orderPayable?->deposit_ratio ?? null);

    if ($depositRatio === null && is_array($orderPaymentSummary)) {
        $depositRatio = $extractDepositRatioFromArray($orderPaymentSummary);
    }

    $orderPaymentPayload = $orderPayable?->payment_payload;

    if ($depositRatio === null && is_array($orderPaymentPayload)) {
        $depositRatio = $extractDepositRatioFromArray($orderPaymentPayload);
    }

    $requestMeta = is_array($request->meta) ? $request->meta : [];

    if ($depositRatio === null && $requestMeta !== []) {
        $depositRatio = $extractDepositRatioFromArray($requestMeta);
    }

    $depositRatioPercent = $depositRatio !== null
        ? round($depositRatio * 100, 2)
        : null;

    $depositRatioPercentDisplay = null;

    if ($depositRatioPercent !== null) {
        $formattedPercentage = number_format($depositRatioPercent, 2);
        $depositRatioPercentDisplay = rtrim(rtrim($formattedPercentage, '0'), '.');

        if ($depositRatioPercentDisplay === '') {
            $depositRatioPercentDisplay = '0';
        }
    }


    $normalizeDisplayString = static function ($value): ?string {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            if ($trimmed === '') {
                return null;
            }

            return $trimmed;
        }

        if (is_numeric($value)) {
            return (string) $value;
        }

        return null;
    };

    $normalizeNumeric = static function ($value): ?float {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            if ($trimmed === '' || ! is_numeric($trimmed)) {
                return null;
            }

            $value = (float) $trimmed;
        } elseif (! is_numeric($value)) {
            return null;
        } else {
            $value = (float) $value;
        }

        if (! is_finite($value)) {
            return null;
        }

        return $value;
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

        if (is_numeric($value)) {
            $formatted = number_format((float) $value, 2);

            return $currency ? $formatted . ' ' . $currency : $formatted;
        }

        return __('N/A');
    };

    $paymentAmountDisplay = is_numeric($request->amount)
        ? number_format((float) $request->amount, 2) . ' ' . $request->currency
        : ($normalizeDisplayString($request->amount) ?? __('N/A'));

    // Prefer canonical transaction identifier for requests linked to a payment transaction.
    $displayReference = null;

    if ($paymentTransaction instanceof \App\Models\PaymentTransaction) {
        $txRef = $paymentTransaction->payment_id ?? $paymentTransaction->payment_signature ?? null;

        if ($txRef === null || (is_string($txRef) && trim($txRef) === '')) {
            $txRef = 'TX-' . $paymentTransaction->getKey();
        }

        $displayReference = $normalizeDisplayString($txRef);
    }

    if ($displayReference === null) {
        $displayReference = $normalizeDisplayString($request->reference);
    }

    $paymentInfoRows = [
        [
            'label' => __('Reference'),
            'value' => $displayReference ?? __('N/A'),
        ],
        [
            'label' => __('Amount'),
            'value' => $paymentAmountDisplay,
        ],
    ];

    if ($depositPaidAmount > 0) {
        $paymentInfoRows[] = [
            'label' => __('Manual Payment Advance Paid'),
            'value' => $formatMoney($depositPaidAmount, $orderCurrency),
        ];
    }

    if ($depositRemainingAmount > 0) {
        $paymentInfoRows[] = [
            'label' => __('Manual Payment Advance Remaining'),
            'value' => $formatMoney($depositRemainingAmount, $orderCurrency),
        ];
    }

    if ($depositRatioPercentDisplay !== null) {
        $paymentInfoRows[] = [
            'label' => __('Manual Payment Deposit Ratio'),
            'value' => $depositRatioPercentDisplay . '%',
        ];
    }

    if ($orderRemainingBalance > 0) {
        $paymentInfoRows[] = [
            'label' => __('Manual Payment Outstanding Balance'),
            'value' => $formatMoney($orderRemainingBalance, $orderCurrency),
        ];
    }

    $payableTypeDisplay = filled($request->payable_type)
        ? Str::title(class_basename($request->payable_type))
        : __('N/A');

    $paymentInfoRows[] = [
        'label' => __('Payable Type'),
        'value' => $payableTypeDisplay,
    ];

    $paymentGatewayDisplay = $normalizeDisplayString($paymentGatewayLabel) ?? __('N/A');

    if (! empty($manualBankName) && $paymentGatewayLabel !== trans('المحفظة')) {
        $paymentGatewayDisplay .= ' — ' . $manualBankName;
    }

    $paymentInfoRows[] = [
        'label' => __('Payment Gateway'),
        'value' => $paymentGatewayDisplay,
    ];

    if ($paymentGatewayCanonical === 'wallet') {
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
        'label' => __('Department'),
        'value' => $normalizeDisplayString($departmentLabel) ?? __('N/A'),
    ];

    $transactionIdentifier = $normalizeDisplayString($request->paymentTransaction?->id);

    if ($transactionIdentifier === null) {
        $transactionIdentifier = __('Not generated');
    }

    $paymentInfoRows[] = [
        'label' => __('Transaction ID'),
        'value' => $transactionIdentifier,
    ];

    $coupon = $orderPayable?->coupon;
    $couponCode = $normalizeDisplayString($orderPayable?->coupon_code) ?? $normalizeDisplayString($coupon?->code);

    if ($couponCode === null && is_array($orderPaymentSummary)) {
        $couponCode = $normalizeDisplayString(data_get($orderPaymentSummary, 'coupon.code'))
            ?? $normalizeDisplayString(data_get($orderPaymentSummary, 'coupon_code'));
    }

    if ($couponCode === null && $requestMeta !== []) {
        $couponCode = $normalizeDisplayString(data_get($requestMeta, 'coupon.code'))
            ?? $normalizeDisplayString(data_get($requestMeta, 'coupon_code'));
    }

    $couponName = $normalizeDisplayString($coupon?->name);

    if ($couponName === null && $requestMeta !== []) {
        $couponName = $normalizeDisplayString(data_get($requestMeta, 'coupon.name'));
    }

    $couponDescription = $normalizeDisplayString($coupon?->description);

    if ($couponDescription === null && $requestMeta !== []) {
        $couponDescription = $normalizeDisplayString(data_get($requestMeta, 'coupon.description'));
    }

    $couponDiscountType = $normalizeDisplayString($coupon?->discount_type);

    if ($couponDiscountType === null && $requestMeta !== []) {
        $couponDiscountType = $normalizeDisplayString(data_get($requestMeta, 'coupon.discount_type'));
    }

    if ($couponDiscountType === null && is_array($orderPaymentSummary)) {
        $couponDiscountType = $normalizeDisplayString(data_get($orderPaymentSummary, 'coupon.discount_type'));
    }

    $couponDiscountTypeNormalized = null;

    if ($couponDiscountType !== null) {
        $couponDiscountTypeNormalized = Str::slug($couponDiscountType, '_');
    }

    $couponDiscountValue = $normalizeNumeric($coupon?->discount_value);

    if ($couponDiscountValue === null && $requestMeta !== []) {
        $couponDiscountValue = $normalizeNumeric(data_get($requestMeta, 'coupon.discount_value'));
    }

    if ($couponDiscountValue === null && is_array($orderPaymentSummary)) {
        $couponDiscountValue = $normalizeNumeric(data_get($orderPaymentSummary, 'coupon.discount_value'));
    }

    $couponMinimumOrder = $normalizeNumeric($coupon?->minimum_order_amount);

    if ($couponMinimumOrder === null && $requestMeta !== []) {
        $couponMinimumOrder = $normalizeNumeric(data_get($requestMeta, 'coupon.minimum_order_amount'));
    }

    $couponAppliedAmount = $normalizeNumeric($orderPayable?->discount_amount);

    if ($couponAppliedAmount === null && is_array($orderPaymentSummary)) {
        $couponAppliedAmount = $normalizeNumeric(data_get($orderPaymentSummary, 'coupon_discount'));
    }

    if ($couponAppliedAmount === null && $requestMeta !== []) {
        $couponAppliedAmount = $normalizeNumeric(data_get($requestMeta, 'coupon.discount_applied'));
    }

    $couponDiscountTypeLabel = null;

    if (in_array($couponDiscountTypeNormalized, ['percentage', 'percent'], true)) {
        $couponDiscountTypeLabel = __('Manual Payment Coupon Type Percentage');
    } elseif (in_array($couponDiscountTypeNormalized, ['fixed', 'fixed_amount'], true)) {
        $couponDiscountTypeLabel = __('Manual Payment Coupon Type Fixed');
    } elseif ($couponDiscountType !== null) {
        $couponDiscountTypeLabel = Str::headline($couponDiscountType);
    }

    $couponDiscountValueDisplay = null;

    if ($couponDiscountValue !== null) {
        if (in_array($couponDiscountTypeNormalized, ['percentage', 'percent'], true)) {
            $formattedCouponPercentage = number_format($couponDiscountValue, 2);
            $percentageDisplay = rtrim(rtrim($formattedCouponPercentage, '0'), '.');
            $couponDiscountValueDisplay = ($percentageDisplay === '' ? '0' : $percentageDisplay) . '%';
        } else {
            $couponDiscountValueDisplay = $formatMoney($couponDiscountValue, $orderCurrency);
        }
    }

    $couponMinimumOrderDisplay = null;

    if ($couponMinimumOrder !== null && $couponMinimumOrder > 0) {
        $couponMinimumOrderDisplay = $formatMoney($couponMinimumOrder, $orderCurrency);
    }

    $couponAppliedAmountDisplay = null;

    if ($couponAppliedAmount !== null && $couponAppliedAmount > 0) {
        $couponAppliedAmountDisplay = $formatMoney($couponAppliedAmount, $orderCurrency);
    }

    $couponRows = [];

    if ($couponCode !== null) {
        $couponRows[] = [
            'label' => __('Manual Payment Coupon Code'),
            'value' => $couponCode,
        ];
    }

    if ($couponName !== null) {
        $couponRows[] = [
            'label' => __('Manual Payment Coupon Name'),
            'value' => $couponName,
        ];
    }

    if ($couponDiscountTypeLabel !== null) {
        $couponRows[] = [
            'label' => __('Manual Payment Coupon Type'),
            'value' => $couponDiscountTypeLabel,
        ];
    }

    if ($couponDiscountValueDisplay !== null) {
        $couponRows[] = [
            'label' => __('Manual Payment Coupon Value'),
            'value' => $couponDiscountValueDisplay,
        ];
    }

    if ($couponAppliedAmountDisplay !== null) {
        $couponRows[] = [
            'label' => __('Manual Payment Coupon Applied Discount'),
            'value' => $couponAppliedAmountDisplay,
        ];
    }

    if ($couponMinimumOrderDisplay !== null) {
        $couponRows[] = [
            'label' => __('Manual Payment Coupon Minimum Order'),
            'value' => $couponMinimumOrderDisplay,
        ];
    }

    if ($couponDescription !== null) {
        $couponRows[] = [
            'label' => __('Manual Payment Coupon Description'),
            'value' => $couponDescription,
            'format' => 'multiline',
        ];
    }

    if ($couponRows !== []) {
        $paymentInfoRows[] = [
            'section' => __('Manual Payment Coupon Details'),
        ];

        foreach ($couponRows as $couponRow) {
            $paymentInfoRows[] = $couponRow;
        }
    }


@endphp

<div class="manual-payment-review-content py-2">
    <div class="card shadow-sm mb-4">
        <div class="card-header bg-light">
            <h6 class="mb-0"><i class="fa fa-user me-2"></i>{{ __('User Details') }}</h6>
        </div>
        <div class="card-body">
            <div class="table-responsive">
                <table class="table table-sm table-bordered align-middle mb-0">
                    <thead class="table-light">
                        <tr>
                            <th class="text-muted text-uppercase small">{{ __('Name') }}</th>
                            <th class="text-muted text-uppercase small">{{ __('Email') }}</th>
                            <th class="text-muted text-uppercase small">{{ __('Mobile') }}</th>
                            <th class="text-muted text-uppercase small">{{ __('Submitted At') }}</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td class="text-break text-body">{{ $request->user?->name ?? __('N/A') }}</td>
                            <td class="text-break text-body">{{ $request->user?->email ?? __('N/A') }}</td>
                            <td class="text-break text-body">{{ $request->user?->mobile ?? __('N/A') }}</td>
                            <td class="text-break text-body">{{ $request->created_at?->format('Y-m-d H:i') ?? __('N/A') }}</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    <div class="card shadow-sm mb-4">
        <div class="card-header bg-light d-flex justify-content-between align-items-center">
            <h6 class="mb-0"><i class="fa fa-info-circle me-2"></i>{{ __('Payment Information') }}</h6>
            {!! $statusHtml !!}
        </div>
        <div class="card-body">
            @php
                $groupedPaymentInfo = [];
                $currentSectionKey = '__default';


                foreach ($paymentInfoRows as $row) {
                    if (isset($row['section'])) {
                        $sectionLabel = is_string($row['section']) ? trim($row['section']) : '';
                        $currentSectionKey = $sectionLabel !== '' ? $sectionLabel : '__default';

                        if (! array_key_exists($currentSectionKey, $groupedPaymentInfo)) {
                            $groupedPaymentInfo[$currentSectionKey] = [];
                        }

                        continue;
                    }

                    if (! array_key_exists($currentSectionKey, $groupedPaymentInfo)) {
                        $groupedPaymentInfo[$currentSectionKey] = [];
                    }

                    $groupedPaymentInfo[$currentSectionKey][] = $row;
                }

                $defaultSectionLabel = __('General Details');
            @endphp

            @foreach($groupedPaymentInfo as $sectionLabel => $rows)
                @php
                    $resolvedSectionLabel = $sectionLabel === '__default' ? $defaultSectionLabel : $sectionLabel;
                    $filteredRows = array_values(array_filter($rows, static function ($item) {
                        return is_array($item) && array_key_exists('label', $item);
                    }));
                @endphp


                @if($filteredRows === [])
                    @continue
                @endif

                @if($sectionLabel !== '__default')
                    <h6 class="fw-semibold text-primary mb-2">{{ $resolvedSectionLabel }}</h6>
                @elseif(! $loop->first)
                    <h6 class="fw-semibold text-primary mb-2">{{ $resolvedSectionLabel }}</h6>
                @endif

                <div class="table-responsive{{ $loop->last ? '' : ' mb-4' }}">
                    <table class="table table-sm table-bordered align-middle mb-0">
                        <thead class="table-light">
                            <tr>
                                @foreach($filteredRows as $row)
                                    <th class="text-muted text-uppercase small">{{ $row['label'] ?? __('N/A') }}</th>
                                @endforeach
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                @foreach($filteredRows as $row)
                                    @php
                                        $value = $row['value'] ?? null;
                                        $format = $row['format'] ?? null;
                                    @endphp
                                    <td class="text-break text-body">
                                        @if($format === 'multiline')
                                            @if($value === null || $value === '')
                                                {{ __('N/A') }}
                                            @else
                                                {!! nl2br(e($value)) !!}
                                            @endif
                                        @else
                                            {{ $value ?? __('N/A') }}
                                        @endif
                                    </td>
                                @endforeach
                            </tr>
                        </tbody>
                    </table>
                </div>
            @endforeach
        </div>
    </div>

    <div class="card shadow-sm mb-4">
        <div class="card-header bg-light">
            <h6 class="mb-0"><i class="fa fa-exchange-alt me-2"></i>{{ __('Transfer Information') }}</h6>
        </div>
        <div class="card-body">
            @php
                $resolvedTransferDetails = is_array($transferDetails) ? $transferDetails : [];
                $transferDisplay = [];

                $resolvedBankName = is_string($transferDetailsBankName) ? trim($transferDetailsBankName) : null;
                if ($resolvedBankName !== null && $resolvedBankName !== '') {
                    $transferDisplay[__('Bank Name')] = $resolvedBankName;
                }

                $senderName = $resolvedTransferDetails['sender_name'] ?? null;
                if (is_numeric($senderName) && ! is_string($senderName)) {
                    $senderName = (string) $senderName;
                } elseif (is_string($senderName)) {
                    $senderName = trim($senderName);
                } else {
                    $senderName = null;

                }

                if ($senderName !== null && $senderName !== '') {
                    $transferDisplay[__('Sender Name')] = $senderName;
                }

                $transferReference = $resolvedTransferDetails['transfer_reference'] ?? null;
                if (is_numeric($transferReference) && ! is_string($transferReference)) {
                    $transferReference = (string) $transferReference;
                } elseif (is_string($transferReference)) {
                    $transferReference = trim($transferReference);
                } else {
                    $transferReference = null;


                }

                if ($transferReference !== null && $transferReference !== '') {
                    $transferDisplay[__('Transfer Reference')] = $transferReference;
                }

                $transferNote = $resolvedTransferDetails['note'] ?? null;
                if (is_numeric($transferNote) && ! is_string($transferNote)) {
                    $transferNote = (string) $transferNote;
                } elseif (is_string($transferNote)) {
                    $transferNote = trim($transferNote);
                } else {
                    $transferNote = null;

                }

                if ($transferNote !== null && $transferNote !== '') {
                    $transferDisplay[__('Additional Notes')] = $transferNote;
                }
            @endphp

            @if($transferDisplay !== [])
                <div class="table-responsive">
                    <table class="table table-sm table-bordered align-middle mb-0">
                        <thead class="table-light">
                            <tr>
                                @foreach($transferDisplay as $label => $value)
                                    <th class="text-muted text-uppercase small">{{ $label }}</th>
                                @endforeach
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                @foreach($transferDisplay as $label => $value)
                                    @php
                                        $stringValue = is_string($value) ? $value : (is_numeric($value) ? (string) $value : '');
                                    @endphp
                                    <td class="text-break text-body">
                                        @if($stringValue !== '' && Str::contains($stringValue, "\n"))
                                            {!! nl2br(e($stringValue)) !!}
                                        @else
                                            {{ $stringValue !== '' ? $stringValue : __('N/A') }}
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


        @include('payments.manual.partials.payable-summary', ['request' => $request])


    <div class="card shadow-sm mt-4">
        <div class="card-header bg-light">
            <h6 class="mb-0"><i class="fa fa-file-invoice-dollar me-2"></i>{{ __('Receipt') }}</h6>
        </div>
        <div class="card-body">
            @include('payments.manual.partials.receipt', ['request' => $request, 'receiptUrl' => $transferReceiptUrl])
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
                @if(! $readOnly)
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
                @else
                    <p class="text-muted mb-0">{{ __('Gateway actions are available only for manual payment requests.') }}</p>
                @endif

                @if(!empty($eastYemenMeta))
                    <hr class="my-4">
                    <h6 class="mb-2">{{ __('Recent Gateway Activity') }}</h6>
                    <pre class="bg-light border rounded p-3 small mb-0">@json($eastYemenMeta, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)</pre>
                @endif
            </div>
        </div>
    @endif



    @if(! $readOnly)
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
    @endif

    
        </div>
    </div>
</div>