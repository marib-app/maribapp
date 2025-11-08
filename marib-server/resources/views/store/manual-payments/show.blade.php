@extends('layouts.main')

@section('title', __('حوالة #:id', ['id' => $manualPaymentRequest->id]))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('مراجعة كاملة للتحويل البنكي واتخاذ القرار قبل تفعيل الطلب.') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end gap-2 flex-wrap">
                <a href="{{ route('merchant.manual-payments.index') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i>
                    {{ __('العودة للقائمة') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    @php
        $meta = is_array($manualPaymentRequest->meta) ? $manualPaymentRequest->meta : [];
        $transferDetails = $transferDetails ?? [];
        $senderName = $transferDetails['sender_name'] ?? data_get($meta, 'transfer_details.sender_name');
        $transferReference = $transferDetails['transfer_reference']
            ?? data_get($meta, 'transfer_details.transfer_reference')
            ?? $manualPaymentRequest->reference;
        $transferNote = $transferDetails['note'] ?? data_get($meta, 'transfer_details.note');
        $transferSource = $transferDetails['source'] ?? data_get($meta, 'transfer_details.source');
        $receiptUrl = $manualPaymentRequest->receipt_path
            ? Storage::disk('public')->url($manualPaymentRequest->receipt_path)
            : ($transferDetails['receipt_url'] ?? data_get($meta, 'receipt_url'));

        if (! $receiptUrl && isset($transferDetails['receipt_path'])) {
            $receiptUrl = Storage::disk('public')->url($transferDetails['receipt_path']);
        }

        $customerContact = collect([
            $manualPaymentRequest->user?->mobile,
            $manualPaymentRequest->user?->email,
        ])->filter()->implode(' · ');

        $bankName = $manualPaymentRequest->manualBank?->name
            ?? $manualPaymentRequest->bank_name
            ?? data_get($meta, 'manual.bank.name')
            ?? data_get($meta, 'manual_bank.name');
        $bankBeneficiary = $manualPaymentRequest->bank_account_name
            ?? $manualPaymentRequest->manualBank?->beneficiary_name
            ?? data_get($meta, 'manual.bank.beneficiary_name');
        $bankAccountNumber = $manualPaymentRequest->bank_account_number
            ?? data_get($meta, 'manual.bank.account_number')
            ?? data_get($meta, 'manual_bank.account_number');
        $bankIban = $manualPaymentRequest->bank_iban ?? data_get($meta, 'manual.bank.iban');
        $bankSwift = $manualPaymentRequest->bank_swift_code ?? data_get($meta, 'manual.bank.swift_code');
        $statusColor = $manualPaymentRequest->status === \App\Models\ManualPaymentRequest::STATUS_APPROVED
            ? 'success'
            : ($manualPaymentRequest->status === \App\Models\ManualPaymentRequest::STATUS_REJECTED ? 'danger' : 'warning');
    @endphp

    <section class="section">
        <div class="row">
            <div class="col-12 col-lg-7">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('ظ…ظ„ط®طµ ط§ظ„ط­ط§ظ„ط©') }}</h6>
                    </div>
                    <div class="card-body">
                        <dl class="row">
                            <dt class="col-sm-4">{{ __('ط§ظ„ط¹ظ…ظٹظ„') }}</dt>
                            <dd class="col-sm-8">
                                {{ $manualPaymentRequest->user?->name ?? __('ظ…ط³طھط®ط¯ظ…') }}
                                @if ($customerContact !== '')
                                    <br><small class="text-muted">{{ $customerContact }}</small>
                                @endif
                            </dd>

                            <dt class="col-sm-4">{{ __('ط§ظ„ظ…طھط¬ط±') }}</dt>
                            <dd class="col-sm-8">{{ $store->name }}</dd>

                            <dt class="col-sm-4">{{ __('ط§ظ„ظ…ط¨ظ„ط؛') }}</dt>
                            <dd class="col-sm-8">
                                {{ number_format($manualPaymentRequest->amount ?? 0, 2) }}
                                {{ $manualPaymentRequest->currency ?? 'ط±.ظٹ' }}
                            </dd>

                            <dt class="col-sm-4">{{ __('ط§ظ„ط­ط§ظ„ط©') }}</dt>
                            <dd class="col-sm-8">
                                <span class="badge bg-{{ $statusColor }}">
                                    {{ __($manualPaymentRequest->status) }}
                                </span>
                            </dd>

                            <dt class="col-sm-4">{{ __('ط±ظ‚ظ… ط§ظ„طھط£ظƒظٹط¯') }}</dt>
                            <dd class="col-sm-8">#{{ $manualPaymentRequest->id }}</dd>

                            <dt class="col-sm-4">{{ __('ط§ظ„ظ…ط±ط¬ط¹') }}</dt>
                            <dd class="col-sm-8">{{ $transferReference ?? '--' }}</dd>

                            <dt class="col-sm-4">{{ __('ط§ظ„ظ…ط¹ط§ظ…ظ„ط©') }}</dt>
                            <dd class="col-sm-8">{{ optional($manualPaymentRequest->created_at)->format('Y-m-d H:i') }}</dd>

                            <dt class="col-sm-4">{{ __('ط§ظ„ظ…ط¹ط§ظ…ظ„ط© ط§ظ„طھط¬ط§ط±ظٹط©') }}</dt>
                            <dd class="col-sm-8">
                                @if ($manualPaymentRequest->paymentTransaction)
                                    #{{ $manualPaymentRequest->paymentTransaction->id }}
                                @else
                                    --
                                @endif
                            </dd>
                        </dl>
                    </div>
                </div>

                <div class="card mt-3">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('طھظپط§طµظٹظ„ ط§ظ„طھط­ظˆظٹظ„') }}</h6>
                    </div>
                    <div class="card-body">
                        <dl class="row">
                            <dt class="col-sm-4">{{ __('ط§ط³ظ… ط§ظ„ظ…ظˆط¯ط¹') }}</dt>
                            <dd class="col-sm-8">{{ $senderName ?? '--' }}</dd>

                            <dt class="col-sm-4">{{ __('ط±ظ‚ظ… ط§ظ„ط¹ظ…ظ„ظٹط©') }}</dt>
                            <dd class="col-sm-8">{{ $transferReference ?? '--' }}</dd>

                            <dt class="col-sm-4">{{ __('ظ…طµط¯ط± ط§ظ„طھط­ظˆظٹظ„') }}</dt>
                            <dd class="col-sm-8">{{ $transferSource ?? __('ط§ظ„ط§طھطµط§ظ„ ط§ظ„ظٹط¯ظˆظٹ') }}</dd>

                            <dt class="col-sm-4">{{ __('ظ…ظ„ط§ط­ط¸ط© ط§ظ„ط¹ظ…ظٹظ„') }}</dt>
                            <dd class="col-sm-8">{{ $manualPaymentRequest->user_note ?: __('ظ„ط§ ظٹظˆط¬ط¯ ط§ظٹ ظ†طµ ظ…ط¶ط§ظپ.') }}</dd>

                            <dt class="col-sm-4">{{ __('ظ…ظ„ط§ط­ط¸ط© ط§ظ„طھط­ظˆظٹظ„') }}</dt>
                            <dd class="col-sm-8">{{ $transferNote ?? '--' }}</dd>
                        </dl>

                        @if ($receiptUrl)
                            <a href="{{ $receiptUrl }}" class="btn btn-outline-primary btn-sm" target="_blank">
                                <i class="bi bi-receipt"></i>
                                {{ __('ظ…ط´ط§ظ‡ط¯ط© ط¥ظٹطµط§ظ„ ط§ظ„طھط­ظˆظٹظ„') }}
                            </a>
                        @endif
                    </div>
                </div>

                <div class="card mt-3">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('ط¨ظٹط§ظ†ط§طھ ط§ظ„ط­ط³ط§ط¨') }}</h6>
                    </div>
                    <div class="card-body">
                        <dl class="row">
                            <dt class="col-sm-4">{{ __('ط§ظ„ظˆط³ظٹظ„ط©') }}</dt>
                            <dd class="col-sm-8">{{ $bankName ?? __('طھط­ظˆظٹظ„ ط¨ظ†ظƒظٹ') }}</dd>

                            <dt class="col-sm-4">{{ __('طµط§ط­ط¨ ط§ظ„ط­ط³ط§ط¨') }}</dt>
                            <dd class="col-sm-8">{{ $bankBeneficiary ?? '--' }}</dd>

                            <dt class="col-sm-4">{{ __('ط±ظ‚ظ… ط§ظ„ط­ط³ط§ط¨') }}</dt>
                            <dd class="col-sm-8">{{ $bankAccountNumber ?? '--' }}</dd>

                            <dt class="col-sm-4">{{ __('IBAN') }}</dt>
                            <dd class="col-sm-8">{{ $bankIban ?? '--' }}</dd>

                            <dt class="col-sm-4">{{ __('SWIFT/BIC') }}</dt>
                            <dd class="col-sm-8">{{ $bankSwift ?? '--' }}</dd>
                        </dl>
                    </div>
                </div>

                @if ($relatedOrder)
                    <div class="card mt-3">
                        <div class="card-header d-flex justify-content-between align-items-center">
                            <h6 class="mb-0">{{ __('ط§ظ„ط·ظ„ط¨ ط§ظ„ظ…ط±طھط¨ط·') }}</h6>
                            <a href="{{ route('merchant.orders.show', $relatedOrder) }}" class="btn btn-sm btn-outline-secondary">
                                {{ __('ط¹ط±ط¶ ط§ظ„ط·ظ„ط¨') }}
                            </a>
                        </div>
                        <div class="card-body">
                            <dl class="row">
                                <dt class="col-sm-4">{{ __('ط±ظ‚ظ… ط§ظ„ط·ظ„ط¨') }}</dt>
                                <dd class="col-sm-8">#{{ $relatedOrder->order_number ?? $relatedOrder->id }}</dd>

                                <dt class="col-sm-4">{{ __('ط­ط§ظ„ط© ط§ظ„ط·ظ„ط¨') }}</dt>
                                <dd class="col-sm-8">{{ __($relatedOrder->order_status) }}</dd>

                                <dt class="col-sm-4">{{ __('ط­ط§ظ„ط© ط§ظ„ط¯ظپط¹') }}</dt>
                                <dd class="col-sm-8">{{ __($relatedOrder->payment_status ?? 'pending') }}</dd>

                                <dt class="col-sm-4">{{ __('ط§ظ„ظ…ط¨ظ„ط؛') }}</dt>
                                <dd class="col-sm-8">{{ number_format($relatedOrder->final_amount, 2) }} {{ __('ط±.ظٹ') }}</dd>
                            </dl>
                        </div>
                    </div>
                @endif
            </div>

            <div class="col-12 col-lg-5">
                <div class="card">
                    <div class="card-header">
                        <div>
                            <h6 class="mb-0">{{ __('إجراء التأكيد') }}</h6>
                            <small class="text-muted">{{ __('استخدم هذا النموذج لقبول أو رفض الحوالة بعد مراجعة البيانات.') }}</small>
                        </div>
                    </div>
                    <div class="card-body">
                        @if ($canDecide)
                            <form method="post" action="{{ route('merchant.manual-payments.decide', $manualPaymentRequest) }}" enctype="multipart/form-data">
                                @csrf
                                <div class="mb-3">
                                    <label class="form-label">{{ __('اختيار القرار') }}</label>
                                    <select name="decision" class="form-select">
                                        <option value="{{ \App\Models\ManualPaymentRequest::STATUS_APPROVED }}">{{ __('طھط£ظƒظٹط¯ ط§ظ„ط¯ظپط¹') }}</option>
                                        <option value="{{ \App\Models\ManualPaymentRequest::STATUS_REJECTED }}">{{ __('ط±ظپط¶ ط§ظ„ط¯ظپط¹') }}</option>
                                    </select>
                                </div>
                                <div class="mb-3">
                                    <label class="form-label d-flex justify-content-between">
                                        <span>{{ __('ملاحظة التاجر') }}</span>
                                        <small class="text-muted">{{ __('تظهر للعميل عند الرفض أو القبول الاختياري.') }}</small>
                                    </label>
                                    <textarea name="note" class="form-control @error('note') is-invalid @enderror" rows="3" placeholder="{{ __('ط£ط¶ظپ طھظپط§طµظٹظ„ ط§ظ„ظ…ط±ط¬ط¹ ط£ظˆ ط³ط¨ط¨ ط§ظ„ط±ظپط¶') }}"></textarea>
                                    @error('note')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="mb-3">
                                    <label class="form-label">{{ __('إرفاق المستندات') }}</label>
                                    <input type="file" name="attachment" class="form-control @error('attachment') is-invalid @enderror" accept=".jpg,.jpeg,.png,.pdf">
                                    <small class="text-muted d-block mt-1">{{ __('ط­ط¯ ط§ظ„ط*ط¬ظ… ط§ظ„ط£ظ‚طµظ‰ 5ظ…ط¨ (PDF/PNG/JPG)') }}</small>
                                    @error('attachment')
                                        <div class="invalid-feedback d-block">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="form-check mb-3">
                                    <input class="form-check-input" type="checkbox" name="notify_customer" value="1" id="notifyCustomerCheck" checked>
                                    <label class="form-check-label" for="notifyCustomerCheck">
                                        {{ __('إرسال إشعار للزبون') }}
                                    </label>
                                </div>
                                <button type="submit" class="btn btn-primary w-100">
                                    {{ __('طھظ†ظپظٹط° ط§ظ„ط¥ط¬ط±ط§ط،') }}
                                </button>
                            </form>
                        @else
                            <p class="text-muted mb-0">{{ __('ظ‡ط°ظ‡ ط§ظ„ط­ظˆط§ظ„ط© ظ…طºظ„ظ‚ط© ط£ظˆ ظ…ط¹ط§ظ„ط¬ط© ظ…ط¨ظ„ط؛.') }}</p>
                        @endif
                    </div>
                </div>

                @if ($manualPaymentRequest->admin_note)
                    <div class="card mt-3">
                        <div class="card-header">
                            <h6 class="mb-0">{{ __('ملاحظات قبلية') }}</h6>
                        </div>
                        <div class="card-body">
                            <p class="mb-0">{{ $manualPaymentRequest->admin_note }}</p>
                        </div>
                    </div>
                @endif
                @if ($historyEntries->isNotEmpty())
                    <div class="card mt-3">
                        <div class="card-header">
                            <h6 class="mb-0">{{ __('سجل القرارات') }}</h6>
                        </div>
                        <div class="card-body">
                            <ul class="manual-payment-timeline">
                                @foreach ($historyEntries as $history)
                                    <li>
                                        <div class="timeline-point bg-{{ $history->status === \App\Models\ManualPaymentRequest::STATUS_APPROVED ? 'success' : ($history->status === \App\Models\ManualPaymentRequest::STATUS_REJECTED ? 'danger' : 'warning') }}"></div>
                                        <div class="timeline-content">
                                            <div class="d-flex justify-content-between flex-wrap gap-2">
                                                <strong>{{ __($history->status) }}</strong>
                                                <small class="text-muted">{{ optional($history->created_at)->format('Y-m-d H:i') }}</small>
                                            </div>
                                            <p class="mb-1 text-muted">{{ $history->user?->name ?? __('النظام') }}</p>
                                            @if ($history->note)
                                                <p class="mb-0">{{ $history->note }}</p>
                                            @endif
                                        </div>
                                    </li>
                                @endforeach
                            </ul>
                        </div>
                    </div>
                @endif
            </div>
        </div>
    </section>
@endsection

@push('styles')
<style>
    .manual-payment-timeline {
        list-style: none;
        margin: 0;
        padding: 0;
    }
    .manual-payment-timeline li {
        position: relative;
        padding-left: 28px;
        margin-bottom: 18px;
    }
    .manual-payment-timeline li::before {
        content: '';
        position: absolute;
        left: 7px;
        top: 0;
        bottom: -10px;
        width: 2px;
        background: #e5e7eb;
    }
    .manual-payment-timeline li:last-child::before {
        bottom: 12px;
    }
    .manual-payment-timeline .timeline-point {
        position: absolute;
        left: 0;
        top: 4px;
        width: 14px;
        height: 14px;
        border-radius: 50%;
    }
    .manual-payment-timeline .timeline-content {
        background: #f9fafb;
        border-radius: 8px;
        padding: 8px 12px;
    }
</style>
@endpush
