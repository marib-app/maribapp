@extends('layouts.main')

@section('title')
    {{ __('إعدادات الفواتير') }}
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
        <form class="create-form-without-reset" action="{{ route('settings.store') }}" method="post" enctype="multipart/form-data" data-success-function="successFunction" data-parsley-validate>
            @csrf
            <div class="row d-flex mb-3">
                <div class="col-lg-6">
                    <div class="card h-100">
                        <div class="card-body">
                            <div class="divider pt-3">
                                <h6 class="divider-text">{{ __('البيانات الرئيسية') }}</h6>
                            </div>
                            <div class="row">
                                <div class="col-sm-12 form-group">
                                    <label for="invoice_company_name" class="form-label mt-1">{{ __('اسم الشركة على الفاتورة') }}</label>
                                    <input type="text" id="invoice_company_name" name="invoice_company_name" class="form-control" value="{{ $settings['invoice_company_name'] ?? ($settings['company_name'] ?? '') }}" placeholder="{{ __('اسم الشركة') }}">
                                </div>
                                <div class="col-sm-12 form-group">
                                    <label for="invoice_company_tax_id" class="form-label mt-1">{{ __('الرقم الضريبي') }}</label>
                                    <input type="text" id="invoice_company_tax_id" name="invoice_company_tax_id" class="form-control" value="{{ $settings['invoice_company_tax_id'] ?? '' }}" placeholder="{{ __('أدخل الرقم الضريبي') }}">
                                </div>
                                <div class="col-sm-12 form-group">
                                    <label for="invoice_company_phone" class="form-label mt-1">{{ __('رقم التواصل') }}</label>
                                    <input type="text" id="invoice_company_phone" name="invoice_company_phone" class="form-control" value="{{ $settings['invoice_company_phone'] ?? ($settings['company_tel1'] ?? '') }}" placeholder="{{ __('رقم الهاتف') }}">
                                </div>
                                <div class="col-sm-12 form-group">
                                    <label for="invoice_company_email" class="form-label mt-1">{{ __('البريد الإلكتروني') }}</label>
                                    <input type="email" id="invoice_company_email" name="invoice_company_email" class="form-control" value="{{ $settings['invoice_company_email'] ?? ($settings['company_email'] ?? '') }}" placeholder="{{ __('البريد الإلكتروني') }}">
                                </div>
                                <div class="col-sm-12 form-group">
                                    <label for="invoice_company_address" class="form-label mt-1">{{ __('عنوان الفاتورة') }}</label>
                                    <textarea id="invoice_company_address" name="invoice_company_address" class="form-control" rows="4" placeholder="{{ __('أدخل عنوان الشركة') }}">{{ $settings['invoice_company_address'] ?? ($settings['company_address'] ?? '') }}</textarea>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-lg-6">
                    <div class="card h-100">
                        <div class="card-body">
                            <div class="divider pt-3">
                                <h6 class="divider-text">{{ __('الشعار وتذييل الفاتورة') }}</h6>
                            </div>
                            <div class="row">
                                <div class="col-sm-12 form-group">
                                    <label for="invoice_logo" class="form-label">{{ __('شعار الفاتورة') }}</label>
                                    <input class="filepond" type="file" name="invoice_logo" id="invoice_logo">
                                    <img src="{{ $settings['invoice_logo'] ?? ($settings['company_logo'] ?? '') }}" data-custom-image="{{ asset('assets/images/logo/sidebar_logo.png') }}" class="mt-2 invoice_logo" alt="logo" style="max-height: 120px;">
                                </div>
                                <div class="col-sm-12 form-group">
                                    <label for="invoice_footer_note" class="form-label">{{ __('ملاحظة تظهر أسفل الفاتورة') }}</label>
                                    <textarea id="invoice_footer_note" name="invoice_footer_note" class="form-control" rows="4" placeholder="{{ __('أدخل نص الشكر أو الملاحظات الختامية') }}">{{ $settings['invoice_footer_note'] ?? '' }}</textarea>
                                </div>
                                <div class="col-sm-12 form-group">
                                    <label for="currency_symbol" class="form-label">{{ __('رمز العملة الافتراضي') }}</label>
                                    <input type="text" id="currency_symbol" name="currency_symbol" class="form-control" value="{{ \App\Support\Currency::preferredSymbol($settings['currency_symbol'] ?? null, $settings['currency_code'] ?? ($settings['currency'] ?? ($settings['default_currency'] ?? config('app.currency')))) }}" placeholder="{{ __('مثال: ر.ي أو ر.س أو أ.ر') }}">
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-body">
                    <div class="divider pt-3">
                        <h6 class="divider-text">{{ __('معاينة سريعة') }}</h6>
                    </div>
                    <p class="text-muted mb-2">{{ __('سيتم استخدام البيانات أعلاه في قالب الفاتورة الافتراضي. يمكنك تنزيل فاتورة لأي طلب للتحقق من النتيجة.') }}</p>
                    <div class="bg-light rounded p-3">
                        <p class="mb-1"><strong>{{ __('العناصر المعروضة') }}:</strong> {{ __('اسم الشركة، العنوان، البريد الإلكتروني، رقم التواصل، الرقم الضريبي، ملاحظات التذييل، شعار الفاتورة') }}</p>
                        <p class="mb-0"><strong>{{ __('التنسيق') }}:</strong> {{ __('اتجاه من اليمين إلى اليسار مع دعم كامل للغة العربية والخط المناسب داخل ملف الـ PDF') }}</p>
                    </div>
                </div>
            </div>

            <div class="col-12 d-flex justify-content-end">
                <button type="submit" class="btn btn-primary me-1 mb-3">{{ __('حفظ الإعدادات') }}</button>
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