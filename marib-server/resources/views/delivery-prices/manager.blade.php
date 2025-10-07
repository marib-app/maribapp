@php
    $currentDepartment = $department ?? null;
    $policyModes = $policyModes ?? [];
    $policyData = $policyData ?? null;
    $policyModel = $policy ?? null;
    $departments = $departments ?? [];
    $currentVendor = $vendor ?? null;
    $vendors = $vendors ?? [];

    $policyRules = $policyData['policy_rules'] ?? [];
    $weightTierOptions = collect($policyData['weight_tiers'] ?? [])->map(function ($tier) {
        return [
            'id' => $tier['id'] ?? null,
            'name' => $tier['name'] ?? '',
        ];
    })->filter(fn ($tier) => $tier['id'] !== null)->values()->all();

    $departmentLabel = $currentDepartment && isset($departments[$currentDepartment])
        ? $departments[$currentDepartment]
        : ($currentDepartment === null ? 'جميع الأقسام' : $currentDepartment);

    $vendorLabel = $currentVendor && isset($vendors[$currentVendor])
        ? $vendors[$currentVendor]
        : ($currentVendor === null ? 'جميع التجار' : $currentVendor);

    $defaultPaymentSettings = [
        'allow_pay_now' => true,
        'allow_pay_on_delivery' => false,
        'cod_fee' => null,
        'source' => 'default',
        'source_label' => 'الإعدادات الافتراضية',
        'vendor_has_override' => false,
        'department_has_override' => false,
    ];

    $paymentSettings = $paymentSettings ?? [];
    if (!is_array($paymentSettings)) {
        $paymentSettings = [];
    }

    $paymentSettings = array_merge($defaultPaymentSettings, $paymentSettings);
    $allowPayNowChecked = filter_var(old('allow_pay_now', $paymentSettings['allow_pay_now'] ? '1' : '0'), FILTER_VALIDATE_BOOLEAN);
    $allowPayOnDeliveryChecked = filter_var(old('allow_pay_on_delivery', $paymentSettings['allow_pay_on_delivery'] ? '1' : '0'), FILTER_VALIDATE_BOOLEAN);
    $codFeeValue = old('cod_fee', $paymentSettings['cod_fee'] !== null ? number_format((float) $paymentSettings['cod_fee'], 2, '.', '') : '');
    $paymentSourceLabel = $paymentSettings['source_label'] ?? 'الإعدادات الافتراضية';
    $vendorHasOverride = (bool) ($paymentSettings['vendor_has_override'] ?? false);
    $departmentHasOverride = (bool) ($paymentSettings['department_has_override'] ?? false);
    $paymentScopeLabel = $currentVendor !== null
        ? 'إعدادات التاجر المحدد'
        : ($currentDepartment !== null ? 'إعدادات القسم المحدد' : 'الإعدادات الافتراضية للسياسة');




@endphp

<div class="delivery-policy-page" id="delivery-policy-manager" data-current-department="{{ $currentDepartment }}" data-current-vendor="{{ $currentVendor }}">
    
