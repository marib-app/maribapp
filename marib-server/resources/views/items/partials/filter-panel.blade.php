<div class="items-filters row g-2 align-items-end" data-filters-panel role="toolbar">
    <div class="col-12 col-md-4 col-lg-3 col-xl-2">
        <label for="filter" class="form-label fw-semibold mb-1">{{ __('Status') }}</label>
        <select class="form-select form-select-sm bootstrap-table-filter-control-status" id="filter">
            <option value="">{{ __('All') }}</option>
            <option value="review">{{ __('Under Review') }}</option>
            <option value="approved">{{ __('Approved') }}</option>
            <option value="rejected">{{ __('Rejected') }}</option>
            <option value="sold out">{{ __('Sold Out') }}</option>
        </select>
    </div>
    <div class="col-12 col-md-4 col-lg-3 col-xl-2">
        <label for="category_filter" class="form-label fw-semibold mb-1">{{ __('Category') }}</label>
        <select
            class="form-select form-select-sm select2"
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
