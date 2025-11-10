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

                        @php
                            $flashError = session('errors');
                            if ($flashError instanceof \Illuminate\Support\ViewErrorBag) {
                                $flashError = null;
                            }
                        @endphp
                        @if(session('success'))
                            <div class="alert alert-success" role="alert">
                                {{ session('success') }}
                            </div>
                        @endif
                        @if($flashError)
                            <div class="alert alert-danger" role="alert">
                                {{ is_array($flashError) ? implode(' ', \Illuminate\Support\Arr::wrap($flashError)) : $flashError }}
                            </div>
                        @endif
                        @if($errors->any())
                            <div class="alert alert-danger" role="alert">
                                {{ $errors->first() }}
                            </div>
                        @endif

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


    <div class="modal fade" id="cloneCategoryModal" tabindex="-1" aria-labelledby="cloneCategoryModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <form method="POST" id="cloneCategoryForm">
                    @csrf
                    <input type="hidden" name="source_category_id" value="">
                    <div class="modal-header">
                        <h5 class="modal-title" id="cloneCategoryModalLabel">{{ __('نسخ الفئة الحالية إلى قسم آخر') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('إغلاق') }}"></button>
                    </div>
                    <div class="modal-body">
                        <p class="mb-3">{{ __('سيتم نسخ جميع الفئات الفرعية والحقول المخصصة ضمن الفئة:') }} <strong id="cloneSourceName">—</strong></p>
                        <div id="cloneCategoryFeedback" class="alert alert-danger d-none" role="alert"></div>
                        <div class="mb-3">
                            <label for="cloneTargetSelect" class="form-label">{{ __('اختر القسم الهدف') }}</label>
                            <select class="form-select select2 select2-full-width" id="cloneTargetSelect" name="target_parent_category_id" required disabled style="width: 100%;">
                                <option value="">{{ __('جارٍ تحميل الأقسام المتاحة...') }}</option>
                            </select>
                        </div>
                        <div id="cloneCategoryLoadingIndicator" class="d-flex align-items-center">
                            <div class="spinner-border spinner-border-sm text-primary me-2" role="status">
                                <span class="visually-hidden">{{ __('جارٍ التحميل...') }}</span>
                            </div>
                            <span>{{ __('يرجى الانتظار بينما نقوم بتحميل الأقسام المتاحة.') }}</span>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">{{ __('إلغاء') }}</button>
                        <button type="submit" class="btn btn-primary" id="cloneCategorySubmit" disabled>{{ __('نسخ') }}</button>
                    </div>
                </form>
            </div>
        </div>
    </div>


@endsection


