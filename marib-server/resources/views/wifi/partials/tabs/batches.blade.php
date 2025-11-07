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
            <tbody data-batches-static></tbody>
        </table>
    </div>
</div>
