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
        :root {
            --sf-primary: #0d6efd;
            --sf-surface: #f7f9fc;
            --sf-border: #e7ebf3;
            --sf-muted: #6c757d;
            --sf-card-radius: 14px;
        }
        .storefront-shell { font-family: 'Cairo','Tajawal','Noto Sans Arabic','Tahoma','Arial',sans-serif; }
        .storefront-hero { background: linear-gradient(135deg,#eef4ff 0%,#ffffff 60%); border: 1px solid var(--sf-border); border-radius: 16px; }
        .pill { display: inline-flex; align-items: center; gap: 6px; padding: 6px 10px; border-radius: 999px; background: #f5f7fb; border: 1px solid var(--sf-border); font-size: 12px; color: var(--sf-primary); }
        .section-card { border: 1px solid var(--sf-border); border-radius: var(--sf-card-radius); background: #fff; }
        .section-card .card-title { font-weight: 700; font-size: 15px; }
        .sticky-actions { position: sticky; top: 12px; z-index: 3; }
        .badge-dot { display:inline-flex; align-items:center; gap:6px; padding:6px 10px; border-radius: 10px; background: #f1f4f9; color: #0d6efd; font-size: 12px; }
        .mini-label { font-size: 12px; color: var(--sf-muted); }
        .list-row { border: 1px solid var(--sf-border); border-radius: 12px; padding: 10px 12px; background: #fbfcff; }
        .ghost { color: var(--sf-muted); }
    </style>
@endsection

@section('content')
    <section class="section storefront-shell">
        <div class="d-flex align-items-center justify-content-between flex-wrap gap-3 mb-3">
            <div>
                <div class="text-muted small">{{ __('لوحة التحكم / المتاجر الإلكترونية') }}</div>
                <h3 class="fw-bold m-0">{{ __('إدارة واجهة المتجر') }}</h3>
            </div>
            <div class="d-flex gap-2 flex-wrap sticky-actions">
                <button form="storefrontUiForm" type="submit" class="btn btn-primary">{{ __('حفظ واجهة المتجر') }}</button>
                <button form="termsForm" type="submit" class="btn btn-outline-secondary">{{ __('حفظ الشروط') }}</button>
            </div>
        </div>

        <div class="storefront-hero p-3 p-md-4 mb-4">
            <div class="d-flex flex-wrap align-items-center gap-3">
                <div class="rounded-circle d-flex align-items-center justify-content-center" style="width:52px;height:52px;background:#0d6efd1a;">
                    <i class="bi bi-magic text-primary fs-4"></i>
                </div>
                <div class="flex-grow-1">
                    <div class="fw-semibold fs-5 mb-1">{{ __('تصميم واجهة متجر متكاملة') }}</div>
                    <div class="text-muted small">{{ __('تحكم كامل في الشريط المميز، بطاقات الترويج، العروض والتخفيضات دون تبويبات معقدة.') }}</div>
                </div>
                <div class="d-flex gap-2 flex-wrap">
                    <span class="pill"><i class="bi bi-sliders"></i>{{ __('إعداد سريع') }}</span>
                    <span class="pill"><i class="bi bi-bag-heart"></i>{{ __('تجربة جذابة') }}</span>
                    <span class="pill"><i class="bi bi-activity"></i>{{ __('حفظ فوري') }}</span>
                </div>
            </div>
        </div>

        <div class="row g-4">
            <div class="col-xl-4 col-12">
                <div class="card section-card shadow-sm mb-4">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <div>
                                <div class="card-title mb-1">{{ __('الشروط والأحكام') }}</div>
                                <div class="text-muted small">{{ __('نص عادي فقط كما سيظهر للمتاجر الإلكترونية.') }}</div>
                            </div>
                            <button form="termsForm" type="submit" class="btn btn-primary btn-sm">{{ __('حفظ') }}</button>
                        </div>
                        <form id="termsForm" class="create-form-without-reset" action="{{ route('seller-store-settings.terms.store') }}" method="post">
                            @csrf
                            <textarea id="store_terms_editor" name="store_terms_conditions" class="form-control" rows="10" inputmode="text" placeholder="{{ __('اكتب نص الشروط كما سيظهر للمستخدمين (نص فقط بدون أكواد).') }}">{{ old('store_terms_conditions', strip_tags($storeTerms)) }}</textarea>
                            <div class="text-muted small mt-2">{{ __('يُسمح بالنصوص العادية فقط، سيُزال أي HTML عند الحفظ.') }}</div>
                        </form>
                    </div>
                </div>

                <div class="card section-card shadow-sm mb-4">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <div>
                                <div class="card-title mb-1">{{ __('بوابات الدفع') }}</div>
                                <div class="text-muted small">{{ __('عرض وإدارة بوابات الدفع الخاصة بالمتاجر الإلكترونية.') }}</div>
                            </div>
                            <a href="{{ route('seller-store-settings.gateways.index') }}" class="btn btn-primary btn-sm">{{ __('إدارة البوابات') }}</a>
                        </div>
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

                <div class="card section-card shadow-sm">
                    <div class="card-body">
                        <div class="card-title mb-2">{{ __('ملخص سريع') }}</div>
                        <div class="vstack gap-2 mini-label">
                            <div class="d-flex justify-content-between"><span>{{ __('فئات مميزة') }}</span><span id="summaryCats" class="fw-semibold">0</span></div>
                            <div class="d-flex justify-content-between"><span>{{ __('بطاقات ترويج') }}</span><span id="summaryPromos" class="fw-semibold">0</span></div>
                            <div class="d-flex justify-content-between"><span>{{ __('عروض جديدة') }}</span><span id="summaryOffers" class="fw-semibold">0</span></div>
                            <div class="d-flex justify-content-between"><span>{{ __('تخفيضات') }}</span><span id="summaryDiscounts" class="fw-semibold">0</span></div>
                        </div>
                        <hr>
                        <div class="mini-label">{{ __('الحفظ يطبق فوراً على تطبيق المتاجر.') }}</div>
                        <button form="storefrontUiForm" type="submit" class="btn btn-primary w-100 mt-3">{{ __('حفظ واجهة المتجر') }}</button>
                    </div>
                </div>
            </div>

            <div class="col-xl-8 col-12">
                <div class="card section-card shadow-sm">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-3">
                            <div>
                                <div class="card-title mb-1">{{ __('مصمم الواجهة (شريط + عروض)') }}</div>
                                <div class="text-muted small">{{ __('كل عناصر الواجهة في لوحة واحدة بدون تبويب منفصل.') }}</div>
                            </div>
                            <div class="form-check form-switch">
                                <input class="form-check-input" type="checkbox" role="switch" id="storefront_ui_enabled" name="enabled" value="1" {{ $uiSetting->enabled ? 'checked' : '' }}>
                                <label class="form-check-label" for="storefront_ui_enabled">{{ __('تشغيل الواجهة المخصصة') }}</label>
                            </div>
                        </div>

                        <form action="{{ route('seller-store-settings.ui.store') }}" method="post" id="storefrontUiForm">
                            @csrf
                            <textarea id="featured_categories" name="featured_categories" class="d-none"></textarea>
                            <textarea id="promotion_slots" name="promotion_slots" class="d-none"></textarea>
                            <textarea id="new_offers_items" name="new_offers_items" class="d-none"></textarea>
                            <textarea id="discount_items" name="discount_items" class="d-none"></textarea>

                            <div class="row g-4">
                                <div class="col-12">
                                    <div class="card section-card shadow-sm mb-4">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between align-items-center mb-3">
                                                <div>
                                                    <div class="card-title mb-1">{{ __('فئات قسم المتجر (عرض فقط)') }}</div>
                                                    <div class="text-muted small">{{ __('مرتبة بالأب ثم الاسم، لعرض المتوفر للقسم.') }}</div>
                                                </div>
                                                <span class="badge-dot"><i class="bi bi-eye"></i>{{ __('عرض فقط') }}</span>
                                            </div>
                                            @if(($categories ?? collect())->count() > 0)
                                                <div class="row g-3">
                                                    @foreach($categories as $cat)
                                                        <div class="col-12 col-md-6 col-lg-4">
                                                            <div class="border rounded-3 h-100 p-3 d-flex gap-3 align-items-center" style="border-color: var(--sf-border);">
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

                                <div class="col-12">
                                    <div class="card section-card shadow-sm mb-4">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between align-items-center mb-3">
                                                <div>
                                                    <div class="card-title mb-1">{{ __('الشريط المميز (فئات مختصرة)') }}</div>
                                                    <div class="text-muted small">{{ __('اختر الفئات التي ستظهر كشرائح أفقية في التطبيق.') }}</div>
                                                </div>
                                                <button type="button" class="btn btn-sm btn-outline-primary" id="addCategoryBtn" onclick="event.preventDefault(); if (window.sfAddCategory) { window.sfAddCategory(); } else { const list=document.getElementById('featuredCategoriesList'); if(list){ const idx=list.children.length+1; const card=document.createElement('div'); card.className='border rounded p-3 bg-light'; card.innerHTML=`<div class=\"fw-semibold mb-2\">{{ __('فئة') }} #${idx}</div><div class=\"text-muted small\">{{ __('تمت الإضافة، عيّن بياناتها بعد إعادة تحميل الصفحة') }}</div>`; list.appendChild(card);} } return false;">
                                                    <i class="bi bi-plus-lg"></i> {{ __('إضافة فئة') }}
                                                </button>
                                            </div>
                                            <div id="featuredCategoriesList" class="d-grid gap-3"></div>
                                            <div class="text-muted small mt-3">{{ __('اختر الفئة والاسم الظاهر، اللون والأيقونة اختيارية.') }}</div>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12">
                                    <div class="card section-card shadow-sm mb-4">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between align-items-center mb-3">
                                                <div>
                                                    <div class="card-title mb-1">{{ __('بطاقات الترويج بين المتاجر') }}</div>
                                                    <div class="text-muted small">{{ __('تظهر بطاقة ترويج بعد عدد معيّن من بطاقات المتاجر.') }}</div>
                                                </div>
                                                <button type="button" class="btn btn-sm btn-outline-primary" id="addPromoBtn">
                                                    <i class="bi bi-megaphone"></i> {{ __('إضافة ترويج') }}
                                                </button>
                                            </div>
                                            <div id="promotionCardsList" class="d-grid gap-3"></div>
                                            <div class="text-muted small mt-3">{{ __('اترك الحقول الفارغة إذا كنت لا تريد ترويجاً معيناً.') }}</div>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12">
                                    <div class="card section-card shadow-sm">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between align-items-center mb-3">
                                                <div>
                                                    <div class="card-title mb-1">{{ __('العروض والتخفيضات') }}</div>
                                                    <div class="text-muted small">{{ __('اختر الإعلانات التي ستظهر كعروض جديدة أو تخفيضات ضمن الواجهة.') }}</div>
                                                </div>
                                                <div class="d-flex gap-2">
                                                    <button type="button" class="btn btn-sm btn-outline-success" data-select-items="offers">
                                                        <i class="bi bi-plus-lg"></i> {{ __('إضافة إلى العروض') }}
                                                    </button>
                                                    <button type="button" class="btn btn-sm btn-outline-warning" data-select-items="discounts">
                                                        <i class="bi bi-plus-lg"></i> {{ __('إضافة إلى التخفيضات') }}
                                                    </button>
                                                </div>
                                            </div>
                                            <div class="row g-3">
                                                <div class="col-md-6">
                                                    <div class="mini-label mb-2">{{ __('عروض جديدة') }}</div>
                                                    <div id="offersList" class="vstack gap-2"></div>
                                                </div>
                                                <div class="col-md-6">
                                                    <div class="mini-label mb-2">{{ __('تخفيضات') }}</div>
                                                    <div id="discountsList" class="vstack gap-2"></div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </section>
    {{-- Modal اختيار الإعلانات --}}
    <div class="modal fade" id="itemsPickerModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-scrollable modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">{{ __('اختر إعلانات') }}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="input-group mb-3">
                        <input type="text" class="form-control" placeholder="{{ __('ابحث بالاسم أو المعرّف') }}" id="itemsSearchInput">
                        <button class="btn btn-outline-primary" type="button" id="itemsSearchBtn">{{ __('بحث') }}</button>
                    </div>
                    <div class="list-group" id="itemsResults"></div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">{{ __('إغلاق') }}</button>
                </div>
            </div>
        </div>
    </div>
    <script>
        // ضمان وجود دالة إضافة الفئة فوراً حتى قبل تحميل بقية السكربتات
        (function () {
            if (window.sfAddCategory) return;
            window.sfAddCategory = function () {
                const list = document.getElementById('featuredCategoriesList');
                if (!list) return false;
                const idx = list.children.length + 1;
                const card = document.createElement('div');
                card.className = 'border rounded p-3 bg-light';
                card.dataset.catCard = '1';
                card.innerHTML = `
                    <div class="d-flex justify-content-between align-items-start gap-2 mb-2">
                        <div class="fw-semibold">{{ __('فئة') }} #${idx}</div>
                        <button type="button" class="btn btn-sm btn-outline-danger" aria-label="Remove" onclick="this.closest('[data-cat-card]').remove()">&times;</button>
                    </div>
                    <div class="text-muted small">{{ __('تمت الإضافة، سيكتمل النموذج بعد تحميل السكربت الكامل أو بعد الحفظ.') }}</div>
                `;
                list.appendChild(card);
                return false;
            };
        })();
    </script>
@endsection
@push('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            // يُسمح بنص عادي فقط لشروط المتجر (بدون محرر WYSIWYG أو أكواد)

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
            const summaryCats = document.getElementById('summaryCats');
            const summaryPromos = document.getElementById('summaryPromos');
            const summaryOffers = document.getElementById('summaryOffers');
            const summaryDiscounts = document.getElementById('summaryDiscounts');

            const modalEl = document.getElementById('itemsPickerModal');
            const itemsModal = (modalEl && window.bootstrap && window.bootstrap.Modal)
                ? new bootstrap.Modal(modalEl)
                : { show() { if (modalEl) { modalEl.classList.add('show'); modalEl.style.display = 'block'; } }, hide() { if (modalEl) { modalEl.classList.remove('show'); modalEl.style.display = 'none'; } } };
            const itemsResults = document.getElementById('itemsResults');
            const itemsSearchInput = document.getElementById('itemsSearchInput');
            const itemsSearchBtn = document.getElementById('itemsSearchBtn');

            let pickerTarget = null;
            let offersSelection = Array.isArray(initialOffers) ? initialOffers : [];
            let discountsSelection = Array.isArray(initialDiscounts) ? initialDiscounts : [];

            function setSummary() {
                summaryCats.textContent = catList ? catList.querySelectorAll('[data-cat-card]').length : 0;
                summaryPromos.textContent = promoList ? promoList.querySelectorAll('[data-promo-card]').length : 0;
                summaryOffers.textContent = offersSelection.length;
                summaryDiscounts.textContent = discountsSelection.length;
            }

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

            window.sfAddCategory = function(data = {}) {
                if (!catList) return;
                const idx = catList.children.length + 1;
                const card = document.createElement('div');
                card.className = 'border rounded p-3 bg-light';
                card.dataset.catCard = '1';
                card.innerHTML = `
                    <div class="d-flex justify-content-between align-items-start gap-2 mb-2">
                        <div class="fw-semibold">{{ __('فئة') }} #${idx}</div>
                        <button type="button" class="btn btn-sm btn-outline-danger" aria-label="Remove" onclick="this.closest('[data-cat-card]').remove(); setTimeout(setSummary, 50);">&times;</button>
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
                setSummary();
            }

            window.sfAddPromo = function(slot = {}) {
                if (!promoList) return;
                const item = Array.isArray(slot.items) && slot.items.length ? slot.items[0] : {};
                const idx = promoList.children.length + 1;
                const card = document.createElement('div');
                card.className = 'border rounded p-3';
                card.dataset.promoCard = '1';
                card.innerHTML = `
                    <div class="d-flex justify-content-between align-items-start gap-2 mb-2">
                        <div class="fw-semibold">{{ __('ترويج') }} #${idx}</div>
                        <button type="button" class="btn btn-sm btn-outline-danger" aria-label="Remove" onclick="this.closest('[data-promo-card]').remove(); setTimeout(setSummary, 50);">&times;</button>
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
                setSummary();
            }
            document.getElementById('addCategoryBtn')?.addEventListener('click', (e) => { e.preventDefault(); window.sfAddCategory(); });
            document.getElementById('addPromoBtn')?.addEventListener('click', (e) => { e.preventDefault(); window.sfAddPromo(); });
            document.querySelectorAll('[data-select-items]').forEach(btn => {
                btn.addEventListener('click', () => {
                    pickerTarget = btn.getAttribute('data-select-items');
                    if (itemsSearchInput) itemsSearchInput.value = '';
                    if (itemsResults) itemsResults.innerHTML = '';
                    itemsModal.show();
                    itemsSearchInput?.focus();
                });
            });

            (initialCategories || []).forEach(cat => window.sfAddCategory(cat));
            (initialPromotions || []).forEach(slot => window.sfAddPromo(slot));
            if (catList && catList.children.length === 0) window.sfAddCategory();
            if (promoList && promoList.children.length === 0) window.sfAddPromo();
            setSummary();

            function renderSelection(target, data) {
                const container = target === 'offers' ? offersListEl : discountsListEl;
                if (!container) return;
                container.innerHTML = '';
                if (!data.length) {
                    container.innerHTML = `<div class="list-row ghost">${target === 'offers' ? '{{ __('لا توجد عروض محددة') }}' : '{{ __('لا توجد تخفيضات محددة') }}'}</div>`;
                    return;
                }
                data.forEach((item) => {
                    const row = document.createElement('div');
                    row.className = 'list-row d-flex align-items-center gap-3';
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
                setSummary();
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
                            setSummary();
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

                        return { frequency: freq, items: [item] };
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

