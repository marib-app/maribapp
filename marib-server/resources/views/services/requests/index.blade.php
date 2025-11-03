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
        --stat-color: #0d6efd;
        --stat-soft: rgba(13, 110, 253, 0.35);
        --stat-bg-start: rgba(13, 110, 253, 0.16);
        --stat-bg-end: rgba(13, 110, 253, 0.05);
        --stat-border: rgba(13, 110, 253, 0.2);
        border-radius: 1.2rem;
        padding: 1.35rem 1.4rem;
        background: linear-gradient(135deg, var(--stat-bg-start), var(--stat-bg-end));
        border: 1px solid var(--stat-border);
        box-shadow: 0 18px 38px rgba(15, 23, 42, 0.12);
        display: flex;
        flex-direction: column;
        gap: 1rem;
        position: relative;
        overflow: hidden;
        min-height: 100%;
    }


    .requests-stat-card::after {
        content: '';
        position: absolute;
        inset: auto 16px -40px auto;
        width: 120px;
        height: 120px;
        border-radius: 50%;
        background: rgba(255, 255, 255, 0.22);
    }
    .requests-stat-card > * {
        position: relative;
        z-index: 1;
    }
    .requests-stat-card__header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 1rem;
    }
    .requests-stat-card__icon {
        width: 48px;
        height: 48px;
        border-radius: 50%;
        background-color: rgba(255, 255, 255, 0.65);
        color: var(--stat-color);
        display: inline-flex;
        align-items: center;
        justify-content: center;
        font-size: 1.6rem;
        box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.6);
    }
    .requests-stat-card__figures {
        display: flex;
        flex-direction: column;
        align-items: flex-end;
        gap: 0.35rem;
    }

    .requests-stat-card__label {
        color: rgba(33, 37, 41, 0.75);
        font-size: 0.75rem;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        font-weight: 600;
    }
    .requests-stat-card__value {
        font-size: 2rem;
        font-weight: 700;
        color: var(--stat-color);
        line-height: 1.1;
    }
    .requests-stat-card__indicator {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 0.75rem;
        font-size: 0.95rem;
        font-weight: 500;
        color: rgba(33, 37, 41, 0.85);
    }
    .requests-stat-card__indicator-share {
        padding: 0.15rem 0.65rem;
        border-radius: 999px;
        background-color: rgba(255, 255, 255, 0.7);
        color: var(--stat-color);
        font-weight: 600;
        font-size: 0.85rem;
    }
    .requests-stat-card__progress {
        width: 100%;
        height: 6px;
        border-radius: 999px;
        background-color: rgba(255, 255, 255, 0.55);
        overflow: hidden;
    }
    .requests-stat-card__progress-bar {
        display: block;
        height: 100%;
        border-radius: inherit;
        background: linear-gradient(90deg, var(--stat-color), var(--stat-soft));
        transition: width 0.4s ease;
    }
    .requests-stat-card--warning {
        --stat-color: #d39e00;
        --stat-soft: rgba(211, 158, 0, 0.38);
        --stat-bg-start: rgba(211, 158, 0, 0.2);
        --stat-bg-end: rgba(211, 158, 0, 0.06);
        --stat-border: rgba(211, 158, 0, 0.28);
    }
    .requests-stat-card--success {
        --stat-color: #198754;
        --stat-soft: rgba(25, 135, 84, 0.35);
        --stat-bg-start: rgba(25, 135, 84, 0.18);
        --stat-bg-end: rgba(25, 135, 84, 0.06);
        --stat-border: rgba(25, 135, 84, 0.28);
    }
    .requests-stat-card--danger {
        --stat-color: #dc3545;
        --stat-soft: rgba(220, 53, 69, 0.35);
        --stat-bg-start: rgba(220, 53, 69, 0.18);
        --stat-bg-end: rgba(220, 53, 69, 0.06);
        --stat-border: rgba(220, 53, 69, 0.28);
    }
    .requests-stat-card--info {
        --stat-color: #0dcaf0;
        --stat-soft: rgba(13, 202, 240, 0.35);
        --stat-bg-start: rgba(13, 202, 240, 0.2);
        --stat-bg-end: rgba(13, 202, 240, 0.06);
        --stat-border: rgba(13, 202, 240, 0.28);
    }
    .requests-stat-card--primary {
        --stat-color: #0d6efd;
        --stat-soft: rgba(13, 110, 253, 0.35);
        --stat-bg-start: rgba(13, 110, 253, 0.16);
        --stat-bg-end: rgba(13, 110, 253, 0.05);
        --stat-border: rgba(13, 110, 253, 0.2);
    }
    @media (max-width: 576px) {
        .requests-stat-card {
            padding: 1.1rem 1.2rem;
        }
        .requests-stat-card__value {
            font-size: 1.7rem;
        }
        .requests-stat-card__icon {
            width: 42px;
            height: 42px;
            font-size: 1.4rem;
        }
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

                @php
                    $totalRequests = (int) ($stats['total'] ?? 0);
                    $share = static function (int $value) use ($totalRequests): string {
                        if ($totalRequests <= 0) {
                            return '0%';
                        }

                        $percentage = ($value / max($totalRequests, 1)) * 100;
                        $decimals = $percentage >= 10 ? 0 : 1;
                        $formatted = number_format($percentage, $decimals, '.', '');
                        $formatted = rtrim(rtrim($formatted, '0'), '.');

                        return $formatted . '%';
                    };

                    $statCards = [
                        [
                            'label' => __('Total Requests'),
                            'value' => $totalRequests,
                            'icon' => 'bi-clipboard-data',
                            'variant' => 'primary',
                        ],
                        [
                            'label' => __('Under Review'),
                            'value' => (int) ($stats['review'] ?? 0),
                            'icon' => 'bi-hourglass-split',
                            'variant' => 'warning',
                        ],
                        [
                            'label' => __('Approved'),
                            'value' => (int) ($stats['approved'] ?? 0),
                            'icon' => 'bi-check-circle',
                            'variant' => 'success',
                        ],
                        [
                            'label' => __('Rejected'),
                            'value' => (int) ($stats['rejected'] ?? 0),
                            'icon' => 'bi-x-circle',
                            'variant' => 'danger',
                        ],
                        [
                            'label' => __('Sold Out'),
                            'value' => (int) ($stats['sold_out'] ?? 0),
                            'icon' => 'bi-bag-x',
                            'variant' => 'info',
                        ],
                    ];
                @endphp

                <div class="row g-3 requests-stats-row">
                    @foreach ($statCards as $card)
                        @php
                            $progress = $totalRequests > 0
                                ? max(0, min(100, round(($card['value'] / max($totalRequests, 1)) * 100, 1)))
                                : 0;
                        @endphp
                        <div class="col-12 col-sm-6 col-xl-3">
                            <div class="requests-stat-card requests-stat-card--{{ $card['variant'] }}">
                                <div class="requests-stat-card__header">
                                    <div class="requests-stat-card__icon">
                                        <i class="bi {{ $card['icon'] }}"></i>
                                    </div>
                                    <div class="requests-stat-card__figures">
                                        <span class="requests-stat-card__label">{{ $card['label'] }}</span>
                                        <span class="requests-stat-card__value">{{ number_format($card['value']) }}</span>
                                    </div>
                                </div>
                                <div class="requests-stat-card__indicator">
                                    <span>{{ __('Requests') }}</span>
                                    <span class="requests-stat-card__indicator-share">{{ $share($card['value']) }}</span>
                                </div>
                                <div class="requests-stat-card__progress">
                                    <span class="requests-stat-card__progress-bar" style="width: {{ $progress }}%;"></span>
                                </div>
                            </div>
                        </div>
                    @endforeach
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
