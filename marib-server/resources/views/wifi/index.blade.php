@extends('layouts.main')

@section('title')
    {{ __('إدارة كبائن الواي فاي') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-body">
                        <p class="mb-0 text-muted">
                            {{ __('لم يتم تفعيل لوحة إدارة كبائن الواي فاي بعد. الرجاء التواصل مع فريق التطوير لاستكمال الربط.') }}
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection