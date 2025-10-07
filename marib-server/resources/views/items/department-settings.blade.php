@extends('layouts.main')

@section('title')
    {{ __('إعدادات :department', ['department' => $departmentLabel]) }}
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

            $ratioKey = $settingsKeys['deposit_ratio'];
            $minimumKey = $settingsKeys['deposit_minimum'];
            $whatsappEnabledKey = $settingsKeys['whatsapp_enabled'];
            $whatsappNumberKey = $settingsKeys['whatsapp_number'];
            $returnPolicyKey = $settingsKeys['return_policy'];

            $whatsappEnabledChecked = filter_var(old($whatsappEnabledKey, $formValues[$whatsappEnabledKey] ?? false), FILTER_VALIDATE_BOOLEAN);
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

        @can($permission)
            @include('items.partials.department-advertiser-form', [
                'action' => $advertiserRoute,
                'advertiser' => $advertiser ?? [],
                'title' => __('بيانات المعلن للقسم'),
            ])
        @endcan

        @can($permission)
            <div class="row">
                <div class="col-12">
                    <div class="card mb-4">
                        <div class="card-header">
                            <h5 class="card-title mb-0">{{ __('إعدادات القسم') }}</h5>
                        </div>
                        <div class="card-body">
                            <form action="{{ $updateRoute }}" method="POST" class="create-form-without-reset">
                                @csrf

                                <div class="row g-3">
                                    <div class="col-md-6">
                                        <label for="department-deposit-ratio" class="form-label">{{ __('نسبة الدفعة المقدمة (%)') }}</label>
                                        <input
                                            type="number"
                                            step="0.01"
                                            min="0"
                                            max="100"
                                            id="department-deposit-ratio"
                                            name="{{ $ratioKey }}"
                                            class="form-control"
                                            value="{{ old($ratioKey, $formValues[$ratioKey] ?? '') }}"
                                            placeholder="{{ __('مثال: 30 يعني 30% من قيمة الطلب') }}"
                                        >
                                        <small class="form-text text-muted">{{ __('اترك الحقل فارغًا لاستخدام القيمة الافتراضية الحالية.') }}</small>
                                    </div>

                                    <div class="col-md-6">
                                        <label for="department-deposit-minimum" class="form-label">{{ __('الحد الأدنى لمبلغ الوديعة') }}</label>
                                        <input
                                            type="number"
                                            step="0.01"
                                            min="0"
                                            id="department-deposit-minimum"
                                            name="{{ $minimumKey }}"
                                            class="form-control"
                                            value="{{ old($minimumKey, $formValues[$minimumKey] ?? '') }}"
                                            placeholder="{{ __('مثال: 0 يعني بدون حد أدنى') }}"
                                        >
                                        <small class="form-text text-muted">{{ __('سيتم تطبيق الحد الأدنى على جميع الطلبات الخاصة بالقسم.') }}</small>
                                    </div>


                                    <div class="col-md-6">
                                        <label class="form-label d-block">{{ __('تفعيل واتساب القسم') }}</label>
                                        <div class="form-check form-switch">
                                            <input type="hidden" name="{{ $whatsappEnabledKey }}" value="0">
                                            <input
                                                class="form-check-input"
                                                type="checkbox"
                                                role="switch"
                                                id="department-whatsapp-enabled"
                                                name="{{ $whatsappEnabledKey }}"
                                                value="1"
                                                {{ $whatsappEnabledChecked ? 'checked' : '' }}
                                            >
                                            <label class="form-check-label" for="department-whatsapp-enabled">{{ __('تشغيل قناة الواتساب الخاصة بالقسم') }}</label>
                                        </div>
                                    </div>

                                    <div class="col-md-6">
                                        <label for="department-whatsapp-number" class="form-label">{{ __('رقم واتساب القسم') }}</label>
                                        <input
                                            type="text"
                                            id="department-whatsapp-number"
                                            name="{{ $whatsappNumberKey }}"
                                            class="form-control"
                                            value="{{ old($whatsappNumberKey, $formValues[$whatsappNumberKey] ?? '') }}"
                                            placeholder="{{ __('أدخل الرقم مع رمز الدولة (مثال: +967123456789)') }}"
                                        >
                                    </div>

                                    <div class="col-12">
                                        <label for="department-return-policy" class="form-label">{{ __('سياسة الاسترجاع الخاصة بالقسم') }}</label>
                                        <textarea
                                            id="department-return-policy"
                                            name="{{ $returnPolicyKey }}"
                                            rows="6"
                                            class="form-control"
                                            placeholder="{{ __('اكتب سياسة الاسترجاع أو أي ملاحظات تود إظهارها للعملاء.') }}"
                                        >{{ old($returnPolicyKey, $formValues[$returnPolicyKey] ?? '') }}</textarea>
                                    </div>
                                </div>

                                <div class="mt-4">
                                    <button type="submit" class="btn btn-primary">{{ __('حفظ التغييرات') }}</button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        @endcan
    </section>
@endsection