@extends('layouts.main')

@section('title')
    {{ __('إدارة شبكات الواي فاي') }}
@endsection

@section('css')
    @vite(['resources/js/wifi/index.scss'])
@endsection

@section('js')
    @vite(['resources/js/wifi/index.js'])
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            if (window.axios) {
                window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';
                window.axios.defaults.withCredentials = true;
                window.axios.get('{{ url('/sanctum/csrf-cookie') }}').catch(() => {});
            }
        }, { once: true });
    </script>
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center g-2">
            <div class="col-12 col-md-6 order-md-1 order-last text-center text-md-start">
                <h4 class="mb-0">@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-center text-md-end">
                <nav aria-label="breadcrumb" class="breadcrumb-header">
                    <ol class="breadcrumb mb-0 justify-content-center justify-content-md-end">
                        <li class="breadcrumb-item"><a href="{{ route('home') }}">{{ __('لوحة التحكم') }}</a></li>
                        <li class="breadcrumb-item active" aria-current="page">{{ __('إدارة الواي فاي') }}</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section wifi-admin" data-wifi-admin-root data-base-url="{{ $adminApiBaseUrl }}" data-owner-base-url="{{ $ownerApiBaseUrl ?? url('/wifi-cabin/api/owner') }}" data-detail-url="{{ route('wifi.show', ['network' => '__NETWORK__']) }}">
        <div class="row g-3 mb-3">
            <div class="col-12">
                @if (session('status'))
                    <div class="alert alert-success shadow-sm border-0" role="alert">
                        {{ session('status') }}
                    </div>
                @endif
            </div>
        </div>

        @include('wifi.partials.stat-grid', ['stats' => $stats])

        @include('wifi.partials.alerts', ['alerts' => $alertsConfig ?? []])

        <div class="card shadow-sm border-0">
            <div class="card-header bg-white border-0 pb-0">
                @include('wifi.partials.tabs.nav')
            </div>
            <div class="card-body">
                <div class="tab-content" id="wifiAdminTabsContent">
                    @include('wifi.partials.tabs.networks')
                    @include('wifi.partials.tabs.requests', ['pendingRequests' => $pendingRequests])
                    @include('wifi.partials.tabs.reports')
                    @include('wifi.partials.tabs.batches')
                </div>
            </div>
        </div>

        @include('wifi.partials.network-modals')
    </section>
@endsection
