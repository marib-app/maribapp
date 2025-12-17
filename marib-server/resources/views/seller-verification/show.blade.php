@extends('layouts.main')
@section('title')
    {{ __("تفاصيل طلب التوثيق") }} #{{ $verification->id }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row d-flex align-items-center">
            <div class="col-12 col-md-6">
                <h4 class="mb-0">@yield('title')</h4>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card mb-3">
            <div class="card-body">
                <h5 class="mb-3">{{ __('بيانات الحساب') }}</h5>
                <div class="row g-3">
                    <div class="col-md-3">
                        <div class="small text-muted">{{ __('المستخدم') }}</div>
                        <div class="fw-bold">{{ $verification->user->name ?? '-' }}</div>
                    </div>
                    <div class="col-md-3">
                        <div class="small text-muted">{{ __('البريد') }}</div>
                        <div>{{ $verification->user->email ?? '-' }}</div>
                    </div>
                    <div class="col-md-3">
                        <div class="small text-muted">{{ __('الجوال') }}</div>
                        <div>{{ $verification->user->mobile ?? '-' }}</div>
                    </div>
                    <div class="col-md-3">
                        <div class="small text-muted">{{ __('الحالة الحالية') }}</div>
                        <span class="badge bg-{{ $verification->status === 'approved' ? 'success' : ($verification->status === 'rejected' ? 'danger' : 'warning') }}">
                            {{ $verification->status }}
                        </span>
                    </div>
                </div>
            </div>
        </div>

        <div class="card mb-3">
            <div class="card-body">
                <h5 class="mb-3">{{ __('تفاصيل الطلب') }}</h5>
                <div class="table-responsive">
                    <table class="table table-sm table-striped">
                        <thead>
                        <tr>
                            <th style="width: 5%;">#</th>
                            <th style="width: 25%;">{{ __('الحقل') }}</th>
                            <th style="width: 70%;">{{ __('القيمة') }}</th>
                        </tr>
                        </thead>
                        <tbody>
                        @foreach($verification->verification_field_values as $index => $fieldValue)
                            @php
                                $field = $fieldValue->verification_field;
                                $val = $fieldValue->value;
                                $display = '';
                                if ($field && $field->type === 'fileinput' && !empty($val)) {
                                    $links = is_array($val) ? $val : [$val];
                                    $display = collect($links)->map(function($link, $i) {
                                        return "<a href=\"{$link}\" target=\"_blank\">".__('فتح الملف')." ".($i+1)."</a>";
                                    })->implode(' , ');
                                } else {
                                    $display = is_array($val) ? implode(' , ', $val) : ($val ?? '-');
                                }
                            @endphp
                            <tr>
                                <td>{{ $index + 1 }}</td>
                                <td>{{ $field->name ?? '-' }}</td>
                                <td class="text-break">{!! $display !!}</td>
                            </tr>
                        @endforeach
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div class="card mb-3">
            <div class="card-body">
                <h5 class="mb-3">{{ __('تفاصيل الدفعات') }}</h5>
                <div class="table-responsive">
                    <table class="table table-sm table-striped">
                        <thead>
                        <tr>
                            <th>#</th>
                            <th>{{ __('المبلغ') }}</th>
                            <th>{{ __('الحالة') }}</th>
                            <th>{{ __('الخطة') }}</th>
                            <th>{{ __('يبدأ في') }}</th>
                            <th>{{ __('ينتهي في') }}</th>
                            <th>{{ __('بوابة الدفع') }}</th>
                            <th>{{ __('تاريخ الإنشاء') }}</th>
                        </tr>
                        </thead>
                        <tbody>
                        @forelse($payments as $payment)
                            <tr>
                                <td>{{ $payment->id }}</td>
                                <td>{{ number_format($payment->amount, 2) }} {{ $payment->currency }}</td>
                                <td>{{ $payment->status }}</td>
                                <td>{{ $payment->plan->name ?? '-' }}</td>
                                <td>{{ optional($payment->starts_at)->toDateString() }}</td>
                                <td>{{ optional($payment->expires_at)->toDateString() }}</td>
                                <td>{{ data_get($payment->meta, 'gateway', '-') }}</td>
                                <td>{{ optional($payment->created_at)->toDateTimeString() }}</td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="8" class="text-center text-muted">{{ __('لا توجد دفعات مسجلة') }}</td>
                            </tr>
                        @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        @if($payments->isNotEmpty())
            @php
                $latestPayment = $payments->first();
            @endphp
            <div class="alert alert-info">
                {{ __('آخر دفعة:') }}
                <strong>{{ number_format($latestPayment->amount, 2) }} {{ $latestPayment->currency }}</strong>
                {{ __('عبر بوابة') }}
                <strong>{{ data_get($latestPayment->meta, 'gateway', __('غير محددة')) }}</strong>
                @if($latestPayment->expires_at)
                    - {{ __('تنتهي في') }} {{ $latestPayment->expires_at->toDateString() }}
                @endif
            </div>
        @endif

        <div class="card">
            <div class="card-body">
                <h5 class="mb-3">{{ __('إجراءات التوثيق') }}</h5>
                <form action="{{ route('seller_verification.approval', $verification->id) }}" method="POST" class="row g-3">
                    @csrf
                    @method('PUT')
                    <div class="col-md-4">
                        <label class="form-label">{{ __('الحالة') }}</label>
                        <select name="status" class="form-select" required>
                            <option value="pending" @selected($verification->status=='pending')>{{ __('Pending') }}</option>
                            <option value="approved" @selected($verification->status=='approved')>{{ __('Approved') }}</option>
                            <option value="rejected" @selected($verification->status=='rejected')>{{ __('Rejected') }}</option>
                            <option value="resubmitted" @selected($verification->status=='resubmitted')>{{ __('Resubmitted') }}</option>
                        </select>
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">{{ __('المدة (أيام)') }}</label>
                        <input type="number" name="duration_days" min="0" value="{{ $verification->duration_days ?? 30 }}" class="form-control">
                        <small class="text-muted">{{ __('يستخدم عند الموافقة لتحديد تاريخ الانتهاء') }}</small>
                    </div>
                    <div class="col-12">
                        <label class="form-label">{{ __('ملاحظات / سبب الرفض') }}</label>
                        <textarea name="rejection_reason" class="form-control" rows="3">{{ $verification->rejection_reason }}</textarea>
                    </div>
                    <div class="col-12">
                        <button type="submit" class="btn btn-primary">{{ __('حفظ الإجراء') }}</button>
                    </div>
                </form>
            </div>
        </div>
    </section>
@endsection
