@extends('layouts.main')
@section('title')
    {{__("Create Feature Section")}}
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
@section('content')

    @php
        $sectionTypes = $allowedSectionTypes ?? [];


        $sectionTypeLabels = [
            'public' => __('إعلانات الجمهور'),
            'real_estate' => __('الخدمات العقارية'),
            'shein' => __('منتجات شي إن'),
            'computer' => __('قسم الكمبيوتر'),
        ];

        $allowedSectionTypeKeys = array_keys($sectionTypeLabels);
        $sectionTypes = array_values(array_filter(
            $sectionTypes,
            static fn($type) => in_array($type, $allowedSectionTypeKeys, true)
        ));

        $defaultSectionType = $defaultSectionType ?? ($sectionTypes[0] ?? null);


        $featureSectionAliasMap = collect(config('feature-section.section_type_aliases', []))
            ->mapWithKeys(fn ($value, $key) => [\Illuminate\Support\Str::lower($key) => $value])
            ->toArray();
        $filterLabels = $filterLabels ?? [];

        $filterSlugOptions = $filterSlugOptions ?? [];
        $filterCanonicalSlugs = $filterCanonicalSlugs ?? [];
        $usedFilterSlugMap = $usedFilterSlugMap ?? [];
        $slugUnavailableMessage = $slugUnavailableMessage ?? __('All slug variants for this filter are already assigned. Please edit the existing feature section instead of creating a duplicate.');


        $rootIdentifiers = $rootIdentifiers ?? [];
        $previewRoute = $previewRoute ?? null;
        $probeRoute = $probeRoute ?? null;
        $flushCacheRoute = $flushCacheRoute ?? null;
        $filterOptions = array_keys($filterLabels);
        $defaultFilterKey = $filterOptions[0] ?? null;
        if (! isset($section)) {
            $section = (object) ['filter' => null];
        }

        $selectedFilter = old('filter_type', $section->filter ?? $defaultFilterKey);
        
        if ($selectedFilter === null || ! array_key_exists($selectedFilter, $filterLabels)) {
            $selectedFilter = $defaultFilterKey;

        }
        $defaultFilterHint = $selectedFilter ? implode(', ', $filterSlugOptions[$selectedFilter] ?? []) : '';
        $rootBadgeTemplate = __('Root: :value');
        $rootBadgeAll = __('All categories (no restriction)');
        $rootBadgeMissing = __('No root configured');
        $zeroWarningText = __('No items matched the current configuration. Please review the filters before saving.');
        $zeroWarningConfirmedText = __('Zero results acknowledged. Saving is now enabled for this configuration.');
        $zeroConfirmMessage = __('This configuration returned zero items. Continue with saving?');
        $previewTitleText = __('Preview Results');
        $probeTitleText = __('Probe API Result');
        $zeroModalWarningText = __('No items were returned for this configuration.');
        $zeroModalConfirmText = __('Allow saving with zero results');
        $statusActiveLabel = __('Active');
        $statusInactiveLabel = __('Inactive');
        $statusUpdateSuccessText = __('Feature section status updated successfully.');
        $statusUpdateErrorText = __('Unable to update feature section status. Please try again.');
        $previewCloseText = __('Close');
        $previewNoSectionsText = __('No sections were returned for this request.');
        $previewTableTitle = __('Title');
        $previewTableSlug = __('Slug');
        $previewTableType = __('Section Type');
        $previewTableTotal = __('Items');
        $flushSuccessText = __('Cache cleared for keys: :keys');
        $flushErrorText = __('Unable to flush cache. Please try again.');
        $flushMissingSlugText = __('Slug is required before flushing the cache.');


        $previewColumns = [
            'title' => $previewTableTitle,
            'slug' => $previewTableSlug,
            'sectionType' => $previewTableType,
            'total' => $previewTableTotal,
        ];

        $flushMessages = [
            'success' => $flushSuccessText,
            'error' => $flushErrorText,
            'missingSlug' => $flushMissingSlugText,
        ];

        $statusLabels = [
            'active' => $statusActiveLabel,
            'inactive' => $statusInactiveLabel,
        ];

        $statusMessages = [
            'success' => $statusUpdateSuccessText,
            'error' => $statusUpdateErrorText,
        ];

        $filterTakenMessage = __('This filter is already used for the selected section type. Please edit the existing feature section instead.');
        $filterDuplicateHint = __('Filters marked as unavailable are already used for this section type. Please edit the existing feature section instead of duplicating it.');
        $filterUnavailableMessage = __('All filters for this section type are already in use. Please edit the existing feature section instead of creating a duplicate.');



        $filterUsageStatusLabel = __('In use');
        $filterUsageSrLabel = __('Filter currently assigned to another section');


        $defaultSectionTypeKey = $defaultSectionType ?? '';
        $defaultUsedSlugs = $defaultSectionTypeKey !== '' && isset($usedFilterSlugMap[$defaultSectionTypeKey])
            ? $usedFilterSlugMap[$defaultSectionTypeKey]
            : [];

        $defaultDisabledFilters = [];
        $defaultAvailableCount = 0;

        foreach ($filterLabels as $filterValue => $label) {
            $allowedSlugs = $filterSlugOptions[$filterValue] ?? [];
            if (! is_array($allowedSlugs)) {
                $allowedSlugs = [];
            }

            $allowedSlugs = array_values(array_filter(array_map(
                static fn($slug) => is_string($slug) ? trim($slug) : '',
                $allowedSlugs
            )));

            $unusedSlugs = array_filter($allowedSlugs, static function ($slug) use ($defaultUsedSlugs) {
                return $slug !== '' && ! isset($defaultUsedSlugs[$slug]);
            });

            $isDisabled = $allowedSlugs !== [] && $unusedSlugs === [];

            if ($isDisabled) {
                $defaultDisabledFilters[$filterValue] = true;
            } else {
                $defaultAvailableCount++;
            }
        }

        $defaultHasAvailableFilters = $defaultAvailableCount > 0;

        $editSelectedFilter = old('filter_type', $section->filter ?? $defaultFilterKey);
        if ($editSelectedFilter === null || ! array_key_exists($editSelectedFilter, $filterLabels)) {
            $editSelectedFilter = $defaultFilterKey;
        }



    @endphp


    <section class="section">
        @can('feature-section-create')
            <div class="row">
                <form action="{{ route('feature-section.store') }}" class="create-form" method="POST" enctype="multipart/form-data" data-parsley-validate data-feature-section-context="create" data-zero-confirm-message="{{ $zeroConfirmMessage }}">
                    @csrf
                    <div class="col-md-8">
                        <div class="card">
                            <div class="card-header">{{__("Add Feature Section")}}</div>
                            <div class="card-body">
                                <div class="row mt-3">
                                    <div class="col-md-6">
                                        <div class="col-md-12 form-group mandatory">
                                            <label for="title" class="mandatory form-label">{{ __('Title') }}</label>
                                            <input type="text" name="title" id="title" class="form-control feature-section-name" data-parsley-required="true">
                                        </div>
                                    </div>
                                    <div class="col-md-6">
                                        <div class="col-md-12 form-group mandatory">
                                            <label for="slug" class="mandatory form-label">{{ __('Slug') }}</label>
                                            <input type="text" name="slug" id="slug" class="form-control feature-section-slug" data-parsley-required="true" data-initial-slug="{{ old("slug") }}" data-enforce-filter-slug="true">


                                            <small class="form-text text-muted" id="slug_filter_hint" data-template="{{ __('Allowed slugs for this filter: :list') }}">{{ __('Allowed slugs for this filter: :list', ['list' => $defaultFilterHint ?: __('N/A')]) }}</small>
                                            <small class="form-text text-muted">{{ __('The slug is prefilled from the selected filter. You can customize it as long as it matches one of the allowed slugs. It is different from the root_categories setting, which only controls the default category tree.') }}</small>



                                            <div class="alert alert-warning mt-2 d-none" role="alert" data-slug-exhausted="create">
                                                <i class="fas fa-exclamation-triangle me-1"></i>
                                                <span data-slug-exhausted-text="create">{{ $slugUnavailableMessage }}</span>
                                            </div>

                                        </div>
                                    </div>



                                <div class="row">
                                    <div class="col-md-6 form-group mandatory">
                                        <label for="filter_type" class=" form-label">{{ __('نوع المرشح') }}</label>
                                        <select id="filter_type" name="filter_type" class="form-control select2">
                                            @foreach ($filterLabels as $value => $label)
                                                @php
                                                    $optionLabel = trim((string) __($label));
                                                    if ($optionLabel === '') {
                                                        $optionLabel = (string) $label;
                                                    }
                                                    
                                                    $isUnavailable = isset($defaultDisabledFilters[$value]);

                                                @endphp
                                                <option value="{{ $value }}"
                                                    title="{{ e($optionLabel) }}"
                                                    data-filter-label="{{ e($optionLabel) }}"
                                                    @if ($isUnavailable) data-filter-unavailable="1" @endif
                                                    @selected($selectedFilter === $value)>{{ $optionLabel }}</option>
                                                
                                            @endforeach

                                        </select>

                                        <div class="form-text text-muted d-none" data-filter-disabled-help="create">
                                            <i class="fas fa-info-circle me-1"></i>{{ $filterDuplicateHint }}
                                        </div>
                                        <div class="alert alert-warning mt-2 {{ $defaultHasAvailableFilters ? 'd-none' : '' }}" role="alert" data-filter-exhausted="create">
                                            <i class="fas fa-exclamation-triangle me-1"></i>{{ $filterUnavailableMessage }}
                                        </div>

                                        <div class="mt-2 d-none" data-filter-usage-indicator="create" data-badge-class="bg-warning text-dark" data-status-label="{{ $filterUsageStatusLabel }}" data-sr-label="{{ $filterUsageSrLabel }}"></div>



                                    </div>
                                    <div class="col-md-6 form-group mandatory">
                                        <label for="section_type" class="mandatory form-label">{{ __('Section Type') }}</label>
                                        <select id="section_type" name="section_type" class="form-control select2" required data-root-badge-target="create">
                                            @foreach($sectionTypes as $type)
                                                <option value="{{ $type }}" @selected(($defaultSectionType ?? '') === $type)>{{ $sectionTypeLabels[$type] ?? __(ucwords(str_replace('_', ' ', $type))) }}</option>

                                                @endforeach
                                        </select>
                                        <div class="form-text mt-1">
                                            <span class="badge bg-light text-dark" data-root-badge data-context="create" data-template="{{ $rootBadgeTemplate }}" data-null-label="{{ $rootBadgeAll }}" data-missing-label="{{ $rootBadgeMissing }}"></span>
                                        </div>
                                    </div>
                                </div>


                                @php
                                    $createPriceRangeActive = old('filter_type', $selectedFilter ?? '') === 'price_range';
                                @endphp
                                <div class="row g-3 align-items-end {{ $createPriceRangeActive ? '' : 'd-none' }}" data-price-range-wrapper="create" data-initial-visible="{{ $createPriceRangeActive ? '1' : '0' }}">
                                    
                                    <div class="col-md-6">

                                        <div class="form-group">
                                            <label for="min_price" class="form-label">{{ __('Minimum Price') }}</label>
                                            <input type="number" name="min_price" id="min_price" class="form-control" min="0" step="0.01" inputmode="decimal" value="{{ old('min_price') }}" placeholder="{{ __('Enter minimum price') }}" data-price-range-input="min" @disabled(! $createPriceRangeActive)>
                                        </div>
                                    </div>
                                    <div class="col-md-6">
                                        <div class="form-group">
                                            <label for="max_price" class="form-label">{{ __('Maximum Price') }}</label>
                                            <input type="number" name="max_price" id="max_price" class="form-control" min="0" step="0.01" inputmode="decimal" value="{{ old('max_price') }}" placeholder="{{ __('Enter maximum price') }}" data-price-range-input="max" @disabled(! $createPriceRangeActive)>
                                        </div>
                                    </div>
                                </div>

                                </div>
                                <div class="row form-group mandatory">
                                    <label for="Field Name" class=" form-label">{{ __('Select Style for APP Section') }}</label>
                                    <div class="col-md-2 col-sm-2">
                                        <label class="radio-img">
                                            <input type="radio" name="style" value="style_1" required/>
                                            <img src="{{asset('/images/app_styles/style_1.png')}}" height="115px" width="130px"alt="style_1" class="style_image">
                                        </label>
                                    </div>
                                    <div class="col-md-2 col-sm-2">
                                        <label class="radio-img">
                                            <input type="radio" name="style" value="style_2"/>
                                            <img src="{{asset('/images/app_styles/style_2.png')}}" height="115px" width="130px"alt="style_2" class="style_image">
                                        </label>
                                    </div>

                                    <div class="col-md-2 col-sm-2">
                                        <label class="radio-img">
                                            <input type="radio" name="style" value="style_3"/>
                                            <img src="{{asset('/images/app_styles/style_3.png')}}" height="115px" width="130px"alt="style_3" class="style_image">
                                        </label>
                                    </div>

                                    <div class="col-md-2 col-sm-2">
                                        <label class="radio-img">
                                            <input type="radio" name="style" value="style_4"/>
                                            <img src="{{asset('/images/app_styles/style_4.png')}}" height="115px" width="130px"alt="style_4" class="style_image">
                                        </label>
                                    </div>

                                </div>
                                <div class="row">
                                    <div class="col-md-12 mb-2">
                                        <label for="description" class="mandatory form-label">{{ __('Description') }}</label>
                                        <textarea name="description" id="description" class="form-control" cols="10" rows="5"></textarea>
                                    </div>
                                </div>

                                <div class="row">
                                    <div class="col-md-12">
                                        <div class="form-check form-switch">
                                            <input type="hidden" name="is_active" value="0">
                                            <input class="form-check-input" type="checkbox" id="is_active" name="is_active" value="1" checked>
                                            <label class="form-check-label" for="is_active">{{ __('Active') }}</label>
                                        </div>
                                    </div>
                                </div>


                                <div class="col-md-12">
                                    <div class="d-flex flex-column flex-lg-row gap-3 align-items-lg-center">
                                        <div class="flex-grow-1">
                                            <div class="alert alert-warning d-none mb-0" data-zero-warning="create" role="alert" data-default-text="{{ $zeroWarningText }}" data-confirmed-text="{{ $zeroWarningConfirmedText }}">
                                                <div class="d-flex align-items-center gap-2">
                                                    <i class="fas fa-exclamation-triangle"></i>
                                                    <span data-zero-warning-text="create"></span>
                                                </div>
                                            </div>
                                            <div class="alert alert-info d-none mb-0 mt-2" data-flush-feedback="create" role="alert"></div>
                                        </div>
                                        <div class="ms-lg-auto d-flex flex-wrap gap-2 justify-content-end">
                                            <button type="button" class="btn btn-outline-info" data-preview-button="create">
                                                <i class="fas fa-eye me-1"></i>{{ __('Preview') }}
                                            </button>

                                            <button type="button" class="btn btn-outline-secondary" data-probe-button="create">
                                                <i class="fas fa-stethoscope me-1"></i>{{ __('Probe API') }}
                                            </button>
                                            <button type="button" class="btn btn-outline-danger" data-flush-button="create">
                                                <i class="fas fa-sync-alt me-1"></i>{{ __('Flush Cache') }}
                                            </button>
                                            <button class="btn btn-primary" type="submit" name="submit" data-filter-submit="create">
                                                <i class="fas fa-save me-1"></i>{{ __('Submit') }}
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </form>
            </div>
        @endcan

        <div class="card">
            <div class="card-body">
                <div class="row">
                    <div class="col-12">
                        <small class="text-danger">* {{__("To change the order, Drag the Table column Up & Down")}}</small>
                        {{-- Data loads via the dedicated feature-section.list endpoint --}}


                        <table class="table table-borderless table-striped" aria-describedby="mydesc"
                               id="table_list" data-toggle="table" data-url="{{ url('feature-section/list') }}?include_actions=1"
                               data-click-to-select="true" data-side-pagination="server" data-pagination="true"
                               data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true" data-search-align="right"
                               data-toolbar="#toolbar" data-show-columns="true" data-show-refresh="true"
                               data-fixed-columns="true" data-fixed-number="1" data-fixed-right-number="1"
                               data-trim-on-search="false" data-responsive="true"
                               data-pagination-successively-size="3" data-query-params="queryParams"
                               data-escape="true"
                               data-reorderable-rows="true"
                               data-use-row-attr-func="true" data-table="feature_sections"
                               data-show-export="true" data-export-options='{"fileName": "featured-section-list","ignoreColumn": ["operate"]}' data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']"
                               data-mobile-responsive="true">
                            <thead class="thead-dark">
                            <tr>
                                <th scope="col" data-field="id" data-sortable="true">{{ __('ID') }}</th>
                                <th scope="col" data-field="style" data-formatter="styleImageFormatter">{{ __('Style') }}</th>
                                <th scope="col" data-field="title" data-sortable="true">{{ __('Title') }}</th>
                                <th scope="col" data-field="slug" data-sortable="true">{{ __('Slug') }}</th>
                                <th scope="col" data-field="section_type" data-sortable="true" data-formatter="featureSectionTypeFormatter">{{ __('Section Type') }}</th>

                                <th scope="col" data-field="description" data-sortable="true">{{ __('Description') }}</th>
                                <th scope="col" data-field="filter" data-sortable="true" data-formatter="filterTextFormatter">{{ __('Filters') }}</th>
                                <th scope="col" data-field="total_data" data-sortable="true" data-align="center">{{ __('Total Data') }}</th>
                                <th scope="col" data-field="sequence" data-sortable="true">{{ __('Sequence') }}</th>
                                <th scope="col" data-field="is_active" data-formatter="featureSectionStatusFormatter" data-events="featureSectionStatusEvents">{{ __('Status') }}</th>


                                <th scope="col" data-field="values_text" data-sortable="false" data-visible="false">{{ __('Value') }}</th>
                                @canany(['feature-section-update', 'feature-section-delete'])
                                    <th scope="col" data-field="operate" data-escape="false" data-sortable="false" data-events="featuredSectionEvents">{{ __('Action') }}</th>
                                @endcanany
                            </tr>
                            </thead>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        @can('feature-section-update')
        <!-- EDIT MODEL MODEL -->
            <div id="editModal" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="myModalLabel1" aria-hidden="true">
                <div class="modal-dialog modal-dialog-centered modal-dialog-scrollable modal-xl">


                    <div class="modal-content shadow-lg border-0">
                        <form action="" id="feature-section-edit-form" class="form-horizontal edit-form" enctype="multipart/form-data" method="POST" novalidate data-feature-section-context="edit" data-zero-confirm-message="{{ $zeroConfirmMessage }}">
                            @csrf
                            <div class="modal-header bg-gradient-primary text-white border-0 sticky-modal-header">
                                <div class="d-flex align-items-center w-100 gap-3 flex-wrap">
                                    <h5 class="modal-title fw-bold d-flex align-items-center mb-0" id="myModalLabel1">
                                        <i class="fas fa-edit me-2"></i>{{ __('Edit feature Section') }}
                                    </h5>
                                    <div class="ms-auto d-flex flex-column flex-md-row align-items-md-center gap-2 flex-wrap w-100 w-md-auto">
                                        <div class="flex-grow-1">
                                            <div class="alert alert-warning d-none mb-0" data-zero-warning="edit" role="alert" data-default-text="{{ $zeroWarningText }}" data-confirmed-text="{{ $zeroWarningConfirmedText }}">
                                                <div class="d-flex align-items-center gap-2">
                                                    <i class="fas fa-exclamation-triangle"></i>
                                                    <span data-zero-warning-text="edit"></span>
                                                </div>
                                            </div>
                                            <div class="alert alert-info d-none mb-0 mt-2" data-flush-feedback="edit" role="alert"></div>
                                        </div>
                                        <div class="d-flex align-items-center gap-2 flex-wrap ms-md-auto">
                                            <button type="button" class="btn btn-outline-info btn-sm" data-preview-button="edit">
                                                <i class="fas fa-eye me-1"></i>{{ __('Preview') }}
                                            </button>
                                            <button type="button" class="btn btn-outline-secondary btn-sm" data-probe-button="edit">
                                                <i class="fas fa-stethoscope me-1"></i>{{ __('Probe API') }}
                                            </button>
                                            <button type="button" class="btn btn-outline-danger btn-sm" data-flush-button="edit">
                                                <i class="fas fa-sync-alt me-1"></i>{{ __('Flush Cache') }}
                                            </button>
                                            <button type="submit" class="btn btn-light btn-sm text-primary fw-bold shadow-sm order-2 order-md-1" data-filter-submit="edit">
                                                <i class="fas fa-save me-1"></i><span>{{ __('Save Changes') }}</span>
                                            </button>
                                            <button type="button" class="btn-close btn-close-white order-1 order-md-2" data-bs-dismiss="modal" aria-label="Close"></button>
                                        </div>
                                    </div>
                                </div>


                            </div>
                            <div class="modal-body p-4 bg-light">
                                <!-- Basic Information Section -->
                                <div class="card border-0 shadow-sm mb-4 hover-card">
                                    <div class="card-header bg-gradient-info text-white border-0">
                                        <h6 class="mb-0 fw-bold"><i class="fas fa-info-circle me-2"></i>{{ __('Basic Information') }}</h6>
                                    </div>
                                    <div class="card-body">
                                        <div class="row">
                                            <div class="col-md-6">
                                                <div class="form-group mb-3">
                                                    <label for="edit_title" class="form-label fw-bold">{{ __('Title') }} <span class="text-danger">*</span></label>
                                                    <input type="text" name="title" id="edit_title" class="form-control edit-feature-section-name" data-parsley-required="true" placeholder="{{ __('Enter section title') }}">
                                                </div>
                                            </div>
                                            <div class="col-md-6">
                                                <div class="form-group mb-3">
                                                    <label for="edit_slug" class="form-label fw-bold">{{ __('Slug') }} <span class="text-danger">*</span></label>

                                                    <input type="text" name="slug" id="edit_slug" class="form-control edit-feature-section-slug" data-parsley-required="true" data-enforce-filter-slug="true">

                                                    <small class="form-text text-muted" id="edit_slug_filter_hint" data-template="{{ __('Allowed slugs for this filter: :list') }}">{{ __('Allowed slugs for this filter: :list', ['list' => $defaultFilterHint?: __('N/A')]) }}</small>
                                                    <small class="form-text text-muted">{{ __('The slug is prefilled from the selected filter. You can customize it as long as it matches one of the allowed slugs. It is different from the root_categories setting, which only controls the default category tree.') }}</small>

                                                    <div class="alert alert-warning mt-2 d-none" role="alert" data-slug-exhausted="edit">
                                                        <i class="fas fa-exclamation-triangle me-1"></i>
                                                        <span data-slug-exhausted-text="edit">{{ $slugUnavailableMessage }}</span>
                                                    </div>

                                                </div>
                                            </div>
                                        </div>
                                        <div class="row">
                                            <div class="col-md-6">
                                                <div class="form-group mb-3">
                                                    <label for="edit_filter_type" class="form-label fw-bold">{{ __('نوع المرشح') }} <span class="text-danger">*</span></label>
                                                    <select id="edit_filter_type" name="filter_type" class="form-control select2">
                                                        @foreach ($filterLabels as $value => $label)
                                                            @php
                                                                $optionLabel = trim((string) __($label));
                                                                if ($optionLabel === '') {
                                                                    $optionLabel = (string) $label;
                                                                }

                                                                $isUnavailable = isset($defaultDisabledFilters[$value]) && $editSelectedFilter !== $value;

                                                            @endphp
                                                            <option value="{{ $value }}"
                                                                title="{{ e($optionLabel) }}"
                                                                data-filter-label="{{ e($optionLabel) }}"
                                                                @if ($isUnavailable) data-filter-unavailable="1" @endif
                                                                @selected($editSelectedFilter === $value)>{{ $optionLabel }}</option>   
                                                        @endforeach


                                                    </select>

                                                    <div class="form-text text-muted d-none" data-filter-disabled-help="edit">
                                                        <i class="fas fa-info-circle me-1"></i>{{ $filterDuplicateHint }}
                                                    </div>
                                                    <div class="alert alert-warning mt-2 d-none" role="alert" data-filter-exhausted="edit">
                                                        <i class="fas fa-exclamation-triangle me-1"></i>{{ $filterUnavailableMessage }}
                                                    </div>
                                                    <div class="mt-2 d-none" data-filter-usage-indicator="edit" data-badge-class="bg-warning text-dark" data-status-label="{{ $filterUsageStatusLabel }}" data-sr-label="{{ $filterUsageSrLabel }}"></div>



                                                </div>
                                            </div>
                                            <div class="col-md-6">
                                                <div class="form-group mb-3">
                                                    <label for="edit_section_type" class="form-label fw-bold">{{ __('Section Type') }} <span class="text-danger">*</span></label>
                                                    <select id="edit_section_type" name="section_type" class="form-control select2" required data-root-badge-target="edit">
                                                        @foreach($sectionTypes as $type)
                                                            <option value="{{ $type }}">{{ $sectionTypeLabels[$type] ?? __(ucwords(str_replace('_', ' ', $type))) }}</option>
                                                        @endforeach


                                                    </select>
                                                    <div class="form-text mt-1">
                                                        <span class="badge bg-light text-dark" data-root-badge data-context="edit" data-template="{{ $rootBadgeTemplate }}" data-null-label="{{ $rootBadgeAll }}" data-missing-label="{{ $rootBadgeMissing }}"></span>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>


                                        <div class="row g-3 align-items-end d-none" data-price-range-wrapper="edit">
                                            <div class="col-md-6">
                                                <div class="form-group mb-3">
                                                    <label for="edit_min_price" class="form-label fw-bold">{{ __('Minimum Price') }}</label>
                                                    <input type="number" name="min_price" id="edit_min_price" class="form-control" min="0" step="0.01" inputmode="decimal" placeholder="{{ __('Enter minimum price') }}" data-price-range-input="min" disabled>
                                                </div>
                                            </div>
                                            <div class="col-md-6">
                                                <div class="form-group mb-3">
                                                    <label for="edit_max_price" class="form-label fw-bold">{{ __('Maximum Price') }}</label>
                                                    <input type="number" name="max_price" id="edit_max_price" class="form-control" min="0" step="0.01" inputmode="decimal" placeholder="{{ __('Enter maximum price') }}" data-price-range-input="max" disabled>
                                                </div>
                                            </div>
                                        </div>

                                        <div class="row">
                                            <div class="col-md-12">
                                                <div class="form-group mb-0">
                                                    <label for="edit_description" class="form-label fw-bold">{{ __('Description') }} <span class="text-danger">*</span></label>
                                                    <textarea id="edit_description" class="form-control" placeholder="{{__('Enter section description')}}" name="description" data-parsley-required="true" rows="3"></textarea>
                                                </div>
                                            </div>
                                        </div>


                                        <div class="row mt-3">
                                            <div class="col-md-12">
                                                <div class="form-check form-switch">
                                                    <input type="hidden" name="is_active" value="0">
                                                    <input class="form-check-input" type="checkbox" id="edit_is_active" name="is_active" value="1">
                                                    <label class="form-check-label" for="edit_is_active">{{ __('Active') }}</label>
                                                </div>
                                            </div>
                                        </div>

                                    </div>
                                </div>

                                <!-- Filter Criteria Section -->

                                <!-- Style Selection Section -->
                                <div class="card border-0 shadow-sm mb-0 hover-card">
                                    <div class="card-header bg-gradient-success text-white border-0">
                                        <h6 class="mb-0 fw-bold"><i class="fas fa-palette me-2"></i>{{ __('Select Style for APP Section') }}</h6>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-md-3 col-sm-6">
                                                <label class="radio-img d-block text-center p-2 border rounded hover-shadow" style="cursor: pointer; transition: all 0.3s ease;">
                                                    <input type="radio" name="style" value="style_1" required class="d-none"/>
                                                    <img src="{{asset('/images/app_styles/style_1.png')}}" class="img-fluid rounded mb-2" alt="style_1" style="max-height: 100px;">
                                                    <div class="fw-bold text-muted small">{{ __('Style 1') }}</div>
                                                </label>
                                            </div>
                                            <div class="col-md-3 col-sm-6">
                                                <label class="radio-img d-block text-center p-2 border rounded hover-shadow" style="cursor: pointer; transition: all 0.3s ease;">
                                                    <input type="radio" name="style" value="style_2" required class="d-none"/>
                                                    <img src="{{asset('/images/app_styles/style_2.png')}}" class="img-fluid rounded mb-2" alt="style_2" style="max-height: 100px;">
                                                    <div class="fw-bold text-muted small">{{ __('Style 2') }}</div>
                                                </label>
                                            </div>
                                            <div class="col-md-3 col-sm-6">
                                                <label class="radio-img d-block text-center p-2 border rounded hover-shadow" style="cursor: pointer; transition: all 0.3s ease;">
                                                    <input type="radio" name="style" value="style_3" required class="d-none"/>
                                                    <img src="{{asset('/images/app_styles/style_3.png')}}" class="img-fluid rounded mb-2" alt="style_3" style="max-height: 100px;">
                                                    <div class="fw-bold text-muted small">{{ __('Style 3') }}</div>
                                                </label>
                                            </div>
                                            <div class="col-md-3 col-sm-6">
                                                <label class="radio-img d-block text-center p-2 border rounded hover-shadow" style="cursor: pointer; transition: all 0.3s ease;">
                                                    <input type="radio" name="style" value="style_4" required class="d-none"/>
                                                    <img src="{{asset('/images/app_styles/style_4.png')}}" class="img-fluid rounded mb-2" alt="style_4" style="max-height: 100px;">
                                                    <div class="fw-bold text-muted small">{{ __('Style 4') }}</div>
                                                </label>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                              <div class="modal-footer bg-gradient-light border-0 p-3 sticky-modal-footer">
                                <div class="d-grid gap-2 d-md-flex w-100 justify-content-md-end">
                                    <button type="button" class="btn btn-outline-secondary shadow-sm" data-bs-dismiss="modal">
                                        <i class="fas fa-times me-2"></i>{{ __('Close') }}
                                    </button>
                                    <button type="submit" class="btn btn-primary shadow-sm" data-filter-submit="edit">
                                        <i class="fas fa-save me-2"></i>{{ __('Save Changes') }}
                                    </button>
                                </div>


                            </div>
                        </form>
                    </div>
                </div>
            </div>
        @endcan
        <div class="modal fade" id="featureSectionPreviewModal" tabindex="-1" aria-hidden="true">
            <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="featureSectionPreviewTitle">{{ $previewTitleText }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ $previewCloseText }}"></button>
                    </div>
                    <div class="modal-body">
                        <div class="alert alert-warning d-none" role="alert" data-preview-zero-warning>
                            <div class="d-flex align-items-center gap-2">
                                <i class="fas fa-exclamation-triangle"></i>
                                <span>{{ $zeroModalWarningText }}</span>
                            </div>
                        </div>
                        <div class="alert alert-info d-none" role="alert" data-preview-message></div>
                        <div class="table-responsive mb-3" data-preview-table-wrapper></div>
                        <pre class="bg-light border rounded p-3 text-break" data-preview-json></pre>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-warning d-none" data-preview-confirm-zero>
                            <i class="fas fa-exclamation-circle me-1"></i>{{ $zeroModalConfirmText }}
                        </button>
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">{{ $previewCloseText }}</button>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
@section('js')
    <style>
        /* Enhanced Modal Styles */
        .hover-shadow:hover {
            box-shadow: 0 4px 15px rgba(0, 123, 255, 0.3) !important;
            border-color: #007bff !important;
            transform: translateY(-2px);
        }




        #editModal .sticky-modal-header {
            position: sticky;
            top: 0;
            z-index: 1056;
        }

        #editModal .sticky-modal-footer {
            position: sticky;
            bottom: 0;
            z-index: 1056;
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%) !important;
            box-shadow: 0 -4px 12px rgba(0, 0, 0, 0.08);
        }

        #editModal .sticky-modal-footer .btn {
            min-height: 48px;
        }

        #editModal .modal-body {
            padding-bottom: 0;
        }




        .radio-img input[type="radio"]:checked + img {
            border: 3px solid #007bff;
            box-shadow: 0 0 10px rgba(0, 123, 255, 0.5);
        }


        .radio-img.selected {
            border-color: #007bff !important;
            box-shadow: 0 8px 18px rgba(0, 123, 255, 0.18);
        }


        .radio-img input[type="radio"]:checked ~ .fw-bold {
            color: #007bff !important;
        }

        .card {
            transition: all 0.3s ease;
        }

        .form-control:focus {
            border-color: #007bff;
            box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
        }

        .select2-container--default .select2-selection--single:focus,
        .select2-container--default .select2-selection--multiple:focus {
            border-color: #007bff;
            box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
        }

        .modal-header.bg-primary {
            background: linear-gradient(135deg, #007bff 0%, #0056b3 100%) !important;
        }

        .card-header.bg-light {
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%) !important;
            border-bottom: 1px solid #dee2e6;
        }

        .btn-primary {
            background: linear-gradient(135deg, #007bff 0%, #0056b3 100%);
            border: none;
            transition: all 0.3s ease;
        }

        .btn-primary:hover {
            background: linear-gradient(135deg, #0056b3 0%, #004085 100%);
            transform: translateY(-1px);
            box-shadow: 0 4px 8px rgba(0, 123, 255, 0.3);
        }

        .btn-outline-secondary:hover {
            transform: translateY(-1px);
            box-shadow: 0 2px 4px rgba(108, 117, 125, 0.3);
        }

        @media (max-width: 768px) {
            .modal-xl {
                max-width: 95% !important;
            }

            .radio-img img {
                max-height: 80px !important;
            }
        }
    </style>
    <script>
        window.featureSectionCategoriesUrl = @json(route('feature-section.categories'));
        window.featureSectionTypeAliasMap = @json($featureSectionAliasMap);
        window.featureSectionTypeLabels = @json($sectionTypeLabels);
        window.featureSectionAllowedSlugsMap = @json($filterSlugOptions);
        window.featureSectionCanonicalSlugMap = @json($filterCanonicalSlugs);
        window.featureSectionFilterLabels = @json($filterLabels);
        window.featureSectionUsedSlugsMap = @json($usedFilterSlugMap);
        window.featureSectionFilterTakenMessage = @json($filterTakenMessage);
        window.featureSectionFilterUnavailableMessage = @json($filterUnavailableMessage);
        window.featureSectionFilterUsageStatusLabel = @json($filterUsageStatusLabel);
        window.featureSectionFilterUsageSrLabel = @json($filterUsageSrLabel);
        window.featureSectionDefaultType = @json($defaultSectionType);
        window.featureSectionPreviewUrl = @json($previewRoute);
        window.featureSectionProbeUrl = @json($probeRoute);
        window.featureSectionFlushUrl = @json($flushCacheRoute);
        window.featureSectionRootIdentifiers = @json($rootIdentifiers);
        window.featureSectionRootBadgeTemplate = @json($rootBadgeTemplate);
        window.featureSectionRootBadgeAll = @json($rootBadgeAll);
        window.featureSectionRootBadgeMissing = @json($rootBadgeMissing);
        window.featureSectionPreviewTitle = @json($previewTitleText);
        window.featureSectionProbeTitle = @json($probeTitleText);
        window.featureSectionPreviewNoSections = @json($previewNoSectionsText);
        window.featureSectionPreviewColumns = @json($previewColumns);
        window.featureSectionFlushMessages = @json($flushMessages);
        window.featureSectionStatusLabels = @json($statusLabels);
        window.featureSectionStatusMessages = @json($statusMessages);
        window.featureSectionStatusRouteTemplate = @json(route('feature-section.status', ['feature_section' => '__ID__']));


        $(document).ready(function() {

            if (typeof window.loadFeatureSectionCategories === 'function') {
                const $createSectionSelect = $('#section_type');
                const $createCategorySelect = $('#category_id');

                if ($createSectionSelect.length && $createCategorySelect.length) {
                    window.loadFeatureSectionCategories($createSectionSelect.val(), $createCategorySelect);
                }
            }

            // Enhanced radio button selection for styles

            const canonicalSlugMap = window.featureSectionCanonicalSlugMap || {};


            const usedSlugMap = window.featureSectionUsedSlugsMap || {};
            const filterLabelsMap = window.featureSectionFilterLabels || {};
            const priceRangeFilterValue = 'price_range';

            const togglePriceRangeFields = (context, show) => {
                const $wrapper = $(`[data-price-range-wrapper="${context}"]`);

                if (!$wrapper.length) {
                    return;
                }

                const $inputs = $wrapper.find('[data-price-range-input]');

                if (show) {
                    $wrapper.removeClass('d-none');
                    $inputs.prop('disabled', false);


                } else {
                    $wrapper.addClass('d-none');
                    $inputs.prop('disabled', true);


                }
            };




            const getFilterLabel = (filter) => {
                const key = (filter || '').toString();

                if (!key) {
                    return '';
                }

                const label = filterLabelsMap[key];

                if (typeof label === 'string' && label.trim() !== '') {
                    return label.trim();
                }

                return key;
            };

            const $createTitle = $('#title');
            const $editTitle = $('#edit_title');

            const markTitleField = ($input) => {
                if (!$input.length) {
                    return;
                }

                $input.each(function() {
                    const $field = $(this);
                    $field.on('input', function() {
                        const currentValue = ($field.val() || '').toString().trim();
                        const autoValue = ($field.data('featureSectionAutoTitle') || '').toString().trim();
                        $field.data('featureSectionUserEdited', currentValue !== '' && currentValue !== autoValue);
                    });
                });
            };

            const autoFillTitleField = ($input, filter, options = {}) => {
                if (!$input.length) {
                    return;
                }

                const settings = { force: false, ...options };
                const label = getFilterLabel(filter);

                if (!label) {
                    return;
                }

                const previousAuto = ($input.data('featureSectionAutoTitle') || '').toString().trim();
                const currentValue = ($input.val() || '').toString().trim();
                const userEdited = $input.data('featureSectionUserEdited') === true;

                const shouldUpdate = settings.force
                    || !currentValue
                    || currentValue === previousAuto
                    || (!userEdited && currentValue === '');

                if (shouldUpdate) {
                    $input.val(label);
                    $input.data('featureSectionUserEdited', false);
                } else {
                    $input.data('featureSectionUserEdited', currentValue !== '' && currentValue !== label);
                }

                $input.data('featureSectionAutoTitle', label);
            };

            markTitleField($createTitle);
            markTitleField($editTitle);



            const filterTakenMessage = window.featureSectionFilterTakenMessage || '{{ __('This filter is already used for the selected section type. Please edit the existing feature section instead.') }}';
            const filterUnavailableMessage = window.featureSectionFilterUnavailableMessage || '{{ __('All filters for this section type are already in use. Please edit the existing feature section instead of creating a duplicate.') }}';

            const filterUsageStatusLabel = window.featureSectionFilterUsageStatusLabel || '{{ __('In use') }}';
            const filterUsageSrLabel = window.featureSectionFilterUsageSrLabel || '{{ __('Filter currently assigned to another section') }}';
            const deriveSlugForFilter = (filter) => {
                if (!filter) {
                    return '';
                }

                const canonical = (canonicalSlugMap[filter] || '').toString();

                if (canonical) {
                    return canonical;
                }

                return (filter || '').toString();
            };


            const resolveUsedSlugsForType = (sectionType) => {
                const key = (sectionType || '').toString();

                if (Object.prototype.hasOwnProperty.call(usedSlugMap, key)) {
                    return usedSlugMap[key] || {};
                }

                if (Object.prototype.hasOwnProperty.call(usedSlugMap, key)) {
                    return usedSlugMap[key] || {};
                }

                return {};
            };

            const setSubmitDisabled = (context, disabled, options = {}) => {
                const $buttons = $(`[data-filter-submit="${context}"]`);
                const settings = (options && typeof options === 'object') ? options : {};
                const reason = settings.reason ?? null;


                if ($buttons.length) {
                    $buttons.prop('disabled', disabled);

                    if (disabled) {
                        const message = reason || filterUnavailableMessage;

                        if (message) {
                            $buttons.attr('title', message);
                            $buttons.data('disabledReason', message);
                        } else {
                            $buttons.removeAttr('title');
                            $buttons.removeData('disabledReason');
                        }
                    
                    } else {
                        $buttons.removeAttr('title');

                        $buttons.removeData('disabledReason');


                    }
                }
            };



  

            const renderFilterUsageBadges = (context, state) => {
                const $container = $(`[data-filter-usage-indicator="${context}"]`);

                if (!$container.length) {
                    return;
                }

                const takenFilters = Array.isArray(state?.takenFilters) ? state.takenFilters : [];

                $container.empty();

                if (!takenFilters.length) {
                    $container.addClass('d-none');
                    return;
                }

                const badgeClass = ($container.data('badgeClass') || 'bg-warning text-dark').toString();
                const statusLabel = ($container.data('statusLabel') || filterUsageStatusLabel || '').toString();
                const srLabel = ($container.data('srLabel') || filterUsageSrLabel || statusLabel).toString();

                takenFilters.forEach((item) => {
                    const value = (item?.value || '').toString();
                    const label = (item?.label || value).toString();

                    const slugs = Array.isArray(item?.slugs) ? item.slugs.filter(Boolean) : [];
                    const displayLabel = slugs.length ? `${label} (${slugs.join(', ')})` : label;

                    const $badge = $('<span>')
                        .addClass(`badge me-1 ${badgeClass}`.trim())
                        .attr('data-filter-used', value);

                    $badge.text(displayLabel);

                    if (statusLabel) {
                        $badge.append(document.createTextNode(` • ${statusLabel}`));
                        $badge.attr('title', statusLabel);
                    }

                    if (srLabel) {
                        $badge.append($('<span>').addClass('visually-hidden').text(` ${srLabel}`));
                    }

                    $container.append($badge);
                });

                $container.removeClass('d-none');
            };



            const updateFilterAvailabilityMessages = (context, state) => {
                const availability = state || { hasDisabled: false, hasAvailable: true, hasUnused: true, totalOptions: 0, takenFilters: [] };
                const $help = $(`[data-filter-disabled-help="${context}"]`);
                const $alert = $(`[data-filter-exhausted="${context}"]`);
                const hasUnused = availability.hasUnused ?? availability.hasAvailable;

                if ($help.length) {
                    if (availability.hasDisabled) {
                        $help.removeClass('d-none');
                    } else {
                        $help.addClass('d-none');
                    }
                }

                if ($alert.length) {
                    if (!hasUnused && (availability.totalOptions ?? 0) > 0) {
                        $alert.removeClass('d-none');
                    } else {
                        $alert.addClass('d-none');
                    }
                }

                renderFilterUsageBadges(context, availability);

                if ((availability.totalOptions ?? 0) === 0) {
                    setSubmitDisabled(context, true);
                }            
            };

            const updateFilterOptionAvailability = ($select, sectionType, options = {}) => {
                if (!$select.length) {
                    return {
                        disabledCount: 0,
                        availableCount: 0,
                        totalOptions: 0,
                        hasAvailable: false,
                        hasDisabled: false,
                        hasUnused: false,
                        takenFilters: [],
                        usedSlugs: {},
                    };                
                }

                const { currentSlug = null } = options;
                const usedForType = resolveUsedSlugsForType(sectionType);
                const usedSlugs = new Set(Object.keys(usedForType || {}));

                let disabledCount = 0;
                let availableCount = 0;
                let totalOptions = 0;
                const takenFilters = [];

                $select.find('option').each(function() {
                    const $option = $(this);
                    const filter = ($option.val() || '').toString();
                    totalOptions += 1;

                    if (!filter) {
                        availableCount += 1;
                        $option.removeAttr('data-filter-unavailable');



                        if ($option.attr('title') === filterTakenMessage) {
                            $option.removeAttr('title');

                        }

                        return;
                    }







                    

                        $option.attr('data-filter-unavailable', '1');

                        if (filterTakenMessage) {
                            $option.attr('title', filterTakenMessage);
                        }

                        takenFilters.push({
                            value: filter,
                            label: filterLabelsMap[filter] || $option.text().trim() || filter,
                            slugs: slug ? [slug] : [],
                        });


                        disabledCount += 1;

                        return;
                    }



                    $option.removeAttr('data-filter-unavailable');

                    if ($option.attr('title') === filterTakenMessage) {
                        $option.removeAttr('title');
                    }

                    availableCount += 1;


                });



                return {
                    disabledCount,
                    availableCount,
                    totalOptions,
                    hasAvailable: totalOptions > 0,
                    hasDisabled: disabledCount > 0,
                    hasUnused: availableCount > 0,
                    takenFilters,
                    usedSlugs: usedForType,


                };
            };

            const renderSlugHint = ($select, $target) => {
                if (!$select.length || !$target.length) {
                    return;
                }

                const filter = $select.val();
                const slugs = getAllowedSlugsForFilter(filter);
                const template = $target.data('template') || ':list';
                const listText = slugs.length ? slugs.join(', ') : (filter || '-');

                $target.text(template.replace(':list', listText));
            };

            const setSlugFieldValue = ($input, filter, options = {}) => {
                if (!$input.length) {
                    return '';
                }

                const settings = {
                    preferredSlug: '',
                    fallbackSlug: '',
                    ...options,
 
                };

                let value = (settings.preferredSlug || '').toString().trim();
                if (!value) {
                    value = deriveSlugForFilter(filter);

                if (!value) {
                    value = (settings.fallbackSlug || '').toString().trim();


                    if (!slugValue) {
                        return;
                    }

                    const exists = $select.find('option').filter((_, element) => $(element).val() === slugValue).length > 0;

                    if (exists) {
                        return;
                    }

                    const previous = getPreviousOption(slugValue);
                    const text = previous?.text || slugValue;


                    addOption(slugValue, text, {
                        disabled: previous?.disabled ?? false,
                        unavailable: previous?.unavailable ?? false,
                    });
                };

                if (!filter) {
                    if (previousOptions.length) {
                        rebuildOptions(previousOptions);
                    } else {
                        addOption('', '');
                    }


                    const hasPreferred = preferredSlug && $select.find('option').filter((_, element) => {
                        const $element = $(element);
                        return $element.val() === preferredSlug && !$element.prop('disabled');
                    }).length > 0;

                    const selectedValue = hasPreferred ? preferredSlug : '';

                    $select.val(selectedValue);




                    $select.prop('disabled', true);
                    $select.data('slugExhausted', '0');

                    triggerSelectUpdate($select);

                    return { selected: selectedValue, hasOptions: false, exhausted: false };
                }

                if (allowedSlugs.length === 0) {
                    if (previousOptions.length) {
                        rebuildOptions(previousOptions);
                    } else {
                        addOption('', '');

                    }
                } else {
                    allowedSlugs.forEach((slug) => {
                        const value = (slug || '').toString();
                        
                        if (!value) {
                            return;
                        }



                        const isCurrent = currentSlug && value === currentSlug;
                        const isUsed = usedSlugs.has(value) && !isCurrent;

                        addOption(value, value, {
                            disabled: isUsed,
                            unavailable: isUsed,
                        });
                    });
                }

                $input.val(value);


                return value;

            };

            const $createFilter = $('#filter_type');
            const $createHint = $('#slug_filter_hint');
            const $createSlug = $('#slug');

            const $editFilter = $('#edit_filter_type');
            const $editHint = $('#edit_slug_filter_hint');
            const $editSlug = $('#edit_slug');

            const $createSectionType = $('#section_type');
            const $editSectionType = $('#edit_section_type');


            const getDataString = ($element, key) => {
                if (!$element.length) {
                    return '';
                }
                const value = $element.data(key);


                if (typeof value === 'string') {
                    return value;
                }

                return '';
            };




            const refreshCreateFilterState = ({ preferredSlug = null } = {}) => {


                if (!$createFilter.length) {
                    return;
                }


                const sectionType = $createSectionType.val();
                const state = updateFilterOptionAvailability($createFilter, sectionType, { context: 'create' });

                updateFilterAvailabilityMessages('create', state);
                renderSlugHint($createFilter, $createHint);

                const filterValue = $createFilter.val();
                let initialSlug = preferredSlug;

                if (initialSlug === null) {
                    initialSlug = getDataString($createSlug, 'initialSlug');
                }

                const currentSlug = ($createSlug.val() || '').toString();
                togglePriceRangeFields('create', filterValue === priceRangeFilterValue);

                


                setSlugFieldValue($createSlug, filterValue, {
                    preferredSlug: initialSlug || currentSlug,
                });

                if (initialSlug) {
                    $createSlug.removeData('initialSlug');
                }

                autoFillTitleField($createTitle, filterValue);


                const $selectedOption = $createFilter.find('option:selected');
                const filterUnavailable = $selectedOption.is('[data-filter-unavailable]');
                const disableSubmit = !filterValue || filterUnavailable;
                const reason = filterUnavailable ? filterTakenMessage : null;

                setSubmitDisabled('create', disableSubmit, { reason });
            
            };

            const refreshEditFilterState = ({ autoFill = false } = {}) => {
                if (!$editFilter.length) {
                    return;
                }

                const sectionType = $editSectionType.val();
                const currentSlug = getDataString($editSlug, 'featureSectionCurrentSlug');
                const state = updateFilterOptionAvailability($editFilter, sectionType, { currentSlug });


                updateFilterAvailabilityMessages('edit', state);
                renderSlugHint($editFilter, $editHint);

                const filterValue = ($editFilter.val() || '').toString();
                let preferredSlug = '';

                if (!autoFill) {
                    preferredSlug = getDataString($editSlug, 'featureSectionPreferredSlug') || currentSlug;
                }


                togglePriceRangeFields('edit', filterValue === priceRangeFilterValue);



                setSlugFieldValue($editSlug, filterValue, {

                    preferredSlug,
                    autoSelect: true,
                });

                if (preferredSlug) {
                    $editSlug.removeData('featureSectionPreferredSlug');
                }
                autoFillTitleField($editTitle, filterValue, { force: autoFill });

                const $selectedOption = $editFilter.find('option:selected');
                const filterUnavailable = $selectedOption.is('[data-filter-unavailable]');
                const disableSubmit = !filterValue || filterUnavailable;
                const reason = filterUnavailable ? filterTakenMessage : null;

                setSubmitDisabled('edit', disableSubmit, { reason });

            };

            refreshCreateFilterState({ preferredSlug: getDataString($createSlug, 'initialSlug') || null });

            $createFilter.on('change', function() {
                const preferredSlug = ($createSlug.val() || '').toString();
                refreshCreateFilterState({ preferredSlug });
            });

            $createSectionType.on('change', function() {
                refreshCreateFilterState({ preferredSlug: ($createSlug.val() || '').toString() });





            });

            $('#editModal').on('shown.bs.modal', function () {
                refreshEditFilterState({ autoFill: false });
            });

            $editSectionType.on('change', function() {
                refreshEditFilterState({ autoFill: false });

            });

            $editFilter.on('change', function() {
                refreshEditFilterState({ autoFill: true });
            
            });

            

            $('.radio-img').on('click', function() {
                const $group = $(this).closest('.card-body');
                $group.find('.radio-img').removeClass('selected');

                $(this).addClass('selected');
                $(this).find('input[type="radio"]').prop('checked', true);
            });


            $('#editModal').on('shown.bs.modal', function () {
                const $modal = $(this);
                const $checkedStyle = $modal.find('input[name="style"]:checked');
                if ($checkedStyle.length) {
                    $modal.find('.radio-img').removeClass('selected');
                    $checkedStyle.closest('.radio-img').addClass('selected');
                }
                updateRootBadge($('#edit_section_type'));
            });

            const rootIdentifiers = window.featureSectionRootIdentifiers || {};
            const rootTemplate = window.featureSectionRootBadgeTemplate || 'Root: :value';
            const rootAll = window.featureSectionRootBadgeAll || 'All categories (no restriction)';
            const rootMissing = window.featureSectionRootBadgeMissing || 'No root configured';

            const previewUrl = window.featureSectionPreviewUrl || null;
            const probeUrl = window.featureSectionProbeUrl || null;
            const flushUrl = window.featureSectionFlushUrl || null;
            const previewTitle = window.featureSectionPreviewTitle || 'Preview Results';
            const probeTitle = window.featureSectionProbeTitle || 'Probe API Result';
            const previewNoSections = window.featureSectionPreviewNoSections || 'No sections were returned for this request.';
            const previewColumns = window.featureSectionPreviewColumns || {};
            const flushMessages = window.featureSectionFlushMessages || {};

            const previewModalElement = document.getElementById('featureSectionPreviewModal');
            const previewModal = previewModalElement ? new bootstrap.Modal(previewModalElement) : null;
            const $previewModal = $(previewModalElement || []);
            let previewActiveForm = null;

            const getContext = ($form) => $form.data('featureSectionContext') || ($form.hasClass('edit-form') ? 'edit' : 'create');
            const findWarning = (context) => $(`[data-zero-warning="${context}"]`);
            const findFlushFeedback = (context) => $(`[data-flush-feedback="${context}"]`);

            const updateRootBadge = ($select) => {
                if (!$select.length) {
                    return;
                }

                const context = $select.data('rootBadgeTarget');
                if (!context) {
                    return;
                }

                const $badge = $(`[data-root-badge][data-context="${context}"]`);
                if (!$badge.length) {
                    return;
                }

                const type = ($select.val() || '').toString();
                let resolved = rootMissing;

                if (Object.prototype.hasOwnProperty.call(rootIdentifiers, type)) {
                    const mapped = rootIdentifiers[type];

                    if (mapped === null) {
                        resolved = rootAll;
                    } else if (mapped === '') {
                        resolved = rootMissing;
                    } else {
                        resolved = mapped;
                    }
                }

                const template = $badge.data('template') || rootTemplate;
                $badge.text(template.replace(':value', resolved));
            };

            updateRootBadge($('#section_type'));
            updateRootBadge($('#edit_section_type'));

            $('#section_type').on('change', function() {
                const $select = $(this);
                updateRootBadge($select);
                refreshCreateFilterState({ preferredSlug: ($createSlug.val() || '').toString() });
            
            });

            $('#edit_section_type').on('change', function() {
                const $select = $(this);
                updateRootBadge($select);
                refreshEditFilterState({ autoFill: true });
            });

            $('[data-zero-warning]').each(function() {
                const $warning = $(this);
                const defaultText = $warning.data('defaultText') || '';
                const $text = $warning.find('[data-zero-warning-text]');

                if ($text.length) {
                    $text.text(defaultText);
                }
            });

            const updateWarning = ($form, show, confirmed = false) => {
                const context = getContext($form);
                const $warning = findWarning(context);

                if (!$warning.length) {
                    return;
                }

                const defaultText = $warning.data('defaultText') || '';
                const confirmedText = $warning.data('confirmedText') || defaultText;
                const $text = $warning.find('[data-zero-warning-text]');

                if (show) {
                    $warning.removeClass('d-none');
                    $warning.toggleClass('alert-warning', !confirmed);
                    $warning.toggleClass('alert-info', confirmed);

                    if ($text.length) {
                        $text.text(confirmed ? confirmedText : defaultText);
                    }
                } else {
                    $warning.addClass('d-none');
                    $warning.removeClass('alert-info').addClass('alert-warning');

                    if ($text.length) {
                        $text.text(defaultText);
                    }
                }
            };

            const confirmZeroForForm = ($form) => {
                $form.data('featureSectionZeroConfirmed', true);
                updateWarning($form, true, true);
            };

            const setFormTotals = ($form, total) => {
                $form.data('featureSectionLastTotal', total);

                if (Number.isFinite(total) && total === 0) {
                    $form.data('featureSectionZeroConfirmed', false);
                    updateWarning($form, true, false);
                } else {
                    $form.data('featureSectionZeroConfirmed', true);
                    updateWarning($form, false);
                }
            };

            const gatherFormData = ($form) => {


                const slugField = $form.find('[name="slug"]');
                const rawSlug = slugField.length ? slugField.val() : '';
                const normalizedSlug = Array.isArray(rawSlug) ? (rawSlug[0] ?? '') : (rawSlug ?? '');
                const filterValue = $form.find('select[name="filter_type"]').val();

                const formData = {
                    title: ($form.find('input[name="title"]').val() || '').trim(),
                    slug: normalizedSlug.toString().trim(),
                    filter: filterValue,
                    section_type: $form.find('select[name="section_type"]').val(),
                    filter_type: filterValue,

                    description: ($form.find('textarea[name="description"]').val() || '').trim(),
                    style: $form.find('input[name="style"]:checked').val() || null,
                };

                const $isActiveInput = $form.find('input[type="checkbox"][name="is_active"]').first();
                if ($isActiveInput.length) {
                    formData.is_active = $isActiveInput.prop('checked') ? 1 : 0;
                }


                const limitField = $form.find('input[name="limit"], input[name="value[limit]"]').first();

                if (limitField.length) {
                    formData.limit = limitField.val();
                }




                if (filterValue === priceRangeFilterValue) {
                    const minPriceField = $form.find('input[name="min_price"]').first();
                    if (minPriceField.length) {
                        formData.min_price = (minPriceField.val() ?? '').toString().trim();
                    }

                    const maxPriceField = $form.find('input[name="max_price"]').first();
                    if (maxPriceField.length) {
                        formData.max_price = (maxPriceField.val() ?? '').toString().trim();
                    }
                }


                return formData;
            };

            const getCsrfToken = ($form) => $form.find('input[name="_token"]').val() || $('meta[name="csrf-token"]').attr('content');

            const escapeHtml = (value) => $('<div>').text(value ?? '').html();

            const buildSectionsTable = (sections) => {
                if (!Array.isArray(sections) || sections.length === 0) {
                    return `<p class="text-muted mb-0">${escapeHtml(previewNoSections)}</p>`;
                }

                const titleHeader = escapeHtml(previewColumns.title || 'Title');
                const slugHeader = escapeHtml(previewColumns.slug || 'Slug');
                const typeHeader = escapeHtml(previewColumns.sectionType || 'Section Type');
                const totalHeader = escapeHtml(previewColumns.total || 'Items');

                let html = '<table class="table table-sm table-striped align-middle mb-0">';
                html += `<thead><tr><th style="width:4rem">#</th><th>${titleHeader}</th><th>${slugHeader}</th><th>${typeHeader}</th><th class="text-end">${totalHeader}</th></tr></thead><tbody>`;

                sections.forEach((section, index) => {
                    const title = escapeHtml(section.title || '-');
                    const slug = escapeHtml(section.slug || '-');
                    const type = escapeHtml(section.section_type || '-');
                    const items = Array.isArray(section.section_data) ? section.section_data.length : (section.total_data ?? 0);
                    html += `<tr><td>${index + 1}</td><td>${title}</td><td>${slug}</td><td>${type}</td><td class="text-end">${items}</td></tr>`;
                });

                html += '</tbody></table>';

                return html;
            };

            const showPreviewModal = (title, sections, response, options = {}) => {
                if (!previewModal) {
                    return;
                }

                const { warning = false, message = '', showConfirm = false } = options;
                const $zeroWarning = $previewModal.find('[data-preview-zero-warning]');
                const $message = $previewModal.find('[data-preview-message]');
                const $tableWrapper = $previewModal.find('[data-preview-table-wrapper]');
                const $jsonTarget = $previewModal.find('[data-preview-json]');
                const $confirmButton = $previewModal.find('[data-preview-confirm-zero]');

                $('#featureSectionPreviewTitle').text(title);

                if (warning) {
                    $zeroWarning.removeClass('d-none');
                } else {
                    $zeroWarning.addClass('d-none');
                }

                if (message) {
                    $message.removeClass('d-none alert-danger alert-warning alert-success').addClass('alert-info').text(message);
                } else {
                    $message.addClass('d-none').text('');
                }

                $tableWrapper.html(buildSectionsTable(sections));

                try {
                    $jsonTarget.text(JSON.stringify(response, null, 2));
                } catch (error) {
                    $jsonTarget.text('');
                }

                if (showConfirm) {
                    $confirmButton.removeClass('d-none');
                } else {
                    $confirmButton.addClass('d-none');
                }

                previewModal.show();
            };

            const handlePreviewSuccess = ($form, response, mode) => {
                const isPreview = mode === 'preview';
                let sections = [];
                let message = response?.message || '';
                let warning = false;
                let showConfirm = false;

                if (isPreview) {
                    const section = response?.section || null;
                    if (section) {
                        sections = [section];
                    }

                    const total = Number(response?.total_data ?? (section && section.total_data));

                    if (Number.isFinite(total)) {
                        setFormTotals($form, total);
                        warning = total === 0;
                        showConfirm = warning;
                    }
                } else {
                    const payload = response?.payload || {};
                    if (payload && Array.isArray(payload.data)) {
                        sections = payload.data;
                    } else if (payload?.data && Array.isArray(payload.data.data)) {
                        sections = payload.data.data;
                    }

                    if (!message && typeof payload?.message === 'string') {
                        message = payload.message;
                    }
                }

                showPreviewModal(isPreview ? previewTitle : probeTitle, sections, response, {
                    warning,
                    message,
                    showConfirm,
                });
            };

            const handlePreviewError = ($form, xhr) => {
                if (!previewModal) {
                    window.alert((xhr && xhr.statusText) || '{{ __('Error Occurred') }}');
                    return;
                }

                const message = xhr?.responseJSON?.message || xhr?.statusText || '{{ __('Error Occurred') }}';
                const $message = $previewModal.find('[data-preview-message]');
                const $tableWrapper = $previewModal.find('[data-preview-table-wrapper]');
                const $jsonTarget = $previewModal.find('[data-preview-json]');
                const $confirmButton = $previewModal.find('[data-preview-confirm-zero]');

                $('#featureSectionPreviewTitle').text(previewTitle);
                $previewModal.find('[data-preview-zero-warning]').addClass('d-none');

                $message.removeClass('d-none alert-info alert-warning alert-success').addClass('alert-danger').text(message);
                $tableWrapper.html(`<p class="text-danger mb-0">${escapeHtml(message)}</p>`);

                try {
                    $jsonTarget.text(JSON.stringify(xhr?.responseJSON ?? {}, null, 2));
                } catch (error) {
                    $jsonTarget.text('');
                }

                $confirmButton.addClass('d-none');

                previewModal.show();
            };

            const requestPreview = ($form, mode, $trigger) => {
                const url = mode === 'probe' ? probeUrl : previewUrl;

                if (!url || !$form.length) {
                    return;
                }

                const data = gatherFormData($form);
                const token = getCsrfToken($form);

                if (token) {
                    data._token = token;
                }

                previewActiveForm = $form;

                if ($trigger && $trigger.length) {
                    $trigger.prop('disabled', true);
                }

                $.ajax({
                    url,
                    method: 'POST',
                    data,
                    success(response) {
                        handlePreviewSuccess($form, response, mode);
                    },
                    error(xhr) {
                        handlePreviewError($form, xhr);
                    },
                    complete() {
                        if ($trigger && $trigger.length) {
                            $trigger.prop('disabled', false);
                        }
                    },
                });
            };

            const flushCache = ($form, $trigger) => {
                if (!flushUrl || !$form.length) {
                    return;
                }

                const data = gatherFormData($form);

                if (!data.slug) {
                    const missingMessage = flushMessages.missingSlug || '{{ __('Slug is required before flushing the cache.') }}';
                    showFlushFeedback($form, missingMessage, 'warning');

                    return;
                }

                const token = getCsrfToken($form);
                if (token) {
                    data._token = token;
                }

                if ($trigger && $trigger.length) {
                    $trigger.prop('disabled', true);
                }

                $.ajax({
                    url: flushUrl,
                    method: 'POST',
                    data,
                    success(response) {
                        const keys = Array.isArray(response?.flushed) ? response.flushed.join(', ') : '';
                        const template = flushMessages.success || '{{ __('Cache cleared for keys: :keys') }}';
                        const message = template.replace(':keys', keys || '-');
                        showFlushFeedback($form, message, response?.success ? 'success' : 'warning');
                    },
                    error() {
                        const message = flushMessages.error || '{{ __('Unable to flush cache. Please try again.') }}';
                        showFlushFeedback($form, message, 'danger');
                    },
                    complete() {
                        if ($trigger && $trigger.length) {
                            $trigger.prop('disabled', false);
                        }
                    },
                });
            };

            const showFlushFeedback = ($form, message, type = 'info') => {
                const context = getContext($form);
                const $alert = findFlushFeedback(context);

                if (!$alert.length) {
                    return;
                }

                $alert.removeClass('alert-info alert-success alert-warning alert-danger');
                $alert.addClass(`alert-${type}`);
                $alert.text(message);
                $alert.removeClass('d-none');

                setTimeout(() => {
                    $alert.addClass('d-none');
                }, 5000);
            };

            if (previewModalElement) {
                previewModalElement.addEventListener('hidden.bs.modal', () => {
                    previewActiveForm = null;
                });
            }

            $previewModal.find('[data-preview-confirm-zero]').on('click', function() {
                if (previewActiveForm) {
                    confirmZeroForForm(previewActiveForm);
                }

                if (previewModal) {
                    previewModal.hide();
                }
            });

            $('[data-preview-button]').on('click', function() {
                const $button = $(this);
                const $form = $button.closest('form');

                requestPreview($form, 'preview', $button);
            });

            $('[data-probe-button]').on('click', function() {
                const $button = $(this);
                const $form = $button.closest('form');

                requestPreview($form, 'probe', $button);
            });

            $('[data-flush-button]').on('click', function() {
                const $button = $(this);
                const $form = $button.closest('form');

                flushCache($form, $button);
            });

            $('.create-form, .edit-form').each(function() {
                $(this).data('featureSectionZeroConfirmed', true);
            });

            $('.create-form, .edit-form').on('submit', function(event) {
                const $form = $(this);
                const total = Number($form.data('featureSectionLastTotal'));
                const zeroConfirmed = $form.data('featureSectionZeroConfirmed');

                if (Number.isFinite(total) && total === 0 && !zeroConfirmed) {
                    const message = $form.data('zeroConfirmMessage') || '{{ __('This configuration returned zero items. Continue with saving?') }}';

                    if (!window.confirm(message)) {
                        event.preventDefault();
                        event.stopImmediatePropagation();

                        return false;
                    }

                    confirmZeroForForm($form);
                }

                return true;
            });


            // Add smooth transitions for form elements
            $('.form-control, .select2').on('focus', function() {
                $(this).closest('.form-group').addClass('focused');
            }).on('blur', function() {
                $(this).closest('.form-group').removeClass('focused');
            });
        });
    </script>
@endsection
