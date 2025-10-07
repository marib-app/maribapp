@extends('layouts.main')

@section('title')
    {{ __('إدارة شي ان') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first"></div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">


            @php
            $flashError = session('errors');
            if ($flashError instanceof \Illuminate\Support\ViewErrorBag) {
                $flashError = null;
            }
        @endphp

        @if ($errors->any())
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                <ul class="mb-0">
                    @foreach ($errors->all() as $validationError)
                        <li>{{ $validationError }}</li>
                    @endforeach
                </ul>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('Close') }}"></button>
            </div>
        @endif

        @if ($flashError)
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                {{ is_array($flashError) ? implode(' ', \Illuminate\Support\Arr::wrap($flashError)) : $flashError }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('Close') }}"></button>
            </div>
        @endif

        @if (session('success'))
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                {{ session('success') }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('Close') }}"></button>
            </div>
        @endif



        <div class="row">




            @can('shein-products-update')
                <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
                    <a href="{{ route('item.shein.settings') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
                        <div class="content d-flex h-100">
                            <div class="row mx-2">
                                <div class="provider_a test">
                                    <i class="fas fa-sliders-h text-dark icon_font_size"></i>
                                </div>
                            </div>
                        </div>
                        <div class="card-body">
                            <h5 class="title">{{ __('إعدادات القسم') }}</h5>
                            <div>{{ __('تعديل المعلن، إعدادات الوديعة، أرقام الواتساب وسياسة الاسترجاع لقسم شي إن') }} <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
                        </div>
                    </a>
                </div>
            @endcan


            @can('delivery-prices-list')
                <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
                    <a href="{{ route('delivery-prices.index', ['department' => \App\Services\DepartmentReportService::DEPARTMENT_SHEIN]) }}" class="card setting_active_tab h-100" style="text-decoration:none;">
                        <div class="content d-flex h-100">
                            <div class="row mx-2">
                                <div class="provider_a test">
                                    <i class="fas fa-shipping-fast text-dark icon_font_size"></i>
                                </div>
                            </div>
                        </div>
                        <div class="card-body">
                            <h5 class="title">{{ __('خدمات التوصيل') }}</h5>
                            <div>{{ __('إدارة خدمات التوصيل لقسم شي إن مع اختيار السياسة المناسبة') }} <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
                        </div>
                    </a>
                </div>
            @endcan



    @can('shein-products-create')
            @if(Route::has('item.shein.products.create'))
                <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
                    <a href="{{ route('item.shein.products.create', ['category_id' => 4]) }}" class="card setting_active_tab h-100" style="text-decoration:none;">
                        <div class="content d-flex h-100">
                            <div class="row mx-2">
                                <div class="provider_a test">
                                    <i class="fas fa-bullhorn text-dark icon_font_size"></i>
                                </div>
                            </div>
                        </div>
                        <div class="card-body">
                            <h5 class="title">{{ __('نشر إعلان جديد') }}</h5>
                            <div>{{ __('إطلاق منتج ضمن فئة شي إن') }} <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
                        </div>
                    </a>
                </div>
            @endif
        @endcan

        @canany(['shein-products-list','shein-products-create','shein-products-update','shein-products-delete'])
            @if(Route::has('item.shein.products'))
                <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
                    <a href="{{ route('item.shein.products') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
                        <div class="content d-flex h-100">
                            <div class="row mx-2">
                                <div class="provider_a test">
                                    <i class="fas fa-boxes text-dark icon_font_size"></i>
                                </div>
                            </div>
                        </div>
                        <div class="card-body">
                            <h5 class="title">{{ __('إدارة المنتجات') }}</h5>
                            <div>{{ __('متابعة جميع منتجات شي إن') }} <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
                        </div>
                    </a>
                </div>
            @endif
        @endcanany

        @canany(['shein-orders-list','shein-orders-create','shein-orders-update','shein-orders-delete'])
            @if(Route::has('item.shein.orders'))
                <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
                    <a href="{{ route('item.shein.orders') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
                        <div class="content d-flex h-100">
                            <div class="row mx-2">
                                <div class="provider_a test">
                                    <i class="fas fa-shopping-cart text-dark icon_font_size"></i>
                                </div>
                            </div>
                        </div>
                        <div class="card-body">
                            <h5 class="title">{{ __('إدارة الطلبات') }}</h5>
                            <div>{{ __('مراجعة وتتبع طلبات العملاء') }} <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
                        </div>
                    </a>
                </div>
            @endif
        @endcanany

        @canany(['shein-requests-list','shein-requests-create','shein-requests-update','shein-requests-delete'])
            @if(Route::has('item.shein.custom-orders.index'))
                    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
                        <a href="{{ route('item.shein.custom-orders.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
                        <div class="content d-flex h-100">
                            <div class="row mx-2">
                                <div class="provider_a test">
                                    <i class="fas fa-clipboard-list text-dark icon_font_size"></i>
                                </div>
                            </div>
                        </div>
                        <div class="card-body">
                            <h5 class="title">{{ __('الطلبات الخاصة') }}</h5>
                            <div>{{ __('متابعة الطلبات المخصصة والطلبات الخاصة') }} <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
                        </div>
                    </a>
                </div>
            @endif
        @endcanany

        @canany(['shein-products-list','shein-products-create','shein-products-update','shein-products-delete'])
            @if(Route::has('item.shein.delegates'))
                <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
                    <a href="{{ route('item.shein.delegates') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
                        <div class="content d-flex h-100">
                            <div class="row mx-2">
                                <div class="provider_a test">
                                    <i class="fas fa-user-friends text-dark icon_font_size"></i>
                                </div>
                            </div>
                        </div>
                        <div class="card-body">
                            <h5 class="title">{{ __('المندوبون') }}</h5>
                            <div>{{ __('تنظيم فرق العمل والمندوبين') }} <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
                        </div>
                    </a>
                </div>
            @endif
        @endcanany

        @canany(['reports-orders','reports-sales','reports-customers','reports-statuses'])
            @if(Route::has('item.shein.reports'))
                <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
                    <a href="{{ route('item.shein.reports') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
                        <div class="content d-flex h-100">
                            <div class="row mx-2">
                                <div class="provider_a test">
                                    <i class="fas fa-chart-line text-dark icon_font_size"></i>
                                </div>
                            </div>
                        </div>
                        <div class="card-body">
                            <h5 class="title">{{ __('التقارير') }}</h5>
                            <div>{{ __('عرض مؤشرات الأداء والإحصائيات') }} <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
                        </div>
                    </a>
                </div>
            @endif
        @endcanany

        @can('chat-monitor-list')
            @if(Route::has('item.shein.support'))
                <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
                    <a href="{{ route('item.shein.support') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
                        <div class="content d-flex h-100">
                            <div class="row mx-2">
                                <div class="provider_a test">
                                    <i class="fas fa-headset text-dark icon_font_size"></i>
                                </div>
                            </div>
                        </div>
                        <div class="card-body">
                            <h5 class="title">{{ __('الدعم والمحادثات') }}</h5>
                            <div>{{ __('متابعة محادثات العملاء وفريق الدعم') }} <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
                        </div>
                    </a>
                </div>
            @endif
        @endcan
    </div>
    </section>
@endsection