@php
    use App\Models\Item;
    use App\Models\Order;
    use App\Models\Package;
    use Illuminate\Support\Facades\Route;
    use Illuminate\Support\Str;

    $payable = $request->payable;
    $typeLabel = $request->payable_type
        ? Str::title(class_basename($request->payable_type))
        : __('Unassigned');
    $identifier = $request->payable_id ? '#' . $request->payable_id : __('N/A');
    $description = __('No additional details available.');
    $detailsUrl = null;
    $quickActions = [];

    if ($payable instanceof Order) {
        $typeLabel = __('Order');
        $identifier = $payable->order_number
            ? __('Order #:number', ['number' => $payable->order_number])
            : __('Order ID: :id', ['id' => $payable->id]);
        $description = __('Customer: :name', ['name' => $payable->user?->name ?? __('Unknown')]);
        $detailsUrl = Route::has('orders.show') ? route('orders.show', $payable, false) : null;
    } elseif ($payable instanceof Package) {
        $typeLabel = __('Package');
        $identifier = __('Package ID: :id', ['id' => $payable->id]);
        $description = $payable->name ?? __('Package without a title');
        $detailsUrl = Route::has('package.show') ? route('package.show', $payable, false) : null;
    } elseif ($payable instanceof Item) {
        $typeLabel = __('Advertisement');
        $identifier = $payable->slug
            ? __('Ad Slug: :slug', ['slug' => $payable->slug])
            : __('Ad ID: :id', ['id' => $payable->id]);
        $description = $payable->name ?? __('Advertisement without a title');
        $detailsUrl = Route::has('item.show') ? route('item.show', $payable, false) : null;
    } elseif (filled($request->payable_type)) {
        $description = __('The associated :type record could not be found.', ['type' => $typeLabel]);
    }
@endphp

