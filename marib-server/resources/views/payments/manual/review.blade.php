@extends('layouts.main')

@php
    use App\Models\ManualPaymentRequest;
    $statusBadge = match ($request->status) {
        ManualPaymentRequest::STATUS_APPROVED => '<span class="badge bg-success">' . __('Approved') . '</span>',
        ManualPaymentRequest::STATUS_REJECTED => '<span class="badge bg-danger">' . __('Rejected') . '</span>',
        default => '<span class="badge bg-warning text-dark">' . __('Pending') . '</span>',
    };
@endphp

@section('title')
    {{ __('Payment Request Review') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted mb-0">{{ __('Inspect the request details and decide whether to approve or reject the payment.') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                <nav aria-label="breadcrumb" class="breadcrumb-header float-end float-lg-end">
                    <ol class="breadcrumb mb-0">
                        <li class="breadcrumb-item">
                            <a href="{{ route('payment-requests.index') }}" class="btn btn-outline-primary">
                                <i class="bi bi-arrow-left"></i> {{ __('Back to Requests') }}
                            </a>
                        </li>
                        <li class="breadcrumb-item">
                            <span class="badge bg-light text-dark border">{{ __('Request #:id', ['id' => $request->id]) }}</span>
                        </li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card shadow-sm">
            <div class="card-header bg-white d-flex flex-wrap justify-content-between align-items-start gap-3">
                <div>
                    <h5 class="card-title mb-1">{{ $request->reference ?? __('Payment Request #:id', ['id' => $request->id]) }}</h5>
                    <div class="text-muted small">
                        {{ __('Submitted :date', ['date' => $request->created_at?->format('Y-m-d H:i') ?? __('N/A')]) }}
                        @if($request->user)
                            &bull; {{ __('By :name', ['name' => $request->user->name]) }}
                        @endif
                    </div>
                </div>
                <div class="text-end">
                    {!! $statusBadge !!}
                    <div class="mt-2 fw-semibold">{{ number_format($request->amount, 2) }} {{ $request->currency }}</div>
                </div>
            </div>
            <div class="card-body">
                @include('payments.manual.show', [
                    'request' => $request,
                    'canReview' => $canReview,
                    'timelineData' => $timelineData ?? [],

                    'paymentGatewayKey' => $paymentGatewayKey ?? null,
                    'paymentGatewayCanonical' => $paymentGatewayCanonical ?? null,
                    'paymentGatewayLabel' => $paymentGatewayLabel ?? null,
                    'departmentLabel' => $departmentLabel ?? null,
                    'readOnly' => false,

                ])
            
            </div>
        </div>





        @can('manual-payments-review')
            <div class="card shadow-sm mt-4">
                <div class="card-header bg-light d-flex justify-content-between align-items-center">
                    <h6 class="mb-0"><i class="fa fa-paper-plane me-2"></i>{{ __('Notify Requester') }}</h6>
                    <small class="text-muted">{{ __('Send a push message without changing the request status.') }}</small>
                </div>
                <div class="card-body">
                    <form id="manual-payment-notification-form" action="{{ route('payment-requests.notify', $request) }}" method="post" class="d-grid gap-3">
                        @csrf
                        <div>
                            <label for="manual-payment-message" class="form-label fw-semibold">{{ __('Message to requester') }}</label>
                            <textarea id="manual-payment-message" name="message" class="form-control" rows="3" maxlength="500" placeholder="{{ __('Provide a brief update for the requester') }}" required></textarea>
                            <div class="form-text">{{ __('Maximum 500 characters.') }}</div>
                        </div>
                        <div class="text-end">
                            <button type="submit" class="btn btn-primary">
                                <i class="fa fa-paper-plane me-1"></i>{{ __('Send notification') }}
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        @endcan




    </section>
@endsection

@push('scripts')
    <script>
        $(document).on('submit', '.manual-payment-action', function (event) {
            event.preventDefault();

            const form = $(this);
            const submitButton = form.find('button[type="submit"]');
            const url = form.attr('action');
            const formData = new FormData(this);
            const shouldReload = form.data('reload-on-success') === true || form.data('reload-on-success') === 'true';

            ajaxRequest('POST', url, formData, function () {
                submitButton.prop('disabled', true).addClass('disabled');
            }, function (response) {
                showSuccessToast(response.message);

                if (shouldReload) {
                    setTimeout(function () {
                        window.location.reload();
                    }, 600);
                }
            }, function (error) {
                showErrorToast(error.message || '{{ __('Something went wrong') }}');
            }, function () {
                if (!shouldReload) {
                    submitButton.prop('disabled', false).removeClass('disabled');
                }
            });
        });
    </script>
@endpush