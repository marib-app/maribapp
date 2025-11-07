@extends('layouts.main')

@section('title', __('تفاصيل الطلب #:number', ['number' => $order->order_number ?? $order->id]))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('متابعة حالة الطلب وتحديثها.') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end flex-wrap gap-2">
                <a href="{{ route('merchant.orders.index') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i>
                    {{ __('عودة لقائمة الطلبات') }}
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
                        <h6 class="mb-0">{{ __('معلومات الطلب') }}</h6>
                    </div>
                    <div class="card-body">
                        <dl class="row">
                            <dt class="col-sm-4">{{ __('رقم الطلب') }}</dt>
                            <dd class="col-sm-8">#{{ $order->order_number ?? $order->id }}</dd>

                            <dt class="col-sm-4">{{ __('العميل') }}</dt>
                            <dd class="col-sm-8">{{ $order->user?->name ?? __('عميل') }}</dd>

                            <dt class="col-sm-4">{{ __('المبلغ النهائي') }}</dt>
                            <dd class="col-sm-8">{{ number_format($order->final_amount, 2) }} {{ __('ر.ي') }}</dd>

                            <dt class="col-sm-4">{{ __('حالة الطلب') }}</dt>
                            <dd class="col-sm-8">
                                <span class="badge bg-primary">{{ __($order->order_status) }}</span>
                            </dd>

                            <dt class="col-sm-4">{{ __('طريقة الدفع') }}</dt>
                            <dd class="col-sm-8">{{ __($order->payment_status ?? 'pending') }}</dd>

                            <dt class="col-sm-4">{{ __('أنشئ في') }}</dt>
                            <dd class="col-sm-8">{{ optional($order->created_at)->format('Y-m-d H:i') }}</dd>
                        </dl>
                    </div>
                </div>

                <div class="card mt-3">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('العناصر') }}</h6>
                    </div>
                    <div class="card-body table-responsive">
                        <table class="table table-sm mb-0">
                            <thead>
                                <tr>
                                    <th>{{ __('المنتج') }}</th>
                                    <th>{{ __('الكمية') }}</th>
                                    <th>{{ __('السعر') }}</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach ($order->orderItems as $item)
                                    <tr>
                                        <td>{{ $item->item?->name ?? __('منتج') }}</td>
                                        <td>{{ $item->quantity }}</td>
                                        <td>{{ number_format($item->price, 2) }} {{ __('ر.ي') }}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <div class="col-12 col-lg-5">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('تحديث حالة الطلب') }}</h6>
                    </div>
                    <div class="card-body">
                        <form method="post" action="{{ route('merchant.orders.status', $order) }}">
                            @csrf
                            <div class="mb-3">
                                <label class="form-label">{{ __('حالة الطلب') }}</label>
                                <select name="order_status" class="form-select">
                                    @foreach ($statusOptions as $key => $label)
                                        <option value="{{ $key }}" @selected($order->order_status === $key)>
                                            {{ __($label) }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">{{ __('ملاحظة داخلية') }}</label>
                                <textarea name="comment" class="form-control" rows="3" placeholder="{{ __('اختياري') }}"></textarea>
                            </div>

                            <div class="form-check mb-3">
                                <input class="form-check-input" type="checkbox" value="1" name="notify_customer" id="notify_customer">
                                <label class="form-check-label" for="notify_customer">
                                    {{ __('إشعار العميل بالتحديث') }}
                                </label>
                            </div>

                            <button type="submit" class="btn btn-primary w-100">
                                <i class="bi bi-save"></i>
                                {{ __('حفظ التغييرات') }}
                            </button>
                        </form>
                    </div>
                </div>

                <div class="card mt-3">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('عنوان الشحن') }}</h6>
                    </div>
                    <div class="card-body">
                        @php
                            $address = is_array($order->shipping_address)
                                ? $order->shipping_address
                                : json_decode((string) $order->shipping_address, true);
                        @endphp
                        @if (! empty($address))
                            <p class="mb-1">{{ data_get($address, 'name') }}</p>
                            <p class="mb-1 text-muted">{{ data_get($address, 'address') }}</p>
                            <p class="mb-0 text-muted">{{ data_get($address, 'phone') }}</p>
                        @else
                            <p class="text-muted mb-0">{{ __('لا يوجد عنوان مسجل.') }}</p>
                        @endif
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
