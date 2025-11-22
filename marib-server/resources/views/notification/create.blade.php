@extends('layouts.main')

@section('title')
    {{ __('إرسال إشعار جديد') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row gy-3 align-items-center">
            <div class="col-12 col-lg-7">
                <h4 class="mb-1">@yield('title')</h4>
                <p class="text-muted mb-0">{{ __('تحكم كامل في الجمهور، المحتوى، ومسار التوجيه من مكان واحد.') }}</p>
            </div>
            <div class="col-12 col-lg-5 text-lg-end">
                <a href="{{ route('notification.index') }}" class="btn btn-outline-primary">
                    <i class="bi bi-clock-history"></i> {{ __('سجل الإشعارات') }}
                </a>
            </div>
        </div>
    </div>
@endsection
@section('content')
    <section class="section">
        @can('notification-create')
            <div class="row g-4">
                <div class="col-12 col-xl-8">
                    <form action="{{ route('notification.store') }}" method="post" class="create-form needs-validation" data-parsley-validate enctype="multipart/form-data">
                        @csrf
                        <input type="hidden" id="user_id" name="user_id" />

                        <div class="card shadow-sm mb-4">
                            <div class="card-header bg-white border-0">
                                <h5 class="mb-0">{{ __('الخطوة 1: الجمهور') }}</h5>
                            </div>
                            <div class="card-body border-top">
                                <div class="row g-3 align-items-center">
                                    <div class="col-lg-6">
                                        <label for="send_to" class="form-label">{{ __('نوع الجمهور المستهدف') }}</label>
                                        <select id="send_to" name="send_to" class="form-select select2" required>
                                            <option value="all">{{ __('الجميع (المفعلون للإشعارات)') }}</option>
                                            <option value="selected">{{ __('قائمة مخصصة') }}</option>
                                            <option value="individual">{{ __('عملاء أفراد') }}</option>
                                            <option value="business">{{ __('تجار ومتاجر') }}</option>
                                            <option value="real_estate">{{ __('حسابات عقار') }}</option>
                                        </select>
                                    </div>
                                    <div class="col-lg-6">
                                        <label class="form-label d-block">{{ __('مستكشف المستخدمين') }}</label>
                                        <div class="d-flex gap-3 flex-wrap align-items-center">
                                            <button type="button" class="btn btn-outline-primary" id="openRecipientModal" data-bs-toggle="modal" data-bs-target="#customRecipientsModal" disabled>
                                                <i class="bi bi-people"></i> {{ __('حدد المستخدمين') }}
                                            </button>
                                            <span class="text-muted small" id="customRecipientHint">{{ __('اختر "قائمة مخصصة" لتفعيل الزر.') }}</span>
                                        </div>
                                    </div>
                                    <div class="col-lg-6">
                                        <label for="category" class="form-label">{{ __('تصنيف الإشعار') }}</label>
                                        <select id="category" name="category" class="form-select" required>
                                            @foreach (($broadcastCategories ?? []) as $value => $label)
                                                <option value="{{ $value }}">{{ $label }}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="card shadow-sm mb-4">
                            <div class="card-header bg-white border-0">
                                <h5 class="mb-0">{{ __('الخطوة 2: المحتوى والوسائط') }}</h5>
                            </div>
                            <div class="card-body border-top">
                                <div class="row g-3">
                                    <div class="col-12">
                                        <label for="title" class="form-label">{{ __('عنوان الإشعار') }} <span class="text-danger">*</span></label>
                                        <input name="title" id="title" type="text" class="form-control form-control-lg" placeholder="{{ __('مثال: عروض خاصة لهذا الأسبوع') }}" required>
                                    </div>
                                    <div class="col-12">
                                        <label for="message" class="form-label">{{ __('نص الرسالة') }} <span class="text-danger">*</span></label>
                                        <textarea id="message" name="message" class="form-control" rows="4" placeholder="{{ __('اشرح ما تريد إعلامه للمستخدمين هنا...') }}" required></textarea>
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label">{{ __('الصورة (اختياري)') }}</label>
                                        <div class="border rounded p-3 d-flex justify-content-between align-items-center">
                                            <div class="form-check mb-0">
                                                <input id="include_image" name="include_image" type="checkbox" class="form-check-input">
                                                <label for="include_image" class="form-check-label">{{ __('تفعيل رفع الصورة') }}</label>
                                            </div>
                                            <small class="text-muted">{{ __('يفضل أبعاد مربعة 1:1') }}</small>
                                        </div>
                                        <div id="show_image" class="row g-2 mt-2 d-none">
                                            <div class="col-12">
                                                <input id="file" name="file" type="file" accept="image/*" class="form-control">
                                                <p id="img_error_msg" class="badge bg-danger d-none mt-2 mb-0"></p>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label">{{ __('زر الإجراء (CTA)') }}</label>
                                        <input type="text" name="cta_label" id="cta_label" class="form-control mb-2" placeholder="{{ __('مثال: شاهد التفاصيل الآن') }}">
                                        <input type="url" name="cta_link" id="cta_link" class="form-control" placeholder="https://example.com">
                                        <small class="text-muted d-block mt-1">{{ __('اختياري إذا أردت توجيه المستخدم لرابط خارجي.') }}</small>
                                    </div>
                                    <div class="col-12">
                                        <div class="border rounded-3 p-3 h-100">
                                            <div class="d-flex flex-column flex-lg-row gap-3 justify-content-between">
                                                <div>
                                                    <strong>{{ __('طلب دفعة من العميل') }}</strong>
                                                    <p class="text-muted small mb-0">
                                                        {{ __('في حال تفعيل الخيار سيظهر للمستلم زر دفع داخل تفاصيل الإشعار بالمبلغ الذي تحدده هنا.') }}
                                                    </p>
                                                </div>
                                                <div class="form-check form-switch mb-0">
                                                    <input class="form-check-input" type="checkbox" role="switch" id="request_payment" name="request_payment" value="1">
                                                    <label class="form-check-label" for="request_payment">{{ __('تفعيل طلب الدفع') }}</label>
                                                </div>
                                            </div>
                                            <div id="payment_request_fields" class="row g-3 mt-1 d-none">
                                                <div class="col-md-6">
                                                    <label for="payment_amount" class="form-label">{{ __('المبلغ المطلوب') }}</label>
                                                    <div class="input-group">
                                                        <input type="number" step="0.01" min="0" class="form-control" id="payment_amount" name="payment_amount" placeholder="0.00">
                                                        <input type="text" class="form-control text-uppercase" id="payment_currency" name="payment_currency" value="YER" maxlength="3" style="max-width: 120px;">
                                                    </div>
                                                    <small class="text-muted d-block mt-1">{{ __('استخدم رمز العملة من 3 أحرف (مثال: YER, SAR, USD).') }}</small>
                                                </div>
                                                <div class="col-md-6">
                                                    <label for="payment_note" class="form-label">{{ __('ملاحظة للعميل (اختياري)') }}</label>
                                                    <input type="text" class="form-control" id="payment_note" name="payment_note" placeholder="{{ __('مثال: رسوم اشتراك شهر مارس') }}">
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="card shadow-sm">
                            <div class="card-header bg-white border-0">
                                <h5 class="mb-0">{{ __('الخطوة 3: وجهة التوجيه') }}</h5>
                            </div>
                            <div class="card-body border-top">
                                <div class="row g-3">
                                    <div class="col-xl-6">
                                        <label for="target_type" class="form-label">{{ __('نوع الوجهة') }}</label>
                                        <select id="target_type" name="target_type" class="form-select">
                                            @foreach (($targetTypeLabels ?? []) as $value => $label)
                                                <option value="{{ $value }}">{{ $label }}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                    <div class="col-xl-6">
                                        <label class="form-label d-block">{{ __('المسار المتوقع') }}</label>
                                        <div class="border rounded p-3 bg-light d-flex gap-2 align-items-center">
                                            <span class="badge bg-primary-subtle text-primary">{{ __('المسار') }}</span>
                                            <span id="deeplink_preview_value" class="fw-semibold">marib://notifications</span>
                                        </div>
                                    </div>
                                </div>

                                <div class="mt-4">
                                    <div class="target-panel" data-target-panel="item">
                                        <label for="target_item_id" class="form-label">{{ __('منتج محدد') }}</label>
                                        <select name="target_item_id" id="target_item_id" class="form-select select2" data-target-input disabled>
                                            <option value="">{{ __('اختر المنتج المناسب') }}</option>
                                            @foreach ($item_list as $row)
                                                <option value="{{ $row->id }}">{{ $row->name }}</option>
                                            @endforeach
                                        </select>
                                    </div>

                                    <div class="target-panel d-none mt-3" data-target-panel="category">
                                        <label for="target_category_id" class="form-label">{{ __('قسم / تصنيف') }}</label>
                                        <select name="target_category_id" id="target_category_id" class="form-select select2" data-target-input disabled>
                                            <option value="">{{ __('اختر التصنيف') }}</option>
                                            @foreach ($categories as $category)
                                                <option value="{{ $category->id }}">{{ $category->name }}</option>
                                            @endforeach
                                        </select>
                                    </div>

                                    <div class="target-panel د-none mt-3" data-target-panel="service">
                                        <label for="target_service_id" class="form-label">{{ __('خدمة محددة') }}</label>
                                        <select name="target_service_id" id="target_service_id" class="form-select select2" data-target-input disabled>
                                            <option value="">{{ __('اختر الخدمة') }}</option>
                                            @foreach ($services as $service)
                                                <option value="{{ $service->id }}">{{ $service->title }}</option>
                                            @endforeach
                                        </select>
                                    </div>

                                    <div class="target-panel d-none mt-3" data-target-panel="blog">
                                        <label for="target_blog_id" class="form-label">{{ __('مقالة مدونة') }}</label>
                                        <select name="target_blog_id" id="target_blog_id" class="form-select select2" data-target-input disabled>
                                            <option value="">{{ __('اختر المقالة') }}</option>
                                            @foreach ($blogs as $blog)
                                                <option value="{{ $blog->id }}">{{ $blog->title }}</option>
                                            @endforeach
                                        </select>
                                    </div>

                                    <div class="target-panel d-none mt-3" data-target-panel="screen">
                                        <label for="target_screen" class="form-label">{{ __('شاشة داخل التطبيق') }}</label>
                                        <select name="target_screen" id="target_screen" class="form-select" data-target-input disabled>
                                            <option value="">{{ __('اختر الشاشة') }}</option>
                                            @foreach (($screenDestinations ?? []) as $value => $label)
                                                <option value="{{ $value }}">{{ $label }}</option>
                                            @endforeach
                                        </select>
                                    </div>

                                    <div class="target-panel d-none mt-3" data-target-panel="custom_link">
                                        <label for="target_url" class="form-label">{{ __('رابط خارجي (URL)') }}</label>
                                        <input type="url" class="form-control" id="target_url" name="target_url" placeholder="https://example.com" data-target-input disabled>
                                    </div>

                                    <div class="target-panel d-none mt-3" data-target-panel="deeplink">
                                        <label for="target_deeplink" class="form-label">{{ __('رابط Deeplink') }}</label>
                                        <input type="text" class="form-control" id="target_deeplink" name="target_deeplink" placeholder="marib://custom-route" data-target-input disabled>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="text-end mt-4">
                            <button class="btn btn-primary btn-lg px-4" type="submit">
                                <i class="bi bi-send me-2"></i>{{ __('إرسال الإشعار الآن') }}
                            </button>
                        </div>
                    </form>
                </div>
                <div class="col-12 col-xl-4">
                    <div class="card shadow-sm mb-4">
                        <div class="card-body">
                            <h6 class="mb-3">{{ __('خطوات منظمة') }}</h6>
                            <ol class="list-group list-group-numbered">
                                <li class="list-group-item border-0 px-0 pb-3">
                                    <strong>{{ __('حدد الجمهور') }}</strong>
                                    <p class="text-muted small mb-0">{{ __('اختر شريحة جاهزة أو مستكشف المستخدمين لاستهداف أشخاص بعينهم.') }}</p>
                                </li>
                                <li class="list-group-item border-0 px-0 pb-3">
                                    <strong>{{ __('اكتب المحتوى') }}</strong>
                                    <p class="text-muted small mb-0">{{ __('عنوان مختصر ورسالة واضحة يزيدان التفاعل.') }}</p>
                                </li>
                                <li class="list-group-item border-0 px-0">
                                    <strong>{{ __('اختر الوجهة') }}</strong>
                                    <p class="text-muted صغير mb-0">{{ __('منتج، خدمة، مقالة مدونة، شاشة، أو رابط خارجي.') }}</p>
                                </li>
                            </ol>
                        </div>
                    </div>

                    <div class="card shadow-sm">
                        <div class="card-body">
                            <h6 class="mb-3">{{ __('نصائح إضافية') }}</h6>
                            <ul class="text-muted small ps-3 mb-0">
                                <li class="mb-2">{{ __('جرب الإشعار على حسابك قبل بثه للجميع.') }}</li>
                                <li class="mb-2">{{ __('ادمج زر CTA واضح عندما يكون هناك رابط مهم.') }}</li>
                                <li class="mb-2">{{ __('يفضل ألا يتجاوز النص 120 حرفاً لضمان ظهور كامل.') }}</li>
                                <li>{{ __('راجع السجل باستمرار لمعرفة آخر النتائج.') }}</li>
                            </ul>
                        </div>
                    </div>
                </div>
            </div>
        @else
            <div class="alert alert-warning">
                {{ __('لا تملك صلاحية إرسال الإشعارات.') }}
            </div>
        @endcan
    </section>

    <div class="modal fade" id="customRecipientsModal" tabindex="-1" aria-labelledby="customRecipientsModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-xl modal-dialog-scrollable">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="customRecipientsModalLabel">{{ __('مستكشف المستخدمين') }}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('إغلاق') }}"></button>
                </div>
                <div class="modal-body">
                    <table class="table table-borderless table-striped"
                           id="user_notification_list"
                           data-toggle="table"
                           data-url="{{ route('customer.list') }}"
                           data-click-to-select="true"
                           data-side-pagination="server"
                           data-pagination="true"
                           data-page-list="[5, 10, 20, 50, 100, 200]"
                           data-search="true"
                           data-show-columns="true"
                           data-show-refresh="true"
                           data-fixed-columns="true"
                           data-fixed-number="1"
                           data-fixed-right-number="1"
                           data-trim-on-search="false"
                           data-responsive="true"
                           data-sort-name="id"
                           data-sort-order="desc"
                           data-pagination-successively-size="3"
                           data-escape="true"
                           data-query-params="notificationUserList"
                           data-mobile-responsive="true">
                        <thead class="thead-dark">
                        <tr>
                            <th scope="col" data-field="state" data-checkbox="true"></th>
                            <th scope="col" data-field="id" data-sortable="true">{{ __('المعرف') }}</th>
                            <th scope="col" data-field="name" data-sortable="true">{{ __('الاسم') }}</th>
                            <th scope="col" data-field="mobile" data-sortable="true">{{ __('الرقم') }}</th>
                        </tr>
                        </thead>
                    </table>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" id="saveSelectedRecipients" data-bs-dismiss="modal" disabled>{{ __('حفظ المستخدمين') }}</button>
                    <button type="button" class="btn btn-light" id="closeRecipientsModal" data-bs-dismiss="modal">{{ __('إغلاق') }}</button>
                </div>
            </div>
        </div>
    </div>
