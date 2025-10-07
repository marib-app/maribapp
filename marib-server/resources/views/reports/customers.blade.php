@extends('layouts.app')

@section('title', 'تقرير العملاء')

@section('content')
<section class="section">
    <div class="dashboard_title mb-3">تقرير العملاء</div>

    <!-- فلتر البحث -->
    <div class="row mb-4">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">فلتر التقرير</h3>
                </div>
                <div class="card-body">
                    <form action="{{ route('reports.customers') }}" method="GET" id="filterForm">
                        <div class="row">
                            <div class="col-md-3">
                                <div class="form-group">
                                    <label for="start_date">من تاريخ</label>
                                    <input type="date" class="form-control" id="start_date" name="start_date" value="{{ $startDate }}">
                                </div>
                            </div>
                            <div class="col-md-3">
                                <div class="form-group">
                                    <label for="end_date">إلى تاريخ</label>
                                    <input type="date" class="form-control" id="end_date" name="end_date" value="{{ $endDate }}">
                                </div>
                            </div>
                            <div class="col-md-3">
                                <div class="form-group">
                                    <label for="name">اسم العميل</label>
                                    <input type="text" class="form-control" id="name" name="name" value="{{ request('name') }}" placeholder="ابحث باسم العميل">
                                </div>
                            </div>
                            <div class="col-md-3">
                                <div class="form-group">
                                    <label for="mobile">رقم الهاتف</label>
                                    <input type="text" class="form-control" id="mobile" name="mobile" value="{{ request('mobile') }}" placeholder="ابحث برقم الهاتف">
                                </div>
                            </div>
                        </div>
                        <div class="row mt-2">
                            <div class="col-md-12 d-flex justify-content-end">
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

    <!-- تقرير العملاء -->
    <div class="row">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">تقرير العملاء</h3>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-bordered" aria-describedby="mydesc">
                            <thead>
                                <tr class="bg-light">
                                    <th style="width: 5%" class="text-center">#</th>
                                    <th style="width: 20%">العميل</th>
                                    <th style="width: 15%">البريد الإلكتروني</th>
                                    <th style="width: 12%">رقم الهاتف</th>
                                    <th style="width: 12%" class="text-center">عدد الطلبات</th>
                                    <th style="width: 15%" class="text-center">إجمالي المبلغ</th>
                                    <th style="width: 13%" class="text-center">متوسط قيمة الطلب</th>
                                    <th style="width: 8%" class="text-center">الإجراءات</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($customers as $index => $customer)
                                    <tr>
                                        <td class="text-center align-middle">{{ $customers->firstItem() + $index }}</td>
                                        <td class="align-middle">
                                            <div class="d-flex align-items-center">
                                                <div class="me-2">
                                                    <span class="fas fa-user-circle fa-2x text-secondary"></span>
                                                </div>
                                                <div>
                                                    <a href="{{ route('customer.show', $customer->id) }}" class="text-primary">
                                                        {{ $customer->name }}
                                                    </a>
                                                </div>
                                            </div>
                                        </td>
                                        <td class="align-middle">
                                            @if($customer->email)
                                                <span class="text-nowrap">
                                                    <i class="fas fa-envelope text-secondary me-1"></i>
                                                    {{ $customer->email }}
                                                </span>
                                            @else
                                                <span class="text-muted">غير متوفر</span>
                                            @endif
                                        </td>
                                        <td class="align-middle">
                                            @if($customer->mobile)
                                                <span class="text-nowrap">
                                                    <i class="fas fa-phone-alt text-secondary me-1"></i>
                                                    {{ $customer->mobile }}
                                                </span>
                                            @else
                                                <span class="text-muted">غير متوفر</span>
                                            @endif
                                        </td>
                                        <td class="text-center align-middle">
                                            <span class="badge bg-info">
                                                {{ number_format($customer->total_orders) }}
                                            </span>
                                        </td>
                                        <td class="text-center align-middle">
                                            <strong>{{ number_format($customer->total_amount, 2) }}</strong>
                                            <small class="text-muted">ريال</small>
                                        </td>
                                        <td class="text-center align-middle">
                                            <strong>{{ number_format($customer->average_amount, 2) }}</strong>
                                            <small class="text-muted">ريال</small>
                                        </td>
                                        <td class="text-center align-middle">
                                            <a href="{{ route('orders.index', ['user_id' => $customer->id]) }}" 
                                               class="btn btn-sm btn-primary">
                                                <i class="fas fa-shopping-cart"></i>
                                            </a>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="8" class="text-center py-3">
                                            <span class="text-muted">لا توجد بيانات للعرض</span>
                                        </td>
                                    </tr>
                                @endforelse
                            </tbody>
                            @if($customers->isNotEmpty())
                                <tfoot>
                                    <tr class="bg-light">
                                        <td colspan="4" class="text-center">
                                            <strong>الإجمالي</strong>
                                        </td>
                                        <td class="text-center">
                                            <strong>{{ number_format($customers->sum('total_orders')) }}</strong>
                                        </td>
                                        <td class="text-center">
                                            <strong>{{ number_format($customers->sum('total_amount'), 2) }}</strong>
                                            <small class="text-muted">ريال</small>
                                        </td>
                                        <td class="text-center">
                                            <strong>{{ number_format($customers->avg('average_amount'), 2) }}</strong>
                                            <small class="text-muted">ريال</small>
                                        </td>
                                        <td></td>
                                    </tr>
                                </tfoot>
                            @endif
                        </table>
                    </div>
                </div>
                <div class="card-footer">
                    <div class="d-flex justify-content-center">
                        {{ $customers->appends(request()->query())->links() }}
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- رسم بياني لأفضل العملاء -->
    @if(count($customers) > 0)
    <div class="row">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">أفضل 10 عملاء</h3>
                </div>
                <div class="card-body">
                    <div class="chart">
                        <canvas id="topCustomersChart" style="min-height: 300px; height: 300px; max-height: 300px; max-width: 100%;"></canvas>
                    </div>
                </div>
            </div>
        </div>
    </div>
    @endif
