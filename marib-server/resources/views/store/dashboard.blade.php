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
        <div class="row">
            @foreach (['today' => __('اليوم'), 'week' => __('آخر ٧ أيام'), 'month' => __('آخر ٣٠ يوماً')] as $key => $label)
                <div class="col-12 col-md-4 mb-3">
                    <div class="card h-100">
                        <div class="card-header d-flex justify-content-between align-items-center">
                            <h6 class="mb-0">{{ $label }}</h6>
                            <small class="text-muted">
                                {{ $overview[$key]['range']['from'] }} - {{ $overview[$key]['range']['to'] }}
                            </small>
                        </div>
                        <div class="card-body">
                            <div class="mb-3">
                                <h2 class="mb-0">{{ number_format($overview[$key]['orders']) }}</h2>
                                <span class="text-muted">{{ __('طلبات') }}</span>
                            </div>
                            <div class="mb-3">
                                <h4 class="mb-0">{{ number_format($overview[$key]['revenue'], 2) }}</h4>
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

        <div class="row">
            <div class="col-12 col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('حالة المتجر') }}</h6>
                    </div>
                    <div class="card-body">
                        <p class="mb-2">
                            <span class="fw-bold">{{ __('الحالة الحالية:') }}</span>
                            <span class="badge bg-{{ $statusCard['status'] === 'approved' ? 'success' : 'warning' }}">
                                {{ __($statusCard['status']) }}
                            </span>
                        </p>
                        <p class="mb-2">
                            <span class="fw-bold">{{ __('وضع الإغلاق:') }}</span>
                            {{ $statusCard['closure_mode'] === 'browse_only' ? __('تصفح فقط') : __('إغلاق كامل') }}
                        </p>
                        <p class="mb-2">
                            <span class="fw-bold">{{ __('إغلاق يدوي:') }}</span>
                            {{ $statusCard['is_manually_closed'] ? __('مفعل') : __('غير مفعل') }}
                        </p>
                        @if ($statusCard['closure_reason'])
                            <p class="text-muted small mb-2">
                                {{ __('سبب الإغلاق: :reason', ['reason' => $statusCard['closure_reason']]) }}
                            </p>
                        @endif
                        @if ($statusCard['closure_expires_at'])
                            <p class="text-muted small mb-2">
                                {{ __('ينتهي الإغلاق في: :time', ['time' => $statusCard['closure_expires_at']]) }}
                            </p>
                        @endif
                        <p class="mb-0">
                            <span class="fw-bold">{{ __('الحد الأدنى للطلب:') }}</span>
                            {{ $statusCard['min_order_amount'] ? number_format($statusCard['min_order_amount'], 2) . ' ر.ي' : __('غير محدد') }}
                        </p>
                    </div>
                </div>
            </div>
            <div class="col-12 col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('إعدادات التوصيل والاستلام') }}</h6>
                    </div>
                    <div class="card-body">
                        <ul class="list-unstyled mb-0">
                            <li class="mb-2">
                                <i class="bi bi-check-circle text-{{ $statusCard['allow_delivery'] ? 'success' : 'secondary' }} me-2"></i>
                                {{ __('التوصيل') }}
                            </li>
                            <li class="mb-2">
                                <i class="bi bi-check-circle text-{{ $statusCard['allow_pickup'] ? 'success' : 'secondary' }} me-2"></i>
                                {{ __('الاستلام من المتجر') }}
                            </li>
                        </ul>
                        <p class="text-muted small mb-0">
                            {{ __('يمكنك تعديل هذه الخيارات من صفحة الإعدادات.') }}
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
