@extends('layouts.main')

@section('title', __('حوالة #:id', ['id' => $manualPaymentRequest->id]))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('مراجعة بيانات الحوالة واتخاذ القرار المناسب.') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end gap-2 flex-wrap">
                <a href="{{ route('merchant.manual-payments.index') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i>
                    {{ __('عودة للحوالات') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-12 col-lg-7">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('معلومات الحوالة') }}</h6>
                    </div>
                    <div class="card-body">
                        <dl class="row">
                            <dt class="col-sm-4">{{ __('العميل') }}</dt>
                            <dd class="col-sm-8">{{ $manualPaymentRequest->user?->name ?? __('مستخدم') }}</dd>

                            <dt class="col-sm-4">{{ __('المبلغ') }}</dt>
                            <dd class="col-sm-8">
                                {{ number_format($manualPaymentRequest->amount ?? 0, 2) }}
                                {{ $manualPaymentRequest->currency ?? 'ر.ي' }}
                            </dd>

                            <dt class="col-sm-4">{{ __('الحالة') }}</dt>
                            <dd class="col-sm-8">
                                <span class="badge bg-{{ $manualPaymentRequest->status === 'approved' ? 'success' : ($manualPaymentRequest->status === 'rejected' ? 'danger' : 'warning') }}">
                                    {{ __($manualPaymentRequest->status) }}
                                </span>
                            </dd>

                            <dt class="col-sm-4">{{ __('المرجع') }}</dt>
                            <dd class="col-sm-8">{{ $manualPaymentRequest->reference ?? '-' }}</dd>

                            <dt class="col-sm-4">{{ __('البنك') }}</dt>
                            <dd class="col-sm-8">{{ $manualPaymentRequest->manualBank?->name ?? __('تحويل يدوي') }}</dd>

                            <dt class="col-sm-4">{{ __('أنشئت في') }}</dt>
                            <dd class="col-sm-8">{{ optional($manualPaymentRequest->created_at)->format('Y-m-d H:i') }}</dd>
                        </dl>
                    </div>
                </div>

                <div class="card mt-3">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('مرفقات/ملاحظات') }}</h6>
                    </div>
                    <div class="card-body">
                        @if ($manualPaymentRequest->receipt_path)
                            <p class="mb-2">
                                <a href="{{ Storage::disk('public')->url($manualPaymentRequest->receipt_path) }}" target="_blank">
                                    {{ __('مشاهدة إيصال التحويل') }}
                                </a>
                            </p>
                        @endif
                        <p class="mb-0 text-muted">{{ $manualPaymentRequest->user_note ?: __('لا توجد ملاحظات من العميل.') }}</p>
                    </div>
                </div>
            </div>

            <div class="col-12 col-lg-5">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('قرار التاجر') }}</h6>
                    </div>
                    <div class="card-body">
                        @if ($canDecide)
                            <form method="post" action="{{ route('merchant.manual-payments.decide', $manualPaymentRequest) }}">
                                @csrf
                                <div class="mb-3">
                                    <label class="form-label">{{ __('إجراء') }}</label>
                                    <select name="decision" class="form-select">
                                        <option value="{{ \App\Models\ManualPaymentRequest::STATUS_APPROVED }}">{{ __('قبول الحوالة') }}</option>
                                        <option value="{{ \App\Models\ManualPaymentRequest::STATUS_REJECTED }}">{{ __('رفض الحوالة') }}</option>
                                    </select>
                                </div>
                                <div class="mb-3">
                                    <label class="form-label">{{ __('ملاحظة (اختياري)') }}</label>
                                    <textarea name="note" class="form-control" rows="3"></textarea>
                                </div>
                                <div class="form-check mb-3">
                                    <input class="form-check-input" type="checkbox" name="notify_customer" value="1" id="notifyCustomerCheck" checked>
                                    <label class="form-check-label" for="notifyCustomerCheck">
                                        {{ __('إرسال إشعار للعميل') }}
                                    </label>
                                </div>
                                <button type="submit" class="btn btn-primary w-100">
                                    {{ __('تنفيذ الإجراء') }}
                                </button>
                            </form>
                        @else
                            <p class="text-muted mb-0">{{ __('تمت معالجة هذه الحوالة مسبقاً.') }}</p>
                        @endif
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
