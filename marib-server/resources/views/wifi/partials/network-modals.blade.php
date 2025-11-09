@php
    use App\Enums\Wifi\WifiNetworkStatus;
    use App\Enums\Wifi\WifiReportStatus;
    use App\Enums\Wifi\WifiCodeBatchStatus;

    $networkStatusOptions = [
        WifiNetworkStatus::ACTIVE->value => __('نشط'),
        WifiNetworkStatus::INACTIVE->value => __('متوقف مؤقتًا'),
        WifiNetworkStatus::SUSPENDED->value => __('معلّق للتحقيق'),
    ];

    $reportStatusOptions = [
        WifiReportStatus::OPEN->value => __('مفتوح'),
        WifiReportStatus::INVESTIGATING->value => __('قيد المتابعة'),
        WifiReportStatus::RESOLVED->value => __('مغلق - تم الحل'),
        WifiReportStatus::DISMISSED->value => __('مغلق - مرفوض'),
    ];

    $batchStatusOptions = [
        WifiCodeBatchStatus::UPLOADED->value => __('مرفوع'),
        WifiCodeBatchStatus::VALIDATED->value => __('قيد المراجعة'),
        WifiCodeBatchStatus::ACTIVE->value => __('مفعل'),
        WifiCodeBatchStatus::ARCHIVED->value => __('مؤرشف'),
    ];
@endphp

<div class="modal fade" id="wifiNetworkDetailsModal" tabindex="-1" aria-hidden="true" data-wifi-network-modal>
    <div class="modal-dialog modal-xl modal-dialog-scrollable modal-dialog-centered">
        <div class="modal-content shadow-lg border-0">
            <div class="modal-header border-0 pb-0">
                <div>
                    <h5 class="modal-title fw-semibold mb-1" data-network-name></h5>
                    <p class="text-muted mb-0" data-network-subtitle>{{ __('عرض تفاصيل الشبكة والعمليات المتاحة.') }}</p>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('إغلاق') }}"></button>
            </div>
            <div class="modal-body pt-3">
                <div class="row g-4">
                    <div class="col-lg-4">
                        <div class="wifi-network-card h-100">
                            <div class="wifi-network-card__logo-wrapper mb-3">
                                <img src="{{ asset('assets/images/no_image_available.png') }}" alt="logo" class="wifi-network-card__logo" data-network-logo>
                            </div>
                            <div class="d-flex flex-column gap-2">
                                <div>
                                    <span class="text-muted small d-block">{{ __('الحالة الحالية') }}</span>
                                    <span class="badge rounded-pill bg-light text-dark fw-semibold" data-network-status-label>—</span>
                                </div>
                                <div>
                                    <span class="text-muted small d-block">{{ __('العمولة المعتمدة') }}</span>
                                    <span class="fw-semibold" data-network-commission>—</span>
                                </div>
                                <div>
                                    <span class="text-muted small d-block">{{ __('العنوان') }}</span>
                                    <span data-network-address>—</span>
                                </div>
                                <div>
                                    <span class="text-muted small d-block">{{ __('آخر تحديث') }}</span>
                                    <span data-network-updated-at>—</span>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-8">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <div class="wifi-network-info h-100">
                                    <h6 class="wifi-network-info__title">{{ __('إحصاءات الأداء') }}</h6>
                                    <ul class="wifi-network-info__list" data-network-stats>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('الخطط النشطة') }}</span>
                                            <span data-network-active-plans>—</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('الأكواد المرفوعة') }}</span>
                                            <span data-network-total-codes>—</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('الأكواد المتاحة') }}</span>
                                            <span data-network-available-codes>—</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('الأكواد المباعة') }}</span>
                                            <span data-network-sold-codes>—</span>
                                        </li>
                                    </ul>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="wifi-network-info h-100">
                                    <h6 class="wifi-network-info__title">{{ __('بيانات الاتصال') }}</h6>
                                    <ul class="wifi-network-info__list" data-network-contacts>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('اسم المالك') }}</span>
                                            <span data-network-owner>—</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('البريد الإلكتروني') }}</span>
                                            <span data-network-owner-email>—</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('الهاتف') }}</span>
                                            <span data-network-owner-phone>—</span>
                                        </li>
                                        <li class="wifi-network-info__item">
                                            <span>{{ __('قناة الدعم') }}</span>
                                            <span data-network-support-channel>—</span>
                                        </li>
                                    </ul>
                                </div>
                            </div>
