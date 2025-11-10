@extends('layouts.main')

@section('title')
    {{ __('تفاصيل شبكة :name', ['name' => $network->name]) }}
@endsection

@section('css')
    @vite(['resources/js/wifi/show.scss'])
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
                        <li class="breadcrumb-item"><a href="{{ route('home') }}">{{ __('لوحة التحكم') }}</a></li>
                        <li class="breadcrumb-item"><a href="{{ route('wifi.index') }}">{{ __('إدارة الواي فاي') }}</a></li>
                        <li class="breadcrumb-item active" aria-current="page">{{ $network->name }}</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    @php
        $networkStatusLabels = [
            'active' => 'نشطة',
            'inactive' => 'متوقفة',
            'suspended' => 'معلقة',
        ];
        $planStatusLabels = [
            'active' => 'نشطة',
            'uploaded' => 'قيد الرفع',
            'validated' => 'قيد المراجعة',
            'archived' => 'مؤرشفة',
        ];
        $batchStatusLabels = [
            'uploaded' => 'مرفوعة',
            'validated' => 'قيد التحقق',
            'active' => 'مفعّلة',
            'archived' => 'مؤرشفة',
        ];
        $contactLabels = [
            'owner' => 'مالك الشبكة',
            'manager' => 'المسؤول',
            'phone' => 'هاتف',
            'whatsapp' => 'واتساب',
            'email' => 'البريد الإلكتروني',
            'support' => 'الدعم',
            'other' => 'قناة أخرى',
        ];
        $commissionRate = isset($commissionRate)
            ? number_format($commissionRate * 100, 2) . '%'
            : '—';
    @endphp

    <section class="section wifi-network-show">
        <div class="d-flex flex-wrap gap-2 mb-4">
            <a href="{{ route('wifi.index') }}" class="btn btn-outline-secondary">
                <i class="bi bi-arrow-right"></i>
                {{ __('العودة للقائمة') }}
            </a>
            <a href="{{ route('wifi.edit', $network) }}" class="btn btn-primary">
                <i class="bi bi-pencil-square"></i>
                {{ __('تحرير الشبكة') }}
            </a>
        </div>

        <div class="row g-4">
            <div class="col-lg-4">
                <div class="card shadow-sm border-0 mb-3">
                    <div class="card-body text-center">
                        <div class="wifi-logo mb-3">
                            @if ($media['logo'])
                                <img src="{{ $media['logo'] }}" alt="{{ $network->name }}" class="img-fluid rounded-4 shadow-sm">
                            @else
                                <div class="wifi-logo__placeholder rounded-4">
                                    <i class="bi bi-wifi" aria-hidden="true"></i>
                                </div>
                            @endif
                        </div>
                        <h5 class="mb-1">{{ $network->name }}</h5>
                        <p class="text-muted mb-3">{{ $network->slug ? "#{$network->slug}" : '—' }}</p>
                        <span class="badge bg-primary-subtle text-primary px-3 py-2">
                            {{ $networkStatusLabels[$network->status?->value ?? $network->status] ?? ($network->status ?? '—') }}
                        </span>
                    </div>
                    <div class="card-body border-top">
                        <dl class="row mb-0 small">
                            <dt class="col-5 text-muted">{{ __('رقم الشبكة') }}</dt>
                            <dd class="col-7">{{ $network->reference_code ?? '—' }}</dd>
                            <dt class="col-5 text-muted">{{ __('العمولة الحالية') }}</dt>
                            <dd class="col-7">{{ $commissionRate }}</dd>
                            <dt class="col-5 text-muted">{{ __('مدى التغطية') }}</dt>
                            <dd class="col-7">{{ $network->coverage_radius_km ? number_format($network->coverage_radius_km, 1) . ' كم' : '—' }}</dd>
                            <dt class="col-5 text-muted">{{ __('تاريخ التحديث') }}</dt>
                            <dd class="col-7">{{ optional($network->updated_at ?? $network->created_at)->format('Y-m-d H:i') }}</dd>
                        </dl>
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-3">
                    <div class="card-header bg-white border-0">
                        <h6 class="mb-0">{{ __('بيانات التواصل') }}</h6>
                    </div>
                    <ul class="list-group list-group-flush wifi-contact-list">
                        @forelse($contacts as $contact)
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                <span class="text-muted">{{ $contactLabels[$contact['type']] ?? $contact['type'] }}</span>
                                <span class="fw-semibold">{{ $contact['value'] }}</span>
                            </li>
                        @empty
                            <li class="list-group-item text-muted">{{ __('لا تتوفر بيانات اتصال.') }}</li>
                        @endforelse
                    </ul>
                </div>

                @if ($media['login_screenshot'])
                    <div class="card shadow-sm border-0">
                        <div class="card-header bg-white border-0 d-flex justify-content-between align-items-center">
                            <h6 class="mb-0">{{ __('صورة شاشة تسجيل الدخول') }}</h6>
                            <a href="{{ $media['login_screenshot'] }}" target="_blank" rel="noopener" class="small">{{ __('عرض بالحجم الكامل') }}</a>
                        </div>
                        <div class="card-body">
                            <div class="ratio ratio-4x3 rounded-4 overflow-hidden">
                                <img src="{{ $media['login_screenshot'] }}" alt="{{ __('شاشة الدخول') }}" class="w-100 h-100 object-fit-cover">
                            </div>
                        </div>
                    </div>
                @endif
            </div>

            <div class="col-lg-8">
                <div class="row g-3 mb-3">
                    <div class="col-md-4">
                        <div class="wifi-stat-card shadow-sm">
                            <span class="text-muted">{{ __('إجمالي الخطط') }}</span>
                            <strong>{{ number_format($statistics['plans']['total']) }}</strong>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="wifi-stat-card shadow-sm">
                            <span class="text-muted">{{ __('الخطط النشطة') }}</span>
                            <strong>{{ number_format($statistics['plans']['active']) }}</strong>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="wifi-stat-card shadow-sm">
                            <span class="text-muted">{{ __('الأكواد المتاحة') }}</span>
                            <strong>{{ number_format($statistics['codes']['available']) }}</strong>
                        </div>
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-3">
                    <div class="card-header bg-white border-0">
                        <h6 class="mb-0">{{ __('بيانات الشبكة') }}</h6>
                    </div>
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <dl class="mb-0 small">
                                    <dt class="text-muted">{{ __('العنوان') }}</dt>
                                    <dd>{{ $network->address ?? '—' }}</dd>
                                    <dt class="text-muted mt-3">{{ __('العملة') }}</dt>
                                    <dd>{{ implode('، ', $network->currencies ?? []) ?: '—' }}</dd>
                                    <dt class="text-muted mt-3">{{ __('الوصف') }}</dt>
                                    <dd>{{ $network->description ?? '—' }}</dd>
                                </dl>
                            </div>
                            <div class="col-md-6">
                                <dl class="mb-0 small">
                                    <dt class="text-muted">{{ __('المالك') }}</dt>
                                    <dd>{{ optional($network->owner)->name ?? '—' }}</dd>
                                    <dt class="text-muted mt-3">{{ __('البريد الإلكتروني') }}</dt>
                                    <dd>{{ optional($network->owner)->email ?? '—' }}</dd>
                                    <dt class="text-muted mt-3">{{ __('رقم الهاتف') }}</dt>
                                    <dd>{{ optional($network->owner)->mobile ?? optional($network->owner)->phone ?? '—' }}</dd>
                                </dl>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="card shadow-sm border-0">
                    <div class="card-header bg-white border-0 d-flex justify-content-between align-items-center">
                        <h6 class="mb-0">{{ __('خطط الشبكة') }}</h6>
                        <span class="badge bg-primary-subtle text-primary">{{ $network->plans->count() }}</span>
                    </div>
                    <div class="card-body">
                        @forelse($network->plans as $plan)
                            @php
                                $planTotal = $plan->codeBatches->sum('total_codes');
                                $planAvailable = $plan->codeBatches->sum('available_codes');
                                $planSold = max($planTotal - $planAvailable, 0);
                            @endphp
                            <div class="wifi-plan-card mb-4">
                                <div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between gap-3">
                                    <div>
                                        <h5 class="mb-1">{{ $plan->name }}</h5>
                                        <span class="badge bg-light text-dark">
                                            {{ $planStatusLabels[$plan->status] ?? $plan->status ?? '—' }}
                                        </span>
                                    </div>
                                    <div class="text-md-end">
                                        <div class="fw-semibold">{{ number_format($plan->price ?? 0, 2) }} {{ $plan->currency }}</div>
                                        <small class="text-muted">{{ __('مدة الصلاحية:') }} {{ $plan->duration_days ? "{$plan->duration_days} يوم" : '—' }}</small>
                                    </div>
                                </div>

                                <div class="row g-3 mt-3 small">
                                    <div class="col-sm-4">
                                        <span class="text-muted d-block">{{ __('حجم البيانات') }}</span>
                                        <strong>{{ $plan->is_unlimited ? __('غير محدود') : ($plan->data_cap_gb ? number_format($plan->data_cap_gb, 2) . ' جيجا' : '—') }}</strong>
                                    </div>
                                    <div class="col-sm-4">
                                        <span class="text-muted d-block">{{ __('الرصيد المتاح') }}</span>
                                        <strong>{{ number_format($planAvailable) }} / {{ number_format($planTotal) }}</strong>
                                    </div>
                                    <div class="col-sm-4">
                                        <span class="text-muted d-block">{{ __('المباع') }}</span>
                                        <strong>{{ number_format($planSold) }}</strong>
                                    </div>
                                </div>

                                @if ($plan->description)
                                    <p class="mt-3 mb-0 text-muted">{{ $plan->description }}</p>
                                @endif

                                <div class="table-responsive mt-3">
                                    <table class="table table-sm align-middle mb-0">
                                        <thead>
                                            <tr>
                                                <th>{{ __('الدفعة') }}</th>
                                                <th>{{ __('الحالة') }}</th>
                                                <th>{{ __('الأكواد (متاح/إجمالي)') }}</th>
                                                <th>{{ __('تاريخ الإضافة') }}</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            @forelse($plan->codeBatches as $batch)
                                                <tr>
                                                    <td>{{ $batch->label ?? '—' }}</td>
                                                    <td>
                                                        <span class="badge bg-secondary-subtle text-dark">
                                                            {{ $batchStatusLabels[$batch->status] ?? $batch->status ?? '—' }}
                                                        </span>
                                                    </td>
                                                    <td>{{ number_format($batch->available_codes ?? 0) }} / {{ number_format($batch->total_codes ?? 0) }}</td>
                                                    <td>{{ optional($batch->created_at)->format('Y-m-d H:i') ?? '—' }}</td>
                                                </tr>
                                            @empty
                                                <tr>
                                                    <td colspan="4" class="text-muted text-center">{{ __('لا توجد دفعات مسجلة لهذه الخطة.') }}</td>
                                                </tr>
                                            @endforelse
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        @empty
                            <p class="text-muted mb-0">{{ __('لا توجد خطط مرتبطة بهذه الشبكة بعد.') }}</p>
                        @endforelse
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