</section>
@endsection

@section('scripts')
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
$(function () {
    // التحقق من وجود عنصر canvas الخاص بالرسم البياني وأن هناك بيانات لعرضها
    const topCustomersCtx = document.getElementById('topCustomersChart');
    
    @if(count($customers) > 0)
    // رسم بياني لأفضل العملاء
    const chartContext = topCustomersCtx.getContext('2d');
    const topCustomersData = {
        labels: [
            @foreach($customers->take(10) as $customer)
                '{{ $customer->name }}',
            @endforeach
        ],
        datasets: [
            {
                label: 'إجمالي المبيعات',
                backgroundColor: 'rgba(60,141,188,0.9)',
                borderColor: 'rgba(60,141,188,0.8)',
                data: [
                    @foreach($customers->take(10) as $customer)
                        {{ $customer->total_amount }},
                    @endforeach
                ]
            },
            {
                label: 'عدد الطلبات',
                backgroundColor: 'rgba(210, 214, 222, 1)',
                borderColor: 'rgba(210, 214, 222, 1)',
                data: [
                    @foreach($customers->take(10) as $customer)
                        {{ $customer->total_orders }},
                    @endforeach
                ]
            }
        ]
    };
    new Chart(chartContext, {
        type: 'bar',
        data: topCustomersData,
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
    @else
    // إظهار رسالة عندما لا توجد بيانات لعرضها في الرسم البياني
    if (topCustomersCtx) {
        const ctx = topCustomersCtx.getContext('2d');
        ctx.font = '16px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('لا توجد بيانات للعرض في الرسم البياني', topCustomersCtx.width / 2, topCustomersCtx.height / 2);
    }
    @endif

    // إعادة تعيين الفلتر
    $('#resetFilter').on('click', function() {
        window.location.href = "{{ route('reports.customers') }}";
    });
});
</script>
@endsection 