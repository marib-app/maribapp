@extends('layouts.main')

@section('title', __('merchant_reports.customers.title'))

@section('page-title')
    <div class="page-title">
        <div class="row g-3 align-items-center">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">{{ __('merchant_reports.customers.subtitle') }}</p>
                <small class="text-muted">
                    {{ $range['from']->translatedFormat('d M Y') }} - {{ $range['to']->translatedFormat('d M Y') }}
                </small>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end flex-wrap gap-2">
                <form method="get" class="d-flex gap-2 flex-wrap align-items-center">
                    <label for="period" class="form-label mb-0 small text-muted">{{ __('merchant_reports.customers.period_label') }}</label>
                    <select class="form-select form-select-sm" id="period" name="period" onchange="this.form.submit()">
                        <option value="7d" @selected($range['key'] === '7d')>{{ __('merchant_reports.customers.period_7d') }}</option>
                        <option value="14d" @selected($range['key'] === '14d')>{{ __('merchant_reports.customers.period_14d') }}</option>
                        <option value="30d" @selected($range['key'] === '30d')>{{ __('merchant_reports.customers.period_30d') }}</option>
                        <option value="90d" @selected($range['key'] === '90d')>{{ __('merchant_reports.customers.period_90d') }}</option>
                        <option value="custom" @selected($range['key'] === 'custom')>{{ __('merchant_reports.customers.period_custom') }}</option>
                    </select>
                </form>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-3 mb-4">
            <div class="col-12 col-md-3">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.customers.summary_total_customers') }}</p>
                        <h3 class="mb-0">{{ number_format($summary['total_customers']) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-12 col-md-3">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.customers.summary_new_customers') }}</p>
                        <h3 class="mb-0">{{ number_format($summary['new_customers']) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-12 col-md-3">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.customers.summary_returning_customers') }}</p>
                        <h3 class="mb-0">{{ number_format($summary['returning_customers']) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-12 col-md-3">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.customers.summary_avg_orders') }}</p>
                        <h3 class="mb-0">{{ $summary['avg_orders_per_customer'] !== null ? number_format($summary['avg_orders_per_customer'], 2) : __('merchant_reports.customers.no_data') }}</h3>
                        <small class="text-muted">
                            {{ __('merchant_reports.customers.summary_avg_revenue') }}:
                            {{ $summary['avg_revenue_per_customer'] !== null ? number_format($summary['avg_revenue_per_customer'], 2) : __('merchant_reports.customers.no_data') }}
                        </small>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-3 mb-4">
            <div class="col-12 col-lg-6">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-header bg-light">
                        <h6 class="mb-0">{{ __('merchant_reports.customers.top_customers_title') }}</h6>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('merchant_reports.customers.customer_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.customers.orders_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.customers.revenue_column') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($topCustomers as $customer)
                                        <tr>
                                            <td>{{ $customer->customer_name ?? __('merchant_reports.customers.not_available') }}</td>
                                            <td class="text-end">{{ number_format($customer->total_orders) }}</td>
                                            <td class="text-end">{{ number_format($customer->revenue, 2) }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="text-center text-muted py-4">
                                                {{ __('merchant_reports.customers.no_data') }}
                                            </td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-12 col-lg-6">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-header bg-light">
                        <h6 class="mb-0">{{ __('merchant_reports.customers.guest_metrics_title') }}</h6>
                    </div>
                    <div class="card-body">
                        <p class="mb-1 text-muted">{{ __('merchant_reports.customers.guest_orders') }}: <strong>{{ number_format($guestMetrics['orders']) }}</strong></p>
                        <p class="mb-0 text-muted">{{ __('merchant_reports.customers.guest_revenue') }}: <strong>{{ number_format($guestMetrics['revenue'], 2) }}</strong></p>
                    </div>
                </div>
            </div>
        </div>

        <div class="card shadow-sm border-0">
            <div class="card-header bg-light">
                <h6 class="mb-0">{{ __('merchant_reports.customers.recent_customers_title') }}</h6>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table mb-0">
                        <thead>
                            <tr>
                                <th>{{ __('merchant_reports.customers.customer_column') }}</th>
                                <th class="text-end">{{ __('merchant_reports.customers.orders_column') }}</th>
                                <th class="text-end">{{ __('merchant_reports.customers.revenue_column') }}</th>
                                <th>{{ __('merchant_reports.customers.first_order_column') }}</th>
                                <th>{{ __('merchant_reports.customers.last_order_column') }}</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($recentCustomers as $customer)
                                <tr>
                                    <td>{{ $customer->customer_name ?? __('merchant_reports.customers.not_available') }}</td>
                                    <td class="text-end">{{ number_format($customer->total_orders) }}</td>
                                    <td class="text-end">{{ number_format($customer->revenue, 2) }}</td>
                                    <td>{{ optional($customer->first_order_at)->format('Y-m-d') }}</td>
                                    <td>{{ optional($customer->last_order_at)->format('Y-m-d') }}</td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="5" class="text-center text-muted py-4">
                                        {{ __('merchant_reports.customers.no_data') }}
                                    </td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </section>
@endsection
