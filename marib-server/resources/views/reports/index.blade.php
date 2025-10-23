@extends('layouts.app')

@section('title', 'تقارير النظام')

@section('content')
<section class="section">
    <div class="dashboard_title mb-3">تقارير النظام</div>


    <div class="mb-3">
        <ul class="nav nav-pills gap-2 flex-wrap">
            <li class="nav-item">
                <a class="nav-link active" href="{{ route('reports.index') }}">
                    <i class="fas fa-chart-pie me-1"></i>
                    التقارير العامة
                </a>
            </li>
            @foreach($departmentSnapshots as $departmentData)
                <li class="nav-item">
                    <a class="nav-link" href="{{ $departmentData['route'] }}">
                        <i class="fas fa-layer-group me-1"></i>
                        {{ $departmentData['label'] }}
                    </a>
                </li>
            @endforeach
        </ul>
    </div>

    @if($departmentSnapshots->isNotEmpty())
        <div class="row mb-4">
            @foreach($departmentSnapshots as $departmentData)
                <div class="col-md-4 col-sm-6 mb-3">
                    <div class="card h-100">
                        <div class="card-body">
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <h5 class="mb-0">{{ $departmentData['label'] }}</h5>
                                <a href="{{ $departmentData['route'] }}" class="btn btn-sm btn-outline-primary">عرض التفاصيل</a>
                            </div>
                            <div class="row text-center">
                                <div class="col-4">
                                    <div class="fw-bold">{{ $departmentData['snapshot']['total_orders'] }}</div>
                                    <div class="text-muted small">إجمالي الطلبات</div>
                                </div>
                                <div class="col-4">
                                    <div class="fw-bold">{{ number_format($departmentData['snapshot']['total_sales'], 2) }}</div>
                                    <div class="text-muted small">المبيعات</div>
                                </div>
                                <div class="col-4">
                                    <div class="fw-bold">{{ $departmentData['snapshot']['open_tickets'] }}</div>
                                    <div class="text-muted small">بلاغات مفتوحة</div>
                                </div>
                            </div>
                            <div class="mt-3 d-flex justify-content-between">
                                <span class="badge bg-success">تم {{ $departmentData['snapshot']['delivered_orders'] }}</span>
                                <span class="badge bg-warning text-dark">قيد المعالجة {{ $departmentData['snapshot']['processing_orders'] }}</span>
                            </div>
                        </div>
                    </div>
                </div>
            @endforeach
        </div>
    @endif

    <div class="row mb-3 d-flex">
        <div class="col-md-12 col-sm-12">
            <div class="row">
                <div class="col-md-3 col-sm-6 mb-3">
                    <a href="{{ route('orders.index') }}">
                        <div class="card h-100">
                            <div class="total_customer d-flex">
                                <div class="curtain"></div>
                                <div class="row">
                                    <div class="col-4 col-md-12 ">
                                        <div class="svg_icon align-items-center d-flex justify-content-center me-3">
                                            <span class="fas fa-shopping-cart text-white fa-2x"></span>
                                        </div>
                                    </div>
                                    <div class="col-8 col-md-12">
                                        <div class="total_number">{{ $stats['total'] }}</div>
                                        <div class="card_title">إجمالي الطلبات</div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </a>
                </div>

                <div class="col-md-3 col-sm-6 mb-3">
                    <a href="{{ route('reports.sales') }}">
                        <div class="card h-100">
                            <div class="total_items d-flex">
                                <div class="curtain"></div>
                                <div class="row">
                                    <div class="col-4 col-md-12 ">
                                        <div class="svg_icon align-items-center d-flex justify-content-center me-3">
                                            <span class="fas fa-money-bill-wave text-white fa-2x"></span>
                                        </div>
                                    </div>
                                    <div class="col-8 col-md-12">
                                        <div class="total_number">{{ number_format($stats['total_sales'], 2) }}</div>
                                        <div class="card_title">إجمالي المبيعات</div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </a>
                </div>

                <div class="col-md-3 col-sm-6 mb-3">
                    <a href="{{ route('orders.index', ['order_status' => 'processing']) }}">
                        <div class="card h-100">
                            <div class="item_for_sale d-flex">
                                <div class="curtain"></div>
                                <div class="row">
                                    <div class="col-4 col-md-12 ">
                                        <div class="svg_icon align-items-center d-flex justify-content-center me-3">
                                            <span class="fas fa-clock text-white fa-2x"></span>
                                        </div>
                                    </div>
                                    <div class="col-8 col-md-12">
                                        <div class="total_number">{{ $stats['processing'] }}</div>
                                        <div class="card_title">الطلبات قيد المعالجة</div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </a>
                </div>

                <div class="col-md-3 col-sm-6 mb-3">
                    <a href="{{ route('orders.index', ['date_from' => date('Y-m-d'), 'date_to' => date('Y-m-d')]) }}">
                        <div class="card h-100">
                            <div class="properties_for_rent d-flex">
                                <div class="curtain"></div>
                                <div class="row">
                                    <div class="col-4 col-md-12 ">
                                        <div class="svg_icon align-items-center d-flex justify-content-center me-3">
                                            <span class="fas fa-calendar-day text-white fa-2x"></span>
                                        </div>
                                    </div>
                                    <div class="col-8 col-md-12">
                                        <div class="total_number">{{ $stats['today'] }}</div>
                                        <div class="card_title">طلبات اليوم</div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </a>
                </div>
            </div>
        </div>
    </div>

    <div class="row">
        <!-- إحصائيات الطلبات حسب الحالة -->
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">الطلبات حسب الحالة</h3>
                </div>
                <div class="card-body">
                    <canvas id="ordersByStatusChart" style="min-height: 250px; height: 250px; max-height: 250px; max-width: 100%;"></canvas>
                </div>
                <div class="card-footer bg-light">
                    <div class="row">
                        @foreach($ordersByStatus as $status)
                            <div class="col-sm-4 col-6">
                                <div class="description-block border-right">
                                    <h5 class="description-header text-primary">{{ $status->total }}</h5>
                                    <span class="description-text">{{ $status->order_status }}</span>
                                </div>
                            </div>
                        @endforeach
                    </div>
                </div>
            </div>
        </div>

        <!-- إحصائيات الطلبات حسب طريقة الدفع -->
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">الطلبات حسب طريقة الدفع</h3>
                </div>
                <div class="card-body">
                    <canvas id="ordersByPaymentMethodChart" style="min-height: 250px; height: 250px; max-height: 250px; max-width: 100%;"></canvas>
                </div>
                <div class="card-footer bg-light">
                    <div class="row">
                        @foreach($ordersByPaymentMethod as $method)
                            <div class="col-sm-4 col-6">
                                <div class="description-block border-right">
                                    <h5 class="description-header text-primary">{{ $method->total }}</h5>
                                    <span class="description-text">{{ $method->payment_gateway_label ?? $method->bank_name ?? ($method->payment_method ?: 'غير محدد') }}</span>
                                </div>
                            </div>
                        @endforeach
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="row">
        <!-- إحصائيات الطلبات اليومية -->
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">الطلبات اليومية (آخر 30 يوم)</h3>
                </div>
                <div class="card-body">
                    <div class="chart">
                        <canvas id="ordersByDayChart" style="min-height: 300px; height: 300px; max-height: 300px; max-width: 100%;"></canvas>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="row">
        <!-- أكثر العملاء طلبًا -->
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">أكثر العملاء طلبًا</h3>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-bordered" aria-describedby="mydesc">
                            <thead>
                                <tr class="bg-light">
                                    <th style="width: 5%" class="text-center">#</th>
                                    <th style="width: 25%">العميل</th>
                                    <th style="width: 15%">رقم الهاتف</th>
                                    <th style="width: 15%" class="text-center">عدد الطلبات</th>
                                    <th style="width: 20%" class="text-center">إجمالي المبلغ</th>
                                    <th style="width: 20%" class="text-center">الإجراءات</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($topCustomers as $index => $customer)
                                    <tr>
                                        <td class="text-center">{{ $index + 1 }}</td>
                                        <td>
                                            <div class="d-flex align-items-center">
                                                <div class="me-2">
                                                    <span class="fas fa-user-circle fa-2x text-secondary"></span>
                                                </div>
                                                <div>
                                                    <a href="{{ route('customer.show', $customer->id) }}" class="text-primary">
                                                        {{ $customer->name }}
                                                    </a>
                                                    @if($customer->email)
                                                        <br>
                                                        <small class="text-muted">{{ $customer->email }}</small>
                                                    @endif
                                                </div>
                                            </div>
                                        </td>
                                        <td>
                                            @if($customer->mobile)
                                                <span class="text-nowrap">
                                                    <i class="fas fa-phone-alt text-secondary me-1"></i>
                                                    {{ $customer->mobile }}
                                                </span>
                                            @else
                                                <span class="text-muted">غير متوفر</span>
                                            @endif
                                        </td>
                                        <td class="text-center">
                                            <span class="badge bg-info">
                                                {{ number_format($customer->total_orders) }}
                                            </span>
                                        </td>
                                        <td class="text-center">
                                            <strong>{{ number_format($customer->total_amount, 2) }}</strong>
                                            <small class="text-muted">ريال</small>
                                        </td>
                                        <td class="text-center">
                                            <a href="{{ route('orders.index', ['user_id' => $customer->id]) }}" 
                                               class="btn btn-sm btn-primary">
                                                <i class="fas fa-shopping-cart me-1"></i>
                                                عرض الطلبات
                                            </a>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="6" class="text-center py-3">
                                            <span class="text-muted">لا توجد بيانات للعرض</span>
                                        </td>
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

