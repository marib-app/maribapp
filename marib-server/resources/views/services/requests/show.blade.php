{{-- resources/views/services/requests/show.blade.php --}}
@extends('layouts.main')

@section('title')
    {{ __('Service Request #:id', ['id' => $serviceRequest->id]) }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-muted mb-0">{{ __('Review the submission details and respond to the applicant.') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                <div class="d-flex flex-wrap justify-content-md-end gap-2">
                    <a href="{{ route('service.requests.index') }}" class="btn btn-outline-primary">
                        <i class="bi bi-arrow-left"></i> {{ __('Back to Requests') }}
                    </a>
                </div>
            </div>
        </div>
    </div>
@endsection

@section('content')
<section class="section">
    <div class="row g-4">
        <div class="col-12 col-xl-8">
            <div class="card mb-4">
                <div class="card-header border-bottom">
                    <h5 class="card-title mb-0">{{ __('Request Summary') }}</h5>
                </div>
                <div class="card-body">
                    @php
                        $statusMap = [
                            'review'   => ['label' => __('Under Review'), 'class' => 'badge bg-warning text-dark'],
                            'approved' => ['label' => __('Approved'), 'class' => 'badge bg-success'],
                            'rejected' => ['label' => __('Rejected'), 'class' => 'badge bg-danger'],
                            'sold out' => ['label' => __('Sold Out'), 'class' => 'badge bg-secondary'],
                        ];
                        $statusInfo = $statusMap[$serviceRequest->status] ?? [
                            'label' => \Illuminate\Support\Str::of($serviceRequest->status ?? '')->replace('_', ' ')->title(),
                            'class' => 'badge bg-secondary',
                        ];
                    @endphp
                    <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center mb-3">
                        <div>
                            <h4 class="mb-1">{{ $service->title ?? __('Service #:id', ['id' => $serviceRequest->service_id]) }}</h4>
                            <div class="small text-muted">
                                {{ __('Request ID') }}: {{ $serviceRequest->id }}
                                @if($serviceRequest->service_id)
                                    &nbsp;•&nbsp; {{ __('Service ID') }}: {{ $serviceRequest->service_id }}
                                @endif
                            </div>
                            @if($category)
                                <div class="small text-muted mt-1">
                                    {{ __('Category') }}: {{ $category->name }}
                                    @if($category->id)
                                        <span class="text-muted">(ID: {{ $category->id }})</span>
                                    @endif
                                </div>
                            @endif
                        </div>
                        <div class="text-md-end">
                            <span class="{{ $statusInfo['class'] }}">{{ $statusInfo['label'] }}</span>
                            @if($serviceRequest->trashed())
                                <span class="badge bg-dark ms-1">{{ __('Archived') }}</span>
                            @endif
                        </div>
                    </div>

                    <div class="row g-3">
                        <div class="col-md-6">
                            <label class="form-label fw-semibold text-muted">{{ __('Created At') }}</label>
                            <div>{{ optional($serviceRequest->created_at)->format('Y-m-d H:i') ?? '—' }}</div>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label fw-semibold text-muted">{{ __('Last Updated') }}</label>
                            <div>{{ optional($serviceRequest->updated_at)->format('Y-m-d H:i') ?? '—' }}</div>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label fw-semibold text-muted">{{ __('Payment Status') }}</label>
                            <div>{{ $serviceRequest->payment_status ? __($serviceRequest->payment_status) : __('Not provided') }}</div>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label fw-semibold text-muted">{{ __('Transaction') }}</label>
                            <div>
                                @if($serviceRequest->payment_transaction_id)
                                    #{{ $serviceRequest->payment_transaction_id }}
                                    <div class="mt-2">
                                        <a href="{{ route('service.requests.review', $serviceRequest) }}" class="btn btn-sm btn-outline-primary">
                                            <i class="bi bi-receipt"></i> {{ __('Review Payment') }}
                                        </a>
                                    </div>
                                @else
                                    <span class="text-muted">—</span>
                                @endif
                            </div>
                        </div>
                    </div>

                    @if($serviceRequest->note)
                        <hr>
                        <div>
                            <label class="form-label fw-semibold text-muted">{{ __('Applicant Note') }}</label>
                            <div class="text-wrap">{!! nl2br(e($serviceRequest->note)) !!}</div>
                        </div>
                    @endif

                    @if($serviceRequest->rejected_reason)
                        <hr>
                        <div>
                            <label class="form-label fw-semibold text-muted text-danger">{{ __('Rejected Reason') }}</label>
                            <div class="text-wrap text-danger">{!! nl2br(e($serviceRequest->rejected_reason)) !!}</div>
                        </div>
                    @endif
                </div>
            </div>

            <div class="card mb-4">
                <div class="card-header border-bottom">
                    <h5 class="card-title mb-0">{{ __('Filled Fields') }}</h5>
                </div>
                <div class="card-body">
                    @if(!empty($payloadEntries))
                        <div class="table-responsive">
                            <table class="table table-sm table-bordered align-middle mb-0">
                                <thead class="table-light">
                                    <tr>
                                        <th style="width: 30%">{{ __('Field') }}</th>
                                        <th>{{ __('Value') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @foreach($payloadEntries as $entry)
                                        <tr>
                                            <th scope="row">
                                                <div>{{ $entry['label'] }}</div>
                                                @if(!empty($entry['note']))
                                                    <div class="small text-muted mt-1">{{ $entry['note'] }}</div>
                                                @endif
                                            </th>
                                            <td>
                                                @if($entry['is_file'] && $entry['file_url'])
                                                    <a href="{{ $entry['file_url'] }}" class="btn btn-sm btn-outline-primary" target="_blank" rel="noopener">
                                                        <i class="bi bi-box-arrow-up-right"></i> {{ $entry['file_name'] ?? $entry['display'] }}
                                                    </a>
                                                    @if(!empty($entry['display']) && $entry['file_name'] !== $entry['display'])
                                                        <div class="small text-muted mt-1">{{ $entry['display'] }}</div>
                                                    @endif
                                                @elseif(!empty($entry['value_list']) && count($entry['value_list']) > 1)
                                                    <ul class="list-unstyled mb-0">
                                                        @foreach($entry['value_list'] as $value)
                                                            <li><i class="bi bi-check2"></i> {{ $value }}</li>
                                                        @endforeach
                                                    </ul>
                                                @else
                                                    <div>{!! nl2br(e($entry['display'] ?? '-')) !!}</div>
                                                    @if(!empty($entry['value_list']) && count($entry['value_list']) === 1)
                                                        <div class="small text-muted mt-1">{{ $entry['value_list'][0] }}</div>
                                                    @endif
                                                @endif
                                            </td>
                                        </tr>
                                    @endforeach
                                </tbody>
                            </table>
                        </div>
                    @else
                        <div class="text-muted">{{ __('No custom fields were submitted for this request.') }}</div>
                    @endif
                </div>
            </div>

            <div class="card">
                <div class="card-header border-bottom">
                    <h5 class="card-title mb-0">{{ __('Attachments') }}</h5>
                </div>
                <div class="card-body">
                    @if(!empty($attachmentEntries))
                        <ul class="list-group list-group-flush">
                            @foreach($attachmentEntries as $attachment)
                                <li class="list-group-item d-flex justify-content-between align-items-start gap-3">
                                    <div>
                                        <div class="fw-semibold">{{ $attachment['label'] }}</div>
                                        @if(!empty($attachment['note']))
                                            <div class="small text-muted">{{ $attachment['note'] }}</div>
                                        @endif
                                    </div>
                                    @if(!empty($attachment['file_url']))
                                        <a href="{{ $attachment['file_url'] }}" class="btn btn-sm btn-outline-primary" target="_blank" rel="noopener">
                                            <i class="bi bi-download"></i> {{ $attachment['file_name'] ?? __('Download') }}
                                        </a>
                                    @else
                                        <span class="badge bg-light text-muted">{{ __('Unavailable') }}</span>
                                    @endif
                                </li>
                            @endforeach
                        </ul>
                    @else
                        <div class="text-muted">{{ __('No files were uploaded for this request.') }}</div>
                    @endif
                </div>
            </div>
        </div>

        <div class="col-12 col-xl-4">
            <div class="card mb-4">
                <div class="card-header border-bottom">
                    <h5 class="card-title mb-0">{{ __('Applicant') }}</h5>
                </div>
                <div class="card-body">
                    @if($applicant)
                        <div class="d-flex align-items-center gap-3 mb-3">
                            @if($applicant->profile)
                                <img src="{{ $applicant->profile }}" alt="{{ $applicant->name }}" class="rounded-circle" style="width:64px;height:64px;object-fit:cover;">
                            @else
                                <div class="rounded-circle bg-light d-flex align-items-center justify-content-center" style="width:64px;height:64px;">
                                    <i class="bi bi-person text-muted fs-3"></i>
                                </div>
                            @endif
                            <div>
                                <div class="fw-semibold">{{ $applicant->name }}</div>
                                <div class="small text-muted">{{ __('User ID') }}: {{ $applicant->id }}</div>
                            </div>
                        </div>
                        <dl class="row mb-0">
                            @if($applicant->email)
                                <dt class="col-5 text-muted">{{ __('Email') }}</dt>
                                <dd class="col-7">{{ $applicant->email }}</dd>
                            @endif
                            @if($applicant->mobile)
                                <dt class="col-5 text-muted">{{ __('Mobile') }}</dt>
                                <dd class="col-7">{{ $applicant->mobile }}</dd>
                            @endif
                            <dt class="col-5 text-muted">{{ __('Account Type') }}</dt>
                            <dd class="col-7">{{ method_exists($applicant, 'getAccountTypeName') ? $applicant->getAccountTypeName() : __('Customer') }}</dd>
                            <dt class="col-5 text-muted">{{ __('Status') }}</dt>
                            <dd class="col-7">
                                @if($applicant->is_verified)
                                    <span class="badge bg-success">{{ __('Verified') }}</span>
                                @else
                                    <span class="badge bg-secondary">{{ __('Pending Verification') }}</span>
                                @endif
                            </dd>
                        </dl>
                    @else
                        <div class="text-muted">{{ __('The applicant account is no longer available.') }}</div>
                    @endif
                </div>
            </div>

            @can('service-requests-update')
            <div class="card">
                <div class="card-header border-bottom">
                    <h5 class="card-title mb-0">{{ __('Update Status') }}</h5>
                </div>
                <div class="card-body">
                    <form method="POST" action="{{ route('service.requests.approval', $serviceRequest->id) }}">
                        @csrf
                        <div class="mb-3">
                            <label for="rejected_reason" class="form-label">{{ __('Internal Note / Rejection Reason') }}</label>
                            <textarea name="rejected_reason" id="rejected_reason" class="form-control" rows="3" placeholder="{{ __('Explain the decision when rejecting the request.') }}"></textarea>
                            <div class="form-text">{{ __('This note will only be stored when the request is rejected.') }}</div>
                        </div>
                        <div class="d-flex gap-2">
                            <button type="submit" name="status" value="approved" class="btn btn-success flex-grow-1">
                                <i class="bi bi-check-circle"></i> {{ __('Approve') }}
                            </button>
                            <button type="submit" name="status" value="rejected" class="btn btn-danger flex-grow-1">
                                <i class="bi bi-x-circle"></i> {{ __('Reject') }}
                            </button>
                        </div>
                    </form>
                </div>
            </div>
            @endcan
        </div>
    </div>
</section>
@endsection
