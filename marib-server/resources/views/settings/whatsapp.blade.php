@extends('layouts.main')

@section('title')
    {{ __('إعدادات واتساب OTP') }}
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
        <form class="create-form-without-reset" action="{{ route('settings.store') }}" method="post" data-parsley-validate>
            @csrf
            <div class="row">
                <div class="col-12 col-lg-8">
                    <div class="card">
                        <div class="card-body">
                            <div class="divider pt-3">
                                <h6 class="divider-text">{{ __('إعدادات التفعيل') }}</h6>
                            </div>
                            <div class="row">
                                <div class="col-12 mb-3">
                                    <label class="form-label">{{ __('تفعيل رمز التحقق عبر واتساب') }}</label>
                                    <div class="form-check form-switch">
                                        <input type="hidden" name="whatsapp_otp_enabled" id="whatsapp_otp_enabled" class="checkbox-toggle-switch-input" value="{{ $settings['whatsapp_otp_enabled'] ?? 0 }}">
                                        <input class="form-check-input checkbox-toggle-switch" type="checkbox" role="switch" id="switch_whatsapp_otp_enabled" {{ ($settings['whatsapp_otp_enabled'] ?? 0) == 1 ? 'checked' : '' }}>
                                        <label class="form-check-label" for="switch_whatsapp_otp_enabled">{{ __('تفعيل أو إيقاف الخدمة') }}</label>
                                    </div>
                                </div>
                            </div>

                            <div class="divider pt-3">
                                <h6 class="divider-text">{{ __('قوالب الرسائل') }}</h6>
                            </div>
                            <div class="row">
                                <div class="col-12 mb-3">
                                    <label for="whatsapp_otp_message_new_user" class="form-label">{{ __('رسالة المستخدم الجديد') }}</label>
                                    <textarea id="whatsapp_otp_message_new_user" name="whatsapp_otp_message_new_user" class="form-control" rows="6" placeholder="{{ __('اكتب رسالة تحتوي على :otp ليتم استبداله بالرمز') }}">{{ $settings['whatsapp_otp_message_new_user'] ?? '' }}</textarea>
                                    <small class="text-muted">{{ __('يجب أن يتضمن النص العنصر :otp ليتم استبداله بالرمز الفعلي.') }}</small>
                                </div>
                                <div class="col-12 mb-3">
                                    <label for="whatsapp_otp_message_forgot_password" class="form-label">{{ __('رسالة استعادة كلمة المرور') }}</label>
                                    <textarea id="whatsapp_otp_message_forgot_password" name="whatsapp_otp_message_forgot_password" class="form-control" rows="6" placeholder="{{ __('اكتب رسالة تحتوي على :otp ليتم استبداله بالرمز') }}">{{ $settings['whatsapp_otp_message_forgot_password'] ?? '' }}</textarea>
                                    <small class="text-muted">{{ __('يجب أن يتضمن النص العنصر :otp ليتم استبداله بالرمز الفعلي.') }}</small>
                                </div>
                            </div>

                            <div class="divider pt-3">
                                <h6 class="divider-text">{{ __('إعدادات الربط') }}</h6>
                            </div>
                            <div class="row">
                                <div class="col-12 mb-3">
                                    <label for="whatsapp_otp_token" class="form-label">{{ __('رمز التكامل (Token)') }}</label>
                                    <input type="text" id="whatsapp_otp_token" name="whatsapp_otp_token" class="form-control" value="{{ $settings['whatsapp_otp_token'] ?? '' }}" placeholder="{{ __('أدخل رمز التكامل لخدمة واتساب') }}">
                                </div>
                            </div>

                            <div class="row">
                                <div class="col-12 text-end">
                                    <button type="submit" class="btn btn-primary">{{ __('حفظ الإعدادات') }}</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </form>
    </section>
@endsection