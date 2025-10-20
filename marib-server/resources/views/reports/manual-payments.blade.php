@extends('layouts.app')

@section('title', 'تقرير طلبات الدفع')

@section('content')
<section class="section">
    <div class="dashboard_title mb-3">لوحة طلبات الدفع</div>

    <div class="card mb-4">
        <div class="card-body">
            <form action="{{ route('reports.payment-requests') }}" method="GET" class="row g-3 align-items-end">
                <div class="col-md-3">
                    <label for="start_date" class="form-label">من تاريخ</label>
                    <input type="date" name="start_date" id="start_date" value="{{ $filters['start_date'] }}" class="form-control">
                </div>
                <div class="col-md-3">
                    <label for="end_date" class="form-label">إلى تاريخ</label>
                    <input type="date" name="end_date" id="end_date" value="{{ $filters['end_date'] }}" class="form-control">
                </div>
                <div class="col-md-3">
                    <label for="status" class="form-label">الحالة</label>
                    <select name="status" id="status" class="form-select">
                        <option value="">الكل</option>
                        @foreach($statusOptions as $statusOption)
                            <option value="{{ $statusOption }}" {{ $filters['status'] === $statusOption ? 'selected' : '' }}>
                                {{ $statusOption ? \Illuminate\Support\Str::of($statusOption)->replace('_', ' ')->title() : 'غير محدد' }}
                            </option>
                        @endforeach
                    </select>
                </div>
                <div class="col-md-3 d-flex gap-2">
                    <button type="submit" class="btn btn-primary flex-grow-1">
                        <i class="fas fa-filter me-1"></i>
                        تطبيق الفلاتر
                    </button>
                    <a href="{{ route('reports.payment-requests') }}" class="btn btn-outline-secondary" title="إعادة التعيين">
                        <i class="fas fa-sync-alt"></i>
                    </a>
                </div>
            </form>
        </div>
        <div class="card-footer bg-light">
            <div class="d-flex flex-wrap gap-2">
                <form action="{{ route('reports.payment-requests') }}" method="GET">
                    <input type="hidden" name="start_date" value="{{ $filters['start_date'] }}">
                    <input type="hidden" name="end_date" value="{{ $filters['end_date'] }}">
                    <input type="hidden" name="status" value="{{ $filters['status'] }}">
                    <input type="hidden" name="export" value="csv">
                    <button class="btn btn-success">
                        <i class="fas fa-file-csv me-1"></i>
                        تصدير CSV
                    </button>
                </form>
                <form action="{{ route('reports.payment-requests') }}" method="GET">
                    <input type="hidden" name="start_date" value="{{ $filters['start_date'] }}">
                    <input type="hidden" name="end_date" value="{{ $filters['end_date'] }}">
                    <input type="hidden" name="status" value="{{ $filters['status'] }}">
                    <input type="hidden" name="export" value="excel">
                    <button class="btn btn-info text-white">
                        <i class="fas fa-file-excel me-1"></i>
                        تصدير Excel
                    </button>
                </form>
            </div>
        </div>
    </div>

    <div class="row mb-4 g-3">
        <div class="col-md-4 col-sm-6">
            <div class="summary-card bg-primary text-white">
                <div class="summary-label">إجمالي طلبات الدفع</div>
                <div class="summary-value">{{ number_format($totals['count']) }}</div>
                <div class="summary-sub">ضمن الفترة المحددة</div>
            </div>
        </div>
        <div class="col-md-4 col-sm-6">
            <div class="summary-card bg-success text-white">
                <div class="summary-label">إجمالي المبالغ</div>
                <div class="summary-value">{{ number_format($totals['amount'], 2) }}</div>
                <div class="summary-sub">ريال سعودي</div>
            </div>
        </div>
        <div class="col-md-4 col-sm-12">
            <div class="summary-card bg-dark text-white">
                <div class="summary-label">متوسط قيمة الطلب</div>
                <div class="summary-value">
                    {{ $totals['count'] > 0 ? number_format($totals['amount'] / $totals['count'], 2) : '0.00' }}
                </div>
                <div class="summary-sub">ريال سعودي</div>
            </div>
        </div>
    </div>

    <div class="row mb-4 g-3">
        @php
            $timeLabels = [
                'today' => 'اليوم',
                'week' => 'هذا الأسبوع',
                'month' => 'هذا الشهر',
            ];
        @endphp
        @foreach($timeBuckets as $key => $bucket)
            <div class="col-md-4 col-sm-6">
                <div class="card h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <h5 class="card-title mb-0">{{ $timeLabels[$key] ?? $key }}</h5>
                            <span class="badge bg-primary">{{ number_format($bucket['count']) }} عملية</span>
                        </div>
                        <div class="text-muted">المجموع</div>
                        <div class="fs-4 fw-bold text-success">{{ number_format($bucket['amount'], 2) }} ريال</div>
                    </div>
                </div>
            </div>
        @endforeach
    </div>

    <div class="row mb-4 g-3">
        @php
            $formatStatus = static function (?string $status): string {
                if (empty($status)) {
                    return 'غير محدد';
                }
                return (string) \Illuminate\Support\Str::of($status)->replace('_', ' ')->title();
            };
        @endphp
        @foreach($statusBreakdown as $statusRow)
            <div class="col-md-4 col-sm-6">
                <div class="card h-100 border-0 shadow-sm status-card">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h6 class="mb-0">{{ $formatStatus($statusRow->status) }}</h6>
                            <span class="badge bg-secondary">{{ number_format($statusRow->total_count) }} طلب</span>
                        </div>
                        <div class="text-muted">إجمالي المبلغ</div>
                        <div class="fs-5 fw-bold text-primary">{{ number_format($statusRow->total_amount, 2) }} ريال</div>
                    </div>
                </div>
            </div>
        @endforeach
    </div>

    <div class="row mb-4 g-3">
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header border-0 pb-0">
                    <h5 class="mb-0">توزيع الحالات</h5>
                </div>
                <div class="card-body">
                    <canvas id="paymentRequestStatusChart" style="min-height: 280px; height: 280px; max-height: 320px;"></canvas>
                </div>
            </div>
        </div>
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header border-0 pb-0">
                    <h5 class="mb-0">العائد اليومي</h5>
                </div>
                <div class="card-body">
                    <canvas id="paymentRequestRevenueChart" style="min-height: 280px; height: 280px; max-height: 320px;"></canvas>
                </div>
            </div>
        </div>
    </div>

    <div class="card">
        <div class="card-header border-0 pb-0">
            <h5 class="mb-0">سجل طلبات الدفع</h5>
        </div>
        <div class="card-body">
            <div class="table-responsive">


                <table class="table table-striped mb-0"
                       id="payment-requests-table"
                       data-toggle="table"
                       data-url="{{ route('reports.payment-requests.list') }}"
                       data-side-pagination="server"
                       data-pagination="true"
                       data-page-list="[10, 20, 50, 100]"
                       data-sort-name="submitted_at"
                       data-sort-order="desc"
                       data-search="false"
                       data-show-refresh="true"
                       data-show-columns="true"
                       data-show-export="true"
                       data-export-options='{"fileName": "payment-requests-report","ignoreColumn": ["operate"]}'
                       data-export-types='["csv","excel","pdf"]'
                       data-query-params="paymentRequestsReportQueryParams"
                       data-escape="false">

                    <thead class="bg-light">
                        <tr>
                            <th data-field="id" data-sortable="true" data-align="center" style="width: 8%">#</th>
                            <th data-field="reference" data-sortable="true" style="width: 15%">المرجع</th>
                            <th data-field="user_name" data-sortable="false" style="width: 20%">المستخدم</th>
                            <th data-field="formatted_amount" data-align="center" style="width: 15%">المبلغ</th>
                            <th data-field="payable_type" data-sortable="true" style="width: 12%">نوع الدفع</th>
                            <th data-field="status_badge" data-align="center" style="width: 12%">الحالة</th>
                            <th data-field="submitted_at" data-sortable="true" data-align="center" style="width: 12%">تاريخ الإرسال</th>
                            <th data-field="operate" data-align="center" style="width: 6%">الإجراءات</th>

                        </tr>
                    </thead>

                </table>
            </div>
        </div>
        <div class="card-footer d-flex justify-content-between align-items-center flex-wrap gap-2">
            <div class="text-muted" id="payment-requests-total">
                إجمالي السجلات: {{ number_format($totals['count']) }}
            </div>
            <div class="text-muted small">
                يتم تحديث الجدول تلقائيًا بعد المراجعة.
            </div>
        </div>
    </div>

    <div class="modal fade" id="paymentRequestModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-xl modal-dialog-scrollable">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">تفاصيل طلب الدفع</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="إغلاق"></button>
                </div>
                <div class="modal-body p-0">
                    <div class="text-center p-5" id="payment-request-modal-loader">
                        <i class="fa fa-spinner fa-spin fa-2x"></i>
                    </div>
                    <div id="payment-request-modal-body"></div>
                </div>
            </div>
        </div>
    </div>
