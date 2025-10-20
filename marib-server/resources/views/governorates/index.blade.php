@extends('layouts.main')

@section('title')
    {{ __('Governorates') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-12 col-md-6">
                <h4 class="mb-0">@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 text-md-end mt-3 mt-md-0">
                @can('governorate-create')
                    <a href="{{ route('governorates.create') }}" class="btn btn-primary">
                        {{ __('Add governorate') }}
                    </a>
                @endcan
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-12">
                @if (session('success'))
                    <div class="alert alert-success">{{ session('success') }}</div>
                @endif

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

        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">{{ __('Governorate directory') }}</h5>
                    </div>
                    <div class="card-body">
                        @include('governorates.partials.table', ['governorates' => $governorates, 'showActions' => true])

                        <div class="mt-3">
                            {{ $governorates->links() }}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection