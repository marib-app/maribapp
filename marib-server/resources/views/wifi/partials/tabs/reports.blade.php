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
                <input type="number" min="1" class="form-control" placeholder="{{ __('معرف الشبكة') }}"
                       data-report-network-filter>
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
                <th data-field="actions" data-formatter="MaribWifiAdminTables.formatReportActions"
                    data-events="MaribWifiAdminTables.reportActionEvents" data-align="center">{{ __('إجراءات') }}</th>
            </tr>
            </thead>
        </table>
    </div>
</div>
