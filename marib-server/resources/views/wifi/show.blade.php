@extends('layouts.main')

@section('title')
    {{ __('تفاصيل الشبكة :name', ['name' => $network->name]) }}
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
                        <li class="breadcrumb-item"><a href="{{ route('home') }}">{{ __('الرئيسية') }}</a></li>
                        <li class="breadcrumb-item"><a href="{{ route('wifi.index') }}">{{ __('شبكات كابينة الواي فاي') }}</a></li>
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
            'inactive' => 'غير نشطة',
            'suspended' => 'معلقة',
        ];
        $planStatusLabels = [
            'active' => 'نشطة',
            'uploaded' => 'تم الرفع',
            'validated' => 'تم التحقق',
            'archived' => 'مؤرشفة',
        ];
        $batchStatusLabels = [
            'uploaded' => 'مرفوع',
            'validated' => 'تم التحقق',
            'active' => 'مفعل',
            'archived' => 'مؤرشف',
        ];
        $contactLabels = [
            'owner' => 'مالك الشبكة',
            'manager' => 'المدير',
            'phone' => 'الهاتف',
            'whatsapp' => 'واتساب',
            'email' => 'البريد الإلكتروني',
            'support' => 'الدعم',
            'other' => 'أخرى',
        ];
        $commissionRate = isset($commissionRate)
            ? number_format($commissionRate * 100, 2) . '%'
            : '—';
        $financialFrom = $financialFilters['from'];
        $financialTo = $financialFilters['to'];
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
            <a href="{{ route('wifi.codes', $network) }}" class="btn btn-success">
                <i class="bi bi-table"></i>
                عرض ملف الأكواد
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
                            <dt class="col-5 text-muted">{{ __('الرمز المرجعي') }}</dt>
                            <dd class="col-7">{{ $network->reference_code ?? '—' }}</dd>
                            <dt class="col-5 text-muted">{{ __('عمولة الشبكة') }}</dt>
                            <dd class="col-7">{{ $commissionRate }}</dd>
                            <dt class="col-5 text-muted">{{ __('نطاق التغطية (كم)') }}</dt>
                            <dd class="col-7">{{ $network->coverage_radius_km ? number_format($network->coverage_radius_km, 1) . ' كم' : '—' }}</dd>
                            <dt class="col-5 text-muted">{{ __('آخر تحديث') }}</dt>
                            <dd class="col-7">{{ optional($network->updated_at ?? $network->created_at)->format('Y-m-d H:i') }}</dd>
                        </dl>
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-3">
                    <div class="card-header bg-white border-0">
                        <h6 class="mb-0">{{ __('معلومات التواصل') }}</h6>
                    </div>
                    <ul class="list-group list-group-flush wifi-contact-list">
                        @forelse($contacts as $contact)
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                <span class="text-muted">{{ $contactLabels[$contact['type']] ?? $contact['type'] }}</span>
                                <span class="fw-semibold">{{ $contact['value'] }}</span>
                            </li>
                        @empty
                            <li class="list-group-item text-muted">{{ __('لا توجد معلومات تواصل متاحة.') }}</li>
                        @endforelse
                    </ul>
                </div>

                @if ($media['login_screenshot'])
                    <div class="card shadow-sm border-0">
                        <div class="card-header bg-white border-0 d-flex justify-content-between align-items-center">
                            <h6 class="mb-0">{{ __('لقطة شاشة تسجيل الدخول') }}</h6>
                            <a href="{{ $media['login_screenshot'] }}" target="_blank" rel="noopener" class="small">{{ __('عرض الصورة بالحجم الكامل') }}</a>
                        </div>
                        <div class="card-body">
                            <div class="ratio ratio-4x3 rounded-4 overflow-hidden">
                                <img src="{{ $media['login_screenshot'] }}" alt="{{ __('صورة تسجيل الدخول') }}" class="w-100 h-100 object-fit-cover">
                            </div>
                        </div>
                    </div>
                @endif
            </div>

            <div class="col-lg-8">
                <div class="row g-3 mb-3">
                    <div class="col-md-4">
                        <div class="wifi-stat-card shadow-sm">
                            <span class="text-muted">{{ __('عدد الباقات') }}</span>
                            <strong>{{ number_format($statistics['plans']['total']) }}</strong>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="wifi-stat-card shadow-sm">
                            <span class="text-muted">{{ __('باقات نشطة') }}</span>
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
                        <h6 class="mb-0">{{ __('معلومات الشبكة') }}</h6>
                    </div>
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <dl class="mb-0 small">
                                    <dt class="text-muted">{{ __('العنوان') }}</dt>
                                    <dd>{{ $network->address ?? '—' }}</dd>
                                    <dt class="text-muted mt-3">{{ __('العملات') }}</dt>
                                    <dd>{{ implode('، ', $network->currencies ?? []) ?: '—' }}</dd>
                                    <dt class="text-muted mt-3">{{ __('الوصف') }}</dt>
                                    <dd>{{ $network->description ?? '—' }}</dd>
                                </dl>
                            </div>
                            <div class="col-md-6">
                                <dl class="mb-0 small">
                                    <dt class="text-muted">{{ __('المالك') }}</dt>
                                    <dd>{{ optional($network->owner)->name ?? '—' }}</dd>
                                    <dt class="text-muted mt-3">{{ __('بريد المالك الإلكتروني') }}</dt>
                                    <dd>{{ optional($network->owner)->email ?? '—' }}</dd>
                                    <dt class="text-muted mt-3">{{ __('هاتف المالك') }}</dt>
                                    <dd>{{ optional($network->owner)->mobile ?? optional($network->owner)->phone ?? '—' }}</dd>
                                </dl>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-3">
                    <div class="card-header bg-white border-0">
                        <div class="d-flex flex-column flex-lg-row align-items-lg-center justify-content-between gap-3">
                            <div>
                                <h6 class="mb-0">{{ __('ملخص مالي') }}</h6>
                                <small class="text-muted">{{ __('الفترة: من :from إلى :to', ['from' => $financialFrom->format('Y-m-d'), 'to' => $financialTo->format('Y-m-d')]) }}</small>
                            </div>
                            <div class="ms-auto">
                                <form method="get" class="row g-2 align-items-end">
                                    <div class="col">
                                        <label class="form-label form-label-sm">{{ __('من') }}</label>
                                        <input type="date" name="from" value="{{ $financialFrom->format('Y-m-d') }}" class="form-control form-control-sm">
                                    </div>
                                    <div class="col">
                                        <label class="form-label form-label-sm">{{ __('إلى') }}</label>
                                        <input type="date" name="to" value="{{ $financialTo->format('Y-m-d') }}" class="form-control form-control-sm">
                                    </div>
                                    <div class="col-auto d-flex gap-2">
                                        <button type="submit" class="btn btn-primary btn-sm">{{ __('تطبيق') }}</button>
                                        <a href="{{ route('wifi.financials.export', ['network' => $network, 'from' => $financialFrom->format('Y-m-d'), 'to' => $financialTo->format('Y-m-d')]) }}" class="btn btn-outline-secondary btn-sm">
                                            <i class="bi bi-download"></i>
                                            {{ __('تصدير CSV') }}
                                        </a>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="row g-3 mb-3">
                            <div class="col-md-4">
                                <div class="wifi-stat-card shadow-sm">
                                    <span class="text-muted">{{ __('إجمالي المبيعات') }}</span>
                                    <strong>{{ number_format($financialTotals['gross'], 2) }}</strong>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="wifi-stat-card shadow-sm">
                                    <span class="text-muted">{{ __('حصة المالك') }}</span>
                                    <strong>{{ number_format($financialTotals['owner_share'], 2) }}</strong>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="wifi-stat-card shadow-sm">
                                    <span class="text-muted">{{ __('العمولة') }}</span>
                                    <strong>{{ number_format($financialTotals['commission'], 2) }}</strong>
                                </div>
                            </div>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-sm align-middle">
                                <thead>
                                    <tr>
                                        <th>{{ __('التاريخ') }}</th>
                                        <th>{{ __('الباقة') }}</th>
                                        <th>{{ __('العميل') }}</th>
                                        <th>{{ __('المبلغ') }}</th>
                                        <th>{{ __('العملة') }}</th>
                                        <th>{{ __('العمولة') }}</th>
                                        <th>{{ __('حصة المالك') }}</th>
                                        <th>{{ __('المرجع') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($recentSales as $sale)
                                        <tr>
                                            <td>{{ optional($sale->paid_at ?? $sale->created_at)->format('Y-m-d H:i') ?? '—' }}</td>
                                            <td>{{ $sale->plan->name ?? '—' }}</td>
                                            <td>{{ $sale->user->name ?? '—' }}</td>
                                            <td>{{ number_format($sale->amount_gross, 2) }}</td>
                                            <td>{{ $sale->currency ?? '—' }}</td>
                                            <td>{{ number_format($sale->commission_amount, 2) }}</td>
                                            <td>{{ number_format($sale->owner_share_amount, 2) }}</td>
                                            <td>{{ $sale->payment_reference ?? '—' }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="8" class="text-center text-muted">{{ __('لا توجد مبيعات ضمن الفترة المحددة.') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>

                <div class="card shadow-sm border-0">
                    <div class="card-header bg-white border-0 d-flex justify-content-between align-items-center">
                        <h6 class="mb-0">{{ __('باقات الشبكة') }}</h6>
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
                                        @php
                                            $planStatusKey = $plan->status instanceof \App\Enums\Wifi\WifiPlanStatus
                                                ? $plan->status->value
                                                : $plan->status;
                                        @endphp
                                        <span class="badge bg-light text-dark">
                                            {{ $planStatusLabels[$planStatusKey] ?? $planStatusKey ?? '—' }}
                                        </span>
                                    </div>
                                    <div class="text-md-end">
                                        <div class="fw-semibold">{{ number_format($plan->price ?? 0, 2) }} {{ $plan->currency }}</div>
                                        <small class="text-muted">{{ __('مدة الباقة:') }} {{ $plan->duration_days ? "{$plan->duration_days} يوم" : '—' }}</small>
                                    </div>
                                </div>

                                <div class="row g-3 mt-3 small">
                                    <div class="col-sm-4">
                                        <span class="text-muted d-block">{{ __('الحد الأعلى للبيانات (جيجابايت/غير محدود)') }}</span>
                                        <strong>{{ $plan->is_unlimited ? __('غير محدود') : ($plan->data_cap_gb ? number_format($plan->data_cap_gb, 2) . ' جيجابايت' : '—') }}</strong>
                                    </div>
                                    <div class="col-sm-4">
                                        <span class="text-muted d-block">{{ __('الأكواد المتاحة / الإجمالي') }}</span>
                                        <strong>{{ number_format($planAvailable) }} / {{ number_format($planTotal) }}</strong>
                                    </div>
                                    <div class="col-sm-4">
                                        <span class="text-muted d-block">{{ __('المباعة') }}</span>
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
                                                <th>{{ __('الأكواد المتاحة/الإجمالي') }}</th>
                                                <th>{{ __('تاريخ الإنشاء') }}</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            @forelse($plan->codeBatches as $batch)
                                                <tr>
                                                    <td>{{ $batch->label ?? '—' }}</td>
                                                    <td>
                                                        @php
                                                            $batchStatusKey = $batch->status instanceof \App\Enums\Wifi\WifiCodeBatchStatus
                                                                ? $batch->status->value
                                                                : $batch->status;
                                                        @endphp
                                                        <span class="badge bg-secondary-subtle text-dark">
                                                            {{ $batchStatusLabels[$batchStatusKey] ?? $batchStatusKey ?? '—' }}
                                                        </span>
                                                    </td>
                                                    <td>{{ number_format($batch->available_codes ?? 0) }} / {{ number_format($batch->total_codes ?? 0) }}</td>
                                                    <td>{{ optional($batch->created_at)->format('Y-m-d H:i') ?? '—' }}</td>
                                                </tr>
                                            @empty
                                                <tr>
                                                    <td colspan="4" class="text-muted text-center">{{ __('لا توجد دفعات أكواد لهذه الباقة.') }}</td>
                                                </tr>
                                            @endforelse
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        @empty
                            <p class="text-muted mb-0">{{ __('لا توجد باقات مرتبطة بهذه الشبكة.') }}</p>
                        @endforelse
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
