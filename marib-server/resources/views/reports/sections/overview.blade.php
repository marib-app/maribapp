@extends('layouts.app')

@section('title', 'تقارير الأقسام المتخصصة')

@section('content')
<section class="section">
    <div class="dashboard_title mb-3">لوحة تقارير الأقسام</div>

    <div class="mb-3">
        <ul class="nav nav-pills gap-2 flex-wrap">
            <li class="nav-item">
                <a class="nav-link" href="{{ route('reports.index') }}">
                    <i class="fas fa-chart-pie me-1"></i>
                    التقارير العامة
                </a>
            </li>
            @foreach($departments as $key => $label)
                <li class="nav-item">
                    <a class="nav-link {{ $department === $key ? 'active' : '' }}" href="{{ $key === 'shein' ? route('item.shein.reports') : ($key === 'computer' ? route('item.computer.reports') : route('reports.index')) }}">
                        <i class="fas fa-layer-group me-1"></i>
                        {{ $label }}
                    </a>
                </li>
            @endforeach
        </ul>
    </div>

    <div class="row mb-4 g-3">
        <div class="col-md-3 col-sm-6">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body">
                    <div class="text-muted small">إجمالي الطلبات</div>
                    <div class="display-6 fw-bold">{{ $metrics['total_orders'] }}</div>
                    <div class="text-success">{{ $metrics['delivered_orders'] }} تم تسليمها</div>
                </div>
            </div>
        </div>
        <div class="col-md-3 col-sm-6">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body">
                    <div class="text-muted small">إجمالي المبيعات</div>
                    <div class="display-6 fw-bold">{{ number_format($metrics['total_sales'], 2) }}</div>
                    <div class="text-muted">متوسط الطلب {{ number_format($metrics['average_order_value'], 2) }}</div>
                </div>
            </div>
        </div>
        <div class="col-md-3 col-sm-6">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body">
                    <div class="text-muted small">إجمالي الدفعات</div>
                    <div class="display-6 fw-bold">{{ number_format($metrics['payments_total'], 2) }}</div>
                    <div class="text-muted">منتجات مباعة {{ $metrics['products_sold'] }}</div>
                </div>
            </div>
        </div>
        <div class="col-md-3 col-sm-6">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body">
                    <div class="text-muted small">العملاء النشطون</div>
                    <div class="display-6 fw-bold">{{ $metrics['unique_customers'] }}</div>
                    <div class="text-danger">بلاغات مفتوحة {{ $metrics['open_tickets'] }}</div>
                </div>
            </div>
        </div>
    </div>

    <div class="row g-3">
        <div class="col-lg-6">
            <div class="card h-100">
                <div class="card-header bg-white border-0 pb-0">
                    <h5 class="card-title mb-0">الطلبات حسب الحالة</h5>
                </div>
                <div class="card-body">
                    <canvas id="department-status-chart" height="220"></canvas>
                </div>
            </div>
        </div>
        <div class="col-lg-6">
            <div class="card h-100">
                <div class="card-header bg-white border-0 pb-0">
                    <h5 class="card-title mb-0">الطلبات حسب طريقة الدفع</h5>
                </div>
                <div class="card-body">
                    <canvas id="department-payment-chart" height="220"></canvas>
                </div>
            </div>
        </div>
    </div>

    <div class="row g-3 mt-2">
        <div class="col-12">
            <div class="card">
                <div class="card-header bg-white border-0 pb-0">
                    <h5 class="card-title mb-0">حركة المبيعات اليومية</h5>
                </div>
                <div class="card-body">
                    <canvas id="department-daily-chart" height="250"></canvas>
                </div>
            </div>
        </div>
    </div>

    <div class="row g-3 mt-2">
        <div class="col-12">
            <div class="card">
                <div class="card-header bg-white border-0 pb-0 d-flex justify-content-between align-items-center">
                    <h5 class="card-title mb-0">أحدث الطلبات في القسم</h5>
                    <a href="{{ route('orders.index', ['department' => $department]) }}" class="btn btn-sm btn-outline-primary">إدارة الطلبات</a>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-striped mb-0">
                            <thead class="bg-light">
                                <tr>
                                    <th>رقم الطلب</th>
                                    <th>العميل</th>
                                    <th>الحالة</th>
                                    <th class="text-center">القيمة</th>
                                    <th class="text-center">تاريخ الإنشاء</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($metrics['recent_orders'] as $order)
                                    <tr>
                                        <td><a href="{{ route('orders.show', $order->id) }}" class="text-primary">{{ $order->order_number ?? $order->id }}</a></td>
                                        <td>
                                            @if($order->user)
                                                <div class="fw-semibold">{{ $order->user->name }}</div>
                                                <small class="text-muted">{{ $order->user->mobile }}</small>
                                            @else
                                                <span class="text-muted">غير متوفر</span>
                                            @endif
                                        </td>
                                        <td>
                                            <span class="badge bg-{{ $order->order_status === 'delivered' ? 'success' : ($order->order_status === 'processing' ? 'warning text-dark' : 'secondary') }}">{{ $order->order_status }}</span>
                                        </td>
                                        <td class="text-center">{{ number_format($order->final_amount, 2) }}</td>
                                        <td class="text-center">{{ optional($order->created_at)->format('Y-m-d H:i') }}</td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="5" class="text-center text-muted">لا توجد طلبات حديثة للقسم.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</section>
@endsection

@section('scripts')
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
    const statusData = @json($metrics['orders_by_status']->map(fn($row) => ['label' => $row->order_status, 'total' => (int) $row->total]));
    const paymentData = @json($metrics['orders_by_payment_method']->map(fn($row) => [
        'label' => $row->payment_gateway_label ?: ($row->bank_name ?: ($row->payment_method ?: 'غير محدد')),
        'total' => (int) $row->total,
    ]));
    const dailyData = @json($metrics['daily_sales']->map(fn($row) => ['date' => $row->date, 'total_orders' => (int) $row->total_orders, 'total_amount' => (float) $row->total_amount]));

    const palette = ['#3c8dbc', '#00a65a', '#f39c12', '#00c0ef', '#605ca8', '#d81b60'];

    new Chart(document.getElementById('department-status-chart').getContext('2d'), {
        type: 'doughnut',
        data: {
            labels: statusData.map(item => item.label),
            datasets: [{
                data: statusData.map(item => item.total),
                backgroundColor: palette,
                borderWidth: 1
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { position: 'bottom' }
            },
            cutout: '60%'
        }
    });

    new Chart(document.getElementById('department-payment-chart').getContext('2d'), {
        type: 'pie',
        data: {
            labels: paymentData.map(item => item.label),
            datasets: [{
                data: paymentData.map(item => item.total),
                backgroundColor: palette,
                borderWidth: 1
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { position: 'bottom' }
            }
        }
    });

    new Chart(document.getElementById('department-daily-chart').getContext('2d'), {
        type: 'line',
        data: {
            labels: dailyData.map(item => item.date),
            datasets: [
                {
                    label: 'عدد الطلبات',
                    data: dailyData.map(item => item.total_orders),
                    borderColor: '#3c8dbc',
                    backgroundColor: 'rgba(60, 141, 188, 0.15)',
                    tension: 0.4,
                    fill: true,
                },
                {
                    label: 'قيمة المبيعات',
                    data: dailyData.map(item => item.total_amount),
                    borderColor: '#00a65a',
                    backgroundColor: 'rgba(0, 166, 90, 0.15)',
                    tension: 0.4,
                    fill: true,
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: true,
                }
            }
        }
    });
</script>
@endsection

@section('styles')
<style>
    .display-6 {
        font-size: 2.5rem;
    }
    .nav-pills .nav-link {
        border-radius: 50px;
    }
    .nav-pills .nav-link.active {
        background-color: #435ebe;
    }
</style>
@endsection