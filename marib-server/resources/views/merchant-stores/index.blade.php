@extends('layouts.main')

@php
    use App\Enums\StoreStatus;

    $statusBadges = [
        StoreStatus::DRAFT->value => 'secondary',
        StoreStatus::PENDING->value => 'warning',
        StoreStatus::APPROVED->value => 'success',
        StoreStatus::REJECTED->value => 'danger',
        StoreStatus::SUSPENDED->value => 'dark',
    ];
    $statusLabels = [
        StoreStatus::DRAFT->value => 'مسودة',
        StoreStatus::PENDING->value => 'بانتظار المراجعة',
        StoreStatus::APPROVED->value => 'معتمد',
        StoreStatus::REJECTED->value => 'مرفوض',
        StoreStatus::SUSPENDED->value => 'معلّق',
    ];
@endphp

@section('title', 'إدارة المتاجر والتجار')

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-12 col-md-6">
                <h4 class="mb-0">@yield('title')</h4>
                <p class="text-muted mb-0">لوحة متابعة ومراجعة لجميع المتاجر وطلبات التسجيل.</p>
            </div>
            <div class="col-12 col-md-6 text-md-end mt-3 mt-md-0">
                <a href="{{ route('seller-store-settings.index') }}" class="btn btn-outline-primary">
                    <i class="bi bi-sliders"></i>
                    إعدادات المتجر العامة
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-3 mb-3">
            <div class="col-md-3 col-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <p class="text-muted mb-1">إجمالي المتاجر</p>
                        <h3 class="mb-0">{{ number_format($metrics['total'] ?? 0) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-md-3 col-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <p class="text-muted mb-1">بانتظار المراجعة</p>
                        <h3 class="text-warning mb-0">{{ number_format($metrics['pending'] ?? 0) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-md-3 col-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <p class="text-muted mb-1">معتمدة وفعّالة</p>
                        <h3 class="text-success mb-0">{{ number_format($metrics['approved'] ?? 0) }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-md-3 col-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <p class="text-muted mb-1">متوقفة</p>
                        <h3 class="text-dark mb-0">{{ number_format($metrics['suspended'] ?? 0) }}</h3>
                    </div>
                </div>
            </div>
        </div>

        <div class="card mb-4">
            <div class="card-body">
                <form method="GET" class="row g-3 align-items-end">
                    <div class="col-lg-4 col-md-6">
                        <label class="form-label" for="store-search">بحث</label>
                        <input
                            id="store-search"
                            type="text"
                            name="search"
                            value="{{ $filters['search'] ?? '' }}"
                            class="form-control"
                            placeholder="اسم المتجر، المالك، رقم الهاتف..."
                        >
                    </div>
                    <div class="col-lg-3 col-md-4">
                        <label class="form-label" for="status-filter">الحالة</label>
                        <select id="status-filter" name="status" class="form-select">
                            <option value="">جميع الحالات</option>
                            @foreach($statuses as $status)
                                <option value="{{ $status->value }}" @selected(($filters['status'] ?? '') === $status->value)>
                                    {{ $statusLabels[$status->value] ?? $status->value }}
                                </option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-lg-5 col-md-12 text-md-end">
                        <button type="submit" class="btn btn-primary me-2">
                            <i class="bi bi-search"></i> تصفية
                        </button>
                        @if(($filters['search'] ?? '') !== '' || ($filters['status'] ?? '') !== '')
                            <a href="{{ route('merchant-stores.index') }}" class="btn btn-outline-secondary">
                                إعادة تعيين
                            </a>
                        @endif
                    </div>
                </form>
            </div>
        </div>

        <div class="card">
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-hover align-middle mb-0">
                        <thead class="table-light">
                        <tr>
                            <th>المتجر</th>
                            <th>مالك الحساب</th>
                            <th>الحالة</th>
                            <th>بيانات التواصل</th>
                            <th>إحصائيات</th>
                            <th class="text-end">إجراءات</th>
                        </tr>
                        </thead>
                        <tbody>
                        @forelse($stores as $store)
                            <tr>
                                <td>
                                    <div class="fw-semibold">{{ $store->name ?? 'متجر بدون اسم' }}</div>
                                    <small class="text-muted">#{{ $store->id }} · {{ $store->slug }}</small>
                                </td>
                                <td>
                                    <div>{{ $store->owner?->name ?? 'غير متوفر' }}</div>
                                    <small class="text-muted">{{ $store->owner?->email }}</small>
                                </td>
                                <td>
                                    @php
                                        $status = $store->status ?? StoreStatus::DRAFT->value;
                                        $badgeClass = $statusBadges[$status] ?? 'secondary';
                                    @endphp
                                    <span class="badge bg-{{ $badgeClass }}">
                                        {{ $statusLabels[$status] ?? $status }}
                                    </span>
                                    <div class="text-muted small">
                                        آخر تحديث {{ optional($store->status_changed_at)->diffForHumans() ?? '—' }}
                                    </div>
                                </td>
                                <td>
                                    <div>{{ $store->contact_phone ?? 'لا يوجد رقم' }}</div>
                                    <small class="text-muted">{{ $store->contact_email }}</small>
                                </td>
                                <td>
                                    <small class="text-muted d-block">
                                        المنتجات: {{ number_format($store->items_count ?? 0) }}
                                    </small>
                                    <small class="text-muted d-block">
                                        الطلبات: {{ number_format($store->orders_count ?? 0) }}
                                    </small>
                                </td>
                                <td class="text-end">
                                    <a
                                        href="{{ route('merchant-stores.show', $store) }}"
                                        class="btn btn-sm btn-outline-primary"
                                    >
                                        <i class="bi bi-eye"></i> معاينة
                                    </a>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="6" class="text-center py-5 text-muted">
                                    <div class="mb-2">
                                        <i class="bi bi-card-list fs-1"></i>
                                    </div>
                                    لا توجد متاجر مطابقة لخيارات البحث.
                                </td>
                            </tr>
                        @endforelse
                        </tbody>
                    </table>
                </div>

                <div class="p-3">
                    {{ $stores->withQueryString()->links() }}
                </div>
            </div>
        </div>
    </section>
@endsection
