@if (!empty($alerts ?? []))
    <div class="alert alert-info border-0 shadow-sm mb-3" role="alert">
        <div class="d-flex flex-column gap-1">
            <h6 class="fw-semibold mb-1">{{ __('إرشادات التنبيهات') }}</h6>
            @foreach($alerts as $key => $config)
                <div class="d-flex flex-wrap align-items-center gap-2">
                    <span class="badge bg-light text-dark">{{ $key }}</span>
                    <span class="small text-muted">{{ data_get($config, 'description', __('لا يتم توفير وصف.')) }}</span>
                </div>
            @endforeach
        </div>
    </div>
@endif
