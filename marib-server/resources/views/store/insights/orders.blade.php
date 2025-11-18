@extends('layouts.main')

@section('title', __('merchant_reports.orders.title'))

@section('page-title')
    <div class="page-title">
        <div class="row g-3 align-items-center">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('merchant_reports.orders.subtitle') }}
                </p>
                <small class="text-muted">
                    {{ $range['from']->translatedFormat('d M Y') }} - {{ $range['to']->translatedFormat('d M Y') }}
                </small>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end flex-wrap gap-2">
                <form method="get" class="d-flex gap-2 flex-wrap align-items-center">
                    <label class="form-label mb-0 small text-muted" for="period">
                        {{ __('merchant_reports.orders.period_label') }}
                    </label>
                    <select class="form-select form-select-sm" id="period" name="period" onchange="this.form.submit()">
                        <option value="7d" @selected($range['key'] === '7d')>{{ __('merchant_reports.orders.period_7d') }}</option>
                        <option value="14d" @selected($range['key'] === '14d')>{{ __('merchant_reports.orders.period_14d') }}</option>
                        <option value="30d" @selected($range['key'] === '30d')>{{ __('merchant_reports.orders.period_30d') }}</option>
                        <option value="90d" @selected($range['key'] === '90d')>{{ __('merchant_reports.orders.period_90d') }}</option>
                        <option value="custom" @selected($range['key'] === 'custom')>{{ __('merchant_reports.orders.period_custom') }}</option>
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
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.orders.summary_total_orders') }}</p>
                        <h3 class="mb-0">{{ number_format($summary['total_orders']) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-12 col-md-3">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.orders.summary_total_revenue') }}</p>
                        <h3 class="mb-0">{{ number_format($summary['total_revenue'], 2) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-12 col-md-3">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.orders.summary_open_orders') }}</p>
                        <h3 class="mb-0">{{ number_format($summary['open_orders']) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-12 col-md-3">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <p class="text-muted small mb-1">{{ __('merchant_reports.orders.summary_avg_fulfillment') }}</p>
                        <h3 class="mb-0">{{ $summary['avg_fulfillment'] ?? __('merchant_reports.orders.no_data') }}</h3>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-3 mb-4">
            <div class="col-12 col-lg-6">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-header bg-light">
                        <h6 class="mb-0">{{ __('merchant_reports.orders.status_breakdown_title') }}</h6>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('merchant_reports.orders.status_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.orders.orders_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.orders.revenue_column') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($statusBreakdown as $row)
                                        <tr>
                                            <td>{{ __($row->order_status) }}</td>
                                            <td class="text-end">{{ number_format($row->total_orders) }}</td>
                                            <td class="text-end">{{ number_format($row->revenue, 2) }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="text-center text-muted py-3">
                                                {{ __('merchant_reports.orders.no_data') }}
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
                        <h6 class="mb-0">{{ __('merchant_reports.orders.payment_breakdown_title') }}</h6>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('merchant_reports.orders.payment_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.orders.orders_column') }}</th>
                                        <th class="text-end">{{ __('merchant_reports.orders.revenue_column') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($paymentBreakdown as $row)
                                        <tr>
                                            <td>{{ __($row->payment_status ?? __('merchant_reports.orders.not_available')) }}</td>
                                            <td class="text-end">{{ number_format($row->total_orders) }}</td>
                                            <td class="text-end">{{ number_format($row->revenue, 2) }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="text-center text-muted py-3">
                                                {{ __('merchant_reports.orders.no_data') }}
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

        <div class="card shadow-sm border-0 mb-4">
            <div class="card-header bg-light">
                <h6 class="mb-0">{{ __('merchant_reports.orders.daily_trend_title') }}</h6>
            </div>
            <div class="card-body p-0">
                @if ($dailyTrend->isEmpty())
                    <div class="py-4 text-center text-muted">
                        {{ __('merchant_reports.orders.daily_trend_empty') }}
                    </div>
                @else
                    <div class="table-responsive">
                        <table class="table mb-0">
                            <thead>
                                <tr>
                                    <th>{{ __('merchant_reports.orders.day_column') }}</th>
                                    <th class="text-end">{{ __('merchant_reports.orders.orders_column') }}</th>
                                    <th class="text-end">{{ __('merchant_reports.orders.revenue_column') }}</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach ($dailyTrend as $point)
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

        <div class="card shadow-sm border-0">
            <div class="card-header bg-light d-flex justify-content-between align-items-center">
                <h6 class="mb-0">{{ __('merchant_reports.orders.recent_orders_title') }}</h6>
                <a href="{{ route('merchant.orders.index') }}" class="btn btn-sm btn-outline-secondary">
                    {{ __('merchant_reports.orders.view_all_orders') }}
                </a>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table mb-0">
                        <thead>
                            <tr>
                                <th>{{ __('merchant_reports.orders.table_order') }}</th>
                                <th>{{ __('merchant_reports.orders.table_customer') }}</th>
                                <th class="text-end">{{ __('merchant_reports.orders.table_amount') }}</th>
                                <th>{{ __('merchant_reports.orders.table_status') }}</th>
                                <th>{{ __('merchant_reports.orders.table_payment') }}</th>
                                <th>{{ __('merchant_reports.orders.table_created') }}</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($recentOrders as $order)
                                <tr>
                                    <td>#{{ $order->order_number ?? $order->id }}</td>
                                    <td>{{ $order->user?->name ?? __('merchant_reports.orders.not_available') }}</td>
                                    <td class="text-end">{{ number_format($order->final_amount, 2) }}</td>
                                    <td><span class="badge bg-light text-dark">{{ __($order->order_status) }}</span></td>
                                    <td>{{ __($order->payment_status) }}</td>
                                    <td>{{ optional($order->created_at)->format('Y-m-d H:i') }}</td>
                                    <td class="text-end">
                                        <a href="{{ route('merchant.orders.show', $order) }}" class="btn btn-sm btn-outline-primary">
                                            {{ __('merchant_reports.orders.view_order') }}
                                        </a>
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="7" class="text-center text-muted py-4">
                                        {{ __('merchant_reports.orders.no_data') }}
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
