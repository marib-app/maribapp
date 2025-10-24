@extends('layouts.main')

@section('title')
    {{ __('System Settings') }}
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
        <form class="create-form-without-reset" action="{{route('settings.store') }}" method="post" enctype="multipart/form-data" data-success-function="successFunction" data-parsley-validate>
            @csrf
            <div class="row d-flex mb-3">
                <div class="col-md-4">
                    <div class="card h-100">
                        <div class="card-body">
                            <div class="divider pt-3">
                                <h6 class="divider-text">{{ __('Company Details') }}</h6>
                            </div>
                            <div class="row">
                                <div class="col-sm-12 form-group mandatory">
                                    <label for="company_name" class="col-sm-6 col-md-6 form-label mt-1">{{ __('Company Name') }}</label>
                                    <input name="company_name" type="text" class="form-control" id="company_name" placeholder="{{ __('Company Name') }}" value="{{ $settings['company_name'] ?? '' }}" required>
                                </div>
                                <div class="col-sm-12 form-group mandatory">
                                    <label for="company_email" class="col-sm-12 col-md-6 form-label mt-1">{{ __('Email') }}</label>
                                    <input id="company_email" name="company_email" type="email" class="form-control" placeholder="{{ __('Email') }}" value="{{ $settings['company_email'] ?? '' }}" required>
                                </div>

                                <div class="col-sm-12 form-group mandatory">
                                    <label for="company_tel1" class="col-sm-12 col-md-6 form-label mt-1">{{ __('Contact Number')." 1" }}</label>
                                    <input id="company_tel1" name="company_tel1" type="text" class="form-control" placeholder="{{ __('Contact Number')." 1" }}" maxlength="16" onKeyDown="if(this.value.length==16 && event.keyCode!=8) return false;" value="{{ $settings['company_tel1'] ?? '' }}" required>
                                </div>

                                <div class="col-sm-12">
                                    <label for="company_tel2" class="col-sm-12 col-md-6 form-label mt-1">{{ __('Contact Number')." 2" }}</label>
                                    <input id="company_tel2" name="company_tel2" type="text" class="form-control" placeholder="{{ __('Contact Number')." 2" }}" maxlength="16" onKeyDown="if(this.value.length==16 && event.keyCode!=8) return false;" value="{{ $settings['company_tel2'] ?? '' }}">
                                </div>

                                <div class="col-sm-12">
                                    <label for="company_address" class="col-sm-12 col-md-6 form-label mt-1">{{ __('Address') }}</label>
                                    <textarea id="company_address" name="company_address" type="text" class="form-control" placeholder="{{ __('Address') }}">{{ $settings['company_address'] ?? '' }}</textarea>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-8">
                    <div class="card">
                        <div class="card-body">
                            <div class="divider pt-3">
                                <h6 class="divider-text">{{ __('More Setting') }}</h6>
                            </div>

                            <div class="row">
                                <div class="form-group col-sm-12 col-md-6 col-xs-12 mandatory">
                                    <label for="default_language" class="form-label ">{{ __('Default Language') }}</label>
                                    <select name="default_language" id="default_language" class="form-select form-control-sm">
                                        @foreach ($languages as $row)
                                            {{ $row }}
                                            <option value="{{ $row->code }}"
                                                {{ $settings['default_language'] == $row->code ? 'selected' : '' }}>
                                                {{ $row->name }}
                                            </option>
                                        @endforeach
                                    </select>
                                </div>
                                <div class="form-group col-sm-12 col-md-6 col-xs-12 mandatory">
                                    <label for="currency_symbol" class="form-label">{{ __('Currency Symbol') }}</label>
                                    <input id="currency_symbol" name="currency_symbol" type="text" class="form-control" placeholder="{{ __('Currency Symbol (e.g. ر.ي / ر.س / أ.ر)') }}" value="{{ \App\Support\Currency::preferredSymbol($settings['currency_symbol'] ?? null, $settings['currency_code'] ?? ($settings['currency'] ?? ($settings['default_currency'] ?? config('app.currency')))) }}" required="">
                                </div>

                                <div class="form-group col-sm-12 col-md-6">
                                    <label for="android_version" class="form-label ">{{ __('Android Version') }}</label>
                                    <input id="android_version" name="android_version" type="text" class="form-control" placeholder="{{ __('Android Version') }}" value="{{ $settings['android_version']?? '' }}" required="">
                                </div>
                                <div class="form-group col-sm-12 col-md-6">
                                    <label for="play_store_link" class="form-label ">{{ __('Play Store Link') }}</label>
                                    <input id="play_store_link" name="play_store_link" type="url" class="form-control" placeholder="{{ __('Play Store Link') }}" value="{{ $settings['play_store_link'] ?? '' }}">
                                </div>


                                <div class="form-group col-sm-12 col-md-6">
                                    <label for="ios_version" class="form-label ">{{ __('IOS Version') }}</label>
                                    <input id="ios_version" name="ios_version" type="text" class="form-control" placeholder="{{ __('IOS Version') }}" value="{{ $settings['ios_version'] ?? '' }}" required="">
                                </div>

                                <div class="form-group col-sm-12 col-md-6">
                                    <label for="app_store_link" class="form-label ">{{ __('App Store Link') }}</label>
                                    <input id="app_store_link" name="app_store_link" type="url" class="form-control" placeholder="{{ __('App Store Link') }}" value="{{ $settings['app_store_link'] ?? '' }}">
                                </div>


                                <div class="form-group col-sm-12 col-md-4">
                                    <label class="form-label ">{{ __('Maintenance Mode') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="hidden" name="maintenance_mode" id="maintenance_mode" class="checkbox-toggle-switch-input" value="{{ $settings['maintenance_mode'] ?? 0 }}">
                                        <input class="form-check-input checkbox-toggle-switch" type="checkbox" role="switch" {{ $settings['maintenance_mode'] == '1' ? 'checked' : '' }} id="switch_maintenance_mode">
                                        <label class="form-check-label" for="switch_maintenance_mode"></label>
                                    </div>
                                </div>

                                <div class="form-group col-sm-12 col-md-4">
                                    <label class="form-label">{{ __('Force Update') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="hidden" name="force_update" id="force_update" class="checkbox-toggle-switch-input" value="{{ $settings['force_update'] ?? 0 }}">
                                        <input class="form-check-input checkbox-toggle-switch" type="checkbox" role="switch" {{ $settings['force_update'] == '1' ? 'checked' : '' }}id="switch_force_update">
                                        <label class="form-check-label" for="switch_force_update"></label>
                                    </div>
                                </div>

                                <div class="form-group col-sm-12 col-md-4">
                                    <label class="form-check-label">{{ __('Number With Suffix') }}</label>
                                    <div class="form-check form-switch  ">
                                        <input type="hidden" name="number_with_suffix" id="number_with_suffix" class="checkbox-toggle-switch-input" value="{{ $settings['number_with_suffix'] ?? 0 }}">
                                        <input class="form-check-input checkbox-toggle-switch" type="checkbox" role="switch" {{ $settings['number_with_suffix'] == '1' ? 'checked' : '' }} id="switch_number_with_suffix" aria-label="switch_number_with_suffix">
                                    </div>
                                </div>
                            </div>

                    </div>
                </div>


                    <div class="card">
                        <div class="card-body">
                            <div class="divider pt-3">
                                <h6 class="divider-text">{{ __('إعدادات الوديعة للأقسام') }}</h6>
                            </div>
                            @php
                                $sheinRatioStored = $settings['orders_deposit_shein_ratio'] ?? config('orders.deposit.departments.shein.ratio');
                                $computerRatioStored = $settings['orders_deposit_computer_ratio'] ?? config('orders.deposit.departments.computer.ratio');

                                $sheinRatioValue = old('orders_deposit_shein_ratio');
                                if ($sheinRatioValue === null) {
                                    $sheinRatioValue = $sheinRatioStored !== null ? rtrim(rtrim(number_format((float) $sheinRatioStored * 100, 2, '.', ''), '0'), '.') : '';
                                }

                                $computerRatioValue = old('orders_deposit_computer_ratio');
                                if ($computerRatioValue === null) {
                                    $computerRatioValue = $computerRatioStored !== null ? rtrim(rtrim(number_format((float) $computerRatioStored * 100, 2, '.', ''), '0'), '.') : '';
                                }

                                $sheinMinimumValue = old('orders_deposit_shein_minimum', $settings['orders_deposit_shein_minimum'] ?? config('orders.deposit.departments.shein.minimum_amount'));
                                $computerMinimumValue = old('orders_deposit_computer_minimum', $settings['orders_deposit_computer_minimum'] ?? config('orders.deposit.departments.computer.minimum_amount'));

                                $sheinIncludeValue = old('orders_deposit_shein_include_shipping', $settings['orders_deposit_shein_include_shipping'] ?? (config('orders.deposit.departments.shein.include_shipping') ? '1' : '0'));
                                $computerIncludeValue = old('orders_deposit_computer_include_shipping', $settings['orders_deposit_computer_include_shipping'] ?? (config('orders.deposit.departments.computer.include_shipping') ? '1' : '0'));
                            @endphp
                            <div class="row g-4">
                                <div class="col-md-6">
                                    <h6 class="fw-bold mb-3">{{ __('قسم شي إن') }}</h6>
                                    <div class="mb-3">
                                        <label for="orders_deposit_shein_ratio" class="form-label">{{ __('نسبة الدفعة المقدمة (%)') }}</label>
                                        <input type="number" step="0.01" min="0" max="100" class="form-control" id="orders_deposit_shein_ratio" name="orders_deposit_shein_ratio" value="{{ $sheinRatioValue }}" placeholder="{{ __('مثال: 30 يعني 30%') }}">
                                    </div>
                                    <div class="mb-3">
                                        <label for="orders_deposit_shein_minimum" class="form-label">{{ __('الحد الأدنى لمبلغ الوديعة') }}</label>
                                        <input type="number" step="0.01" min="0" class="form-control" id="orders_deposit_shein_minimum" name="orders_deposit_shein_minimum" value="{{ $sheinMinimumValue }}" placeholder="{{ __('مثال: 0 يعني بدون حد أدنى') }}">
                                    </div>
                                    <div class="mb-1">
                                        <label class="form-label d-block">{{ __('شمول تكلفة الشحن في الوديعة') }}</label>
                                        <div class="form-check form-switch">
                                            <input type="hidden" name="orders_deposit_shein_include_shipping" value="0">
                                            <input class="form-check-input" type="checkbox" role="switch" id="orders_deposit_shein_include_shipping" name="orders_deposit_shein_include_shipping" value="1" {{ $sheinIncludeValue == '1' ? 'checked' : '' }}>
                                            <label class="form-check-label" for="orders_deposit_shein_include_shipping">{{ __('تضمين رسوم التوصيل ضمن الدفعة المقدمة') }}</label>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <h6 class="fw-bold mb-3">{{ __('قسم الكمبيوتر') }}</h6>
                                    <div class="mb-3">
                                        <label for="orders_deposit_computer_ratio" class="form-label">{{ __('نسبة الدفعة المقدمة (%)') }}</label>
                                        <input type="number" step="0.01" min="0" max="100" class="form-control" id="orders_deposit_computer_ratio" name="orders_deposit_computer_ratio" value="{{ $computerRatioValue }}" placeholder="{{ __('مثال: 20 يعني 20%') }}">
                                    </div>
                                    <div class="mb-3">
                                        <label for="orders_deposit_computer_minimum" class="form-label">{{ __('الحد الأدنى لمبلغ الوديعة') }}</label>
                                        <input type="number" step="0.01" min="0" class="form-control" id="orders_deposit_computer_minimum" name="orders_deposit_computer_minimum" value="{{ $computerMinimumValue }}" placeholder="{{ __('مثال: 0 يعني بدون حد أدنى') }}">
                                    </div>

                                </div>
                            </div>


                        </div>
                    </div>


                    <div class="card">
                        <div class="card-body">
                            <div class="divider pt-3">
                                <h6 class="divider-text">{{ __('إعدادات تذكير تسوية الطلبات') }}</h6>
                            </div>
                            @php
                                $sheinPreShipReminder = old('orders_shein_settlement_reminder_pre_ship_hours', $settings['orders_shein_settlement_reminder_pre_ship_hours'] ?? 12);
                                $sheinArrivalReminder = old('orders_shein_settlement_reminder_arrival_hours', $settings['orders_shein_settlement_reminder_arrival_hours'] ?? 12);
                                $computerPreShipReminder = old('orders_computer_settlement_reminder_pre_ship_hours', $settings['orders_computer_settlement_reminder_pre_ship_hours'] ?? 12);
                                $computerArrivalReminder = old('orders_computer_settlement_reminder_arrival_hours', $settings['orders_computer_settlement_reminder_arrival_hours'] ?? 12);
                            @endphp
                            <div class="row g-4">
                                <div class="col-md-6">
                                    <h6 class="fw-bold mb-3">{{ __('قسم شي إن') }}</h6>
                                    <div class="mb-3">
                                        <label for="orders_shein_settlement_reminder_pre_ship_hours" class="form-label">{{ __('مهلة التذكير قبل الشحن (بالساعات)') }}</label>
                                        <input type="number" step="0.1" min="0" class="form-control" id="orders_shein_settlement_reminder_pre_ship_hours" name="orders_shein_settlement_reminder_pre_ship_hours" value="{{ $sheinPreShipReminder }}" placeholder="{{ __('مثال: 6 يعني 6 ساعات') }}">
                                    </div>
                                    <div class="mb-0">
                                        <label for="orders_shein_settlement_reminder_arrival_hours" class="form-label">{{ __('مهلة التذكير عند الوصول (بالساعات)') }}</label>
                                        <input type="number" step="0.1" min="0" class="form-control" id="orders_shein_settlement_reminder_arrival_hours" name="orders_shein_settlement_reminder_arrival_hours" value="{{ $sheinArrivalReminder }}" placeholder="{{ __('مثال: 2 يعني بعد ساعتين من الوصول') }}">
                                        <small class="text-muted d-block mt-1">{{ __('يتم إرسال التذكير عندما يتجاوز الزمن المحدد منذ آخر تحديث للحالة.') }}</small>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <h6 class="fw-bold mb-3">{{ __('قسم الكمبيوتر') }}</h6>
                                    <div class="mb-3">
                                        <label for="orders_computer_settlement_reminder_pre_ship_hours" class="form-label">{{ __('مهلة التذكير قبل الشحن (بالساعات)') }}</label>
                                        <input type="number" step="0.1" min="0" class="form-control" id="orders_computer_settlement_reminder_pre_ship_hours" name="orders_computer_settlement_reminder_pre_ship_hours" value="{{ $computerPreShipReminder }}" placeholder="{{ __('مثال: 6 يعني 6 ساعات') }}">
                                    </div>
                                    <div class="mb-0">
                                        <label for="orders_computer_settlement_reminder_arrival_hours" class="form-label">{{ __('مهلة التذكير عند الوصول (بالساعات)') }}</label>
                                        <input type="number" step="0.1" min="0" class="form-control" id="orders_computer_settlement_reminder_arrival_hours" name="orders_computer_settlement_reminder_arrival_hours" value="{{ $computerArrivalReminder }}" placeholder="{{ __('مثال: 2 يعني بعد ساعتين من الوصول') }}">
                                        <small class="text-muted d-block mt-1">{{ __('يتم إرسال التذكير عندما يتجاوز الزمن المحدد منذ آخر تحديث للحالة.') }}</small>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>



                    <div class="card mb-0">
                        <div class="card-body">
                            <div class="divider pt-3">
                                <h6 class="divider-text">{{ __('FCM Notification Settings') }}</h6>
                            </div>
                            <div class="form-group row mt-3">
                                <div class="col-md-6 col-sm-12">
                                    <label for="firebase_project_id" class="form-label">{{ __('Firebase Project Id') }}</label>
                                    <input type="text" id="firebase_project_id" name="firebase_project_id" class="form-control" placeholder="{{ __('Firebase Project Id') }}" value="{{ $settings['firebase_project_id'] ?? '' }}"/>
                                </div>


                                <div class="col-md-6 col-sm-12">
                                    <label for="service_file" class="form-label">{{ __('Service Json File') }}</label><span style="color: #00B2CA">{{__('(Accept only Json File)')}}</span>
                                    <input id="service_file" name="service_file" type="file" class="form-control">
                                    <p style="display: none" id="img_error_msg" class="badge rounded-pill bg-danger"></p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>



            <div class="card">
                <div class="card-body">
                    <div class="divider pt-3">
                        <h6 class="divider-text">{{ __('Invoice Settings') }}</h6>
                    </div>

                    <div class="row">
                        <div class="form-group col-md-6 col-sm-12">
                            <label for="invoice_company_name" class="form-label">{{ __('Invoice Company Name') }}</label>
                            <input id="invoice_company_name" name="invoice_company_name" type="text" class="form-control"
                                   placeholder="{{ __('Invoice Company Name') }}" value="{{ $settings['invoice_company_name'] ?? '' }}">
                        </div>

                        <div class="form-group col-md-6 col-sm-12">
                            <label for="invoice_company_tax_id" class="form-label">{{ __('Invoice Tax Number') }}</label>
                            <input id="invoice_company_tax_id" name="invoice_company_tax_id" type="text" class="form-control"
                                   placeholder="{{ __('Invoice Tax Number') }}" value="{{ $settings['invoice_company_tax_id'] ?? '' }}">
                        </div>

                        <div class="form-group col-md-6 col-sm-12">
                            <label for="invoice_company_email" class="form-label">{{ __('Invoice Email') }}</label>
                            <input id="invoice_company_email" name="invoice_company_email" type="email" class="form-control"
                                   placeholder="{{ __('Invoice Email') }}" value="{{ $settings['invoice_company_email'] ?? '' }}">
                        </div>

                        <div class="form-group col-md-6 col-sm-12">
                            <label for="invoice_company_phone" class="form-label">{{ __('Invoice Phone Number') }}</label>
                            <input id="invoice_company_phone" name="invoice_company_phone" type="text" class="form-control"
                                   placeholder="{{ __('Invoice Phone Number') }}" value="{{ $settings['invoice_company_phone'] ?? '' }}">
                        </div>

                        <div class="form-group col-sm-12">
                            <label for="invoice_company_address" class="form-label">{{ __('Invoice Address') }}</label>
                            <textarea id="invoice_company_address" name="invoice_company_address" class="form-control" rows="3"
                                      placeholder="{{ __('Invoice Address') }}">{{ $settings['invoice_company_address'] ?? '' }}</textarea>
                        </div>

                        <div class="form-group col-sm-12">
                            <label for="invoice_footer_note" class="form-label">{{ __('Invoice Footer Note') }}</label>
                            <textarea id="invoice_footer_note" name="invoice_footer_note" class="form-control" rows="4"
                                      placeholder="{{ __('Invoice Footer Note') }}">{{ $settings['invoice_footer_note'] ?? '' }}</textarea>
                            <small class="text-muted">{{ __('This text will appear at the bottom of each invoice PDF.') }}</small>
                        </div>

                        <div class="form-group col-sm-12 col-md-6">
                            <label class="form-label">{{ __('Invoice Logo') }}</label>
                            <input class="filepond" type="file" name="invoice_logo" id="invoice_logo">
                            <img src="{{ $settings['invoice_logo'] ?? '' }}" data-custom-image="{{ asset('assets/images/logo/sidebar_logo.png') }}"
                                 class="mt-2 invoice_logo" alt="invoice logo" style="height: 31%;width: 21%;">
                        </div>
                    </div>
                </div>
            </div>


            <div class="card">
                <div class="card-body">
                    <div class="divider pt-3">
                        <h6 class="divider-text">{{ __('Images') }}</h6>
                    </div>

                    <div class="row">
                        <div class="form-group col-md-4 col-sm-12">
                            <label class=" col-form-label ">{{ __('Favicon Icon') }}</label>
                            <input class="filepond" type="file" name="favicon_icon" id="favicon_icon">
                            <img src="{{ $settings['favicon_icon'] ?? '' }}" data-custom-image="{{asset('assets/images/logo/favicon.png')}}" class="mt-2 favicon_icon" alt="image" style=" height: 31%;width: 21%;">
                        </div>

                        <div class="form-group col-md-4 col-sm-12">
                            <label class="form-label ">{{ __('Company Logo') }}</label>
                            <input class="filepond" type="file" name="company_logo" id="company_logo">
                            <img src="{{ $settings['company_logo'] ?? '' }}" data-custom-image="{{asset('assets/images/logo/logo.png')}}" class="mt-2 company_logo" alt="image" style="height: 31%;width: 21%;">
                        </div>

                        <div class="form-group col-md-4 col-sm-12">
                            <label class="form-label ">{{ __('Login Page Image') }}</label>
                            <input class="filepond" type="file" name="login_image" id="login_image">
                            <img src="{{ $settings['login_image'] ?? ''  }}" data-custom-image="{{asset('assets/images/bg/login.jpg')}}" class="mt-2 login_image" alt="image" style="height: 31%;width: 21%;">
                        </div>
                        <div class="form-group col-md-4 col-sm-12">
                            <label class="form-label ">{{ __('Watermark Image') }}</label>
                            <input class="filepond" type="file" name="watermark_image" id="watermark_image">
                            <img src="{{ $settings['watermark_image'] ?? '' }}" data-custom-image="{{asset('assets/images/logo/watermark.png')}}" class="mt-2 watermark_image" alt="image" style="height: 31%;width: 21%;">
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-body">
                    <div class="divider pt-3">
                        <h6 class="divider-text">{{ __('Web Settings') }}</h6>
                    </div>

                    <div class="row">
                        <div class="form-group col-md-6 col-sm-12">
                            <label for="web_theme_color" class="form-label ">{{ __('Theme Color') }}</label>
                            <input id="web_theme_color" name="web_theme_color" type="color" class="form-control form-control-color" placeholder="{{ __('Theme Color') }}" value="{{ $settings['web_theme_color'] ?? '' }}">
                        </div>

                        <div class="form-group col-md-6 col-sm-12">
                            <label for="place_api_key" class="form-label ">{{ __('Place API Key') }}</label>
                            <input class="form-control" type="text" name="place_api_key" id="place_api_key" value="{{ $settings['place_api_key'] ?? '' }}">
                        </div>

                        <div class="form-group col-md-6 col-sm-12">
                            <label class="form-label ">{{ __('Header Logo') }}</label>
                            <input class="filepond" type="file" name="header_logo" id="header_logo">
                            <img src="{{ $settings['header_logo'] ?? '' }}" data-custom-image="{{asset('assets/images/logo/Header Logo.svg')}}" class="w-25" alt="image">
                        </div>

                        <div class="form-group col-md-6 col-sm-12">
                            <label class="form-label ">{{ __('Footer Logo') }}</label>
                            <input class="filepond" type="file" name="footer_logo" id="footer_logo">
                            <img src="{{ $settings['footer_logo'] ?? '' }}" data-custom-image="{{asset('assets/images/logo/Footer Logo.svg')}}" class="w-25" alt="image">
                        </div>

                        <div class="form-group col-md-6 col-sm-12">
                            <label class="form-label ">{{ __('Placeholder image') }} <small>{{__('(This image will be displayed if no image is available.)')}}</small></label>
                            <input class="filepond" type="file" name="placeholder_image" id="placeholder_image">
                            <img src="{{ $settings['placeholder_image'] ?? '' }}" data-custom-image="{{asset('assets/images/logo/favicon.png')}}" alt="image" style="height: 31%;width: 21%;">
                        </div>


                        <div class="form-group col-md-6 col-sm-12">
                            <label for="footer_description" class="form-label ">{{ __('Footer Description') }}</label>
                            <textarea id="footer_description" name="footer_description" class="form-control" rows="5" placeholder="{{ __('Footer Description') }}">{{ $settings['footer_description'] ?? '' }}</textarea>
                        </div>

                        <div class="form-group col-md-6 col-sm-12">
                            <label for="google_map_iframe_link" class="form-label ">{{ __('Google Map Iframe Link') }}</label>
                            <textarea id="google_map_iframe_link" name="google_map_iframe_link" type="text" class="form-control" rows="5" placeholder="{{ __('Google Map Iframe Link') }}">{{ $settings['google_map_iframe_link'] ?? '' }}</textarea>
                        </div>

                        <div class="form-group col-md-6 col-sm-12">
                            <label for="google_map_iframe_link" class="form-label ">{{ __('Default Latitude & Longitude') }} <small>{{__('(For Default Location Selection)')}}</small></label>
                            <div class="form-group">
                                <label for="default_latitude" class="form-label ">{{ __('Latitude') }}</label>
                                <input id="default_latitude" name="default_latitude" type="text" class="form-control" placeholder="{{ __('Latitude') }}" value="{{ $settings['default_latitude'] ?? '' }}">
                                <label for="default_longitude" class="form-label ">{{ __('Longitude') }}</label>
                                <input id="default_longitude" name="default_longitude" type="text" class="form-control" placeholder="{{ __('Longitude') }}" value="{{ $settings['default_longitude'] ?? '' }}">
                            </div>
                        </div>

                        <div class="form-group col-md-6 col-sm-12">
                            <label class="form-label">{{ __('Show Landing Page') }}</label>
                            <div class="form-check form-switch">
                                <input type="hidden" name="show_landing_page" value="0">
                                <input class="form-check-input" type="checkbox" id="show_landing_page" name="show_landing_page" value="1" {{ isset($settings['show_landing_page']) && $settings['show_landing_page'] == 1 ? 'checked' : '' }}>
                                <label class="form-check-label" for="show_landing_page">
                                    {{ __('On / Off') }}
                                </label>
                            </div>
                        </div>

                        <div class="divider pt-3">
                            <h6 class="divider-text">روابط وسائل التواصل الاجتماعي</h6>
                        </div>
                        <div class="form-group col-sm-12 col-md-4">
                            <label for="instagram_link" class="form-label ">رابط انستغرام</label>
                            <input id="instagram_link" name="instagram_link" type="url" class="form-control" placeholder="رابط انستغرام" value="{{ $settings['instagram_link'] ?? '' }}">
                        </div>
                        <div class="form-group col-sm-12 col-md-4">
                            <label for="x_link" class="form-label ">رابط تويتر (إكس)</label>
                            <input id="x_link" name="x_link" type="url" class="form-control" placeholder="رابط تويتر (إكس)" value="{{ $settings['x_link'] ?? '' }}">
                        </div>
                        <div class="form-group col-sm-12 col-md-4">
                            <label for="facebook_link" class="form-label ">رابط فيسبوك</label>
                            <input id="facebook_link" name="facebook_link" type="url" class="form-control" placeholder="رابط فيسبوك" value="{{ $settings['facebook_link'] ?? '' }}">
                        </div>
                        <div class="form-group col-sm-12 col-md-4">
                            <label for="linkedin_link" class="form-label ">رابط لينكد إن</label>
                            <input id="linkedin_link" name="linkedin_link" type="url" class="form-control" placeholder="رابط لينكد إن" value="{{ $settings['linkedin_link'] ?? '' }}">
                        </div>
                        <div class="form-group col-sm-12 col-md-4">
                            <label for="pinterest_link" class="form-label ">رابط بنترست</label>
                            <input id="pinterest_link" name="pinterest_link" type="url" class="form-control" placeholder="رابط بنترست" value="{{ $settings['pinterest_link'] ?? '' }}">
                        </div>


                        <div class="form-group col-sm-12 col-md-6">
                            <label for="whatsapp_number" class="form-label ">الرقم الرسمي على واتساب</label>
                            <input id="whatsapp_number" name="whatsapp_number" type="text" class="form-control" placeholder="رقم الواتساب مع كود الدولة (مثال: +1234567890)" value="{{ $settings['whatsapp_number'] ?? '' }}">
                        </div>


                        <div class="form-group col-sm-12 col-md-6">
                            <div class="d-flex justify-content-between align-items-center">
                                <label for="whatsapp_number_shein" class="form-label mb-0">رقم واتساب قسم شي إن</label>
                                <div class="form-check form-switch mb-0">
                                    <input type="hidden" name="whatsapp_enabled_shein" value="0">
                                    <input class="form-check-input" type="checkbox" id="whatsapp_enabled_shein" name="whatsapp_enabled_shein" value="1" {{ filter_var($settings['whatsapp_enabled_shein'] ?? false, FILTER_VALIDATE_BOOLEAN) ? 'checked' : '' }}>
                                    <label class="form-check-label" for="whatsapp_enabled_shein">{{ __('On / Off') }}</label>
                                </div>
                            </div>
                            <input id="whatsapp_number_shein" name="whatsapp_number_shein" type="text" class="form-control" placeholder="رقم الواتساب مع كود الدولة (مثال: +1234567890)" value="{{ $settings['whatsapp_number_shein'] ?? '' }}">
                        </div>

                        <div class="form-group col-sm-12 col-md-6">
                            <div class="d-flex justify-content-between align-items-center">
                                <label for="whatsapp_number_computer" class="form-label mb-0">رقم واتساب قسم الكمبيوتر</label>
                                <div class="form-check form-switch mb-0">
                                    <input type="hidden" name="whatsapp_enabled_computer" value="0">
                                    <input class="form-check-input" type="checkbox" id="whatsapp_enabled_computer" name="whatsapp_enabled_computer" value="1" {{ filter_var($settings['whatsapp_enabled_computer'] ?? false, FILTER_VALIDATE_BOOLEAN) ? 'checked' : '' }}>
                                    <label class="form-check-label" for="whatsapp_enabled_computer">{{ __('On / Off') }}</label>
                                </div>
                            </div>
                            <input id="whatsapp_number_computer" name="whatsapp_number_computer" type="text" class="form-control" placeholder="رقم الواتساب مع كود الدولة (مثال: +1234567890)" value="{{ $settings['whatsapp_number_computer'] ?? '' }}">
                        </div>
                    </div>
                </div>
            </div>
            <div class="card">
                <div class="card-body">
                    <div class="divider pt-3">
                        <h6 class="divider-text">{{ __('Deep Link') }}</h6>
                    </div>
                    <div class="form-group row mt-3">
                        <div class="col-md-6 col-sm-12">
                            <label for="deep_link_text_file" class="form-label">{{ __('Apple App Site Association File') }}</label>
                            <input id="deep_link_text_file" name="deep_link_text_file" type="file" class="form-control">
                            <p style="display: none" id="img_error_msg" class="badge rounded-pill bg-danger"></p>
                        </div>
                        <div class="col-md-6 col-sm-12">
                            <label for="deep_link_json_file" class="form-label">{{ __('Assetlinks File') }}</label>
                            <input id="deep_link_json_file" name="deep_link_json_file" type="file" class="form-control">
                            <p style="display: none" id="img_error_msg" class="badge rounded-pill bg-danger"></p>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-body">
                    <div class="divider pt-3">
                        <h6 class="divider-text">{{ __('Authentication Setting (Enable/Disable)') }}</h6>
                    </div>
                    <div class="form-group row mt-3">
                        <div class="form-group col-md-6 col-sm-12">
                            <label class="form-label">{{ __('Mobile Authentication') }}</label>
                            <div class="form-check form-switch">
                                <input type="hidden" name="mobile_authentication" value="0">
                                <input class="form-check-input auth" type="checkbox" id="mobile_authentication" name="mobile_authentication" value="1" {{ isset($settings['mobile_authentication']) ? ($settings['mobile_authentication'] == 1 ? 'checked' : '') : 'checked' }}>
                                <label class="form-check-label" for="google_authentication">
                                    {{ __('On / Off') }}
                                </label>
                            </div>
                        </div>
                        <div class="form-group col-md-6 col-sm-12">
                            <label class="form-label">{{ __('Google Authentication') }}</label>
                            <div class="form-check form-switch">
                                <input type="hidden" name="google_authentication" value="0">
                                <input class="form-check-input auth" type="checkbox" id="google_authentication" name="google_authentication" value="1" {{ isset($settings['google_authentication']) && $settings['google_authentication'] == 1 ? 'checked' : '' }}>
                                <label class="form-check-label" for="google_authentication">
                                    {{ __('On / Off') }}
                                </label>
                            </div>
                        </div>
                        <div class="form-group col-md-6 col-sm-12">
                            <label class="form-label">{{ __('Email Authentication') }}</label>
                            <div class="form-check form-switch">
                                <input type="hidden" name="email_authentication" value="0">
                                <input class="form-check-input auth" type="checkbox" id="email_authentication" name="email_authentication" value="1" {{ isset($settings['email_authentication']) && $settings['email_authentication'] == 1 ? 'checked' : '' }}>
                                <label class="form-check-label" for="email_authentication">
                                    {{ __('On / Off') }}
                                </label>
                            </div>
                        </div>
                        <div class="form-group col-md-6 col-sm-12">
                            <label class="form-label">{{ __('Apple Authentication') }}</label>
                            <div class="form-check form-switch">
                                <input type="hidden" name="apple_authentication" value="0">
                                <input class="form-check-input auth" type="checkbox" id="email_authentication" name="apple_authentication" value="1" {{ isset($settings['apple_authentication']) && $settings['apple_authentication'] == 1 ? 'checked' : '' }}>
                                <label class="form-check-label" for="apple_authentication">
                                    {{ __('On / Off') }}
                                </label>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12 d-flex justify-content-end">
                <button type="submit" value="btnAdd" class="btn btn-primary me-1 mb-3">{{ __('Save') }}</button>
            </div>
        </form>
    </section>
@endsection
@section('js')
    <script>
        function successFunction() {
            window.location.reload();
        }
    </script>
@endsection
