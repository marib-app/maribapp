@extends('layouts.main')
@section('title')
    {{__("Create Categories")}}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-12 col-md-6">
                <h4 class="mb-0">@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 d-flex justify-content-end">
                @if (!empty($category))
                    <a class="btn btn-primary me-2" href="{{ route('category.index') }}">< {{__("Back to All Categories")}} </a>
                    @can('category-create')
                        <a class="btn btn-primary me-2" href="{{ route('category.create', ['id' => $category->id]) }}">+ {{__("Add Subcategory")}} - /{{ $category->name }} </a>
                    @endcanany
                @else
                    @can('category-create')
                        <a class="btn btn-primary"  href="{{ route('category.create') }}">+ {{__("Add Category")}} </a>
                    @endcan
                @endif
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-md-12">
                <div class="card">

                    <div class="card-body">
                        <div class="row">
                            <div class="text-right col-md-12">
                                <a href="{{ route('category.order') }}">{{ __('Set Order of Categories') }}</a>
                            </div>
                        </div>
                        <table class="table table-borderless table-striped" aria-describedby="mydesc"
                               id="table_list" data-toggle="table" data-url="{{ route('category.show', $category->id ?? 0) }}"
                               data-click-to-select="true" data-side-pagination="server" data-pagination="true"
                               data-page-list="[5, 10, 20, 50, 100, 200,500,2000]" data-search="true" data-search-align="right"
                               data-toolbar="#toolbar" data-show-columns="true" data-show-refresh="true"
                               data-trim-on-search="false" data-responsive="true" data-sort-name="sequence"
                               data-sort-order="asc" data-pagination-successively-size="3" data-query-params="queryParams"
                               data-escape="true"
                               data-table="categories" data-use-row-attr-func="true" data-mobile-responsive="false"
                               data-show-export="true" data-export-options='{"fileName": "category-list","ignoreColumn": ["operate"]}' data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']">
                            <thead class="thead-dark">
                            <tr>
                                <th scope="col" data-field="id" data-align="center" data-sortable="true">{{ __('ID') }}</th>
                                <th scope="col" data-field="name" data-sortable="true" data-formatter="categoryNameFormatter">{{ __('Name') }}</th>
                                <th scope="col" data-field="image" data-align="center" data-formatter="imageFormatter">{{ __('Image') }}</th>
                                <th scope="col" data-field="subcategories_count" data-align="center" data-sortable="true" data-formatter="subCategoryFormatter">{{ __('Subcategories') }}</th>
                                <th scope="col" data-field="custom_fields_count" data-align="center" data-sortable="true" data-formatter="customFieldFormatter">{{ __('Custom Fields') }}</th>
                                @can('category-update')
                                    <th scope="col" data-field="status" data-width="5" data-sortable="true"  data-formatter="statusSwitchFormatter">{{ __('Active') }}</th>
                                @endcan
                                @canany(['category-update', 'category-delete'])
                                    <th scope="col" data-field="operate" data-escape="false" data-sortable="false">{{ __('Action') }}</th>
                                @endcanany
                            </tr>
                            </thead>
                        </table>

                    </div>
                </div>
            </div>
        </div>
    </section>

    @can('category-create')
    <!-- Clone category modal -->
    <div class="modal fade" id="cloneCategoryModal" tabindex="-1" aria-labelledby="cloneCategoryModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
                <form method="POST" id="cloneCategoryForm">
                    @csrf
                    <div class="modal-header">
                        <h5 class="modal-title" id="cloneCategoryModalLabel">{{ __('نسخ الفئة') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('Close') }}"></button>
                    </div>
                    <div class="modal-body">
                        <div class="mb-3">
                            <label for="cloneCategorySearch" class="form-label">{{ __('ابحث عن فئة') }}</label>
                            <input type="text" class="form-control" id="cloneCategorySearch" placeholder="{{ __('اكتب للبحث...') }}">
                        </div>
                        <div class="mb-3">
                            <label for="target_parent_category_id" class="form-label">{{ __('انسخ إلى داخل') }}</label>
                            <select class="form-select" name="target_parent_category_id" id="target_parent_category_id">
                                <option value="">{{ __('بدون قسم أب (فئة رئيسية)') }}</option>
                            </select>
                            <div class="form-text">{{ __('لا يمكنك النسخ داخل نفس الفئة أو ضمن فئاتها الفرعية.') }}</div>
                        </div>
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" value="1" id="synchronize_existing" name="synchronize_existing">
                            <label class="form-check-label" for="synchronize_existing">
                                {{ __('حدّث الحقول الموجودة إن وُجدت (بدلاً من إنشائها فقط).') }}
                            </label>
                        </div>
                        <div class="mt-3 d-none" id="cloneOptionsLoading">
                            <div class="spinner-border spinner-border-sm text-primary" role="status">
                                <span class="visually-hidden">{{ __('Loading...') }}</span>
                            </div>
                            <span class="ms-2">{{ __('جارِ جلب الوجهات المتاحة...') }}</span>
                        </div>
                        <div class="mt-2 text-danger small d-none" id="cloneOptionsError"></div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">{{ __('إلغاء') }}</button>
                        <button type="submit" class="btn btn-primary">{{ __('نسخ الفئة') }}</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
    @endcan
