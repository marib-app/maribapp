@extends('layouts.main')

@section('title')
    {{ __('Items') }}
@endsection

@section('css')
    @vite(['resources/js/items/index.scss'])
@endsection

@section('js')
    @vite(['resources/js/items/index.js'])
@endsection




@section('page-title')
    <div class="page-title page-title--items-index">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first"></div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section" data-page="items-index">
        <div class="row">
            <div class="col-md-12">
                <div class="card">
                    <div class="card-body">
                        <div id="filters" class="mb-3">
                            @include('items.partials.filter-panel', ['categories' => $categories])
                        </div>

                        @include('items.partials.results-pane', ['categories' => $categories])
                    </div>
                </div>
            </div>
        </div>

        @include('items.partials.status-modal')
    </section>
@endsection
