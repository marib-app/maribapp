@extends('layouts.main')

@section('title')
    {{ __('طلبات الخدمات') }}
@endsection

@section('page-style')
<style>
    .card-body { overflow-x: hidden; }
    .table-responsive { overflow-x: auto; margin-bottom: 1rem; }
    #filters select,
    #filters input { height: 45px; font-size: 1.05rem; padding: 8px 12px; }
    #filters label { font-size: 1.05rem; font-weight: 600; margin-bottom: 8px; }
    #filters .input-group > .btn { height: 45px; }
    #filters .input-group .btn + .btn { border-radius: 0 .5rem .5rem 0; }
    #table_list { width: 100%; }


    .requests-stats-row { margin-bottom: 1.5rem; }
    .requests-stat-card {
        border: 1px solid #e9ecef;
        border-radius: 1rem;
        padding: 1.25rem 1.5rem;
        background: linear-gradient(135deg, rgba(13, 110, 253, 0.08), rgba(13, 110, 253, 0.02));
        box-shadow: 0 12px 32px rgba(15, 23, 42, 0.08);
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
        min-height: 100%;
    }
    .requests-stat-card__label {
        color: #6c757d;
        font-size: 0.8rem;
        letter-spacing: 0.05em;
        text-transform: uppercase;
        font-weight: 600;
    }
    .requests-stat-card__value {
        font-size: 1.8rem;
        font-weight: 700;
        color: #0d6efd;
        line-height: 1.1;
    }
    .requests-stat-card__indicator {
        font-size: 0.9rem;
        font-weight: 500;
        color: #212529;
    }


    .btn-with-label {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 0.4rem;
        padding: 0.35rem 0.75rem;
        line-height: 1.2;
        width: auto;
        height: auto;
        white-space: nowrap;
    }
    .btn-with-label.btn-icon {
        width: auto;
        height: auto;
    }
    .btn-with-label .btn-label {
        display: inline-block;
    }

