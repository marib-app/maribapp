@extends('layouts.main')

@section('title', __('merchant_products.page.title'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">{{ __('merchant_products.page.subtitle') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end flex-wrap gap-2">
                <a href="{{ route('merchant.dashboard') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i>
                    {{ __('merchant_products.page.back') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    @php
        $availableTabs = ['catalog', 'create', 'inventory'];
        $activeTab = request('tab');
        if (! in_array($activeTab, $availableTabs, true)) {
            $activeTab = 'catalog';
        }
        $catalogQuery = collect($filters ?? [])
            ->filter(static fn ($value) => $value !== null && $value !== '')
            ->put('tab', 'catalog')
            ->all();
        $inventoryQuery = ['tab' => 'inventory'];
    @endphp

    <section class="section">
        @if (session('success'))
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                {{ session('success') }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('Close') }}"></button>
            </div>
        @endif

        @if ($errors->has('store'))
            <div class="alert alert-warning">
                {{ $errors->first('store') }}
            </div>
        @endif

        <div class="row g-3 mb-4">
            <div class="col-md-4">
                <div class="card h-100">
                    <div class="card-body">
                        <p class="text-muted mb-1">{{ __('merchant_products.cards.total') }}</p>
                        <h4 class="mb-0">{{ number_format($stats['total'] ?? 0) }}</h4>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card h-100">
                    <div class="card-body">
                        <p class="text-muted mb-1">{{ __('merchant_products.cards.active') }}</p>
                        <h4 class="mb-0 text-success">{{ number_format($stats['active'] ?? 0) }}</h4>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="card h-100">
                    <div class="card-body">
                        <p class="text-muted mb-1">{{ __('merchant_products.cards.pending') }}</p>
                        <h4 class="mb-0 text-warning">{{ number_format($stats['pending'] ?? 0) }}</h4>
                    </div>
                </div>
            </div>
        </div>

        @if ($missingLocation)
            <div class="alert alert-warning">
                {{ __('merchant_products.messages.location_required') }}
            </div>
        @endif

        <div class="card mb-4">
            <div class="card-body">
                <div class="nav nav-pills flex-column flex-lg-row gap-2" role="tablist">
                    <a class="nav-link d-flex align-items-center gap-2 {{ $activeTab === 'catalog' ? 'active' : '' }}"
                       href="{{ route('merchant.products.index', ['tab' => 'catalog']) }}">
                        <i class="bi bi-card-list"></i>
                        <span>{{ __('merchant_products.tabs.catalog') }}</span>
                    </a>
                    <a class="nav-link d-flex align-items-center gap-2 {{ $activeTab === 'create' ? 'active' : '' }}"
                       href="{{ route('merchant.products.index', ['tab' => 'create']) }}">
                        <i class="bi bi-plus-circle"></i>
                        <span>{{ __('merchant_products.tabs.create') }}</span>
                    </a>
                    <a class="nav-link d-flex align-items-center gap-2 {{ $activeTab === 'inventory' ? 'active' : '' }}"
                       href="{{ route('merchant.products.index', ['tab' => 'inventory']) }}">
                        <i class="bi bi-box-seam"></i>
                        <span>{{ __('merchant_products.tabs.inventory') }}</span>
                    </a>
                </div>
            </div>
        </div>

        <div class="tab-content">
            <div class="tab-pane fade {{ $activeTab === 'catalog' ? 'show active' : '' }}">
                <div class="card mb-3">
                    <div class="card-header">
                        <h5 class="mb-0">{{ __('merchant_products.catalog.filters_title') }}</h5>
                    </div>
                    <div class="card-body">
                        <form method="get" action="{{ route('merchant.products.index') }}">
                            <input type="hidden" name="tab" value="catalog">
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('merchant_products.catalog.search_placeholder') }}</label>
                                    <input type="text" name="search" class="form-control"
                                           placeholder="{{ __('merchant_products.catalog.search_placeholder') }}"
                                           value="{{ $filters['search'] ?? '' }}">
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">{{ __('merchant_products.catalog.status_label') }}</label>
                                    <select name="status" class="form-select">
                                        <option value="">{{ __('merchant_products.catalog.status_any') }}</option>
                                        @foreach ($statuses as $key => $label)
                                            <option value="{{ $key }}" @selected(($filters['status'] ?? '') === $key)>{{ $label }}</option>
                                        @endforeach
                                    </select>
                                </div>
                                <div class="col-md-3 d-flex gap-2 align-items-end">
                                    <button class="btn btn-primary flex-grow-1" type="submit">
                                        {{ __('merchant_products.actions.filters_apply') }}
                                    </button>
                                    <a href="{{ route('merchant.products.index', ['tab' => 'catalog']) }}"
                                       class="btn btn-outline-secondary">
                                        {{ __('merchant_products.actions.filters_reset') }}
                                    </a>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <h5 class="mb-0">{{ __('merchant_products.tabs.catalog') }}</h5>
                    </div>
                    <div class="card-body p-0">
                        @if ($items->isEmpty())
                            <p class="text-muted m-3">{{ __('merchant_products.catalog.empty') }}</p>
                        @else
                            <div class="table-responsive">
                                <table class="table align-middle mb-0">
                                    <thead>
                                        <tr>
                                            <th>{{ __('merchant_products.catalog.table_name') }}</th>
                                            <th>{{ __('merchant_products.catalog.table_status') }}</th>
                                            <th>{{ __('merchant_products.catalog.table_price') }}</th>
                                            <th>{{ __('merchant_products.catalog.table_stock') }}</th>
                                            <th>{{ __('merchant_products.catalog.table_updated') }}</th>
                                            <th>{{ __('merchant_products.catalog.table_actions') }}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        @foreach ($items as $item)
                                            @php
                                                $statusKey = str_replace(' ', '_', $item->status);
                                                $statusLabel = $statuses[$item->status] ?? __('merchant_products.status.' . $statusKey) ?? $item->status;
                                            @endphp
                                            <tr>
                                                <td>
                                                    <div class="fw-semibold">{{ $item->name }}</div>
                                                    <small class="text-muted">#{{ $item->id }}</small>
                                                </td>
                                                <td>
                                                    <span class="badge bg-light text-dark">{{ $statusLabel }}</span>
                                                </td>
                                                <td>
                                                    {{ number_format($item->price ?? 0, 2) }}
                                                    <small class="text-muted">{{ $item->currency ?? $defaultCurrency }}</small>
                                                </td>
                                                <td>{{ number_format($item->total_stock ?? 0) }}</td>
                                                <td>{{ optional($item->updated_at)->format('Y-m-d H:i') }}</td>
                                                <td>
                                                    <div class="d-flex flex-column gap-2">
                                                        <form method="post"
                                                              action="{{ route('merchant.products.status', ['item' => $item->id, 'tab' => 'catalog']) }}">
                                                            @csrf
                                                            @method('patch')
                                                            <div class="input-group input-group-sm">
                                                                <select name="status" class="form-select">
                                                                    @foreach ($statuses as $key => $label)
                                                                        <option value="{{ $key }}" @selected($item->status === $key)>
                                                                            {{ $label }}
                                                                        </option>
                                                                    @endforeach
                                                                </select>
                                                                <button class="btn btn-outline-primary" type="submit">
                                                                    <i class="bi bi-check2"></i>
                                                                    {{ __('merchant_products.status_form.submit') }}
                                                                </button>
                                                            </div>
                                                        </form>
                                                        <div class="d-flex gap-2">
                                                            <a href="{{ route('merchant.products.index', ['tab' => 'inventory', 'highlight' => $item->id]) }}"
                                                               class="btn btn-light btn-sm flex-grow-1">
                                                                <i class="bi bi-box"></i>
                                                                {{ __('merchant_products.catalog.manage_stock') }}
                                                            </a>
                                                            <form method="post"
                                                                  action="{{ route('merchant.products.destroy', ['item' => $item->id, 'tab' => 'catalog']) }}"
                                                                  onsubmit="return confirm('{{ __('merchant_products.catalog.delete') }}?');">
                                                                @csrf
                                                                @method('delete')
                                                                <button type="submit" class="btn btn-link text-danger btn-sm">
                                                                    <i class="bi bi-trash"></i>
                                                                </button>
                                                            </form>
                                                        </div>
                                                    </div>
                                                </td>
                                            </tr>
                                        @endforeach
                                    </tbody>
                                </table>
                            </div>
                            <div class="p-3">
                                {{ $items->appends($catalogQuery)->links() }}
                            </div>
                        @endif
                    </div>
                </div>
            </div>

            <div class="tab-pane fade {{ $activeTab === 'create' ? 'show active' : '' }}">
                @php
                    $sizeCatalogList = $sizeCatalog ?? [];
                    $colorRows = old('colors');
                    if (! is_array($colorRows) || $colorRows === []) {
                        $colorRows = [['code' => '#ffffff', 'label' => '', 'quantity' => null]];
                    } else {
                        $colorRows = array_values($colorRows);
                    }
                    $sizeRows = old('sizes');
                    if (! is_array($sizeRows) || $sizeRows === []) {
                        $sizeRows = [['value' => '']];
                    } else {
                        $sizeRows = array_values($sizeRows);
                    }
                    $customRows = old('custom_options');
                    if (! is_array($customRows) || $customRows === []) {
                        $customRows = [''];
                    } else {
                        $customRows = array_values($customRows);
                    }
                @endphp
                <div class="card">
                    <div class="card-header">
                        <h5 class="mb-0">{{ __('merchant_products.form.title') }}</h5>
                    </div>
                    <div class="card-body">
                        <form method="post" action="{{ route('merchant.products.store', ['tab' => 'create']) }}" enctype="multipart/form-data">
                            @csrf
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('merchant_products.form.name') }}</label>
                                    <input type="text" name="name" class="form-control @error('name') is-invalid @enderror"
                                           value="{{ old('name') }}" maxlength="255">
                                    @error('name')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('merchant_products.form.category') }}</label>
                                    <select name="category_id" class="form-select @error('category_id') is-invalid @enderror">
                                        <option value="">{{ __('merchant_products.form.category_placeholder') }}</option>
                                        @foreach ($categories as $option)
                                            <option value="{{ $option['id'] }}" @selected((int) old('category_id') === $option['id'])>
                                                {{ $option['label'] }}
                                            </option>
                                        @endforeach
                                    </select>
                                    @error('category_id')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('merchant_products.form.price') }}</label>
                                    <input type="number" name="price" min="0" step="0.01"
                                           class="form-control @error('price') is-invalid @enderror"
                                           value="{{ old('price') }}">
                                    @error('price')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('merchant_products.form.currency') }}</label>
                                    <select name="currency" class="form-select @error('currency') is-invalid @enderror">
                                        @foreach ($currencyOptions as $code => $label)
                                            <option value="{{ $code }}" @selected(old('currency', $defaultCurrency) === $code)>{{ $label }}</option>
                                        @endforeach
                                    </select>
                                    <small class="text-muted">{{ __('merchant_products.form.currency_help') }}</small>
                                    @error('currency')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('merchant_products.form.stock') }}</label>
                                    <input type="number" name="stock" min="0"
                                           class="form-control @error('stock') is-invalid @enderror"
                                           value="{{ old('stock', 0) }}">
                                    @error('stock')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-12">
                                    <label class="form-label">{{ __('merchant_products.form.description') }}</label>
                                    <textarea name="description" rows="4"
                                              class="form-control @error('description') is-invalid @enderror">{{ old('description') }}</textarea>
                                    @error('description')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-12">
                                    <label class="form-label">{{ __('merchant_products.form.image') }}</label>
                                    <input type="file" name="primary_image"
                                           class="form-control @error('primary_image') is-invalid @enderror"
                                           accept="image/*">
                                    <small class="text-muted">{{ __('merchant_products.form.image_help') }}</small>
                                    @error('primary_image')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('merchant_products.form.video_link') }}</label>
                                    <input type="url" name="video_link"
                                           class="form-control @error('video_link') is-invalid @enderror"
                                           value="{{ old('video_link') }}">
                                    @error('video_link')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('merchant_products.form.delivery_size') }}</label>
                                    <input type="number" name="delivery_size" min="0" step="0.01"
                                           class="form-control @error('delivery_size') is-invalid @enderror"
                                           value="{{ old('delivery_size') }}">
                                    <small class="text-muted">{{ __('merchant_products.form.delivery_size_help') }}</small>
                                    @error('delivery_size')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                            </div>

                            <hr class="my-4">

                            <div class="row g-3">
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('merchant_products.form.discount_type') }}</label>
                                    <select name="discount_type" class="form-select @error('discount_type') is-invalid @enderror">
                                        <option value="none" @selected(old('discount_type', 'none') === 'none')>{{ __('merchant_products.form.discount_none') }}</option>
                                        <option value="percentage" @selected(old('discount_type') === 'percentage')>{{ __('merchant_products.form.discount_percentage') }}</option>
                                        <option value="fixed" @selected(old('discount_type') === 'fixed')>{{ __('merchant_products.form.discount_fixed') }}</option>
                                    </select>
                                    @error('discount_type')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('merchant_products.form.discount_value') }}</label>
                                    <input type="number" name="discount_value" min="0" step="0.01"
                                           class="form-control @error('discount_value') is-invalid @enderror"
                                           value="{{ old('discount_value') }}">
                                    @error('discount_value')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label">{{ __('merchant_products.form.discount_schedule') }}</label>
                                    <div class="input-group">
                                        <input type="datetime-local" name="discount_start"
                                               class="form-control @error('discount_start') is-invalid @enderror"
                                               value="{{ old('discount_start') }}">
                                        <input type="datetime-local" name="discount_end"
                                               class="form-control @error('discount_end') is-invalid @enderror"
                                               value="{{ old('discount_end') }}">
                                    </div>
                                    @error('discount_start')
                                        <div class="invalid-feedback d-block">{{ $message }}</div>
                                    @enderror
                                    @error('discount_end')
                                        <div class="invalid-feedback d-block">{{ $message }}</div>
                                    @enderror
                                </div>
                            </div>

                            <hr class="my-4">

                            <div class="mb-3">
                                <h6 class="mb-1">{{ __('merchant_products.form.attributes_title') }}</h6>
                                <p class="text-muted mb-0">{{ __('merchant_products.form.attributes_description') }}</p>
                            </div>

                            <div class="border rounded p-3 mb-4">
                                <div class="d-flex justify-content-between align-items-center mb-3">
                                    <h6 class="mb-0">{{ __('merchant_products.form.colors_title') }}</h6>
                                    <button type="button" class="btn btn-sm btn-outline-primary" data-add-color>
                                        <i class="bi bi-plus-lg"></i>
                                        {{ __('merchant_products.form.add_color') }}
                                    </button>
                                </div>
                                <div class="row text-muted mb-2">
                                    <div class="col-md-3">{{ __('merchant_products.form.color_picker') }}</div>
                                    <div class="col-md-4">{{ __('merchant_products.form.color_label') }}</div>
                                    <div class="col-md-3">{{ __('merchant_products.form.color_quantity') }}</div>
                                </div>
                                <div class="d-flex flex-column gap-3" data-color-rows>
                                    @foreach ($colorRows as $index => $color)
                                        <div class="row g-3 align-items-end" data-repeater-row>
                                            <div class="col-md-3">
                                                <input type="color"
                                                       name="colors[{{ $index }}][code]"
                                                       class="form-control form-control-color"
                                                       value="{{ old('colors.' . $index . '.code', $color['code'] ?? '#ffffff') }}">
                                                @error('colors.' . $index . '.code')
                                                    <div class="text-danger small">{{ $message }}</div>
                                                @enderror
                                            </div>
                                            <div class="col-md-4">
                                                <input type="text" name="colors[{{ $index }}][label]"
                                                       class="form-control"
                                                       placeholder="{{ __('merchant_products.form.color_label_placeholder') }}"
                                                       value="{{ old('colors.' . $index . '.label', $color['label'] ?? '') }}">
                                                @error('colors.' . $index . '.label')
                                                    <div class="text-danger small">{{ $message }}</div>
                                                @enderror
                                            </div>
                                            <div class="col-md-3">
                                                <input type="number" min="0" name="colors[{{ $index }}][quantity]"
                                                       class="form-control"
                                                       placeholder="0"
                                                       value="{{ old('colors.' . $index . '.quantity', $color['quantity'] ?? '') }}">
                                                @error('colors.' . $index . '.quantity')
                                                    <div class="text-danger small">{{ $message }}</div>
                                                @enderror
                                            </div>
                                            <div class="col-md-2 text-end">
                                                <button type="button" class="btn btn-outline-danger btn-sm" data-remove-row>
                                                    <i class="bi bi-x-lg"></i>
                                                </button>
                                            </div>
                                        </div>
                                    @endforeach
                                </div>
                            </div>

                            <div class="border rounded p-3 mb-4">
                                <div class="d-flex justify-content-between align-items-center mb-3">
                                    <h6 class="mb-0">{{ __('merchant_products.form.sizes_title') }}</h6>
                                    <button type="button" class="btn btn-sm btn-outline-primary" data-add-size>
                                        <i class="bi bi-plus-lg"></i>
                                        {{ __('merchant_products.form.add_size') }}
                                    </button>
                                </div>
                                <div class="d-flex flex-column gap-3" data-size-rows>
                                    @foreach ($sizeRows as $index => $size)
                                        <div class="row g-3 align-items-end" data-repeater-row>
                                            <div class="col-md-10">
                                                @php
                                                    $currentSizeValue = old('sizes.' . $index . '.value', $size['value'] ?? '');
                                                    $normalizedSizeCatalog = collect($sizeCatalogList)->map(fn ($entry) => (string) $entry)->all();
                                                    $isCustomSize = $currentSizeValue !== '' && ! in_array($currentSizeValue, $normalizedSizeCatalog, true);
                                                @endphp
                                                <select name="sizes[{{ $index }}][value]"
                                                        class="form-select @error('sizes.' . $index . '.value') is-invalid @enderror">
                                                    <option value="">{{ __('merchant_products.form.size_placeholder') }}</option>
                                                    @foreach ($sizeCatalogList as $option)
                                                        @php
                                                            $optionValue = (string) $option;
                                                        @endphp
                                                        <option value="{{ $optionValue }}" @selected($currentSizeValue === $optionValue)>{{ $optionValue }}</option>
                                                    @endforeach
                                                    @if ($isCustomSize)
                                                        <option value="{{ $currentSizeValue }}" selected>{{ $currentSizeValue }}</option>
                                                    @endif
                                                </select>
                                                @error('sizes.' . $index . '.value')
                                                    <div class="text-danger small">{{ $message }}</div>
                                                @enderror
                                            </div>
                                            <div class="col-md-2 text-end">
                                                <button type="button" class="btn btn-outline-danger btn-sm" data-remove-row>
                                                    <i class="bi bi-x-lg"></i>
                                                </button>
                                            </div>
                                        </div>
                                    @endforeach
                                </div>
                                <small class="text-muted">{{ __('merchant_products.form.size_catalog_hint') }}</small>
                            </div>

                            <div class="border rounded p-3 mb-4">
                                <div class="d-flex justify-content-between align-items-center mb-3">
                                    <h6 class="mb-0">{{ __('merchant_products.form.custom_title') }}</h6>
                                    <button type="button" class="btn btn-sm btn-outline-primary" data-add-option>
                                        <i class="bi bi-plus-lg"></i>
                                        {{ __('merchant_products.form.add_option') }}
                                    </button>
                                </div>
                                <div class="d-flex flex-column gap-3" data-option-rows>
                                    @foreach ($customRows as $index => $value)
                                        <div class="row g-3 align-items-end" data-repeater-row>
                                            <div class="col-md-10">
                                                <input type="text"
                                                       name="custom_options[{{ $index }}]"
                                                       class="form-control"
                                                       placeholder="{{ __('merchant_products.form.custom_placeholder') }}"
                                                       value="{{ old('custom_options.' . $index, $value) }}">
                                                @error('custom_options.' . $index)
                                                    <div class="text-danger small">{{ $message }}</div>
                                                @enderror
                                            </div>
                                            <div class="col-md-2 text-end">
                                                <button type="button" class="btn btn-outline-danger btn-sm" data-remove-row>
                                                    <i class="bi bi-x-lg"></i>
                                                </button>
                                            </div>
                                        </div>
                                    @endforeach
                                </div>
                            </div>

                            <div class="mt-4 d-flex justify-content-end">
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-check-circle me-1"></i>
                                    {{ __('merchant_products.form.submit') }}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>

            <div class="tab-pane fade {{ $activeTab === 'inventory' ? 'show active' : '' }}">
                <div class="row g-3">
                    <div class="col-12">
                        <h5 class="mb-3">{{ __('merchant_products.inventory.title') }}</h5>
                        <p class="text-muted">{{ __('merchant_products.inventory.subtitle') }}</p>
                    </div>
                    @forelse ($items as $inventoryItem)
                        @php
                            $baseStock = $inventoryItem->stocks->firstWhere('variant_key', null) ?? $inventoryItem->stocks->first();
                            $reservedStock = $baseStock->reserved_stock ?? 0;
                            $availableStock = $baseStock?->available ?? 0;
                        @endphp
                        <div class="col-md-6 col-xl-4">
                            <div class="card h-100">
                                <div class="card-body d-flex flex-column gap-3">
                                    <div>
                                        <div class="fw-semibold">{{ $inventoryItem->name }}</div>
                                        <small class="text-muted">#{{ $inventoryItem->id }}</small>
                                    </div>
                                    <div class="d-flex justify-content-between">
                                        <div>
                                            <p class="text-muted mb-1">{{ __('merchant_products.inventory.available') }}</p>
                                            <h5 class="mb-0">{{ number_format($availableStock) }}</h5>
                                        </div>
                                        <div class="text-end">
                                            <p class="text-muted mb-1">{{ __('merchant_products.inventory.reserved') }}</p>
                                            <h5 class="mb-0 text-warning">{{ number_format($reservedStock) }}</h5>
                                        </div>
                                    </div>
                                    <form method="post"
                                          action="{{ route('merchant.products.stock', ['item' => $inventoryItem->id, 'tab' => 'inventory']) }}">
                                        @csrf
                                        @method('patch')
                                        <label class="form-label">{{ __('merchant_products.inventory.update_button') }}</label>
                                        <div class="input-group">
                                            <input type="number" name="stock_value" min="0"
                                                   class="form-control @error('stock_value') is-invalid @enderror"
                                                   value="{{ $baseStock->stock ?? 0 }}">
                                            <button type="submit" class="btn btn-outline-primary">
                                                <i class="bi bi-save"></i>
                                                {{ __('merchant_products.inventory.update_button') }}
                                            </button>
                                            @error('stock_value')
                                                <div class="invalid-feedback d-block">{{ $message }}</div>
                                            @enderror
                                        </div>
                                    </form>
                                </div>
                            </div>
                        </div>
                    @empty
                        <div class="col-12">
                            <div class="alert alert-light mb-0">
                                {{ __('merchant_products.alerts.no_items') }}
                            </div>
                        </div>
                    @endforelse
                </div>
                <div class="p-3">
                    {{ $items->appends($inventoryQuery)->links() }}
                </div>
            </div>
        </div>

        <template id="colorRowTemplate">
            <div class="row g-3 align-items-end" data-repeater-row>
                <div class="col-md-3">
                    <input type="color" name="colors[__INDEX__][code]" class="form-control form-control-color" value="#ffffff">
                </div>
                <div class="col-md-4">
                    <input type="text" name="colors[__INDEX__][label]" class="form-control" placeholder="{{ __('merchant_products.form.color_label_placeholder') }}">
                </div>
                <div class="col-md-3">
                    <input type="number" name="colors[__INDEX__][quantity]" class="form-control" min="0" placeholder="0">
                </div>
                <div class="col-md-2 text-end">
                    <button type="button" class="btn btn-outline-danger btn-sm" data-remove-row>
                        <i class="bi bi-x-lg"></i>
                    </button>
                </div>
            </div>
        </template>

        <template id="sizeRowTemplate">
            <div class="row g-3 align-items-end" data-repeater-row>
                <div class="col-md-10">
                    <select name="sizes[__INDEX__][value]" class="form-select">
                        <option value="">{{ __('merchant_products.form.size_placeholder') }}</option>
                        @foreach ($sizeCatalogList as $option)
                            <option value="{{ $option }}">{{ $option }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-2 text-end">
                    <button type="button" class="btn btn-outline-danger btn-sm" data-remove-row>
                        <i class="bi bi-x-lg"></i>
                    </button>
                </div>
            </div>
        </template>

        <template id="optionRowTemplate">
            <div class="row g-3 align-items-end" data-repeater-row>
                <div class="col-md-10">
                    <input type="text" name="custom_options[__INDEX__]" class="form-control" placeholder="{{ __('merchant_products.form.custom_placeholder') }}">
                </div>
                <div class="col-md-2 text-end">
                    <button type="button" class="btn btn-outline-danger btn-sm" data-remove-row>
                        <i class="bi bi-x-lg"></i>
                    </button>
                </div>
            </div>
        </template>

    </section>
@endsection

@push('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const setupRepeater = (containerSelector, templateId, addSelector) => {
                const container = document.querySelector(containerSelector);
                const template = document.getElementById(templateId);
                const addButton = document.querySelector(addSelector);

                if (!container || !template || !addButton) {
                    return;
                }

                let index = container.querySelectorAll('[data-repeater-row]').length;

                const addRow = () => {
                    const html = template.innerHTML.replace(/__INDEX__/g, index++);
                    const fragment = document.createElement('div');
                fragment.innerHTML = html.trim();
                    const row = fragment.firstElementChild;
                    container.appendChild(row);
                };

                addButton.addEventListener('click', (event) => {
                    event.preventDefault();
                    addRow();
                });

                container.addEventListener('click', (event) => {
                    if (event.target.closest('[data-remove-row]')) {
                        event.preventDefault();
                        const row = event.target.closest('[data-repeater-row]');
                        if (row && container.querySelectorAll('[data-repeater-row]').length > 1) {
                            row.remove();
                        }
                    }
                });
            };

            setupRepeater('[data-color-rows]', 'colorRowTemplate', '[data-add-color]');
            setupRepeater('[data-size-rows]', 'sizeRowTemplate', '[data-add-size]');
            setupRepeater('[data-option-rows]', 'optionRowTemplate', '[data-add-option]');
        });
    </script>
@endpush
