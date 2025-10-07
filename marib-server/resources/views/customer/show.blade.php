@extends('layouts.main')

@section('title')
    {{ __('تفاصيل العميل') }} - {{ $user->name }}
@endsection

@section('content')
<div class="container-fluid">
    <div class="row">
        <div class="col-md-12 mb-3">
            <div class="d-flex justify-content-between align-items-center">
                <h2>{{ __('تفاصيل العميل') }} - {{ $user->name }}</h2>
                <div>
                    <a href="{{ route('customer.index') }}" class="btn btn-secondary">
                        <i class="fa fa-arrow-right"></i> {{ __('العودة للقائمة') }}
                    </a>
                </div>
            </div>
        </div>
    </div>

    <div class="row">
        <!-- معلومات العميل الأساسية -->
        <div class="col-md-6">
            <div class="card">
                <div class="card-header">
                    <h4 class="card-title">{{ __('المعلومات الأساسية') }}</h4>
                </div>
                <div class="card-body">
                    <table class="table table-bordered">
                        <tr>
                            <th style="width: 30%">{{ __('الاسم') }}</th>
                            <td>{{ $user->name }}</td>
                        </tr>
                        <tr>
                            <th>{{ __('البريد الإلكتروني') }}</th>
                            <td>{{ $user->email }}</td>
                        </tr>
                        <tr>
                            <th>{{ __('رقم الهاتف') }}</th>
                            <td>{{ $user->mobile ?? __('غير متوفر') }}</td>
                        </tr>
                        <tr>
                            <th>{{ __('نوع الحساب') }}</th>
                            <td>{{ $user->getAccountTypeName() }}</td>
                        </tr>
                        <tr>
                            <th>{{ __('تاريخ التسجيل') }}</th>
                            <td>{{ $user->created_at->format('Y-m-d H:i') }}</td>
                        </tr>
                        <tr>
                            <th>{{ __('الحالة') }}</th>
                            <td>
                                @if($user->deleted_at)
                                    <span class="badge bg-danger">{{ __('محظور') }}</span>
                                @else
                                    <span class="badge bg-success">{{ __('نشط') }}</span>
                                @endif
                            </td>
                        </tr>
                    </table>
                </div>
            </div>
        </div>

        <!-- المعلومات الإضافية المنظمة -->
        <div class="col-md-6">
            <!-- معلومات الاتصال -->
            <div class="card">
                <div class="card-header">
                    <h4 class="card-title">{{ __('معلومات الاتصال') }}</h4>
                </div>
                <div class="card-body">
                    @if($user->additional_info && isset($user->additional_info['contact_info']) && !empty($user->additional_info['contact_info']))
                        <table class="table table-bordered">
                            @foreach($user->additional_info['contact_info'] as $label => $value)
                                <tr>
                                    <th style="width: 30%">{{ $label }}</th>
                                    <td>{{ $value }}</td>
                                </tr>
                            @endforeach
                        </table>
                    @else
                        <div class="alert alert-info">
                            {{ __('لا توجد معلومات اتصال إضافية') }}
                        </div>
                    @endif
                </div>
            </div>

            <!-- العناوين -->
            <div class="card mt-3">
                <div class="card-header">
                    <h4 class="card-title">{{ __('العناوين') }}</h4>
                </div>
                <div class="card-body">
                    @if($user->additional_info && isset($user->additional_info['addresses']) && !empty($user->additional_info['addresses']))
                        @foreach($user->additional_info['addresses'] as $address)
                            <div class="border rounded p-2 mb-2">
                                <strong>{{ $address['type'] ?? 'عنوان' }}</strong>
                                @if(isset($address['is_primary']) && $address['is_primary'])
                                    <span class="badge bg-primary">رئيسي</span>
                                @endif
                                <br>
                                <small>{{ $address['address'] ?? '' }}</small>
                            </div>
                        @endforeach
                    @else
                        <div class="alert alert-info">
                            {{ __('لا توجد عناوين مسجلة') }}
                        </div>
                    @endif
                </div>
            </div>

            <!-- الفئات -->
            <div class="card mt-3">
                <div class="card-header">
                    <h4 class="card-title">{{ __('الفئات') }}</h4>
                </div>
                <div class="card-body">
                    @if($user->additional_info && isset($user->additional_info['categories']) && !empty($user->additional_info['categories']))
                        <div class="d-flex flex-wrap">
                            @foreach($user->additional_info['categories'] as $category)
                                <span class="badge bg-secondary me-1 mb-1">
                                    {{ $category['id'] ?? '' }} ({{ $category['type'] ?? 'فئة' }})
                                </span>
                            @endforeach
                        </div>
                    @else
                        <div class="alert alert-info">
                            {{ __('لا توجد فئات مسجلة') }}
                        </div>
                    @endif
                </div>
            </div>

            <!-- معلومات الدفع -->
            <div class="card mt-3">
                <div class="card-header">
                    <h4 class="card-title">{{ __('معلومات الدفع') }}</h4>
                </div>
                <div class="card-body">
                    @if($user->payment_info)
                        <table class="table table-bordered">
                            @foreach($user->payment_info as $label => $value)
                                <tr>
                                    <th style="width: 30%">{{ $label }}</th>
                                    <td>{{ $value }}</td>
                                </tr>
                            @endforeach
                        </table>
                    @else
                        <div class="alert alert-info">
                            {{ __('لا توجد معلومات دفع مسجلة') }}
                        </div>
                    @endif
                </div>
            </div>
        </div>
    </div>

    @if($user->isSeller())
        <!-- المنتجات -->
        <div class="row mt-4">
            <div class="col-md-12">
                <div class="card">
                    <div class="card-header">
                        <h4 class="card-title">{{ __('المنتجات') }}</h4>
                    </div>
                    <div class="card-body">
                        @if($user->items->count() > 0)
                            <div class="table-responsive">
                                <table class="table table-bordered table-striped">
                                    <thead>
                                        <tr>
                                            <th>#</th>
                                            <th>{{ __('المنتج') }}</th>
                                            <th>{{ __('السعر') }}</th>
                                            <th>{{ __('الحالة') }}</th>
                                            <th>{{ __('تاريخ الإضافة') }}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        @foreach($user->items as $index => $item)
                                            <tr>
                                                <td>{{ $index + 1 }}</td>
                                                <td>{{ $item->name }}</td>
                                                <td>{{ number_format($item->price, 2) }}</td>
                                                <td>
                                                    <span class="badge bg-{{ $item->status == 'approved' ? 'success' : 'warning' }}">
                                                        {{ $item->status }}
                                                    </span>
                                                </td>
                                                <td>{{ $item->created_at->format('Y-m-d') }}</td>
                                            </tr>
                                        @endforeach
                                    </tbody>
                                </table>
                            </div>
                        @else
                            <div class="alert alert-info">
                                {{ __('لا توجد منتجات مضافة') }}
                            </div>
                        @endif
                    </div>
                </div>
            </div>
        </div>
    @endif

    <!-- الطلبات -->
    <div class="row mt-4">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header">
                    <h4 class="card-title">{{ __('الطلبات') }}</h4>
                </div>
                <div class="card-body">
                    @if($user->orders->count() > 0)
                        <div class="table-responsive">
                            <table class="table table-bordered table-striped">
                                <thead>
                                    <tr>
                                        <th>#</th>
                                        <th>{{ __('رقم الطلب') }}</th>
                                        <th>{{ __('المبلغ') }}</th>
                                        <th>{{ __('حالة الطلب') }}</th>
                                        <th>{{ __('حالة الدفع') }}</th>
                                        <th>{{ __('التاريخ') }}</th>
                                        <th>{{ __('الإجراءات') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @foreach($user->orders as $index => $order)
                                        <tr>
                                            <td>{{ $index + 1 }}</td>
                                            <td>{{ $order->order_number }}</td>
                                            <td>{{ number_format($order->final_amount, 2) }}</td>
                                            <td>
                                                @php
                                                    $statusConfig = \App\Models\Order::statusDisplayMap()[$order->order_status] ?? null;
                                                    $statusLabel = \App\Models\Order::statusLabel($order->order_status);
                                                    $statusLabel = $statusLabel !== ''
                                                        ? $statusLabel
                                                        : \Illuminate\Support\Str::of($order->order_status)->replace('_', ' ')->headline();
                                                    $statusIconClass = \App\Models\Order::statusIcon($order->order_status);
                                                    $statusTimeline = \App\Models\Order::statusTimelineMessage($order->order_status);
                                                    $isReserveStatus = (bool) data_get($statusConfig, 'reserve', false);
                                                @endphp
                                                <span class="badge bg-light text-dark border d-inline-flex align-items-center gap-1"
                                                    @if($statusTimeline) title="{{ $statusTimeline }}" @endif>
                                                    @if($statusIconClass)
                                                        <i class="{{ $statusIconClass }}"></i>
                                                    @endif
                                                    <span>{{ $statusLabel }}</span>
                                                    @if($isReserveStatus)
                                                        <span class="ms-1 small fw-semibold">احتياطي</span>
                                                    @endif
                                                </span>
                                            </td>
                                            <td>
                                                <span class="badge bg-{{ $order->payment_status == 'paid' ? 'success' : 'warning' }}">
                                                    {{ $order->payment_status }}
                                                </span>
                                            </td>
                                            <td>{{ $order->created_at->format('Y-m-d') }}</td>
                                            <td>
                                                <a href="{{ route('orders.show', $order->id) }}" class="btn btn-sm btn-info">
                                                    <i class="fa fa-eye"></i>
                                                </a>
                                            </td>
                                        </tr>
                                    @endforeach
                                </tbody>
                            </table>
                        </div>
                    @else
                        <div class="alert alert-info">
                            {{ __('لا توجد طلبات') }}
                        </div>
                    @endif
                </div>
            </div>
        </div>
    </div>
</div>
@endsection 