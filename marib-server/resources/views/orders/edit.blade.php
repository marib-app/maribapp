@extends('layouts.main')

@php
    use App\Models\ManualPaymentRequest;
@endphp

@section('title', 'تعديل الطلب #' . $order->order_number)

@section('content')
<div class="container-fluid">

    @php
        $statusDisplayMap = \App\Models\Order::statusDisplayMap();
        $manualPaymentStatusLabels = [
            ManualPaymentRequest::STATUS_PENDING => 'قيد المراجعة',
            ManualPaymentRequest::STATUS_UNDER_REVIEW => 'قيد المراجعة',
            ManualPaymentRequest::STATUS_APPROVED => 'مدفوع (يدوي)',
            ManualPaymentRequest::STATUS_REJECTED => 'مرفوض',
        ];
        $manualPaymentStatusBadgeClasses = [
            ManualPaymentRequest::STATUS_PENDING => 'bg-warning text-dark',
            ManualPaymentRequest::STATUS_UNDER_REVIEW => 'bg-warning text-dark',
            ManualPaymentRequest::STATUS_APPROVED => 'bg-success',
            ManualPaymentRequest::STATUS_REJECTED => 'bg-danger',
        ];


        $manualPaymentStatusAlertClasses = [
            ManualPaymentRequest::STATUS_PENDING => 'alert-warning',
            ManualPaymentRequest::STATUS_UNDER_REVIEW => 'alert-warning',
            ManualPaymentRequest::STATUS_APPROVED => 'alert-success',
            ManualPaymentRequest::STATUS_REJECTED => 'alert-danger',
        ];
        $latestManualPaymentRequest = $latestManualPaymentRequest ?? ($order->manualPaymentRequests->first() ?? null);


        $orderUser = $order->user;
        $orderUserFallbackLabel = $order->user_id ? ('مستخدم #' . $order->user_id) : 'غير متوفر';
        $orderUserName = $orderUser?->name ?? $orderUserFallbackLabel;
        $orderUserEmail = $orderUser?->email;
        $orderUserMobile = $orderUser?->mobile;
        $orderUserProfileUrl = $orderUser ? route('customer.show', $orderUser->getKey()) : null;


    @endphp

    <div class="row">
        <div class="col-md-12 mb-3">
            <div class="d-flex justify-content-between align-items-center">
                <h2>تعديل الطلب #{{ $order->order_number }}</h2>
                <div>
                    <a href="{{ route('orders.show', $order->id) }}" class="btn btn-info">
                        <i class="fa fa-eye"></i> عرض الطلب
                    </a>
             
                </div>
            </div>
        </div>
    </div>

    <div class="col-md-12">
        <div class="card">
            <div class="card-header">
                <h4 class="card-title">سجل الطلب</h4>
            </div>
            <div class="card-body">
                @php
                    $timelineSteps = collect($statusDisplayMap)
                        ->map(static fn (array $config, string $code) => $config + ['code' => $code])
                        ->reject(static fn (array $config) => (bool) ($config['reserve'] ?? false))
                        ->values();

                    $normalizeStatus = static function ($status) {
                        if ($status === null) {
                            return null;
                        }

                        return \Illuminate\Support\Str::of($status)
                            ->trim()
                            ->lower()
                            ->replace('-', '_')
                            ->replace(' ', '_')
                            ->value();
                    };

                    $historyStatuses = $order->history
                        ->pluck('status_to')
                        ->map($normalizeStatus)
                        ->filter()
                        ->unique()
                        ->values();

                    $timestampStatuses = collect($order->status_timestamps ?? [])
                        ->keys()
                        ->map($normalizeStatus)
                        ->filter()
                        ->unique()
                        ->values();

                    $currentStatusCode = $normalizeStatus($order->order_status);



                    $currentStepIndex = 0;
                    foreach ($timelineSteps as $index => $step) {
                        $code = $step['code'];

                        if ($historyStatuses->contains($code) || $timestampStatuses->contains($code) || $currentStatusCode === $code) {
                            $currentStepIndex = $index;
                        }
                    }
                @endphp

                <div class="d-flex justify-content-between align-items-center mb-4 mt-4">
                    @foreach($timelineSteps as $index => $step)
                        <div class="step text-center">
                            <div class="circle {{ $index <= $currentStepIndex ? 'active' : '' }}">{{ $index + 1 }}</div>
                            <div class="label d-flex align-items-center justify-content-center gap-1">
                                @if(! empty($step['icon']))
                                    <i class="{{ $step['icon'] }}"></i>
                                @endif
                                <span>{{ $step['label'] }}</span>
                            </div>
                        
                        </div>
                        @if($index < $timelineSteps->count() - 1)
                            <div class="line"></div>
                        @endif
                    @endforeach
                </div>
            </div>
        </div>
    </div>





    <form action="{{ route('orders.update', $order->id) }}" method="POST" id="orderForm">
        @csrf
        @method('PUT')


        @php
            $selectedStatus = old('order_status', $order->order_status);
            $showTrackingFields = in_array($selectedStatus, [
                \App\Models\Order::STATUS_OUT_FOR_DELIVERY,
                \App\Models\Order::STATUS_DELIVERED,
            ], true);
            $showDeliveryProofFields = $selectedStatus === \App\Models\Order::STATUS_DELIVERED;
            $paymentStatusLocked = true;
            $orderStatusLocked = $pendingManualPaymentRequest !== null;
            $statusLabel = \App\Models\Order::statusLabel($order->order_status);
            $latestManualPaymentRequest = $latestManualPaymentRequest ?? $order->manualPaymentRequests->first();
            $manualPaymentStatus = $latestManualPaymentRequest?->status;
            $manualPaymentStatusLabelValue = $manualPaymentStatus
                ? ($manualPaymentStatusLabels[$manualPaymentStatus] ?? $manualPaymentStatus)
                : null;
            $manualPaymentBadgeClass = $manualPaymentStatus
                ? ($manualPaymentStatusBadgeClasses[$manualPaymentStatus] ?? 'bg-secondary')
                : null;

            $paymentStatusLabel = $manualPaymentStatusLabelValue
                ?? ($paymentStatusOptions[$order->payment_status] ?? ($order->payment_status ?: 'غير محدد'));

            $canChangeOrderStatus = $order->hasSuccessfulPayment() && ! $orderStatusLocked;
            $orderStatusLockMessage = null;

            if (! $order->hasSuccessfulPayment()) {
                $orderStatusLockMessage = 'لا يمكن تعديل حالة الطلب قبل تأكيد الدفع بنجاح.';
            } elseif ($orderStatusLocked) {
                $orderStatusLockMessage = 'لا يمكن تعديل حالة الطلب حتى يتم اعتماد الدفعة من خلال فريق المدفوعات.';
            }

        @endphp

        <div class="row">
            <!-- معلومات الطلب الأساسية -->
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header">
                        <h4 class="card-title">معلومات الطلب الأساسية</h4>
                    </div>
                    <div class="card-body">
                        <div class="form-group">
                            <label for="order_status">حالة الطلب</label>
                            @if($canChangeOrderStatus)
                                <select class="form-control" id="order_status" name="order_status" required>
                                    @foreach($orderStatuses as $status)
                                        @php
                                            $statusCode = (string) $status->code;
                                            $statusConfig = $statusDisplayMap[$statusCode] ?? null;
                                            $optionLabel = $status->name;
                                            if (! is_string($optionLabel) || trim($optionLabel) === '') {
                                                $optionLabel = $statusCode !== ''
                                                    ? (data_get($statusConfig, 'label', \Illuminate\Support\Str::of($statusCode)->replace('_', ' ')->headline()))
                                                    : 'غير مسمى';
                                            }
                                            $statusIcon = $status->icon ?: data_get($statusConfig, 'icon');
                                            $statusColor = $status->color ?: '#6c757d';
                                            $isReserveStatus = (bool) $status->is_reserve
                                                || (bool) data_get($statusConfig, 'reserve', false);
                                            $isCurrentStatus = $order->order_status == $statusCode;
                                        @endphp
                                        <option value="{{ $statusCode }}" {{ $isCurrentStatus ? 'selected' : '' }}
                                            style="color: {{ $statusColor }}"
                                            data-icon="{{ $statusIcon }}"
                                            data-reserve="{{ $isReserveStatus ? '1' : '0' }}"
                                            {{ $isReserveStatus && ! $isCurrentStatus ? 'disabled' : '' }}>
                                            {{ $optionLabel }}{{ $isReserveStatus ? ' (احتياطي)' : '' }}
                                        </option>
                                    @endforeach
                                </select>
                            @else
                                <div class="form-control-plaintext border rounded bg-light px-3 py-2">
                                    {{ $statusLabel ?: '—' }}
                                </div>
                                <input type="hidden" name="order_status" value="{{ $order->order_status }}">
                                @if($orderStatusLockMessage)
                                    <small class="text-muted d-block mt-2">{{ $orderStatusLockMessage }}</small>
                                @endif
                            @endif

                            <div class="form-check mt-2">
                                <input class="form-check-input" type="checkbox" id="enable_reserve_statuses">
                                <label class="form-check-label" for="enable_reserve_statuses">
                                    السماح باستخدام المراحل الاحتياطية في هذا التحديث
                                </label>
                            </div>
                            <small class="form-text text-muted" id="order-status-icon-preview"></small>

                            @error('order_status')
                                <span class="text-danger">{{ $message }}</span>
                            @enderror
                        </div>

                        <div class="form-group">
                            <label class="form-label">حالة الدفع</label>
                            <div class="form-control-plaintext border rounded bg-light px-3 py-2">
                                @if($manualPaymentStatusLabelValue)
                                    <span class="badge {{ $manualPaymentBadgeClass ?? 'bg-secondary' }}">{{ $manualPaymentStatusLabelValue }}</span>
                                @else
                                    {{ $paymentStatusLabel ?? '—' }}
                                @endif
                            
                            </div>
                            <small class="text-muted d-block mt-2">يتم تحديث حالة الدفع حصراً من خلال واجهة طلبات الدفع.</small>

                        </div>

                        <div class="form-group">
                            <label for="shipping_address">عنوان الشحن</label>
                            <textarea class="form-control" id="shipping_address" name="shipping_address" rows="3">{{ old('shipping_address', $order->shipping_address) }}</textarea>
                            @error('shipping_address')
                                <span class="text-danger">{{ $message }}</span>
                            @enderror
                        </div>

                        <div class="form-group">
                            <label for="notes">ملاحظات</label>
                            <textarea class="form-control" id="notes" name="notes" rows="3">{{ old('notes', $order->notes) }}</textarea>
                            @error('notes')
                                <span class="text-danger">{{ $message }}</span>
                            @enderror
                        </div>


                        <div id="tracking-fields" class="{{ $showTrackingFields ? '' : 'd-none' }}">
                            <hr>
                            <h5 class="mb-3">معلومات التتبع</h5>
                            <div class="form-group">
                                <label for="carrier_name">شركة الشحن</label>
                                <input type="text" class="form-control" id="carrier_name" name="carrier_name"
                                       value="{{ old('carrier_name', $order->carrier_name) }}" {{ $showTrackingFields ? '' : 'disabled' }}>
                                @error('carrier_name')
                                    <span class="text-danger">{{ $message }}</span>
                                @enderror
                            </div>
                            <div class="form-group">
                                <label for="tracking_number">رقم التتبع</label>
                                <input type="text" class="form-control" id="tracking_number" name="tracking_number"
                                       value="{{ old('tracking_number', $order->tracking_number) }}" {{ $showTrackingFields ? '' : 'disabled' }}>
                                @error('tracking_number')
                                    <span class="text-danger">{{ $message }}</span>
                                @enderror
                            </div>
                            <div class="form-group">
                                <label for="tracking_url">رابط التتبع</label>
                                <input type="url" class="form-control" id="tracking_url" name="tracking_url"
                                       value="{{ old('tracking_url', $order->tracking_url) }}" {{ $showTrackingFields ? '' : 'disabled' }}>
                                <small class="form-text text-muted">سيظهر هذا الرابط للمستخدم لتتبع الشحنة.</small>
                                @error('tracking_url')
                                    <span class="text-danger">{{ $message }}</span>
                                @enderror
                            </div>
                        </div>

                        <div id="delivery-proof-fields" class="{{ $showDeliveryProofFields ? '' : 'd-none' }}">
                            <hr>
                            <h5 class="mb-3">إثبات التسليم</h5>
                            <div class="form-group">
                                <label for="delivery_proof_image_path">رابط صورة التسليم</label>
                                <input type="text" class="form-control" id="delivery_proof_image_path" name="delivery_proof_image_path"
                                       value="{{ old('delivery_proof_image_path', $order->delivery_proof_image_path) }}" {{ $showDeliveryProofFields ? '' : 'disabled' }}>
                                @error('delivery_proof_image_path')
                                    <span class="text-danger">{{ $message }}</span>
                                @enderror
                            </div>
                            <div class="form-group">
                                <label for="delivery_proof_signature_path">رابط التوقيع</label>
                                <input type="text" class="form-control" id="delivery_proof_signature_path" name="delivery_proof_signature_path"
                                       value="{{ old('delivery_proof_signature_path', $order->delivery_proof_signature_path) }}" {{ $showDeliveryProofFields ? '' : 'disabled' }}>
                                @error('delivery_proof_signature_path')
                                    <span class="text-danger">{{ $message }}</span>
                                @enderror
                            </div>
                            <div class="form-group">
                                <label for="delivery_proof_otp_code">رمز OTP للتسليم</label>
                                <input type="text" class="form-control" id="delivery_proof_otp_code" name="delivery_proof_otp_code" maxlength="64"
                                       value="{{ old('delivery_proof_otp_code', $order->delivery_proof_otp_code) }}" {{ $showDeliveryProofFields ? '' : 'disabled' }}>
                                @error('delivery_proof_otp_code')
                                    <span class="text-danger">{{ $message }}</span>
                                @enderror
                            </div>
                        </div>

                    </div>
                </div>
            </div>

            <!-- معلومات العميل والتحديث -->
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header">
                        <h4 class="card-title">معلومات العميل</h4>
                    </div>
                    <div class="card-body">
                        <table class="table table-bordered">
                            <tr>
                                <th style="width: 30%">الاسم</th>
                                <td>
                                    @if($orderUserProfileUrl)
                                        <a href="{{ $orderUserProfileUrl }}">
                                            {{ $orderUserName }}
                                        </a>
                                    @else
                                        {{ $orderUserName }}
                                    @endif

                                </td>
                            </tr>
                            <tr>
                                <th>البريد الإلكتروني</th>
                                <td>{{ $orderUserEmail ?? 'غير متوفر' }}</td>
                            </tr>
                            <tr>
                                <th>رقم الهاتف</th>
                                <td>{{ $orderUserMobile ?? 'غير متوفر' }}</td>
                            </tr>
                        </table>
                    </div>
                </div>

                <div class="card mt-4">
                    <div class="card-header">
                        <h4 class="card-title">تعليق التحديث</h4>
                    </div>
                    <div class="card-body">
                        <div class="form-group">
                            <label for="comment">تعليق على التحديث</label>
                            <textarea class="form-control" id="comment" name="comment" rows="3">{{ old('comment') }}</textarea>
                            <small class="form-text text-muted">هذا التعليق سيظهر في سجل الطلب</small>
                            @error('comment')
                                <span class="text-danger">{{ $message }}</span>
                            @enderror
                        </div>

                        <div class="form-check mb-3">
                            <input class="form-check-input" type="checkbox" id="notify_customer" name="notify_customer" value="1" {{ old('notify_customer') ? 'checked' : '' }}>
                            <label class="form-check-label" for="notify_customer">
                                إشعار العميل بالتحديث
                            </label>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row mt-4">
            <!-- عناصر الطلب (للعرض فقط) -->
            <div class="col-md-12">
                <div class="card">
                    <div class="card-header">
                        <h4 class="card-title">عناصر الطلب</h4>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-bordered table-striped">
                                <thead>
                                    <tr>
                                        <th>#</th>
                                        <th>المنتج</th>
                                        <th>السعر</th>
                                        <th>الكمية</th>
                                        <th>المجموع الفرعي</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($order->items as $index => $item)
                                        <tr>
                                            <td>{{ $index + 1 }}</td>
                                            <td>{{ $item->item_name }}</td>
                                            <td>{{ number_format($item->price, 2) }}</td>
                                            <td>{{ $item->quantity }}</td>
                                            <td>{{ number_format($item->subtotal, 2) }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="5" class="text-center">لا توجد عناصر</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                                <tfoot>
                                    <tr>
                                        <th colspan="4" class="text-left">المجموع</th>
                                        <th>{{ number_format($order->total_amount, 2) }}</th>
                                    </tr>
                                    <tr>
                                        <th colspan="4" class="text-left">الضريبة (15%)</th>
                                        <th>{{ number_format($order->tax_amount, 2) }}</th>
                                    </tr>
                                    <tr>
                                        <th colspan="4" class="text-left">الخصم</th>
                                        <th>{{ number_format($order->discount_amount, 2) }}</th>
                                    </tr>
                                    <tr>
                                        <th colspan="4" class="text-left">المجموع النهائي</th>
                                        <th>{{ number_format($order->final_amount, 2) }}</th>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                        <div class="alert alert-info mt-3">
                            <i class="fa fa-info-circle"></i> ملاحظة: لتعديل عناصر الطلب، يرجى حذف هذا الطلب وإنشاء طلب جديد.
                        </div>
                    </div>
                </div>
            </div>
        </div>

  
        <div class="row mt-4">
            <div class="col-md-12">
                <div class="card">
                    <div class="card-body">
                        <div class="d-flex justify-content-center">
                            <button type="submit" class="btn btn-primary btn-lg">
                                <i class="fa fa-save"></i> حفظ التغييرات
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </form>
</div>
@endsection


@push('scripts')
<script>
    document.addEventListener('DOMContentLoaded', function () {
        const statusSelect = document.getElementById('order_status');
        const reserveToggle = document.getElementById('enable_reserve_statuses');
        const preview = document.getElementById('order-status-icon-preview');
        const trackingSection = document.getElementById('tracking-fields');
        const proofSection = document.getElementById('delivery-proof-fields');


        if (!statusSelect || !preview) {
            return;
        }

        const refreshPreview = () => {
            const option = statusSelect.options[statusSelect.selectedIndex];

            if (!option) {
                preview.textContent = '';
                return;
            }

            const icon = option.dataset.icon || '';
            const label = option.textContent.trim();

            if (icon) {
                preview.innerHTML = `<i class="${icon} me-1"></i>${label}`;
            } else {
                preview.textContent = label;
            }
        };


        const toggleSection = (section, show) => {
            if (!section) {
                return;
            }

            section.classList.toggle('d-none', !show);

            section.querySelectorAll('input, textarea, select').forEach((element) => {
                element.disabled = !show;
            });
        };

        const refreshTrackingVisibility = () => {
            const status = statusSelect.value;
            const showTracking = ['out_for_delivery', 'delivered'].includes(status);
            const showProof = status === 'delivered';

            toggleSection(trackingSection, showTracking);
            toggleSection(proofSection, showProof);
        };



        const syncReserveOptions = () => {
            const enabled = reserveToggle && reserveToggle.checked;

            Array.from(statusSelect.options).forEach((option) => {
                if (option.dataset.reserve === '1') {
                    if (!enabled && option.value !== statusSelect.value) {
                        option.disabled = true;
                    } else {
                        option.disabled = false;
                    }
                }
            });
        };

        if (reserveToggle) {
            if (statusSelect.selectedOptions[0]?.dataset.reserve === '1') {
                reserveToggle.checked = true;
            }

            reserveToggle.addEventListener('change', () => {
                syncReserveOptions();

                const selectedOption = statusSelect.selectedOptions[0];
                if (!reserveToggle.checked && selectedOption?.dataset.reserve === '1') {
                    selectedOption.disabled = false;
                }
            });
        }

        statusSelect.addEventListener('change', () => {
            syncReserveOptions();
            refreshPreview();
            refreshTrackingVisibility();


        });

        syncReserveOptions();
        refreshPreview();
        refreshTrackingVisibility();


    });
</script>
@endpush


<style>
    .step {
        text-align: center;
    }
    .circle {
        width: 30px;
        height: 30px;
        background: #ddd;
        border-radius: 50%;
        display: inline-block;
        line-height: 30px;
        color: #fff;
        font-weight: bold;
    }
    .circle.active {
        background: #007bff;
    }
    .line {
        flex-grow: 1;
        height: 2px;
        background: #ddd;
    }
    .label {
        font-size: 12px;
        margin-top: 5px;
    }
    .d-flex {
        display: flex;
    }
    .justify-content-between {
        justify-content: space-between;
    }
    .align-items-center {
        align-items: center;
    }
    </style>