</style>
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
        <div class="card">
            <div class="card-body">

                {{-- فلاتر --}}
                <div class="row">
                    <div class="col-12">
                        <div id="filters" class="row g-3 align-items-end mb-4">
                            <div class="col-sm-6 col-lg-3">
                                <label for="filter" class="d-block">{{__("Status")}}</label>
                                <select class="form-control bootstrap-table-filter-control-status" id="filter">
                                    <option value="">{{__("All")}}</option>
                                    <option value="review">{{__("Under Review")}}</option>
                                    <option value="approved">{{__("Approved")}}</option>
                                    <option value="rejected">{{__("Rejected")}}</option>
                                    <option value="sold out">{{__("Sold Out")}}</option>
                                </select>
                            </div>
                            <div class="col-sm-6 col-lg-3">
                                <label class="d-block">{{__("Category")}}</label>
                                @if($selectedCategory)
                                    <div class="form-control-plaintext fw-semibold">{{ $selectedCategory->name }}</div>
                                @else
                                    <div class="form-control-plaintext text-muted">{{__("All Categories")}}</div>
                                @endif
                            </div>

                            <div class="col-12 col-lg-6">
                                <label for="request_number" class="d-block">{{ __('Search by Transaction Number') }}</label>
                                <div class="input-group">
                                    <input type="text" class="form-control" id="request_number" placeholder="{{ __('Enter transaction number') }}" autocomplete="off">
                                    <button class="btn btn-outline-primary" type="button" id="requestNumberApply">{{ __('Search') }}</button>
                                    <button class="btn btn-outline-secondary" type="button" id="requestNumberReset">{{ __('Reset') }}</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {{-- نظرة عامة سريعة --}}
                <div class="row g-3 requests-stats-row">
                    <div class="col-sm-6 col-xl-3">
                        <div class="requests-stat-card">
                            <span class="requests-stat-card__label">{{ __('Total Requests') }}</span>
                            <span class="requests-stat-card__value">{{ number_format($stats['total'] ?? 0) }}</span>
                            <span class="requests-stat-card__indicator text-muted">{{ __('Requests') }}</span>
                        </div>
                    </div>
                    <div class="col-sm-6 col-xl-3">
                        <div class="requests-stat-card">
                            <span class="requests-stat-card__label">{{ __('Under Review') }}</span>
                            <span class="requests-stat-card__value text-warning">{{ number_format($stats['review'] ?? 0) }}</span>
                            <span class="requests-stat-card__indicator">{{ __('Requests') }}</span>
                        </div>
                    </div>
                    <div class="col-sm-6 col-xl-3">
                        <div class="requests-stat-card">
                            <span class="requests-stat-card__label">{{ __('Approved') }}</span>
                            <span class="requests-stat-card__value text-success">{{ number_format($stats['approved'] ?? 0) }}</span>
                            <span class="requests-stat-card__indicator">{{ __('Requests') }}</span>
                        </div>
                    </div>
                    <div class="col-sm-6 col-xl-3">
                        <div class="requests-stat-card">
                            <span class="requests-stat-card__label">{{ __('Rejected') }}</span>
                            <span class="requests-stat-card__value text-danger">{{ number_format($stats['rejected'] ?? 0) }}</span>
                            <span class="requests-stat-card__indicator">{{ __('Requests') }}</span>
                        </div>
                    </div>
                    <div class="col-sm-6 col-xl-3">
                        <div class="requests-stat-card">
                            <span class="requests-stat-card__label">{{ __('Sold Out') }}</span>
                            <span class="requests-stat-card__value text-info">{{ number_format($stats['sold_out'] ?? 0) }}</span>
                            <span class="requests-stat-card__indicator">{{ __('Requests') }}</span>

                        </div>
                    </div>
                </div>

                {{-- الجدول --}}
                <div class="row">
                    <div class="table-responsive">
                        <table
                           class="table-borderless table-striped"
                           aria-describedby="mydesc"
                           id="table_list"
                           data-toggle="table"
                           data-url="{{ route('service.requests.datatable') }}"
                           data-click-to-select="true"
                           data-side-pagination="server"
                           data-pagination="true"
                           data-page-list="[5, 10, 20, 50, 100, 200]"
                           data-search="true"
                           data-show-columns="true"
                           data-show-refresh="true"
                           data-trim-on-search="false"
                           data-escape="true"
                           data-responsive="true"
                           data-sort-name="id"
                           data-sort-order="desc"
                           data-pagination-successively-size="3"
                           data-table="items"
                           data-status-column="deleted_at"
                           data-show-export="true"
                           data-export-options='{"fileName": "service-requests-list","ignoreColumn": ["operate"]}'
                           data-export-types='["pdf","json","xml","csv","txt","sql","doc","excel"]'
                           data-mobile-responsive="true"
                           data-filter-control="true"
                           data-filter-control-container="#filters"
                           data-toolbar="#filters"
                           data-query-params="queryParams">
                            <thead class="thead-dark">
                            <tr>
                                <th data-field="request_number" data-sortable="true" data-sort-name="request_number" data-formatter="requestNumberFormatter">{{ __('Transaction Identifier') }}</th>
                                <th data-field="id" data-sortable="true" data-visible="false">{{ __('ID') }}</th>
                                
                                <th data-field="name" data-sortable="true">{{ __('Name') }}</th>

                                <th data-field="custom_fields" data-sortable="false" data-escape="false" data-formatter="customFieldsFormatter" data-events="fieldsEvents">{{ __('الحقول المُعبأة') }}</th>

                                <th data-field="submitted_at" data-sortable="true" data-sort-name="created_at" data-formatter="submissionDateFormatter">{{ __('Submitted At') }}</th>
                                <th data-field="category.name" data-sortable="true" data-visible="false" data-formatter="serviceTypeFormatter">{{ __('نوع الخدمة') }}</th>
                                <th data-field="description" data-align="center" data-sortable="true" data-visible="false" data-formatter="descriptionFormatter">{{ __('Description') }}</th>
                                <th data-field="user.name" data-sort-name="user_name" data-sortable="true" data-visible="false">{{ __('User') }}</th>
                                <th data-field="status" data-sortable="true" data-filter-control="select" data-escape="false" data-visible="false" data-formatter="itemStatusFormatter">{{ __('Status') }}</th>
                                @can('service-requests-update')
                                    <th data-field="active_status" data-sortable="true" data-sort-name="deleted_at" data-escape="false" data-formatter="statusSwitchFormatter">{{ __('Active') }}</th>
                                @endcan

                                <th data-field="rejected_reason" data-sortable="true" data-visible="false">{{ __('Rejected Reason') }}</th>

                                {{-- أخفي تواريخ/معرّفات إضافية فقط للبحث --}}
                                <th data-field="created_at" data-sortable="true" data-visible="false">{{ __('Created At') }}</th>
                                <th data-field="updated_at" data-sortable="true" data-visible="false">{{ __('Updated At') }}</th>
                                <th data-field="user_id" data-sortable="true" data-visible="false">{{ __('User ID') }}</th>
                                <th data-field="category_id" data-sortable="true" data-visible="false">{{ __('Category ID') }}</th>

                                @canany(['service-requests-list','service-requests-update'])
                                    <th data-field="operate" data-align="center" data-sortable="false" data-events="itemEvents" data-escape="false">{{ __('Action') }}</th>
                                @endcanany
                            </tr>
                            </thead>
                        </table>
                    </div>
                </div>

            </div>
        </div>

        {{-- مودال عرض الحقول المعبأة --}}
        <div id="editModal" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="myModalLabel1" aria-hidden="true">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="myModalLabel1">{{ __('Service Request Details') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <div class="modal-body">
                        <div class="center" id="custom_fields"></div>
                    </div>
                </div>
            </div>
        </div>

        {{-- مودال تغيير الحالة --}}
        <div id="editStatusModal" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="myModalLabel1" aria-hidden="true">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="myModalLabel1">{{ __('Status') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <div class="modal-body">
                        <form class="edit-form" action="" method="POST" data-success-function="updateApprovalSuccess">
                            @csrf
                            <div class="row">
                                <div class="col-md-12">
                                    <select name="status" class="form-select" id="status" aria-label="status">
                                        <option value="review">{{__("Under Review")}}</option>
                                        <option value="approved">{{__("Approve")}}</option>
                                        <option value="rejected">{{__("Reject")}}</option>
                                    </select>
                                </div>
                            </div>
                            <div id="rejected_reason_container" class="col-md-12" style="display:none;">
                                <label for="rejected_reason" class="mandatory form-label">{{ __('Reason') }}</label>
                                <textarea name="rejected_reason" id="rejected_reason" class="form-control" placeholder="{{ __('Reason') }}"></textarea>
                            </div>
                            <input type="submit" value="{{__("Save")}}" class="btn btn-primary mt-3">
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection

@section('script')
<script>
    function updateApprovalSuccess() { $('#editStatusModal').modal('hide'); }
    const CATEGORY_ID = @json($selectedCategoryId);

    // اسم الفئة كبادج
    function serviceTypeFormatter(value, row) {
        if (row.category && row.category.name) {
            return '<span class="badge bg-light-primary">' + row.category.name + '</span>';
        }
        return '<span class="badge bg-light-secondary">-</span>';
    }


    function requestNumberFormatter(value, row) {
        var reference = value || (row && row.id ? ('#' + row.id) : '-');
        return '<span class="badge bg-primary text-white fw-semibold px-3 py-2">' + escapeHtml(reference) + '</span>';
    }

    // زر "عرض الحقول" + عدّاد
    function customFieldsFormatter(value, row) {
        var count = Array.isArray(row.custom_fields) ? row.custom_fields.length : 0;
        return '<button class="btn btn-sm btn-outline-secondary view-fields">'+
                   '{{ __("View") }}'+
               '</button> ' +
               '<span class="badge bg-light text-dark ms-1">'+ count +'</span>';
    }


    function submissionDateFormatter(value) {
        if (!value) {
            return '<span class="text-muted">-</span>';
        }
        return '<span class="text-nowrap">' + escapeHtml(value) + '</span>';
    }

    // بناء جدول الحقول داخل المودال
    function renderCustomFieldsTable(fields) {
        if (!Array.isArray(fields) || !fields.length) {
            return '<div class="text-muted">{{ __("No custom fields filled") }}</div>';
        }
        var html = '<div class="table-responsive"><table class="table table-sm table-bordered mb-0"><thead><tr>'+
                   '<th style="width:30%">{{ __("Field") }}</th><th>{{ __("Value") }}</th></tr></thead><tbody>';

        fields.forEach(function(f) {
            var label = f.label || f.name || f.key || '-';
            var val   = '';
            if (Array.isArray(f.values) && f.values.length) {
                val = f.values.join(', ');
            } else if (typeof f.value === 'object' && f.value !== null) {
                try { val = Object.values(f.value).join(', '); } catch(e) { val = JSON.stringify(f.value); }
            } else {
                val = (f.value !== undefined && f.value !== null) ? String(f.value) : (f.text || f.display || '-');
            }
            html += '<tr><td><strong>'+ escapeHtml(label) +'</strong></td><td>'+ escapeHtml(val) +'</td></tr>';
        });

        html += '</tbody></table></div>';
        return html;
    }

    // أحداث عمود الحقول
    window.fieldsEvents = {
        'click .view-fields': function (e, value, row, index) {
            var html = renderCustomFieldsTable(row.custom_fields || row.attributes || []);
            $('#custom_fields').html(html);
            $('#editModal').modal('show');
        }
    };

    // تمرير الفلاتر للسيرفر
    function queryParams(params) {
        const query = {

            status_filter: $('#filter').val(),
            offset: params.offset,
            limit: params.limit,
            search: params.search,
            sort: params.sort,
            order: params.order,
            filter: params.filter
        };

        const requestNumberValue = $('#request_number').val();
        query.request_number = requestNumberValue ? requestNumberValue.trim() : '';

        if (CATEGORY_ID !== null && CATEGORY_ID !== undefined && CATEGORY_ID !== '') {
            query.category_id = CATEGORY_ID;
        }

        return query;


    }

    // أدوات مساعدة
    function escapeHtml(s) {
        if (s === null || s === undefined) return '';
        return String(s).replace(/[&<>"'`=\/]/g, function (c) {
            return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;','/':'&#x2F;','`':'&#x60;','=':'&#x3D;'}[c];
        });
    }

    $(document).ready(function() {

        const $table = $('#table_list');
        const $requestNumber = $('#request_number');

        function refreshTableToFirstPage() {
            const options = $table.bootstrapTable('getOptions');
            options.pageNumber = 1;
            $table.bootstrapTable('refresh');
        }


        // تحديث الجدول عند تغيير الفلاتر
        $('#filter').on('change', function() {
            refreshTableToFirstPage();
        });

        $('#requestNumberApply').on('click', function () {
            refreshTableToFirstPage();
        });

        $('#requestNumberReset').on('click', function () {
            $requestNumber.val('');
            refreshTableToFirstPage();
        });

        $requestNumber.on('keypress', function (event) {
            if (event.which === 13) {
                event.preventDefault();
                refreshTableToFirstPage();
            }
        });

        // إظهار/إخفاء سبب الرفض
        $('#status').on('change', function() {
            $('#rejected_reason_container').toggle($(this).val() === 'rejected');
        });
    });
</script>
@endsection
