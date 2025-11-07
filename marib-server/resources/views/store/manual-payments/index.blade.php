@extends('layouts.main')

@section('title', __('الحوالات اليدوية'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('مراجعة التحويلات البنكية المرسلة من الزبائن لهذا المتجر.') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end gap-2 flex-wrap">
                <a href="{{ route('merchant.dashboard') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i>{{ __('العودة للوحة المتجر') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-body">
                <form method="get" class="row g-2 mb-3">
                    <div class="col-12 col-md-4">
                        <label class="form-label">{{ __('الحالة') }}</label>
                        <select name="status" class="form-select" onchange="this.form.submit()">
                            <option value="">{{ __('الكل') }}</option>
                            @foreach ([
                                \App\Models\ManualPaymentRequest::STATUS_PENDING => __('قيد المراجعة'),
                                \App\Models\ManualPaymentRequest::STATUS_UNDER_REVIEW => __('قيد التحقق'),
                                \App\Models\ManualPaymentRequest::STATUS_APPROVED => __('مقبول'),
                                \App\Models\ManualPaymentRequest::STATUS_REJECTED => __('مرفوض'),
                            ] as $key => $label)
                                <option value="{{ $key }}" @selected($selectedStatus === $key)>
                                    {{ $label }} ({{ $statusCounts[$key] ?? 0 }})
                                </option>
                            @endforeach
                        </select>
                    </div>
                </form>

                <div class="table-responsive">
                    <table class="table table-striped align-middle">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>{{ __('العميل') }}</th>
                                <th>{{ __('المبلغ') }}</th>
                                <th>{{ __('البنك') }}</th>
                            <th>{{ __('الحالة') }}</th>
                            <th>{{ __('تاريخ الإنشاء') }}</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($manualPayments as $requestRow)
                            <tr>
                                    <td>#{{ $requestRow->id }}</td>
                                    <td>{{ $requestRow->user?->name ?? __('مستخدم') }}</td>
                                    <td>{{ number_format($requestRow->amount ?? 0, 2) }} {{ $requestRow->currency ?? 'ر.ي' }}</td>
                                    <td>{{ $requestRow->manualBank?->name ?? __('تحويل يدوي') }}</td>
                                    <td>
                                    <span class="badge bg-{{ $requestRow->status === 'approved' ? 'success' : ($requestRow->status === 'rejected' ? 'danger' : 'warning') }}">
                                        {{ __($requestRow->status) }}
                                    </span>
                                </td>
                                <td>{{ optional($requestRow->created_at)->format('Y-m-d H:i') }}</td>
                                <td class="text-end">
                                    <a href="{{ route('merchant.manual-payments.show', $requestRow) }}" class="btn btn-sm btn-outline-primary">
                                        {{ __('عرض') }}
                                    </a>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="text-center text-muted py-4">
                                    {{ __('لا توجد حوالات يدوية حالياً.') }}
                                </td>
                            </tr>
                        @endforelse
                        </tbody>
                    </table>
                </div>

                <div class="mt-3">
                    {{ $manualPayments->links() }}
                </div>
            </div>
        </div>
    </section>
@endsection
