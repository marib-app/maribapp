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
                            <select class="form-select select2 w-100" id="cloneTargetSelect" name="target_parent_category_id" required disabled>
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

            const modalInstance = bootstrap.Modal.getOrCreateInstance(modalElement);
            const form = document.getElementById('cloneCategoryForm');
            const $modalElement = $('#cloneCategoryModal');
            const $targetSelect = $('#cloneTargetSelect');
            const sourceInput = form.querySelector('input[name="source_category_id"]');
            const feedback = document.getElementById('cloneCategoryFeedback');
            const loadingIndicator = document.getElementById('cloneCategoryLoadingIndicator');
            const submitButton = document.getElementById('cloneCategorySubmit');
            const sourceNameLabel = document.getElementById('cloneSourceName');


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
            };


            const resetModalState = () => {
                feedback.classList.add('d-none');
                feedback.textContent = '';
                destroySelect2();
                $targetSelect.empty().append(
                    $('<option>', {
                        value: '',
                        text: '{{ __('جارٍ تحميل الأقسام المتاحة...') }}'
                    })
                );
                $targetSelect.prop('disabled', true);
                initializeSelect2();
                $targetSelect.trigger('change.select2');
                targetSelect.disabled = true;
                submitButton.disabled = true;
            };

            const populateOptions = (options) => {
                destroySelect2();
                $targetSelect.empty();


                if (!Array.isArray(options) || options.length === 0) {
                    $targetSelect.append(
                        $('<option>', {
                            value: '',
                            text: '{{ __('لا توجد أقسام متاحة للنسخ إليها.') }}'
                        })
                    );
                    $targetSelect.prop('disabled', true);
                    initializeSelect2();
                    $targetSelect.trigger('change.select2');
                    submitButton.disabled = true;
                    return;
                }

                $targetSelect.append(
                    $('<option>', {
                        value: '',
                        text: '{{ __('اختر القسم الهدف') }}',
                        disabled: true,
                        selected: true
                    })
                );

                options.forEach(function (option) {
                    $targetSelect.append(
                        $('<option>', {
                            value: option.id,
                            text: option.label
                        })
                    );
                });

                $targetSelect.prop('disabled', false);
                initializeSelect2();
                $targetSelect.trigger('change.select2');
                submitButton.disabled = true;
            };

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
                        $targetSelect.empty().append(
                            $('<option>', {
                                value: '',
                                text: '{{ __('حدث خطأ أثناء تحميل البيانات.') }}'
                            })
                        );
                        $targetSelect.prop('disabled', true);
                        initializeSelect2();
                        $targetSelect.trigger('change.select2');
                        submitButton.disabled = true;
                    });

                modalInstance.show();
            });

            modalElement.addEventListener('hidden.bs.modal', function () {
                form.reset();
                resetModalState();
            });

            $targetSelect.on('change.select2', function () {
                submitButton.disabled = $targetSelect.val() === '';
            });
        });

            destroySelect2();
            initializeSelect2();

    </script>
@endpush