@endsection

@push('scripts')
@can('category-create')
<script>
    (function () {
        const cloneModal = document.getElementById('cloneCategoryModal');
        if (!cloneModal) return;

        const modal = new bootstrap.Modal(cloneModal);
        const form = document.getElementById('cloneCategoryForm');
        const select = document.getElementById('target_parent_category_id');
        const searchInput = document.getElementById('cloneCategorySearch');
        const loading = document.getElementById('cloneOptionsLoading');
        const errorBox = document.getElementById('cloneOptionsError');
        const title = document.getElementById('cloneCategoryModalLabel');
        let optionsCache = [];

        const resetState = () => {
            if (!select) return;
            select.innerHTML = '';
            const defaultOpt = document.createElement('option');
            defaultOpt.value = '';
            defaultOpt.textContent = @json(__('بدون قسم أب (فئة رئيسية)'));
            select.appendChild(defaultOpt);
            optionsCache = [];
            if (searchInput) searchInput.value = '';
            loading?.classList.add('d-none');
            if (errorBox) {
                errorBox.textContent = '';
                errorBox.classList.add('d-none');
            }
        };

        const renderOptions = (list) => {
            if (!select) return;
            const currentDefault = select.firstElementChild;
            select.innerHTML = '';
            if (currentDefault) select.appendChild(currentDefault);
            list.forEach(opt => {
                const optionEl = document.createElement('option');
                optionEl.value = opt.id;
                optionEl.textContent = opt.label;
                select.appendChild(optionEl);
            });
        };

        const applySearch = () => {
            const term = (searchInput?.value || '').trim().toLowerCase();
            if (!term) {
                renderOptions(optionsCache);
                return;
            }
            const filtered = optionsCache.filter(opt => (opt.label || '').toLowerCase().includes(term));
            renderOptions(filtered);
        };

        document.addEventListener('click', function (e) {
            const target = e.target.closest('.clone-category-btn');
            if (!target) return;
            e.preventDefault();

            resetState();
            const fetchUrl = target.getAttribute('data-target');
            const submitUrl = target.getAttribute('data-submit');
            const name = target.getAttribute('data-name') || '';
            if (title) title.textContent = name ? `${@json(__('نسخ:'))} ${name}` : @json(__('نسخ الفئة'));
            if (form && submitUrl) form.setAttribute('action', submitUrl);

            if (loading) loading.classList.remove('d-none');
            fetch(fetchUrl, {headers: {'X-Requested-With': 'XMLHttpRequest'}})
                .then(res => res.json())
                .then(options => {
                    resetState();
                    if (!Array.isArray(options)) return;
                    optionsCache = options;
                    renderOptions(optionsCache);
                })
                .catch(() => {
                    loading?.classList.add('d-none');
                    if (errorBox) {
                        errorBox.textContent = @json(__('تعذر جلب الوجهات المتاحة. حاول مجدداً.'));
                        errorBox.classList.remove('d-none');
                    }
                });

            modal.show();
        });

        if (searchInput) {
            searchInput.addEventListener('input', applySearch);
        }
    })();
</script>
@endcan
@endpush
