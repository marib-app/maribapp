@extends('layouts.main')

@section('title', __('merchant_coupons.edit_title'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('merchant_coupons.page_lead') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end align-items-start gap-2 flex-wrap">
                <a href="{{ route('merchant.coupons.index') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i>
                    {{ __('merchant_coupons.cancel_button') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-body">
                <form action="{{ route('merchant.coupons.update', $coupon) }}" method="POST">
                    @csrf
                    @method('put')
                    @include('store.coupons._form', ['coupon' => $coupon])

                    <div class="mt-4 d-flex gap-2">
                        <button type="submit" class="btn btn-primary">{{ __('merchant_coupons.update_button') }}</button>
                        <a href="{{ route('merchant.coupons.index') }}" class="btn btn-link">{{ __('merchant_coupons.cancel_button') }}</a>
                    </div>
                </form>
            </div>
        </div>
    </section>
@endsection
