<!--
  ============================================
  ملف: resources/views/layouts/app.blade.php
  ============================================
-->

<!DOCTYPE html>
@php



    if (function_exists('current_language')) {
        current_language();
    }


    $lang = Session::get('language');
    $isRTL = false;
    $currentLocale = app()->getLocale();

    if (is_object($lang)) {
        if (isset($lang->rtl)) {
            $isRTL = (bool) $lang->rtl;
        }
        if (isset($lang->code)) {
            $currentLocale = $lang->code;
        } elseif (isset($lang->locale)) {
            $currentLocale = $lang->locale;
        }
    } elseif (is_array($lang)) {
        if (array_key_exists('rtl', $lang)) {
            $isRTL = (bool) $lang['rtl'];
        }
        if (isset($lang['code'])) {
            $currentLocale = $lang['code'];
        } elseif (isset($lang['locale'])) {
            $currentLocale = $lang['locale'];
        }
    } elseif (is_string($lang) && $lang !== '') {
        $isRTL = $lang === 'ar';
        $currentLocale = $lang;
    }

    if ($currentLocale && $currentLocale !== app()->getLocale()) {
        app()->setLocale($currentLocale);
    }


    if (app()->getLocale() == 'ar') { $isRTL = true; }
@endphp
<html lang="{{ app()->getLocale() }}" dir="{{ $isRTL ? 'rtl' : 'ltr' }}" data-bs-theme="light">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="shortcut icon" href="{{ $favicon ?? url('assets/images/logo/favicon.png') }}" type="image/x-icon">
    <title>{{ trim($__env->yieldContent('title')) ?: config('app.name') }}</title>
    <meta name="csrf-token" content="{{ csrf_token() }}"/>

    {{-- خطوط تدعم العربية + تثبيت للعناصر الرسومية --}}
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
        :root { --arabic-font: "Cairo", system-ui, -apple-system, "Segoe UI", Arial, sans-serif; }
        html, body { font-family: var(--arabic-font); }
        canvas, svg, .apexcharts-legend, .chartjs-render-monitor { font-family: var(--arabic-font) !important; }
    </style>

    @include('layouts.include')

    @if($isRTL)
    <link rel="stylesheet" href="{{ asset('assets/css/rtl-sidebar.css') }}">
    <style>
        body.rtl #sidebar { right: 0 !important; left: auto !important; position: fixed; }
        body.rtl #main { margin-right: 300px !important; margin-left: 0 !important; }
        body.rtl .sidebar-wrapper { right: 0 !important; left: auto !important; }
        body.rtl #sidebar:not(.active) .sidebar-wrapper { right: -300px !important; }
        body.rtl #sidebar:not(.active) ~ #main { margin-right: 0 !important; }
        @media screen and (max-width: 1199px) {
            body.rtl #main { margin-right: 0 !important; }
            body.rtl .sidebar-wrapper { right: -300px !important; }
            body.rtl #sidebar.active .sidebar-wrapper { right: 0 !important; }
        }
    </style>
    @endif

    @yield('css')
</head>
<body class="{{ $isRTL ? 'rtl' : 'ltr' }}">
<div id="app">
    @include('layouts.sidebar')
    <div id="main" class="layout-navbar">
        @include('layouts.topbar')
        <div id="main-content">
            <div class="page-heading">
                @yield('page-title')
            </div>
            @yield('content')
        </div>
    </div>
    <div class="wrapper mt-5">
        <div class="content">
            @include('layouts.footer')
        </div>
    </div>
</div>

@include('layouts.footer_script')

{{-- لضمان JSON عربي غير مُهَرَّب عند الحاجة داخل الصفحات --}}
<script>
  // Chart.js (إن وُجد)
  if (window.Chart && Chart.defaults && Chart.defaults.font) {
    Chart.defaults.font.family = getComputedStyle(document.documentElement).getPropertyValue('--arabic-font');
  }
  // ApexCharts (إن وُجد)
  if (window.Apex) {
    window.Apex = Object.assign({},
      window.Apex || {},
      { chart: Object.assign({}, (window.Apex||{}).chart, {
          fontFamily: getComputedStyle(document.documentElement).getPropertyValue('--arabic-font')
        })
      }
    );
  }
</script>

@yield('js')
@yield('scripts')
</body>
</html>
