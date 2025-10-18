{{-- resources/views/wifi/index.blade.php --}}
@extends('layouts.main')

@section('title')
    {{ __('WiFi Cabin Management') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4 class="mb-1">@yield('title')</h4>
                <p class="text-muted mb-0">{{ __('Monitor networks, plans, balances and proactive alerts for the WiFi cabins.') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                <div class="d-flex justify-content-md-end gap-2 mt-3 mt-md-0">
                    <a href="{{ route('wifi.create') }}" class="btn btn-primary">
                        <i class="bi bi-plus-circle"></i>
                        {{ __('Create WiFi Voucher Batch') }}
                    </a>
                </div>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-4">
            <div class="col-12 col-xl-7 d-flex flex-column gap-4">
                <div class="card shadow-sm h-100">
                    <div class="card-header border-0 pb-0 d-flex align-items-center justify-content-between">
                        <div>
                            <h5 class="card-title mb-1">{{ __('WiFi Networks') }}</h5>
                            <p class="text-muted small mb-0">{{ __('Track availability and plan count for every managed cabin network.') }}</p>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-hover align-middle mb-0">
                                <thead>
                                <tr>
                                    <th scope="col">{{ __('Network') }}</th>
                                    <th scope="col" class="text-center">{{ __('Status') }}</th>
                                    <th scope="col" class="text-center">{{ __('Plans') }}</th>
                                    <th scope="col" class="text-center">{{ __('Coverage (km)') }}</th>
                                    <th scope="col">{{ __('Support Contacts') }}</th>

                                    <th scope="col" class="text-end">{{ __('Actions') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @forelse($networks as $network)
                                    @php
                                        $networkId = data_get($network, 'id') ?? data_get($network, 'uuid') ?? data_get($network, 'slug');
                                        $rawPlans = data_get($network, 'plans');
                                        $plansCount = data_get($network, 'plans_count');
                                        if (is_countable($rawPlans) && ! is_string($rawPlans)) {
                                            $plansCount = count($rawPlans);
                                        }
                                        if ($plansCount === null) {
                                            $plansCount = data_get($network, 'metrics.plans');
                                        }
                                        $status = data_get($network, 'status', __('Unknown'));
                                        $statusClass = $status === 'active' ? 'bg-success' : ($status === 'inactive' ? 'bg-secondary' : 'bg-warning');
                                        $statusLabel = \Illuminate\Support\Str::upper((string) $status);
                                    @endphp
                                    <tr>
                                        <td>
                                            <div class="d-flex align-items-center gap-2">
                                                <div class="avatar bg-primary-subtle text-primary fw-semibold">
                                                    <i class="bi bi-router"></i>
                                                </div>
                                                <div>
                                                    <div class="fw-semibold">{{ data_get($network, 'name', __('Unnamed Network')) }}</div>
                                                    <div class="text-muted small">{{ data_get($network, 'identifier', data_get($network, 'code', '—')) }}</div>


                                                    <div class="text-muted small">{{ __('Slug') }}: <span class="text-body-secondary">{{ data_get($network, 'slug', '—') }}</span></div>
                                                    <div class="text-muted small">{{ __('Wallet') }}: <span class="text-body-secondary">{{ data_get($network, 'wallet.currency', data_get($network, 'wallet_id', __('Not linked'))) }}</span></div>

                                                </div>
                                            </div>
                                        </td>
                                        <td class="text-center">
                                            <span class="badge {{ $statusClass }} text-uppercase">{{ $statusLabel }}</span>
                                        </td>
                                        <td class="text-center">
                                            {{ $plansCount ?? '—' }}
                                        </td>


                                        @php($coverage = data_get($network, 'coverage_radius_km'))
                                        <td class="text-center">
                                            {{ $coverage !== null ? number_format((float) $coverage, 2) : '—' }}
                                        </td>
                                        <td>
                                            @php($contacts = collect(data_get($network, 'contacts', []))->filter())
                                            <div class="d-flex flex-wrap gap-1">
                                                @forelse($contacts as $contact)
                                                    <span class="badge bg-light border text-muted">{{ $contact }}</span>
                                                @empty
                                                    <span class="text-muted">—</span>
                                                @endforelse
                                            </div>
                                        </td>


                                        <td class="text-end">
                                            @if($networkId)
                                                <a href="{{ route('wifi.edit', $networkId) }}" class="btn btn-sm btn-outline-primary">
                                                    <i class="bi bi-pencil-square"></i>
                                                    {{ __('Manage') }}
                                                </a>
                                            @else
                                                <span class="text-muted">—</span>
                                            @endif
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="6" class="text-center text-muted py-4">
                                            <i class="bi bi-wifi-off display-6 d-block mb-2"></i>
                                            <span>{{ __('No networks available yet.') }}</span>
                                        </td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>




                </div>
                <div class="card shadow-sm">
                    <div class="card-header border-0 pb-0 d-flex align-items-center justify-content-between">
                        <div>
                            <h5 class="card-title mb-1">{{ __('Owner Requests') }}</h5>
                            <p class="text-muted small mb-0">{{ __('Review pending uploads submitted by network owners before activating them.') }}</p>
                        </div>
                    </div>
                    <div class="card-body">



                    @if (session('status'))
                        <div class="alert alert-success d-flex align-items-center justify-content-between" role="alert">
                            <div class="me-3">
                                <i class="bi bi-check-circle me-2"></i>{{ session('status') }}
                            </div>
                            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('Close') }}"></button>
                        </div>
                    @endif

                    @if (session('error'))
                        <div class="alert alert-danger d-flex align-items-center justify-content-between" role="alert">
                            <div class="me-3">
                                <i class="bi bi-exclamation-triangle me-2"></i>{{ session('error') }}
                            </div>
                            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('Close') }}"></button>
                        </div>
                    @endif

                    @php($ownerRequestErrors = $errors->getBag('wifiOwnerRequests'))
                    @if ($ownerRequestErrors->any())
                        <div class="alert alert-danger" role="alert">
                            <div class="d-flex align-items-start">
                                <i class="bi bi-info-circle me-2 mt-1"></i>
                                <ul class="mb-0 small">
                                    @foreach($ownerRequestErrors->all() as $error)
                                        <li>{{ $error }}</li>
                                    @endforeach
                                </ul>
                            </div>
                        </div>
                    @endif


                    <div class="table-responsive">
                        <table class="table table-hover align-middle mb-0">
                            <thead>
                            <tr>
                                <th scope="col">{{ __('Request') }}</th>
                                <th scope="col">{{ __('Network & Owner') }}</th>
                                <th scope="col">{{ __('Submitted') }}</th>
                                <th scope="col" class="text-end">{{ __('Actions') }}</th>
                            </tr>
                            </thead>
                            <tbody>
                            @forelse(($ownerRequests ?? collect()) as $ownerRequest)
                                @php
                                    $requestId = data_get($ownerRequest, 'id');
                                    $status = (string) data_get($ownerRequest, 'status', 'pending');
                                    $statusClass = match (strtolower($status)) {
                                        'approved', 'processed', 'completed' => 'bg-success',
                                        'rejected', 'denied' => 'bg-danger',
                                        'pending' => 'bg-warning text-dark',
                                        default => 'bg-secondary',
                                    };
                                    $statusLabel = \Illuminate\Support\Str::upper($status);
                                    $networkName = data_get($ownerRequest, 'network.name', __('Unknown Network'));
                                    $ownerName = data_get($ownerRequest, 'owner.name');
                                    $ownerEmail = data_get($ownerRequest, 'owner.email');
                                    $planName = data_get($ownerRequest, 'plan.name');
                                    $totalRows = data_get($ownerRequest, 'total_rows');
                                    $acceptedRows = data_get($ownerRequest, 'accepted_rows');
                                    $rejectedRows = data_get($ownerRequest, 'rejected_rows');
                                    $filename = data_get($ownerRequest, 'original_filename');
                                    $createdAt = data_get($ownerRequest, 'created_at');
                                    $uploaderName = data_get($ownerRequest, 'uploader.name');
                                    $uploaderEmail = data_get($ownerRequest, 'uploader.email');
                                @endphp
                                <tr>
                                    <td>
                                        <div class="d-flex flex-column gap-1">
                                            <div class="d-flex align-items-center gap-2">
                                                <span class="badge {{ $statusClass }}">{{ $statusLabel }}</span>
                                                <span class="fw-semibold">{{ $filename ?? __('Batch #:id', ['id' => $requestId]) }}</span>
                                            </div>
                                            <div class="text-muted small">
                                                {{ __('Plan') }}: <span class="text-body-secondary">{{ $planName ?? __('General Stock') }}</span>
                                            </div>
                                            <div class="text-muted small">
                                                {{ __('Rows') }}: <span class="text-body-secondary">{{ number_format((int) $totalRows) }}</span>
                                                <span class="ms-2 text-success">{{ __('Accepted') }}: {{ number_format((int) $acceptedRows) }}</span>
                                                <span class="ms-2 text-danger">{{ __('Rejected') }}: {{ number_format((int) $rejectedRows) }}</span>
                                            </div>
                                        </div>
                                    </td>
                                    <td>
                                        <div class="fw-semibold">{{ $networkName }}</div>
                                        <div class="text-muted small">{{ $ownerName ? __('Owner: :name', ['name' => $ownerName]) : __('Owner pending assignment') }}</div>
                                        @if($ownerEmail)
                                            <div class="text-muted small">{{ $ownerEmail }}</div>
                                        @endif
                                    </td>
                                    <td>
                                        <div class="text-muted small">{{ $createdAt ? \Illuminate\Support\Carbon::parse($createdAt)->format('Y-m-d H:i') : __('Not available') }}</div>
                                        @if($uploaderName)
                                            <div class="text-muted small">{{ __('By') }}: {{ $uploaderName }}</div>
                                        @endif
                                        @if($uploaderEmail)
                                            <div class="text-muted small">{{ $uploaderEmail }}</div>
                                        @endif
                                    </td>
                                    <td class="text-end">
                                        @if($requestId)
                                            <div class="d-flex flex-wrap justify-content-end gap-2">
                                                <form action="{{ route('wifi.owner-requests.approve', $requestId) }}" method="POST" class="d-inline">
                                                    @csrf
                                                    <button type="submit" class="btn btn-sm btn-success">
                                                        <i class="bi bi-check-circle"></i>
                                                        {{ __('Approve') }}
                                                    </button>
                                                </form>
                                                <form action="{{ route('wifi.owner-requests.reject', $requestId) }}" method="POST" class="d-inline">
                                                    @csrf
                                                    <button type="submit" class="btn btn-sm btn-outline-danger">
                                                        <i class="bi bi-x-circle"></i>
                                                        {{ __('Reject') }}
                                                    </button>
                                                </form>
                                            </div>
                                        @else
                                            <span class="text-muted">—</span>
                                        @endif
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="4" class="text-center text-muted py-4">
                                        <i class="bi bi-inbox display-6 d-block mb-2"></i>
                                        <span>{{ __('No owner requests awaiting review.') }}</span>
                                    </td>
                                </tr>
                            @endforelse
                            </tbody>
                        </table>



                    </div>
                </div>
            </div>

            <div class="col-12 col-xl-5 d-flex flex-column gap-4">
                <div class="card shadow-sm h-100">
                    <div class="card-header border-0 pb-0">
                        <h5 class="card-title mb-1">{{ __('Stock Overview') }}</h5>
                        <p class="text-muted small mb-0">{{ __('Follow issued vouchers and available balances across networks.') }}</p>
                    </div>
                    <div class="card-body">
                        @forelse($balances as $balance)
                            <div class="border rounded-3 p-3 mb-3">
                                <div class="d-flex justify-content-between align-items-start mb-2">
                                    <div>
                                        <h6 class="mb-1">{{ data_get($balance, 'name', __('Unnamed Network')) }}</h6>
                                        <p class="text-muted small mb-0">{{ __('Last Sync') }}: {{ data_get($balance, 'synced_at', __('Not available')) }}</p>
                                    </div>
                                    <span class="badge bg-info-subtle text-info">{{ __('Available Balance') }}: {{ data_get($balance, 'available', 0) }}</span>
                                </div>
                                <div class="row g-2 small text-muted">
                                    <div class="col-6">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Reserved Balance') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($balance, 'reserved', 0) }}</div>
                                        </div>
                                    </div>
                                    <div class="col-6">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Total Issued') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($balance, 'issued', 0) }}</div>
                                        </div>
                                    </div>
                                    <div class="col-12">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Remaining Vouchers') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($balance, 'remaining', data_get($balance, 'available', 0)) }}</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        @empty
                            <div class="text-center text-muted py-4">
                                <i class="bi bi-bar-chart display-6 d-block mb-2"></i>
                                <span>{{ __('No stock data available.') }}</span>
                            </div>
                        @endforelse
                    </div>
                </div>

                <div class="card shadow-sm">
                    <div class="card-header border-0 pb-0">
                        <h5 class="card-title mb-1">{{ __('Alerts') }}</h5>
                        <p class="text-muted small mb-0">{{ __('Act quickly on low balances, outages or integration incidents.') }}</p>
                    </div>
                    <div class="card-body">
                        @forelse($alerts as $alert)
                            @php
                                $severity = strtolower((string) data_get($alert, 'severity', 'info'));
                                $badgeClass = match ($severity) {
                                    'critical', 'error' => 'bg-danger',
                                    'warning' => 'bg-warning text-dark',
                                    'success' => 'bg-success',
                                    default => 'bg-info',
                                };
                                $severityLabel = \Illuminate\Support\Str::upper($severity);
                            @endphp
                            <div class="alert alert-light border shadow-sm mb-3" role="alert">
                                <div class="d-flex justify-content-between align-items-start mb-1">
                                    <h6 class="mb-0">{{ data_get($alert, 'title', __('Service Alert')) }}</h6>
                                    <span class="badge {{ $badgeClass }} text-uppercase">{{ $severityLabel }}</span>
                                </div>
                                <p class="mb-2 text-muted">{{ data_get($alert, 'message', __('No additional details provided.')) }}</p>
                                <div class="d-flex justify-content-between small text-muted">
                                    <span><i class="bi bi-router"></i> {{ data_get($alert, 'network_name', __('Unnamed Network')) }}</span>
                                    <span><i class="bi bi-clock"></i> {{ data_get($alert, 'reported_at', __('Not available')) }}</span>
                                </div>
                            </div>
                        @empty
                            <div class="text-center text-muted py-4">
                                <i class="bi bi-bell-slash display-6 d-block mb-2"></i>
                                <span>{{ __('No alerts for now.') }}</span>
                            </div>
                        @endforelse
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection