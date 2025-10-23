@extends('layouts.main')


@php
    use App\Models\ManualPaymentRequest;
@endphp

@section('title', 'إدارة طلبات قسم الكمبيوتر')

@section('styles')
<style>
    .pagination {
        margin: 0;
    }
    .pagination .page-item .page-link {
        padding: 0.5rem 0.75rem;
        color: #3c8dbc;
        background-color: #fff;
        border: 1px solid #dee2e6;
        margin: 0 2px;
    }
    .pagination .page-item.active .page-link {
        background-color: #3c8dbc;
        border-color: #3c8dbc;
        color: #fff;
    }
    .pagination .page-item.disabled .page-link {
        color: #6c757d;
        pointer-events: none;
        background-color: #fff;
        border-color: #dee2e6;
    }
    .pagination .page-link:hover {
        color: #fff;
        background-color: #3c8dbc;
        border-color: #3c8dbc;
    }
    .pagination .page-link:focus {
        box-shadow: 0 0 0 0.2rem rgba(60, 141, 188, 0.25);
    }

    .offcanvas-search-filters {
        --bs-offcanvas-width: min(90vw, 400px);
        z-index: 1056;
    }

    @media (min-width: 992px) {
        .offcanvas-search-filters {
            --bs-offcanvas-width: 480px;
        }
    }

    .filter-trigger-btn {
        min-width: 180px;
    }

