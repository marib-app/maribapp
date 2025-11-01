@php
    $receiptUrl = $receiptUrl ?? $request->receipt_url;
    $receiptName = null;
    $receiptMime = null;
    $receiptSize = null;

    $rawMeta = is_array($request->meta) ? $request->meta : [];

    $resolveAttachmentUrl = static function (array $attachment): ?string {
        $candidateUrl = data_get($attachment, 'url');
        $candidatePath = data_get($attachment, 'path');
        $candidateDisk = data_get($attachment, 'disk');

        if (is_string($candidateUrl) && trim($candidateUrl) !== '') {
            return trim($candidateUrl);
        }

        if (! is_string($candidatePath) || trim($candidatePath) === '') {
            return null;
        }

        $normalizedPath = trim($candidatePath);

        if (filter_var($normalizedPath, FILTER_VALIDATE_URL)) {
            return $normalizedPath;
        }

        $diskName = is_string($candidateDisk) && trim($candidateDisk) !== ''
            ? trim($candidateDisk)
            : 'public';

        try {
            $disk = \Illuminate\Support\Facades\Storage::disk($diskName);
            $url = $disk->url($normalizedPath);

            if (is_string($url) && trim($url) !== '') {
                return trim($url);
            }
        } catch (\Throwable) {
            // Ignore storage resolution errors and continue with other candidates.
        }

        return null;
    };

    if (! $receiptUrl) {
        $attachments = data_get($rawMeta, 'attachments', []);

        if (is_array($attachments)) {
            foreach ($attachments as $attachment) {
                if (! is_array($attachment)) {
                    continue;
                }

                $candidateUrl = $resolveAttachmentUrl($attachment);

                if (! $candidateUrl) {
                    continue;
                }

                $receiptUrl = $candidateUrl;
                $receiptName = data_get($attachment, 'name');
                $receiptMime = data_get($attachment, 'mime_type');
                $receiptSize = data_get($attachment, 'size');

                break;
            }
        }
    }

    if (! $receiptUrl) {
        $receiptPath = data_get($rawMeta, 'receipt.path');

        if (is_string($receiptPath) && trim($receiptPath) !== '') {
            $receiptUrl = $resolveAttachmentUrl([
                'path' => $receiptPath,
                'disk' => data_get($rawMeta, 'receipt.disk', 'public'),
            ]);
        }
    }

    $extension = null;

    if ($receiptUrl) {
        $parsedPath = parse_url($receiptUrl, PHP_URL_PATH) ?? '';
        $extension = strtolower(pathinfo($parsedPath, PATHINFO_EXTENSION) ?: '');
    }

    $isImage = false;

    if (is_string($receiptMime) && $receiptMime !== '') {
        $isImage = \Illuminate\Support\Str::startsWith(strtolower($receiptMime), 'image/');
    }

    if (! $isImage && is_string($extension) && $extension !== '') {
        $isImage = in_array($extension, ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'svgz', 'heic', 'heif'], true);
    }

    // Fallbacks: check for base64/data URIs or raw base64 stored in meta fields, and attempt to resolve
    // storage path to public URL if earlier resolution failed.
    if (! $receiptUrl) {
        // common meta locations for embedded/base64 data
        $maybeBase64 = data_get($rawMeta, 'receipt.data')
            ?? data_get($rawMeta, 'transfer.receipt_data')
            ?? data_get($rawMeta, 'transfer_details.receipt_data')
            ?? data_get($rawMeta, 'attachments.0.data');

        if (is_string($maybeBase64) && trim($maybeBase64) !== '') {
            $maybeBase64Trim = trim($maybeBase64);

            // If already a data URI, use it directly.
            if (str_starts_with($maybeBase64Trim, 'data:')) {
                $receiptUrl = $maybeBase64Trim;
                $isImage = str_starts_with(strtolower($maybeBase64Trim), 'data:image/');
            } else {
                // Try to detect raw base64 by checking length and allowed chars (very permissive).
                $base64Candidate = preg_replace('/\s+/', '', $maybeBase64Trim);
                if (preg_match('/^[A-Za-z0-9+\/=]+$/', $base64Candidate) && strlen($base64Candidate) > 100) {
                    // assume PNG if unknown
                    $receiptUrl = 'data:image/png;base64,' . $base64Candidate;
                    $isImage = true;
                }
            }
        }
    }

    // If we have a path (not a full URL) try to build a public storage URL as a last resort.
    if ($receiptUrl && ! filter_var($receiptUrl, FILTER_VALIDATE_URL) && ! str_starts_with($receiptUrl, 'data:')) {
        try {
            // Attempt the storage url again via the public storage path helper
            $possible = url('storage/' . ltrim($receiptUrl, '/'));

            if (is_string($possible) && trim($possible) !== '') {
                $receiptUrl = $possible;
            }
        } catch (Throwable) {
            // ignore
        }
    }

    $downloadName = null;

    if (is_string($receiptName) && trim($receiptName) !== '') {
        $downloadName = trim($receiptName);
    } elseif ($extension) {
        $downloadName = 'receipt.' . $extension;
    }

    $formattedSize = null;

    if (is_numeric($receiptSize)) {
        $bytes = (float) $receiptSize;

        if ($bytes > 0) {
            $units = ['B', 'KB', 'MB', 'GB'];
            $power = min((int) floor(log($bytes, 1024)), count($units) - 1);
            $formattedSize = number_format($bytes / (1024 ** $power), $power === 0 ? 0 : 2) . ' ' . $units[$power];
        }
    }
@endphp

@if($receiptUrl)


<div class="d-flex flex-wrap gap-3 align-items-start">
        <div class="receipt-thumbnail border rounded p-3 text-center" style="min-width: 180px;">
            @if($isImage)
                <img src="{{ $receiptUrl }}" alt="{{ __('Payment receipt') }}"
                     class="img-fluid" style="max-height: 180px; cursor: pointer;"
                     data-bs-toggle="modal" data-bs-target="#manualReceiptModal-{{ $request->id }}">
            @else
                <div class="d-flex flex-column align-items-center justify-content-center" style="min-height: 120px;">
                    <i class="fa fa-file-text fa-3x text-primary mb-2"></i>
                    <div class="small text-muted">{{ $downloadName ?? __('Receipt file') }}</div>
                </div>
            @endif
        </div>
        <div class="d-flex flex-column gap-2">
            <div>
                <div class="fw-semibold">{{ $downloadName ?? __('Receipt file') }}</div>
                @if($formattedSize)
                    <div class="text-muted small">{{ $formattedSize }}</div>
                @endif
            </div>
            <a href="{{ $receiptUrl }}" class="btn btn-outline-primary" target="_blank" rel="noopener">
                
            <i class="fa fa-external-link-alt me-1"></i>{{ __('Open Receipt') }}
            </a>
            <a href="{{ $receiptUrl }}" class="btn btn-outline-secondary" @if($downloadName) download="{{ $downloadName }}" @else download @endif>
                <i class="fa fa-download me-1"></i>{{ __('Download') }}
            </a>
        </div>
    </div>

    @if($isImage)
        <div class="modal fade" id="manualReceiptModal-{{ $request->id }}" tabindex="-1" aria-hidden="true">
            <div class="modal-dialog modal-lg modal-dialog-centered">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">{{ __('Receipt Preview') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <div class="modal-body text-center">
                        <img src="{{ $receiptUrl }}" alt="{{ __('Payment receipt') }}" class="img-fluid">
                    </div>
                </div>
            </div>
        </div>
    @endif

@else
    <p class="text-muted mb-0">{{ __('No receipt uploaded for this request.') }}</p>
@endif