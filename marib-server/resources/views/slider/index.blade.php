@extends('layouts.main')

@section('title')
    {{ __('Slider') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first"></div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-12">

                <div class="card">
                    <div class="card-content">
                        <div class="row mt-1">
                            <div class="card-body">


                                @if(session('success'))
                                    <div class="alert alert-success">
                                        {{ session('success') }}
                                    </div>
                                @endif


                                @can('slider-create')
                                    <div class="mb-3 d-flex flex-wrap gap-2 justify-content-start">
                                        <a href="{{ route('slider.create') }}" class="btn btn-primary">
                                            {{ __('إضافة سلايدر جديد') }}
                                        </a>
                                        <button type="button" class="btn btn-outline-primary" data-bs-toggle="modal" data-bs-target="#sliderDefaultModal">
                                            {{ __('إضافة صورة افتراضية') }}
                                        </button>

                                    </div>
                                @endcan
                                <div id="toolbar" class="mb-3"></div>

                                <div class="form-group row ">
                                    <div class="col-12">
                                        <table class="table table-borderless table-striped" aria-describedby="mydesc"
                                               id="table_list" data-toggle="table"
                                               data-url="{{ route('slider.show',1) }}" data-click-to-select="true"
                                               data-side-pagination="server" data-pagination="true"
                                               data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true"
                                               data-toolbar="#toolbar" data-show-columns="true" data-show-refresh="true"
                                               data-fixed-columns="true" data-fixed-number="1" data-fixed-right-number="1"
                                               data-trim-on-search="false" data-responsive="true" data-sort-name="id"
                                               data-sort-order="desc" data-pagination-successively-size="3"
                                               data-escape="true"
                                               data-query-params="queryParams" data-id-field="id"
                                               data-show-export="true" data-export-options='{"fileName": "slider-list","ignoreColumn": ["operate"]}' data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']"
                                               data-mobile-responsive="true">
                                            <thead class="thead-dark">
                                            <tr>
                                                <th scope="col" data-field="id" data-align="center" data-sortable="true">{{ __('ID') }}</th>
                                                <th scope="col" data-field="image" data-align="center" data-sortable="false" data-formatter="imageFormatter">{{ __('Image') }}</th>
                                                <th scope="col" data-field="model_type" data-align="center" data-sortable="true" data-formatter="typeFormatter">{{ __('Type') }}</th>
                                                <th scope="col" data-field="model.name" data-sort-name="" data-align="center" data-sortable="true">{{ __('Name') }}</th>
                                                <th scope="col" data-field="interface_type" data-align="center" data-sortable="true" data-formatter="interfaceTypeFormatter">{{ __('Interface Type') }}</th>

                                                <th scope="col" data-field="status" data-align="center" data-sortable="true">{{ __('الحالة') }}</th>
                                                <th scope="col" data-field="priority" data-align="center" data-sortable="true" data-visible="false">{{ __('الأولوية') }}</th>
                                                <th scope="col" data-field="weight" data-align="center" data-sortable="true" data-visible="false">{{ __('الوزن') }}</th>
                                                <th scope="col" data-field="share_of_voice" data-align="center" data-sortable="true" data-visible="false">{{ __('حصة الظهور') }}</th>
                                                <th scope="col" data-field="impressions" data-align="center" data-sortable="true" data-formatter="sliderNumberFormatter">{{ __('الظهور') }}</th>
                                                <th scope="col" data-field="clicks" data-align="center" data-sortable="true" data-formatter="sliderNumberFormatter">{{ __('النقرات') }}</th>
                                                <th scope="col" data-field="ctr" data-align="center" data-sortable="true" data-formatter="sliderCtrFormatter">{{ __('CTR (%)') }}</th>
                                                <th scope="col" data-field="per_user_per_day_limit" data-align="center" data-sortable="true" data-formatter="sliderLimitFormatter" data-visible="false">{{ __('حد يومي') }}</th>
                                                <th scope="col" data-field="per_user_per_session_limit" data-align="center" data-sortable="true" data-formatter="sliderLimitFormatter" data-visible="false">{{ __('حد الجلسة') }}</th>

                                                <th scope="col" data-field="starts_at" data-align="center" data-sortable="true" data-visible="false">{{ __('تاريخ البدء') }}</th>
                                                <th scope="col" data-field="ends_at" data-align="center" data-sortable="true" data-visible="false">{{ __('تاريخ الانتهاء') }}</th>


                                                <th scope="col" data-field="third_party_link" data-align="center" data-sortable="true">{{ __('Third Party Link') }}</th>
                                                @can('slider-delete')
                                                    <th scope="col" data-field="operate" data-escape="false" data-align="center" data-sortable="false">{{ __('Action') }}</th>
                                                @endcan
                                            </tr>
                                            </thead>
                                        </table>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>


        <div class="row mt-3">
            <div class="col-12">
                <div class="card">
                    <div class="card-header border-bottom-0">
                        <h5 class="mb-0">{{ __('الصور الافتراضية للسلايدر') }}</h5>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped align-middle mb-0">
                                <thead>
                                <tr>
                                    <th>{{ __('نوع الواجهة') }}</th>
                                    <th>{{ __('الصورة') }}</th>
                                    <th>{{ __('الحالة') }}</th>
                                    <th>{{ __('تاريخ الإضافة') }}</th>
                                    @can('slider-delete')
                                        <th class="text-end">{{ __('إجراءات') }}</th>
                                    @endcan
                                </tr>
                                </thead>
                                <tbody>
                                @forelse($sliderDefaults as $default)
                                    <tr>
                                        <td>{{ $interfaceTypeLabels[$default->interface_type] ?? $default->interface_type }}</td>
                                        <td>
                                            @if($default->image_url)
                                                <img src="{{ $default->image_url }}" alt="{{ $default->interface_type }}" class="img-thumbnail" style="max-width: 120px;">
                                            @endif
                                        </td>
                                        <td>
                                            <span class="badge bg-success">{{ __('مفعل') }}</span>
                                        </td>
                                        <td>{{ optional($default->created_at)->format('Y-m-d H:i') }}</td>
                                        @can('slider-delete')
                                            <td class="text-end">
                                                <form action="{{ route('slider.defaults.destroy', $default) }}" method="POST" onsubmit="return confirm('{{ __('هل أنت متأكد من الحذف؟') }}');">
                                                    @csrf
                                                    @method('DELETE')
                                                    <button type="submit" class="btn btn-sm btn-outline-danger">{{ __('حذف') }}</button>
                                                </form>
                                            </td>
                                        @endcan
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="5" class="text-center text-muted">{{ __('لا توجد صور افتراضية محددة بعد.') }}</td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row mt-3">
            <div class="col-12">
                <div class="card">
                    <div class="card-header border-bottom-0">
                        <div class="d-flex flex-wrap justify-content-between align-items-end gap-3">
                            <div>
                                <h5 class="mb-1">{{ __('تقارير أداء السلايدر') }}</h5>
                                <p class="text-muted mb-0">{{ __('راقب الانطباعات، النقرات ونسبة النقر إلى الظهور عبر الفترات المختلفة.') }}</p>
                            </div>
                            <div class="d-flex flex-wrap align-items-end gap-2">
                                <div>
                                    <label for="summary_start_date" class="form-label mb-1">{{ __('بداية الفترة') }}</label>
                                    <input type="date" id="summary_start_date" class="form-control form-control-sm" value="{{ $reportDefaultStart }}">
                                </div>
                                <div>
                                    <label for="summary_end_date" class="form-label mb-1">{{ __('نهاية الفترة') }}</label>
                                    <input type="date" id="summary_end_date" class="form-control form-control-sm" value="{{ $reportDefaultEnd }}">
                                </div>
                                <div class="d-flex align-items-end gap-2">
                                    <button type="button" class="btn btn-sm btn-primary" id="summary_refresh">{{ __('تحديث التقارير') }}</button>
                                    <button type="button" class="btn btn-sm btn-outline-secondary" id="summary_reset">{{ __('إعادة تعيين') }}</button>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="row g-4">
                            <div class="col-md-6">
                                <h6 class="fw-semibold">{{ __('التجميع اليومي') }}</h6>
                                <table id="slider_daily_metrics" class="table table-striped"
                                       data-toggle="table" data-pagination="false" data-search="false"
                                       data-show-export="true" data-export-options='{"fileName": "slider-daily-metrics"}'>
                                    <thead>
                                    <tr>
                                        <th scope="col" data-field="date" data-align="center">{{ __('التاريخ') }}</th>
                                        <th scope="col" data-field="impressions" data-align="center" data-formatter="sliderNumberFormatter">{{ __('الظهور') }}</th>
                                        <th scope="col" data-field="clicks" data-align="center" data-formatter="sliderNumberFormatter">{{ __('النقرات') }}</th>
                                        <th scope="col" data-field="ctr" data-align="center" data-formatter="sliderCtrFormatter">{{ __('CTR (%)') }}</th>
                                    </tr>
                                    </thead>
                                </table>
                            </div>
                            <div class="col-md-6">
                                <h6 class="fw-semibold">{{ __('التجميع الأسبوعي') }}</h6>
                                <table id="slider_weekly_metrics" class="table table-striped"
                                       data-toggle="table" data-pagination="false" data-search="false"
                                       data-show-export="true" data-export-options='{"fileName": "slider-weekly-metrics"}'>
                                    <thead>
                                    <tr>
                                        <th scope="col" data-field="label" data-align="center">{{ __('الأسبوع') }}</th>
                                        <th scope="col" data-field="impressions" data-align="center" data-formatter="sliderNumberFormatter">{{ __('الظهور') }}</th>
                                        <th scope="col" data-field="clicks" data-align="center" data-formatter="sliderNumberFormatter">{{ __('النقرات') }}</th>
                                        <th scope="col" data-field="ctr" data-align="center" data-formatter="sliderCtrFormatter">{{ __('CTR (%)') }}</th>
                                    </tr>
                                    </thead>
                                </table>
                            </div>
                            <div class="col-md-6">
                                <h6 class="fw-semibold">{{ __('حسب الحالة') }}</h6>
                                <table id="slider_status_metrics" class="table table-striped"
                                       data-toggle="table" data-pagination="false" data-search="false"
                                       data-show-export="true" data-export-options='{"fileName": "slider-status-metrics"}'>
                                    <thead>
                                    <tr>
                                        <th scope="col" data-field="status" data-align="center" data-formatter="sliderStatusFormatter">{{ __('الحالة') }}</th>
                                        <th scope="col" data-field="impressions" data-align="center" data-formatter="sliderNumberFormatter">{{ __('الظهور') }}</th>
                                        <th scope="col" data-field="clicks" data-align="center" data-formatter="sliderNumberFormatter">{{ __('النقرات') }}</th>
                                        <th scope="col" data-field="ctr" data-align="center" data-formatter="sliderCtrFormatter">{{ __('CTR (%)') }}</th>
                                    </tr>
                                    </thead>
                                </table>
                            </div>
                            <div class="col-md-6">
                                <h6 class="fw-semibold">{{ __('حسب نوع الواجهة') }}</h6>
                                <table id="slider_interface_metrics" class="table table-striped"
                                       data-toggle="table" data-pagination="false" data-search="false"
                                       data-show-export="true" data-export-options='{"fileName": "slider-interface-metrics"}'>
                                    <thead>
                                    <tr>
                                        <th scope="col" data-field="interface_type" data-align="center" data-formatter="sliderInterfaceSummaryFormatter">{{ __('نوع الواجهة') }}</th>
                                        <th scope="col" data-field="impressions" data-align="center" data-formatter="sliderNumberFormatter">{{ __('الظهور') }}</th>
                                        <th scope="col" data-field="clicks" data-align="center" data-formatter="sliderNumberFormatter">{{ __('النقرات') }}</th>
                                        <th scope="col" data-field="ctr" data-align="center" data-formatter="sliderCtrFormatter">{{ __('CTR (%)') }}</th>
                                    </tr>
                                    </thead>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>


    </section>



    @can('slider-create')
        <div class="modal fade" id="sliderDefaultModal" tabindex="-1" aria-labelledby="sliderDefaultModalLabel" aria-hidden="true">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="sliderDefaultModalLabel">{{ __('إضافة صورة افتراضية') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <form action="{{ route('slider.defaults.store') }}" method="POST" enctype="multipart/form-data">
                        @csrf
                        <div class="modal-body">
                            <div class="mb-3">
                                <label for="default_interface_type" class="form-label">{{ __('نوع الواجهة') }}</label>
                                <select id="default_interface_type" name="interface_type" class="form-select" required>
                                    @foreach($interfaceTypeOptions as $interfaceType)
                                        <option value="{{ $interfaceType }}">{{ $interfaceTypeLabels[$interfaceType] ?? $interfaceType }}</option>
                                    @endforeach
                                </select>
                            </div>
                            <div class="mb-3">
                                <label for="default_image" class="form-label">{{ __('الصورة') }}</label>
                                <input type="file" id="default_image" name="image" class="form-control" accept="image/*" required>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">{{ __('إلغاء') }}</button>
                            <button type="submit" class="btn btn-primary">{{ __('حفظ') }}</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    @endcan



@endsection

@section('script')
<script>

    const sliderInterfaceTypeLabels = @json($interfaceTypeLabels);
    const sliderInterfaceTypeAliasMap = @json($sliderAliasMap);
    const sliderStatusLabelsMap = @json($sliderStatusLabels);
    const sliderDailyMetricsSeed = @json($dailyMetrics);
    const sliderWeeklyMetricsSeed = @json($weeklyMetrics);
    const sliderStatusMetricsSeed = @json($statusMetrics);
    const sliderInterfaceMetricsSeed = @json($interfaceMetrics);
    const sliderMetricsSummaryRoute = @json(route('slider.metrics.summary'));
    const sliderSummaryDefaultStart = @json($reportDefaultStart);
    const sliderSummaryDefaultEnd = @json($reportDefaultEnd);

    const sliderDefaultInterfaceType = @json($defaultInterfaceType);
    window.sliderDefaultInterfaceType = sliderDefaultInterfaceType;

    function typeFormatter(value, row) {
        const fallback = value || (row && row.target_type) || (row && row.model_type) || '';

        const classes = {

            'App\\Models\\Item': 'منتج',
            'App\\Models\\Category': 'فئة',
            'App\\Models\\Blog': 'صفحة',
            'App\\Models\\User': 'مستخدم',
            'App\\Models\\Service': 'خدمة'
        
        };
        
        const aliases = {
            'item': 'منتج',
            'category': 'فئة',
            'blog': 'صفحة',
            'user': 'مستخدم',
            'service': 'خدمة'
        };

        if (!fallback) {
            return '-';
        }

        if (aliases[fallback]) {
            return aliases[fallback];
        }

        return classes[fallback] || fallback;


    }

    function normalizeSliderInterfaceType(value) {
        if (typeof value !== 'string' || value.trim() === '') {
            return value;
        }

        const lower = value.trim().toLowerCase();

        if (Object.prototype.hasOwnProperty.call(sliderInterfaceTypeAliasMap, lower)) {
            return sliderInterfaceTypeAliasMap[lower];
        }

        return lower;
    }

    function interfaceTypeFormatter(value) {
        const normalizedValue = normalizeSliderInterfaceType(value);
        const lookupKey = (value && value.trim() !== '') ? normalizedValue : sliderDefaultInterfaceType;

        if (lookupKey && Object.prototype.hasOwnProperty.call(sliderInterfaceTypeLabels, lookupKey)) {
            return sliderInterfaceTypeLabels[lookupKey];
        }

        if (value && Object.prototype.hasOwnProperty.call(sliderInterfaceTypeLabels, value)) {
            return sliderInterfaceTypeLabels[value];
        }

        return value || '-';
    }

    function imageFormatter(value) {
        if (!value) return '-';

        return '<img src="' + value + '" class="img-thumbnail" width="100" height="100" />';
    }

    function sliderNumberFormatter(value) {
        const numeric = Number(value ?? 0);

        if (!Number.isFinite(numeric)) {
            return '0';
        }

        return numeric.toLocaleString('en-US');
    }

    function sliderCtrFormatter(value) {
        const numeric = Number(value ?? 0);

        if (!Number.isFinite(numeric)) {
            return '0.00%';
        }

        return numeric.toFixed(2) + '%';
    }

    function sliderLimitFormatter(value) {
        if (value === null || value === undefined || Number(value) <= 0) {
            return '-';
        }

        return sliderNumberFormatter(value);
    }

    function sliderStatusFormatter(value) {
        if (!value) {
            return '-';
        }

        if (Object.prototype.hasOwnProperty.call(sliderStatusLabelsMap, value)) {
            return sliderStatusLabelsMap[value];
        }

        const readable = value.replace(/_/g, ' ');
        return readable.charAt(0).toUpperCase() + readable.slice(1);
    }

    function sliderInterfaceSummaryFormatter(value) {
        if (!value) {
            return sliderInterfaceTypeLabels[sliderDefaultInterfaceType] || '-';
        }

        const normalized = normalizeSliderInterfaceType(value);

        if (normalized && Object.prototype.hasOwnProperty.call(sliderInterfaceTypeLabels, normalized)) {
            return sliderInterfaceTypeLabels[normalized];
        }

        if (Object.prototype.hasOwnProperty.call(sliderInterfaceTypeLabels, value)) {
            return sliderInterfaceTypeLabels[value];
        }

        return value;
    }

    function queryParams(params) {
        const interfaceFilter = $('#interface_type_filter').val();
        const startDate = $('#metrics_start_date').val();
        const endDate = $('#metrics_end_date').val();

        const nextParams = { ...params };

        if (interfaceFilter && interfaceFilter !== '') {
            nextParams.interface_type = interfaceFilter;
        }

        if (startDate) {
            nextParams.start_date = startDate;
        }

        if (endDate) {
            nextParams.end_date = endDate;
        }

        return nextParams;


    }
 

    function normalizeMetricRows(rows) {
        return (rows || []).map((row) => ({
            ...row,
            impressions: Number(row.impressions ?? 0),
            clicks: Number(row.clicks ?? 0),
            ctr: Number(row.ctr ?? 0),
        }));
    }

    function enrichStatusMetrics(rows) {
        return normalizeMetricRows(rows).map((row) => ({
            ...row,
            status: row.status || '',
        }));
    }

    function enrichInterfaceMetrics(rows) {
        return normalizeMetricRows(rows).map((row) => ({
            ...row,
            interface_type: row.interface_type || 'all',
        }));
    }





    function loadSliderSummaryTables(response) {
        $('#slider_daily_metrics').bootstrapTable('load', normalizeMetricRows(response.daily || []));
        $('#slider_weekly_metrics').bootstrapTable('load', normalizeMetricRows(response.weekly || []));
        $('#slider_status_metrics').bootstrapTable('load', enrichStatusMetrics(response.status || []));
        $('#slider_interface_metrics').bootstrapTable('load', enrichInterfaceMetrics(response.interface || []));
    }

    let sliderSummaryRequest = null;


    function fetchSliderSummary() {
        const params = {};
        const start = $('#summary_start_date').val();
        const end = $('#summary_end_date').val();

        if (start) {
            params.start_date = start;


        }

        if (end) {
            params.end_date = end;
        }

        if (sliderSummaryRequest && typeof sliderSummaryRequest.abort === 'function') {
            sliderSummaryRequest.abort();

        }

        sliderSummaryRequest = $.getJSON(sliderMetricsSummaryRoute, params)
            .done((response) => {
                loadSliderSummaryTables(response || {});
            })
            .fail((xhr) => {
                console.error('Unable to load slider metrics summary', xhr);
            })
            .always(() => {
                sliderSummaryRequest = null;
            });
    }


    function refreshTable() {
        $('#table_list').bootstrapTable('refresh');
    }


    function refreshFilter() {
        const previousInterface = $('#interface_type_filter').val() || '';
        const previousStart = $('#metrics_start_date').val() || '';
        const previousEnd = $('#metrics_end_date').val() || '';



        $('#toolbar').html(`
            <div class="row g-2 align-items-end">
                <div class="col-lg-4 col-md-12">
                    <small class="text-danger">* {{ __("To change the order, Drag the Table column Up & Down") }}</small>
                </div>
                <div class="col-md-3 col-lg-2">
                    <label for="interface_type_filter" class="form-label mb-1">{{ __('تصفية حسب القسم') }}</label>
                    <select id="interface_type_filter" class="form-select form-select-sm">
                        <option value="">{{ __('جميع الأقسام') }}</option>
                        @foreach($interfaceTypeOptions as $type)
                            <option value="{{ $type }}">{{ $interfaceTypeLabels[$type] ?? $type }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-3 col-lg-2">
                    <label for="metrics_start_date" class="form-label mb-1">{{ __('بداية الفترة') }}</label>
                    <input type="date" id="metrics_start_date" class="form-control form-control-sm" value="${previousStart}">
                </div>
                <div class="col-md-3 col-lg-2">
                    <label for="metrics_end_date" class="form-label mb-1">{{ __('نهاية الفترة') }}</label>
                    <input type="date" id="metrics_end_date" class="form-control form-control-sm" value="${previousEnd}">
                </div>
                <div class="col-md-3 col-lg-2 d-flex gap-2">
                    <button type="button" class="btn btn-sm btn-outline-primary flex-grow-1" id="metrics_filter_apply">{{ __('تطبيق الفلتر') }}</button>
                    <button type="button" class="btn btn-sm btn-outline-secondary" id="metrics_filter_reset">{{ __('إعادة تعيين') }}</button>
                </div>
            </div>
        `);

        $('#interface_type_filter').val(previousInterface);

        $('#interface_type_filter').on('change', refreshTable);
        $('#metrics_start_date, #metrics_end_date').on('change', refreshTable);
        $('#metrics_filter_apply').on('click', refreshTable);
        $('#metrics_filter_reset').on('click', function () {
            $('#interface_type_filter').val('');
            $('#metrics_start_date').val('');
            $('#metrics_end_date').val('');
            refreshTable();
        });
    }

    $(document).ready(function () {



        $(document).on('click', '.refresh', refreshFilter);
        refreshFilter();

        $('#slider_daily_metrics').bootstrapTable({ data: normalizeMetricRows(sliderDailyMetricsSeed) });
        $('#slider_weekly_metrics').bootstrapTable({ data: normalizeMetricRows(sliderWeeklyMetricsSeed) });
        $('#slider_status_metrics').bootstrapTable({ data: enrichStatusMetrics(sliderStatusMetricsSeed) });
        $('#slider_interface_metrics').bootstrapTable({ data: enrichInterfaceMetrics(sliderInterfaceMetricsSeed) });



        $('#summary_refresh').on('click', function (event) {
            event.preventDefault();
            fetchSliderSummary();


        });

        $('#summary_reset').on('click', function (event) {
            event.preventDefault();
            $('#summary_start_date').val(sliderSummaryDefaultStart);
            $('#summary_end_date').val(sliderSummaryDefaultEnd);
            fetchSliderSummary();
        });

        // استدعاء الدالة عند تحميل الصفحة
        $('#summary_start_date, #summary_end_date').on('change', fetchSliderSummary);
    });
</script>
@endsection

