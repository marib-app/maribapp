@extends('layouts.main')

@section('title')
    {{ __('Add metal rate') }}
@endsection



@can('governorate-create')
    @isset($governorateStoreUrl)
        @include('governorates.partials.quick-create-modal', ['storeUrl' => $governorateStoreUrl])
    @endisset
@endcan

@push('scripts')
    @include('metal_rates.partials.icon_preview_scripts')
    @include('metal_rates.partials.quote_table_scripts')


@endpush

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-start text-md-end">
                <a href="{{ route('metal-rates.index') }}" class="btn btn-outline-secondary">{{ __('Back to metal rates') }}</a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-12">
                @if ($errors->any())
                    <div class="alert alert-danger">
                        <ul class="mb-0">
                            @foreach ($errors->all() as $error)
                                <li>{{ $error }}</li>
                            @endforeach
                        </ul>
                    </div>
                @endif
            </div>
        </div>

        @can('metal-rate-create')
            <div class="row">
                <div class="col-12">
                    <div class="card">
                        <div class="card-header">
                            <h5 class="card-title mb-0">{{ __('Add metal rate') }}</h5>
                        </div>
                        <div class="card-body">
                            <form action="{{ route('metal-rates.store') }}" method="POST" class="needs-validation" novalidate enctype="multipart/form-data">
                                @csrf
                                <div class="mb-3">
                                    <label for="metal_type" class="form-label">{{ __('Metal type') }}</label>
                                    <select name="metal_type" id="metal_type" class="form-select" required>
                                        <option value="" disabled @selected(! old('metal_type'))>{{ __('Select type') }}</option>
                                        <option value="gold" @selected(old('metal_type') === 'gold')>{{ __('Gold') }}</option>
                                        <option value="silver" @selected(old('metal_type') === 'silver')>{{ __('Silver') }}</option>
                                    </select>
                                </div>

                                <div class="mb-3">
                                    <label for="karat" class="form-label">{{ __('Karat (for gold only)') }}</label>
                                    <input type="number" step="0.01" min="0" max="999" class="form-control" id="karat" name="karat" value="{{ old('karat') }}" placeholder="24">
                                    <div class="form-text">{{ __('Leave empty for silver.') }}</div>
                                </div>

                                <div class="mb-4">
                                    <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-2">
                                        <label class="form-label mb-0">{{ __('Governorate quotes') }}</label>
                                        <div class="d-flex align-items-center gap-2">
                                            <span class="badge bg-light text-dark">{{ __('Inline editable') }}</span>
                                            @can('governorate-create')
                                                <button type="button" class="btn btn-sm btn-outline-primary"
                                                        data-bs-toggle="modal"
                                                        data-bs-target="#governorateQuickCreateModal">
                                                    {{ __('Add governorate') }}
                                                </button>
                                            @endcan
                                        </div>
                                    </div>
                                    
                                    @include('metal_rates.partials.quote-table', [
                                        'governorates' => $governorates,
                                        'quotes' => [],
                                        'context' => 'create',
                                        'defaultGovernorateId' => $defaultGovernorateId,
                                    ])
                                </div>

                                <div class="mb-3">
                                    <label for="create_icon" class="form-label">{{ __('Icon (optional)') }}</label>
                                    <input type="file" class="form-control" id="create_icon" name="icon" accept="image/png,image/jpeg,image/jpg,image/webp,image/svg+xml" data-metal-icon-input data-metal-icon-preview="create_icon_preview">
                                    <div class="form-text">{{ __('Allowed types: JPG, PNG, WEBP, SVG. Max size: 2MB.') }}</div>
                                    <div class="mt-2 d-none" id="create_icon_preview_wrapper" data-metal-icon-preview-container>
                                        <img src="#" alt="" id="create_icon_preview" class="img-thumbnail" style="max-height: 120px;" data-original-src="" data-original-alt="">
                                    </div>
                                </div>

                                <div class="mb-3">
                                    <label for="create_icon_alt" class="form-label">{{ __('Icon alternative text') }}</label>
                                    <input type="text" class="form-control" id="create_icon_alt" name="icon_alt" value="{{ old('icon_alt') }}" maxlength="255" placeholder="{{ __('Describe the icon for screen readers') }}">
                                    <div class="form-text">{{ __('Optional, helps with accessibility when an icon is provided.') }}</div>
                                </div>

                                <div class="d-grid">
                                    <button type="submit" class="btn btn-primary">{{ __('Save metal rate') }}</button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        @else
            <div class="row">
                <div class="col-12">
                    <div class="alert alert-warning">{{ __('You do not have permission to create metal rates.') }}</div>
                </div>
            </div>
        @endcan
    </section>
@endsection