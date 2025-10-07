@php
    $groups = ($paymentGroups ?? collect())->filter();

    $statusLabelsMap = $statusLabels ?? [];
    $statusOptions = collect($orderStatuses ?? [])
        ->mapWithKeys(static function ($status) use ($statusLabelsMap) {
            if ($status instanceof \App\Models\OrderStatus) {
                $code = (string) $status->code;
                $defaultLabel = $status->name;
            } else {
                $code = is_string($status) ? $status : (string) $status;
                $defaultLabel = $code;
            }

            if ($code === '') {
                return [];
            }

            $label = data_get($statusLabelsMap, $code . '.label', $defaultLabel);

            if (empty($label)) {
                $label = \Illuminate\Support\Str::of($code)->replace('_', ' ')->headline();
            }

            return [$code => $label];
        })
        ->all();



@endphp

<div class="payment-groups-section">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <h5 class="mb-0">إدارة مجموعات الدفع</h5>
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#createPaymentGroupModal">
            <i class="fa fa-layer-group"></i>
            <span class="ms-1">إنشاء مجموعة</span>
        </button>
    </div>

    @if ($groups->isEmpty())
        <div class="alert alert-info mb-0">
            لا توجد مجموعات مرتبطة بهذا الطلب حتى الآن. يمكنك إنشاء مجموعة جديدة لإدارة التحديثات الجماعية والإشعارات.
        </div>
    @else
        <div class="table-responsive">
            <table class="table table-striped align-middle">
                <thead>
                    <tr>
                        <th>اسم المجموعة</th>
                        <th>ملاحظة</th>
                        <th>عدد الطلبات</th>
                        <th>إجمالي الكمية</th>
                        <th>إجمالي المبالغ</th>
                        <th class="text-end">إجراءات</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($groups as $group)
                        @php
                            $orders = $group->orders ?? collect();
                            $ordersCount = $orders->count();
                            $totalQuantity = $orders->flatMap(static fn ($order) => $order->items ?? collect())->sum('quantity');
                            $totalAmount = $orders->sum('final_amount');
                        @endphp
                        <tr>
                            <td>
                                <div class="fw-semibold">{{ $group->name }}</div>
                                <div class="text-muted small">آخر تحديث: {{ optional($group->updated_at)->format('Y-m-d H:i') ?? 'غير متوفر' }}</div>
                            </td>
                            <td>{{ $group->note ? \Illuminate\Support\Str::limit($group->note, 80) : '—' }}</td>
                            <td>
                                <span class="badge bg-info">{{ $ordersCount }}</span>
                            </td>
                            <td>{{ number_format($totalQuantity ?? 0) }}</td>
                            <td>{{ number_format($totalAmount ?? 0, 2) }}</td>
                            <td class="text-end">
                                <a href="{{ route('orders.payment-groups.show', $group) }}" class="btn btn-outline-primary btn-sm">
                                    <i class="fa fa-folder-open"></i>
                                    فتح المجموعة
                                </a>
                                <button type="button" class="btn btn-outline-secondary btn-sm" data-bs-toggle="modal" data-bs-target="#bulkUpdateGroupModal-{{ $group->id }}">
                                    <i class="fa fa-sync"></i>
                                    تحديث جماعي
                                </button>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    @endif
</div>

@foreach ($groups as $group)
    <div class="modal fade" id="bulkUpdateGroupModal-{{ $group->id }}" tabindex="-1" aria-labelledby="bulkUpdateGroupModalLabel-{{ $group->id }}" aria-hidden="true">
        <div class="modal-dialog modal-lg modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="bulkUpdateGroupModalLabel-{{ $group->id }}">
                        تحديث جماعي - {{ $group->name }}
                    </h5>
                    <button type="button" class="close" data-bs-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <form method="POST" action="{{ route('orders.payment-groups.bulk-update', $group) }}">
                    @csrf
                    <div class="modal-body">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="order_status_{{ $group->id }}">حالة الطلب</label>
                                    <select name="order_status" id="order_status_{{ $group->id }}" class="form-control">
                                        <option value="">بدون تغيير</option>
                                        @foreach ($statusOptions as $statusCode => $statusLabel)
                                            <option value="{{ $statusCode }}">{{ $statusLabel }}</option>
                                        @endforeach
                                    </select>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="notification_title_{{ $group->id }}">عنوان الإشعار (اختياري)</label>
                                    <input type="text" id="notification_title_{{ $group->id }}" name="notification_title" class="form-control" maxlength="190">
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="notes_{{ $group->id }}">ملاحظات الطلب</label>
                                    <textarea name="notes" id="notes_{{ $group->id }}" rows="3" class="form-control"></textarea>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-group">
                                    <label for="comment_{{ $group->id }}">تعليق سجل الحالة</label>
                                    <textarea name="comment" id="comment_{{ $group->id }}" rows="3" class="form-control"></textarea>
                                </div>
                            </div>
                            <div class="col-12">
                                <div class="form-group">
                                    <label for="notification_message_{{ $group->id }}">نص الإشعار للعملاء</label>
                                    <textarea name="notification_message" id="notification_message_{{ $group->id }}" rows="3" class="form-control"></textarea>
                                    <small class="form-text text-muted">سيتم إرسال هذا النص لجميع العملاء المرتبطين بالطلبات المختارة عند تفعيل خيار الإشعار.</small>
                                </div>
                            </div>
                            <div class="col-12">
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" value="1" id="notify_customer_{{ $group->id }}" name="notify_customer">
                                    <label class="form-check-label" for="notify_customer_{{ $group->id }}">
                                        إشعار جميع العملاء المرتبطين بهذه المجموعة
                                    </label>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">إلغاء</button>
                        <button type="submit" class="btn btn-primary">تطبيق التحديث</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
@endforeach

<div class="modal fade" id="createPaymentGroupModal" tabindex="-1" aria-labelledby="createPaymentGroupModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="createPaymentGroupModalLabel">إنشاء مجموعة جديدة</h5>
                <button type="button" class="close" data-bs-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <form action="{{ route('orders.payment-groups.store', $order) }}" method="POST">
                @csrf
                <div class="modal-body">
                    <div class="form-group">
                        <label for="group_name">اسم المجموعة</label>
                        <input type="text" id="group_name" name="name" class="form-control" value="{{ old('name') }}" required maxlength="190">
                    </div>
                    <div class="form-group">
                        <label for="group_note">ملاحظة (اختياري)</label>
                        <textarea id="group_note" name="note" rows="3" class="form-control" maxlength="1000">{{ old('note') }}</textarea>
                    </div>
                    <p class="small text-muted mb-0">سيتم إضافة هذا الطلب تلقائياً إلى المجموعة الجديدة بعد إنشائها.</p>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">إلغاء</button>
                    <button type="submit" class="btn btn-primary">إنشاء المجموعة</button>
                </div>
            </form>
        </div>
    </div>
</div>