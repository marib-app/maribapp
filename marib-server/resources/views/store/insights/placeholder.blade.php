@extends('layouts.main')

@section('title', __($page['title_key']))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">{{ __($page['subtitle_key']) }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end flex-wrap gap-2">
                <a href="{{ route('merchant.dashboard') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i> {{ __('merchant_insights.back_to_dashboard') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row justify-content-center">
            <div class="col-md-10 col-lg-8">
                <div class="card border-0 shadow-sm">
                    <div class="card-body text-center py-5 px-4">
                        <div class="display-4 mb-3 text-primary">
                            <i class="bi {{ $page['icon'] }}"></i>
                        </div>
                        <h4 class="mb-3">{{ __($page['title_key']) }}</h4>
                        <p class="text-muted mb-4">{{ __($page['description_key']) }}</p>
                        <div class="p-4 rounded-3 bg-light text-muted fw-semibold">
                            {{ __('merchant_insights.placeholder_hint') }}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
