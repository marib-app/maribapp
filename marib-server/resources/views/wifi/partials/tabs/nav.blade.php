<ul class="nav nav-pills wifi-tabs" id="wifiAdminTabs" role="tablist">
    <li class="nav-item" role="presentation">
        <button class="nav-link active" id="wifi-networks-tab" data-bs-toggle="pill" data-bs-target="#wifi-networks"
                type="button" role="tab" aria-controls="wifi-networks" aria-selected="true">
            <i class="bi bi-diagram-3"></i> {{ __('الشبكات الفعّالة') }}
        </button>
    </li>
    <li class="nav-item" role="presentation">
        <button class="nav-link" id="wifi-requests-tab" data-bs-toggle="pill" data-bs-target="#wifi-requests"
                type="button" role="tab" aria-controls="wifi-requests" aria-selected="false">
            <i class="bi bi-inbox"></i> {{ __('طلبات الإضافة') }}
        </button>
    </li>
    <li class="nav-item" role="presentation">
        <button class="nav-link" id="wifi-reports-tab" data-bs-toggle="pill" data-bs-target="#wifi-reports"
                type="button" role="tab" aria-controls="wifi-reports" aria-selected="false">
            <i class="bi bi-flag"></i> {{ __('البلاغات') }}
        </button>
    </li>
    <li class="nav-item" role="presentation">
        <button class="nav-link" id="wifi-batches-tab" data-bs-toggle="pill" data-bs-target="#wifi-batches"
                type="button" role="tab" aria-controls="wifi-batches" aria-selected="false">
            <i class="bi bi-stack"></i> {{ __('دفعات الأكواد') }}
        </button>
    </li>
</ul>
