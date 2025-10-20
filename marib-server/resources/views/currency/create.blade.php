@extends('layouts.main')

@section('title')
    {{ __('Add Currency Rate') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-md-end">
                <a href="{{ route('currency.index') }}" class="btn btn-outline-secondary">
                    {{ __('Back to list') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">{{ __('Create a new currency') }}</h5>
                    </div>
                    <div class="card-body">
                        {!! Form::open(['route' => 'currency.store', 'data-parsley-validate', 'class' => 'create-form', 'files' => true]) !!}
                        <div class="row">
                            <div class="col-md-6 col-12 form-group mandatory">
                                {{ Form::label('currency_name', __('Currency Name'), ['class' => 'form-label']) }}
                                {{ Form::text('currency_name', old('currency_name'), [
                                    'class' => 'form-control',
                                    'placeholder' => __('Enter Currency Name'),
                                    'data-parsley-required' => 'true',
                                ]) }}
                            </div>

                            <div class="col-md-6 col-12 form-group">
                                {{ Form::label('icon', __('Icon (optional)'), ['class' => 'form-label']) }}
                                <input type="file" name="icon" id="create_icon" class="form-control icon-input"
                                       accept="image/png,image/jpeg,image/jpg,image/webp,image/svg+xml">
                                <small class="text-muted">{{ __('Max 2MB. Allowed types: JPG, PNG, SVG, WEBP.') }}</small>

                                <div class="currency-icon-preview mt-2 d-none" data-preview="create">
                                    <img src="" alt="" class="img-thumbnail preview-image" style="max-height: 120px;">
                                    <div class="mt-2">
                                        <button type="button" class="btn btn-outline-danger btn-sm clear-icon"
                                                data-target="create">{{ __('Remove icon') }}</button>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12 form-group">
                                {{ Form::label('icon_alt', __('Icon alternative text'), ['class' => 'form-label']) }}
                                {{ Form::text('icon_alt', old('icon_alt'), [
                                    'class' => 'form-control icon-alt-input',
                                    'placeholder' => __('Describe the icon for accessibility (optional)')
                                ]) }}
                            </div>

                            <div class="col-12">
                                <div class="d-flex align-items-center justify-content-between flex-wrap gap-2">
                                    <label class="form-label mb-1 mb-md-0">{{ __('Governorate price sets') }}</label>
                                    <div class="d-flex align-items-center gap-2">
                                        <span class="badge bg-light text-dark">{{ __('Inline editable') }}</span>
                                        @can('governorate-create')
                                            <button type="button"
                                                    class="btn btn-sm btn-outline-primary"
                                                    data-bs-toggle="modal"
                                                    data-bs-target="#governorateQuickCreateModal">
                                                {{ __('Add governorate') }}
                                            </button>
                                        @endcan
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <p class="text-muted small mb-2">
                                    {{ __('Enter sell/buy values for each governorate. Leave a row blank to skip it and choose one default fallback set.') }}
                                </p>
                                @include('currency.partials.quote-table', [
                                    'governorates' => $governorates,
                                    'context' => 'create',
                                    'quotes' => [],
                                    'defaultGovernorateId' => old('default_governorate_id')
                                ])
                            </div>

                            <div class="col-12 text-end form-group">
                                {{ Form::submit(__('Add Currency'), ['class' => 'btn btn-primary']) }}
                            </div>
                        </div>
                        {!! Form::close() !!}
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection

@can('governorate-create')
    @isset($governorateStoreUrl)
        @include('governorates.partials.quick-create-modal', ['storeUrl' => $governorateStoreUrl])
    @endisset
@endcan


@push('scripts')
    <script src="{{ asset('js/currency.js') }}"></script>
@endpush
