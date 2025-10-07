{{-- resources/views/wifi/create.blade.php --}}
@extends('layouts.main')

@section('title')
    {{ __('Create WiFi Voucher Batch') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4 class="mb-1">@yield('title')</h4>
                <p class="text-muted mb-0">{{ __('Issue prepaid vouchers for WiFi cabin customers in one step.') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                <div class="d-flex justify-content-md-end gap-2 mt-3 mt-md-0">
                    <a href="{{ route('wifi.index') }}" class="btn btn-outline-secondary">
                        <i class="bi bi-arrow-right-circle"></i>
                        {{ __('Back to WiFi dashboard') }}
                    </a>
                </div>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-4">
            <div class="col-12 col-xl-7">
                <div class="card shadow-sm h-100">
                    <div class="card-header border-0 pb-0">
                        <h5 class="card-title mb-1">{{ __('Voucher configuration') }}</h5>
                        <p class="text-muted small mb-0">{{ __('Select the network, plan and quantity to allocate vouchers for the cabin.') }}</p>
                    </div>
                    <div class="card-body">
                        <form action="#" method="post" class="row g-3">
                            @csrf
                            <div class="col-12">
                                <label for="wifi-network" class="form-label">{{ __('Choose Network') }}</label>
                                <select id="wifi-network" class="form-select" required>
                                    <option value="">{{ __('Select a network') }}</option>
                                    @foreach($networks as $network)
                                        @php
                                            $value = data_get($network, 'id') ?? data_get($network, 'uuid') ?? data_get($network, 'slug');
                                        @endphp
                                        <option value="{{ $value }}">{{ data_get($network, 'name', __('Unnamed Network')) }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div class="col-12">
                                <label for="wifi-plan" class="form-label">{{ __('Select Plan') }}</label>
                                <select id="wifi-plan" class="form-select" required>
                                    <option value="">{{ __('Choose a plan') }}</option>
                                    @foreach($plans as $plan)
                                        @php
                                            $planId = data_get($plan, 'id') ?? data_get($plan, 'code');
                                            $planName = data_get($plan, 'name', __('Unnamed Plan'));

                                            $allowanceLabel = data_get($plan, 'data_allowance_label', data_get($plan, 'allowance'));
                                            $validityLabel = data_get($plan, 'validity_label', data_get($plan, 'validity'));
                                            $speedLabel = data_get($plan, 'speed_label');
                                            $currency = data_get($plan, 'currency');
                                            $priceLabel = data_get($plan, 'price');

                                            if ($currency && $priceLabel !== null) {
                                                $priceLabel = trim($priceLabel . ' ' . $currency);
                                            }

                                            $planDescription = trim(collect([
                                                $allowanceLabel,
                                                $validityLabel,
                                                $speedLabel,
                                                $priceLabel,
                                            ])->filter()->implode(' • '));
                                        @endphp
                                        <option value="{{ $planId }}">{{ $planName }} @if($planDescription) — {{ $planDescription }} @endif</option>
                                    @endforeach
                                </select>
                            </div>

                            <div class="col-md-6">
                                <label for="wifi-quantity" class="form-label">{{ __('Quantity') }}</label>
                                <input type="number" min="1" step="1" class="form-control" id="wifi-quantity" placeholder="50" required>
                            </div>

                            <div class="col-md-6">
                                <label for="wifi-reference" class="form-label">{{ __('Reference / Batch name') }}</label>
                                <input type="text" class="form-control" id="wifi-reference" placeholder="Cabin A - April">
                            </div>

                            <div class="col-12">
                                <label for="wifi-notes" class="form-label">{{ __('Internal notes') }}</label>
                                <textarea id="wifi-notes" rows="3" class="form-control" placeholder="{{ __('Optional instructions for the support team...') }}"></textarea>
                            </div>

                            <div class="col-12 d-flex justify-content-end">
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-cloud-upload"></i>
                                    {{ __('Issue Vouchers') }}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>

            <div class="col-12 col-xl-5">
                <div class="card shadow-sm h-100">
                    <div class="card-header border-0 pb-0">
                        <h5 class="card-title mb-1">{{ __('Plan catalog') }}</h5>
                        <p class="text-muted small mb-0">{{ __('Review pricing and quotas available for WiFi cabin customers.') }}</p>
                    </div>
                    <div class="card-body">
                        @forelse($plans as $plan)
                            <div class="border rounded-3 p-3 mb-3">

                                @php
                                    $available = (int) data_get($plan, 'available_count', data_get($plan, 'stock.available', 0));
                                    $reserved = (int) data_get($plan, 'stock.reserved', 0);
                                    $issued = (int) data_get($plan, 'stock.issued', 0);
                                    $sold = (int) data_get($plan, 'sold_count', $reserved + $issued);
                                    $total = (int) data_get($plan, 'total_codes', $available + $sold);
                                    $ownerNet = number_format((float) data_get($plan, 'owner_net_amount', 0), 2);
                                    $grossRevenue = number_format((float) data_get($plan, 'gross_revenue_amount', 0), 2);
                                    $currency = data_get($plan, 'currency');

                                    if ($currency) {
                                        $ownerNet = trim($ownerNet . ' ' . $currency);
                                        $grossRevenue = trim($grossRevenue . ' ' . $currency);
                                    }
                                @endphp

                                <div class="d-flex justify-content-between align-items-start">
                                    <div>
                                        <h6 class="mb-1">{{ data_get($plan, 'name', __('Unnamed Plan')) }}</h6>
                                        <p class="text-muted small mb-2">{{ data_get($plan, 'description', __('No description provided.')) }}</p>
                                    </div>
                                    <span class="badge bg-primary-subtle text-primary">{{ data_get($plan, 'price', '—') }}</span>
                                </div>
                                <div class="row g-2 small text-muted">
                                    <div class="col-6">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Data Allowance') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($plan, 'data_allowance_label', data_get($plan, 'allowance', '—')) }}</div>
                                        </div>
                                    </div>
                                    <div class="col-6">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Validity') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($plan, 'validity_label', data_get($plan, 'validity', '—')) }}</div>
                                        </div>
                                    </div>
                                    <div class="col-12">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Speed') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($plan, 'speed_label', '—') }}</div>
                                        
                                        </div>
                                    </div>
                                    <div class="col-12">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Network') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($plan, 'network_name', __('Unnamed Network')) }}</div>
                                        </div>
                                    </div>


                                    <div class="col-12">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Voucher performance') }}</div>
                                            <div class="d-flex flex-wrap gap-2 mt-1">
                                                <span class="badge bg-light border text-muted">{{ __('Available') }}: {{ number_format($available) }}</span>
                                                <span class="badge bg-warning-subtle text-warning fw-semibold">{{ __('Sold') }}: {{ number_format($sold) }}</span>
                                                <span class="badge bg-secondary-subtle text-secondary">{{ __('Total') }}: {{ number_format($total) }}</span>
                                            </div>
                                            <div class="d-flex flex-wrap gap-2 mt-2">
                                                <span class="badge bg-success-subtle text-success">{{ __('Owner Net') }}: {{ $ownerNet }}</span>
                                                <span class="badge bg-info-subtle text-info">{{ __('Gross Sales') }}: {{ $grossRevenue }}</span>
                                            </div>
                                        </div>
                                    </div>

                                </div>
                            </div>
                        @empty
                            <div class="text-center text-muted py-4">
                                <i class="bi bi-card-text display-6 d-block mb-2"></i>
                                <span>{{ __('No plans configured yet.') }}</span>
                            </div>
                        @endforelse
                    </div>
                </div>


                <div class="card shadow-sm">
                    <div class="card-header border-0 pb-0">
                        <h5 class="card-title mb-1">{{ __('Network coverage & contacts') }}</h5>
                        <p class="text-muted small mb-0">{{ __('Verify slugs, wallet linkage and support channels for each managed network.') }}</p>
                    </div>
                    <div class="card-body">
                        @forelse($networks as $networkSummary)
                            @php(
                                $summaryCoverage = data_get($networkSummary, 'coverage_radius_km')
                            )
                            @php(
                                $summaryContacts = collect(data_get($networkSummary, 'contacts', []))->filter()
                            )
                            <div class="border rounded-3 p-3 mb-3">
                                <div class="d-flex justify-content-between align-items-start mb-2">
                                    <div>
                                        <h6 class="mb-1">{{ data_get($networkSummary, 'name', __('Unnamed Network')) }}</h6>
                                        <p class="text-muted small mb-1">{{ __('Slug') }}: <span class="text-body-secondary">{{ data_get($networkSummary, 'slug', '—') }}</span></p>
                                        <p class="text-muted small mb-1">{{ __('Wallet') }}: <span class="text-body-secondary">{{ data_get($networkSummary, 'wallet.currency', data_get($networkSummary, 'wallet_id', __('Not linked'))) }}</span></p>
                                    </div>
                                    <span class="badge bg-primary-subtle text-primary">{{ __('ID') }}: {{ data_get($networkSummary, 'id', '—') }}</span>
                                </div>
                                <div class="small text-muted mb-2">
                                    <i class="bi bi-geo-alt"></i>
                                    {{ __('Coverage radius') }}:
                                    <span class="text-body-secondary">{{ $summaryCoverage !== null ? number_format((float) $summaryCoverage, 2) . ' ' . __('km') : __('Not available') }}</span>
                                </div>
                                <div class="small text-muted">
                                    <i class="bi bi-telephone"></i>
                                    {{ __('Support contacts') }}:
                                    <span class="d-block mt-1">
                                        @forelse($summaryContacts as $contact)
                                            <span class="badge bg-light border text-muted me-1 mb-1">{{ $contact }}</span>
                                        @empty
                                            <span class="text-body-secondary">{{ __('No contacts registered.') }}</span>
                                        @endforelse
                                    </span>
                                </div>
                            </div>
                        @empty
                            <div class="text-center text-muted py-4">
                                <i class="bi bi-list-check display-6 d-block mb-2"></i>
                                <span>{{ __('No networks configured yet.') }}</span>
                            </div>
                        @endforelse
                    </div>
                </div>


            </div>
        </div>
    </section>
@endsection