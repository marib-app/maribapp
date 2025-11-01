@extends('layouts.main')

@php
    use App\Models\ManualPaymentRequest;
    $statusBadge = match ($request->status) {
        ManualPaymentRequest::STATUS_APPROVED => '<span class="badge bg-success">' . __('Approved') . '</span>',
        ManualPaymentRequest::STATUS_REJECTED => '<span class="badge bg-danger">' . __('Rejected') . '</span>',
        default => '<span class="badge bg-warning text-dark">' . __('Pending') . '</span>',
    };
    $receiptDisplay = $transaction->receipt_no ?? ('PT-' . $transaction->id);
    $transactionBreadcrumb = __('Transaction #:id', ['id' => $receiptDisplay]);
    $transactionTitle = $request->reference ?? __('Payment Transaction #:id', ['id' => $receiptDisplay]);
    
@endphp

@section('title')
    {{ __('Payment Transaction Review') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted mb-0">{{ __('Inspect the transaction details captured from the payment record.') }}</p>
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
                            <span class="badge bg-light text-dark border">{{ $transactionBreadcrumb }}</span>
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
                    <h5 class="card-title mb-1">{{ $transactionTitle }}</h5>
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
                    'canReview' => false,
                    'timelineData' => [],
                    'paymentGatewayKey' => $paymentGatewayKey ?? null,
                    'paymentGatewayCanonical' => $paymentGatewayCanonical ?? null,
                    'paymentGatewayLabel' => $paymentGatewayLabel ?? null,
                    'departmentLabel' => $departmentLabel ?? null,
                    'readOnly' => true,
                ])
            </div>
        </div>
    </section>
@endsection