@push('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const modalElement = document.getElementById('cloneCategoryModal');
            if (!modalElement) {
                return;
            }

            const form = document.getElementById('cloneCategoryForm');
            const $modalElement = $('#cloneCategoryModal');
            const $targetSelect = $('#cloneTargetSelect');
            const targetSelectElement = document.getElementById('cloneTargetSelect');
            const sourceInput = form.querySelector('input[name="source_category_id"]');
            const feedback = document.getElementById('cloneCategoryFeedback');
            const loadingIndicator = document.getElementById('cloneCategoryLoadingIndicator');
            const submitButton = document.getElementById('cloneCategorySubmit');
            const sourceNameLabel = document.getElementById('cloneSourceName');
            const bootstrapModalConstructor = window.bootstrap?.Modal;
            let modalInstance = null;
            let showModal = null;


            const destroySelect2 = () => {
                if ($targetSelect.data('select2')) {
                    $targetSelect.select2('destroy');
                }
            };

            const initializeSelect2 = () => {
                $targetSelect.select2({
                    dropdownParent: $modalElement,
                    width: '100%'
                });
                updateSubmitButtonState();
            };


            const resetModalState = () => {
                feedback.classList.add('d-none');
                feedback.textContent = '';
                destroySelect2();
                const loadingOption = document.createElement('option');
                loadingOption.value = '';
                loadingOption.textContent = '{{ __('جارٍ تحميل الأقسام المتاحة...') }}';

                targetSelectElement.innerHTML = '';
                targetSelectElement.appendChild(loadingOption);

                $targetSelect.prop('disabled', true);
                targetSelectElement.disabled = true;
                initializeSelect2();
                $targetSelect.trigger('change.select2');
                submitButton.disabled = true;
                loadingIndicator.classList.remove('d-none');
            };

            const updateSubmitButtonState = () => {
                submitButton.disabled = targetSelectElement.disabled || targetSelectElement.value === '';
            };

            const dispatchNativeChange = () => {
                try {
                    const changeEvent = new Event('change', { bubbles: true });
                    targetSelectElement.dispatchEvent(changeEvent);
                } catch (error) {
                    // Some environments may not support the Event constructor; fall back if needed.
                    if (typeof document.createEvent === 'function') {
                        const legacyChangeEvent = document.createEvent('Event');
                        legacyChangeEvent.initEvent('change', true, true);
                        targetSelectElement.dispatchEvent(legacyChangeEvent);
                    }
                }
            };

            const syncSelectionState = (selectedValue = '') => {
                if (selectedValue !== '') {
                    const normalizedValue = String(selectedValue);
                    $targetSelect.val(normalizedValue);
                    targetSelectElement.value = normalizedValue;
                } else {
                    $targetSelect.val('');
                    targetSelectElement.value = '';
                }

                $targetSelect.trigger('change.select2');
                dispatchNativeChange();
                updateSubmitButtonState();
            };


            const populateOptions = (options) => {
                destroySelect2();
                targetSelectElement.innerHTML = '';

                const fragment = document.createDocumentFragment();
                const hasArrayOptions = Array.isArray(options);
                const isUsableOption = function (option) {
                    return option && option.id !== undefined && option.id !== null && option.id !== '';
                };
                const usableOptions = hasArrayOptions ? options.filter(isUsableOption) : [];

                if (!hasArrayOptions || usableOptions.length === 0) {
                    const emptyOption = document.createElement('option');
                    emptyOption.value = '';
                    emptyOption.textContent = '{{ __('لا توجد أقسام متاحة للنسخ إليها.') }}';
                    fragment.appendChild(emptyOption);

                    targetSelectElement.appendChild(fragment);
                    $targetSelect.prop('disabled', true);
                    targetSelectElement.disabled = true;
                    initializeSelect2();
                    syncSelectionState('');

                    return;
                }



                let selectedValue = '';
                const hasSingleUsableOption = usableOptions.length === 1;


                if (hasSingleUsableOption) {
                    const singleOption = usableOptions[0];
                    selectedValue = String(singleOption.id);
                    const optionElement = document.createElement('option');
                    optionElement.value = selectedValue;
                    optionElement.textContent = singleOption.label;
                    optionElement.selected = true;
                    fragment.appendChild(optionElement);

                    targetSelectElement.appendChild(fragment);
                    $targetSelect.prop('disabled', false);
                    targetSelectElement.disabled = false;
                    targetSelectElement.value = selectedValue;
                    initializeSelect2();
                    submitButton.disabled = false;
                    syncSelectionState(selectedValue);
                    return;
                } else {
                    const placeholderOption = document.createElement('option');
                    placeholderOption.value = '';
                    placeholderOption.textContent = '{{ __('اختر القسم الهدف') }}';
                    placeholderOption.disabled = true;
                    placeholderOption.selected = true;
                    fragment.appendChild(placeholderOption);

                    usableOptions.forEach(function (option) {
                        const optionElement = document.createElement('option');
                        optionElement.value = option.id;
                        optionElement.textContent = option.label;
                        fragment.appendChild(optionElement);
                    });
                }


           

                targetSelectElement.appendChild(fragment);

                $targetSelect.prop('disabled', false);
                targetSelectElement.disabled = false;
                initializeSelect2();
                syncSelectionState(selectedValue);

            };

            function handleModalHidden() {
                form.reset();
                resetModalState();
            }

            if (bootstrapModalConstructor) {
                if (typeof bootstrapModalConstructor.getOrCreateInstance === 'function') {
                    modalInstance = bootstrapModalConstructor.getOrCreateInstance(modalElement);
                } else if (typeof bootstrapModalConstructor === 'function') {
                    modalInstance = new bootstrapModalConstructor(modalElement);
                }

                if (modalInstance && typeof modalInstance.show === 'function') {
                    showModal = function () {
                        modalInstance.show();
                    };
                    modalElement.addEventListener('hidden.bs.modal', handleModalHidden);
                }
            }

            if (!showModal && typeof $modalElement.modal === 'function') {
                showModal = function () {
                    $modalElement.modal('show');
                };
                $modalElement.on('hidden.bs.modal', handleModalHidden);
            }

            if (!showModal) {
                const modalErrorMessage = 'Bootstrap modal library is unavailable. Clone category modal cannot be opened.';
                if (typeof console !== 'undefined' && typeof console.error === 'function') {
                    console.error(modalErrorMessage);
                }
                if (typeof window.alert === 'function') {
                    window.alert(modalErrorMessage);
                }
                return;
            }

            document.body.addEventListener('click', function (event) {
                const trigger = event.target.closest('.js-open-clone-category');
                if (!trigger) {
                    return;
                }

                event.preventDefault();

                const { categoryId, categoryName, optionsUrl, actionUrl } = trigger.dataset;

                if (!categoryId || !optionsUrl || !actionUrl) {
                    return;
                }

                resetModalState();

                form.action = actionUrl;
                sourceInput.value = categoryId;
                sourceNameLabel.textContent = categoryName || '#';

                fetch(optionsUrl, {
                    headers: {
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                })
                    .then(function (response) {
                        if (!response.ok) {
                            throw new Error('Request failed');
                        }
                        return response.json();
                    })
                    .then(function (data) {
                        loadingIndicator.classList.add('d-none');
                        populateOptions(data.options || []);
                    })
                    .catch(function () {
                        loadingIndicator.classList.add('d-none');
                        feedback.textContent = '{{ __('تعذر تحميل الأقسام المتاحة. يرجى المحاولة مرة أخرى.') }}';
                        feedback.classList.remove('d-none');
                        destroySelect2();
                        targetSelectElement.innerHTML = '';
                        const errorOption = document.createElement('option');
                        errorOption.value = '';
                        errorOption.textContent = '{{ __('حدث خطأ أثناء تحميل البيانات.') }}';
                        targetSelectElement.appendChild(errorOption);
                        $targetSelect.prop('disabled', true);
                        targetSelectElement.disabled = true;
                        initializeSelect2();
                        $targetSelect.trigger('change.select2');
                        submitButton.disabled = true;
                    });


                if (typeof showModal === 'function') {
                    showModal();
                }
            });

            $targetSelect.on('change.select2', function () {
                updateSubmitButtonState();
            });

            initializeSelect2();
        });
    </script>
@endpush
