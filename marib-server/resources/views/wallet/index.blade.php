@extends('layouts.main')

@section('title')
    {{ __('Wallet Accounts') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center g-2">
            <div class="col-12 col-md-6 order-md-1 order-last text-center text-md-start">

                <h4 class="mb-0">@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-center text-md-end">
                <nav aria-label="breadcrumb" class="breadcrumb-header">
                    <ol class="breadcrumb mb-0 justify-content-center justify-content-md-end">
                        <li class="breadcrumb-item"><a href="{{ route('home') }}">{{ __('Dashboard') }}</a></li>
                        <li class="breadcrumb-item active" aria-current="page">{{ __('Wallet Accounts') }}</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-3">
            <div class="col-12">
                <div class="row g-3 mb-3">
                    <div class="col-xl-3 col-lg-4 col-md-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex align-items-center justify-content-between mb-3">
                                    <span class="badge rounded-pill bg-primary-subtle text-primary fs-6">
                                        <i class="bi bi-wallet2"></i>
                                    </span>
                                    <span class="badge bg-primary text-white">{{ $currency }}</span>
                                </div>
                                <p class="text-muted small mb-1">{{ __('Total Balance') }}</p>


                                <h3 class="fw-bold mb-0">{{ number_format($totalBalance, 2) }}</h3>
                            </div>
                        </div>
                    </div>
                    <div class="col-xl-3 col-lg-4 col-md-6">

                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex align-items-center justify-content-between mb-3">
                                    <span class="badge rounded-pill bg-success-subtle text-success fs-6">
                                        <i class="bi bi-people"></i>
                                    </span>
                                    <span class="badge bg-success-subtle text-success">{{ __('Users') }}</span>
                                </div>
                                <p class="text-muted small mb-1">{{ __('Total Accounts') }}</p>


                                <h3 class="fw-bold mb-0">{{ number_format($accountCount) }}</h3>
                            </div>
                        </div>
                    </div>
                    <div class="col-xl-3 col-lg-4 col-md-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex align-items-center justify-content-between mb-3">
                                    <span class="badge rounded-pill bg-info-subtle text-info fs-6">
                                        <i class="bi bi-clock-history"></i>
                                    </span>
                                    <span class="badge bg-info-subtle text-info">{{ __('Last Updated') }}</span>
                                </div>
                                <p class="text-muted small mb-1">{{ __('Latest Wallet Activity') }}</p>
                                <h3 class="fw-bold mb-0">{{ $lastUpdatedAt ? $lastUpdatedAt->diffForHumans() : __('No activity yet') }}</h3>
                            </div>
                        </div>
                    </div>
                    <div class="col-xl-3 col-lg-4 col-md-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex align-items-center justify-content-between mb-3">
                                    <span class="badge rounded-pill bg-warning-subtle text-warning fs-6">
                                        <i class="bi bi-arrow-repeat"></i>
                                    </span>
                                    <span class="badge bg-warning-subtle text-warning">{{ __('Recent Updates') }}</span>
                                </div>
                                <p class="text-muted small mb-1">{{ __('Accounts refreshed today') }}</p>
                                <h3 class="fw-bold mb-0">{{ number_format($recentlyUpdatedCount) }}</h3>
                            </div>
                        </div>
                    </div>

                </div>
            </div>

            <div class="col-12">
                <div class="card shadow-sm border-0">
                    <div class="card-header border-0 bg-white py-3">
                        <div class="d-flex flex-column flex-lg-row justify-content-between align-items-start align-items-lg-center gap-3">
                            <div>
                                <h5 class="card-title mb-1">{{ __('Wallet Directory') }}</h5>
                                <p class="text-muted small mb-0">{{ __('Search and manage user wallet accounts.') }}</p>
                            </div>
                            <form method="get" class="d-flex flex-column flex-sm-row gap-2 w-100 w-sm-auto" role="search">
                                <input type="search"
                                       name="search"
                                       value="{{ $search }}"
                                       class="form-control"
                                       placeholder="{{ __('Search by user name, email or mobile') }}">
                                <button type="submit" class="btn btn-primary d-flex align-items-center justify-content-center gap-2">
                                    <i class="bi bi-search"></i>
                                    <span>{{ __('Search') }}</span>

                                </button>
                            </form>
                        </div>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover align-middle mb-0">
                                
                            <thead class="table-light">
                                <tr>
                                    <th class="py-3">{{ __('User') }}</th>
                                    <th class="text-center py-3">{{ __('Balance') }}</th>
                                    <th class="py-3">{{ __('Updated At') }}</th>
                                    <th class="text-center text-md-end py-3">{{ __('Actions') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @forelse($accounts as $account)
                                    <tr class="table-row-spacious">
                                        <td class="py-4">
                                            <div class="d-flex align-items-center gap-3">
                                                <span class="d-inline-flex align-items-center justify-content-center rounded-circle bg-primary-subtle text-primary" style="width: 48px; height: 48px;">
                                                    <i class="bi bi-person-vcard fs-4"></i>
                                                </span>
                                                <div>
                                                    <div class="fw-semibold">{{ $account->user?->name ?? __('Unknown User') }}</div>
                                                    <div class="text-muted small">{{ $account->user?->email }}</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td class="text-center py-4">
                                            <span class="badge bg-warning-subtle text-dark fw-semibold px-3 py-2">
                                                <i class="bi bi-coin"></i>
                                                {{ number_format((float) $account->balance, 2) }} {{ $currency }}
                                            </span>
                                        </td>
                                        <td class="py-4">
                                            <div class="small text-muted">
                                                <i class="bi bi-calendar-event me-1"></i>
                                                {{ optional($account->updated_at)->format('Y-m-d H:i') ?? __('Not updated') }}
                                            </div>
                                        </td>
                                        <td class="text-center text-md-end py-4">
                                            @if($account->user)
                                                <div class="btn-toolbar justify-content-center justify-content-md-end gap-2 flex-wrap" role="toolbar" aria-label="{{ __('Actions') }}">
                                                    <button type="button"
                                                            class="btn btn-outline-secondary btn-sm d-flex align-items-center gap-2"
                                                            data-bs-toggle="offcanvas"
                                                            data-bs-target="#walletAccountPreview{{ $account->getKey() }}"
                                                            aria-controls="walletAccountPreview{{ $account->getKey() }}">
                                                        <i class="bi bi-eye"></i>
                                                        <span>{{ __('Preview') }}</span>
                                                    </button>
                                                    <a href="{{ route('wallet.show', $account->user) }}" class="btn btn-primary btn-sm d-flex align-items-center gap-2">
                                                        <i class="bi bi-wallet2"></i>
                                                        <span>{{ __('Open Wallet') }}</span>
                                                    </a>
                                                </div>
                                            @else
                                                <span class="text-muted">{{ __('No user record') }}</span>
                                            @endif
                                        </td>
                                    </tr>
                                    @if($account->user)
                                        @push('modals')
                                            <div class="offcanvas offcanvas-end" tabindex="-1" id="walletAccountPreview{{ $account->getKey() }}" aria-labelledby="walletAccountPreviewLabel{{ $account->getKey() }}">
                                                <div class="offcanvas-header">
                                                    <h5 class="offcanvas-title" id="walletAccountPreviewLabel{{ $account->getKey() }}">{{ __('Wallet Snapshot') }}</h5>
                                                    <button type="button" class="btn-close" data-bs-dismiss="offcanvas" aria-label="{{ __('Close') }}"></button>
                                                </div>
                                                <div class="offcanvas-body">
                                                    <div class="mb-3">
                                                        <p class="text-muted small mb-1">{{ __('Account Holder') }}</p>
                                                        <p class="fw-semibold mb-0">{{ $account->user?->name }}</p>
                                                        <p class="text-muted mb-0">{{ $account->user?->email }}</p>
                                                    </div>
                                                    <div class="mb-3">
                                                        <p class="text-muted small mb-1">{{ __('Current Balance') }}</p>
                                                        <p class="fw-bold fs-4 mb-0">
                                                            {{ number_format((float) $account->balance, 2) }} {{ $currency }}
                                                        </p>
                                                    </div>
                                                    <div class="mb-3">
                                                        <p class="text-muted small mb-1">{{ __('Last Updated') }}</p>
                                                        <p class="mb-0">{{ optional($account->updated_at)->format('Y-m-d H:i') ?? __('Not updated') }}</p>
                                                    </div>
                                                    <div class="d-grid gap-2">
                                                        <a href="{{ route('wallet.show', $account->user) }}" class="btn btn-primary">
                                                            <i class="bi bi-box-arrow-up-right"></i>
                                                            <span>{{ __('Open Wallet') }}</span>
                                                        </a>
                                                    </div>
                                                </div>
                                            </div>
                                        @endpush
                                    @endif

                                @empty
                                    <tr>
                                        <td colspan="4" class="text-center py-4 text-muted">
                                            <i class="bi bi-wallet2 display-6 d-block mb-2"></i>
                                            {{ __('No wallet accounts found for the current filters.') }}
                                        </td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                    @if($accounts->hasPages())
                        <div class="card-footer bg-white border-0">
                            {{ $accounts->links() }}
                        </div>
                    @endif
                </div>
            </div>
        </div>
    </section>
@endsection