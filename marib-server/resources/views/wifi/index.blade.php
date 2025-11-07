@extends('layouts.main')

@section('title')
    {{ __('إدارة كبائن الواي فاي') }}
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
                        <li class="breadcrumb-item active" aria-current="page">{{ __('كبائن الواي فاي') }}</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-3">
            <div class="col-12">
                @if (session('status'))
                    <div class="alert alert-success" role="alert">
                        {{ session('status') }}
                    </div>
                @endif
            </div>

            <div class="col-xl-3 col-lg-4 col-md-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <span class="badge bg-primary-subtle text-primary"><i class="bi bi-router"></i></span>
                            <span class="badge bg-primary">{{ __('الشبكات') }}</span>
                        </div>
                        <h3 class="fw-bold mb-0">{{ number_format($stats['networks']['total']) }}</h3>
                        <p class="text-muted small mb-0">{{ __('نشط: :active | موقوف: :inactive | معلّق: :suspended', [
                            'active' => number_format($stats['networks']['active']),
                            'inactive' => number_format($stats['networks']['inactive']),
                            'suspended' => number_format($stats['networks']['suspended'])
                        ]) }}</p>
                    </div>
                </div>
            </div>

            <div class="col-xl-3 col-lg-4 col-md-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <span class="badge bg-success-subtle text-success"><i class="bi bi-list-check"></i></span>
                            <span class="badge bg-success">{{ __('الخطط') }}</span>
                        </div>
                        <h3 class="fw-bold mb-0">{{ number_format($stats['plans']['total']) }}</h3>
                        <p class="text-muted small mb-0">{{ __('نشطة: :active | مرفوعة: :uploaded | مؤرشفة: :archived', [
                            'active' => number_format($stats['plans']['active']),
                            'uploaded' => number_format($stats['plans']['uploaded']),
                            'archived' => number_format($stats['plans']['archived'])
                        ]) }}</p>
                    </div>
                </div>
            </div>

            <div class="col-xl-3 col-lg-4 col-md-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <span class="badge bg-warning-subtle text-warning"><i class="bi bi-box-seam"></i></span>
                            <span class="badge bg-warning text-dark">{{ __('دفعات الأكواد') }}</span>
                        </div>
                        <h3 class="fw-bold mb-0">{{ number_format($stats['batches']['total']) }}</h3>
                        <p class="text-muted small mb-0">{{ __('قيد المراجعة: :pending | مفعّلة: :active', [
                            'pending' => number_format($stats['batches']['pending']),
                            'active' => number_format($stats['batches']['active'])
                        ]) }}</p>
                    </div>
                </div>
            </div>

            <div class="col-xl-3 col-lg-4 col-md-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <span class="badge bg-info-subtle text-info"><i class="bi bi-key"></i></span>
                            <span class="badge bg-info text-dark">{{ __('الأكواد') }}</span>
                        </div>
                        <h3 class="fw-bold mb-0">{{ number_format($stats['codes']['total']) }}</h3>
                        <p class="text-muted small mb-0">{{ __('متاحة: :available | مباعة: :sold', [
                            'available' => number_format($stats['codes']['available']),
                            'sold' => number_format($stats['codes']['sold'])
                        ]) }}</p>
                    </div>
                </div>
            </div>

            <div class="col-12 col-lg-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-header border-0 bg-white d-flex justify-content-between align-items-center">
                        <h5 class="card-title mb-0">{{ __('طلبات المالك المعلقة') }}</h5>
                        <a href="{{ route('wifi.create') }}" class="btn btn-sm btn-primary">
                            <i class="bi bi-upload"></i> {{ __('رفع دفعة جديدة') }}
                        </a>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover align-middle mb-0">
                                <thead class="table-light">
                                    <tr>
                                        <th>{{ __('الخطة') }}</th>
                                        <th>{{ __('الشبكة') }}</th>
                                        <th>{{ __('الوسم') }}</th>
                                        <th>{{ __('الإجمالي') }}</th>
                                        <th>{{ __('تاريخ الرفع') }}</th>
                                        <th class="text-end">{{ __('الإجراءات') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                @forelse($pendingRequests as $requestBatch)
                                    <tr>
                                        <td>{{ $requestBatch->plan?->name ?? '—' }}</td>
                                        <td>{{ $requestBatch->plan?->network?->name ?? '—' }}</td>
                                        <td>{{ $requestBatch->label }}</td>
                                        <td>{{ number_format($requestBatch->total_codes ?? 0) }}</td>
                                        <td>{{ optional($requestBatch->created_at)->format('Y-m-d H:i') }}</td>
                                        <td class="text-end">
                                            <div class="d-flex justify-content-end gap-2">
                                                <form method="post" action="{{ route('wifi.owner-requests.approve', $requestBatch) }}">
                                                    @csrf
                                                    <button type="submit" class="btn btn-success btn-sm">
                                                        <i class="bi bi-check-circle"></i> {{ __('موافقة') }}
                                                    </button>
                                                </form>
                                                <button type="button" class="btn btn-outline-danger btn-sm" data-bs-toggle="modal" data-bs-target="#reject-batch-{{ $requestBatch->id }}">
                                                    <i class="bi bi-x-circle"></i> {{ __('رفض') }}
                                                </button>
                                            </div>

                                            <div class="modal fade" id="reject-batch-{{ $requestBatch->id }}" tabindex="-1" aria-hidden="true">
                                                <div class="modal-dialog modal-dialog-centered">
                                                    <div class="modal-content">
                                                        <div class="modal-header">
                                                            <h5 class="modal-title">{{ __('رفض طلب المالك') }}</h5>
                                                            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('إغلاق') }}"></button>
                                                        </div>
                                                        <form method="post" action="{{ route('wifi.owner-requests.reject', $requestBatch) }}">
                                                            @csrf
                                                            <div class="modal-body">
                                                                <p class="text-muted">{{ __('يرجى توضيح سبب الرفض (اختياري).') }}</p>
                                                                <textarea name="reason" class="form-control" rows="3" placeholder="{{ __('سبب الرفض') }}"></textarea>
                                                            </div>
                                                            <div class="modal-footer">
                                                                <button type="button" class="btn btn-light" data-bs-dismiss="modal">{{ __('إلغاء') }}</button>
                                                                <button type="submit" class="btn btn-danger">{{ __('تأكيد الرفض') }}</button>
                                                            </div>
                                                        </form>
                                                    </div>
                                                </div>
                                            </div>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="6" class="text-center text-muted py-4">{{ __('لا توجد طلبات معلقة حاليًا.') }}</td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12 col-lg-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-header border-0 bg-white">
                        <h5 class="card-title mb-0">{{ __('إعدادات التنبيه الافتراضية') }}</h5>
                    </div>
                    <div class="card-body">
                        <p class="text-muted">{{ __('يتم جلب هذه القيم من ملف الإعدادات config/wifi.php.') }}</p>
                        <dl class="row mb-0">
                            <dt class="col-sm-6">{{ __('حد تنبيه انخفاض المخزون') }}</dt>
                            <dd class="col-sm-6">{{ number_format(data_get($alertsConfig, 'low_stock_threshold', 0)) }}</dd>

                            <dt class="col-sm-6">{{ __('فترة التهدئة (بالدقائق)') }}</dt>
                            <dd class="col-sm-6">{{ number_format(data_get($alertsConfig, 'low_stock_cooldown_minutes', 0)) }}</dd>
                        </dl>
                        <p class="text-muted small mt-3 mb-0">{{ __('نقطة نهاية واجهة برمجة التطبيقات الإدارية:') }}
                            <code>{{ $adminApiBaseUrl }}</code>
                        </p>
                    </div>
                </div>
            </div>
            
            <div class="col-12">
                <div class="card shadow-sm border-0">
                    <div class="card-header border-0 bg-white py-3">
                        <div class="d-flex flex-column flex-lg-row justify-content-between align-items-start align-items-lg-center gap-2">
                            <div>
                                <h5 class="card-title mb-1">{{ __('الشبكات المسجلة') }}</h5>
                                <p class="text-muted small mb-0">{{ __('إدارة ومراجعة شبكات الواي فاي المسجلة في المنصة.') }}</p>
                            </div>
                            <form method="get" class="d-flex flex-column flex-sm-row gap-2 w-100 w-sm-auto">
                                <input type="search"
                                       name="search"
                                       value="{{ $search }}"
                                       class="form-control"
                                       placeholder="{{ __('بحث بالاسم أو العنوان') }}">
                                <button type="submit" class="btn btn-outline-primary d-flex align-items-center gap-2">
                                    <i class="bi bi-search"></i>
                                    <span>{{ __('بحث') }}</span>
                                </button>
                            </form>
                        </div>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover align-middle mb-0">
                                <thead class="table-light">
                                <tr>
                                    <th>{{ __('الاسم') }}</th>
                                    <th>{{ __('المالك') }}</th>
                                    <th>{{ __('الحالة') }}</th>
                                    <th>{{ __('عدد الخطط') }}</th>
                                    <th>{{ __('تاريخ الإنشاء') }}</th>
                                    <th class="text-end">{{ __('إدارة') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @forelse($networks as $network)
                                    <tr>
                                        <td>{{ $network->name }}</td>
                                        <td>
                                            <div class="d-flex flex-column">
                                                <strong>{{ $network->owner?->name ?? __('غير محدد') }}</strong>
                                                <small class="text-muted">{{ $network->owner?->email }}</small>
                                            </div>
                                        </td>
                                        <td>
                                            <span class="badge bg-light text-dark">{{ $network->status->label() }}</span>
                                        </td>
                                        <td>{{ number_format($network->plans_count ?? 0) }}</td>
                                        <td>{{ optional($network->created_at)->format('Y-m-d') }}</td>
                                        <td class="text-end">
                                            <a href="{{ route('wifi.edit', $network) }}" class="btn btn-sm btn-primary">
                                                <i class="bi bi-pencil-square"></i> {{ __('إدارة') }}
                                            </a>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="6" class="text-center text-muted py-4">{{ __('لا توجد شبكات مسجلة حاليًا.') }}</td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                    <div class="card-footer bg-white border-0">
                        {{ $networks->links() }}
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection