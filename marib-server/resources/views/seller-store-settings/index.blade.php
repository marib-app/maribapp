@extends('layouts.main')

@section('title')
    {{ __('إعدادات المتجر الإلكتروني') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
        </div>
    </div>
@endsection

@section('css')
    <style>
        .storefront-settings-page {
            font-family: 'Cairo', 'Tajawal', 'Noto Sans Arabic', 'Tahoma', 'Arial', sans-serif;
        }
        .storefront-hero {
            background: linear-gradient(135deg, #eef4ff 0%, #ffffff 60%);
            border: 1px solid #e6edf7;
        }
        .pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 10px;
            border-radius: 999px;
            background: #f5f7fb;
            border: 1px solid #e6edf7;
            font-size: 12px;
            color: #0d6efd;
        }
    </style>
@endsection

@section('content')
    <section class="section storefront-settings-page">
        <div class="card border-0 shadow-sm">
            <div class="card-body">
                <ul class="nav nav-tabs" id="sellerStoreSettingsTabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active" id="seller-store-terms-tab" data-bs-toggle="tab" data-bs-target="#seller-store-terms" type="button" role="tab">
                            {{ __('شروط وأحكام المتجر') }}
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="seller-store-gateways-tab" data-bs-toggle="tab" data-bs-target="#seller-store-gateways" type="button" role="tab">
                            {{ __('بوابات الدفع') }}
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="storefront-ui-tab" data-bs-toggle="tab" data-bs-target="#storefront-ui" type="button" role="tab">
                            {{ __('واجهة المتجر (فئات + عروض + تخفيضات)') }}
                        </button>
                    </li>
                </ul>

                <div class="tab-content mt-4" id="sellerStoreSettingsTabsContent">
                    {{-- شروط المتجر --}}
                    <div class="tab-pane fade show active" id="seller-store-terms" role="tabpanel">
                        <form class="create-form-without-reset" action="{{ route('seller-store-settings.terms.store') }}" method="post">
                            @csrf
                            <div class="mb-3">
                                <label class="form-label" for="store_terms_editor">{{ __('نص الشروط والأحكام') }}</label>
                                <textarea id="store_terms_editor" name="store_terms_conditions" class="form-control" rows="12">{{ old('store_terms_conditions', $storeTerms) }}</textarea>
                            </div>
                            <div class="d-flex justify-content-end">
                                <button type="submit" class="btn btn-primary">{{ __('حفظ الشروط') }}</button>
                            </div>
                        </form>
                    </div>

                    {{-- بوابات الدفع --}}
                    <div class="tab-pane fade" id="seller-store-gateways" role="tabpanel">
                        <div class="row g-3">
                            <div class="col-12 d-flex justify-content-between align-items-center">
                                <div class="text-muted">{{ __('إدارة بوابات الدفع الخاصة بالمتاجر.') }}</div>
                                <a href="{{ route('seller-store-settings.gateways.index') }}" class="btn btn-primary">{{ __('إدارة البوابات') }}</a>
                            </div>
                            <div class="col-12">
                                <div class="table-responsive">
                                    <table class="table table-striped align-middle mb-0">
                                        <thead>
                                        <tr>
                                            <th>{{ __('البوابة') }}</th>
                                            <th>{{ __('الحالة') }}</th>
                                            <th>{{ __('حسابات التاجر') }}</th>
                                            <th>{{ __('آخر تحديث') }}</th>
                                            <th>{{ __('ملاحظات') }}</th>
                                        </tr>
                                        </thead>
                                        <tbody>
                                        @forelse ($storeGateways as $gateway)
                                            @php
                                                $updatedAt = $gateway->updated_at;
                                                $lastUpdated = $updatedAt
                                                    ? $updatedAt->timezone(config('app.timezone', 'UTC'))->format('M j, Y H:i')
                                                    : __('Never');
                                                $notes = data_get($gateway, 'notes', data_get($gateway, 'note'));
                                            @endphp
                                            <tr>
                                                <td>
                                                    <div class="d-flex align-items-center gap-2">
                                                        @if($gateway->logo_url)
                                                            <img src="{{ $gateway->logo_url }}" alt="{{ $gateway->name }}" class="rounded border" style="width:40px;height:40px;object-fit:contain;">
                                                        @else
                                                            <span class="badge bg-light text-body-secondary border">{{ \Illuminate\Support\Str::upper(\Illuminate\Support\Str::limit($gateway->name, 3, '')) }}</span>
                                                        @endif
                                                        <div>
                                                            <div class="fw-semibold">{{ $gateway->name }}</div>
                                                            <div class="small text-muted text-break">{{ __('ID') }}: {{ $gateway->id }}</div>
                                                        </div>
                                                    </div>
                                                </td>
                                                <td>@if($gateway->is_active)<span class="badge bg-success">{{ __('مفعّل') }}</span>@else<span class="badge bg-secondary">{{ __('معطّل') }}</span>@endif</td>
                                                <td class="text-nowrap">{{ $gateway->accounts_count }}</td>
                                                <td class="text-nowrap">{{ $lastUpdated }}</td>
                                                <td class="text-break">@if(!empty($notes)){!! nl2br(e($notes)) !!}@else<span class="text-muted">{{ __('لا توجد ملاحظات') }}</span>@endif</td>
                                            </tr>
                                        @empty
                                            <tr><td colspan="5" class="text-center text-muted py-4">{{ __('لا توجد بوابات مضافة بعد.') }}</td></tr>
                                        @endforelse
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                    {{-- واجهة المتجر: فئات + ترويج + عروض + تخفيضات في نفس التبويب --}}
                    <div class="tab-pane fade" id="storefront-ui" role="tabpanel">
                        <form action="{{ route('seller-store-settings.ui.store') }}" method="post" id="storefrontUiForm">
                            @csrf
                            <textarea id="featured_categories" name="featured_categories" class="d-none"></textarea>
                            <textarea id="promotion_slots" name="promotion_slots" class="d-none"></textarea>
                            <textarea id="new_offers_items" name="new_offers_items" class="d-none"></textarea>
                            <textarea id="discount_items" name="discount_items" class="d-none"></textarea>

                            <div class="row g-4">
                                <div class="col-12">
                                    <div class="p-4 rounded-4 shadow-sm storefront-hero">
                                        <div class="d-flex flex-wrap align-items-center gap-3">
                                            <div class="rounded-circle d-flex align-items-center justify-content-center" style="width:52px;height:52px;background:#0d6efd1a;">
                                                <i class="bi bi-layout-text-window-reverse text-primary fs-4"></i>
                                            </div>
                                            <div class="flex-grow-1">
                                                <div class="fw-semibold fs-5 mb-1">{{ __('تجربة متجر احترافية دون JSON يدوي') }}</div>
                                                <div class="text-muted small">{{ __('شريط فئات + بطاقات ترويج + عروض + تخفيضات في واجهة واحدة') }}</div>
                                            </div>
                                            <div class="d-flex gap-2 flex-wrap">
                                                <span class="pill"><i class="bi bi-shop"></i>{{ __('متاجر إلكترونية') }}</span>
                                                <span class="pill"><i class="bi bi-sliders"></i>{{ __('شريط فئات') }}</span>
                                                <span class="pill"><i class="bi bi-megaphone"></i>{{ __('بطاقات عروض') }}</span>
                                                <span class="pill"><i class="bi bi-tags"></i>{{ __('تخفيضات') }}</span>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12">
                                    <div class="card border-0 shadow-sm">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between align-items-center mb-3">
                                                <div>
                                                    <div class="fw-semibold">{{ __('فئات قسم المتجر (عرض فقط)') }}</div>
                                                    <div class="text-muted small">{{ __('ترتيب بالأب ثم الاسم، مع إظهار الصورة إن وجدت.') }}</div>
                                                </div>
                                            </div>
                                            @if(($categories ?? collect())->count() > 0)
                                                <div class="row g-3">
                                                    @foreach($categories as $cat)
                                                        <div class="col-12 col-md-6 col-lg-4">
                                                            <div class="border rounded-3 h-100 p-3 d-flex gap-3 align-items-center">
                                                                <div class="flex-shrink-0">
                                                                    @if(!empty($cat->image))
                                                                        <img src="{{ $cat->image }}" alt="{{ $cat->name }}" class="rounded" style="width:58px;height:58px;object-fit:cover;">
                                                                    @else
                                                                        <div class="rounded bg-light d-flex align-items-center justify-content-center" style="width:58px;height:58px;">
                                                                            <i class="bi bi-folder text-muted"></i>
                                                                        </div>
                                                                    @endif
                                                                </div>
                                                                <div class="flex-grow-1">
                                                                    <div class="fw-semibold text-truncate" title="{{ $cat->name }}">{{ $cat->name }}</div>
                                                                    <div class="text-muted small text-truncate" title="{{ $cat->slug }}">{{ $cat->slug }}</div>
                                                                    @if($cat->parent_category_id)
                                                                        <div class="badge bg-light text-muted border">{{ __('أب') }}: {{ $cat->parent_category_id }}</div>
                                                                    @else
                                                                        <div class="badge bg-primary-subtle text-primary border">{{ __('جذر المتجر') }}</div>
                                                                    @endif
                                                                </div>
                                                            </div>
                                                        </div>
                                                    @endforeach
                                                </div>
                                            @else
                                                <div class="alert alert-warning mb-0">{{ __('لم يتم العثور على فئات لقسم المتجر.') }}</div>
                                            @endif
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-4">
                                    <div class="card shadow-sm h-100 border-0">
                                        <div class="card-body">
                                            <div class="d-flex align-items-start gap-2 mb-3">
                                                <div class="rounded-circle bg-primary-subtle text-primary d-flex align-items-center justify-content-center" style="width:38px;height:38px;">
                                                    <i class="bi bi-toggle2-on"></i>
                                                </div>
                                                <div>
                                                    <div class="fw-semibold">{{ __('تفعيل واجهة المتجر المخصصة') }}</div>
                                                    <div class="text-muted small">{{ __('إيقافها يعيد الواجهة للوضع الافتراضي.') }}</div>
                                                </div>
                                            </div>
                                            <div class="form-check form-switch mb-4">
                                                <input class="form-check-input" type="checkbox" role="switch" id="storefront_ui_enabled" name="enabled" value="1" {{ $uiSetting->enabled ? 'checked' : '' }}>
                                                <label class="form-check-label" for="storefront_ui_enabled">{{ __('تشغيل / إيقاف') }}</label>
                                            </div>
                                            <div class="vstack gap-2 small text-muted">
                                                <div class="d-flex align-items-center gap-2"><i class="bi bi-collection-play text-primary"></i><span>{{ __('شريط فئات أفقي داخل التطبيق.') }}</span></div>
                                                <div class="d-flex align-items-center gap-2"><i class="bi bi-megaphone text-success"></i><span>{{ __('بطاقات عروض بين المتاجر كل X بطاقات.') }}</span></div>
                                                <div class="d-flex align-items-center gap-2"><i class="bi bi-magic text-warning"></i><span>{{ __('الحقول الفارغة يتم تجاهلها تلقائياً عند الحفظ.') }}</span></div>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-8">
                                    <div class="card shadow-sm mb-4 border-0">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between align-items-center mb-3">
                                                <div>
                                                    <div class="fw-semibold">{{ __('شريط الفئات المميزة') }}</div>
                                                    <div class="text-muted small">{{ __('اختر الفئات التي تظهر كشرائح قابلة للتمرير.') }}</div>
                                                </div>
                                                <button type="button" class="btn btn-sm btn-outline-primary" id="addCategoryBtn">
                                                    {{ __('إضافة فئة') }}
                                                </button>
                                            </div>
                                            <div id="featuredCategoriesList" class="d-grid gap-3"></div>
                                            <div class="text-muted small mt-3">{{ __('اختر الفئة من القائمة. اللون اختياري للتمييز.') }}</div>
                                        </div>
                                    </div>

                                    <div class="card shadow-sm border-0">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between align-items-center mb-3">
                                                <div>
                                                    <div class="fw-semibold">{{ __('بطاقات العروض بين المتاجر') }}</div>
                                                    <div class="text-muted small">{{ __('تظهر بطاقة ترويج بعد عدد معين من بطاقات المتاجر.') }}</div>
                                                </div>
                                                <button type="button" class="btn btn-sm btn-outline-primary" id="addPromoBtn">
                                                    {{ __('إضافة ترويج') }}
                                                </button>
                                            </div>
                                            <div id="promotionCardsList" class="d-grid gap-3"></div>
                                            <div class="text-muted small mt-3">{{ __('التكرار يحدد كل كم بطاقة متجر يظهر هذا الترويج.') }}</div>
                                        </div>
                                    </div>

                                    <div class="card shadow-sm border-0 mt-4">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between align-items-center mb-3">
                                                <div>
                                                    <div class="fw-semibold">{{ __('عروض جديدة داخل الواجهة') }}</div>
                                                    <div class="text-muted small">{{ __('اختر إعلانات متاجر لإبرازها كعروض جديدة.') }}</div>
                                                </div>
                                                <button type="button" class="btn btn-sm btn-primary" data-select-items="offers">
                                                    <i class="bi bi-plus"></i> {{ __('إضافة عرض') }}
                                                </button>
                                            </div>
                                            <div id="offersList" class="d-grid gap-2"></div>
                                            <div class="text-muted small mt-2">{{ __('يتم الحفظ مع إعدادات الواجهة مباشرة.') }}</div>
                                        </div>
                                    </div>

                                    <div class="card shadow-sm border-0 mt-4">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between align-items-center mb-3">
                                                <div>
                                                    <div class="fw-semibold">{{ __('تخفيضات مميزة داخل الواجهة') }}</div>
                                                    <div class="text-muted small">{{ __('اختر إعلانات متاجر لتظهر كبطاقات تخفيضات.') }}</div>
                                                </div>
                                                <button type="button" class="btn btn-sm btn-success" data-select-items="discounts">
                                                    <i class="bi bi-plus"></i> {{ __('إضافة تخفيض') }}
                                                </button>
                                            </div>
                                            <div id="discountsList" class="d-grid gap-2"></div>
                                            <div class="text-muted small mt-2">{{ __('يتم الحفظ مع إعدادات الواجهة مباشرة.') }}</div>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 d-flex justify-content-end">
                                    <button type="submit" class="btn btn-primary px-4">{{ __('حفظ إعدادات الواجهة') }}</button>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </section>

    {{-- Modal اختيار الإعلان --}}
    <div class="modal fade" id="itemsPickerModal" tabindex="-1" aria-labelledby="itemsPickerLabel" aria-hidden="true">
        <div class="modal-dialog modal-lg modal-dialog-scrollable">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="itemsPickerLabel">{{ __('اختر إعلاناً من المتاجر') }}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="input-group mb-3">
                        <span class="input-group-text"><i class="bi bi-search"></i></span>
                        <input type="text" class="form-control" id="itemsSearchInput" placeholder="{{ __('ابحث بالاسم') }}">
                        <button class="btn btn-outline-primary" type="button" id="itemsSearchBtn">{{ __('بحث') }}</button>
                    </div>
                    <div id="itemsResults" class="list-group"></div>
                    <div class="text-muted small mt-2">{{ __('يتم جلب إعلانات المتاجر فقط.') }}</div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">{{ __('إغلاق') }}</button>
                </div>
            </div>
        </div>
    </div>
@endsection
@push('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            if (typeof tinymce !== 'undefined') {
                tinymce.init({
                    selector: '#store_terms_editor',
                    height: 350,
                    menubar: false,
                    directionality: document.documentElement.getAttribute('dir') || 'ltr',
                    plugins: ['advlist autolink lists link charmap preview anchor', 'searchreplace visualblocks code fullscreen', 'insertdatetime media table paste code help wordcount'],
                    toolbar: 'undo redo | formatselect | bold italic backcolor | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | removeformat | help'
                });
            }

            const storeCategories = @json($categories ?? []);
            const initialCategories = @json(old('featured_categories') ? json_decode(old('featured_categories'), true) : $uiSetting->featured_categories);
            const initialPromotions = @json(old('promotion_slots') ? json_decode(old('promotion_slots'), true) : $uiSetting->promotion_slots);
            const initialOffers = @json(old('new_offers_items') ? json_decode(old('new_offers_items'), true) : $uiSetting->new_offers_items);
            const initialDiscounts = @json(old('discount_items') ? json_decode(old('discount_items'), true) : $uiSetting->discount_items);
            const itemsEndpoint = "{{ route('seller-store-settings.items') }}";

            const catList = document.getElementById('featuredCategoriesList');
            const promoList = document.getElementById('promotionCardsList');
            const hiddenCats = document.getElementById('featured_categories');
            const hiddenPromos = document.getElementById('promotion_slots');
            const hiddenOffers = document.getElementById('new_offers_items');
            const hiddenDiscounts = document.getElementById('discount_items');
            const form = document.getElementById('storefrontUiForm');
            const offersListEl = document.getElementById('offersList');
            const discountsListEl = document.getElementById('discountsList');
            const modalEl = document.getElementById('itemsPickerModal');
            const itemsModal = (modalEl && window.bootstrap && window.bootstrap.Modal)
                ? new bootstrap.Modal(modalEl)
                : {
                    show() { if (modalEl) { modalEl.classList.add('show'); modalEl.style.display = 'block'; } },
                    hide() { if (modalEl) { modalEl.classList.remove('show'); modalEl.style.display = 'none'; } },
                };
            const itemsResults = document.getElementById('itemsResults');
            const itemsSearchInput = document.getElementById('itemsSearchInput');
            const itemsSearchBtn = document.getElementById('itemsSearchBtn');

            let pickerTarget = null;
            let offersSelection = Array.isArray(initialOffers) ? initialOffers : [];
            let discountsSelection = Array.isArray(initialDiscounts) ? initialDiscounts : [];

            function renderCategoryOptions(selected) {
                const placeholder = "{{ __('اختر فئة') }}";
                const safeSelected = (selected ?? '').toString();
                const options = storeCategories.map(cat => {
                    const val = (cat.id ?? cat.slug ?? '').toString();
                    const label = `${cat.name ?? cat.slug ?? ''} (${cat.slug ?? '#' + cat.id ?? ''})`;
                    const isSelected = val === safeSelected || (cat.slug && cat.slug.toString() === safeSelected);
                    return `<option value="${val}" data-slug="${cat.slug ?? ''}" ${isSelected ? 'selected' : ''}>${label}</option>`;
                }).join('');
                return `<option value="">${placeholder}</option>${options}`;
            }

            function buildCategoryCard(data = {}) {
                if (!catList) return;
                const idx = catList.children.length + 1;
                const card = document.createElement('div');
                card.className = 'border rounded p-3 bg-light';
                card.dataset.catCard = '1';
                card.innerHTML = `
                    <div class="d-flex justify-content-between align-items-start gap-2 mb-2">
                        <div class="fw-semibold">{{ __('فئة') }} #${idx}</div>
                        <button type="button" class="btn btn-sm btn-outline-danger" aria-label="Remove" onclick="this.closest('[data-cat-card]').remove()">&times;</button>
                    </div>
                    <div class="row g-2">
                        <div class="col-md-6">
                            <label class="form-label small mb-1">{{ __('اسم العرض في التطبيق') }}</label>
                            <input type="text" class="form-control form-control-sm js-cat-label" placeholder="{{ __('مثل: عروض التوفير') }}" value="${data.label ?? ''}">
                        </div>
                        <div class="col-md-6">
                            <label class="form-label small mb-1">{{ __('الفئة') }}</label>
                            <select class="form-select form-select-sm js-cat-id">${renderCategoryOptions(data.id ?? data.slug ?? '')}</select>
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small mb-1">{{ __('لون اختياري') }}</label>
                            <input type="color" class="form-control form-control-color form-control-sm js-cat-color" value="${data.color ?? '#f97316'}">
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small mb-1">{{ __('أيقونة (اختياري)') }}</label>
                            <input type="text" class="form-control form-control-sm js-cat-icon" placeholder="fa-solid fa-tags" value="${data.icon ?? ''}">
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small mb-1">{{ __('ترتيب العرض') }}</label>
                            <input type="number" min="1" class="form-control form-control-sm js-cat-order" value="${data.order ?? idx}">
                        </div>
                    </div>
                `;
                catList.appendChild(card);
            }

            function buildPromoCard(slot = {}) {
                if (!promoList) return;
                const item = Array.isArray(slot.items) && slot.items.length ? slot.items[0] : {};
                const idx = promoList.children.length + 1;
                const card = document.createElement('div');
                card.className = 'border rounded p-3';
                card.dataset.promoCard = '1';
                card.innerHTML = `
                    <div class="d-flex justify-content-between align-items-start gap-2 mb-2">
                        <div class="fw-semibold">{{ __('ترويج') }} #${idx}</div>
                        <button type="button" class="btn btn-sm btn-outline-danger" aria-label="Remove" onclick="this.closest('[data-promo-card]').remove()">&times;</button>
                    </div>
                    <div class="row g-2">
                        <div class="col-md-4">
                            <label class="form-label small mb-1">{{ __('يظهر بعد كل') }}</label>
                            <div class="input-group input-group-sm">
                                <input type="number" min="1" class="form-control js-promo-frequency" value="${slot.frequency ?? 4}">
                                <span class="input-group-text">{{ __('بطاقة متجر') }}</span>
                            </div>
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small mb-1">{{ __('نوع الهدف') }}</label>
                            <select class="form-select form-select-sm js-promo-type">
                                <option value="ad" ${item.type === 'ad' ? 'selected' : ''}>{{ __('إعلان') }}</option>
                                <option value="store" ${item.type === 'store' ? 'selected' : ''}>{{ __('متجر') }}</option>
                                <option value="custom" ${item.type === 'custom' ? 'selected' : ''}>{{ __('مخصص') }}</option>
                            </select>
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small mb-1">{{ __('معرّف/Slug الهدف') }}</label>
                            <input type="text" class="form-control form-control-sm js-promo-target" placeholder="123 أو my-store" value="${item.id ?? item.slug ?? ''}">
                        </div>
                        <div class="col-md-6">
                            <label class="form-label small mb-1">{{ __('عنوان الترويج') }}</label>
                            <input type="text" class="form-control form-control-sm js-promo-title" placeholder="{{ __('مثال: خصم 20% هذا الأسبوع') }}" value="${item.title ?? ''}">
                        </div>
                        <div class="col-md-6">
                            <label class="form-label small mb-1">{{ __('وصف مختصر') }}</label>
                            <input type="text" class="form-control form-control-sm js-promo-subtitle" placeholder="{{ __('مثال: توصيل مجاني على الطلبات') }}" value="${item.subtitle ?? ''}">
                        </div>
                        <div class="col-12">
                            <label class="form-label small mb-1">{{ __('رابط صورة الترويج (اختياري)') }}</label>
                            <input type="text" class="form-control form-control-sm js-promo-image" placeholder="https://example.com/banner.jpg" value="${item.image ?? ''}">
                        </div>
                    </div>
                `;
                promoList.appendChild(card);
            }

            document.getElementById('addCategoryBtn')?.addEventListener('click', (e) => { e.preventDefault(); buildCategoryCard(); });
            document.getElementById('addPromoBtn')?.addEventListener('click', (e) => { e.preventDefault(); buildPromoCard(); });
            document.querySelectorAll('[data-select-items]').forEach(btn => {
                btn.addEventListener('click', () => {
                    pickerTarget = btn.getAttribute('data-select-items');
                    if (itemsSearchInput) itemsSearchInput.value = '';
                    if (itemsResults) itemsResults.innerHTML = '';
                    itemsModal.show();
                    itemsSearchInput?.focus();
                });
            });

            (initialCategories || []).forEach(cat => buildCategoryCard(cat));
            (initialPromotions || []).forEach(slot => buildPromoCard(slot));
            if (catList && catList.children.length === 0) buildCategoryCard();
            if (promoList && promoList.children.length === 0) buildPromoCard();

            function renderSelection(target, data) {
                const container = target === 'offers' ? offersListEl : discountsListEl;
                if (!container) return;
                container.innerHTML = '';
                data.forEach((item) => {
                    const row = document.createElement('div');
                    row.className = 'border rounded p-2 d-flex align-items-center gap-3';
                    row.innerHTML = `
                        <div class="flex-shrink-0">
                            ${item.thumbnail ? `<img src="${item.thumbnail}" alt="${item.name}" class="rounded" style="width:48px;height:48px;object-fit:cover;">` : '<div class="rounded bg-light" style="width:48px;height:48px;"></div>'}
                        </div>
                        <div class="flex-grow-1">
                            <div class="fw-semibold text-truncate">${item.name ?? ''}</div>
                            ${item.price ? `<div class="text-muted small">${item.price}</div>` : ''}
                        </div>
                        <button type="button" class="btn btn-sm btn-outline-danger" data-remove-item="${item.id}" data-target="${target}">&times;</button>
                    `;
                    container.appendChild(row);
                });
            }

            renderSelection('offers', offersSelection);
            renderSelection('discounts', discountsSelection);

            document.addEventListener('click', (e) => {
                const btn = e.target.closest('[data-remove-item]');
                if (!btn) return;
                const id = btn.getAttribute('data-remove-item');
                const target = btn.getAttribute('data-target');
                if (target === 'offers') {
                    offersSelection = offersSelection.filter(i => i.id != id);
                    renderSelection('offers', offersSelection);
                } else if (target === 'discounts') {
                    discountsSelection = discountsSelection.filter(i => i.id != id);
                    renderSelection('discounts', discountsSelection);
                }
            });

            async function searchItems(query) {
                if (!itemsResults) return;
                itemsResults.innerHTML = '<div class="text-center py-3 text-muted">{{ __('جاري البحث...') }}</div>';
                try {
                    const resp = await fetch(`${itemsEndpoint}?q=${encodeURIComponent(query || '')}`);
                    const json = await resp.json();
                    const list = Array.isArray(json.data) ? json.data : [];
                    if (!list.length) {
                        itemsResults.innerHTML = '<div class="text-center text-muted py-3">{{ __('لا توجد نتائج') }}</div>';
                        return;
                    }
                    itemsResults.innerHTML = '';
                    list.forEach(item => {
                        const el = document.createElement('button');
                        el.type = 'button';
                        el.className = 'list-group-item list-group-item-action d-flex align-items-center gap-3';
                        el.innerHTML = `
                            ${item.thumbnail ? `<img src="${item.thumbnail}" class="rounded" style="width:48px;height:48px;object-fit:cover;">` : '<div class="rounded bg-light" style="width:48px;height:48px;"></div>'}
                            <div class="flex-grow-1 text-start">
                                <div class="fw-semibold">${item.name ?? ''}</div>
                                ${item.price ? `<div class="text-muted small">${item.price}</div>` : ''}
                            </div>
                        `;
                        el.addEventListener('click', () => {
                            if (pickerTarget === 'offers') {
                                if (!offersSelection.find(i => i.id === item.id)) offersSelection.push(item);
                                renderSelection('offers', offersSelection);
                            } else if (pickerTarget === 'discounts') {
                                if (!discountsSelection.find(i => i.id === item.id)) discountsSelection.push(item);
                                renderSelection('discounts', discountsSelection);
                            }
                            itemsModal.hide();
                        });
                        itemsResults.appendChild(el);
                    });
                } catch (err) {
                    itemsResults.innerHTML = '<div class="text-center text-danger py-3">{{ __('حدث خطأ أثناء الجلب') }}</div>';
                }
            }

            itemsSearchBtn?.addEventListener('click', () => searchItems(itemsSearchInput?.value || ''));
            itemsSearchInput?.addEventListener('keyup', (e) => {
                if (e.key === 'Enter') {
                    searchItems(itemsSearchInput.value);
                }
            });

            form?.addEventListener('submit', function (e) {
                try {
                    const cats = Array.from(catList?.querySelectorAll('[data-cat-card]') || []).map(card => {
                        const label = card.querySelector('.js-cat-label')?.value.trim() || '';
                        const idOrSlug = card.querySelector('.js-cat-id')?.value.trim() || '';
                        if (!label || !idOrSlug) return null;

                        const color = card.querySelector('.js-cat-color')?.value || null;
                        const icon = card.querySelector('.js-cat-icon')?.value.trim() || null;
                        const order = parseInt(card.querySelector('.js-cat-order')?.value, 10);

                        const entry = {
                            label,
                            ...(isNaN(Number(idOrSlug)) ? { slug: idOrSlug } : { id: idOrSlug }),
                        };
                        if (color) entry.color = color;
                        if (icon) entry.icon = icon;
                        if (!isNaN(order) && order > 0) entry.order = order;
                        return entry;
                    }).filter(Boolean);

                    const promos = Array.from(promoList?.querySelectorAll('[data-promo-card]') || []).map(card => {
                        const freq = parseInt(card.querySelector('.js-promo-frequency')?.value, 10) || 4;
                        const type = card.querySelector('.js-promo-type')?.value || 'ad';
                        const target = card.querySelector('.js-promo-target')?.value.trim() || '';
                        const title = card.querySelector('.js-promo-title')?.value.trim() || '';
                        const subtitle = card.querySelector('.js-promo-subtitle')?.value.trim() || '';
                        const image = card.querySelector('.js-promo-image')?.value.trim() || '';

                        if (!target && !title && !image) return null;

                        const item = { type };
                        if (title) item.title = title;
                        if (subtitle) item.subtitle = subtitle;
                        if (image) item.image = image;
                        if (target) {
                            if (isNaN(Number(target))) {
                                item.slug = target;
                            } else {
                                item.id = target;
                            }
                        }

                        return {
                            frequency: freq,
                            items: [item],
                        };
                    }).filter(Boolean);

                    hiddenCats.value = JSON.stringify(cats);
                    hiddenPromos.value = JSON.stringify(promos);
                    hiddenOffers.value = JSON.stringify(offersSelection);
                    hiddenDiscounts.value = JSON.stringify(discountsSelection);
                } catch (err) {
                    e.preventDefault();
                    alert('{{ __('تعذر تجهيز البيانات للحفظ، تأكد من القيم المدخلة.') }}');
                }
            });
        });
    </script>
@endpush