<div class="col-12">
                                <div class="wifi-network-plans" data-network-plans>
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <h6 class="wifi-network-info__title mb-0">{{ __('الخطط المتاحة') }}</h6>
                                        <span class="badge bg-light text-dark" data-network-plans-count>0</span>
                                    </div>
                                    <div class="wifi-network-plans__list" data-network-plans-container>
                                        <p class="text-muted mb-0">{{ __('سيتم تحميل الخطط المرتبطة عند فتح النافذة.') }}</p>
                                    </div>
                                </div>
<div class="col-12">
                                <div class="wifi-network-plans" data-network-batches>
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <h6 class="wifi-network-info__title mb-0">{{ __('دفعات الأكواد الأخيرة') }}</h6>
                                        <span class="badge bg-light text-dark" data-network-batches-count>0</span>
                                    </div>
                                    <div class="wifi-network-plans__list" data-network-batches-container>
                                        <p class="text-muted mb-0">{{ __('لم يتم تحميل أي دفعات بعد.') }}</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="modal-footer border-0 justify-content-between flex-wrap gap-2">
                <div class="d-flex gap-2">
                    <button type="button" class="btn btn-outline-secondary" data-action="refresh-network-details">
                        <i class="bi bi-arrow-repeat"></i> {{ __('تحديث البيانات') }}
                    </button>
                    <button type="button" class="btn btn-outline-primary" data-action="open-network-batches">
                        <i class="bi bi-collection"></i> {{ __('إدارة الدفعات') }}
                    </button>
                </div>
                <div class="d-flex gap-2">
                    <button type="button" class="btn btn-warning" data-action="open-network-commission">
                        <i class="bi bi-cash-stack"></i> {{ __('تعديل العمولة') }}
                    </button>
                    <button type="button" class="btn btn-primary" data-action="open-network-status">
                        <i class="bi bi-shield-check"></i> {{ __('تحديث الحالة') }}
                    </button>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="wifiNetworkStatusModal" tabindex="-1" aria-hidden="true" data-wifi-status-modal>
    <div class="modal-dialog modal-md modal-dialog-centered">
        <div class="modal-content border-0 shadow">
            <div class="modal-header border-0">
                <h5 class="modal-title fw-semibold">{{ __('تحديث حالة الشبكة') }}</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('إغلاق') }}"></button>
            </div>
            <form method="post" class="needs-validation" novalidate data-network-status-form>
                @csrf
                <input type="hidden" name="_method" value="patch">
                <div class="modal-body">
                    <div class="mb-3">
                        <label for="wifi_network_status" class="form-label">{{ __('الحالة الجديدة') }}</label>
                        <select id="wifi_network_status" name="status" class="form-select" required>
                            @foreach($networkStatusOptions as $value => $label)
                                <option value="{{ $value }}">{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="mb-0">
                        <label for="wifi_network_reason" class="form-label">{{ __('سبب التعديل (اختياري)') }}</label>
                        <textarea id="wifi_network_reason" name="reason" class="form-control" rows="3" maxlength="250" placeholder="{{ __('اكتب ملاحظاتك للمالك أو فريق الدعم') }}"></textarea>
                    </div>
                    <div class="form-text text-muted mt-2" data-network-status-feedback></div>
                </div>
                <div class="modal-footer border-0">
                    <button type="button" class="btn btn-light" data-bs-dismiss="modal">{{ __('إلغاء') }}</button>
                    <button type="submit" class="btn btn-primary">
                        <i class="bi bi-save"></i> {{ __('حفظ الحالة') }}
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<div class="modal fade" id="wifiNetworkCommissionModal" tabindex="-1" aria-hidden="true" data-wifi-commission-modal>
    <div class="modal-dialog modal-md modal-dialog-centered">
        <div class="modal-content border-0 shadow">
            <div class="modal-header border-0">
                <h5 class="modal-title fw-semibold">{{ __('تعديل عمولة الشبكة') }}</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('إغلاق') }}"></button>
            </div>
            <form method="post" class="needs-validation" novalidate data-network-commission-form>
                @csrf
                <input type="hidden" name="_method" value="patch">
                <div class="modal-body">
                    <div class="mb-3">
                        <label for="wifi_network_commission" class="form-label">{{ __('النسبة المئوية') }}</label>
                        <div class="input-group">
                            <input type="number" step="0.01" min="0" max="50" id="wifi_network_commission" name="commission_rate" class="form-control" required placeholder="{{ __('أدخل نسبة العمولة') }}">
                            <span class="input-group-text">%</span>
                        </div>
                        <div class="form-text">{{ __('يتم احتساب العمولة من قيمة المبيعات النهائية، الحد الأقصى 50%.') }}</div>
                    </div>
                    <div class="form-text text-muted" data-network-commission-feedback></div>
                </div>
                <div class="modal-footer border-0">
                    <button type="button" class="btn btn-light" data-bs-dismiss="modal">{{ __('إغلاق') }}</button>
                    <button type="submit" class="btn btn-success">
                        <i class="bi bi-check2-circle"></i> {{ __('تحديث العمولة') }}
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<div class="modal fade" id="wifiNetworkBatchesModal" tabindex="-1" aria-hidden="true" data-wifi-batches-modal>
    <div class="modal-dialog modal-lg modal-dialog-scrollable modal-dialog-centered">
        <div class="modal-content border-0 shadow">
            <div class="modal-header border-0">
                <div>
                    <h5 class="modal-title fw-semibold">{{ __('دفعات الأكواد المرتبطة') }}</h5>
                    <p class="text-muted mb-0" data-network-batches-subtitle>{{ __('تحكم بدفعات الأكواد المرفوعة لكل خطة.') }}</p>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('إغلاق') }}"></button>
            </div>
            <div class="modal-body">
                <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-3">
                    <div class="btn-group" role="group">
                        <button type="button" class="btn btn-outline-primary" data-action="refresh-batches">
                            <i class="bi bi-arrow-clockwise"></i> {{ __('تحديث') }}
                        </button>
                        <a href="{{ route('wifi.create') }}" class="btn btn-primary">
                            <i class="bi bi-upload"></i> {{ __('رفع دفعة جديدة') }}
                        </a>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <label for="wifi_batch_status_filter" class="form-label mb-0">{{ __('الحالة') }}</label>
                        <select id="wifi_batch_status_filter" class="form-select form-select-sm" data-batch-status-filter>
                            <option value="">{{ __('الكل') }}</option>
                            @foreach($batchStatusOptions as $value => $label)
                                <option value="{{ $value }}">{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                </div>
                <div class="table-responsive">
                    <table id="wifi-network-batches-table" class="table table-hover align-middle"
                           data-toggle="table"
                           data-search="false"
                           data-pagination="true"
                           data-page-size="5"
                           data-side-pagination="client"
                           data-mobile-responsive="true"
                           data-locale="{{ app()->getLocale() }}"
                           data-empty-text="{{ __('لا توجد دفعات مسجلة لهذه الشبكة بعد.') }}">
                        <thead class="table-light">
                        <tr>
                            <th data-field="label">{{ __('الوسم') }}</th>
                            <th data-field="plan">{{ __('الخطة') }}</th>
                            <th data-field="status" data-formatter="MaribWifiAdminTables.formatBatchStatus">{{ __('الحالة') }}</th>
                            <th data-field="available_codes">{{ __('المتاح') }}</th>
                            <th data-field="total_codes">{{ __('الإجمالي') }}</th>
                            <th data-field="created_at" data-formatter="MaribWifiAdminTables.formatDate">{{ __('تاريخ الرفع') }}</th>
                            <th data-field="actions" data-formatter="MaribWifiAdminTables.formatBatchActions" data-events="MaribWifiAdminTables.batchActionEvents" data-align="center">{{ __('إجراءات') }}</th>
                        </tr>
                        </thead>
                    </table>
                </div>
            </div>
            <div class="modal-footer border-0">
                <button type="button" class="btn btn-light" data-bs-dismiss="modal">{{ __('إغلاق النافذة') }}</button>
            </div>
        </div>
    </div>
</div>

