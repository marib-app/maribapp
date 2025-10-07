@extends('layouts.app')
@section('title', 'تقرير حالات الطلبات')

@section('content')
<section class="section">
    <div class="dashboard_title mb-3">تقرير حالات الطلبات</div>

    <!-- فلتر البحث -->
    <div class="row mb-4">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">فلتر التقرير</h3>
                </div>
                <div class="card-body">
                    <form action="{{ route('reports.statuses') }}" method="GET" id="filterForm">
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
            </div
        </div>
    </div>

    <!-- رسم بياني لحالات الطلبات -->
    <div class="row">
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">توزيع حالات الطلبات</h3>
                </div>
                <div class="card-body">
                    <div class="chart">
                        <canvas id="statusDistributionChart" style="min-height: 300px; height: 300px; max-height: 300px; max-width: 100%;"></canvas>
                    </div>
                </div>
            </div>
        </div>
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">توزيع المبيعات حسب الحالة</h3>
                </div>
                <div class="card-body">
                    <div class="chart">
                        <canvas id="statusAmountChart" style="min-height: 300px; height: 300px; max-height: 300px; max-width: 100%;"></canvas>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- جدول حالات الطلبات -->
    <div class="row">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">تقرير حالات الطلبات</h3>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-bordered">
                            <thead>
                                <tr>
                                    <th style="width: 15%">الحالة</th>
                                    <th style="width: 10%">عدد الطلبات</th>
                                    <th style="width: 10%">النسبة المئوية</th>
                                    <th style="width: 15%">إجمالي المبيعات</th>
                                    <th style="width: 15%">متوسط قيمة الطلب</th>
                                    <th style="width: 20%">آخر طلب</th>
                                    <th style="width: 15%">الإجراءات</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($statusStats as $stat)
                                    <tr>
                                        <td>
                                            <div class="d-flex align-items-center">
                                                <span class="status-dot me-2" style="width: 12px; height: 12px; border-radius: 50%; display: inline-block; background-color: {{ $stat['status']->color }}"></span>
                                                <span>{{ $stat['status']->name }}</span>
                                            </div>
                                        </td>
                                        <td class="text-center">{{ number_format($stat['count']) }}</td>
                                        <td class="text-center">
                                            @if($totalOrders > 0)
                                                {{ number_format(($stat['count'] / $totalOrders) * 100, 1) }}%
                                            @else
                                                0%
                                            @endif
                                        </td>
                                        <td class="text-center">{{ number_format($stat['amount'], 2) }} ريال</td>
                                        <td class="text-center">
                                            {{ $stat['count'] > 0 ? number_format($stat['amount'] / $stat['count'], 2) : 0 }} ريال
                                        </td>
                                        <td>
                                            @if($stat['orders']->isNotEmpty())
                                                @php $lastOrder = $stat['orders']->first(); @endphp
                                                <div>
                                                    <a href="{{ route('orders.show', $lastOrder->id) }}" class="text-primary">
                                                        #{{ $lastOrder->order_number }}
                                                    </a>
                                                    <br>
                                                    <small class="text-muted">{{ $lastOrder->created_at->format('Y-m-d H:i') }}</small>
                                                </div>
                                            @else
                                                <span class="text-muted">لا يوجد طلبات</span>
                                            @endif
                                        </td>
                                        <td class="text-center">
                                            <a href="{{ route('orders.index', ['order_status' => $stat['status']->code, 'date_from' => $startDate, 'date_to' => $endDate]) }}" 
                                               class="btn btn-sm btn-info">
                                                <i class="fa fa-eye"></i> عرض الطلبات
                                            </a>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="7" class="text-center">لا توجد بيانات للعرض</td>
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
$(function () {
    // رسم بياني لتوزيع حالات الطلبات
    const statusDistributionCtx = document.getElementById('statusDistributionChart').getContext('2d');
    const statusDistributionData = {
        labels: [
            @foreach($statusStats as $stat)
                '{{ $stat['status']->name }}',
            @endforeach
        ],
        datasets: [{
            data: [
                @foreach($statusStats as $stat)
                    {{ $stat['count'] }},
                @endforeach
            ],
            backgroundColor: [
                @foreach($statusStats as $stat)
                    '{{ $stat['status']->color }}',
                @endforeach
            ]
        }]
    };
    new Chart(statusDistributionCtx, {
        type: 'doughnut',
        data: statusDistributionData,
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'right',
                }
            }
        }
    });

    // رسم بياني لتوزيع المبيعات حسب الحالة
    const statusAmountCtx = document.getElementById('statusAmountChart').getContext('2d');
    const statusAmountData = {
        labels: [
            @foreach($statusStats as $stat)
                '{{ $stat['status']->name }}',
            @endforeach
        ],
        datasets: [{
            data: [
                @foreach($statusStats as $stat)
                    {{ $stat['amount'] }},
                @endforeach
            ],
            backgroundColor: [
                @foreach($statusStats as $stat)
                    '{{ $stat['status']->color }}',
                @endforeach
            ]
        }]
    };
    new Chart(statusAmountCtx, {
        type: 'pie',
        data: statusAmountData,
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'right',
                }
            }
        }
    });

    // إعادة تعيين الفلتر
    $('#resetFilter').on('click', function() {
        window.location.href = "{{ route('reports.statuses') }}";
    });
});
</script>
@endsection 