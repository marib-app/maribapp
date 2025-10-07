@extends('layouts.main')

@php
    use Illuminate\Support\Str;
@endphp

@section('title')
    {{ __('Wallet Withdrawal Requests') }}
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
                        <li class="breadcrumb-item"><a href="{{ route('wallet.index') }}">{{ __('Wallet Accounts') }}</a></li>
                        <li class="breadcrumb-item active" aria-current="page">{{ __('Withdrawal Requests') }}</li>
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
                    @foreach($statusSummaries as $summary)
                        <div class="col-xl-3 col-md-6">
                            <div class="card shadow-sm border-0 h-100">
                                <div class="card-body">
                                    <div class="d-flex align-items-center justify-content-between mb-3">
                                        <span class="badge rounded-pill {{ match($summary['status']) {
                                            \App\Models\WalletWithdrawalRequest::STATUS_APPROVED => 'bg-success-subtle text-success',
                                            \App\Models\WalletWithdrawalRequest::STATUS_REJECTED => 'bg-danger-subtle text-danger',
                                            default => 'bg-warning-subtle text-warning'
                                        } }} fs-6">
                                            <i class="{{ match($summary['status']) {
                                                \App\Models\WalletWithdrawalRequest::STATUS_APPROVED => 'bi bi-check-circle',
                                                \App\Models\WalletWithdrawalRequest::STATUS_REJECTED => 'bi bi-x-circle',
                                                default => 'bi bi-hourglass-split'
                                            } }}"></i>
                                        </span>
                                        <span class="badge bg-secondary-subtle text-secondary">
                                            {{ number_format($summary['amount'], 2) }} {{ $currency }}
                                        </span>
                                    </div>
                                    <p class="text-muted small mb-1">{{ $summary['label'] }}</p>
                                    <h4 class="fw-bold mb-0">{{ number_format($summary['count']) }}</h4>
                                </div>
                            </div>
                        </div>
                    @endforeach
                    <div class="col-xl-3 col-md-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex align-items-center justify-content-between mb-3">
                                    <span class="badge rounded-pill bg-info-subtle text-info fs-6">
                                        <i class="bi bi-graph-up"></i>
                                    </span>
                                    <span class="badge bg-info-subtle text-info">{{ __('Total Volume') }}</span>
                                </div>
                                <p class="text-muted small mb-1">{{ __('Total withdrawal amount processed') }}</p>
                                <h4 class="fw-bold mb-0">{{ number_format($totalWithdrawalAmount, 2) }} {{ $currency }}</h4>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-3">
                    <div class="card-header bg-white border-0">
                        <div class="d-flex flex-column flex-lg-row justify-content-between align-items-start align-items-lg-center gap-3">
                            <div>
                                <h5 class="card-title mb-1">{{ __('Withdrawal Overview') }}</h5>
                                <p class="text-muted small mb-0">{{ __('Review and manage wallet withdrawal requests from users.') }}</p>
                            </div>
                            <form method="get" class="row g-2 align-items-end">
                                <div class="col-sm-6 col-lg-auto">
                                    <label for="status" class="form-label small mb-1">{{ __('Status') }}</label>
                                    <select id="status" name="status" class="form-select" onchange="this.form.submit()">
                                        <option value="">{{ __('All statuses') }}</option>
                                        @foreach($statusOptions as $value => $label)
                                            <option value="{{ $value }}" @selected($filters['status'] === $value)>{{ $label }}</option>
                                        @endforeach
                                    </select>
                                </div>
                                <div class="col-sm-6 col-lg-auto">
                                    <label for="method" class="form-label small mb-1">{{ __('Withdrawal Method') }}</label>
                                    <select id="method" name="method" class="form-select" onchange="this.form.submit()">
                                        <option value="">{{ __('All methods') }}</option>
                                        @foreach($methodOptions as $value => $option)
                                            <option value="{{ $value }}" @selected($filters['method'] === $value)>{{ $option['name'] }}</option>
                                        @endforeach
                                    </select>
                                </div>
                                <div class="col-lg-auto">
                                    <a href="{{ route('wallet.withdrawals.index') }}" class="btn btn-outline-secondary w-100">
                                        <i class="bi bi-arrow-repeat me-1"></i>{{ __('Reset') }}
                                    </a>
                                </div>
                            </form>
                        </div>
                        <div class="border rounded-3 p-3 mt-3 bg-light-subtle">
                            <div class="d-flex flex-column flex-lg-row align-items-center justify-content-between gap-3">
                                <div class="d-flex align-items-center gap-2">
                                    <span class="badge bg-primary text-white">
                                        <i class="bi bi-lightning-charge"></i>
                                    </span>
                                    <div>
                                        <p class="fw-semibold mb-0">{{ __('Quick Decision Bar') }}</p>
                                        <p class="text-muted small mb-0">{{ __('Approve or reject pending withdrawals directly from this toolbar.') }}</p>
                                    </div>
                                </div>
                                <div class="btn-group" role="group" aria-label="{{ __('Quick Decision Bar') }}">
                                    <a href="{{ request()->fullUrlWithQuery(['status' => \App\Models\WalletWithdrawalRequest::STATUS_PENDING]) }}" class="btn btn-warning d-flex align-items-center gap-2">
                                        <i class="bi bi-hourglass-split"></i>
                                        <span>{{ __('View Pending') }}</span>
                                    </a>
                                    <a href="{{ request()->fullUrlWithQuery(['status' => \App\Models\WalletWithdrawalRequest::STATUS_APPROVED]) }}" class="btn btn-success d-flex align-items-center gap-2">
                                        <i class="bi bi-check-circle"></i>
                                        <span>{{ __('View Approved') }}</span>
                                    </a>
                                    <a href="{{ request()->fullUrlWithQuery(['status' => \App\Models\WalletWithdrawalRequest::STATUS_REJECTED]) }}" class="btn btn-danger d-flex align-items-center gap-2">
                                        <i class="bi bi-x-circle"></i>
                                        <span>{{ __('View Rejected') }}</span>
                                    </a>
                                </div>
                            </div>
                        </div>

                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card shadow-sm border-0">
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover align-middle mb-0">
                                <thead class="table-light">
                                <tr>
                                    <th class="py-3">{{ __('Request') }}</th>
                                    <th class="py-3">{{ __('User') }}</th>
                                    <th class="text-center text-md-start py-3">{{ __('Amount') }}</th>
                                    <th class="py-3">{{ __('Method') }}</th>
                                    <th class="py-3">{{ __('Notes') }}</th>
                                    <th class="py-3">{{ __('Requested At') }}</th>
                                    <th class="text-center text-md-end py-3">{{ __('Actions') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @forelse($withdrawals as $withdrawal)
                                    @php
                                        $statusClass = match ($withdrawal->status) {
                                            \App\Models\WalletWithdrawalRequest::STATUS_APPROVED => 'bg-success-subtle text-success',
                                            \App\Models\WalletWithdrawalRequest::STATUS_REJECTED => 'bg-danger-subtle text-danger',
                                            default => 'bg-warning-subtle text-warning'
                                        };
                                        $methodLabel = $methodOptions[$withdrawal->preferred_method]['name'] ?? Str::headline(str_replace('_', ' ', $withdrawal->preferred_method));
                                    @endphp
                                    <tr class="table-row-spacious">
                                        <td class="py-4">
                                            <div class="d-flex align-items-center gap-3">
                                                <span class="d-inline-flex align-items-center justify-content-center rounded-circle bg-secondary-subtle text-secondary" style="width: 48px; height: 48px;">
                                                    <i class="bi bi-receipt fs-4"></i>
                                                </span>
                                                <div>
                                                    <div class="fw-semibold">#{{ $withdrawal->getKey() }}</div>
                                                    <span class="badge {{ $statusClass }} mt-2">{{ $statusOptions[$withdrawal->status] ?? Str::headline($withdrawal->status) }}</span>
                                                </div>
                                            </div>

                                        </td>
                                        <td class="py-4">
                                            <div class="d-flex align-items-center gap-3">
                                                <span class="d-inline-flex align-items-center justify-content-center rounded-circle bg-primary-subtle text-primary" style="width: 48px; height: 48px;">
                                                    <i class="bi bi-person-circle fs-4"></i>
                                                </span>
                                                <div>
                                                    <div class="fw-semibold">{{ $withdrawal->account?->user?->name ?? __('Unknown User') }}</div>
                                                    <div class="text-muted small">{{ $withdrawal->account?->user?->email }}</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td class="text-center text-md-start py-4">
                                            <span class="badge bg-warning-subtle text-warning fw-semibold px-3 py-2">
                                                <i class="bi bi-cash-stack"></i>
                                                {{ number_format((float) $withdrawal->amount, 2) }} {{ $currency }}
                                            </span>

                                        </td>
                                        <td class="py-4">
                                            <span class="badge bg-info-subtle text-info">{{ $methodLabel }}</span>
                                            @if($withdrawal->wallet_reference)
                                                <div class="text-muted small mt-1 d-flex align-items-center gap-2">
                                                    <i class="bi bi-link-45deg"></i>
                                                    <span>{{ $withdrawal->wallet_reference }}</span>
                                                </div>
                                                
                                                @endif
                                        </td>
                                        <td class="py-4">
                                            @if($withdrawal->notes)
                                                <div class="small">{{ $withdrawal->notes }}</div>
                                            @else
                                                <span class="text-muted small">{{ __('No notes provided.') }}</span>
                                            @endif
                                            @if($withdrawal->review_notes)
                                                <div class="small text-muted mt-1">{{ __('Reviewer notes:') }} {{ $withdrawal->review_notes }}</div>
                                            @endif
                                        </td>
                                        <td class="py-4">
                                            <div class="small d-flex align-items-center gap-2">
                                                <i class="bi bi-calendar-week"></i>
                                                <span>{{ optional($withdrawal->created_at)->format('Y-m-d H:i') }}</span>
                                            </div>
                                            <div class="text-muted small mt-1 d-flex align-items-center gap-2">
                                                <i class="bi bi-clock-history"></i>
                                                <span>{{ optional($withdrawal->created_at)->diffForHumans() }}</span>
                                            </div>

                                        </td>
                                        <td class="text-center text-md-end py-4">
                                            <div class="btn-toolbar justify-content-center justify-content-md-end gap-2 flex-wrap" role="toolbar" aria-label="{{ __('Actions') }}">
                                                <button type="button" class="btn btn-outline-secondary btn-sm d-flex align-items-center gap-2"
                                                        data-bs-toggle="offcanvas"
                                                        data-bs-target="#withdrawalPreview{{ $withdrawal->getKey() }}"
                                                        aria-controls="withdrawalPreview{{ $withdrawal->getKey() }}">
                                                    <i class="bi bi-eye"></i>
                                                    <span>{{ __('Preview') }}</span>
                                                </button>
                                                @if($withdrawal->isPending())
                                                    <form method="post" action="{{ route('wallet.withdrawals.approve', $withdrawal) }}" class="d-flex">


                                                        @csrf
                                                        <button type="submit" class="btn btn-success btn-sm d-flex align-items-center gap-2" onclick="return confirm('{{ __('Approve this withdrawal request?') }}');">
                                                            <i class="bi bi-check-circle"></i>
                                                            <span>{{ __('Approve') }}</span>

                                                        </button>
                                                    </form>
                                                    <form method="post" action="{{ route('wallet.withdrawals.reject', $withdrawal) }}" class="d-flex">
                                                        @csrf
                                                        <button type="submit" class="btn btn-danger btn-sm d-flex align-items-center gap-2" onclick="return confirm('{{ __('Reject this withdrawal request?') }}');">
                                                            <i class="bi bi-x-circle"></i>
                                                            <span>{{ __('Reject') }}</span>
                                                        </button>
                                                    </form>
                                                @else
                                                    <span class="badge bg-secondary-subtle text-secondary">{{ __('Processed') }}</span>
                                                @endif
                                            </div>
                                        </td>
                                    </tr>
                                    @push('modals')
                                        <div class="offcanvas offcanvas-end" tabindex="-1" id="withdrawalPreview{{ $withdrawal->getKey() }}" aria-labelledby="withdrawalPreviewLabel{{ $withdrawal->getKey() }}">
                                            <div class="offcanvas-header">
                                                <h5 class="offcanvas-title" id="withdrawalPreviewLabel{{ $withdrawal->getKey() }}">{{ __('Withdrawal Snapshot') }}</h5>
                                                <button type="button" class="btn-close" data-bs-dismiss="offcanvas" aria-label="{{ __('Close') }}"></button>
                                            </div>
                                            <div class="offcanvas-body">
                                                <div class="mb-3">
                                                    <p class="text-muted small mb-1">{{ __('Request Identifier') }}</p>
                                                    <p class="fw-semibold mb-0">#{{ $withdrawal->getKey() }}</p>
                                                    <span class="badge {{ $statusClass }} mt-2">{{ $statusOptions[$withdrawal->status] ?? Str::headline($withdrawal->status) }}</span>
                                                </div>
                                                <div class="mb-3">
                                                    <p class="text-muted small mb-1">{{ __('Requested Amount') }}</p>
                                                    <p class="fw-bold fs-4 mb-0">{{ number_format((float) $withdrawal->amount, 2) }} {{ $currency }}</p>
                                                </div>
                                                <div class="mb-3">
                                                    <p class="text-muted small mb-1">{{ __('Preferred Method') }}</p>
                                                    <p class="mb-0">{{ $methodLabel }}</p>
                                                    @if($withdrawal->wallet_reference)
                                                        <a href="{{ $withdrawal->wallet_reference }}" target="_blank" rel="noopener" class="d-inline-flex align-items-center gap-1 mt-1">
                                                            <i class="bi bi-box-arrow-up-right"></i>
                                                            <span>{{ __('Open reference link') }}</span>
                                                        </a>
                                                    @endif
                                                </div>
                                                <div class="mb-3">
                                                    <p class="text-muted small mb-1">{{ __('Notes') }}</p>
                                                    <p class="mb-0">{{ $withdrawal->notes ?: __('No notes provided.') }}</p>
                                                </div>
                                                @if($withdrawal->review_notes)
                                                    <div class="mb-3">
                                                        <p class="text-muted small mb-1">{{ __('Review Notes') }}</p>
                                                        <p class="mb-0">{{ $withdrawal->review_notes }}</p>
                                                    </div>
                                                @endif
                                                @php
                                                    $documents = collect($withdrawal->meta['documents'] ?? [])->filter(fn ($doc) => filled($doc));
                                                @endphp
                                                <div class="mb-3">
                                                    <p class="text-muted small mb-2">{{ __('Supporting Documents') }}</p>
                                                    @if($documents->isNotEmpty())
                                                        <ul class="list-unstyled mb-0 d-grid gap-2">
                                                            @foreach($documents as $document)
                                                                @php
                                                                    $link = is_array($document) ? ($document['url'] ?? ($document['link'] ?? null)) : $document;
                                                                    $label = is_array($document) ? ($document['name'] ?? ($document['label'] ?? $link)) : $document;
                                                                @endphp
                                                                @if($link)
                                                                    <li>
                                                                        <a href="{{ $link }}" target="_blank" rel="noopener" class="d-inline-flex align-items-center gap-2">
                                                                            <i class="bi bi-paperclip"></i>
                                                                            <span>{{ $label }}</span>
                                                                        </a>
                                                                    </li>
                                                                @endif
                                                            @endforeach
                                                        </ul>
                                                    @else
                                                        <p class="text-muted small mb-0">{{ __('No documents provided.') }}</p>
                                                    @endif
                                                </div>
                                                <div class="d-grid gap-2">
                                                    @if($withdrawal->isPending())
                                                        <form method="post" action="{{ route('wallet.withdrawals.approve', $withdrawal) }}">
                                                            @csrf
                                                            <button type="submit" class="btn btn-success d-flex align-items-center gap-2" onclick="return confirm('{{ __('Approve this withdrawal request?') }}');">
                                                                <i class="bi bi-check-circle"></i>
                                                                <span>{{ __('Approve') }}</span>
                                                            </button>
                                                        </form>
                                                        <form method="post" action="{{ route('wallet.withdrawals.reject', $withdrawal) }}">
                                                            @csrf
                                                            <button type="submit" class="btn btn-danger d-flex align-items-center gap-2" onclick="return confirm('{{ __('Reject this withdrawal request?') }}');">
                                                                <i class="bi bi-x-circle"></i>
                                                                <span>{{ __('Reject') }}</span>
                                                            </button>
                                                        </form>
                                                    @endif
                                                </div>
                                            </div>
                                        </div>
                                    @endpush    

                                @empty
                                    <tr>
                                        <td colspan="7" class="text-center py-4 text-muted">
                                            <i class="bi bi-cash-coin display-6 d-block mb-2"></i>
                                            {{ __('No withdrawal requests found for the selected filters.') }}
                                        </td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                    @if($withdrawals->hasPages())
                        <div class="card-footer bg-white border-0">
                            {{ $withdrawals->links() }}
                        </div>
                    @endif
                </div>
            </div>
        </div>
    </section>
@endsection
