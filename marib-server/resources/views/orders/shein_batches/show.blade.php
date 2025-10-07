@extends('layouts.main')

@section('title', __('إدارة دفعة شي إن :ref', ['ref' => $batch->reference]))

@section('content')
<div class="container-fluid">
    <div class="row">
        <div class="col-lg-4">
            <div class="card mb-3">
                <div class="card-header">
                    <h5 class="card-title mb-0">{{ __('تفاصيل الدفعة') }}</h5>
                </div>
                <div class="card-body">
                    <dl class="row mb-0">
                        <dt class="col-5">{{ __('المرجع') }}</dt>
                        <dd class="col-7">{{ $batch->reference }}</dd>
                        <dt class="col-5">{{ __('التاريخ') }}</dt>
                        <dd class="col-7">{{ optional($batch->batch_date)->format('Y-m-d') ?? __('غير محدد') }}</dd>
                        <dt class="col-5">{{ __('الحالة الحالية') }}</dt>
                        <dd class="col-7">{{ __($batch->status) }}</dd>
                        <dt class="col-5">{{ __('الودائع') }}</dt>
                        <dd class="col-7">{{ number_format($batch->deposit_amount ?? 0, 2) }}</dd>
                        <dt class="col-5">{{ __('البواقي') }}</dt>
                        <dd class="col-7">{{ number_format($batch->outstanding_amount ?? 0, 2) }}</dd>
                        <dt class="col-5">{{ __('آخر تحديث') }}</dt>
                        <dd class="col-7">{{ optional($batch->updated_at)->format('Y-m-d H:i') }}</dd>
                    </dl>
                </div>
            </div>

            <div class="card mb-3">
                <div class="card-header">
                    <h5 class="card-title mb-0">{{ __('تعديل الدفعة') }}</h5>
                </div>
                <form action="{{ route('item.shein.batches.update', $batch) }}" method="POST">
                    @csrf
                    @method('PUT')
                    <div class="card-body">
                        <div class="form-group">
                            <label for="batch_date">{{ __('تاريخ الدفعة') }}</label>
                            <input type="date" name="batch_date" id="batch_date" class="form-control" value="{{ old('batch_date', optional($batch->batch_date)->format('Y-m-d')) }}">
                        </div>
                        <div class="form-group">
                            <label for="status">{{ __('الحالة') }}</label>
                            <select name="status" id="status" class="form-control">
                                @foreach(\App\Models\SheinOrderBatch::statuses() as $status)
                                    <option value="{{ $status }}" {{ old('status', $batch->status) === $status ? 'selected' : '' }}>{{ __($status) }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div class="form-group">
                            <label for="deposit_amount">{{ __('قيمة الوديعة') }}</label>
                            <input type="number" step="0.01" min="0" id="deposit_amount" name="deposit_amount" class="form-control" value="{{ old('deposit_amount', $batch->deposit_amount) }}">
                        </div>
                        <div class="form-group">
                            <label for="outstanding_amount">{{ __('البواقي الحالية') }}</label>
                            <input type="number" step="0.01" id="outstanding_amount" name="outstanding_amount" class="form-control" value="{{ old('outstanding_amount', $batch->outstanding_amount) }}">
                        </div>
                        <div class="form-group">
                            <label for="batch_notes">{{ __('ملاحظات الدفعة') }}</label>
                            <textarea id="batch_notes" name="notes" rows="3" class="form-control">{{ old('notes', $batch->notes) }}</textarea>
                        </div>
                        <div class="form-group">
                            <label for="closed_at">{{ __('تاريخ الإغلاق') }}</label>
                            <input type="datetime-local" id="closed_at" name="closed_at" class="form-control" value="{{ old('closed_at', optional($batch->closed_at)->format('Y-m-d\TH:i')) }}">
                        </div>
                    </div>
                    <div class="card-footer text-right">
                        <button type="submit" class="btn btn-primary">{{ __('حفظ التعديلات') }}</button>
                    </div>
                </form>
            </div>
        </div>

        <div class="col-lg-8">
            <div class="card mb-3">
                <div class="card-header">
                    <h5 class="card-title mb-0">{{ __('إضافة طلبات إلى الدفعة') }}</h5>
                </div>
                <form action="{{ route('item.shein.batches.assign-orders', $batch) }}" method="POST">
                    @csrf
                    <div class="card-body">
                        <div class="form-group">
                            <label for="order_ids">{{ __('اختر الطلبات المتاحة (آخر 50 طلب)') }}</label>
                            <select multiple class="form-control" id="order_ids" name="order_ids[]" size="8">
                                @foreach($availableOrders as $order)
                                    <option value="{{ $order->id }}">
                                        {{ $order->order_number }} - {{ optional($order->user)->name ?? __('عميل غير معروف') }} ({{ number_format($order->final_amount ?? 0, 2) }})
                                    </option>
                                @endforeach
                            </select>
                        </div>
                        <small class="text-muted">{{ __('يمكنك تحديد أكثر من طلب بالضغط على زر التحكم أثناء التحديد.') }}</small>
                    </div>
                    <div class="card-footer text-right">
                        <button type="submit" class="btn btn-success">{{ __('إضافة الطلبات') }}</button>
                    </div>
                </form>
            </div>

            <div class="card">
                <div class="card-header d-flex justify-content-between align-items-center">
                    <h5 class="card-title mb-0">{{ __('طلبات الدفعة الحالية') }}</h5>
                    <span class="badge badge-info">{{ __('إجمالي الطلبات: :count', ['count' => $orders->total()]) }}</span>
                </div>
                <form action="{{ route('item.shein.batches.bulk-update', $batch) }}" method="POST">
                    @csrf
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover mb-0">
                                <thead>
                                    <tr>
                                        <th width="40"><input type="checkbox" id="select-all"></th>
                                        <th>{{ __('رقم الطلب') }}</th>
                                        <th>{{ __('العميل') }}</th>
                                        <th>{{ __('الحالة') }}</th>
                                        <th>{{ __('القيمة النهائية') }}</th>
                                        <th>{{ __('المحصل') }}</th>
                                        <th>{{ __('آخر تحديث') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($orders as $order)
                                        <tr>
                                            <td>
                                                <input type="checkbox" name="order_ids[]" value="{{ $order->id }}">
                                            </td>
                                            <td>{{ $order->order_number }}</td>
                                            <td>{{ optional($order->user)->name ?? __('غير محدد') }}</td>
                                            <td>
                                                @php
                                                    $statusConfig = $statusLabels[$order->order_status] ?? null;
                                                    $statusLabel = data_get($statusConfig, 'label', $order->order_status);
                                                    $statusIcon = data_get($statusConfig, 'icon');
                                                    $statusTimeline = data_get($statusConfig, 'timeline');
                                                    $isReserveStatus = (bool) data_get($statusConfig, 'reserve', false);
                                                @endphp
                                                <span class="badge bg-light text-dark border d-inline-flex align-items-center gap-1"
                                                    @if($statusTimeline) title="{{ $statusTimeline }}" @endif>
                                                    @if($statusIcon)
                                                        <i class="{{ $statusIcon }}"></i>
                                                    @endif
                                                    <span>{{ $statusLabel }}</span>
                                                    @if($isReserveStatus)
                                                        <span class="ms-1 small fw-semibold">احتياطي</span>
                                                    @endif
                                                </span>
                                            </td>
                                            
                                            <td>{{ number_format($order->final_amount ?? 0, 2) }}</td>
                                            <td>{{ number_format($order->delivery_collected_amount ?? 0, 2) }}</td>
                                            <td>{{ optional($order->updated_at)->format('Y-m-d H:i') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="7" class="text-center py-4">{{ __('لا توجد طلبات في هذه الدفعة بعد.') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                    <div class="card-footer">
                        <div class="row">
                            <div class="col-md-4">
                                <div class="form-group mb-2">
                                    <label for="order_status">{{ __('تحديث الحالة') }}</label>
                                    <select name="order_status" id="order_status" class="form-control">
                                        <option value="">{{ __('بدون تغيير') }}</option>
                                        @foreach($orderStatuses as $status)
                                            @php
                                                $statusConfig = $statusLabels[$status] ?? null;
                                                $statusLabel = data_get($statusConfig, 'label', $status);
                                                $statusIcon = data_get($statusConfig, 'icon');
                                                $isReserveStatus = (bool) data_get($statusConfig, 'reserve', false);
                                            @endphp
                                            <option value="{{ $status }}" data-icon="{{ $statusIcon }}"
                                                data-reserve="{{ $isReserveStatus ? '1' : '0' }}">
                                                {{ $statusLabel }}{{ $isReserveStatus ? ' (احتياطي)' : '' }}
                                            </option>
                                            
                                            @endforeach
                                    </select>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="form-group mb-2">
                                    <label for="bulk_notes">{{ __('تحديث الملاحظات') }}</label>
                                    <textarea name="notes" id="bulk_notes" class="form-control" rows="2"></textarea>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="form-group mb-2">
                                    <label for="comment">{{ __('تعليق سجل الحالة') }}</label>
                                    <textarea name="comment" id="comment" class="form-control" rows="2"></textarea>
                                </div>
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" value="1" id="notify_customer" name="notify_customer">
                                    <label class="form-check-label" for="notify_customer">
                                        {{ __('إشعار العميل بالتحديث') }}
                                    </label>
                                </div>
                            </div>
                        </div>
                        <div class="text-right">
                            <button type="submit" class="btn btn-primary">{{ __('تطبيق التغييرات') }}</button>
                        </div>
                    </div>
                </form>
                @if($orders instanceof \Illuminate\Pagination\LengthAwarePaginator)
                    <div class="card-footer border-top">
                        {{ $orders->links() }}
                    </div>
                @endif
            </div>
        </div>
    </div>
</div>
@endsection

@section('scripts')
<script>
    document.getElementById('select-all')?.addEventListener('change', function (event) {
        document.querySelectorAll('input[name="order_ids[]"]').forEach(function (checkbox) {
            checkbox.checked = event.target.checked;
        });
    });
</script>
@endsection