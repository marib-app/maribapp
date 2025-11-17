@extends('layouts.main')

@push('styles')
    <style>
        .wallet-pagination .pagination {
            flex-wrap: wrap;
            gap: 0.25rem;
        }

        .wallet-pagination .page-item .page-link {
            padding: 0.35rem 0.75rem;
            font-size: .875rem;
            border-radius: 0.75rem;
            min-width: 2.25rem;
            text-align: center;
        }

        .wallet-pagination .page-item .page-link svg,
        .wallet-pagination .page-item .page-link .fi {
            width: 1rem;
            height: 1rem;
        }
    </style>
@endpush

@section('title')
    {{ __('Wallet for :name', ['name' => $user->name]) }}
@endsection

@push('modals')
    <div class="modal fade" id="manualCreditModal" tabindex="-1" aria-labelledby="manualCreditModalLabel"
         aria-hidden="true">
        <div class="modal-dialog modal-lg modal-dialog-scrollable">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="manualCreditModalLabel">{{ __('Manual Deposit') }}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('Close') }}"></button>
                </div>
                <div class="modal-body">
                    <ul class="nav nav-tabs mb-3" role="tablist">
                        <li class="nav-item" role="presentation">
                            <button class="nav-link active" id="manual-credit-form-tab" data-bs-toggle="tab"
                                    data-bs-target="#manual-credit-form" type="button" role="tab">
                                <i class="bi bi-plus-circle me-1"></i>{{ __('New Deposit') }}
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="manual-credit-history-tab" data-bs-toggle="tab"
                                    data-bs-target="#manual-credit-history" type="button" role="tab">
                                <i class="bi bi-clock-history me-1"></i>{{ __('History') }}
                            </button>
                        </li>
                    </ul>
                    <div class="tab-content">
                        <div class="tab-pane fade show active" id="manual-credit-form" role="tabpanel"
                             aria-labelledby="manual-credit-form-tab">
                            <form method="post" action="{{ route('wallet.credit', $user) }}" class="needs-validation" novalidate>
                                @csrf
                                <div class="mb-3">
                                    <label for="modal_amount" class="form-label">{{ __('Amount') }}</label>
                                    <div class="input-group">
                                        <input type="number" step="0.01" min="0.01" class="form-control" id="modal_amount" name="amount"
                                               value="{{ old('amount') }}" required placeholder="0.00">
                                        <span class="input-group-text">{{ $currency }}</span>
                                    </div>
                                    @error('amount')
                                    <div class="text-danger small mt-1">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="mb-3">
                                    <label for="modal_operation_reference" class="form-label">{{ __('Operation reference') }}</label>
                                    <div class="input-group">
                                        <input type="text" class="form-control" id="modal_operation_reference" name="operation_reference"
                                               value="{{ old('operation_reference', $manualCreditReference) }}" readonly>
                                        <span class="input-group-text"><i class="bi bi-shield-lock"></i></span>
                                    </div>
                                    <div class="form-text">{{ __('Reference numbers are generated sequentially to avoid duplication.') }}</div>
                                    @error('operation_reference')
                                    <div class="text-danger small mt-1">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="mb-3">
                                    <label for="modal_notes" class="form-label">{{ __('Administrative notes') }}</label>
                                    <textarea class="form-control" id="modal_notes" name="notes" rows="3" maxlength="500"
                                              placeholder="{{ __('Optional internal notes for reference.') }}">{{ old('notes') }}</textarea>
                                    @error('notes')
                                    <div class="text-danger small mt-1">{{ $message }}</div>
                                    @enderror
                                </div>
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-plus-circle me-1"></i>{{ __('Credit Wallet') }}
                                </button>
                            </form>
                        </div>
                        <div class="tab-pane fade" id="manual-credit-history" role="tabpanel"
                             aria-labelledby="manual-credit-history-tab">
                            @if($manualCreditEntries->isEmpty())
                                <p class="text-muted mb-0">{{ __('No manual deposits have been recorded yet.') }}</p>
                            @else
                                <div class="table-responsive">
                                    <table class="table table-sm align-middle">
                                        <thead>
                                        <tr>
                                            <th>{{ __('Reference') }}</th>
                                            <th class="text-end">{{ __('Amount') }}</th>
                                            <th>{{ __('Created At') }}</th>
                                            <th>{{ __('Notes') }}</th>
                                        </tr>
                                        </thead>
                                        <tbody>
                                        @foreach($manualCreditEntries as $entry)
                                            <tr>
                                                <td>{{ data_get($entry->meta, 'operation_reference') ?? $entry->getKey() }}</td>
                                                <td class="text-end text-success">+{{ number_format((float) $entry->amount, 2) }} {{ $currency }}</td>
                                                <td>
                                                    <div>{{ optional($entry->created_at)->format('Y-m-d H:i') }}</div>
                                                    <small class="text-muted">{{ optional($entry->created_at)->diffForHumans() }}</small>
                                                </td>
                                                <td>
                                                    {{ data_get($entry->meta, 'notes') ?? '—' }}
                                                </td>
                                            </tr>
                                        @endforeach
                                        </tbody>
                                    </table>
                                </div>
                            @endif
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
@endpush