</style>
@endsection

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

    @endphp

    <div class="row">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header">
                    <h4 class="card-title">إدارة طلبات قسم الكمبيوتر</h4>
                </div>
                <div class="card-body">
                    <!-- فلاتر البحث -->
                    <div class="row mb-4">
                        <div class="col-12 d-flex justify-content-end">
                            <button class="btn btn-outline-primary filter-trigger-btn" type="button"
                                data-bs-toggle="offcanvas" data-bs-target="#filtersOffcanvas"
                                aria-controls="filtersOffcanvas">
                                <i class="fa fa-filter me-2"></i>
                                خيارات البحث
                            </button>
                        </div>
                    </div>

                    <div class="offcanvas offcanvas-end offcanvas-search-filters" tabindex="-1"
                        id="filtersOffcanvas" aria-labelledby="filtersOffcanvasLabel">
                        <div class="offcanvas-header">
                            <h5 class="offcanvas-title" id="filtersOffcanvasLabel">خيارات البحث والتصفية</h5>
                            <button type="button" class="btn-close text-reset" data-bs-dismiss="offcanvas"
                                aria-label="إغلاق"></button>
                        </div>
                        <div class="offcanvas-body">
                            <form action="{{ route('item.computer.orders') }}" method="GET">
                                <div class="row g-3">
                                    <div class="col-12 col-md-6 col-lg-12">
                                        <div class="form-group">
                                            <label for="search">بحث</label>
                                            <input type="text" class="form-control" id="search" name="search"
                                                placeholder="رقم الطلب، اسم العميل..." value="{{ request('search') }}">
                                        </div>
                                    </div>
                                    <div class="col-12 col-md-6 col-lg-12">
                                        <div class="form-group">
                                            <label for="user_id">العميل</label>
                                            <select class="form-control select2" id="user_id" name="user_id">
                                                <option value="">جميع العملاء</option>
                                                @foreach($users as $user)
                                                    <option value="{{ $user->id }}" {{ request('user_id') == $user->id ? 'selected' : '' }}>
                                                        {{ $user->name }} ({{ $user->mobile ?? 'بدون رقم' }})
                                                    </option>
                                                @endforeach
                                            </select>
                                        </div>
                                    </div>


                                    <div class="col-12 col-lg-12">
                                        <div class="form-group">
                                            <label for="order_status">حالة الطلب</label>
                                            <select class="form-control" id="order_status" name="order_status">
                                                <option value="">جميع الحالات</option>
                                                @foreach($orderStatuses as $status)
                                                    @php
                                                        $statusCode = optional($status)->code;
                                                        $statusColor = optional($status)->color ?: '#6c757d';
                                                        $statusConfig = $statusCode ? ($statusDisplayMap[$statusCode] ?? null) : null;
                                                        $statusLabel = optional($status)->name;
                                                        if (! is_string($statusLabel) || trim($statusLabel) === '') {
                                                            $statusLabel = $statusCode
                                                                ? (data_get($statusConfig, 'label', \Illuminate\Support\Str::of($statusCode)->replace('_', ' ')->headline()))
                                                                : 'غير مسمى';
                                                        }
                                                        $statusIcon = optional($status)->icon ?: data_get($statusConfig, 'icon');
                                                        $isReserveStatus = (bool) optional($status)->is_reserve
                                                            || (bool) data_get($statusConfig, 'reserve', false);
                                                    @endphp
                                                    <option value="{{ $statusCode ?? '' }}" {{ request('order_status') == $statusCode ? 'selected' : '' }}
                                                        style="color: {{ $statusColor }}"
                                                        data-icon="{{ $statusIcon }}"
                                                        data-reserve="{{ $isReserveStatus ? '1' : '0' }}">
                                                        {{ $statusLabel }}{{ $isReserveStatus ? ' (احتياطي)' : '' }}
                                                    </option>
                                                @endforeach
                                            </select>
                                            <div class="form-check mt-2">
                                                <input class="form-check-input" type="checkbox" value="1" id="include_reserve_statuses"
                                                    name="include_reserve_statuses" {{ request()->boolean('include_reserve_statuses') ? 'checked' : '' }}>
                                                <label class="form-check-label" for="include_reserve_statuses">
                                                    عرض المراحل الاحتياطية
                                                </label>



                                        
                                            </div>
                                        </div>
                                    </div>
                                    <div class="col-12 col-md-6 col-lg-12">
                                        <div class="form-group">
                                            <label for="payment_status">حالة الدفع</label>
                                            <select class="form-control" id="payment_status" name="payment_status">
                                                <option value="">جميع الحالات</option>
                                                <option value="pending" {{ request('payment_status') == 'pending' ? 'selected' : '' }}>قيد الانتظار</option>
                                                <option value="paid" {{ request('payment_status') == 'paid' ? 'selected' : '' }}>مدفوع</option>
                                                <option value="partial" {{ request('payment_status') == 'partial' ? 'selected' : '' }}>مدفوع جزئياً</option>
                                                <option value="payment_partial" {{ request('payment_status') == 'payment_partial' ? 'selected' : '' }}>مدفوع جزئياً</option>

                                                <option value="refunded" {{ request('payment_status') == 'refunded' ? 'selected' : '' }}>مسترجع</option>
                                            </select>
                                        </div>
                                    </div>
                                    <div class="col-12 col-md-6 col-lg-12">
                                        <div class="form-group">
                                            <label for="date_from">من تاريخ</label>
                                            <input type="date" class="form-control" id="date_from" name="date_from" value="{{ request('date_from') }}">
                                        </div>
                                    </div>
                                    <div class="col-12 col-md-6 col-lg-12">
                                        <div class="form-group">
                                            <label for="date_to">إلى تاريخ</label>
                                            <input type="date" class="form-control" id="date_to" name="date_to" value="{{ request('date_to') }}">
                                        </div>
                                    </div>
                                    <div class="col-12">
                                        <div class="d-grid">
                                            <button type="submit" class="btn btn-primary">
                                                <i class="fa fa-search me-2"></i> بحث
                                            </button>
                                     
                                        </div>
                 
                                    </div>
                                </div>
                           </form>
                        </div>
                    </div>

                    <!-- جدول الطلبات -->

                    @php
                        $paymentStatusLabels = [
                            'pending' => 'قيد الانتظار',
                            'paid' => 'مدفوع',
                            'partial' => 'مدفوع جزئياً',
                            'payment_partial' => 'مدفوع جزئياً',
                            'refunded' => 'مسترجع',
                        ];

                        $paymentStatusBadgeClasses = [
                            'pending' => 'bg-warning',
                            'paid' => 'bg-success',
                            'partial' => 'bg-primary',
                            'payment_partial' => 'bg-primary',
                            'refunded' => 'bg-info',
                        ];
                    @endphp

                    <div class="table-responsive">
                        <table class="table table-bordered table-striped">
                            <thead>
                                <tr>
                                    <th>#</th>
                                    <th>رقم الطلب</th>
                                    <th>العميل</th>
                                    <th>التاجر</th>
                                    <th>الفئة</th>
                                    <th>المبلغ الإجمالي</th>
                                    <th>سعر التوصيل</th>
                                    <th>المسافة</th>
                                    <th>حجم الطلب</th>
                                    <th>طريقة الدفع</th>
                                    <th>حالة الدفع</th>
                                    <th>حالة الطلب</th>
                                    <th>تاريخ الطلب</th>
                                    <th>الإجراءات</th>
                                </tr>
                            </thead>
                            <tbody>

                                @php
                                    $resolvedCategoryIds = $categoryIds ?? [];
                                    $departmentSlug = $department ?? null;
                                @endphp

                                @php
                                    $resolvedCategoryIds = $categoryIds ?? [];
                                    $departmentSlug = $department ?? null;
                                @endphp

                                @forelse($orders as $order)
                                    <tr>
                                        <td>{{ $order->id }}</td>
                                        <td>{{ $order->order_number }}</td>
                                        <td>
                                            @if($order->user)
                                                <a href="{{ route('customer.show', $order->user_id) }}">
                                                    {{ $order->user->name }} <br>
                                                    <small>{{ $order->user->mobile ?? 'بدون رقم' }}</small>
                                                </a>
                                            @else
                                                <span class="text-muted">غير متوفر</span>
                                            @endif
                                        </td>
                                        <td>
                                            @if($order->seller)
                                                <a href="{{ route('customer.show', $order->seller_id) }}">
                                                    {{ $order->seller->name }} <br>
                                                    <small>{{ $order->seller->mobile ?? 'بدون رقم' }}</small>
                                                </a>
                                            @else
                                                <span class="text-muted">غير متوفر</span>
                                            @endif
                                        </td>
                                        <td>
                                            @php
                                                $categories = [];
                                                $orderBelongsToDepartment = $departmentSlug && $order->department === $departmentSlug;


                                                foreach($order->items as $orderItem) {
                                                    if ($orderItem->item && $orderItem->item->category) {
                                                        $category = $orderItem->item->category;
                                                        $categoryId = $category->id;
                                                        $parentCategoryId = $category->parent_category_id;
                                                        $matchesResolvedCategories = in_array($categoryId, $resolvedCategoryIds, true)
                                                            || ($parentCategoryId !== null && in_array($parentCategoryId, $resolvedCategoryIds, true));

                                                        if ($matchesResolvedCategories || $orderBelongsToDepartment) {
                                                            $categories[$categoryId] = $category->name;
                                                        }
                                                    }
                                                }
                                            @endphp
                                            @if(count($categories) > 0)
                                                @foreach($categories as $categoryId => $categoryName)
                                                    <span class="badge badge-info">{{ $categoryName }}</span><br>
                                                @endforeach
                                            @else
                                                <span class="text-muted">غير متوفر</span>
                                            @endif
                                        </td>
                                        <td>{{ number_format($order->final_amount, 2) }}</td>
                                        <td>{{ $order->delivery_price ? number_format($order->delivery_price, 2) : '-' }}</td>
                                        <td>{{ $order->delivery_distance ? number_format($order->delivery_distance, 2) . ' كم' : '-' }}</td>
                                        <td>
                                            @if($order->delivery_size)
                                                @switch($order->delivery_size)
                                                    @case('small')
                                                        صغير
                                                        @break
                                                    @case('medium')
                                                        متوسط
                                                        @break
                                                    @case('large')
                                                        كبير
                                                        @break
                                                    @default
                                                        {{ $order->delivery_size }}
                                                @endswitch
                                            @else
                                                -
                                            @endif
                                        </td>
                                        <td>{{ $order->resolved_payment_gateway_label ?? 'غير محدد' }}</td>
                                        <td>
                                            @php
                                                $latestManualPaymentRequest = $order->latestManualPaymentRequest;
                                                $manualPaymentStatus = $latestManualPaymentRequest?->status;
                                                $manualPaymentStatusLabel = $manualPaymentStatus
                                                    ? ($manualPaymentStatusLabels[$manualPaymentStatus] ?? 'غير محدد')
                                                    : null;
                                                $manualPaymentStatusClass = $manualPaymentStatus
                                                    ? ($manualPaymentStatusBadgeClasses[$manualPaymentStatus] ?? 'bg-secondary')
                                                    : null;
                                                $manualPaymentLocked = $manualPaymentStatus !== null
                                                    && in_array($manualPaymentStatus, ManualPaymentRequest::OPEN_STATUSES, true);


                                                $paymentStatusValue = $order->payment_status;

                                                if ($manualPaymentStatusLabel !== null) {
                                                    $paymentStatusLabel = $manualPaymentStatusLabel;
                                                    $paymentStatusClass = $manualPaymentStatusClass ?? 'bg-secondary';
                                                } else {
                                                    $paymentStatusLabel = $paymentStatusValue
                                                        ? ($paymentStatusLabels[$paymentStatusValue] ?? 'غير معروف')
                                                        : 'غير محدد';
                                                    $paymentStatusClass = $paymentStatusValue
                                                        ? ($paymentStatusBadgeClasses[$paymentStatusValue] ?? 'bg-secondary')
                                                        : 'bg-secondary';
                                                }

                                            @endphp
                                            <span class="badge {{ $paymentStatusClass }}">{{ $paymentStatusLabel }}</span>



                                        </td>
                                        <td>
                                            @php
                                            $statusCollection = $orderStatuses instanceof \Illuminate\Support\Collection
                                                ? $orderStatuses
                                                : collect($orderStatuses);
                                            $matchedStatus = $statusCollection->firstWhere('code', $order->order_status);
                                            $statusDisplayEntry = $statusDisplayMap[$order->order_status] ?? null;
                                            $statusColor = optional($matchedStatus)->color ?: '#777777';
                                            $statusLabel = \App\Models\Order::statusLabel($order->order_status);
                                            $statusLabel = $statusLabel !== ''
                                                ? $statusLabel
                                                : (optional($matchedStatus)->name
                                                    ?? (is_array($statusDisplayEntry)
                                                        ? ($statusDisplayEntry['label'] ?? null)
                                                        : null)
                                                    ?? \Illuminate\Support\Str::of($order->order_status)->replace('_', ' ')->headline());
                                            $statusIconClass = \App\Models\Order::statusIcon($order->order_status);
                                            if (! $statusIconClass && is_array($statusDisplayEntry)) {
                                                $statusIconClass = $statusDisplayEntry['icon'] ?? null;
                                            }
                                            $statusTimelineMessage = \App\Models\Order::statusTimelineMessage($order->order_status)
                                                ?? (is_array($statusDisplayEntry) ? ($statusDisplayEntry['timeline'] ?? null) : null);
                                            $isReserveStatus = (bool) optional($matchedStatus)->is_reserve
                                                || (bool) (is_array($statusDisplayEntry) ? ($statusDisplayEntry['reserve'] ?? false) : false);
                                            $statusBadgeTitle = $statusTimelineMessage ?? '';
                                            if ($isReserveStatus) {
                                                $statusBadgeTitle = trim('مرحلة احتياطية' . ($statusBadgeTitle !== '' ? ' - ' . $statusBadgeTitle : ''));
                                            }
                                                @endphp
                                            <span class="badge d-inline-flex align-items-center gap-1"
                                                style="background-color: {{ $statusColor }}"
                                                @if($statusBadgeTitle !== '') title="{{ $statusBadgeTitle }}" @endif>
                                                @if($statusIconClass)
                                                    <i class="{{ $statusIconClass }}"></i>
                                                @endif
                                                <span>{{ $statusLabel }}</span>
                                                @if($isReserveStatus)
                                                    <span class="ms-1 small fw-semibold">احتياطي</span>
                                                @endif
                                            </span>


                                        </td>
                                        <td>{{ $order->created_at->format('Y-m-d H:i') }}</td>
                                        <td>
                                            <div class="btn-group">
                                                <a href="{{ route('orders.show', $order->id) }}" class="btn btn-sm btn-info">
                                                    <i class="fa fa-eye"></i>
                                                </a>
                                                @if($manualPaymentLocked)
                                                    <span class="btn btn-sm btn-primary disabled" title="لا يمكن تعديل الطلب أثناء مراجعة الدفع" aria-disabled="true">
                                                        <i class="fa fa-edit"></i>
                                                    </span>
                                                @else
                                                    <a href="{{ route('orders.edit', $order->id) }}" class="btn btn-sm btn-primary">
                                                        <i class="fa fa-edit"></i>
                                                    </a>
                                                @endif
                                                @if($manualPaymentLocked)
                                                    <span class="btn btn-sm btn-danger disabled" title="لا يمكن حذف الطلب أثناء مراجعة الدفع" aria-disabled="true">
                                                        <i class="fa fa-trash"></i>
                                                    </span>
                                                @else
                                                    <button type="button" class="btn btn-sm btn-danger" data-bs-toggle="modal" data-bs-target="#deleteModal{{ $order->id }}">
                                                        <i class="fa fa-trash"></i>
                                                    </button>
                                                @endif
                                            </div>

                                            <!-- Modal for delete confirmation -->
                                            <div class="modal fade" id="deleteModal{{ $order->id }}" tabindex="-1" role="dialog" aria-labelledby="deleteModalLabel{{ $order->id }}" aria-hidden="true">
                                                <div class="modal-dialog" role="document">
                                                    <div class="modal-content">
                                                        <div class="modal-header">
                                                            <h5 class="modal-title" id="deleteModalLabel{{ $order->id }}">تأكيد الحذف</h5>
                                                            <button type="button" class="close" data-bs-dismiss="modal" aria-label="Close">
                                                                <span aria-hidden="true">&times;</span>
                                                            </button>
                                                        </div>
                                                        <div class="modal-body">
                                                            هل أنت متأكد من حذف الطلب رقم <strong>{{ $order->order_number }}</strong>؟
                                                        </div>
                                                        <div class="modal-footer">
                                                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">إلغاء</button>
                                                            <form action="{{ route('orders.destroy', $order->id) }}" method="POST" style="display: inline;">
                                                                @csrf
                                                                @method('DELETE')
                                                                <button type="submit" class="btn btn-danger">حذف</button>
                                                            </form>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="14" class="text-center">لا توجد طلبات لقسم الكمبيوتر</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>

                    <!-- الترقيم -->
                    @if($orders->hasPages())
                        <div class="card-footer">
                            <div class="d-flex justify-content-center">
                                <nav>
                                    <ul class="pagination pagination-sm mb-0">
                                        {{-- Previous Page Link --}}
                                        @if ($orders->onFirstPage())
                                            <li class="page-item disabled">
                                                <span class="page-link">«</span>
                                            </li>
                                        @else
                                            <li class="page-item">
                                                <a class="page-link" href="{{ $orders->previousPageUrl() }}" rel="prev">«</a>
                                            </li>
                                        @endif

                                        {{-- Pagination Elements --}}
                                        @foreach ($orders->getUrlRange(max(1, $orders->currentPage() - 2), min($orders->lastPage(), $orders->currentPage() + 2)) as $page => $url)
                                            @if ($page == $orders->currentPage())
                                                <li class="page-item active">
                                                    <span class="page-link">{{ $page }}</span>
                                                </li>
                                            @else
                                                <li class="page-item">
                                                    <a class="page-link" href="{{ $url }}">{{ $page }}</a>
                                                </li>
                                            @endif
                                        @endforeach

                                        {{-- Next Page Link --}}
                                        @if ($orders->hasMorePages())
                                            <li class="page-item">
                                                <a class="page-link" href="{{ $orders->nextPageUrl() }}" rel="next">»</a>
                                            </li>
                                        @else
                                            <li class="page-item disabled">
                                                <span class="page-link">»</span>
                                            </li>
                                        @endif
                                    </ul>
                                </nav>
                            </div>
                            <div class="text-center mt-2">
                                <small class="text-muted">
                                    عرض {{ $orders->firstItem() ?? 0 }} إلى {{ $orders->lastItem() ?? 0 }} من إجمالي {{ $orders->total() }} طلب
                                </small>
                            </div>
                        </div>
                    @endif
                </div>
            </div>
        </div>
    </div>
</div>
@endsection

@section('scripts')
<script>
    $(function () {
         const $offcanvas = $('#filtersOffcanvas');

        $('.select2').each(function () {
            const $select = $(this);
            const $parentOffcanvas = $select.closest('.offcanvas');
            $select.select2({
                dropdownParent: $parentOffcanvas.length ? $parentOffcanvas : $(document.body),
                width: '100%'
            });
        });

        if ($offcanvas.length) {
            $offcanvas.on('shown.bs.offcanvas', function () {
                $('.select2').each(function () {
                    $(this).select2('close');
                });
            });
        }
        
    });
</script>
@endsection 