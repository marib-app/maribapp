{{-- صفحة الإعدادات الرئيسية: تعرض كل أقسام الإعدادات ككروت بنفس الثيم القديم --}}
@extends('layouts.main')

@section('title')
    {{ __('الإعدادات') }}
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
  <div class="row">

    @if(Route::has('settings.system'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.system') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-cogs text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">الإعدادات العامة</h5>
          <div>اذهب إلى الإعدادات <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif



    @if(Route::has('settings.invoice.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.invoice.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-file-invoice text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">إعدادات الفواتير</h5>
          <div>تخصيص مظهر الفاتورة <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif



    @if(Route::has('settings.payment-gateway.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.payment-gateway.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-credit-card text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">بوابات الدفع</h5>
          <div>إدارة طرق الدفع <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif

    @if(Route::has('settings.firebase.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.firebase.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-cloud text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">إعدادات Firebase</h5>
          <div>تهيئة Firebase <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif


    @if(Route::has('settings.whatsapp.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.whatsapp.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fab fa-whatsapp text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">رسائل واتساب OTP</h5>
          <div>إدارة رسائل التحقق عبر واتساب <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif

    @if(Route::has('settings.language.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.language.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-language text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">اللغات</h5>
          <div>ملفات الترجمة واللغات <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif

    @if(Route::has('settings.admob.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.admob.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-ad text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">إعلانات AdMob</h5>
          <div>إعدادات الإعلانات <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif

    @if(Route::has('settings.seo-settings.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.seo-settings.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-search text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">إعدادات SEO</h5>
          <div>الميتا والسيو للموقع <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif

    @if(Route::has('settings.file-manager.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.file-manager.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-folder-open text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">مدير الملفات</h5>
          <div>إعدادات التخزين والوسائط <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif

    @if(Route::has('settings.system-status.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.system-status.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-tachometer-alt text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">حالة النظام</h5>
          <div>فحص الروابط والكاش والخدمات <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif

    @if(Route::has('settings.about-us.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.about-us.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-info-circle text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">من نحن</h5>
          <div>تحرير صفحة من نحن <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif

    @if(Route::has('settings.terms-conditions.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.terms-conditions.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-file-contract text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">الشروط والأحكام</h5>
          <div>تحرير صفحة الشروط <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif


        @if(Route::has('settings.usage-guide.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.usage-guide.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-book-open text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">دليل الاستخدام</h5>
          <div>تحرير دليل الاستخدام <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif


    @if(Route::has('settings.privacy-policy.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.privacy-policy.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-shield-alt text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">سياسة الخصوصية</h5>
          <div>تحرير صفحة الخصوصية <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif

    @if(Route::has('settings.contact-us.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.contact-us.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-address-book text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">اتصل بنا</h5>
          <div>تحرير صفحة التواصل <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif

    @hasrole('Super Admin')
    @if(Route::has('settings.error-logs.index'))
    <div class="col-xxl-3 col-xl-4 col-lg-6 col-md-12 mb-3">
      <a href="{{ route('settings.error-logs.index') }}" class="card setting_active_tab h-100" style="text-decoration:none;">
        <div class="content d-flex h-100">
          <div class="row mx-2">
            <div class="provider_a test">
              <i class="fas fa-bug text-dark icon_font_size"></i>
            </div>
          </div>
        </div>
        <div class="card-body">
          <h5 class="title">عارض السجلات</h5>
          <div>استعراض أخطاء النظام <i class="fas fa-arrow-right mt-2 arrow_icon"></i></div>
        </div>
      </a>
    </div>
    @endif
    @endhasrole

  </div>
</section>
@endsection
