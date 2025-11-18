@extends('layouts.main')

@section('title', __('merchant_dashboard.page_title'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('merchant_dashboard.page_lead') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end align-items-start gap-2 flex-wrap">
                <a href="{{ route('merchant.settings') }}" class="btn btn-outline-primary">
                    <i class="bi bi-gear me-1"></i>{{ __('merchant_dashboard.manage_store_settings') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        @if (!empty($alerts))
            <div class="row g-3 mb-3">
                @foreach ($alerts as $alert)
                    <div class="col-12 col-md-4">
                        <div class="alert alert-{{ $alert['type'] }} border-0 shadow-sm mb-0">
                            <i class="bi bi-exclamation-circle me-2"></i>{{ $alert['message'] }}
                        </div>
                    </div>
                @endforeach
            </div>
        @endif

        <div class="row">
            @foreach ([
                'today' => __('merchant_dashboard.range_today'),
                'week' => __('merchant_dashboard.range_week'),
                'month' => __('merchant_dashboard.range_month'),
            ] as $key => $label)
                <div class="col-12 col-md-4 mb-3">
                    <div class="card h-100 shadow-sm border-0">
                        <div class="card-header bg-light d-flex justify-content-between align-items-center">
                            <div>
                                <p class="text-muted mb-0 small">{{ $label }}</p>
                                <small class="text-muted">
                                    {{ $overview[$key]['range']['from'] }} - {{ $overview[$key]['range']['to'] }}
                                </small>
                            </div>
                            <span class="badge bg-primary">{{ number_format($overview[$key]['orders']) }} {{ __('merchant_dashboard.orders_suffix') }}</span>
                        </div>
                        <div class="card-body">
                            <div class="mb-3">
                                <h3 class="mb-1">{{ number_format($overview[$key]['revenue'], 2) }}</h3>
                                <span class="text-muted">{{ __('merchant_dashboard.revenue_hint') }}</span>
                            </div>
                            <div class="d-flex justify-content-between text-muted small">
                                <div>
                                    <span class="d-block">{{ __('merchant_dashboard.visits_label') }}</span>
                                    <strong>{{ number_format($overview[$key]['visits']) }}</strong>
                                </div>
                                <div>
                                    <span class="d-block">{{ __('merchant_dashboard.product_views_label') }}</span>
                                    <strong>{{ number_format($overview[$key]['product_views']) }}</strong>
                                </div>
                                <div>
                                    <span class="d-block">{{ __('merchant_dashboard.add_to_cart_label') }}</span>
                                    <strong>{{ number_format($overview[$key]['add_to_cart']) }}</strong>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            @endforeach
        </div>

        <div class="row mb-4">
            <div class="col-12 col-lg-4 mb-3">
                <div class="card h-100 shadow-sm border-0">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <div>
                                <p class="text-muted mb-1">{{ __('merchant_dashboard.store_status_label') }}</p>
                                <span class="badge bg-{{ $statusCard['status'] === 'approved' ? 'success' : 'warning' }}">
                                    {{ __($statusCard['status']) }}
                                </span>
                            </div>
                            <a href="{{ route('merchant.settings') }}" class="btn btn-sm btn-outline-secondary">
                                <i class="bi bi-gear"></i> {{ __('merchant_dashboard.manage_store_settings') }}
                            </a>
                        </div>
                        <ul class="list-unstyled text-muted small mb-0">
                            <li class="mb-1">
                                <strong>{{ __('merchant_dashboard.closure_mode_label') }}:</strong>
                                {{ $statusCard['closure_mode'] === 'browse_only' ? __('merchant_dashboard.mode_browse') : __('merchant_dashboard.mode_full') }}
                            </li>
                            <li class="mb-1">
                                <strong>{{ __('merchant_dashboard.manual_closure_label') }}:</strong>
                                {{ $statusCard['is_manually_closed'] ? __('merchant_dashboard.toggle_on') : __('merchant_dashboard.toggle_off') }}
                            </li>
                            <li class="mb-1">
                                <strong>{{ __('merchant_dashboard.min_order_label') }}:</strong>
                                {{ $statusCard['min_order_amount'] ? number_format($statusCard['min_order_amount'], 2) . ' ' . __('merchant_dashboard.currency') : __('merchant_dashboard.not_set') }}
                            </li>
                            <li class="mb-1">
                                <strong>{{ __('merchant_dashboard.delivery_label') }}:</strong>
                                <i class="bi bi-circle-fill text-{{ $statusCard['allow_delivery'] ? 'success' : 'secondary' }} me-1"></i>
                                {{ $statusCard['allow_delivery'] ? __('merchant_dashboard.toggle_on') : __('merchant_dashboard.not_available') }}
                            </li>
                            <li>
                                <strong>{{ __('merchant_dashboard.pickup_label') }}:</strong>
                                <i class="bi bi-circle-fill text-{{ $statusCard['allow_pickup'] ? 'success' : 'secondary' }} me-1"></i>
                                {{ $statusCard['allow_pickup'] ? __('merchant_dashboard.toggle_on') : __('merchant_dashboard.not_available') }}
                            </li>
                            @if ($statusCard['closure_reason'])
                                <li class="mt-2">
                                    <strong>{{ __('merchant_dashboard.closure_reason_label') }}:</strong> {{ $statusCard['closure_reason'] }}
                                </li>
                            @endif
                            @if ($statusCard['closure_expires_at'])
                                <li>
                                    <strong>{{ __('merchant_dashboard.closure_until_label') }}:</strong> {{ $statusCard['closure_expires_at'] }}
                                </li>
                            @endif
                        </ul>
                    </div>
                </div>
            </div>
            <div class="col-12 col-lg-8 mb-3">
                <div class="row g-3">
                    <div class="col-12 col-md-6">
                        <div class="card border-0 shadow-sm h-100">
                            <div class="card-body">
                                <p class="text-muted mb-1">{{ __('merchant_dashboard.manual_pending_title') }}</p>
                                <h3 class="mb-0">{{ number_format($manualPaymentStats['open_count'] ?? 0) }}</h3>
                                <small class="text-muted d-block mb-2">{{ __('merchant_dashboard.manual_pending_amount') }}: {{ number_format($manualPaymentStats['open_amount'] ?? 0, 2) }} {{ __('merchant_dashboard.currency') }}</small>
                                <div class="d-flex gap-3 text-muted small">
                                    <div>
                                        <span class="d-block">{{ __('merchant_dashboard.manual_approved_today') }}</span>
                                        <strong>{{ number_format($manualPaymentStats['approved_today'] ?? 0) }}</strong>
                                    </div>
                                    <div>
                                        <span class="d-block">{{ __('merchant_dashboard.manual_rejected_today') }}</span>
                                        <strong>{{ number_format($manualPaymentStats['rejected_today'] ?? 0) }}</strong>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="col-12 col-md-6">
                        <div class="card border-0 shadow-sm h-100">
                            <div class="card-body">
                                <p class="text-muted mb-1">{{ __('merchant_dashboard.pending_orders') }}</p>
                                <h3 class="mb-0">{{ number_format($pendingOrderCount) }}</h3>
                                <small class="text-muted">{{ __('merchant_dashboard.pending_orders_desc') }}: {{ number_format($pendingOrderValue, 2) }} {{ __('merchant_dashboard.currency') }}</small>
                                <div class="mt-3">
                                    <a href="{{ route('merchant.manual-payments.index') }}" class="btn btn-outline-primary btn-sm me-2">
                                        <i class="bi bi-receipt"></i> {{ __('merchant_dashboard.review_manuals') }}
                                    </a>
                                    <a href="{{ route('merchant.orders.index') }}" class="btn btn-outline-secondary btn-sm">
                                        <i class="bi bi-basket"></i> {{ __('merchant_dashboard.view_orders') }}
                                    </a>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row">
            <div class="col-12 col-xl-7 mb-4">
                <div class="card border-0 shadow-sm h-100">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h6 class="mb-0">{{ __('merchant_dashboard.recent_manual_payments_title') }}</h6>
                        <a href="{{ route('merchant.manual-payments.index') }}" class="btn btn-link btn-sm">
                            {{ __('merchant_dashboard.view_all') }}
                        </a>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('merchant_dashboard.manual_table_reference') }}</th>
                                        <th>{{ __('merchant_dashboard.manual_table_customer') }}</th>
                                        <th>{{ __('merchant_dashboard.manual_table_amount') }}</th>
                                        <th>{{ __('merchant_dashboard.manual_table_status') }}</th>
                                        <th>{{ __('merchant_dashboard.manual_table_date') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($recentManualPayments as $payment)
                                        <tr>
                                            <td>#{{ $payment->id }}</td>
                                            <td>{{ $payment->user?->name ?? __('merchant_dashboard.guest_user') }}</td>
                                            <td>{{ number_format($payment->amount ?? 0, 2) }} {{ $payment->currency ?? __('merchant_dashboard.currency') }}</td>
                                            <td>
                                                <span class="badge bg-{{ $payment->status === \App\Models\ManualPaymentRequest::STATUS_APPROVED ? 'success' : ($payment->status === \App\Models\ManualPaymentRequest::STATUS_REJECTED ? 'danger' : 'warning') }}">
                                                    {{ __($payment->status) }}
                                                </span>
                                            </td>
                                            <td>{{ optional($payment->created_at)->format('Y-m-d H:i') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="5" class="text-center text-muted py-4">{{ __('merchant_dashboard.no_records') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-xl-5 mb-4">
                <div class="card border-0 shadow-sm h-100">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('merchant_dashboard.recent_activity_title') }}</h6>
                    </div>
                    <div class="card-body">
                        @if ($recentActivities->isEmpty())
                            <p class="text-muted mb-0">{{ __('merchant_dashboard.recent_activity_empty') }}</p>
                        @else
                            <ul class="manual-payment-timeline mb-0">
                                @foreach ($recentActivities as $activity)
                                    <li>
                                        <div class="d-flex justify-content-between">
                                            <div>
                                                <strong>{{ __($activity->status) }}</strong>
                                                <div class="text-muted small">
                                                    #{{ $activity->manualPaymentRequest?->id }} &middot; {{ $activity->user?->name ?? __('merchant_dashboard.system_user') }}
                                                </div>
                                            </div>
                                            <small class="text-muted">{{ optional($activity->created_at)->diffForHumans() }}</small>
                                        </div>
                                    </li>
                                @endforeach
                            </ul>
                        @endif
                    </div>
                </div>
            </div>
        </div>

        <div class="row">
            <div class="col-12 col-lg-6 mb-4">
                <div class="card border-0 shadow-sm h-100">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h6 class="mb-0">{{ __('merchant_dashboard.recent_orders_title') }}</h6>
                        <a href="{{ route('merchant.orders.index') }}" class="btn btn-link btn-sm">{{ __('merchant_dashboard.view_all') }}</a>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('merchant_dashboard.orders_table_order') }}</th>
                                        <th>{{ __('merchant_dashboard.orders_table_amount') }}</th>
                                        <th>{{ __('merchant_dashboard.orders_table_status') }}</th>
                                        <th>{{ __('merchant_dashboard.orders_table_payment') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($recentOrders as $order)
                                        <tr>
                                            <td>#{{ $order->order_number ?? $order->id }}</td>
                                            <td>{{ number_format($order->final_amount, 2) }} {{ __('merchant_dashboard.currency') }}</td>
                                            <td>{{ __($order->order_status ?? 'processing') }}</td>
                                            <td>{{ __($order->payment_status ?? 'pending') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="4" class="text-center text-muted py-4">{{ __('merchant_dashboard.recent_orders_empty') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-lg-6 mb-4">
                <div class="card border-0 shadow-sm h-100">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('merchant_dashboard.quick_actions') }}</h6>
                    </div>
                    <div class="card-body">
                        <div class="d-flex flex-column gap-3">
                            <a href="{{ route('merchant.manual-payments.index') }}" class="btn btn-outline-primary d-flex justify-content-between align-items-center">
                                <span><i class="bi bi-cash-coin me-2"></i>{{ __('merchant_dashboard.quick_action_manuals') }}</span>
                                <i class="bi bi-chevron-left"></i>
                            </a>
                            <a href="{{ route('merchant.orders.index') }}" class="btn btn-outline-secondary d-flex justify-content-between align-items-center">
                                <span><i class="bi bi-bag-check me-2"></i>{{ __('merchant_dashboard.quick_action_orders') }}</span>
                                <i class="bi bi-chevron-left"></i>
                            </a>
                            <a href="{{ route('merchant.settings') }}" class="btn btn-outline-dark d-flex justify-content-between align-items-center">
                                <span><i class="bi bi-sliders me-2"></i>{{ __('merchant_dashboard.quick_action_settings') }}</span>
                                <i class="bi bi-chevron-left"></i>
                            </a>
                        </div>
                        <p class="text-muted small mt-3 mb-0">
                            {{ __('merchant_dashboard.quick_actions_hint') }}
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection

@push('styles')
<style>
    .manual-payment-timeline {
        list-style: none;
        margin: 0;
        padding: 0;
    }
    .manual-payment-timeline li {
        position: relative;
        padding-left: 28px;
        margin-bottom: 18px;
    }
    .manual-payment-timeline li::before {
        content: '';
        position: absolute;
        left: 7px;
        top: 0;
        width: 12px;
        height: 12px;
        border-radius: 50%;
        background-color: var(--bs-primary);
    }
    .manual-payment-timeline li::after {
        content: '';
        position: absolute;
        left: 12px;
        top: 12px;
        width: 2px;
        height: calc(100% + 6px);
        background-color: rgba(0, 0, 0, 0.1);
    }
    .manual-payment-timeline li:last-child::after {
        display: none;
    }
</style>
@endpush
