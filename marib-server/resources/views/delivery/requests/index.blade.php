@extends('layouts.main')

@section('title', __('طلبات التوصيل'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('متابعة الطلبات التي جُهزت من قبل المتاجر وبانتظار فريق التوصيل.') }}
                </p>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-body">
                <form class="row g-2 mb-3">
                    <div class="col-12 col-md-3">
                        <label class="form-label">{{ __('الحالة') }}</label>
                        <select name="status" class="form-select" onchange="this.form.submit()">
                            <option value="">{{ __('الكل') }}</option>
                            @foreach ([
                                \App\Models\DeliveryRequest::STATUS_PENDING => __('قيد الترحيل'),
                                \App\Models\DeliveryRequest::STATUS_ASSIGNED => __('تم التعيين'),
                                \App\Models\DeliveryRequest::STATUS_DISPATCHED => __('في الطريق'),
                                \App\Models\DeliveryRequest::STATUS_DELIVERED => __('مكتمل'),
                                \App\Models\DeliveryRequest::STATUS_CANCELED => __('ملغى'),
                            ] as $key => $label)
                                <option value="{{ $key }}" @selected($selectedStatus === $key)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-12 col-md-5">
                        <label class="form-label">{{ __('بحث بالطلب') }}</label>
                        <input type="search" name="search" value="{{ $search }}" class="form-control" placeholder="{{ __('رقم الطلب أو مرجع الحوالة') }}">
                    </div>
                    <div class="col-12 col-md-2 d-flex align-items-end">
                        <button class="btn btn-outline-primary w-100" type="submit">
                            <i class="bi bi-search"></i> {{ __('بحث') }}
                        </button>
                    </div>
                </form>

                <div class="table-responsive">
                    <table class="table table-hover align-middle">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>{{ __('رقم الطلب') }}</th>
                                <th>{{ __('القيمة') }}</th>
                                <th>{{ __('الحالة') }}</th>
                                <th>{{ __('تاريخ الإنشاء') }}</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($requests as $requestRow)
                                <tr>
                                    <td>#{{ $requestRow->id }}</td>
                                    <td>#{{ $requestRow->order?->order_number ?? $requestRow->order_id }}</td>
                                    <td>{{ number_format($requestRow->order?->final_amount ?? 0, 2) }} {{ __('ر.ي') }}</td>
                                    <td>
                                        <span class="badge bg-{{ $requestRow->status === \App\Models\DeliveryRequest::STATUS_DELIVERED ? 'success' : 'primary' }}">
                                            {{ __($requestRow->status) }}
                                        </span>
                                    </td>
                                    <td>{{ optional($requestRow->created_at)->format('Y-m-d H:i') }}</td>
                                    <td class="text-end">
                                        <a href="{{ route('delivery.requests.show', $requestRow) }}" class="btn btn-sm btn-outline-primary">
                                            {{ __('إدارة') }}
                                        </a>
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                <td colspan="6" class="text-center text-muted py-4">
                                        {{ __('لا توجد طلبات للتوصيل حالياً.') }}
                                    </td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>

                <div class="mt-3">
                    {{ $requests->links() }}
                </div>
            </div>
        </div>
    </section>
@endsection
