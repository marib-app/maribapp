@extends('layouts.main')

@section('title')
    {{ __('إدارة شبكات الواي فاي') }}
@endsection

@section('css')
    @vite(['resources/js/wifi/index.scss'])
@endsection

@section('js')
    @vite(['resources/js/wifi/index.js'])
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
                        <li class="breadcrumb-item active" aria-current="page">{{ __('إدارة الواي فاي') }}</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section wifi-admin" data-wifi-admin-root data-base-url="{{ $adminApiBaseUrl }}" data-owner-base-url="{{ url('/api/wifi/owner') }}">
        <div class="row g-3 mb-3">
            <div class="col-12">
                @if (session('status'))
                    <div class="alert alert-success shadow-sm border-0" role="alert">
                        {{ session('status') }}
                    </div>
                @endif
            </div>

            <div class="col-xl-3 col-lg-6 col-md-6">
                <div class="wifi-stat-card">
                    <div class="wifi-stat-card__header">
                        <div class="wifi-stat-card__icon text-primary bg-primary-subtle">
                            <i class="bi bi-wifi"></i>
                        </div>
                        <span class="badge bg-primary text-white">{{ __('الشبكات') }}</span>
                    </div>
                    <div class="wifi-stat-card__content">
                        <span class="wifi-stat-card__value">{{ number_format($stats['networks']['total']) }}</span>
                        <p class="wifi-stat-card__subtitle">{{ __('نشط: :active | موقوف: :inactive | معلّق: :suspended', [
                            'active' => number_format($stats['networks']['active']),
                            'inactive' => number_format($stats['networks']['inactive']),
                            'suspended' => number_format($stats['networks']['suspended'])
                        ]) }}</p>
                    </div>
                </div>
            </div>

            <div class="col-xl-3 col-lg-6 col-md-6">
                <div class="wifi-stat-card">
                    <div class="wifi-stat-card__header">
                        <div class="wifi-stat-card__icon text-success bg-success-subtle">
                            <i class="bi bi-list-check"></i>
                        </div>
                        <span class="badge bg-success text-white">{{ __('الخطط') }}</span>
                    </div>
                    <div class="wifi-stat-card__content">
                        <span class="wifi-stat-card__value">{{ number_format($stats['plans']['total']) }}</span>
                        <p class="wifi-stat-card__subtitle">{{ __('نشطة: :active | مرفوعة: :uploaded | مؤرشفة: :archived', [
                            'active' => number_format($stats['plans']['active']),
                            'uploaded' => number_format($stats['plans']['uploaded']),
                            'archived' => number_format($stats['plans']['archived'])
                        ]) }}</p>
                    </div>
                </div>
            </div>

            <div class="col-xl-3 col-lg-6 col-md-6">
                <div class="wifi-stat-card">
                    <div class="wifi-stat-card__header">
                        <div class="wifi-stat-card__icon text-warning bg-warning-subtle">
                            <i class="bi bi-box-seam"></i>
                        </div>
                        <span class="badge bg-warning text-dark">{{ __('دفعات الأكواد') }}</span>
                    </div>
                    <div class="wifi-stat-card__content">
                        <span class="wifi-stat-card__value">{{ number_format($stats['batches']['total']) }}</span>
                        <p class="wifi-stat-card__subtitle">{{ __('قيد المراجعة: :pending | مفعّلة: :active', [


                            'pending' => number_format($stats['batches']['pending']),
                            'active' => number_format($stats['batches']['active'])
                        ]) }}</p>
                    </div>
                </div>
            </div>

            <div class="col-xl-3 col-lg-6 col-md-6">
                <div class="wifi-stat-card">
                    <div class="wifi-stat-card__header">
                        <div class="wifi-stat-card__icon text-info bg-info-subtle">
                            <i class="bi bi-key"></i>
                        </div>
                        <span class="badge bg-info text-dark">{{ __('الأكواد') }}</span>
                    </div>
                    <div class="wifi-stat-card__content">
                        <span class="wifi-stat-card__value">{{ number_format($stats['codes']['total']) }}</span>
                        <p class="wifi-stat-card__subtitle">{{ __('متاحة: :available | مباعة: :sold', [


                            'available' => number_format($stats['codes']['available']),
                            'sold' => number_format($stats['codes']['sold'])
                        ]) }}</p>
                    </div>
                </div>
            </div>

        </div>

        @if (!empty($alertsConfig))
            <div class="alert alert-info border-0 shadow-sm mb-3" role="alert">
                <div class="d-flex flex-column gap-1">
                    <h6 class="fw-semibold mb-1">{{ __('إرشادات التنبيهات') }}</h6>
                    @foreach($alertsConfig as $key => $config)
                        <div class="d-flex flex-wrap align-items-center gap-2">
                            <span class="badge bg-light text-dark">{{ $key }}</span>
                            <span class="small text-muted">{{ data_get($config, 'description', __('لم يتم توفير وصف.')) }}</span>
                        </div>
                    @endforeach
                </div>
            </div>
        @endif

        <div class="card shadow-sm border-0">
            <div class="card-header bg-white border-0 pb-0">
                <ul class="nav nav-pills wifi-tabs" id="wifiAdminTabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active" id="wifi-networks-tab" data-bs-toggle="pill" data-bs-target="#wifi-networks" type="button" role="tab" aria-controls="wifi-networks" aria-selected="true">
                            <i class="bi bi-diagram-3"></i> {{ __('الشبكات الفعّالة') }}
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="wifi-requests-tab" data-bs-toggle="pill" data-bs-target="#wifi-requests" type="button" role="tab" aria-controls="wifi-requests" aria-selected="false">
                            <i class="bi bi-inbox"></i> {{ __('طلبات الإضافة') }}
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="wifi-reports-tab" data-bs-toggle="pill" data-bs-target="#wifi-reports" type="button" role="tab" aria-controls="wifi-reports" aria-selected="false">
                            <i class="bi bi-flag"></i> {{ __('البلاغات') }}
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="wifi-batches-tab" data-bs-toggle="pill" data-bs-target="#wifi-batches" type="button" role="tab" aria-controls="wifi-batches" aria-selected="false">
                            <i class="bi bi-stack"></i> {{ __('دفعات الأكواد') }}
                        </button>
                    </li>
                </ul>
            </div>
            <div class="card-body">
                <div class="tab-content" id="wifiAdminTabsContent">
                    <div class="tab-pane fade show active" id="wifi-networks" role="tabpanel" aria-labelledby="wifi-networks-tab" tabindex="0">
                        <div class="wifi-toolbar" id="wifi-networks-toolbar">
                            <div class="row g-2 align-items-center">
                                <div class="col-sm-6 col-md-4">
                                    <div class="input-group">
                                        <span class="input-group-text"><i class="bi bi-search"></i></span>
                                        <input type="search" class="form-control" id="wifi-network-search" placeholder="{{ __('بحث بالاسم أو العنوان') }}" data-network-search>
                                    </div>
                                </div>
                                <div class="col-sm-6 col-md-3">
                                    <select class="form-select" id="wifi-network-status-filter" data-network-status-filter>
                                        <option value="">{{ __('جميع الحالات') }}</option>
                                        <option value="active">{{ __('نشط') }}</option>
                                        <option value="inactive">{{ __('متوقف مؤقتًا') }}</option>
                                        <option value="suspended">{{ __('معلّق') }}</option>
                                    </select>
                                </div>
                                <div class="col-sm-12 col-md-5 text-end">
                                    <div class="btn-group" role="group">
                                        <button type="button" class="btn btn-outline-secondary" data-action="refresh-networks">
                                            <i class="bi bi-arrow-repeat"></i> {{ __('تحديث القائمة') }}
                                        </button>
                                        <a href="{{ route('wifi.create') }}" class="btn btn-primary">
                                            <i class="bi bi-upload"></i> {{ __('رفع دفعة جديدة') }}
                                        </a>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="table-responsive">
                            <table id="wifi-networks-table" class="table table-hover align-middle"
                                   data-toggle="table"
                                   data-toolbar="#wifi-networks-toolbar"
                                   data-pagination="true"
                                   data-page-list="[10, 20, 50]"
                                   data-side-pagination="server"
                                   data-page-size="10"
                                   data-locale="{{ app()->getLocale() }}"
                                   data-search="false"
                                   data-show-refresh="false"
                                   data-mobile-responsive="true"
                                   data-show-columns="true"
                                   data-ajax="MaribWifiAdminTables.fetchNetworks"
                                   data-query-params="MaribWifiAdminTables.networkQueryParams"
                                   data-response-handler="MaribWifiAdminTables.transformNetworkResponse"
                                   data-empty-text="{{ __('لا توجد شبكات متاحة حاليًا.') }}">
                                <thead class="table-light">
                                <tr>
                                    <th data-field="name" data-sortable="true">{{ __('اسم الشبكة') }}</th>
                                    <th data-field="owner_name">{{ __('المالك') }}</th>
                                    <th data-field="status" data-formatter="MaribWifiAdminTables.formatNetworkStatus">{{ __('الحالة') }}</th>
                                    <th data-field="active_plans" data-sortable="true">{{ __('الخطط النشطة') }}</th>
                                    <th data-field="codes_summary" data-formatter="MaribWifiAdminTables.formatCodesSummary">{{ __('الأكواد') }}</th>
                                    <th data-field="commission" data-formatter="MaribWifiAdminTables.formatCommission">{{ __('العمولة') }}</th>
                                    <th data-field="updated_at" data-formatter="MaribWifiAdminTables.formatDate">{{ __('آخر تحديث') }}</th>
                                    <th data-field="actions" data-formatter="MaribWifiAdminTables.formatNetworkActions" data-events="MaribWifiAdminTables.networkActionEvents" data-align="center">{{ __('الإجراءات') }}</th>
                                </tr>
                                </thead>
                            </table>
                        </div>
                    </div>

                    <div class="tab-pane fade" id="wifi-requests" role="tabpanel" aria-labelledby="wifi-requests-tab" tabindex="0">
                        <div class="wifi-toolbar mb-3" id="wifi-requests-toolbar">
                            <div class="row g-2 align-items-center">
                                <div class="col-sm-6 col-md-4">
                                    <div class="input-group">
                                        <span class="input-group-text"><i class="bi bi-search"></i></span>
                                        <input type="search" class="form-control" placeholder="{{ __('بحث بالوسم أو الشبكة') }}" data-request-search>
                                    </div>
                                </div>
                                <div class="col-sm-6 col-md-3">
                                    <select class="form-select" data-request-status-filter>
                                        <option value="">{{ __('كل الطلبات') }}</option>
                                        <option value="uploaded">{{ __('مرفوعة') }}</option>
                                        <option value="validated">{{ __('قيد المراجعة') }}</option>
                                    </select>
                                </div>
                                <div class="col-sm-12 col-md-5 text-end">
                                    <button type="button" class="btn btn-outline-secondary" data-action="refresh-requests">
                                        <i class="bi bi-arrow-repeat"></i> {{ __('تحديث') }}
                                    </button>
                                </div>
                            </div>
                        </div>
                        
                        
                        <div class="table-responsive">
                            <table id="wifi-requests-table" class="table table-striped table-hover align-middle"
                                   data-toggle="table"
                                   data-toolbar="#wifi-requests-toolbar"
                                   data-search="true"
                                   data-pagination="true"
                                   data-page-size="10"
                                   data-mobile-responsive="true"
                                   data-locale="{{ app()->getLocale() }}"
                                   data-empty-text="{{ __('لا توجد طلبات حالية من المالكين.') }}">
                                   
                                   
                                   <thead class="table-light">
                                <tr>
                                    <th data-field="plan">{{ __('الخطة') }}</th>
                                    <th data-field="network">{{ __('الشبكة') }}</th>
                                    <th data-field="label">{{ __('الوسم') }}</th>
                                    <th data-field="total_codes" data-align="center">{{ __('الإجمالي') }}</th>
                                    <th data-field="created_at" data-formatter="MaribWifiAdminTables.formatDate">{{ __('تاريخ الرفع') }}</th>
                                    <th data-field="actions" data-align="center">{{ __('الإجراءات') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @foreach($pendingRequests as $requestBatch)
                                    <tr>
                                        <td>{{ $requestBatch->plan?->name ?? '—' }}</td>
                                        <td>{{ $requestBatch->plan?->network?->name ?? '—' }}</td>
                                        <td>{{ $requestBatch->label }}</td>
                                        <td data-value="{{ (int) ($requestBatch->total_codes ?? 0) }}">{{ number_format($requestBatch->total_codes ?? 0) }}</td>
                                        <td>{{ optional($requestBatch->created_at)->format('Y-m-d H:i') }}</td>
                                        <td>
                                            <div class="d-flex justify-content-center gap-2">
                                                <form method="post" action="{{ route('wifi.owner-requests.approve', $requestBatch) }}" class="d-inline-flex align-items-center gap-1" data-request-approve>


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
                                @endforeach

                                </tbody>
                            </table>
                        </div>
                    </div>
                    <div class="tab-pane fade" id="wifi-reports" role="tabpanel" aria-labelledby="wifi-reports-tab" tabindex="0">
                        <div class="wifi-toolbar" id="wifi-reports-toolbar">
                            <div class="row g-2 align-items-center">
                                <div class="col-sm-6 col-md-4">
                                    <select class="form-select" data-report-status-filter>
                                        <option value="">{{ __('كل البلاغات') }}</option>
                                        <option value="open">{{ __('مفتوح') }}</option>
                                        <option value="investigating">{{ __('قيد المتابعة') }}</option>
                                        <option value="resolved">{{ __('تم الحل') }}</option>
                                        <option value="dismissed">{{ __('مرفوض') }}</option>
                                    </select>
                                </div>
                                <div class="col-sm-6 col-md-3">
                                    <input type="number" min="1" class="form-control" placeholder="{{ __('معرف الشبكة') }}" data-report-network-filter>
                                </div>
                                <div class="col-sm-12 col-md-5 text-end">
                                    <button type="button" class="btn btn-outline-secondary" data-action="refresh-reports">
                                        <i class="bi bi-arrow-repeat"></i> {{ __('تحديث القائمة') }}
                                    </button>
                                </div>
                            </div>
                        </div>
                        <div class="table-responsive">
                            <table id="wifi-reports-table" class="table table-hover align-middle"
                                   data-toggle="table"
                                   data-toolbar="#wifi-reports-toolbar"
                                   data-pagination="true"
                                   data-page-size="10"
                                   data-side-pagination="server"
                                   data-locale="{{ app()->getLocale() }}"
                                   data-search="false"
                                   data-ajax="MaribWifiAdminTables.fetchReports"
                                   data-query-params="MaribWifiAdminTables.reportQueryParams"
                                   data-response-handler="MaribWifiAdminTables.transformReportResponse"
                                   data-empty-text="{{ __('لا توجد بلاغات مسجلة.') }}">
                                <thead class="table-light">
                                <tr>
                                    <th data-field="id" data-sortable="true">{{ __('الرقم') }}</th>
                                    <th data-field="network_name">{{ __('الشبكة') }}</th>
                                    <th data-field="title">{{ __('عنوان البلاغ') }}</th>
                                    <th data-field="status" data-formatter="MaribWifiAdminTables.formatReportStatus">{{ __('الحالة') }}</th>
                                    <th data-field="created_at" data-formatter="MaribWifiAdminTables.formatDate">{{ __('تاريخ البلاغ') }}</th>
                                    <th data-field="actions" data-formatter="MaribWifiAdminTables.formatReportActions" data-events="MaribWifiAdminTables.reportActionEvents" data-align="center">{{ __('إجراءات') }}</th>
                                </tr>
                                </thead>
                            </table>
                        </div>
                    </div>
                    <div class="tab-pane fade" id="wifi-batches" role="tabpanel" aria-labelledby="wifi-batches-tab" tabindex="0">
                        <div class="wifi-toolbar mb-3" id="wifi-batches-toolbar">
                            <div class="row g-2 align-items-center">
                                <div class="col-sm-6 col-md-4">
                                    <div class="input-group">
                                        <span class="input-group-text"><i class="bi bi-search"></i></span>
                                        <input type="search" class="form-control" placeholder="{{ __('بحث عن دفعة') }}" data-batch-search>
                                    </div>
                                </div>
                                <div class="col-sm-6 col-md-3">
                                    <select class="form-select" data-batch-status-filter-main>
                                        <option value="">{{ __('جميع الحالات') }}</option>
                                        <option value="uploaded">{{ __('مرفوع') }}</option>
                                        <option value="validated">{{ __('قيد المراجعة') }}</option>
                                        <option value="active">{{ __('مفعل') }}</option>
                                        <option value="archived">{{ __('مؤرشف') }}</option>
                                    </select>
                                </div>
                                <div class="col-sm-12 col-md-5 text-end">
                                    <a href="{{ route('wifi.create') }}" class="btn btn-primary">
                                        <i class="bi bi-upload"></i> {{ __('إضافة دفعة جديدة') }}
                                    </a>
                                </div>
                            </div>

                        </div>

                        <div class="table-responsive">
                            <table id="wifi-batches-table" class="table table-striped align-middle"
                                   data-toggle="table"
                                   data-toolbar="#wifi-batches-toolbar"
                                   data-search="true"
                                   data-pagination="true"
                                   data-page-size="10"
                                   data-mobile-responsive="true"
                                   data-locale="{{ app()->getLocale() }}"
                                   data-empty-text="{{ __('لا توجد دفعات مسجلة.') }}">
                                <thead class="table-light">
                                <tr>
                                    <th data-field="network">{{ __('الشبكة') }}</th>
                                    <th data-field="plan">{{ __('الخطة') }}</th>
                                    <th data-field="label">{{ __('الوسم') }}</th>
                                    <th data-field="status" data-formatter="MaribWifiAdminTables.formatBatchStatus">{{ __('الحالة') }}</th>
                                    <th data-field="available_codes">{{ __('متاح') }}</th>
                                    <th data-field="total_codes">{{ __('الإجمالي') }}</th>
                                    <th data-field="created_at" data-formatter="MaribWifiAdminTables.formatDate">{{ __('تاريخ الرفع') }}</th>
                                </tr>
                                </thead>
                                <tbody data-batches-static>

                                </tbody>
                            </table>
                        </div>
                    </div>

                </div>
            </div>
        </div>
        @include('wifi.partials.network-modals')


    </section>
@endsection