@php

    // ضمان تهيئة اللغة الحالية حتى ولو كانت الجلسة تحتوي على سلسلة فقط
    if (function_exists('current_language')) {
        current_language();
    }


    // استخدام المتغير $isRTL الذي تم تعريفه في app.blade.php
    // إذا لم يكن معرفًا، فسنقوم بتعريفه هنا
    if (!isset($isRTL)) {
        $lang = Session::get('language');
        $isRTL = false;

        if (is_object($lang) && isset($lang->rtl)) {
            $isRTL = (bool) $lang->rtl;
        } elseif (is_array($lang) && array_key_exists('rtl', $lang)) {
            $isRTL = (bool) $lang['rtl'];
        } elseif (is_string($lang)) {
            $isRTL = $lang === 'ar';
        }
        
        
        // تعيين قيمة افتراضية للغة العربية إذا لم تكن محددة
        if (app()->getLocale() == 'ar') {
            $isRTL = true;
        }
    }
@endphp

@if (!$isRTL)
    {{--NON RTL CSS--}}
    <link rel="stylesheet" href="{{ asset('assets/css/main/app.css') }}">
    <link rel="stylesheet" href="{{ asset('assets/css/pages/otherpages.css') }}"/>
    <link rel="stylesheet" href="{{ asset('assets/css/custom.css') }}"/>
@else
    {{--RTL CSS--}}
    <link rel="stylesheet" href="{{ asset('assets/css/main/rtl.css') }}">
    <link rel="stylesheet" href="{{ asset('assets/css/pages/otherpages_rtl.css') }}"/>
    <link rel="stylesheet" href="{{ asset('assets/css/custom.css') }}"/>
@endif
{{--Dark Theme--}}
<link rel="stylesheet" href="{{ asset('assets/css/dark-theme.css') }}">

{{--Bootstrap Switch --}}
<link rel="stylesheet" href="{{asset("assets/css/bootstrap-switch-button.min.css")}}">

{{--Toastify--}}
<link rel="stylesheet" href="{{ asset('assets/extensions/toastify-js/toastify.css') }}">

{{--Bootstrap Table--}}
<link rel="stylesheet" href="{{ asset('assets/extensions/bootstrap-table/bootstrap-table.min.css') }}" type="text/css"/>
<link rel="stylesheet" href="{{ asset('assets/extensions/bootstrap-table/fixed-columns/bootstrap-table-fixed-columns.min.css') }}" type="text/css"/>
<link rel="stylesheet" href="{{ asset("assets/extensions/bootstrap-table/bootstrap-table-reorder-rows.css")}}">


{{--Font Awesome--}}
<link rel="stylesheet" href="{{ asset('assets/extensions/@fortawesome/fontawesome-free/css/all.min.css') }}" type="text/css"/>

{{--Magnific Popup--}}
<link rel="stylesheet" href="{{ asset('assets/extensions/magnific-popup/magnific-popup.css') }}">

{{--Select2--}}
<link rel="stylesheet" href="{{ asset('assets/extensions/select2/select2.min.css') }}"/>
<link rel="stylesheet" href="{{ asset('assets/extensions/select2/select2-bootstrap-5-theme.min.css') }}"/>

{{--Sweet Alert--}}
<link rel="stylesheet" href="{{ asset('assets/extensions/sweetalert2/sweetalert2.min.css') }}"/>

{{--Filepond--}}
<link rel="stylesheet" href="{{ asset('assets/extensions/filepond/filepond.min.css') }}" type="text/css"/>
<link rel="stylesheet" href="{{ asset('assets/extensions/filepond/filepond-plugin-image-preview.min.css') }}" type="text/css"/>
<link rel="stylesheet" href="{{ asset('assets/extensions/filepond/filepond-plugin-pdf-preview.min.css') }}" type="text/css"/>

{{--Jquery Vectormap--}}
<link rel="stylesheet" href="{{ asset('assets/css/pages/jquery-jvectormap-2.0.5.css') }}" type="text/css"/>

{{--JS Tree--}}
<link rel="stylesheet" href="{{asset('assets/extensions/jstree/jstree.min.css')}}"/>

{{--<link href="https://cdn.datatables.net/1.13.2/css/dataTables.bootstrap5.min.css" rel="stylesheet"/>--}}
{{--<link rel="stylesheet" href="{{ url('assets/extensions/chosen.css') }}"/>--}}

<script>
    const FALLBACK_IMAGE = "{{ asset('/assets/images/no_image_available.png') }}";

    const setImageSource = (image, source) => {
        if (image.dataset.fallbackApplied === source) {
            return;
        }

        image.dataset.fallbackApplied = source;
        image.src = source;
    };

    const handleImageError = (image) => {
        if (!(image instanceof HTMLImageElement)) {
            return;
        }

        if (image.classList.contains('custom-default-image')) {
            return;
        }

        const customImage = image.getAttribute('data-custom-image');
        if (customImage && image.src !== customImage) {
            setImageSource(image, customImage);
            return;
        }

        if (!image.src.includes('no_image_available.png')) {
            setImageSource(image, FALLBACK_IMAGE);
        }
    };

    const onImageError = (event) => {
        const target = event.currentTarget instanceof HTMLImageElement ? event.currentTarget : event.target;
        handleImageError(target);
    };

    const registerImage = (image) => {
        if (!(image instanceof HTMLImageElement)) {
            return;
        }

        image.removeEventListener('error', onImageError);
        image.addEventListener('error', onImageError);

        if (image.complete && image.naturalWidth === 0) {
            handleImageError(image);
        }
    };

    document.querySelectorAll('img').forEach(registerImage);

    // Create a MutationObserver to watch for DOM changes
    const observer = new MutationObserver((mutationsList) => {
        mutationsList.forEach((mutation) => {
            mutation.addedNodes?.forEach((node) => {
                if (node instanceof HTMLImageElement) {
                    registerImage(node);
                } else if (node instanceof HTMLElement) {
                    node.querySelectorAll?.('img').forEach(registerImage);
                }
            });
        });
    });

    // Start observing changes in the DOM
    observer.observe(document.body ?? document, {childList: true, subtree: true});

    const onErrorImage = (e) => {
        handleImageError(e.target);

    };

    {{--const onErrorImageSidebarHorizontalLogo = (e) => {--}}
    {{--    if (!e.target.src.includes('no_image_available.jpg')) {--}}
    {{--        e.target.src = "{{asset('/assets/vertical-logo.svg')}}";--}}
    {{--    }--}}
    {{--};--}}
</script>