@push('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            document.querySelectorAll('[data-bs-tab-target]').forEach(function (trigger) {
                trigger.addEventListener('click', function () {
                    var targetSelector = this.getAttribute('data-bs-tab-target');
                    if (!targetSelector) {
                        return;
                    }
                    var tabTrigger = document.querySelector('[data-bs-toggle="tab"][data-bs-target=\"' + targetSelector + '\"]');
                    if (tabTrigger) {
                        var tabInstance = bootstrap.Tab.getOrCreateInstance(tabTrigger);
                        tabInstance.show();
                    }
                });
            });
        @if ($errors->has('amount') || $errors->has('operation_reference') || $errors->has('notes'))
            var modalElement = document.getElementById('manualCreditModal');
            if (modalElement) {
                var modal = new bootstrap.Modal(modalElement);
                modal.show();
            }
        @endif
        });
    </script>
@endpush

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4 class="mb-0">@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-md-end">
                <nav aria-label="breadcrumb" class="breadcrumb-header">
                    <ol class="breadcrumb mb-0">
                        <li class="breadcrumb-item"><a href="{{ route('home') }}">{{ __('Dashboard') }}</a></li>
                        <li class="breadcrumb-item"><a href="{{ route('wallet.index') }}">{{ __('Wallet Accounts') }}</a></li>
                        <li class="breadcrumb-item active" aria-current="page">{{ $user->name }}</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
            <div class="d-flex flex-column">
                <span class="text-muted small">{{ __('Manual Deposits') }}</span>
                <h5 class="mb-0">{{ __('Wallet Overview') }}</h5>
            </div>
            <div class="d-flex flex-wrap gap-2">
                <button type="button"
                        class="btn btn-primary d-flex align-items-center gap-2"
                        data-bs-toggle="modal"
                        data-bs-target="#manualCreditModal"
                        data-bs-tab-target="#manual-credit-form">
                    <i class="bi bi-cash-stack"></i>
                    <span>{{ __('New Deposit') }}</span>
                </button>
                <button type="button"
                        class="btn btn-outline-secondary d-flex align-items-center gap-2"
                        data-bs-toggle="modal"
                        data-bs-target="#manualCreditModal"
                        data-bs-tab-target="#manual-credit-history">
                    <i class="bi bi-clock-history"></i>
                    <span>{{ __('History') }}</span>
                </button>
            </div>
        </div>
        <div class="row g-3">
            <div class="col-12">
                <div class="card shadow-sm border-0 mb-3">
                    <div class="card-body">
                        <div class="row g-3 align-items-center">
                            <div class="col-lg-6 d-flex align-items-center gap-3">
                                <span class="avatar avatar-xl bg-warning-subtle text-warning rounded-circle d-flex align-items-center justify-content-center">
                                    <i class="bi bi-wallet2 fs-3"></i>
                                </span>
                                <div>
                                    <p class="text-muted mb-1">{{ __('محفظة المستخدم') }}</p>
                                    <h4 class="mb-0">{{ $user->name }}</h4>
                                    <small class="text-muted">{{ $user->email }}</small>
                                </div>
                            </div>
                            <div class="col-lg-6 text-lg-end">
                                <p class="text-muted mb-1">{{ __('الرصيد الحالي') }}</p>
                                <h2 class="fw-bold mb-2">{{ number_format((float) $walletAccount->balance, 2) }} {{ $currency }}</h2>
                                <span class="badge bg-primary-subtle text-primary">{{ __('محدّث حتى') }} {{ now()->format('Y-m-d H:i') }}</span>
                            </div>
                        </div>
                        <div class="row g-3 mt-4">
                            <div class="col-6 col-md-3">
                                <div class="p-3 rounded-3 bg-light-subtle border text-center">
                                    <p class="text-muted small mb-1">{{ __('إجمالي الحركات') }}</p>
                                    <h5 class="fw-bold mb-0">{{ number_format($walletMetrics['total_transactions']) }}</h5>
                                </div>
                            </div>
                            <div class="col-6 col-md-3">
                                <div class="p-3 rounded-3 bg-success-subtle border text-center">
                                    <p class="text-muted small mb-1">{{ __('إجمالي الإيداعات') }}</p>
                                    <h5 class="fw-bold mb-0 text-success">
                                        {{ number_format((float) $walletMetrics['total_credits'], 2) }} {{ $currency }}
                                    </h5>
                                </div>
                            </div>
                            <div class="col-6 col-md-3">
                                <div class="p-3 rounded-3 bg-danger-subtle border text-center">
                                    <p class="text-muted small mb-1">{{ __('إجمالي الخصومات') }}</p>
                                    <h5 class="fw-bold mb-0 text-danger">
                                        {{ number_format((float) $walletMetrics['total_debits'], 2) }} {{ $currency }}
                                    </h5>
                                </div>
                            </div>
                            <div class="col-6 col-md-3">
                                <div class="p-3 rounded-3 bg-warning-subtle border text-center">
                                    <p class="text-muted small mb-1">{{ __('آخر عملية') }}</p>
                                    <h6 class="fw-bold mb-0">
                                        {{ optional($walletMetrics['last_activity'])->diffForHumans() ?? __('لا يوجد سجل بعد') }}
                                    </h6>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card shadow-sm border-0 mb-3">
                    <div class="card-header bg-white border-0">
                        <div class="d-flex flex-column gap-3">
                            <div class="d-flex flex-column flex-xl-row justify-content-between align-items-start align-items-xl-center gap-3">
                            <div>
                                <h5 class="card-title mb-1">{{ __('سجل الحركات المالية') }}</h5>
                                <p class="text-muted small mb-0">{{ __('يمكنك فلترة العمليات بحسب نوعها ومراجعة التفاصيل الدقيقة لكل عملية.') }}</p>
                            </div>
                            <form method="get" class="row g-2 align-items-end">
                                <div class="col-auto">
                                    <label for="filter" class="form-label mb-0">{{ __('نوع الحركة') }}</label>
                                </div>
                                <div class="col-auto">
                                    <select id="filter" name="filter" class="form-select" onchange="this.form.submit()">
                                        @foreach($filters as $filterOption)
                                            <option value="{{ $filterOption }}" @selected($appliedFilter === $filterOption)>
                                                {{ __('wallet.filters.' . $filterOption) }}
                                            </option>
                                        @endforeach
                                    </select>
                                </div>
                                <div class="col-auto">
                                    <a href="{{ route('wallet.show', ['user' => $user->getKey()]) }}" class="btn btn-outline-secondary">
                                        {{ __('Reset') }}
                                    </a>
                                </div>
                            </form>
                        </div>
                    </div>
                    <div class="card-body p-0">
                        <div class="tab-content">
                            <div class="tab-pane fade show active" id="wallet-ledger-transactions" role="tabpanel"
                                 aria-labelledby="wallet-ledger-transactions-tab">
                                <div class="table-responsive">
                                    <table class="table table-hover mb-0">
                                <thead class="table-light">
                                <tr>
                                    <th class="text-center">#</th>
                                    <th>{{ __('المرجع') }}</th>
                                    <th>{{ __('نوع الحركة') }}</th>
                                    <th class="text-end">{{ __('المبلغ') }}</th>
                                    <th class="text-end">{{ __('الرصيد بعد العملية') }}</th>
                                    <th>{{ __('تفاصيل إضافية') }}</th>
                                    <th>{{ __('تاريخ التنفيذ') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @php
                                    $rowNumber = ($transactions->currentPage() - 1) * $transactions->perPage();
                                @endphp
                                @forelse($transactions as $transaction)
                                    @php
                                        $metaReason = data_get($transaction->meta, 'reason');
                                        $operationReference = data_get($transaction->meta, 'operation_reference');
                                        $notes = data_get($transaction->meta, 'notes');
                                        $typeLabel = $transaction->type === 'credit' ? __('إيداع') : __('خصم');
                                        $typeBadgeClass = $transaction->type === 'credit' ? 'bg-success' : 'bg-danger';
                                    @endphp
                                    <tr>
                                        <td class="text-center fw-semibold">{{ ++$rowNumber }}</td>
                                        <td>
                                            <div class="fw-semibold">#{{ $transaction->getKey() }}</div>
                                            @if($operationReference)
                                                <div class="small text-muted">{{ $operationReference }}</div>
                                            @endif
                                        </td>
                                        <td>
                                            <span class="badge {{ $typeBadgeClass }}">
                                                {{ $typeLabel }}
                                            </span>
                                        </td>
                                        <td class="text-end">
                                            <span class="fw-semibold {{ $transaction->type === 'credit' ? 'text-success' : 'text-danger' }}">
                                                {{ number_format((float) $transaction->amount, 2) }} {{ $currency }}
                                            </span>
                                        </td>
                                        <td class="text-end">{{ number_format((float) $transaction->balance_after, 2) }} {{ $currency }}</td>
                                        <td>
                                            <div class="small text-muted d-flex flex-column gap-1">
                                                @if($transaction->manualPaymentRequest)
                                                    @php
                                                        $mprRef = \App\Support\Payments\ReferencePresenter::forManualRequest(
                                                            $transaction->manualPaymentRequest,
                                                            $transaction->paymentTransaction ?? null
                                                        );
                                                    @endphp
                                                    <div>
                                                        <i class="bi bi-file-earmark-text me-1"></i>
                                                        {{ __('طلب دفع يدوي') }}: {{ $mprRef ?? $transaction->manualPaymentRequest->getKey() }}
                                                    </div>
                                                @endif
                                                @if($transaction->paymentTransaction)
                                                    @php
                                                        $txRef = \App\Support\Payments\ReferencePresenter::forTransaction($transaction->paymentTransaction);
                                                    @endphp
                                                    <div>
                                                        <i class="bi bi-credit-card me-1"></i>
                                                        {{ __('عملية دفع') }}: {{ $txRef ?? $transaction->paymentTransaction->getKey() }}
                                                    </div>
                                                @endif
                                                @if($metaReason)
                                                    <div>
                                                        <i class="bi bi-info-circle me-1"></i>
                                                        {{ __('السبب') }}: {{ \Illuminate\Support\Str::headline($metaReason) }}
                                                    </div>
                                                @endif
                                                @if($notes)
                                                    <div>
                                                        <i class="bi bi-chat-text me-1"></i>
                                                        {{ __('ملاحظات') }}: {{ $notes }}
                                                    </div>
                                                @endif
                                            </div>
                                        </td>
                                        <td>
                                            <div class="small">{{ optional($transaction->created_at)->format('Y-m-d H:i') }}</div>
                                            <div class="text-muted small">{{ optional($transaction->created_at)->diffForHumans() }}</div>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="7" class="text-center py-4 text-muted">
                                            <i class="bi bi-inboxes display-6 d-block mb-2"></i>
                                            {{ __('لا توجد حركات مطابقة للفلتر الحالي.') }}
                                        </td>
                                    </tr>
                                @endforelse
                                </tbody>
                                    </table>
                                </div>
                            </div>
                    <div class="tab-pane fade" id="wallet-ledger-manual" role="tabpanel"
                         aria-labelledby="wallet-ledger-manual-tab">
                        <div class="table-responsive">
                            <table class="table table-striped mb-0">
                                <thead class="table-light">
                                <tr>
                                    <th class="text-center">#</th>
                                    <th>{{ __('Reference') }}</th>
                                    <th class="text-end">{{ __('Amount') }}</th>
                                    <th>{{ __('Created At') }}</th>
                                    <th>{{ __('Notes') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @php
                                    $manualRow = 0;
                                @endphp
                                @forelse($manualCreditEntries as $entry)
                                    <tr>
                                        <td class="text-center fw-semibold">{{ ++$manualRow }}</td>
                                        <td>{{ data_get($entry->meta, 'operation_reference') ?? $entry->getKey() }}</td>
                                        <td class="text-end text-success">+{{ number_format((float) $entry->amount, 2) }} {{ $currency }}</td>
                                        <td>
                                            <div>{{ optional($entry->created_at)->format('Y-m-d H:i') }}</div>
                                            <small class="text-muted">{{ optional($entry->created_at)->diffForHumans() }}</small>
                                        </td>
                                        <td>{{ data_get($entry->meta, 'notes') ?? __('Not available') }}</td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="5" class="text-center py-4 text-muted">
                                            <i class="bi bi-journal-x display-6 d-block mb-2"></i>
                                            {{ __('No manual deposits have been recorded yet.') }}
                                        </td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
                    @if($transactions->hasPages())
                        <div class="card-footer bg-white border-0 wallet-pagination">
                            {{ $transactions->onEachSide(1)->links('pagination::bootstrap-5') }}
                        </div>
                    @endif
                </div>
            </div>
        </div>
    </section>
@endsection



