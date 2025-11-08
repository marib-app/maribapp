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
        <div class="row gy-3">
            <div class="col-12 col-md-4">
                <div class="card border-0 shadow-sm h-100 bg-primary text-white">
                    <div class="card-body">
                        <p class="text-uppercase fw-bold small mb-2">{{ __('حوالات قيد المتابعة') }}</p>
                        <h3 class="fw-bold mb-0">{{ $openCount }}</h3>
                        <small class="d-block mt-1">{{ __('إجمالي المبلغ') }}: {{ number_format($openAmount, 2) }} {{ __('ر.ي') }}</small>
                    </div>
                </div>
            </div>
            <div class="col-6 col-md-4">
                <div class="card border-0 shadow-sm h-100">
                    <div class="card-body">
                        <p class="text-uppercase fw-semibold small mb-2 text-success">{{ __('موافقات اليوم') }}</p>
                        <h3 class="fw-bold mb-0 text-success">{{ $approvedToday }}</h3>
                    </div>
                </div>
            </div>
            <div class="col-6 col-md-4">
                <div class="card border-0 shadow-sm h-100">
                    <div class="card-body">
                        <p class="text-uppercase fw-semibold small mb-2 text-danger">{{ __('رفض اليوم') }}</p>
                        <h3 class="fw-bold mb-0 text-danger">{{ $rejectedToday }}</h3>
                    </div>
                </div>
            </div>
        </div>

        <div class="card mt-4">
            <div class="card-body">
                <form method="get" class="row gy-2 gx-2 align-items-end mb-3">
                    <div class="col-12 col-md-3">
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
                    <div class="col-12 col-md-6">
                        <label class="form-label">{{ __('بحث عن مرجع/عميل') }}</label>
                        <div class="input-group">
                            <input type="search" name="search" value="{{ $search }}" class="form-control" placeholder="{{ __('رقم الحوالة أو اسم العميل') }}">
                            <button class="btn btn-outline-primary" type="submit">
                                <i class="bi bi-search"></i>
                            </button>
                        </div>
                    </div>
                    <div class="col-12 col-md-auto ms-auto">
                        <button type="submit" class="btn btn-outline-secondary w-100">
                            <i class="bi bi-funnel"></i> {{ __('تطبيق الفلترة') }}
                        </button>
                    </div>
                </form>

                <div class="table-responsive">
                    <table class="table table-striped align-middle">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>{{ __('المرجع') }}</th>
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
                                @php
                                    $statusColor = $requestRow->status === \App\Models\ManualPaymentRequest::STATUS_APPROVED
                                        ? 'success'
                                        : ($requestRow->status === \App\Models\ManualPaymentRequest::STATUS_REJECTED ? 'danger' : 'warning');
                                @endphp
                                <tr class="{{ in_array($requestRow->status, \App\Models\ManualPaymentRequest::OPEN_STATUSES, true) ? 'table-warning' : '' }}">
                                    <td>#{{ $requestRow->id }}</td>
                                    <td>{{ $requestRow->reference ?? '-' }}</td>
                                    <td>
                                        {{ $requestRow->user?->name ?? __('مستخدم') }}
                                        @if ($requestRow->user?->mobile)
                                            <br><small class="text-muted">{{ $requestRow->user->mobile }}</small>
                                        @endif
                                    </td>
                                    <td>{{ number_format($requestRow->amount ?? 0, 2) }} {{ $requestRow->currency ?? 'ر.ي' }}</td>
                                    <td>{{ $requestRow->manualBank?->name ?? __('تحويل يدوي') }}</td>
                                    <td>
                                        <span class="badge bg-{{ $statusColor }}">
                                            {{ __($requestRow->status) }}
                                        </span>
                                    </td>
                                    <td>{{ optional($requestRow->created_at)->format('Y-m-d H:i') }}</td>
                                    <td class="text-end">
                                        <a href="{{ route('merchant.manual-payments.show', $requestRow) }}" class="btn btn-sm btn-outline-primary">
                                            {{ __('عرض التفاصيل') }}
                                        </a>
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="8" class="text-center text-muted py-4">
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
