@extends('layouts.main')

@section('title')
    {{ __('Edit Currency Rate') }}
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
                        <h5 class="card-title mb-0">{{ __('Update currency details') }}</h5>
                    </div>
                    <div class="card-body">
                        {!! Form::model($currency, [
                            'route' => ['currency.update', $currency->id],
                            'method' => 'PUT',
                            'data-parsley-validate',
                            'class' => 'edit-form',
                            'files' => true,
                            'data-original-icon-url' => $currency->icon_url ?? '',
                            'data-original-icon-alt' => $currency->icon_alt ?? '',
                        ]) !!}
                        {{ Form::hidden('remove_icon', '0', ['id' => 'edit_remove_icon']) }}
                        <div class="row">
                            <div class="col-md-6 col-12 form-group mandatory">
                                {{ Form::label('currency_name', __('Currency Name'), ['class' => 'form-label', 'for' => 'edit_currency_name']) }}
                                {{ Form::text('currency_name', null, [
                                    'class' => 'form-control',
                                    'id' => 'edit_currency_name',
                                    'placeholder' => __('Enter Currency Name'),
                                    'data-parsley-required' => 'true',
                                ]) }}
                            </div>

                            <div class="col-md-6 col-12 form-group">
                                {{ Form::label('icon', __('Icon (optional)'), ['class' => 'form-label', 'for' => 'edit_icon']) }}
                                <input type="file" name="icon" id="edit_icon" class="form-control icon-input"
                                       accept="image/png,image/jpeg,image/jpg,image/webp,image/svg+xml">
                                <small class="text-muted">{{ __('Max 2MB. Allowed types: JPG, PNG, SVG, WEBP.') }}</small>

                                <div class="currency-icon-preview mt-2 {{ $currency->icon_url ? '' : 'd-none' }}" data-preview="edit">
                                    <img src="{{ $currency->icon_url }}" alt="{{ $currency->icon_alt }}" class="img-thumbnail preview-image" style="max-height: 120px;">
                                    <div class="mt-2 d-flex gap-2">
                                        <button type="button" class="btn btn-outline-danger btn-sm clear-icon" data-target="edit">{{ __('Remove icon') }}</button>
                                        <span class="text-muted current-icon-alt">{{ $currency->icon_alt }}</span>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12 form-group">
                                {{ Form::label('icon_alt', __('Icon alternative text'), ['class' => 'form-label', 'for' => 'edit_icon_alt']) }}
                                {{ Form::text('icon_alt', null, [
                                    'class' => 'form-control icon-alt-input',
                                    'id' => 'edit_icon_alt',
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
                                    {{ __('Update sell/buy values for each governorate. Leave a row blank to skip it and choose one default fallback set.') }}
                                </p>
                                @include('currency.partials.quote-table', [
                                    'governorates' => $governorates,
                                    'context' => 'edit',
                                    'quotes' => $quotes,
                                    'defaultGovernorateId' => $defaultGovernorateId,
                                ])
                            </div>

                            <div class="col-12 text-end form-group">
                                {{ Form::submit(__('Save Changes'), ['class' => 'btn btn-primary']) }}
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