@endsection
@push('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const includeImage = document.getElementById('include_image');
            const imageWrapper = document.getElementById('show_image');
            const targetSelect = document.getElementById('target_type');
            const targetPanels = document.querySelectorAll('[data-target-panel]');
            const previewValue = document.getElementById('deeplink_preview_value');
            const targetInputs = document.querySelectorAll('[data-target-input]');
            const sendToSelect = document.getElementById('send_to');
            const customRecipientHint = document.getElementById('customRecipientHint');
            const paymentToggle = document.getElementById('request_payment');
            const paymentFields = document.getElementById('payment_request_fields');
            const paymentAmount = document.getElementById('payment_amount');
            const paymentCurrency = document.getElementById('payment_currency');
            const userIdInput = document.getElementById('user_id');
            const recipientsModalEl = document.getElementById('customRecipientsModal');
            const openRecipientModalBtn = document.getElementById('openRecipientModal');
            const saveRecipientsBtn = document.getElementById('saveSelectedRecipients');
            const closeRecipientsBtn = document.getElementById('closeRecipientsModal');
            let recipientsModal = null;

            function getModalInstance() {
                if (!recipientsModalEl || typeof bootstrap === 'undefined' || typeof bootstrap.Modal !== 'function') {
                    return null;
                }
                if (!recipientsModal) {
                    recipientsModal = new bootstrap.Modal(recipientsModalEl, { backdrop: 'static', keyboard: true });
                }
                return recipientsModal;
            }

            function showModal() {
                const instance = getModalInstance();
                if (instance) {
                    instance.show();
                } else if (window.jQuery) {
                    window.jQuery(recipientsModalEl).modal('show');
                } else if (recipientsModalEl) {
                    recipientsModalEl.classList.add('show');
                    recipientsModalEl.style.display = 'block';
                }
            }

            function hideModal() {
                const instance = getModalInstance();
                if (instance) {
                    instance.hide();
                } else if (window.jQuery) {
                    window.jQuery(recipientsModalEl).modal('hide');
                } else if (recipientsModalEl) {
                    recipientsModalEl.classList.remove('show');
                    recipientsModalEl.style.display = 'none';
                }
            }

            function togglePaymentFields() {
                const enabled = paymentToggle && paymentToggle.checked;
                if (paymentFields) {
                    paymentFields.classList.toggle('d-none', !enabled);
                }
                const inputs = [paymentAmount, paymentCurrency];
                inputs.forEach(input => {
                    if (!input) return;
                    if (enabled) {
                        input.setAttribute('required', 'required');
                    } else {
                        input.removeAttribute('required');
                        if (input === paymentAmount) {
                            input.value = '';
                        }
                    }
                });
            }

            function toggleImageField() {
                if (!includeImage || !imageWrapper) {
                    return;
                }
                const show = includeImage.checked;
                imageWrapper.classList.toggle('d-none', !show);
                const fileInput = imageWrapper.querySelector('input[type="file"]');
                if (fileInput) {
                    if (show) {
                        fileInput.setAttribute('required', 'required');
                    } else {
                        fileInput.value = '';
                        fileInput.removeAttribute('required');
                    }
                }
            }

            function resetInput(input) {
                if (input.tagName === 'SELECT' && window.jQuery) {
                    window.jQuery(input).val('').trigger('change');
                } else {
                    input.value = '';
                }
            }

            function toggleTargetPanels() {
                const current = targetSelect ? targetSelect.value : 'inbox';
                targetPanels.forEach(panel => {
                    const inputs = panel.querySelectorAll('[data-target-input]');
                    const match = panel.dataset.targetPanel === current;
                    panel.classList.toggle('d-none', !match);
                    inputs.forEach(input => {
                        if (match) {
                            input.removeAttribute('disabled');
                        } else {
                            input.setAttribute('disabled', 'disabled');
                            resetInput(input);
                        }
                    });
                });
                updatePreview();
            }

            function updatePreview() {
                if (!previewValue) {
                    return;
                }
                const type = targetSelect ? targetSelect.value : 'inbox';
                let preview = 'marib://notifications';
                const valueOf = id => {
                    const el = document.getElementById(id);
                    return el && el.value ? el.value : '';
                };
                if (type === 'item') {
                    const id = valueOf('target_item_id');
                    if (id) preview = `marib://item/${id}`;
                } else if (type === 'category') {
                    const id = valueOf('target_category_id');
                    if (id) preview = `marib://category/${id}`;
                } else if (type === 'service') {
                    const id = valueOf('target_service_id');
                    if (id) preview = `marib://service/${id}`;
                } else if (type === 'blog') {
                    const id = valueOf('target_blog_id');
                    if (id) preview = `marib://blog/${id}`;
                } else if (type === 'screen') {
                    const screen = valueOf('target_screen');
                    if (screen) preview = `marib://${screen}`;
                } else if (type === 'custom_link') {
                    const url = valueOf('target_url');
                    if (url) preview = url;
                } else if (type === 'deeplink') {
                    const deeplink = valueOf('target_deeplink');
                    if (deeplink) preview = deeplink;
                }
                previewValue.textContent = preview;
            }

            function syncSelectedUsers(ids) {
                if (userIdInput) {
                    userIdInput.value = ids.join(',');
                }
                if (saveRecipientsBtn) {
                    if (ids.length > 0) {
                        saveRecipientsBtn.removeAttribute('disabled');
                    } else {
                        saveRecipientsBtn.setAttribute('disabled', 'disabled');
                    }
                }
            }

            function refreshSelectedUsersFromTable() {
                if (!window.jQuery) {
                    syncSelectedUsers([]);
                    return;
                }
                const $table = window.jQuery('#user_notification_list');
                if (!$table.length || typeof $table.bootstrapTable !== 'function') {
                    syncSelectedUsers([]);
                    return;
                }
                const selections = $table.bootstrapTable('getSelections') || [];
                const ids = selections.map(row => row.id);
                syncSelectedUsers(ids);
            }

            function toggleCustomRecipientsField() {
                const custom = sendToSelect && sendToSelect.value === 'selected';
                if (openRecipientModalBtn) {
                    openRecipientModalBtn.disabled = !custom;
                    openRecipientModalBtn.classList.toggle('btn-outline-secondary', !custom);
                    openRecipientModalBtn.classList.toggle('btn-outline-primary', custom);
                }
                if (customRecipientHint) {
                    customRecipientHint.textContent = custom ? '{{ __('اضغط على الزر لاختيار المستخدمين المطلوبين.') }}' : '{{ __('اختر "قائمة مخصصة" لتحديد أشخاص بعينهم.') }}';
                }
                if (!custom) {
                    syncSelectedUsers([]);
                    if (window.jQuery) {
                        const $table = window.jQuery('#user_notification_list');
                        if ($table.length) {
                            $table.bootstrapTable('uncheckAll');
                        }
                    }
                } else {
                    showModal();
                }
            }

            if (includeImage) {
                includeImage.addEventListener('change', toggleImageField);
                toggleImageField();
            }

            if (paymentToggle) {
                paymentToggle.addEventListener('change', togglePaymentFields);
                togglePaymentFields();
            }

            if (targetSelect) {
                targetSelect.addEventListener('change', toggleTargetPanels);
            }

            targetInputs.forEach(input => {
                input.addEventListener('change', updatePreview);
                input.addEventListener('keyup', updatePreview);
            });

            if (window.jQuery) {
                const $table = window.jQuery('#user_notification_list');
                if ($table.length) {
                    $table.on('check.bs.table uncheck.bs.table check-all.bs.table uncheck-all.bs.table', refreshSelectedUsersFromTable);
                }
            }

            if (openRecipientModalBtn) {
                openRecipientModalBtn.addEventListener('click', showModal);
            }

            if (saveRecipientsBtn) {
                saveRecipientsBtn.addEventListener('click', function () {
                    refreshSelectedUsersFromTable();
                    hideModal();
                });
            }

            if (closeRecipientsBtn) {
                closeRecipientsBtn.addEventListener('click', hideModal);
            }

            if (sendToSelect) {
                sendToSelect.addEventListener('change', toggleCustomRecipientsField);
                if (window.jQuery) {
                    window.jQuery(sendToSelect).on('change.select2', toggleCustomRecipientsField);
                }
            }

            toggleTargetPanels();
            toggleCustomRecipientsField();
            refreshSelectedUsersFromTable();
        });
    </script>
@endpush
