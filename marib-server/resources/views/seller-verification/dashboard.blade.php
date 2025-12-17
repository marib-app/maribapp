@extends('layouts.main')
@section('title')
    {{ __("الحسابات الموثقة") }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row d-flex align-items-center">
            <div class="col-12 col-md-6">
                <h4 class="mb-0">@yield('title')</h4>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card mb-3">
            <div class="card-body">
                <ul class="nav nav-tabs" id="verificationTabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active" id="requests-tab" data-bs-toggle="tab" data-bs-target="#requests" type="button" role="tab" aria-controls="requests" aria-selected="true">
                            {{ __('طلبات التوثيق') }}
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="payments-tab" data-bs-toggle="tab" data-bs-target="#payments" type="button" role="tab" aria-controls="payments" aria-selected="false">
                            {{ __('مدفوعات التوثيق') }}
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="verified-tab" data-bs-toggle="tab" data-bs-target="#verified" type="button" role="tab" aria-controls="verified" aria-selected="false">
                            {{ __('الحسابات الموثقة') }}
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="plans-tab" data-bs-toggle="tab" data-bs-target="#plans" type="button" role="tab" aria-controls="plans" aria-selected="false">
                            {{ __('إدارة خطط التوثيق') }}
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="fields-tab" data-bs-toggle="tab" data-bs-target="#fields" type="button" role="tab" aria-controls="fields" aria-selected="false">
                            {{ __('حقول التوثيق') }}
                        </button>
                    </li>
                </ul>
                <div class="tab-content pt-3">
                    <div class="tab-pane fade show active" id="requests" role="tabpanel" aria-labelledby="requests-tab">
                        <table class="stable-borderless table-striped"
                               id="table_requests"
                               data-toggle="table"
                               data-url="{{ route('verification_requests.show') }}"
                               data-side-pagination="server"
                               data-pagination="true"
                               data-page-list="[5, 10, 20, 50, 100, 200]"
                               data-search="true"
                               data-show-refresh="true"
                               data-show-columns="true"
                               data-mobile-responsive="true"
                               data-sort-name="id"
                               data-sort-order="desc">
                            <thead class="thead-dark">
                            <tr>
                                <th scope="col" data-field="id" data-align="center" data-sortable="true">#</th>
                                <th scope="col" data-field="user_name" data-align="center" data-sortable="true">{{ __('المستخدم') }}</th>
                                <th scope="col" data-field="status" data-align="center" data-sortable="true">{{ __('الحالة') }}</th>
                                <th scope="col" data-field="operate" data-align="center" data-sortable="false" data-escape="false" data-events="verificationEvents">{{ __('إجراء') }}</th>
                            </tr>
                            </thead>
                        </table>
                    </div>
                    <div class="tab-pane fade" id="payments" role="tabpanel" aria-labelledby="payments-tab">
                        <table class="stable-borderless table-striped"
                               id="table_payments"
                               data-toggle="table"
                               data-url="{{ route('verification_payments.show') }}"
                               data-side-pagination="server"
                               data-pagination="true"
                               data-page-list="[5, 10, 20, 50, 100, 200]"
                               data-search="true"
                               data-show-refresh="true"
                               data-show-columns="true"
                               data-mobile-responsive="true"
                               data-sort-name="id"
                               data-sort-order="desc">
                                                        <thead class="thead-dark">
                            <tr>
                                <th scope="col" data-field="id" data-align="center" data-sortable="true">#</th>
                                <th scope="col" data-field="user_name" data-align="center" data-sortable="true">المستخدم</th>
                                <th scope="col" data-field="plan" data-align="center" data-sortable="true">الباقة</th>
                                <th scope="col" data-field="amount" data-align="center" data-sortable="true">المبلغ</th>
                                <th scope="col" data-field="currency" data-align="center" data-sortable="true">العملة</th>
                                <th scope="col" data-field="gateway" data-align="center" data-sortable="true">طريقة الدفع</th>
                                <th scope="col" data-field="status" data-align="center" data-sortable="true">الحالة</th>
                                <th scope="col" data-field="expires_at" data-align="center" data-sortable="true">تاريخ الانتهاء</th>
                                <th scope="col" data-field="created_at" data-align="center" data-sortable="true">تاريخ الدفع</th>
                            </tr>
                            </thead>
                        </table>
                    </div>
                    <div class="tab-pane fade" id="verified" role="tabpanel" aria-labelledby="verified-tab">
                        <table class="stable-borderless table-striped"
                               id="table_verified"
                               data-toggle="table"
                               data-url="{{ route('verification_verified_accounts.show') }}"
                               data-side-pagination="server"
                               data-pagination="true"
                               data-page-list="[5, 10, 20, 50, 100, 200]"
                               data-search="true"
                               data-show-refresh="true"
                               data-show-columns="true"
                               data-mobile-responsive="true"
                               data-sort-name="id"
                               data-sort-order="desc">
                            <thead class="thead-dark">
                            <tr>
                                <th scope="col" data-field="id" data-align="center" data-sortable="true">#</th>
                                <th scope="col" data-field="name" data-align="center" data-sortable="true">{{ __('الاسم') }}</th>
                                <th scope="col" data-field="email" data-align="center" data-sortable="true">{{ __('البريد') }}</th>
                                <th scope="col" data-field="mobile" data-align="center" data-sortable="true">{{ __('الجوال') }}</th>
                                <th scope="col" data-field="expires_at" data-align="center" data-sortable="true">{{ __('ينتهي في') }}</th>
                                <th scope="col" data-field="status_badge" data-align="center" data-sortable="false" data-escape="false">{{ __('الحالة') }}</th>
                                <th scope="col" data-field="actions" data-align="center" data-sortable="false" data-escape="false">{{ __('إجراءات') }}</th>
                            </tr>
                            </thead>
                        </table>
                    </div>
                    <div class="tab-pane fade" id="plans" role="tabpanel" aria-labelledby="plans-tab">
                        <h5 class="mb-3">{{ __('إدارة خطط التوثيق') }}</h5>
                        <form action="{{ route('seller-verification.plan.store') }}" method="POST" class="row g-3">
                            @csrf
                            <div class="col-md-3">
                                <label class="form-label">{{ __('اسم الخطة') }}</label>
                                <input type="text" name="name" class="form-control" required>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">{{ __('نوع الحساب') }}</label>
                                <select name="account_type" class="form-select" required>
                                    <option value="individual">{{ __('فردي') }}</option>
                                    <option value="commercial">{{ __('تجاري') }}</option>
                                    <option value="realestate">{{ __('عقاري') }}</option>
                                </select>
                            </div>
                            <div class="col-md-2">
                                <label class="form-label">{{ __('المدة (أيام)') }}</label>
                                <input type="number" min="0" name="duration_days" class="form-control" placeholder="{{ __('مثال: 30') }}">
                                <small class="text-muted">{{ __('اتركها فارغة للمفتوح') }}</small>
                            </div>
                            <div class="col-md-2">
                                <label class="form-label">{{ __('السعر') }}</label>
                                <input type="number" step="0.01" min="0" name="price" class="form-control" required>
                            </div>
                            <div class="col-md-2">
                                <label class="form-label">{{ __('العملة') }}</label>
                                <select name="currency" class="form-select" required>
                                    <option value="SAR" selected>SAR (﷼ سعودي)</option>
                                    <option value="YER">YER (﷼ يمني)</option>
                                    <option value="USD">USD ($)</option>
                                </select>
                            </div>
                            <div class="col-12">
                                <button type="submit" class="btn btn-primary">{{ __('حفظ الخطة') }}</button>
                            </div>
                        </form>

                        @if($plans->isNotEmpty())
                            <hr>
                            <div class="table-responsive">
                                <table class="table table-sm table-striped">
                                    <thead>
                                    <tr>
                                        <th>#</th>
                                        <th>{{ __('الخطة') }}</th>
                                        <th>{{ __('النوع') }}</th>
                                        <th>{{ __('المدة') }}</th>
                                        <th>{{ __('السعر') }}</th>
                                        <th>{{ __('الحالة') }}</th>
                                        <th>{{ __('إجراءات') }}</th>
                                    </tr>
                                    </thead>
                                    <tbody>
                                    @foreach($plans as $plan)
                                        <tr>
                                            <td>{{ $plan->id }}</td>
                                            <td>{{ $plan->name }}</td>
                                            <td>{{ $plan->account_type }}</td>
                                            <td>{{ $plan->duration_days ?? __('مفتوح') }}</td>
                                            <td>{{ number_format($plan->price, 2) }} {{ $plan->currency }}</td>
                                            <td>
                                                <form action="{{ route('seller-verification.plan.update', $plan->id) }}" method="POST" class="d-inline">
                                                    @csrf
                                                    @method('PUT')
                                                    <input type="hidden" name="name" value="{{ $plan->name }}">
                                                    <input type="hidden" name="account_type" value="{{ $plan->account_type }}">
                                                    <input type="hidden" name="duration_days" value="{{ $plan->duration_days }}">
                                                    <input type="hidden" name="price" value="{{ $plan->price }}">
                                                    <input type="hidden" name="currency" value="{{ $plan->currency }}">
                                                    <input type="hidden" name="is_active" value="{{ $plan->is_active ? 0 : 1 }}">
                                                    <button type="submit" class="btn btn-sm {{ $plan->is_active ? 'btn-success' : 'btn-secondary' }}">
                                                        {{ $plan->is_active ? __('نشط') : __('متوقف') }}
                                                    </button>
                                                </form>
                                            </td>
                                            <td class="d-flex gap-1">
                                                <button type="button" class="btn btn-sm btn-outline-primary" data-bs-toggle="modal" data-bs-target="#editPlanModal{{ $plan->id }}">
                                                    {{ __('تعديل') }}
                                                </button>
                                                <form action="{{ route('seller-verification.plan.delete', $plan->id) }}" method="POST" onsubmit="return confirm('{{ __('حذف الخطة؟') }}')">
                                                    @csrf
                                                    @method('DELETE')
                                                    <button type="submit" class="btn btn-sm btn-outline-danger">{{ __('حذف') }}</button>
                                                </form>
                                            </td>
                                        </tr>
                                        <!-- Edit Modal -->
                                        <div class="modal fade" id="editPlanModal{{ $plan->id }}" tabindex="-1" aria-labelledby="editPlanModalLabel{{ $plan->id }}" aria-hidden="true">
                                            <div class="modal-dialog modal-lg">
                                                <div class="modal-content">
                                                    <div class="modal-header">
                                                        <h5 class="modal-title" id="editPlanModalLabel{{ $plan->id }}">{{ __('تعديل الخطة') }}</h5>
                                                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                                    </div>
                                                    <div class="modal-body">
                                                        <form action="{{ route('seller-verification.plan.update', $plan->id) }}" method="POST" class="row g-3">
                                                            @csrf
                                                            @method('PUT')
                                                            <div class="col-md-4">
                                                                <label class="form-label">{{ __('اسم الخطة') }}</label>
                                                                <input type="text" name="name" value="{{ $plan->name }}" class="form-control" required>
                                                            </div>
                                                            <div class="col-md-4">
                                                                <label class="form-label">{{ __('نوع الحساب') }}</label>
                                                                <select name="account_type" class="form-select" required>
                                                                    <option value="individual" @selected($plan->account_type=='individual')>{{ __('فردي') }}</option>
                                                                    <option value="commercial" @selected($plan->account_type=='commercial')>{{ __('تجاري') }}</option>
                                                                    <option value="realestate" @selected($plan->account_type=='realestate')>{{ __('عقاري') }}</option>
                                                                </select>
                                                            </div>
                                                            <div class="col-md-4">
                                                                <label class="form-label">{{ __('المدة (أيام)') }}</label>
                                                                <input type="number" min="0" name="duration_days" value="{{ $plan->duration_days }}" class="form-control" placeholder="{{ __('مثال: 30') }}">
                                                                <small class="text-muted">{{ __('اتركها فارغة للمفتوح') }}</small>
                                                            </div>
                                                            <div class="col-md-4">
                                                                <label class="form-label">{{ __('السعر') }}</label>
                                                                <input type="number" step="0.01" min="0" name="price" value="{{ $plan->price }}" class="form-control" required>
                                                            </div>
                                                            <div class="col-md-4">
                                                                <label class="form-label">{{ __('العملة') }}</label>
                                                                <select name="currency" class="form-select" required>
                                                                    <option value="SAR" @selected($plan->currency=='SAR')>SAR (﷼ سعودي)</option>
                                                                    <option value="YER" @selected($plan->currency=='YER')>YER (﷼ يمني)</option>
                                                                    <option value="USD" @selected($plan->currency=='USD')>USD ($)</option>
                                                                </select>
                                                            </div>
                                                            <div class="col-md-4">
                                                                <label class="form-label">{{ __('الحالة') }}</label>
                                                                <select name="is_active" class="form-select">
                                                                    <option value="1" @selected($plan->is_active)> {{ __('نشط') }}</option>
                                                                    <option value="0" @selected(!$plan->is_active)> {{ __('متوقف') }}</option>
                                                                </select>
                                                            </div>
                                                            <div class="col-12">
                                                                <button type="submit" class="btn btn-primary">{{ __('حفظ التعديلات') }}</button>
                                                            </div>
                                                        </form>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                        <!-- /Edit Modal -->
                                    @endforeach
                                    </tbody>
                                </table>
                            </div>
                        @endif
                    </div>
                    <div class="tab-pane fade" id="fields" role="tabpanel" aria-labelledby="fields-tab">
                        <div class="d-flex justify-content-between align-items-center mb-2 flex-wrap gap-2">
                            <h5 class="mb-0">{{ __('حقول التوثيق') }}</h5>
                            <div class="d-flex gap-2">
                                <select id="fieldAccountType" class="form-select form-select-sm">
                                    <option value="">{{ __('كل الأنواع') }}</option>
                                    <option value="individual">{{ __('فردي') }}</option>
                                    <option value="commercial">{{ __('تجاري') }}</option>
                                    <option value="realestate">{{ __('عقاري') }}</option>
                                </select>
                                <a href="{{ route('seller-verification.create') }}" class="btn btn-sm btn-primary">{{ __('إضافة حقل') }}</a>
                            </div>
                        </div>
                        <table class="stable-borderless table-striped"
                               id="table_fields"
                               data-toggle="table"
                               data-url="{{ route('verification-field.show') }}"
                               data-side-pagination="server"
                               data-pagination="true"
                               data-page-list="[5, 10, 20, 50, 100, 200]"
                               data-search="true"
                               data-show-refresh="true"
                               data-show-columns="true"
                               data-mobile-responsive="true"
                               data-sort-name="id"
                               data-sort-order="desc">
                            <thead class="thead-dark">
                            <tr>
                                <th scope="col" data-field="id" data-align="center" data-sortable="true">#</th>
                                <th scope="col" data-field="name" data-align="center" data-sortable="true">{{ __('الاسم') }}</th>
                                <th scope="col" data-field="type" data-align="center" data-sortable="true">{{ __('النوع') }}</th>
                                <th scope="col" data-field="account_type_label" data-align="center" data-sortable="true">{{ __('نوع الحساب') }}</th>
                                <th scope="col" data-field="status" data-align="center" data-sortable="true">{{ __('الحالة') }}</th>
                                <th scope="col" data-field="operate" data-align="center" data-sortable="false" data-escape="false">{{ __('إجراءات') }}</th>
                            </tr>
                            </thead>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- تفاصيل طلب التوثيق -->
    <div id="editModal" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="verificationModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="verificationModalLabel">{{ __('تفاصيل طلب التوثيق') }}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="center" id="verification_fields"></div>
                </div>
            </div>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const params = new URLSearchParams(window.location.search);
            const hashTab = window.location.hash.replace('#', '');
            const requestedTab = params.get('tab') || (hashTab ? hashTab : null);
            const tabButtons = document.querySelectorAll('#verificationTabs button[data-bs-toggle="tab"]');

            const ensureTable = (targetId) => {
                const tableId = targetId === '#requests' ? '#table_requests'
                    : targetId === '#payments' ? '#table_payments'
                        : targetId === '#verified' ? '#table_verified'
                            : '#table_fields';
                if ($(tableId).data('bootstrap.table')) {
                    $(tableId).bootstrapTable('refresh');
                } else {
                    $(tableId).bootstrapTable();
                }
            };

            if (requestedTab) {
                const trigger = document.querySelector(`#${requestedTab}-tab`);
                if (trigger && window.bootstrap?.Tab) {
                    const tabInstance = new bootstrap.Tab(trigger);
                    tabInstance.show();
                    ensureTable(`#${requestedTab}`);
                }
            } else {
                // Initialize the default active tab on first load
                const activeTab = document.querySelector('#verificationTabs button.active');
                if (activeTab) {
                    ensureTable(activeTab.dataset.bsTarget);
                }
            }

            tabButtons.forEach(btn => {
                btn.addEventListener('shown.bs.tab', function () {
                    ensureTable(this.dataset.bsTarget);
                });
            });

            // Filter fields by account_type if supported in backend
            $('#fieldAccountType').on('change', function () {
                const type = $(this).val();
                const url = "{{ route('verification-field.show') }}" + (type ? ('?account_type=' + type) : '');
                $('#table_fields').bootstrapTable('refresh', {url});
            });
        });
    </script>
@endsection

