@extends('layouts.main')

@section('title', 'مجموعة الدفع: ' . $group->name)

@section('content')
<div class="container-fluid">
    @if (session('success'))
        <div class="alert alert-success alert-dismissible fade show" role="alert">
            {{ session('success') }}
            <button type="button" class="close" data-bs-dismiss="alert" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
        </div>
    @endif

    @if ($errors->any())
        <div class="alert alert-danger alert-dismissible fade show" role="alert">
            <strong>حدث خطأ أثناء المعالجة:</strong>
            <ul class="mb-0 mt-2">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
            <button type="button" class="close" data-bs-dismiss="alert" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
        </div>
    @endif

    <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-4">
        <h2 class="mb-0">مجموعة الدفع: {{ $group->name }}</h2>
        <div class="d-flex align-items-center gap-2">
            @if ($orders->isNotEmpty())
                <a href="{{ route('orders.show', $orders->first()) }}" class="btn btn-outline-secondary">
                    <i class="fa fa-arrow-right"></i>
                    العودة إلى الطلب الأول
                </a>
            @endif
            <a href="{{ route('orders.index') }}" class="btn btn-outline-primary">
                <i class="fa fa-list"></i>
                قائمة الطلبات
            </a>
        </div>
    </div>

    <div class="row">
        <div class="col-lg-4">
            <div class="card mb-3">
                <div class="card-header">
                    <h5 class="card-title mb-0">تفاصيل المجموعة</h5>
                </div>
                <div class="card-body">
                    <dl class="row mb-0">
                        <dt class="col-5">اسم المجموعة</dt>
                        <dd class="col-7">{{ $group->name }}</dd>
                        <dt class="col-5">ملاحظة</dt>
                        <dd class="col-7">{{ $group->note ?: '—' }}</dd>
                        <dt class="col-5">عدد الطلبات</dt>
                        <dd class="col-7">{{ $ordersCount }}</dd>
                        <dt class="col-5">إجمالي الكمية</dt>
                        <dd class="col-7">{{ number_format($totalQuantity ?? 0) }}</dd>
                        <dt class="col-5">إجمالي المبالغ</dt>
                        <dd class="col-7">{{ number_format($totalAmount ?? 0, 2) }}</dd>
                        <dt class="col-5">تاريخ الإنشاء</dt>
                        <dd class="col-7">{{ optional($group->created_at)->format('Y-m-d H:i') ?? 'غير متوفر' }}</dd>
                        <dt class="col-5">آخر تحديث</dt>
                        <dd class="col-7">{{ optional($group->updated_at)->format('Y-m-d H:i') ?? 'غير متوفر' }}</dd>
                    </dl>
                </div>
            </div>

            <div class="card mb-3">
                <div class="card-body">
                    <h6 class="card-title">إضافة طلبات من شي إن</h6>
                    <p class="text-muted small">اختر طلبات جديدة من قائمة طلبات شي إن لإضافتها إلى هذه المجموعة.</p>
                    <button type="button" class="btn btn-primary w-100" data-bs-toggle="modal" data-bs-target="#addOrdersModal">
                        <i class="fa fa-plus"></i>
                        إضافة طلبات إلى المجموعة
                    </button>
                </div>
            </div>
        </div>

        <div class="col-lg-8">
            <div class="card mb-3">
                <div class="card-header">
                    <h5 class="card-title mb-0">تحديث جماعي</h5>
                </div>
                <form action="{{ route('orders.payment-groups.bulk-update', $group) }}" method="POST">
                    @csrf
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="group_order_status">حالة الطلب</label>
                                    <select name="order_status" id="group_order_status" class="form-control">
                                        <option value="">بدون تغيير</option>
                                        @foreach ($orderStatuses as $status)
                                            @php
                                                $statusConfig = $statusLabels[$status] ?? [];
                                                $statusLabel = $statusConfig['label'] ?? $status;
                                            @endphp
                                            <option value="{{ $status }}">{{ $statusLabel }}</option>
                                        @endforeach
                                    </select>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="group_notification_title">عنوان الإشعار (اختياري)</label>
                                    <input type="text" class="form-control" id="group_notification_title" name="notification_title" value="{{ old('notification_title') }}" maxlength="190">
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="group_notes">ملاحظات الطلب</label>
                                    <textarea class="form-control" id="group_notes" name="notes" rows="3">{{ old('notes') }}</textarea>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="group_comment">تعليق سجل الحالة</label>
                                    <textarea class="form-control" id="group_comment" name="comment" rows="3">{{ old('comment') }}</textarea>
                                </div>
                            </div>
                            <div class="col-12">
                                <div class="form-group">
                                    <label for="group_notification_message">نص الإشعار للعملاء</label>
                                    <textarea class="form-control" id="group_notification_message" name="notification_message" rows="3">{{ old('notification_message') }}</textarea>
                                    <small class="form-text text-muted">سيتم إرسال هذا النص لكل عميل عند تفعيل خيار الإشعار أدناه.</small>
                                </div>
                            </div>
                            <div class="col-12">
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" value="1" id="group_notify_customer" name="notify_customer" {{ old('notify_customer') ? 'checked' : '' }}>
                                    <label class="form-check-label" for="group_notify_customer">
                                        إشعار جميع العملاء المرتبطين بهذه المجموعة
                                    </label>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="card-footer text-right">
                        <button type="submit" class="btn btn-primary">تطبيق التحديث على جميع الطلبات</button>
                    </div>
                </form>
            </div>

            <div class="card">
                <div class="card-header d-flex justify-content-between align-items-center">
                    <h5 class="card-title mb-0">الطلبات ضمن المجموعة</h5>
                    <span class="badge bg-info">{{ $ordersCount }} طلب</span>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover mb-0">
                            <thead>
                                <tr>
                                    <th>رقم الطلب</th>
                                    <th>العميل</th>
                                    <th>حالة الطلب</th>
                                    <th>حالة الدفع</th>
                                    <th>المبلغ النهائي</th>
                                    <th>آخر تحديث</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse ($orders as $order)
                                    @php
                                        $statusConfig = $statusLabels[$order->order_status] ?? [];
                                        $statusLabel = $statusConfig['label'] ?? $order->order_status;
                                        $statusIcon = $statusConfig['icon'] ?? null;
                                        $pendingManualPayments = (int) ($order->pending_manual_payment_requests_count ?? 0);
                                        if ($pendingManualPayments > 0) {
                                            $paymentLabel = 'قيد المراجعة';
                                        } else {
                                            $paymentLabel = $paymentStatusLabels[$order->payment_status] ?? $order->payment_status;
                                        }
                                        
                                        @endphp
                                    <tr>
                                        <td>
                                            <a href="{{ route('orders.show', $order) }}" class="text-decoration-none">
                                                {{ $order->order_number ?? $order->id }}
                                            </a>
                                        </td>
                                        <td>{{ optional($order->user)->name ?? 'غير معروف' }}</td>
                                        <td>
                                            <span class="badge bg-light text-dark border d-inline-flex align-items-center gap-1">
                                                @if ($statusIcon)
                                                    <i class="{{ $statusIcon }}"></i>
                                                @endif
                                                <span>{{ $statusLabel }}</span>
                                            </span>
                                        </td>
                                        <td>
                                            {{ $paymentLabel ?: 'غير محدد' }}
                                            @if($pendingManualPayments > 0)
                                                <div class="small text-muted">{{ $pendingManualPayments }} دفعة قيد المراجعة</div>
                                            @endif
                                        </td>

                                        
                                        <td>{{ number_format($order->final_amount ?? 0, 2) }}</td>
                                        <td>{{ optional($order->updated_at)->format('Y-m-d H:i') ?? '—' }}</td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="6" class="text-center py-4">لا توجد طلبات ضمن هذه المجموعة حالياً.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="addOrdersModal" tabindex="-1" aria-labelledby="addOrdersModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="addOrdersModalLabel">إضافة طلبات من قائمة شي إن</h5>
                <button type="button" class="close" data-bs-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <form action="{{ route('orders.payment-groups.orders.store', $group) }}" method="POST">
                @csrf
                <div class="modal-body">
                    <div class="form-group">
                        <label for="available_order_ids">اختر الطلبات المتاحة</label>
                        <select name="order_ids[]" id="available_order_ids" class="form-control" size="8" multiple>
                            @forelse ($availableOrders as $orderOption)
                                <option value="{{ $orderOption->id }}">
                                    {{ $orderOption->order_number ?? $orderOption->id }} — {{ optional($orderOption->user)->name ?? 'عميل غير معروف' }} ({{ number_format($orderOption->final_amount ?? 0, 2) }})
                                </option>
                            @empty
                                <option disabled>لا توجد طلبات متاحة حالياً.</option>
                            @endforelse
                        </select>
                        <small class="form-text text-muted">يمكنك تحديد أكثر من طلب بالضغط على زر التحكم أثناء التحديد.</small>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">إلغاء</button>
                    <button type="submit" class="btn btn-primary" @if($availableOrders->isEmpty()) disabled @endif>إضافة الطلبات</button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection