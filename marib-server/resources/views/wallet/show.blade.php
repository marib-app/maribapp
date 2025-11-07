@extends('layouts.main')

@section('title')
    {{ __('Wallet for :name', ['name' => $user->name]) }}
@endsection

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
        <div class="row g-3">
            <div class="col-lg-4">
                <div class="card shadow-sm border-0 mb-3">
                    <div class="card-body">
                        <div class="d-flex align-items-center mb-3">
                            <span class="avatar avatar-xl bg-warning-subtle text-warning rounded-circle d-flex align-items-center justify-content-center me-3">
                                <i class="bi bi-wallet2 fs-3"></i>
                            </span>
                            <div>
                                <h5 class="mb-0">{{ $user->name }}</h5>
                                <small class="text-muted">{{ $user->email }}</small>
                            </div>
                        </div>
                        <div class="border rounded-3 p-3 bg-light-subtle">
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <span class="text-muted fw-semibold">{{ __('Current Balance') }}</span>
                                <span class="badge bg-primary-subtle text-primary">{{ $currency }}</span>
                            </div>
                            <h2 class="fw-bold mb-3">{{ number_format((float) $walletAccount->balance, 2) }}</h2>
                            <dl class="row mb-0 small text-muted">
                                <dt class="col-6">{{ __('Account ID') }}</dt>
                                <dd class="col-6 text-end">{{ $walletAccount->getKey() }}</dd>
                                <dt class="col-6">{{ __('Last Transaction') }}</dt>
                                <dd class="col-6 text-end">{{ optional($latestTransaction?->created_at)->diffForHumans() ?? __('No transactions yet') }}</dd>
                                <dt class="col-6">{{ __('Total Movements') }}</dt>
                                <dd class="col-6 text-end">{{ number_format($transactions->total()) }}</dd>
                            </dl>
                        </div>
                    </div>
                </div>

                <div class="card shadow-sm border-0">
                    <div class="card-header bg-white border-0">
                        <h5 class="card-title mb-0">{{ __('Manual Credit') }}</h5>
                    </div>
                    <div class="card-body">
                        <form method="post" action="{{ route('wallet.credit', $user) }}" class="needs-validation" novalidate>
                            @csrf
                            <div class="mb-3">
                                <label for="amount" class="form-label">{{ __('Amount') }}</label>
                                <div class="input-group">
                                    <input type="number" step="0.01" min="0.01" class="form-control" id="amount" name="amount"
                                           value="{{ old('amount') }}" required placeholder="0.00">
                                    <span class="input-group-text">{{ $currency }}</span>
                                </div>
                                @error('amount')
                                <div class="text-danger small mt-1">{{ $message }}</div>
                                @enderror
                            </div>
                            <div class="mb-3">
                                <label for="operation_reference" class="form-label">{{ __('Operation reference') }}</label>
                                <input type="text" class="form-control" id="operation_reference" name="operation_reference"
                                       value="{{ old('operation_reference') }}" required maxlength="191"
                                       placeholder="{{ __('e.g. REF-2024-001') }}">
                                <div class="form-text">{{ __('Use a unique administrative reference to avoid duplicate credits.') }}</div>
                                @error('operation_reference')
                                <div class="text-danger small mt-1">{{ $message }}</div>
                                @enderror
                            </div>
                            <div class="mb-3">
                                <label for="notes" class="form-label">{{ __('Administrative notes') }}</label>
                                <textarea class="form-control" id="notes" name="notes" rows="3" maxlength="500"
                                          placeholder="{{ __('Explain the reason for this manual credit (optional).') }}">{{ old('notes') }}</textarea>
                                @error('notes')
                                <div class="text-danger small mt-1">{{ $message }}</div>
                                @enderror
                            </div>
                            <button type="submit" class="btn btn-primary w-100">
                                <i class="bi bi-plus-circle me-1"></i>{{ __('Credit Wallet') }}
                            </button>
                        </form>
                    </div>
                </div>
            </div>

            <div class="col-lg-8">
                <div class="card shadow-sm border-0 mb-3">
                    <div class="card-header bg-white border-0">
                        <div class="d-flex flex-column flex-lg-row justify-content-between align-items-start align-items-lg-center gap-3">
                            <div>
                                <h5 class="card-title mb-1">{{ __('Wallet Movements') }}</h5>
                                <p class="text-muted small mb-0">{{ __('Filter transactions similar to the mobile wallet view.') }}</p>
                            </div>
                            <form method="get" class="row g-2 align-items-end">
                                <div class="col-auto">
                                    <label for="filter" class="form-label mb-0">{{ __('Filter') }}</label>
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
                        <div class="table-responsive">
                            <table class="table table-hover mb-0">
                                <thead class="table-light">
                                <tr>
                                    <th>{{ __('Reference') }}</th>
                                    <th>{{ __('Type') }}</th>
                                    <th class="text-end">{{ __('Amount') }}</th>
                                    <th class="text-end">{{ __('Balance After') }}</th>
                                    <th>{{ __('Details') }}</th>
                                    <th>{{ __('Created At') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @forelse($transactions as $transaction)
                                    @php
                                        $metaReason = data_get($transaction->meta, 'reason');
                                        $operationReference = data_get($transaction->meta, 'operation_reference');
                                        $notes = data_get($transaction->meta, 'notes');
                                    @endphp
                                    <tr>
                                        <td>
                                            <div class="fw-semibold">#{{ $transaction->getKey() }}</div>
                                            @if($operationReference)
                                                <div class="small text-muted">{{ $operationReference }}</div>
                                            @endif
                                        </td>
                                        <td>
                                            <span class="badge {{ $transaction->type === 'credit' ? 'bg-success' : 'bg-danger' }}">
                                                {{ ucfirst($transaction->type) }}
                                            </span>
                                        </td>
                                        <td class="text-end">
                                            <span class="fw-semibold {{ $transaction->type === 'credit' ? 'text-success' : 'text-danger' }}">
                                                {{ number_format((float) $transaction->amount, 2) }}
                                            </span>
                                        </td>
                                        <td class="text-end">{{ number_format((float) $transaction->balance_after, 2) }}</td>
                                        <td>
                                            <div class="small text-muted">
                                                @if($transaction->manualPaymentRequest)
                                                    @php
                                                        $mprRef = \App\Support\Payments\ReferencePresenter::forManualRequest(
                                                            $transaction->manualPaymentRequest,
                                                            $transaction->paymentTransaction ?? null
                                                        );
                                                    @endphp
                                                    <div>{{ __('Manual payment request') }}: {{ $mprRef ?? $transaction->manualPaymentRequest->getKey() }}</div>
                                                @endif
                                                @if($transaction->paymentTransaction)
                                                    @php
                                                        $txRef = \App\Support\Payments\ReferencePresenter::forTransaction($transaction->paymentTransaction);
                                                    @endphp
                                                    <div>{{ __('Payment transaction') }}: {{ $txRef ?? $transaction->paymentTransaction->getKey() }}</div>
                                                @endif
                                                @if($metaReason)
                                                    <div>{{ __('Reason') }}: {{ \Illuminate\Support\Str::headline($metaReason) }}</div>
                                                @endif
                                                @if($notes)
                                                    <div>{{ __('Notes') }}: {{ $notes }}</div>
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
                                        <td colspan="6" class="text-center py-4 text-muted">
                                            <i class="bi bi-arrow-repeat display-6 d-block mb-2"></i>
                                            {{ __('No transactions found for the selected filter.') }}
                                        </td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                    @if($transactions->hasPages())
                        <div class="card-footer bg-white border-0">
                            {{ $transactions->links() }}
                        </div>
                    @endif
                </div>
            </div>
        </div>
    </section>
@endsection
