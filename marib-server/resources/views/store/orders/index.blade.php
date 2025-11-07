@extends('layouts.main')

@section('title', __('طلبات المتجر'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('عرض الطلبات الخاصة بالمتجر الحالي وإدارتها.') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end align-items-start gap-2 flex-wrap">
                <a href="{{ route('merchant.dashboard') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i>
                    {{ __('العودة للوحة المتجر') }}
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
                        <label class="form-label">{{ __('حالة الطلب') }}</label>
                        <select name="status" class="form-select" onchange="this.form.submit()">
                            <option value="">{{ __('الكل') }}</option>
                            @foreach (config('constants.ORDER_STATUSES', []) as $key => $label)
                                <option value="{{ $key }}" @selected($selectedStatus === $key)>{{ __($label) }}</option>
                            @endforeach
                        </select>
                    </div>
                </form>

                <div class="table-responsive">
                    <table class="table table-striped">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>{{ __('العميل') }}</th>
                                <th>{{ __('الإجمالي') }}</th>
                                <th>{{ __('الحالة') }}</th>
                                <th>{{ __('الدفع') }}</th>
                                <th>{{ __('أنشئ في') }}</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($orders as $order)
                                <tr>
                                    <td>#{{ $order->order_number ?? $order->id }}</td>
                                    <td>{{ $order->user?->name ?? __('عميل') }}</td>
                                    <td>{{ number_format($order->final_amount, 2) }} {{ __('ر.ي') }}</td>
                                    <td>
                                        <span class="badge bg-info">
                                            {{ __($order->order_status) }}
                                        </span>
                                    </td>
                                    <td>{{ __($order->payment_status) }}</td>
                                    <td>{{ optional($order->created_at)->format('Y-m-d H:i') }}</td>
                                    <td class="text-end">
                                        <a href="{{ route('merchant.orders.show', $order) }}" class="btn btn-sm btn-outline-primary">
                                            {{ __('عرض') }}
                                        </a>
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="7" class="text-center text-muted py-4">
                                        {{ __('لا توجد طلبات حالياً.') }}
                                    </td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>

                <div class="mt-3">
                    {{ $orders->links() }}
                </div>
            </div>
        </div>
    </section>
@endsection
