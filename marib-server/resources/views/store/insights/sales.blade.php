@extends('layouts.main')

@section('title', __('merchant_reports.sales.title'))

@section('page-title')
    <div class="page-title">
        <div class="row g-3 align-items-center">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">{{ __('merchant_reports.sales.subtitle') }}</p>
                <small class="text-muted">
                    {{ $range['from']->translatedFormat('d M Y') }} - {{ $range['to']->translatedFormat('d M Y') }}
                </small>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end flex-wrap gap-2">
                <form method="get" class="d-flex gap-2 flex-wrap align-items-center">
                    <label for="period" class="form-label mb-0 small text-muted">{{ __('merchant_reports.sales.period_label') }}</label>
                    <select class="form-select form-select-sm" id="period" name="period" onchange="this.form.submit()">
                        <option value="7d" @selected($range['key'] === '7d')>{{ __('merchant_reports.sales.period_7d') }}</option>
                        <option value="14d" @selected($range['key'] === '14d')>{{ __('merchant_reports.sales.period_14d') }}</option>
                        <option value="30d" @selected($range['key'] === '30d')>{{ __('merchant_reports.sales.period_30d') }}</option>
                        <option value="90d" @selected($range['key'] === '90d')>{{ __('merchant_reports.sales.period_90d') }}</option>
                        <option value="custom" @selected($range['key'] === 'custom')>{{ __('merchant_reports.sales.period_custom') }}</option>
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
                        <p class="text-muted small mb-1">{{ __('merchant_reports.sales.summary_total_revenue') }}</p>
                        <h3 class="mb-0">{{ number_format($summary['total_revenue'], 2) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-12 col-md-3">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.sales.summary_total_orders') }}</p>
                        <h3 class="mb-0">{{ number_format($summary['total_orders']) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-12 col-md-3">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.sales.summary_avg_order') }}</p>
                        <h3 class="mb-0">{{ $summary['avg_order_value'] !== null ? number_format($summary['avg_order_value'], 2) : __('merchant_reports.sales.no_data') }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-12 col-md-3">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.sales.summary_items_sold') }}</p>
                        <h3 class="mb-0">{{ number_format($summary['items_sold']) }}</h3>
                        <small class="text-muted">
                            {{ __('merchant_reports.sales.summary_avg_basket') }}:
                            {{ $summary['avg_basket'] !== null ? number_format($summary['avg_basket'], 2) : __('merchant_reports.sales.no_data') }}
                        </small>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-3 mb-4">
            <div class="col-12 col-lg-6">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-header bg-light">
                        <h6 class="mb-0">{{ __('merchant_reports.sales.payment_mix_title') }}</h6>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('merchant_reports.sales.payment_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.sales.orders_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.sales.revenue_column') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($paymentMix as $row)
                                        <tr>
                                            <td>{{ __($row->payment_status) }}</td>
                                            <td class="text-end">{{ number_format($row->total_orders) }}</td>
                                            <td class="text-end">{{ number_format($row->revenue, 2) }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="text-center text-muted py-3">
                                                {{ __('merchant_reports.sales.no_data') }}
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
                        <h6 class="mb-0">{{ __('merchant_reports.sales.top_products_title') }}</h6>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('merchant_reports.sales.product_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.sales.quantity_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.sales.revenue_column') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($topProducts as $product)
                                        <tr>
                                            <td>{{ $product->item_name ?? __('merchant_reports.sales.unknown_product') }}</td>
                                            <td class="text-end">{{ number_format($product->total_quantity) }}</td>
                                            <td class="text-end">{{ number_format($product->total_revenue, 2) }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="text-center text-muted py-3">
                                                {{ __('merchant_reports.sales.no_data') }}
                                            </td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-3 mb-4">
            <div class="col-12 col-lg-6">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-header bg-light">
                        <h6 class="mb-0">{{ __('merchant_reports.sales.top_customers_title') }}</h6>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('merchant_reports.sales.customer_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.sales.orders_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.sales.revenue_column') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($topCustomers as $customer)
                                        <tr>
                                            <td>{{ $customer->customer_name ?? __('merchant_reports.sales.not_available') }}</td>
                                            <td class="text-end">{{ number_format($customer->total_orders) }}</td>
                                            <td class="text-end">{{ number_format($customer->revenue, 2) }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="text-center text-muted py-3">
                                                {{ __('merchant_reports.sales.no_data') }}
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
                        <h6 class="mb-0">{{ __('merchant_reports.sales.daily_revenue_title') }}</h6>
                    </div>
                    <div class="card-body p-0">
                        @if ($dailyRevenue->isEmpty())
                            <div class="py-4 text-center text-muted">
                                {{ __('merchant_reports.sales.no_data') }}
                            </div>
                        @else
                            <div class="table-responsive">
                                <table class="table mb-0">
                                    <thead>
                                        <tr>
                                            <th>{{ __('merchant_reports.sales.day_column') }}</th>
                                            <th class="text-end">{{ __('merchant_reports.sales.orders_column') }}</th>
                                            <th class="text-end">{{ __('merchant_reports.sales.revenue_column') }}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        @foreach ($dailyRevenue as $point)
                                            <tr>
                                                <td>{{ $point->day->translatedFormat('d M') }}</td>
                                                <td class="text-end">{{ number_format($point->total_orders) }}</td>
                                                <td class="text-end">{{ number_format($point->revenue, 2) }}</td>
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
    </section>
@endsection
