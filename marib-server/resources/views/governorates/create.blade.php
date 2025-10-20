@extends('layouts.main')

@section('title')
    {{ __('Add governorate') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-12 col-md-6">
                <h4 class="mb-0">@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 text-md-end mt-3 mt-md-0">
                <a href="{{ route('governorates.index') }}" class="btn btn-outline-secondary">
                    {{ __('Back to governorates') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-12 col-lg-6">
                <div class="card mb-4">
                    <div class="card-header">
                        <h5 class="card-title mb-0">{{ __('Create a new governorate') }}</h5>
                    </div>
                    <div class="card-body">
                        {!! Form::open(['route' => 'governorates.store', 'method' => 'post']) !!}
                        <div class="mb-3">
                            {{ Form::label('name', __('Name'), ['class' => 'form-label']) }}
                            {{ Form::text('name', old('name'), ['class' => 'form-control', 'required' => true, 'maxlength' => 255]) }}
                        </div>
                        <div class="mb-3">
                            {{ Form::label('code', __('Code'), ['class' => 'form-label']) }}
                            {{ Form::text('code', old('code'), [
                                'class' => 'form-control text-uppercase',
                                'required' => true,
                                'maxlength' => 20,
                                'placeholder' => __('e.g. NATL'),
                            ]) }}
                            <div class="form-text">{{ __('Codes are stored in uppercase automatically.') }}</div>
                        </div>
                        <div class="form-check form-switch mb-4">
                            {{ Form::checkbox('is_active', 1, old('is_active', true), ['class' => 'form-check-input', 'id' => 'is_active']) }}
                            {{ Form::label('is_active', __('Active'), ['class' => 'form-check-label']) }}
                        </div>
                        <div class="d-grid">
                            <button type="submit" class="btn btn-primary">{{ __('Save governorate') }}</button>
                        </div>
                        {!! Form::close() !!}
                    </div>
                </div>
            </div>

            <div class="col-12 col-lg-6">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">{{ __('Existing governorates') }}</h5>
                    </div>
                    <div class="card-body">
                        @include('governorates.partials.table', ['governorates' => $governorates, 'showActions' => false])
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection