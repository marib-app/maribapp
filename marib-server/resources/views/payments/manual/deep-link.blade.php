<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ __('Open in App') }}</title>
    @include('layouts.include')
</head>
<body>
<div class="container py-5">
    <div class="row justify-content-center">
        <div class="col-md-6 text-center">
            <h1 class="h4 mb-3">{{ __('Open transaction in the app') }}</h1>
            <p class="text-muted">{{ __('We are redirecting you to the mobile application. If nothing happens, use the buttons below.') }}</p>
            <div class="d-flex justify-content-center gap-2 mt-4">
                <a href="{{ $playStoreLink }}" class="btn btn-outline-primary" target="_blank" rel="noopener">
                    <i class="fa fa-google-play me-1"></i>{{ __('Get on Play Store') }}
                </a>
                <a href="{{ $appStoreLink }}" class="btn btn-outline-dark" target="_blank" rel="noopener">
                    <i class="fa fa-apple me-1"></i>{{ __('Get on App Store') }}
                </a>
            </div>
        </div>
    </div>
</div>

@include('layouts.footer_script')
<script>
    document.addEventListener('DOMContentLoaded', function () {
        const appScheme = 'maribsrv://{{ $deeplinkPath }}';
        const appStoreLink = '{{ $appStoreLink }}';
        const playStoreLink = '{{ $playStoreLink }}';
        const fallback = navigator.userAgent.match(/iPad|iPhone|iPod/) ? appStoreLink : playStoreLink;

        window.location.href = appScheme;

        setTimeout(function () {
            window.location.href = fallback;
        }, 1200);
    });
</script>
</body>
</html>