<div class="card shadow-sm mt-4">
    <div class="card-header bg-light d-flex justify-content-between align-items-center">
        <h6 class="mb-0"><i class="fa fa-link me-2"></i>{{ __('Linked Record') }}</h6>
        <span class="badge bg-info text-dark">{{ $typeLabel }}</span>
    </div>
    <div class="card-body">
        @if($payable)
            <dl class="row mb-0">
                <dt class="col-sm-4 text-muted">{{ __('Identifier') }}</dt>
                <dd class="col-sm-8">{{ $identifier }}</dd>

                <dt class="col-sm-4 text-muted">{{ __('Summary') }}</dt>
                <dd class="col-sm-8">{{ $description }}</dd>

                @if($detailsUrl)
                    <dt class="col-sm-4 text-muted">{{ __('Details') }}</dt>
                    <dd class="col-sm-8">
                        <a href="{{ $detailsUrl }}" target="_blank" rel="noopener" class="text-decoration-none">
                            {{ __('Open in a new tab') }}
                            <i class="fa fa-external-link-alt ms-1"></i>
                        </a>
                    </dd>
                    @php
                        if ($payable instanceof Order) {
                            $quickActions[] = [
                                'label' => __('Manual Payment Open Order Details'),
                                'href' => $detailsUrl,
                                'icon' => 'fa fa-external-link-alt',
                            ];
                        }
                    @endphp

                @endif
            </dl>


            @if($payable instanceof Order)
                @php
                    $orderStatusLabel = Str::of(Order::statusLabel($payable->order_status))->trim()->value();
                    $paymentStatus = is_string($payable->payment_status) ? strtolower($payable->payment_status) : null;
                    $paymentStatusLabel = $paymentStatus
                        ? (Order::paymentStatusLabels()[$paymentStatus] ?? Str::of($payable->payment_status)->replace('_', ' ')->headline())
                        : '';
                    $orderCreatedAt = $payable->created_at?->format('Y-m-d H:i');
                    $sellerName = $payable->seller?->name;
                    $currency = $payable->currency ?? $request->currency ?? config('app.currency', 'SAR');
                    $formatMoney = static function ($value) use ($currency) {
                        if ($value === null) {
                            return __('N/A');
                        }

                        if (is_numeric($value)) {
                            return number_format((float) $value, 2) . ' ' . $currency;
                        }

                        return (string) $value;
                    };
                    $orderTotal = $payable->final_amount ?? $payable->total_amount ?? null;
                    $depositPaid = (float) ($payable->deposit_amount_paid ?? 0);
                    $depositRemaining = (float) ($payable->deposit_remaining_balance ?? 0);
                    $depositIncludesShipping = (bool) ($payable->deposit_includes_shipping ?? false);
                    $paymentSummary = $payable->payment_summary;
                    $financialRows = [];

                    if ($orderTotal !== null) {
                        $financialRows[] = [
                            'label' => __('Manual Payment Order Total'),
                            'value' => $formatMoney($orderTotal),
                        ];
                    }

                    if ($depositPaid > 0) {
                        $financialRows[] = [
                            'label' => __('Manual Payment Advance Paid'),
                            'value' => $formatMoney($depositPaid),
                        ];
                    }

                    if ($depositRemaining > 0) {
                        $financialRows[] = [
                            'label' => __('Manual Payment Advance Remaining'),
                            'value' => $formatMoney($depositRemaining),
                        ];
                    }

                    if (is_array($paymentSummary)) {
                        $summaryLabels = [
                            'remaining_balance' => __('Manual Payment Outstanding Balance'),
                            'online_paid_total' => __('Manual Payment Online Paid'),
                            'online_outstanding' => __('Manual Payment Online Outstanding'),
                            'cod_due' => __('Manual Payment COD Due'),
                            'cod_outstanding' => __('Manual Payment COD Outstanding'),
                        ];

                        foreach ($summaryLabels as $key => $label) {
                            $value = data_get($paymentSummary, $key);

                            if ($value === null) {
                                continue;
                            }

                            $numericValue = is_numeric($value) ? (float) $value : null;

                            if ($numericValue === null || abs($numericValue) < 0.0001) {
                                continue;
                            }

                            $financialRows[] = [
                                'label' => $label,
                                'value' => $formatMoney($numericValue),
                            ];
                        }
                    }

                    $depositReceipts = is_array($payable->deposit_receipts ?? null) ? $payable->deposit_receipts : [];
                    $canViewDepositReceipts = ! empty($depositReceipts) && Route::has('orders.deposit-receipts');
                    $depositReceiptsUrl = $canViewDepositReceipts ? route('orders.deposit-receipts', $payable) : null;

                    $followUpItems = [];

                    if ($depositPaid > 0) {
                        $followUpItems[] = __('Manual Payment Follow Up Deposit', ['amount' => $formatMoney($depositPaid)]);
                    }

                    $outstandingBalance = null;

                    if (is_array($paymentSummary)) {
                        $outstandingBalance = data_get($paymentSummary, 'remaining_balance');
                    }

                    if ($outstandingBalance === null && $depositRemaining > 0) {
                        $outstandingBalance = $depositRemaining;
                    }

                    if ($outstandingBalance !== null && is_numeric($outstandingBalance) && (float) $outstandingBalance > 0) {
                        $followUpItems[] = __('Manual Payment Follow Up Outstanding', ['amount' => $formatMoney((float) $outstandingBalance)]);
                    }

                    if ($depositReceiptsUrl) {
                        $quickActions[] = [
                            'label' => __('Manual Payment View Deposit Receipts'),
                            'href' => $depositReceiptsUrl,
                            'icon' => 'fa fa-receipt',
                        ];
                    }


                    $followUpItems[] = __('Manual Payment Follow Up Review Order');
                    $followUpItems[] = __('Manual Payment Follow Up Update Status');

                @endphp

                <hr class="my-4">
                <div class="row g-4 align-items-start">
                    <div class="col-lg-6">
                        <h6 class="fw-semibold mb-3">
                            <i class="fa fa-clipboard-list me-2"></i>{{ __('Manual Payment Order Overview') }}
                        </h6>
                        <dl class="row mb-0">
                            <dt class="col-sm-5 text-muted">{{ __('Manual Payment Order Status') }}</dt>
                            <dd class="col-sm-7">{{ $orderStatusLabel !== '' ? $orderStatusLabel : __('N/A') }}</dd>

                            <dt class="col-sm-5 text-muted">{{ __('Manual Payment Payment Status') }}</dt>
                            <dd class="col-sm-7">{{ $paymentStatusLabel !== '' ? $paymentStatusLabel : __('N/A') }}</dd>

                            <dt class="col-sm-5 text-muted">{{ __('Manual Payment Seller') }}</dt>
                            <dd class="col-sm-7">{{ $sellerName ?? __('N/A') }}</dd>

                            <dt class="col-sm-5 text-muted">{{ __('Manual Payment Order Created') }}</dt>
                            <dd class="col-sm-7">{{ $orderCreatedAt ?? __('N/A') }}</dd>
                        </dl>
                    </div>

                    <div class="col-lg-6">
                        <h6 class="fw-semibold mb-3">
                            <i class="fa fa-coins me-2"></i>{{ __('Manual Payment Payment Breakdown') }}
                        </h6>
                        <dl class="row mb-0">
                            @foreach($financialRows as $row)
                                <dt class="col-sm-6 text-muted">{{ $row['label'] }}</dt>
                                <dd class="col-sm-6">{{ $row['value'] }}</dd>
                            @endforeach
                        </dl>

                        @if($depositIncludesShipping && $depositPaid > 0)
                            <p class="small text-muted mt-3 mb-0">
                                <i class="fa fa-info-circle me-1"></i>{{ __('Manual Payment Deposit Includes Delivery') }}
                            </p>
                        @endif


                    </div>
                </div>

                @if(! empty($followUpItems))
                    <div class="alert alert-info mt-4 mb-0" role="alert">
                        <h6 class="fw-semibold mb-2">
                            <i class="fa fa-tasks me-2"></i>{{ __('Manual Payment Follow Up Guidance') }}
                        </h6>
                        <ul class="mb-0 ps-3">
                            @foreach($followUpItems as $item)
                                <li>{{ $item }}</li>
                            @endforeach
                        </ul>
                    </div>
                @endif

                @if(! empty($quickActions))
                    <div class="mt-4">
                        <h6 class="fw-semibold mb-2">
                            <i class="fa fa-bolt me-2"></i>{{ __('Manual Payment Follow Up Quick Actions') }}
                        </h6>
                        <div class="d-flex flex-wrap gap-2">
                            @foreach($quickActions as $action)
                                <a href="{{ $action['href'] }}" target="_blank" rel="noopener"
                                   class="btn btn-outline-primary btn-sm d-inline-flex align-items-center gap-1">
                                    <i class="{{ $action['icon'] }}"></i>
                                    <span>{{ $action['label'] }}</span>
                                </a>
                            @endforeach
                        </div>
                    </div>
                @endif

            @endif

        @else
            <p class="mb-0 text-muted">
                {{ __('No linked record is available for this manual payment request.') }}
            </p>
        @endif
    </div>
</div>