@section('styles')
<style>
    .small-box {
        border-radius: 10px;
        box-shadow: 0 0 15px rgba(0,0,0,0.1);
        transition: transform 0.3s;
    }
    .small-box:hover {
        transform: translateY(-5px);
    }
    .card {
        border-radius: 10px;
        overflow: hidden;
        margin-bottom: 25px;
    }
    .card-header {
        background-color: #343a40;
        color: white;
        border-bottom: 0;
    }
    .description-header {
        font-weight: 600;
    }
    .table thead th {
        background-color: #f8f9fa;
        color: #333;
        font-weight: 600;
    }
    .btn-primary {
        background-color: #3c8dbc;
        border-color: #3c8dbc;
    }
    .btn-primary:hover {
        background-color: #367fa9;
        border-color: #367fa9;
    }
</style>
@endsection

@section('scripts')
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
$(function () {
    // تحديد ألوان احترافية للرسوم البيانية
    const chartColors = [
        '#3c8dbc', '#00a65a', '#f39c12', '#00c0ef', '#605ca8', '#d81b60', '#3d9970', '#39cccc', '#01ff70', '#ff851b'
    ];
    
    // إحصائيات الطلبات حسب الحالة
    const statusCtx = document.getElementById('ordersByStatusChart').getContext('2d');
    const statusData = {
        labels: [
            @foreach($ordersByStatus as $status)
                '{{ $status->order_status }}',
            @endforeach
        ],
        datasets: [{
            data: [
                @foreach($ordersByStatus as $status)
                    {{ $status->total }},
                @endforeach
            ],
            backgroundColor: chartColors,
            borderWidth: 1
        }]
    };
    new Chart(statusCtx, {
        type: 'doughnut',
        data: statusData,
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'right',
                    labels: {
                        boxWidth: 15,
                        padding: 15
                    }
                },
                tooltip: {
                    backgroundColor: 'rgba(0,0,0,0.7)',
                    padding: 10,
                    titleFont: {
                        size: 14
                    },
                    bodyFont: {
                        size: 13
                    }
                }
            },
            cutout: '60%',
            animation: {
                animateScale: true,
                animateRotate: true
            }
        }
    });

    // إحصائيات الطلبات حسب طريقة الدفع
    const paymentMethodCtx = document.getElementById('ordersByPaymentMethodChart').getContext('2d');
    const paymentMethodData = {
        labels: [
            @foreach($ordersByPaymentMethod as $method)
                '{{ $method->payment_gateway_label ?? $method->bank_name ?? ($method->payment_method ?: "غير محدد") }}',
            @endforeach
        ],
        datasets: [{
            data: [
                @foreach($ordersByPaymentMethod as $method)
                    {{ $method->total }},
                @endforeach
            ],
            backgroundColor: chartColors,
            borderWidth: 1
        }]
    };
    new Chart(paymentMethodCtx, {
        type: 'pie',
        data: paymentMethodData,
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'right',
                    labels: {
                        boxWidth: 15,
                        padding: 15
                    }
                },
                tooltip: {
                    backgroundColor: 'rgba(0,0,0,0.7)',
                    padding: 10,
                    titleFont: {
                        size: 14
                    },
                    bodyFont: {
                        size: 13
                    }
                }
            },
            animation: {
                animateScale: true,
                animateRotate: true
            }
        }
    });

    // إحصائيات الطلبات اليومية
    const dayCtx = document.getElementById('ordersByDayChart').getContext('2d');
    const dayData = {
        labels: [
            @foreach($ordersByDay as $day)
                '{{ $day->date }}',
            @endforeach
        ],
        datasets: [
            {
                label: 'عدد الطلبات',
                backgroundColor: 'rgba(60,141,188,0.3)',
                borderColor: 'rgba(60,141,188,1)',
                pointRadius: 4,
                pointColor: '#3b8bba',
                pointStrokeColor: 'rgba(60,141,188,1)',
                pointHighlightFill: '#fff',
                pointHighlightStroke: 'rgba(60,141,188,1)',
                borderWidth: 2,
                fill: true,
                data: [
                    @foreach($ordersByDay as $day)
                        {{ $day->total }},
                    @endforeach
                ]
            },
            {
                label: 'المبلغ الإجمالي',
                backgroundColor: 'rgba(0,166,90,0.3)',
                borderColor: 'rgba(0,166,90,1)',
                pointRadius: 4,
                pointColor: '#00a65a',
                pointStrokeColor: '#00a65a',
                pointHighlightFill: '#fff',
                pointHighlightStroke: 'rgba(0,166,90,1)',
                borderWidth: 2,
                fill: true,
                data: [
                    @foreach($ordersByDay as $day)
                        {{ $day->amount }},
                    @endforeach
                ]
            }
        ]
    };
    new Chart(dayCtx, {
        type: 'line',
        data: dayData,
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: {
                    grid: {
                        display: false,
                    }
                },
                y: {
                    grid: {
                        display: true,
                        color: 'rgba(0,0,0,0.05)',
                    },
                    beginAtZero: true
                }
            },
            plugins: {
                tooltip: {
                    backgroundColor: 'rgba(0,0,0,0.7)',
                    padding: 10,
                    titleFont: {
                        size: 14
                    },
                    bodyFont: {
                        size: 13
                    }
                }
            },
            interaction: {
                mode: 'index',
                intersect: false,
            },
            elements: {
                line: {
                    tension: 0.4
                }
            }
        }
    });
});
</script>
@endsection
