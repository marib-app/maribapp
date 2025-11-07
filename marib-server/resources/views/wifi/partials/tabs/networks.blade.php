<div class="tab-pane fade show active" id="wifi-networks" role="tabpanel" aria-labelledby="wifi-networks-tab" tabindex="0">
    <div class="wifi-toolbar" id="wifi-networks-toolbar">
        <div class="row g-2 align-items-center">
            <div class="col-sm-6 col-md-4">
                <div class="input-group">
                    <span class="input-group-text"><i class="bi bi-search"></i></span>
                    <input type="search" class="form-control" id="wifi-network-search"
                           placeholder="{{ __('بحث بالاسم أو العنوان') }}" data-network-search>
                </div>
            </div>
            <div class="col-sm-6 col-md-3">
                <select class="form-select" id="wifi-network-status-filter" data-network-status-filter>
                    <option value="">{{ __('جميع الحالات') }}</option>
                    <option value="active">{{ __('نشط') }}</option>
                    <option value="inactive">{{ __('متوقف مؤقتاً') }}</option>
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
               data-empty-text="{{ __('لا توجد شبكات متاحة حالياً.') }}">
            <thead class="table-light">
            <tr>
                <th data-field="name" data-sortable="true">{{ __('اسم الشبكة') }}</th>
                <th data-field="owner_name">{{ __('المالك') }}</th>
                <th data-field="status" data-formatter="MaribWifiAdminTables.formatNetworkStatus">{{ __('الحالة') }}</th>
                <th data-field="active_plans" data-sortable="true">{{ __('الخطط النشطة') }}</th>
                <th data-field="codes_summary" data-formatter="MaribWifiAdminTables.formatCodesSummary">{{ __('الأكواد') }}</th>
                <th data-field="commission" data-formatter="MaribWifiAdminTables.formatCommission">{{ __('العمولة') }}</th>
                <th data-field="updated_at" data-formatter="MaribWifiAdminTables.formatDate">{{ __('آخر تحديث') }}</th>
                <th data-field="actions" data-formatter="MaribWifiAdminTables.formatNetworkActions"
                    data-events="MaribWifiAdminTables.networkActionEvents" data-align="center">{{ __('إجراءات') }}</th>
            </tr>
            </thead>
        </table>
    </div>
</div>
