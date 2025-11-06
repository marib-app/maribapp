@extends('layouts.main')

@section('title')
    {{ __('Edit Store Gateway') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-md-end align-items-center gap-2">
                <a href="{{ route('seller-store-settings.gateways.index') }}" class="btn btn-outline-secondary">
                    {{ __('Back to Gateways') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-header">
                <h5 class="card-title mb-0">{{ __('Gateway Details') }}</h5>
            </div>
            <div class="card-body">
                <form
                    action="{{ route('seller-store-settings.gateways.update', $storeGateway) }}"
                    method="post"
                    enctype="multipart/form-data"
                >
                    @csrf
                    @method('put')

                    @include('seller-store-settings.gateways._form', [
                        'submitLabel' => __('Update Gateway'),
                    ])
                </form>
            </div>
        </div>
    </section>
@endsection