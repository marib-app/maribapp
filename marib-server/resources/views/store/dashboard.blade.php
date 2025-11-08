@extends('layouts.main')

@section('title', __('لوحة المتجر'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('متابعة أداء متجرك وحالة الطلبات بشكل لحظي.') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end align-items-start gap-2 flex-wrap">
                <a href="{{ route('seller-store-settings.index') }}" class="btn btn-outline-primary">
                    <i class="bi bi-gear me-1"></i>{{ __('إعدادات المتجر') }}
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
            @foreach (['today' => __('اليوم'), 'week' => __('آخر ٧ أيام'), 'month' => __('آخر ٣٠ يوماً')] as $key => $label)
                <div class="col-12 col-md-4 mb-3">
                    <div class="card h-100 shadow-sm border-0">
                        <div class="card-header bg-light d-flex justify-content-between align-items-center">
                            <div>
                                <p class="text-muted mb-0 small">{{ $label }}</p>
                                <small class="text-muted">
                                    {{ $overview[$key]['range']['from'] }} - {{ $overview[$key]['range']['to'] }}
                                </small>
                            </div>
                            <span class="badge bg-primary">{{ number_format($overview[$key]['orders']) }} {{ __('طلب') }}</span>
                        </div>
                        <div class="card-body">
                            <div class="mb-3">
                                <h3 class="mb-1">{{ number_format($overview[$key]['revenue'], 2) }}</h3>
                                <span class="text-muted">{{ __('الإيراد (ر.ي)') }}</span>
                            </div>
                            <div class="d-flex justify-content-between text-muted small">
                                <div>
                                    <span class="d-block">{{ __('زيارات') }}</span>
                                    <strong>{{ number_format($overview[$key]['visits']) }}</strong>
                                </div>
                                <div>
                                    <span class="d-block">{{ __('مشاهدات المنتجات') }}</span>
                                    <strong>{{ number_format($overview[$key]['product_views']) }}</strong>
                                </div>
                                <div>
                                    <span class="d-block">{{ __('إضافات للسلة') }}</span>
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
                                <p class="text-muted mb-1">{{ __('حالة المتجر') }}</p>
                                <span class="badge bg-{{ $statusCard['status'] === 'approved' ? 'success' : 'warning' }}">
                                    {{ __($statusCard['status']) }}
                                </span>
                            </div>
                            <a href="{{ route('seller-store-settings.index') }}" class="btn btn-outline-secondary btn-sm">
                                <i class="bi bi-gear"></i> {{ __('إعدادات المتجر') }}
                            </a>
                        </div>
                        <ul class="list-unstyled mb-0 text-muted small">
                            <li class="mb-1">
                                <strong>{{ __('وضع الإغلاق:') }}</strong>
                                {{ $statusCard['closure_mode'] === 'browse_only' ? __('تصفح فقط') : __('إغلاق كامل') }}
                            </li>
                            <li class="mb-1">
                                <strong>{{ __('إغلاق يدوي:') }}</strong>
                                {{ $statusCard['is_manually_closed'] ? __('مفعل') : __('غير مفعل') }}
                            </li>
                            <li class="mb-1">
                                <strong>{{ __('الحد الأدنى للطلب:') }}</strong>
                                {{ $statusCard['min_order_amount'] ? number_format($statusCard['min_order_amount'], 2) . ' ' . __('ر.ي') : __('غير محدد') }}
                            </li>
                            <li class="mb-1">
                                <strong>{{ __('التوصيل:') }}</strong>
                                <i class="bi bi-circle-fill text-{{ $statusCard['allow_delivery'] ? 'success' : 'secondary' }} me-1"></i>
                                {{ $statusCard['allow_delivery'] ? __('مفعل') : __('غير متاح') }}
                            </li>
                            <li>
                                <strong>{{ __('الاستلام:') }}</strong>
                                <i class="bi bi-circle-fill text-{{ $statusCard['allow_pickup'] ? 'success' : 'secondary' }} me-1"></i>
                                {{ $statusCard['allow_pickup'] ? __('مفعل') : __('غير متاح') }}
                            </li>
                            @if ($statusCard['closure_reason'])
                                <li class="mt-2">
                                    <strong>{{ __('سبب الإغلاق:') }}</strong> {{ $statusCard['closure_reason'] }}
                                </li>
                            @endif
                            @if ($statusCard['closure_expires_at'])
                                <li>
                                    <strong>{{ __('ينتهي في:') }}</strong> {{ $statusCard['closure_expires_at'] }}
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
                                <p class="text-muted mb-1">{{ __('حوالات قيد المراجعة') }}</p>
                                <h3 class="mb-0">{{ number_format($manualPaymentStats['open_count'] ?? 0) }}</h3>
                                <small class="text-muted d-block mb-2">{{ __('إجمالي المبلغ') }}: {{ number_format($manualPaymentStats['open_amount'] ?? 0, 2) }} {{ __('ر.ي') }}</small>
                                <div class="d-flex gap-3 text-muted small">
                                    <div>
                                        <span class="d-block">{{ __('مقبولة اليوم') }}</span>
                                        <strong>{{ number_format($manualPaymentStats['approved_today'] ?? 0) }}</strong>
                                    </div>
                                    <div>
                                        <span class="d-block">{{ __('مرفوضة اليوم') }}</span>
                                        <strong>{{ number_format($manualPaymentStats['rejected_today'] ?? 0) }}</strong>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="col-12 col-md-6">
                        <div class="card border-0 shadow-sm h-100">
                            <div class="card-body">
                                <p class="text-muted mb-1">{{ __('طلبات قيد التنفيذ') }}</p>
                                <h3 class="mb-0">{{ number_format($pendingOrderCount) }}</h3>
                                <small class="text-muted">{{ __('قيمة تقريبية') }}: {{ number_format($pendingOrderValue, 2) }} {{ __('ر.ي') }}</small>
                                <div class="mt-3">
                                    <a href="{{ route('merchant.manual-payments.index') }}" class="btn btn-outline-primary btn-sm me-2">
                                        <i class="bi bi-receipt"></i> {{ __('إدارة الحوالات') }}
                                    </a>
                                    <a href="{{ route('merchant.orders.index') }}" class="btn btn-outline-secondary btn-sm">
                                        <i class="bi bi-basket"></i> {{ __('إدارة الطلبات') }}
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
                        <h6 class="mb-0">{{ __('أحدث الحوالات اليدوية') }}</h6>
                        <a href="{{ route('merchant.manual-payments.index') }}" class="btn btn-link btn-sm">
                            {{ __('عرض الكل') }}
                        </a>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('المرجع') }}</th>
                                        <th>{{ __('العميل') }}</th>
                                        <th>{{ __('المبلغ') }}</th>
                                        <th>{{ __('الحالة') }}</th>
                                        <th>{{ __('التاريخ') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($recentManualPayments as $payment)
                                        <tr>
                                            <td>#{{ $payment->id }}</td>
                                            <td>{{ $payment->user?->name ?? __('مستخدم') }}</td>
                                            <td>{{ number_format($payment->amount ?? 0, 2) }} {{ $payment->currency ?? __('ر.ي') }}</td>
                                            <td>
                                                <span class="badge bg-{{ $payment->status === \App\Models\ManualPaymentRequest::STATUS_APPROVED ? 'success' : ($payment->status === \App\Models\ManualPaymentRequest::STATUS_REJECTED ? 'danger' : 'warning') }}">
                                                    {{ __($payment->status) }}
                                                </span>
                                            </td>
                                            <td>{{ optional($payment->created_at)->format('Y-m-d H:i') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="5" class="text-center text-muted py-4">{{ __('لا توجد بيانات.') }}</td>
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
                        <h6 class="mb-0">{{ __('نشاطات حديثة') }}</h6>
                    </div>
                    <div class="card-body">
                        @if ($recentActivities->isEmpty())
                            <p class="text-muted mb-0">{{ __('لا يوجد نشاط مؤخراً.') }}</p>
                        @else
                            <ul class="manual-payment-timeline">
                                @foreach ($recentActivities as $activity)
                                    <li>
                                        <div class="timeline-point bg-{{ $activity->status === \App\Models\ManualPaymentRequest::STATUS_APPROVED ? 'success' : ($activity->status === \App\Models\ManualPaymentRequest::STATUS_REJECTED ? 'danger' : 'primary') }}"></div>
                                        <div class="timeline-content">
                                            <div class="d-flex justify-content-between flex-wrap gap-2">
                                                <strong>{{ __($activity->status) }}</strong>
                                                <small class="text-muted">{{ optional($activity->created_at)->diffForHumans() }}</small>
                                            </div>
                                            <p class="mb-1 text-muted">
                                                #{{ $activity->manualPaymentRequest?->id }} · {{ $activity->user?->name ?? __('النظام') }}
                                            </p>
                                            @if ($activity->note)
                                                <p class="mb-0">{{ $activity->note }}</p>
                                            @endif
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
                        <h6 class="mb-0">{{ __('آخر الطلبات') }}</h6>
                        <a href="{{ route('merchant.orders.index') }}" class="btn btn-link btn-sm">{{ __('عرض الكل') }}</a>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('الطلب') }}</th>
                                        <th>{{ __('القيمة') }}</th>
                                        <th>{{ __('الحالة') }}</th>
                                        <th>{{ __('الدفع') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($recentOrders as $order)
                                        <tr>
                                            <td>#{{ $order->order_number ?? $order->id }}</td>
                                            <td>{{ number_format($order->final_amount, 2) }} {{ __('ر.ي') }}</td>
                                            <td>{{ __($order->order_status ?? 'processing') }}</td>
                                            <td>{{ __($order->payment_status ?? 'pending') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="4" class="text-center text-muted py-4">{{ __('لا توجد طلبات حديثة.') }}</td>
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
                        <h6 class="mb-0">{{ __('إجراءات سريعة') }}</h6>
                    </div>
                    <div class="card-body">
                        <div class="d-flex flex-column gap-3">
                            <a href="{{ route('merchant.manual-payments.index') }}" class="btn btn-outline-primary d-flex justify-content-between align-items-center">
                                <span><i class="bi bi-cash-coin me-2"></i>{{ __('مراجعة الحوالات') }}</span>
                                <i class="bi bi-chevron-left"></i>
                            </a>
                            <a href="{{ route('merchant.orders.index') }}" class="btn btn-outline-secondary d-flex justify-content-between align-items-center">
                                <span><i class="bi bi-bag-check me-2"></i>{{ __('إدارة الطلبات') }}</span>
                                <i class="bi bi-chevron-left"></i>
                            </a>
                            <a href="{{ route('seller-store-settings.index') }}" class="btn btn-outline-dark d-flex justify-content-between align-items-center">
                                <span><i class="bi bi-sliders me-2"></i>{{ __('تعديل إعدادات المتجر') }}</span>
                                <i class="bi bi-chevron-left"></i>
                            </a>
                        </div>
                        <p class="text-muted small mt-3 mb-0">
                            {{ __('كل الإجراءات الأساسية متاحة لك من هذه اللوحة لتسريع إدارة المتجر.') }}
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
        bottom: -10px;
        width: 2px;
        background: #e5e7eb;
    }
    .manual-payment-timeline li:last-child::before {
        bottom: 12px;
    }
    .manual-payment-timeline .timeline-point {
        position: absolute;
        left: 0;
        top: 4px;
        width: 14px;
        height: 14px;
        border-radius: 50%;
    }
    .manual-payment-timeline .timeline-content {
        background: #f9fafb;
        border-radius: 8px;
        padding: 8px 12px;
    }
</style>
@endpush
