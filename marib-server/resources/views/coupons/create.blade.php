@extends('layouts.main')

@section('title')
    {{ __('إضافة قسيمة جديدة') }}
@endsection

@section('content')
    <div class="content-wrapper">
        <div class="page-header">
            <h3 class="page-title">{{ __('إضافة قسيمة جديدة') }}</h3>
            <div class="buttons">
                <a href="{{ route('coupons.index') }}" class="btn btn-outline-secondary">{{ __('عودة للقائمة') }}</a>
            </div>
        </div>

        <div class="row grid-margin">
            <div class="col-lg-12">
                <div class="card">
                    <div class="card-body">
                        <form action="{{ route('coupons.store') }}" method="POST" class="row g-3">
                            @csrf
                            @include('coupons._form')

                            <div class="col-12 d-flex justify-content-end">
                                <button type="submit" class="btn btn-primary">{{ __('حفظ القسيمة') }}</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </div>
@endsection