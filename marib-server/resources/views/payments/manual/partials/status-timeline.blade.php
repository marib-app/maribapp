@php
    $timelineData = $timelineData ?? [];
    $timelineEndpoint = $timelineEndpoint ?? null;
    $pollInterval = $timelineData['poll_interval'] ?? 8000;
    $initialState = json_encode($timelineData, JSON_THROW_ON_ERROR);
@endphp

<div class="card shadow-sm mt-4">
    <div class="card-header bg-light d-flex justify-content-between align-items-center">
        <h6 class="mb-0">
            <i class="fa fa-timeline me-2"></i>{{ __('Status timeline') }}
        </h6>
        <small class="text-muted">{{ __('Timeline updates automatically.') }}</small>
    </div>
    <div class="card-body">
        <div
            class="manual-payment-status-timeline"
            data-manual-payment-timeline
            data-timeline-endpoint="{{ $timelineEndpoint }}"
            data-endpoint="{{ $timelineEndpoint }}"
            data-poll-interval="{{ $pollInterval }}"
            data-initial-state='{{ $initialState }}'
            data-error-message="{{ $timelineData['error_message'] ?? __('Unable to refresh the status timeline right now.') }}"
        >
            <div class="manual-payment-timeline-summary">
                <div class="manual-payment-timeline-current">
                    <span class="badge {{ $timelineData['current_status_badge'] ?? 'bg-secondary' }}" data-timeline-current-badge>
                        <i class="{{ $timelineData['current_status_icon'] ?? 'fa-solid fa-hourglass-half' }}" data-timeline-current-icon aria-hidden="true"></i>
                        <span data-timeline-current-label>{{ $timelineData['current_status_label'] ?? __('Pending') }}</span>
                    </span>
                    <span class="manual-payment-timeline-updated" data-timeline-updated data-prefix="{{ __('Updated') }}: ">
                        @if(!empty($timelineData['last_updated_at_human']))
                            {{ __('Updated') }}: {{ $timelineData['last_updated_at_human'] }}
                        @endif
                    </span>
                </div>
                <div class="manual-payment-timeline-caption">
                    {{ __('Timeline updates automatically.') }}
                </div>
            </div>

            <div class="manual-payment-timeline-feedback" data-timeline-feedback></div>

            <div class="manual-payment-timeline-items" data-timeline-items>
                @forelse($timelineData['timeline'] ?? [] as $entry)
                    <div class="manual-payment-timeline-entry {{ !empty($entry['is_current']) ? 'is-current' : '' }}">
                        <div class="manual-payment-timeline-marker">
                            <i class="{{ $entry['icon'] ?? 'fa-solid fa-circle text-secondary' }}" aria-hidden="true"></i>
                        </div>
                        <div class="manual-payment-timeline-content">
                            <div class="manual-payment-timeline-header">
                                <div class="manual-payment-timeline-title">{{ $entry['status_label'] ?? $entry['status'] ?? __('Pending') }}</div>
                                <div class="manual-payment-timeline-meta">
                                    {{ collect([$entry['actor'] ?? null, $entry['created_at_human'] ?? null])->filter()->implode(' • ') }}
                                </div>
                            </div>
                            @if(!empty($entry['note']))
                                <p class="manual-payment-timeline-note mb-0">{{ $entry['note'] }}</p>
                            @endif
                            @if(!empty($entry['attachment_url']))
                                <div class="manual-payment-timeline-attachment mt-2">
                                    <a href="{{ $entry['attachment_url'] }}" target="_blank" rel="noopener" class="btn btn-sm btn-outline-secondary">
                                        <i class="fa-solid fa-paperclip me-1" aria-hidden="true"></i>
                                        {{ $entry['attachment_label'] ?? $entry['attachment_name'] ?? __('View attachment') }}
                                    </a>
                                </div>
                            @endif
                            @if(!empty($entry['notification_sent']))
                                <div class="manual-payment-timeline-notification text-muted small mt-2">
                                    <i class="fa-solid fa-bell me-1" aria-hidden="true"></i>
                                    {{ $entry['notification_label'] ?? __('Notification sent') }}
                                </div>
                            @endif
                            @if(!empty($entry['document_valid_until_human']))
                                <div class="manual-payment-timeline-document">
                                    <i class="fa-solid fa-id-card-clip" aria-hidden="true"></i>
                                    <span>{{ $entry['document_valid_label'] ?? $entry['document_valid_until_human'] }}</span>
                                </div>
                            @endif
                        </div>
                    </div>
                @empty
                    <p class="text-muted mb-0">{{ $timelineData['empty_message'] ?? __('No status updates yet.') }}</p>
                @endforelse
            </div>
        </div>
    </div>
</div>