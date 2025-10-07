@if($request->receipt_url)
    <div class="d-flex flex-wrap gap-3 align-items-start">
        <div class="receipt-thumbnail border rounded p-2">
            <img src="{{ $request->receipt_url }}" alt="{{ __('Payment receipt') }}"
                 class="img-fluid" style="max-height: 160px; cursor: pointer;"
                 data-bs-toggle="modal" data-bs-target="#manualReceiptModal-{{ $request->id }}">
        </div>
        <div class="d-flex flex-column gap-2">
            <a href="{{ $request->receipt_url }}" class="btn btn-outline-primary" target="_blank" rel="noopener">
                <i class="fa fa-external-link-alt me-1"></i>{{ __('Open Receipt') }}
            </a>
            <a href="{{ $request->receipt_url }}" class="btn btn-outline-secondary" download>
                <i class="fa fa-download me-1"></i>{{ __('Download') }}
            </a>
        </div>
    </div>

    <div class="modal fade" id="manualReceiptModal-{{ $request->id }}" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-lg modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">{{ __('Receipt Preview') }}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body text-center">
                    <img src="{{ $request->receipt_url }}" alt="{{ __('Payment receipt') }}" class="img-fluid">
                </div>
            </div>
        </div>
    </div>
@else
    <p class="text-muted mb-0">{{ __('No receipt uploaded for this request.') }}</p>
@endif