</section>
@endsection

@section('styles')
<style>
    .summary-card {
        border-radius: 12px;
        padding: 20px;
        box-shadow: 0 10px 20px rgba(0, 0, 0, 0.08);
    }
    .summary-card .summary-label {
        font-size: 14px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        opacity: 0.8;
    }
    .summary-card .summary-value {
        font-size: 32px;
        font-weight: 700;
        margin-top: 10px;
    }
    .summary-card .summary-sub {
        font-size: 12px;
        opacity: 0.8;
    }
    .status-card {
        border-radius: 12px;
    }
    .status-card .card-body {
        padding: 20px;
    }
</style>
@endsection

@section('scripts')
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
@php
    $statusChartLabels = $statusBreakdown->pluck('status')->map($formatStatus);
    $statusChartCounts = $statusBreakdown->pluck('total_count');
    $revenueLabels = $revenueTrend->pluck('date');
    $revenueAmounts = $revenueTrend->pluck('total_amount');
@endphp
<script>

        window.paymentRequestsReportQueryParams = function (params) {
        const startDate = document.getElementById('start_date');
        const endDate = document.getElementById('end_date');
        const status = document.getElementById('status');

        params.date_from = startDate ? startDate.value : '';
        params.date_to = endDate ? endDate.value : '';
        params.status = status ? status.value : '';

        return params;
    };

    document.addEventListener('DOMContentLoaded', () => {
        const chartColors = ['#0d6efd', '#20c997', '#ffc107', '#dc3545', '#6610f2', '#fd7e14'];

        const statusCtx = document.getElementById('paymentRequestStatusChart');
        if (statusCtx) {
            new Chart(statusCtx.getContext('2d'), {
                type: 'doughnut',
                data: {
                    labels: @json($statusChartLabels),
                    datasets: [{
                        data: @json($statusChartCounts),
                        backgroundColor: chartColors,
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    cutout: '65%',
                    plugins: {
                        legend: {
                            position: 'bottom',
                            labels: {
                                padding: 20,
                                usePointStyle: true,
                            }
                        }
                    }
                }
            });
        }

        const revenueCtx = document.getElementById('paymentRequestRevenueChart');
        if (revenueCtx) {
            new Chart(revenueCtx.getContext('2d'), {
                type: 'line',
                data: {
                    labels: @json($revenueLabels),
                    datasets: [{
                        label: 'الإيراد اليومي',
                        data: @json($revenueAmounts),
                        borderColor: '#0d6efd',
                        backgroundColor: 'rgba(13, 110, 253, 0.15)',
                        fill: true,
                        tension: 0.4,
                        pointRadius: 4,
                        pointBackgroundColor: '#0d6efd',
                        borderWidth: 2
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    interaction: {
                        mode: 'index',
                        intersect: false
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            grid: {
                                color: 'rgba(0,0,0,0.05)'
                            }
                        },
                        x: {
                            grid: {
                                display: false
                            }
                        }
                    },
                    plugins: {
                        legend: {
                            display: false
                        }
                    }
                }
            });
        }




        
    });
</script>
@endsection