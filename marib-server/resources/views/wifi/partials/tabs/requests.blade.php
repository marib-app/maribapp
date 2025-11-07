<div class="tab-pane fade" id="wifi-requests" role="tabpanel" aria-labelledby="wifi-requests-tab" tabindex="0">
    <div class="wifi-toolbar mb-3" id="wifi-requests-toolbar">
        <div class="row g-2 align-items-center">
            <div class="col-sm-6 col-md-4">
                <div class="input-group">
                    <span class="input-group-text"><i class="bi bi-search"></i></span>
                    <input type="search" class="form-control" placeholder="{{ __('بحث بالوسم أو الشبكة') }}"
                           data-request-search>
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
                            <form method="post" action="{{ route('wifi.owner-requests.approve', $requestBatch) }}"
                                  class="d-inline-flex align-items-center gap-1" data-request-approve>
                                @csrf
                                <button type="submit" class="btn btn-success btn-sm">
                                    <i class="bi bi-check-circle"></i> {{ __('موافقة') }}
                                </button>
                            </form>
                            <button type="button" class="btn btn-outline-danger btn-sm" data-bs-toggle="modal"
                                    data-bs-target="#reject-batch-{{ $requestBatch->id }}">
                                <i class="bi bi-x-circle"></i> {{ __('رفض') }}
                            </button>
                        </div>

                        <div class="modal fade" id="reject-batch-{{ $requestBatch->id }}" tabindex="-1" aria-hidden="true">
                            <div class="modal-dialog modal-dialog-centered">
                                <div class="modal-content">
                                    <div class="modal-header">
                                        <h5 class="modal-title">{{ __('رفض طلب المالك') }}</h5>
                                        <button type="button" class="btn-close" data-bs-dismiss="modal"
                                                aria-label="{{ __('إغلاق') }}"></button>
                                    </div>
                                    <form method="post" action="{{ route('wifi.owner-requests.reject', $requestBatch) }}">
                                        @csrf
                                        <div class="modal-body">
                                            <p class="text-muted">{{ __('يرجى توضيح سبب الرفض (اختياري).') }}</p>
                                            <textarea name="reason" class="form-control" rows="3"
                                                      placeholder="{{ __('سبب الرفض') }}"></textarea>
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
