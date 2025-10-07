@extends('layouts.app')
@section('title', 'تقرير المبيعات')

@section('content')
<section class="section">
    <div class="dashboard_title mb-3">تقرير المبيعات</div>

    <!-- فلتر البحث -->
    <div class="row mb-4">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">فلتر التقرير</h3>
                </div>
                <div class="card-body">
                    <form action="{{ route('reports.sales') }}" method="GET" id="filterForm">
                        <div class="row">
                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="start_date">من تاريخ</label>
                                    <input type="date" class="form-control" id="start_date" name="start_date" value="{{ $startDate }}">
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="form-group">
                                    <label for="end_date">إلى تاريخ</label>
                                    <input type="date" class="form-control" id="end_date" name="end_date" value="{{ $endDate }}">
                                </div>
                            </div>
                            <div class="col-md-4 d-flex align-items-end">
                                <div class="form-group">
                                    <button type="submit" class="btn btn-primary">
                                        <i class="fa fa-search"></i> عرض التقرير
                                    </button>
                             
                                </div>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <!-- ملخص المبيعات -->
    <div class="row mb-3">
        <div class="col-md-12 col-sm-12">
            <div class="row">
                <div class="col-md-4 col-sm-6 mb-3">
                    <div class="card h-100">
                        <div class="total_customer d-flex">
                            <div class="curtain"></div>
                            <div class="row">
                                <div class="col-4 col-md-12 ">
                                    <div class="svg_icon align-items-center d-flex justify-content-center me-3">
                                        <span class="fas fa-money-bill-wave text-white fa-2x"></span>
                                    </div>
                                </div>
                                <div class="col-8 col-md-12">
                                    <div class="total_number">{{ number_format($totalSales, 2) }}</div>
                                    <div class="card_title">إجمالي المبيعات</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="col-md-4 col-sm-6 mb-3">
                    <div class="card h-100">
                        <div class="total_items d-flex">
                            <div class="curtain"></div>
                            <div class="row">
                                <div class="col-4 col-md-12 ">
                                    <div class="svg_icon align-items-center d-flex justify-content-center me-3">
                                        <span class="fas fa-shopping-cart text-white fa-2x"></span>
                                    </div>
                                </div>
                                <div class="col-8 col-md-12">
                                    <div class="total_number">{{ $totalOrders }}</div>
                                    <div class="card_title">عدد الطلبات</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="col-md-4 col-sm-6 mb-3">
                    <div class="card h-100">
                        <div class="item_for_sale d-flex">
                            <div class="curtain"></div>
                            <div class="row">
                                <div class="col-4 col-md-12 ">
                                    <div class="svg_icon align-items-center d-flex justify-content-center me-3">
                                        <span class="fas fa-chart-line text-white fa-2x"></span>
                                    </div>
                                </div>
                                <div class="col-8 col-md-12">
                                    <div class="total_number">{{ number_format($averageOrderValue, 2) }}</div>
                                    <div class="card_title">متوسط قيمة الطلب</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- رسم بياني للمبيعات -->
    <div class="row">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">المبيعات اليومية</h3>
                </div>
                <div class="card-body">
                    <div class="chart">
                        <canvas id="salesChart" style="min-height: 300px; height: 300px; max-height: 300px; max-width: 100%;"></canvas>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- تفاصيل المبيعات -->
    <div class="row">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">تفاصيل المبيعات</h3>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-bordered" aria-describedby="mydesc">
                            <thead>
                                <tr class="bg-light">
                                    <th style="width: 30%" class="text-center">التاريخ</th>
                                    <th style="width: 35%" class="text-center">عدد الطلبات</th>
                                    <th style="width: 35%" class="text-center">إجمالي المبيعات</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($salesStats as $stat)
                                    <tr>
                                        <td class="text-center">
                                            <span class="text-primary">{{ \Carbon\Carbon::parse($stat->date)->format('Y-m-d') }}</span>
                                        </td>
                                        <td class="text-center">
                                            <span class="badge bg-info">{{ number_format($stat->total_orders) }}</span>
                                        </td>
                                        <td class="text-center">
                                            <strong>{{ number_format($stat->total_amount, 2) }}</strong>
                                            <small class="text-muted">ريال</small>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="3" class="text-center py-3">
                                            <span class="text-muted">لا توجد بيانات للعرض</span>
                                        </td>
                                    </tr>
                                @endforelse
                                @if($salesStats->isNotEmpty())
                                    <tr class="bg-light">
                                        <td class="text-center">
                                            <strong>الإجمالي</strong>
                                        </td>
                                        <td class="text-center">
                                            <strong>{{ number_format($salesStats->sum('total_orders')) }}</strong>
                                        </td>
                                        <td class="text-center">
                                            <strong>{{ number_format($salesStats->sum('total_amount'), 2) }}</strong>
                                            <small class="text-muted">ريال</small>
                                        </td>
                                    </tr>
                                @endif
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
$(function () {
    // رسم بياني للمبيعات
    const salesCtx = document.getElementById('salesChart').getContext('2d');
    const salesData = {
        labels: [
            @foreach($salesStats as $stat)
                '{{ $stat->date }}',
            @endforeach
        ],
        datasets: [
            {
                label: 'إجمالي المبيعات',
                backgroundColor: 'rgba(60,141,188,0.9)',
                borderColor: 'rgba(60,141,188,0.8)',
                pointRadius: true,
                pointColor: '#3b8bba',
                pointStrokeColor: 'rgba(60,141,188,1)',
                pointHighlightFill: '#fff',
                pointHighlightStroke: 'rgba(60,141,188,1)',
                data: [
                    @foreach($salesStats as $stat)
                        {{ $stat->total_amount }},
                    @endforeach
                ]
            }
        ]
    };
    new Chart(salesCtx, {
        type: 'bar',
        data: salesData,
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
                    },
                    beginAtZero: true
                }
            }
        }
    });

    // إعادة تعيين الفلتر
    $('#resetFilter').on('click', function() {
        window.location.href = "{{ route('reports.sales') }}";
    });
});
</script>
@endsection 