<div class="page-heading">
        <div class="d-flex flex-column flex-lg-row align-items-lg-center justify-content-between gap-3 mb-4">
            <div>
                <h2 class="fw-bold mb-1">خدمات التوصيل</h2>
                <div class="text-muted">إدارة سياسات الشحن والشرائح المرتبطة بها.</div>
            </div>
            <div class="d-flex flex-wrap gap-2 text-start text-lg-end justify-content-lg-end">
                <span class="badge bg-primary-subtle text-primary-emphasis fs-6">{{ $departmentLabel }}</span>
                <span class="badge bg-info-subtle text-info-emphasis fs-6">{{ $vendorLabel }}</span>


            </div>
        </div>

        <div class="card shadow-sm border-0 mb-4">
            <div class="card-body">
                <div class="row g-3 align-items-end">
                    <div class="col-md-4">
                        <label for="delivery-policy-department" class="form-label fw-semibold mb-1">القسم</label>
                        <select id="delivery-policy-department" class="form-select">
                            <option value="" {{ $currentDepartment === null ? 'selected' : '' }}>جميع الأقسام</option>
                            @foreach($departments as $key => $label)
                                <option value="{{ $key }}" {{ $currentDepartment === $key ? 'selected' : '' }}>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-md-4">
                        <label for="delivery-policy-vendor" class="form-label fw-semibold mb-1">التاجر</label>
                        <select id="delivery-policy-vendor" class="form-select">
                            <option value="" {{ $currentVendor === null ? 'selected' : '' }}>جميع التجار</option>
                            @foreach($vendors as $key => $label)
                                <option value="{{ $key }}" {{ (string) $currentVendor === (string) $key ? 'selected' : '' }}>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-md-4 text-muted small">
                        اختر القسم والتاجر لمشاهدة السياسة النشطة وتعديل إعدادات الدفع المرتبطة بهما.
                    </div>
                </div>
            </div>
        </div>

        @if(session('success'))
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                {{ session('success') }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        @endif

        @if(session('error'))
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                {{ session('error') }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        @endif

        @if($errors->any())
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                <ul class="mb-0">
                    @foreach($errors->all() as $message)
                        <li>{{ $message }}</li>
                    @endforeach
                </ul>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        @endif
    </div>

    <div class="row gy-4">
        <div class="col-12 col-lg-7">
            <div class="card shadow-sm border-0 h-100">
                <div class="card-header bg-white border-bottom">
                    <h5 class="mb-0 fw-bold">إعدادات السياسة</h5>
                </div>
                <div class="card-body">
                    @if($policyModel)
                        @php
                            $formQuery = array_filter([
                                'department' => $currentDepartment,
                                'vendor' => $currentVendor,
                            ], fn ($value) => $value !== null && $value !== '');
                            $formAction = route('delivery-prices.policies.update', $policyModel) . ($formQuery ? ('?' . http_build_query($formQuery)) : '');
                        @endphp
                        <form action="{{ $formAction }}" method="POST" class="row g-3" id="delivery-policy-form">

                            @csrf
                            @method('PUT')
                            <input type="hidden" name="vendor_id" value="{{ $currentVendor ?? '' }}">
                            <input type="hidden" name="context_department" value="{{ $currentDepartment ?? '' }}">

                            <div class="col-md-6">
                                <label class="form-label">اسم السياسة</label>
                                <input type="text" name="name" class="form-control" value="{{ old('name', $policyModel->name) }}" required>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label">وضع التسعير</label>
                                <select name="mode" class="form-select" id="policy-mode-select">
                                    @foreach($policyModes as $value => $label)
                                        <option value="{{ $value }}" {{ old('mode', $policyModel->mode ?? '') === $value ? 'selected' : '' }}>{{ $label }}</option>
                                    @endforeach
                                </select>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">العملة</label>
                                <input type="text" name="currency" maxlength="3" class="form-control text-uppercase" value="{{ old('currency', $policyModel->currency) }}" required>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">الشحن المجاني</label>
                                <div class="form-check form-switch">
                                    <input class="form-check-input" type="checkbox" role="switch" id="policy-free-shipping" name="free_shipping_enabled" value="1" {{ old('free_shipping_enabled', $policyModel->free_shipping_enabled) ? 'checked' : '' }}>
                                    <label class="form-check-label" for="policy-free-shipping">تفعيل</label>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">حد الشحن المجاني</label>
                                <div class="input-group">
                                    <input type="number" step="0.01" min="0" name="free_shipping_threshold" id="policy-free-shipping-threshold" class="form-control" value="{{ old('free_shipping_threshold', $policyModel->free_shipping_threshold) }}" {{ $policyModel->free_shipping_enabled ? '' : 'disabled' }}>
                                    <span class="input-group-text text-uppercase">{{ $policyModel->currency }}</span>
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="border rounded p-3 bg-light-subtle">
                                    <div class="d-flex flex-column flex-lg-row justify-content-lg-between align-items-lg-center gap-2 mb-3">
                                        <div>
                                            <h6 class="fw-semibold mb-1">خيارات الدفع</h6>
                                            <p class="text-muted small mb-0">{{ $paymentScopeLabel }} لتحديد توافر الدفع المسبق أو عند الاستلام ورسومه.</p>
                                        </div>
                                        <span class="badge bg-secondary-subtle text-secondary-emphasis">مصدر الإعدادات الحالي: {{ $paymentSourceLabel }}</span>
                                    </div>
                                    @if($currentVendor !== null && !$vendorHasOverride)
                                        <div class="alert alert-warning small" role="alert">
                                            لا يوجد إعداد مخصص لهذا التاجر حالياً. يتم استخدام إعدادات القسم أو الإعدادات الافتراضية.
                                        </div>
                                    @elseif($currentVendor === null && !$departmentHasOverride)
                                        <div class="alert alert-info small" role="alert">
                                            لم يتم ضبط إعدادات خاصة لهذا القسم بعد، سيتم استخدام القيم الافتراضية حتى يتم حفظ التغييرات.
                                        </div>
                                    @endif
                                    <div class="row g-3 align-items-center">
                                        <div class="col-md-4">
                                            <label class="form-label" for="allow-pay-now-toggle">السماح بالدفع الآن</label>
                                            <div class="form-check form-switch">
                                                <input class="form-check-input" type="checkbox" role="switch" id="allow-pay-now-toggle" name="allow_pay_now" value="1" {{ $allowPayNowChecked ? 'checked' : '' }}>
                                                <label class="form-check-label" for="allow-pay-now-toggle">تفعيل</label>
                                            </div>
                                        </div>
                                        <div class="col-md-4">
                                            <label class="form-label" for="allow-pay-on-delivery-toggle">السماح بالدفع عند الاستلام</label>
                                            <div class="form-check form-switch">
                                                <input class="form-check-input" type="checkbox" role="switch" id="allow-pay-on-delivery-toggle" name="allow_pay_on_delivery" value="1" {{ $allowPayOnDeliveryChecked ? 'checked' : '' }}>
                                                <label class="form-check-label" for="allow-pay-on-delivery-toggle">تفعيل</label>
                                            </div>
                                        </div>
                                        <div class="col-md-4">
                                            <label class="form-label" for="policy-cod-fee">رسوم الدفع عند الاستلام</label>
                                            <div class="input-group">
                                                <input type="number" step="0.01" min="0" name="cod_fee" id="policy-cod-fee" class="form-control" value="{{ $codFeeValue }}" placeholder="بدون رسوم إضافية">
                                                <span class="input-group-text text-uppercase">{{ $policyModel->currency }}</span>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <label class="form-label">ملاحظات</label>
                                <textarea name="notes" rows="3" class="form-control" placeholder="ملاحظات داخلية حول هذه السياسة">{{ old('notes', $policyModel->description) }}</textarea>
                            </div>
                            <div class="col-12 d-flex justify-content-between align-items-center">
                                <small class="text-muted">آخر تحديث: {{ optional($policyModel->updated_at)->format('Y-m-d H:i') }}</small>
                                <button type="submit" class="btn btn-primary">حفظ إعدادات السياسة</button>
                            </div>
                        </form>
                    @else
                        <p class="text-muted mb-0">لا توجد سياسة نشطة لهذا القسم حالياً. سيتم إنشاؤها تلقائياً عند إضافة أول شريحة وزن.</p>
                    @endif
                </div>
            </div>
        </div>
        <div class="col-12 col-lg-5">
            <div class="card shadow-sm border-0 h-100" id="delivery-simulator-card">
                <div class="card-header bg-white border-bottom">
                    <h5 class="mb-0 fw-bold">محاكي تكلفة التوصيل</h5>
                </div>
                <div class="card-body">
                    <form id="delivery-simulator-form" class="row g-3">
                        <div class="col-12">
                            <label class="form-label">وضع التسعير</label>
                            <select class="form-select" name="mode" id="simulator-mode">
                                @foreach($policyModes as $value => $label)
                                    <option value="{{ $value }}" {{ ($policyModel->mode ?? '') === $value ? 'selected' : '' }}>{{ $label }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div class="col-12">
                            <label class="form-label">المسافة (كم)</label>
                            <input type="number" min="0" step="0.01" class="form-control" name="distance" required>
                        </div>
                        <div class="col-12" id="simulator-weight-wrapper">
                            <label class="form-label">الوزن (كجم)</label>
                            <input type="number" min="0" step="0.01" class="form-control" name="weight">
                        </div>
                        <div class="col-12">
                            <label class="form-label">قيمة الطلب</label>
                            <input type="number" min="0" step="0.01" class="form-control" name="order_total">
                        </div>
                        <div class="col-12 d-grid">
                            <button type="submit" class="btn btn-outline-primary">حساب التكلفة</button>
                        </div>
                    </form>
                    <div id="delivery-simulator-result" class="mt-3" hidden>
                        <div class="alert" role="alert"></div>
                        <div class="simulator-breakdown"></div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="card shadow-sm border-0 mt-4">
        <div class="card-header bg-white border-bottom d-flex justify-content-between align-items-center">
            <h5 class="mb-0 fw-bold">شرائح الوزن وقواعد المسافة</h5>
            <small class="text-muted">تأكد من عدم وجود تداخل بين الشرائح أو القواعد.</small>
        </div>
        <div class="card-body">


            @if($policyModel && count($policyRules))
                <div class="border rounded p-3 bg-white mb-4">
                    <h6 class="fw-semibold mb-3">قواعد السياسة العامة</h6>
                    <div class="table-responsive mb-3">
                        <table class="table table-bordered align-middle">
                            <thead class="table-light">
                                <tr>
                                    <th scope="col">#</th>
                                    <th scope="col">المسافة الأدنى</th>
                                    <th scope="col">المسافة الأقصى</th>
                                    <th scope="col">التسعير</th>
                                    <th scope="col">ينطبق على</th>
                                    <th scope="col">ترتيب العرض</th>
                                    <th scope="col">ملاحظات</th>
                                    <th scope="col">الحالة</th>
                                    <th scope="col" class="text-center">إجراءات</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($policyRules as $ruleIndex => $rule)
                                    @php
                                        $policyRuleTier = collect($weightTierOptions)->firstWhere('id', $rule['weight_tier_id'] ?? null);
                                        $policyRuleTierName = $policyRuleTier['name'] ?? '';
                                        $isPolicyRuleForPolicy = ($rule['applies_to'] ?? \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_POLICY) === \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_POLICY;
                                    @endphp
                                    <tr data-policy-rule="{{ $rule['id'] }}" data-distance-rule="{{ $rule['id'] }}">
                                        <td>{{ $ruleIndex + 1 }}</td>
                                        <td>
                                            <span data-distance-summary-field="min_distance">{{ number_format($rule['min_distance'], 2) }}</span>
                                            <span class="text-muted small">كم</span>
                                        </td>
                                        <td>
                                            @if($rule['max_distance'] !== null)
                                                <span data-distance-summary-field="max_distance" data-empty-text="بدون حد">{{ number_format($rule['max_distance'], 2) }}</span>
                                                <span class="text-muted small">كم</span>
                                            @else
                                                <span data-distance-summary-field="max_distance" data-empty-text="بدون حد">بدون حد</span>
                                            @endif
                                        </td>
                                        <td>
                                            <div class="distance-summary-price-amount {{ $rule['is_free_shipping'] ? 'd-none' : '' }}" data-distance-summary-field="price_amount" data-currency="{{ $rule['currency'] ?? ($policyModel->currency ?? 'SAR') }}">
                                                <span class="distance-summary-price-value" data-distance-summary-field="price_value">{{ number_format($rule['price'], 2) }}</span>
                                                <span class="text-uppercase small distance-summary-price-currency" data-distance-summary-field="price_currency">{{ $rule['currency'] ?? ($policyModel->currency ?? 'SAR') }}</span>
                                                <span class="text-muted small ms-1 distance-summary-price-unit" data-distance-summary-field="price_unit">{{ $rule['price_type'] === 'per_km' ? 'سعر لكل كيلومتر' : 'سعر ثابت' }}</span>
                                            </div>
                                            <span class="badge bg-success-subtle text-success-emphasis distance-summary-free {{ $rule['is_free_shipping'] ? '' : 'd-none' }}" data-distance-summary-field="free_badge">شحن مجاني</span>
                                            <div class="text-muted small mt-1" data-distance-summary-field="price_type_text">{{ $rule['price_type'] === 'per_km' ? 'يتم ضرب السعر بالمسافة المقطوعة.' : 'يطبق السعر كما هو على هذا المجال.' }}</div>
                                        </td>
                                        <td>
                                            <span class="badge {{ $isPolicyRuleForPolicy ? 'bg-primary-subtle text-primary-emphasis' : 'bg-warning-subtle text-warning-emphasis' }}" data-distance-summary-field="applies_to_badge" data-policy-label="السياسة" data-weight-label="شريحة وزن">{{ $isPolicyRuleForPolicy ? 'السياسة' : 'شريحة وزن' }}</span>
                                            <div class="small text-muted mt-1" data-distance-summary-field="applies_to_details" data-policy-text="تطبق القاعدة على كامل السياسة." data-weight-empty-text="اختر شريحة لتطبيق القاعدة.">{{ $isPolicyRuleForPolicy ? 'تطبق القاعدة على كامل السياسة.' : ($policyRuleTierName ?: 'اختر شريحة لتطبيق القاعدة.') }}</div>
                                        </td>
                                        <td>
                                            <span data-distance-summary-field="sort_order">{{ $rule['sort_order'] ?? 0 }}</span>
                                        </td>
                                        <td>
                                            <span class="distance-summary-notes" data-distance-summary-field="notes" data-empty-text="لا توجد ملاحظات.">{{ !empty($rule['notes']) ? $rule['notes'] : 'لا توجد ملاحظات.' }}</span>
                                        </td>
                                        <td>
                                            <span class="badge {{ $rule['status'] ? 'bg-success-subtle text-success-emphasis' : 'bg-secondary' }} distance-summary-status" data-distance-summary-field="status_badge" data-active-text="نشطة" data-inactive-text="موقوفة">{{ $rule['status'] ? 'نشطة' : 'موقوفة' }}</span>
                                        </td>
                                        <td class="text-center">
                                            <button class="btn btn-sm btn-outline-secondary mb-2 toggle-rule-form" type="button" data-target="#policy-rule-form-{{ $rule['id'] }}">تحرير</button>
                                            <form action="{{ route('delivery-prices.destroy', $rule['id']) }}" method="POST" class="d-inline" onsubmit="return confirm('هل تريد حذف هذه القاعدة؟');">
                                                @csrf
                                                @method('DELETE')
                                                <button type="submit" class="btn btn-sm btn-outline-danger">حذف</button>
                                            </form>
                                        </td>
                                    </tr>
                                    <tr id="policy-rule-form-{{ $rule['id'] }}" class="rule-edit-row collapse">
                                        <td colspan="9">
                                            <form action="{{ route('delivery-prices.update', $rule['id']) }}" method="POST" class="row g-3 align-items-end distance-rule-form" data-tier-id="policy" data-rule-id="{{ $rule['id'] }}">
                                                @csrf
                                                @method('PUT')
                                                <input type="hidden" name="policy_id" value="{{ $policyModel?->getKey() }}">
                                                <div class="col-md-3">
                                                    <label class="form-label">المسافة الأدنى</label>
                                                    <input type="number" step="0.01" min="0" name="min_distance" class="form-control" value="{{ $rule['min_distance'] }}" required>
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">المسافة الأقصى</label>
                                                    <input type="number" step="0.01" min="0" name="max_distance" class="form-control" value="{{ $rule['max_distance'] }}">
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">ينطبق على</label>
                                                    <select name="applies_to" class="form-select distance-applies-to">
                                                        <option value="{{ \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_POLICY }}" {{ $isPolicyRuleForPolicy ? 'selected' : '' }}>السياسة كاملة</option>
                                                        <option value="{{ \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_WEIGHT_TIER }}" {{ !$isPolicyRuleForPolicy ? 'selected' : '' }}>شريحة وزن محددة</option>
                                                    </select>
                                                </div>
                                                <div class="col-md-4" data-weight-tier-container>
                                                    <label class="form-label">شريحة الوزن</label>
                                                    <select name="weight_tier_id" class="form-select" data-weight-tier-field>
                                                        <option value="">اختر شريحة</option>
                                                        @foreach($weightTierOptions as $option)
                                                            <option value="{{ $option['id'] }}" {{ !$isPolicyRuleForPolicy && $rule['weight_tier_id'] === $option['id'] ? 'selected' : '' }}>{{ $option['name'] }}</option>
                                                        @endforeach
                                                    </select>
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">السعر</label>
                                                    <input type="number" step="0.01" min="0" name="price" class="form-control" value="{{ $rule['price'] }}" {{ $rule['is_free_shipping'] ? 'disabled' : '' }}>
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">نوع التسعير</label>
                                                    <select name="price_type" class="form-select distance-price-type">
                                                        <option value="flat" {{ $rule['price_type'] === 'flat' ? 'selected' : '' }}>سعر ثابت</option>
                                                        <option value="per_km" {{ $rule['price_type'] === 'per_km' ? 'selected' : '' }}>لكل كيلومتر</option>
                                                    </select>
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">العملة</label>
                                                    <input type="text" name="currency" maxlength="3" class="form-control text-uppercase" value="{{ $rule['currency'] ?? ($policyModel->currency ?? 'SAR') }}" required>
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">ترتيب العرض</label>
                                                    <input type="number" step="1" min="0" name="sort_order" class="form-control" value="{{ $rule['sort_order'] }}">
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">مجاني</label>
                                                    <div class="form-check form-switch">
                                                        <input class="form-check-input distance-free-toggle" type="checkbox" name="is_free_shipping" value="1" {{ $rule['is_free_shipping'] ? 'checked' : '' }}>
                                                    </div>
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">الحالة</label>
                                                    <div class="form-check form-switch">
                                                        <input class="form-check-input" type="checkbox" name="status" value="1" {{ $rule['status'] ? 'checked' : '' }}>
                                                    </div>
                                                </div>
                                                <div class="col-12">
                                                    <label class="form-label">ملاحظات</label>
                                                    <textarea name="notes" rows="2" class="form-control" placeholder="ملاحظات حول هذه القاعدة">{{ $rule['notes'] ?? '' }}</textarea>
                                                </div>

                                                <div class="col-12 d-flex justify-content-end">
                                                    <button type="submit" class="btn btn-sm btn-outline-primary">تحديث القاعدة</button>
                                                </div>
                                            </form>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="9" class="text-center text-muted">لا توجد قواعد سياسة بعد.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                    <div class="border rounded p-3 bg-light-subtle">
                        <h6 class="fw-semibold mb-3">إضافة قاعدة سياسة</h6>
                        <form action="{{ route('delivery-prices.store') }}" method="POST" class="row g-3 align-items-end distance-rule-form" data-tier-id="policy" data-rule-id="new-policy">
                            @csrf
                            <input type="hidden" name="policy_id" value="{{ $policyModel?->getKey() }}">
                            <div class="col-md-3">
                                <label class="form-label">المسافة الأدنى</label>
                                <input type="number" step="0.01" min="0" name="min_distance" class="form-control" required>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">المسافة الأقصى</label>
                                <input type="number" step="0.01" min="0" name="max_distance" class="form-control">
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">ينطبق على</label>
                                <select name="applies_to" class="form-select distance-applies-to">
                                    <option value="{{ \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_POLICY }}" selected>السياسة كاملة</option>
                                    <option value="{{ \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_WEIGHT_TIER }}">شريحة وزن محددة</option>
                                </select>
                            </div>
                            <div class="col-md-4" data-weight-tier-container>
                                <label class="form-label">شريحة الوزن</label>
                                <select name="weight_tier_id" class="form-select" data-weight-tier-field>
                                    <option value="">اختر شريحة</option>
                                    @foreach($weightTierOptions as $option)
                                        <option value="{{ $option['id'] }}">{{ $option['name'] }}</option>
                                    @endforeach
                                </select>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">السعر</label>
                                <input type="number" step="0.01" min="0" name="price" class="form-control">
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">نوع التسعير</label>
                                <select name="price_type" class="form-select distance-price-type">
                                    <option value="flat" selected>سعر ثابت</option>
                                    <option value="per_km">لكل كيلومتر</option>
                                </select>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">العملة</label>
                                <input type="text" name="currency" maxlength="3" class="form-control text-uppercase" value="{{ $policyModel->currency ?? 'SAR' }}" required>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">ترتيب العرض</label>
                                <input type="number" step="1" min="0" name="sort_order" class="form-control">
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">مجاني</label>
                                <div class="form-check form-switch">
                                    <input class="form-check-input distance-free-toggle" type="checkbox" name="is_free_shipping" value="1">
                                </div>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">الحالة</label>
                                <div class="form-check form-switch">
                                    <input class="form-check-input" type="checkbox" name="status" value="1" checked>
                                </div>
                            </div>
                            <div class="col-12">
                                <label class="form-label">ملاحظات</label>
                                <textarea name="notes" rows="2" class="form-control" placeholder="ملاحظات حول هذه القاعدة"></textarea>
                            </div>
                            <div class="col-12 d-flex justify-content-end">
                                <button type="submit" class="btn btn-outline-success">إضافة القاعدة</button>
                            </div>
                        </form>
                    </div>
                </div>
            @endif


            @if($policyData && count($policyData['weight_tiers']))
                <div class="accordion" id="weight-tiers-accordion">
                    @foreach($policyData['weight_tiers'] as $index => $tier)
                        <div class="accordion-item mb-3 border rounded" data-weight-tier="{{ $tier['id'] }}">
                            <h2 class="accordion-header" id="tier-heading-{{ $tier['id'] }}">
                                <button class="accordion-button {{ $index > 0 ? 'collapsed' : '' }}" type="button" data-bs-toggle="collapse" data-bs-target="#tier-collapse-{{ $tier['id'] }}" aria-expanded="{{ $index === 0 ? 'true' : 'false' }}" aria-controls="tier-collapse-{{ $tier['id'] }}">
                                    <div class="w-100 d-flex justify-content-between align-items-center">
                                        <div>
                                            <span class="fw-semibold">{{ $tier['name'] }}</span>
                                            <span class="ms-2 text-muted small">من {{ number_format($tier['min_weight'], 2) }} كجم إلى {{ $tier['max_weight'] !== null ? number_format($tier['max_weight'], 2) . ' كجم' : 'بدون حد' }}</span>
                                        </div>
                                        <span class="badge {{ $tier['status'] ? 'bg-success-subtle text-success-emphasis' : 'bg-secondary' }}">{{ $tier['status'] ? 'نشطة' : 'موقوفة' }}</span>
                                    </div>
                                </button>
                            </h2>
                            <div id="tier-collapse-{{ $tier['id'] }}" class="accordion-collapse collapse {{ $index === 0 ? 'show' : '' }}" aria-labelledby="tier-heading-{{ $tier['id'] }}" data-bs-parent="#weight-tiers-accordion">
                                <div class="accordion-body">
                                    <div class="row g-3 mb-4">
                                        <div class="col-12 col-lg-8">
                                            <form action="{{ route('delivery-prices.weight-tiers.update', $tier['id']) }}" method="POST" class="row g-3 align-items-end weight-tier-form" data-tier-id="{{ $tier['id'] }}">
                                                @csrf
                                                @method('PUT')
                                                <div class="col-md-4">
                                                    <label class="form-label">اسم الشريحة</label>
                                                    <input type="text" name="name" class="form-control" value="{{ $tier['name'] }}" required>
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">الوزن الأدنى</label>
                                                    <input type="number" step="0.01" min="0" name="min_weight" class="form-control" value="{{ $tier['min_weight'] }}" required>
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">الوزن الأقصى</label>
                                                    <input type="number" step="0.01" min="0" name="max_weight" class="form-control" value="{{ $tier['max_weight'] }}">
                                                </div>
                                                <div class="col-md-2">
                                                    <label class="form-label">الحالة</label>
                                                    <div class="form-check form-switch">
                                                        <input class="form-check-input" type="checkbox" name="status" value="1" {{ $tier['status'] ? 'checked' : '' }}>
                                                    </div>
                                                </div>




                                                <div class="col-md-4">
                                                    <label class="form-label">السعر الأساسي</label>
                                                    <div class="input-group">
                                                        <input type="number" step="0.01" min="0" name="base_price" class="form-control" value="{{ $tier['base_price'] }}">
                                                        <span class="input-group-text text-uppercase">{{ $policyModel->currency ?? 'SAR' }}</span>
                                                    </div>
                                                </div>
                                                <div class="col-md-4">
                                                    <label class="form-label">السعر لكل كيلومتر</label>
                                                    <div class="input-group">
                                                        <input type="number" step="0.01" min="0" name="price_per_km" class="form-control" value="{{ $tier['price_per_km'] }}">
                                                        <span class="input-group-text text-uppercase">{{ $policyModel->currency ?? 'SAR' }}</span>
                                                    </div>
                                                </div>
                                                <div class="col-md-4">
                                                    <label class="form-label">الرسوم الثابتة</label>
                                                    <div class="input-group">
                                                        <input type="number" step="0.01" min="0" name="flat_fee" class="form-control" value="{{ $tier['flat_fee'] }}">
                                                        <span class="input-group-text text-uppercase">{{ $policyModel->currency ?? 'SAR' }}</span>
                                                    </div>
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">ترتيب العرض</label>
                                                    <input type="number" step="1" min="0" name="sort_order" class="form-control" value="{{ $tier['sort_order'] }}">
                                                </div>
                                                <div class="col-12">
                                                    <label class="form-label">ملاحظات</label>
                                                    <textarea name="notes" rows="2" class="form-control" placeholder="ملاحظات اختيارية لهذه الشريحة">{{ $tier['notes'] }}</textarea>
                                                </div>







                                                <div class="col-12 d-flex justify-content-end gap-2">
                                                    <button type="submit" class="btn btn-sm btn-outline-primary">تحديث الشريحة</button>
                                                </div>
                                            </form>
                                            <form action="{{ route('delivery-prices.weight-tiers.destroy', $tier['id']) }}" method="POST" class="text-end mt-2" onsubmit="return confirm('هل أنت متأكد من حذف هذه الشريحة؟ سيتم حذف قواعد المسافة المرتبطة بها.');">
                                                @csrf
                                                @method('DELETE')
                                                <button type="submit" class="btn btn-sm btn-outline-danger">حذف الشريحة</button>
                                            </form>
                                        </div>
                                        <div class="col-12 col-lg-4">
                                            <div class="bg-light rounded p-3 h-100" data-tier-summary="{{ $tier['id'] }}" data-currency="{{ $policyModel->currency ?? 'SAR' }}">
                                                <div class="small text-muted fw-semibold mb-2">ملخص الشريحة</div>
                                                <dl class="mb-0 small">
                                                    <div class="d-flex justify-content-between align-items-center mb-1">
                                                        <dt class="text-muted mb-0">السعر الأساسي</dt>
                                                        <dd class="mb-0 fw-semibold" data-summary-field="base_price">{{ number_format($tier['base_price'], 2) }} {{ $policyModel->currency ?? 'SAR' }}</dd>
                                                    </div>
                                                    <div class="d-flex justify-content-between align-items-center mb-1">
                                                        <dt class="text-muted mb-0">السعر لكل كم</dt>
                                                        <dd class="mb-0" data-summary-field="price_per_km">{{ number_format($tier['price_per_km'], 2) }} {{ $policyModel->currency ?? 'SAR' }} لكل كم</dd>
                                                    </div>
                                                    <div class="d-flex justify-content-between align-items-center mb-1">
                                                        <dt class="text-muted mb-0">الرسوم الثابتة</dt>
                                                        <dd class="mb-0" data-summary-field="flat_fee">{{ number_format($tier['flat_fee'], 2) }} {{ $policyModel->currency ?? 'SAR' }}</dd>
                                                    </div>
                                                    <div class="d-flex justify-content-between align-items-center">
                                                        <dt class="text-muted mb-0">ترتيب العرض</dt>
                                                        <dd class="mb-0" data-summary-field="sort_order">{{ $tier['sort_order'] }}</dd>
                                                    </div>
                                                </dl>
                                                <div class="small text-muted mt-3">الملاحظات</div>
                                                <div class="small" data-summary-field="notes" data-empty-text="لا توجد ملاحظات.">{{ $tier['notes'] ? $tier['notes'] : 'لا توجد ملاحظات.' }}</div>
                                                
                                            </div>
                                        </div>
                                    </div>

                                    <div class="table-responsive">
                                        <table class="table table-bordered align-middle mb-3 distance-rules-table" data-tier-id="{{ $tier['id'] }}">
                                            <thead class="table-light">
                                                <tr>
                                                    <th scope="col">#</th>
                                                    <th scope="col">المسافة الأدنى</th>
                                                    <th scope="col">المسافة الأقصى</th>

                                                    <th scope="col">التسعير</th>
                                                    <th scope="col">ترتيب العرض</th>
                                                    <th scope="col">ملاحظات</th>
                                                    <th scope="col">الحالة</th>
                                                    <th scope="col" class="text-center">إجراءات</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                @forelse($tier['distance_rules'] as $ruleIndex => $rule)
                                                    <tr data-distance-rule="{{ $rule['id'] }}">
                                                        <td>{{ $ruleIndex + 1 }}</td>
                                                            <span data-distance-summary-field="min_distance">{{ number_format($rule['min_distance'], 2) }}</span>
                                                            <span class="text-muted small">كم</span>
                                                        </td>
                                                        <td>
                                                            @if($rule['max_distance'] !== null)
                                                                <span data-distance-summary-field="max_distance" data-empty-text="بدون حد">{{ number_format($rule['max_distance'], 2) }}</span>
                                                                <span class="text-muted small">كم</span>


                                                            @else
                                                                <span data-distance-summary-field="max_distance" data-empty-text="بدون حد">بدون حد</span>
                                                            @endif
                                                        </td>
                                                        <td>

                                                            <div class="distance-summary-price-amount {{ $rule['is_free_shipping'] ? 'd-none' : '' }}" data-distance-summary-field="price_amount" data-currency="{{ $rule['currency'] ?? ($policyModel->currency ?? 'SAR') }}">
                                                                <span class="distance-summary-price-value" data-distance-summary-field="price_value">{{ number_format($rule['price'], 2) }}</span>
                                                                <span class="text-uppercase small distance-summary-price-currency" data-distance-summary-field="price_currency">{{ $rule['currency'] ?? ($policyModel->currency ?? 'SAR') }}</span>
                                                                <span class="text-muted small ms-1 distance-summary-price-unit" data-distance-summary-field="price_unit">{{ $rule['price_type'] === 'per_km' ? 'سعر لكل كيلومتر' : 'سعر ثابت' }}</span>
                                                            </div>
                                                            <span class="badge bg-success-subtle text-success-emphasis distance-summary-free {{ $rule['is_free_shipping'] ? '' : 'd-none' }}" data-distance-summary-field="free_badge">شحن مجاني</span>
                                                            <div class="text-muted small mt-1" data-distance-summary-field="price_type_text">{{ $rule['price_type'] === 'per_km' ? 'يتم ضرب السعر بالمسافة المقطوعة.' : 'يطبق السعر كما هو على هذا المجال.' }}</div>
                                                        </td>
                                                        <td>
                                                            <span data-distance-summary-field="sort_order">{{ $rule['sort_order'] }}</span>
                                                        </td>
                                                        <td>
                                                            <span class="distance-summary-notes" data-distance-summary-field="notes" data-empty-text="لا توجد ملاحظات.">{{ !empty($rule['notes']) ? $rule['notes'] : 'لا توجد ملاحظات.' }}</span>
                                                        </td>
                                                        <td>
                                                            <span class="badge {{ $rule['status'] ? 'bg-success-subtle text-success-emphasis' : 'bg-secondary' }} distance-summary-status" data-distance-summary-field="status_badge" data-active-text="نشطة" data-inactive-text="موقوفة">{{ $rule['status'] ? 'نشطة' : 'موقوفة' }}</span>


                                                    </td>
                                                        <td class="text-center">
                                                            <button class="btn btn-sm btn-outline-secondary mb-2 toggle-rule-form" type="button" data-target="#rule-form-{{ $rule['id'] }}">تحرير</button>
                                                            <form action="{{ route('delivery-prices.destroy', $rule['id']) }}" method="POST" class="d-inline" onsubmit="return confirm('هل تريد حذف هذه القاعدة؟');">
                                                                @csrf
                                                                @method('DELETE')
                                                                <button type="submit" class="btn btn-sm btn-outline-danger">حذف</button>
                                                            </form>
                                                        </td>
                                                    </tr>
                                                    <tr id="rule-form-{{ $rule['id'] }}" class="rule-edit-row collapse">
                                                        <td colspan="8">
                                                            <form action="{{ route('delivery-prices.update', $rule['id']) }}" method="POST" class="row g-3 align-items-end distance-rule-form" data-tier-id="{{ $tier['id'] }}" data-rule-id="{{ $rule['id'] }}">
                                                                @csrf
                                                                @method('PUT')


                                                                 <input type="hidden" name="policy_id" value="{{ $policyModel?->getKey() }}">
                                                                <input type="hidden" name="weight_tier_id" value="{{ $tier['id'] }}" data-weight-tier-field data-weight-tier-default="{{ $tier['id'] }}">


                                                                <div class="col-md-3">
                                                                    <label class="form-label">المسافة الأدنى</label>
                                                                    <input type="number" step="0.01" min="0" name="min_distance" class="form-control" value="{{ $rule['min_distance'] }}" required>
                                                                </div>
                                                                <div class="col-md-3">
                                                                    <label class="form-label">المسافة الأقصى</label>
                                                                    <input type="number" step="0.01" min="0" name="max_distance" class="form-control" value="{{ $rule['max_distance'] }}">
                                                                </div>


                                                                <div class="col-md-3">
                                                                    <label class="form-label">ينطبق على</label>
                                                                    <select name="applies_to" class="form-select distance-applies-to">
                                                                        <option value="{{ \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_WEIGHT_TIER }}" {{ $rule['applies_to'] === \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_WEIGHT_TIER ? 'selected' : '' }}>شريحة الوزن الحالية</option>
                                                                        <option value="{{ \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_POLICY }}" {{ $rule['applies_to'] === \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_POLICY ? 'selected' : '' }}>السياسة كاملة</option>
                                                                    </select>
                                                                </div>

                                                                <div class="col-md-3">
                                                                    <label class="form-label">السعر</label>
                                                                    <input type="number" step="0.01" min="0" name="price" class="form-control" value="{{ $rule['price'] }}" {{ $rule['is_free_shipping'] ? 'disabled' : '' }}>
                                                                </div>

                                                                <div class="col-md-3">
                                                                    <label class="form-label">نوع التسعير</label>
                                                                    <select name="price_type" class="form-select distance-price-type">
                                                                        <option value="flat" {{ $rule['price_type'] === 'flat' ? 'selected' : '' }}>سعر ثابت</option>
                                                                        <option value="per_km" {{ $rule['price_type'] === 'per_km' ? 'selected' : '' }}>لكل كيلومتر</option>
                                                                    </select>
                                                                </div>
                                                                <div class="col-md-3">



                                                                    <label class="form-label">العملة</label>
                                                                    <input type="text" name="currency" maxlength="3" class="form-control text-uppercase" value="{{ $rule['currency'] ?? ($policyModel->currency ?? 'SAR') }}" required>
                                                                </div>
                                                                <div class="col-md-3">
                                                                    <label class="form-label">ترتيب العرض</label>
                                                                    <input type="number" step="1" min="0" name="sort_order" class="form-control" value="{{ $rule['sort_order'] }}">
                                                                </div>

                                                                <div class="col-md-3">

                                                                    <label class="form-label">مجاني</label>
                                                                    
                                                                    <div class="form-check form-switch">

                                                                    <input class="form-check-input distance-free-toggle" type="checkbox" name="is_free_shipping" value="1" {{ $rule['is_free_shipping'] ? 'checked' : '' }}>

                                                                </div>
                                                                </div>
                                                                <div class="col-md-3">


 <label class="form-label">الحالة</label>
                                                                    <div class="form-check form-switch">
                                                                        <input class="form-check-input" type="checkbox" name="status" value="1" {{ $rule['status'] ? 'checked' : '' }}>
                                                                    </div>
                                                                </div>

                                                                <div class="col-12">
                                                                    <label class="form-label">ملاحظات</label>
                                                                    <textarea name="notes" rows="2" class="form-control" placeholder="ملاحظات حول هذه القاعدة">{{ $rule['notes'] ?? '' }}</textarea>
                                                                </div>


                                                                <div class="col-12 d-flex justify-content-end">
                                                                    <button type="submit" class="btn btn-sm btn-outline-primary">تحديث القاعدة</button>
                                                                </div>
                                                            </form>
                                                        </td>
                                                    </tr>
                                                @empty
                                                    <tr>
                                                        <td colspan="8" class="text-center text-muted">لا توجد قواعد مسافة بعد لهذه الشريحة.</td>

                                                    </tr>
                                                @endforelse
                                            </tbody>
                                        </table>
                                    </div>

                                    <div class="border rounded p-3 bg-light-subtle">
                                        <h6 class="fw-semibold mb-3">إضافة قاعدة مسافة</h6>
                                        <form action="{{ route('delivery-prices.store') }}" method="POST" class="row g-3 align-items-end distance-rule-form" data-tier-id="{{ $tier['id'] }}" data-rule-id="new">
                                            @csrf
                                            <input type="hidden" name="policy_id" value="{{ $policyModel?->getKey() }}">
                                            <input type="hidden" name="weight_tier_id" value="{{ $tier['id'] }}" data-weight-tier-field data-weight-tier-default="{{ $tier['id'] }}">                                            <div class="col-md-3">
                                                <label class="form-label">المسافة الأدنى</label>
                                                <input type="number" step="0.01" min="0" name="min_distance" class="form-control" required>
                                            </div>
                                            <div class="col-md-3">
                                                <label class="form-label">المسافة الأقصى</label>
                                                <input type="number" step="0.01" min="0" name="max_distance" class="form-control">
                                            </div>


                                            <div class="col-md-3">
                                                <label class="form-label">ينطبق على</label>
                                                <select name="applies_to" class="form-select distance-applies-to">
                                                    <option value="{{ \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_WEIGHT_TIER }}" selected>شريحة الوزن الحالية</option>
                                                    <option value="{{ \App\Models\Pricing\PricingDistanceRule::APPLIES_TO_POLICY }}">السياسة كاملة</option>
                                                </select>
                                            </div>

                                            <div class="col-md-3">
                                                <label class="form-label">السعر</label>
                                                <input type="number" step="0.01" min="0" name="price" class="form-control">
                                            </div>

                                            <div class="col-md-3">
                                                <label class="form-label">نوع التسعير</label>
                                                <select name="price_type" class="form-select distance-price-type">
                                                    <option value="flat" selected>سعر ثابت</option>
                                                    <option value="per_km">لكل كيلومتر</option>
                                                </select>
                                            </div>
                                            <div class="col-md-3">

                                                <label class="form-label">العملة</label>
                                                <input type="text" name="currency" maxlength="3" class="form-control text-uppercase" value="{{ $policyModel->currency ?? 'SAR' }}" required>
                                            </div>

                                            <div class="col-md-3">
                                                <label class="form-label">ترتيب العرض</label>
                                                <input type="number" step="1" min="0" name="sort_order" class="form-control">
                                            </div>
                                            <div class="col-md-3">

                                                <label class="form-label">مجاني</label>
                                                <div class="form-check form-switch">
                                                    <input class="form-check-input distance-free-toggle" type="checkbox" name="is_free_shipping" value="1">
                                                </div>
                                            </div>

                                            <div class="col-12">
                                                <label class="form-label">ملاحظات</label>
                                                <textarea name="notes" rows="2" class="form-control" placeholder="ملاحظات حول هذه القاعدة"></textarea>
                                            </div>

                                            <div class="col-12 d-flex justify-content-end">
                                                <button type="submit" class="btn btn-outline-success">إضافة القاعدة</button>
                                            </div>
                                        </form>
                                    </div>
                                </div>
                            </div>
                        </div>
                    @endforeach
                </div>
            @else
                <p class="text-muted mb-4">لم يتم تعريف أي شريحة وزن بعد. ابدأ بإضافة شريحة جديدة.</p>
            @endif

            @if($policyModel)
                <div class="border rounded p-4 mt-4 bg-white">
                    <h6 class="fw-semibold mb-3">إضافة شريحة وزن جديدة</h6>
                    <form action="{{ route('delivery-prices.weight-tiers.store', $policyModel) }}" method="POST" class="row g-3 align-items-end weight-tier-form" data-tier-id="new">
                        @csrf
                        <div class="col-md-4">
                            <label class="form-label">اسم الشريحة</label>
                            <input type="text" name="name" class="form-control" placeholder="مثال: خفيفة" required>
                        </div>
                        <div class="col-md-3">
                            <label class="form-label">الوزن الأدنى</label>
                            <input type="number" step="0.01" min="0" name="min_weight" class="form-control" required>
                        </div>
                        <div class="col-md-3">
                            <label class="form-label">الوزن الأقصى</label>
                            <input type="number" step="0.01" min="0" name="max_weight" class="form-control">
                        </div>
                        <div class="col-md-2">
                            <label class="form-label">الحالة</label>
                            <div class="form-check form-switch">
                                <input class="form-check-input" type="checkbox" name="status" value="1" checked>
                            </div>
                        </div>



                        <div class="col-md-3">
                            <label class="form-label">السعر الأساسي</label>
                            <div class="input-group">
                                <input type="number" step="0.01" min="0" name="base_price" class="form-control" value="{{ old('base_price') }}">
                                <span class="input-group-text text-uppercase">{{ $policyModel->currency ?? 'SAR' }}</span>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <label class="form-label">السعر لكل كيلومتر</label>
                            <div class="input-group">
                                <input type="number" step="0.01" min="0" name="price_per_km" class="form-control" value="{{ old('price_per_km') }}">
                                <span class="input-group-text text-uppercase">{{ $policyModel->currency ?? 'SAR' }}</span>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <label class="form-label">الرسوم الثابتة</label>
                            <div class="input-group">
                                <input type="number" step="0.01" min="0" name="flat_fee" class="form-control" value="{{ old('flat_fee') }}">
                                <span class="input-group-text text-uppercase">{{ $policyModel->currency ?? 'SAR' }}</span>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <label class="form-label">ترتيب العرض</label>
                            <input type="number" step="1" min="0" name="sort_order" class="form-control" value="{{ old('sort_order') }}">
                        </div>
                        <div class="col-12">
                            <label class="form-label">ملاحظات</label>
                            <textarea name="notes" rows="2" class="form-control" placeholder="ملاحظات داخلية">{{ old('notes') }}</textarea>
                        </div>







                        <div class="col-12 d-flex justify-content-end">
                            <button type="submit" class="btn btn-success">إضافة شريحة الوزن</button>
                        </div>
                    </form>
                </div>
            @endif
        </div>
    </div>
</div>

<script type="application/json" id="delivery-policy-state">@json($policyData)</script>