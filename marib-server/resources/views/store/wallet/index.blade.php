@extends('layouts.main')

@section('title', __('merchant_wallet.page.title'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">{{ __('merchant_wallet.page.subtitle') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end flex-wrap gap-2">
                <a href="{{ route('merchant.dashboard') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i>
                    {{ __('merchant_wallet.page.back') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    @php
        $availableTabs = ['summary', 'transactions', 'withdrawals', 'request'];
        $activeTab = request('tab');
        if (! in_array($activeTab, $availableTabs, true)) {
            $activeTab = 'summary';
        }
    @endphp

    <section class="section">
        @if (! $wallet)
            <div class="alert alert-info mb-0">
                {{ __('merchant_wallet.messages.unavailable') }}
            </div>
        @else
            @php
                $walletAccount = $wallet['account'];
                $walletTransactions = $wallet['transactions'];
                $walletWithdrawals = $wallet['withdrawals'];
                $walletMethods = $wallet['methods'];
                $walletCurrency = $wallet['currency'] ?? strtoupper((string) config('app.currency', 'SAR'));
                $selectedMethodKey = old('preferred_method', array_key_first($walletMethods) ?? null);
                $minimumWithdrawal = $wallet['minimum_amount'] ?? 0;
                $walletMethodNames = collect($walletMethods)->mapWithKeys(static fn ($method, $key) => [$key => $method['name']])->all();
                $summaryTransactions = $walletTransactions->take(5);
                $summaryWithdrawals = $walletWithdrawals->take(5);
                $pendingSummary = $walletWithdrawals->where('status', \App\Models\WalletWithdrawalRequest::STATUS_PENDING);
                $approvedSummary = $walletWithdrawals->where('status', \App\Models\WalletWithdrawalRequest::STATUS_APPROVED);
                $pendingWithdrawalAmount = (float) $pendingSummary->sum('amount');
                $pendingWithdrawalCount = $pendingSummary->count();
                $withdrawalStatusClasses = [
                    \App\Models\WalletWithdrawalRequest::STATUS_PENDING => 'bg-warning text-dark',
                    \App\Models\WalletWithdrawalRequest::STATUS_APPROVED => 'bg-success',
                    \App\Models\WalletWithdrawalRequest::STATUS_REJECTED => 'bg-danger',
                ];
                $methodLabelResolver = static fn (string $methodKey) => $walletMethodNames[$methodKey] ?? \Illuminate\Support\Str::headline(str_replace('_', ' ', $methodKey));
            @endphp

            @if (session('success'))
                <div class="alert alert-success alert-dismissible fade show" role="alert">
                    {{ session('success') }}
                    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('merchant_wallet.page.close') }}"></button>
                </div>
            @endif

            <div class="card mb-4">
                <div class="card-body">
                    <div class="nav nav-pills flex-column flex-lg-row gap-2" role="tablist">
                        <a class="nav-link d-flex align-items-center gap-2 {{ $activeTab === 'summary' ? 'active' : '' }}" href="{{ route('merchant.wallet.index', ['tab' => 'summary']) }}">
                            <i class="bi bi-graph-up"></i>
                            <span>{{ __('merchant_wallet.tabs.summary') }}</span>
                        </a>
                        <a class="nav-link d-flex align-items-center gap-2 {{ $activeTab === 'transactions' ? 'active' : '' }}" href="{{ route('merchant.wallet.index', ['tab' => 'transactions']) }}">
                            <i class="bi bi-clock-history"></i>
                            <span>{{ __('merchant_wallet.tabs.transactions') }}</span>
                        </a>
                        <a class="nav-link d-flex align-items-center gap-2 {{ $activeTab === 'withdrawals' ? 'active' : '' }}" href="{{ route('merchant.wallet.index', ['tab' => 'withdrawals']) }}">
                            <i class="bi bi-arrow-repeat"></i>
                            <span>{{ __('merchant_wallet.tabs.withdrawals') }}</span>
                        </a>
                        <a class="nav-link d-flex align-items-center gap-2 {{ $activeTab === 'request' ? 'active' : '' }}" href="{{ route('merchant.wallet.index', ['tab' => 'request']) }}">
                            <i class="bi bi-upload"></i>
                            <span>{{ __('merchant_wallet.tabs.request') }}</span>
                        </a>
                    </div>
                </div>
            </div>

            <div class="tab-content">
                <div class="tab-pane fade {{ $activeTab === 'summary' ? 'show active' : '' }}">
                    <div class="row g-4">
                        <div class="col-xl-4">
                            <div class="card h-100">
                                <div class="card-header">
                                    <h5 class="mb-0">{{ __('merchant_wallet.summary.balance_title') }}</h5>
                                </div>
                                <div class="card-body">
                                    <div class="display-6 fw-semibold mb-2">
                                        {{ number_format($wallet['balance'], 2) }}
                                        <small class="text-muted">{{ $walletCurrency }}</small>
                                    </div>
                                    <p class="text-muted mb-0">
                                        {{ __('merchant_wallet.summary.balance_updated', [
                                            'datetime' => optional(optional($walletAccount)->updated_at)->format('Y-m-d H:i') ?? '—',
                                        ]) }}
                                    </p>
                                </div>
                            </div>
                        </div>
                        <div class="col-xl-4">
                            <div class="card h-100">
                                <div class="card-header">
                                    <h5 class="mb-0">{{ __('merchant_wallet.summary.pending_title') }}</h5>
                                </div>
                                <div class="card-body">
                                    <div class="display-6 fw-semibold mb-2">
                                        {{ number_format($pendingWithdrawalAmount, 2) }}
                                        <small class="text-muted">{{ $walletCurrency }}</small>
                                    </div>
                                    <p class="text-muted mb-0">
                                        {{ __('merchant_wallet.summary.pending_caption', ['count' => number_format($pendingWithdrawalCount)]) }}
                                    </p>
                                </div>
                            </div>
                        </div>
                        <div class="col-xl-4">
                            <div class="card h-100">
                                <div class="card-header">
                                    <h5 class="mb-0">{{ __('merchant_wallet.summary.activity_title') }}</h5>
                                </div>
                                <div class="card-body">
                                    <div class="row g-3">
                                        <div class="col-sm-6">
                                            <p class="text-muted mb-1">{{ __('merchant_wallet.summary.activity_transactions') }}</p>
                                            <h4 class="mb-0">{{ number_format($walletTransactions->count()) }}</h4>
                                        </div>
                                        <div class="col-sm-6">
                                            <p class="text-muted mb-1">{{ __('merchant_wallet.summary.activity_withdrawals') }}</p>
                                            <h4 class="mb-0">{{ number_format($walletWithdrawals->count()) }}</h4>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="row g-4 mt-2">
                        <div class="col-lg-6">
                            <div class="card h-100">
                                <div class="card-header d-flex justify-content-between align-items-center">
                                    <h5 class="mb-0">{{ __('merchant_wallet.summary.latest_transactions') }}</h5>
                                    <a href="{{ route('merchant.wallet.index', ['tab' => 'transactions']) }}" class="text-decoration-none">{{ __('merchant_wallet.summary.view_all') }}</a>
                                </div>
                                <div class="card-body p-0">
                                    @if ($summaryTransactions->isEmpty())
                                        <p class="text-muted m-3 mb-0">{{ __('merchant_wallet.summary.empty') }}</p>
                                    @else
                                        <div class="table-responsive">
                                            <table class="table table-sm align-middle mb-0">
                                                <thead>
                                                    <tr>
                                                        <th>{{ __('merchant_wallet.table.type') }}</th>
                                                        <th>{{ __('merchant_wallet.table.amount') }}</th>
                                                        <th>{{ __('merchant_wallet.table.date') }}</th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                    @foreach ($summaryTransactions as $transaction)
                                                        @php($isCredit = $transaction->type === 'credit')
                                                        <tr>
                                                            <td>
                                                                <span class="badge {{ $isCredit ? 'bg-success' : 'bg-danger' }}">
                                                                    {{ $isCredit ? __('merchant_wallet.transaction_types.credit') : __('merchant_wallet.transaction_types.debit') }}
                                                                </span>
                                                            </td>
                                                            <td>
                                                                {{ $isCredit ? '+' : '-' }}{{ number_format($transaction->amount, 2) }}
                                                                <small class="text-muted">{{ $transaction->currency }}</small>
                                                            </td>
                                                            <td>{{ optional($transaction->created_at)->format('Y-m-d H:i') }}</td>
                                                        </tr>
                                                    @endforeach
                                                </tbody>
                                            </table>
                                        </div>
                                    @endif
                                </div>
                            </div>
                        </div>
                        <div class="col-lg-6">
                            <div class="card h-100">
                                <div class="card-header d-flex justify-content-between align-items-center">
                                    <h5 class="mb-0">{{ __('merchant_wallet.summary.latest_withdrawals') }}</h5>
                                    <a href="{{ route('merchant.wallet.index', ['tab' => 'withdrawals']) }}" class="text-decoration-none">{{ __('merchant_wallet.summary.view_all') }}</a>
                                </div>
                                <div class="card-body p-0">
                                    @if ($summaryWithdrawals->isEmpty())
                                        <p class="text-muted m-3 mb-0">{{ __('merchant_wallet.summary.empty') }}</p>
                                    @else
                                        <div class="table-responsive">
                                            <table class="table table-sm align-middle mb-0">
                                                <thead>
                                                    <tr>
                                                        <th>{{ __('merchant_wallet.table.status') }}</th>
                                                        <th>{{ __('merchant_wallet.table.amount') }}</th>
                                                        <th>{{ __('merchant_wallet.table.method') }}</th>
                                                        <th>{{ __('merchant_wallet.table.date') }}</th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                    @foreach ($summaryWithdrawals as $withdrawal)
                                                        @php($statusClass = $withdrawalStatusClasses[$withdrawal->status] ?? 'bg-secondary')
                                                        <tr>
                                                            <td><span class="badge {{ $statusClass }}">{{ $withdrawal->statusLabel() }}</span></td>
                                                            <td>
                                                                {{ number_format($withdrawal->amount, 2) }}
                                                                <small class="text-muted">{{ $walletCurrency }}</small>
                                                            </td>
                                                            <td>{{ $methodLabelResolver($withdrawal->preferred_method) }}</td>
                                                            <td>{{ optional($withdrawal->created_at)->format('Y-m-d H:i') }}</td>
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

                <div class="tab-pane fade {{ $activeTab === 'transactions' ? 'show active' : '' }}">
                    <div class="card">
                        <div class="card-header">
                            <h5 class="mb-0">{{ __('merchant_wallet.transactions.title') }}</h5>
                        </div>
                        <div class="card-body p-0">
                            @if ($walletTransactions->isEmpty())
                                <p class="text-muted m-3">{{ __('merchant_wallet.transactions.empty') }}</p>
                            @else
                                <div class="table-responsive">
                                    <table class="table align-middle mb-0">
                                        <thead>
                                            <tr>
                                                <th>{{ __('merchant_wallet.table.type') }}</th>
                                                <th>{{ __('merchant_wallet.table.amount') }}</th>
                                                <th>{{ __('merchant_wallet.table.balance_after') }}</th>
                                                <th>{{ __('merchant_wallet.table.date') }}</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            @foreach ($walletTransactions as $transaction)
                                                @php($isCredit = $transaction->type === 'credit')
                                                <tr>
                                                    <td>
                                                        <span class="badge {{ $isCredit ? 'bg-success' : 'bg-danger' }}">
                                                            {{ $isCredit ? __('merchant_wallet.transaction_types.credit') : __('merchant_wallet.transaction_types.debit') }}
                                                        </span>
                                                    </td>
                                                    <td>
                                                        {{ $isCredit ? '+' : '-' }}{{ number_format($transaction->amount, 2) }}
                                                        <small class="text-muted">{{ $transaction->currency }}</small>
                                                    </td>
                                                    <td>
                                                        {{ number_format($transaction->balance_after, 2) }}
                                                        <small class="text-muted">{{ $transaction->currency }}</small>
                                                    </td>
                                                    <td>{{ optional($transaction->created_at)->format('Y-m-d H:i') }}</td>
                                                </tr>
                                            @endforeach
                                        </tbody>
                                    </table>
                                </div>
                            @endif
                        </div>
                    </div>
                </div>

                <div class="tab-pane fade {{ $activeTab === 'withdrawals' ? 'show active' : '' }}">
                    <div class="card">
                        <div class="card-header">
                            <h5 class="mb-0">{{ __('merchant_wallet.withdrawals.title') }}</h5>
                        </div>
                        <div class="card-body p-0">
                            @if ($walletWithdrawals->isEmpty())
                                <p class="text-muted m-3">{{ __('merchant_wallet.withdrawals.empty') }}</p>
                            @else
                                <div class="table-responsive">
                                    <table class="table align-middle mb-0">
                                        <thead>
                                            <tr>
                                                <th>{{ __('merchant_wallet.table.status') }}</th>
                                                <th>{{ __('merchant_wallet.table.amount') }}</th>
                                                <th>{{ __('merchant_wallet.table.method') }}</th>
                                                <th>{{ __('merchant_wallet.table.date') }}</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            @foreach ($walletWithdrawals as $withdrawal)
                                                @php($statusClass = $withdrawalStatusClasses[$withdrawal->status] ?? 'bg-secondary')
                                                <tr>
                                                    <td><span class="badge {{ $statusClass }}">{{ $withdrawal->statusLabel() }}</span></td>
                                                    <td>
                                                        {{ number_format($withdrawal->amount, 2) }}
                                                        <small class="text-muted">{{ $walletCurrency }}</small>
                                                    </td>
                                                    <td>{{ $methodLabelResolver($withdrawal->preferred_method) }}</td>
                                                    <td>{{ optional($withdrawal->created_at)->format('Y-m-d H:i') }}</td>
                                                </tr>
                                            @endforeach
                                        </tbody>
                                    </table>
                                </div>
                            @endif
                        </div>
                    </div>
                </div>

                <div class="tab-pane fade {{ $activeTab === 'request' ? 'show active' : '' }}">
                    <div class="card">
                        <div class="card-header">
                            <h5 class="mb-0">{{ __('merchant_wallet.form.title') }}</h5>
                        </div>
                        <div class="card-body">
                            <p class="text-muted">
                                {{ __('merchant_wallet.form.hint', ['amount' => number_format($minimumWithdrawal, 2), 'currency' => $walletCurrency]) }}
                            </p>
                            <form method="post" action="{{ route('merchant.wallet.withdraw') }}">
                                @csrf
                                <div class="row g-3">
                                    <div class="col-md-4">
                                        <label class="form-label">{{ __('merchant_wallet.form.amount') }}</label>
                                        <div class="input-group">
                                            <input
                                                type="number"
                                                step="0.01"
                                                min="{{ $minimumWithdrawal }}"
                                                name="amount"
                                                value="{{ old('amount') }}"
                                                class="form-control @error('amount') is-invalid @enderror"
                                            >
                                            <span class="input-group-text">{{ $walletCurrency }}</span>
                                            @error('amount')
                                                <div class="invalid-feedback">{{ $message }}</div>
                                            @enderror
                                        </div>
                                    </div>
                                    <div class="col-md-4">
                                        <label class="form-label">{{ __('merchant_wallet.table.method') }}</label>
                                        <select id="walletWithdrawalMethod" name="preferred_method" class="form-select @error('preferred_method') is-invalid @enderror">
                                            @foreach ($walletMethods as $methodKey => $methodData)
                                                <option value="{{ $methodKey }}" @selected($selectedMethodKey === $methodKey)>{{ $methodData['name'] }}</option>
                                            @endforeach
                                        </select>
                                        @error('preferred_method')
                                            <div class="invalid-feedback">{{ $message }}</div>
                                        @enderror
                                    </div>
                                    <div class="col-md-4">
                                        <label class="form-label">{{ __('merchant_wallet.form.notes') }}</label>
                                        <input type="text" name="notes" class="form-control @error('notes') is-invalid @enderror" value="{{ old('notes') }}" maxlength="500">
                                        @error('notes')
                                            <div class="invalid-feedback">{{ $message }}</div>
                                        @enderror
                                    </div>
                                </div>

                                @if (! empty($walletMethods))
                                    <div class="mt-4">
                                        @foreach ($walletMethods as $methodKey => $methodData)
                                            @php($methodFields = $methodData['fields'] ?? [])
                                            <div class="wallet-method-fields" data-wallet-method-fields="{{ $methodKey }}" style="{{ $selectedMethodKey === $methodKey ? '' : 'display: none;' }}">
                                                @if (! empty($methodData['description']))
                                                    <p class="text-muted">{{ $methodData['description'] }}</p>
                                                @endif
                                                <div class="row g-3">
                                                    @foreach ($methodFields as $field)
                                                        @php($fieldKey = $field['key'])
                                                        <div class="col-md-6">
                                                            <label class="form-label">
                                                                {{ $field['label'] }}
                                                                @if (! empty($field['required']))
                                                                    <span class="text-danger">*</span>
                                                                @endif
                                                            </label>
                                                            <input
                                                                type="text"
                                                                name="meta[{{ $field['key'] }}]"
                                                                value="{{ old('meta.' . $fieldKey) }}"
                                                                class="form-control @error('meta.' . $fieldKey) is-invalid @enderror"
                                                            >
                                                            @error('meta.' . $fieldKey)
                                                                <div class="invalid-feedback">{{ $message }}</div>
                                                            @enderror
                                                        </div>
                                                    @endforeach
                                                </div>
                                            </div>
                                        @endforeach
                                    </div>
                                @endif

                                <div class="mt-4 d-flex justify-content-end">
                                    <button type="submit" class="btn btn-primary">
                                        <i class="bi bi-upload me-1"></i>
                                        {{ __('merchant_wallet.form.submit') }}
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        @endif
    </section>
@endsection

@push('scripts')
    <script src="{{ asset('assets/js/custom/merchant-settings.js') }}"></script>
@endpush
