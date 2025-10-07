<div class="items-filters h-100">
    <div class="d-lg-none text-end">

        <button
            class="btn btn-outline-primary btn-sm"
            type="button"
            data-bs-toggle="collapse"
            data-bs-target="#filters"
            aria-expanded="false"
            aria-controls="filters"
            data-filters-toggle
            data-show-label="{{ __('Show Filters') }}"
            data-hide-label="{{ __('Hide Filters') }}"
        >
            <i class="fa fa-sliders me-1"></i>
            <span data-filters-toggle-label>{{ __('Show Filters') }}</span>
        </button>
    </div>

    <div id="filters" class="collapse d-lg-block items-filters__body mt-4" data-filters-panel>
        <div class="row g-3" role="toolbar">
            <div class="col-12">
                <label for="filter" class="form-label fw-semibold">{{ __('Status') }}</label>
                <select class="form-select bootstrap-table-filter-control-status" id="filter">
                    <option value="">{{ __('All') }}</option>
                    <option value="review">{{ __('Under Review') }}</option>
                    <option value="approved">{{ __('Approved') }}</option>
                    <option value="rejected">{{ __('Rejected') }}</option>
                    <option value="sold out">{{ __('Sold Out') }}</option>
                </select>
            </div>
            <div class="col-12">
                <label for="category_filter" class="form-label fw-semibold">{{ __('Category') }}</label>
                <select
                    class="form-select select2"
                    id="category_filter"
                    name="category_filter"
                    data-placeholder="{{ __('Search Categories') }}"
                >
                    <option value="">{{ __('All Categories') }}</option>
                    @foreach($categories as $category)
                        <option value="{{ $category->id }}">{{ $category->name }}</option>
                    @endforeach
                </select>
            </div>
        </div>
    </div>
</div>