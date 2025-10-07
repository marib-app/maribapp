@extends('layouts.main')

@section('title', __('تقرير دفعات شي إن'))

@section('content')
<div class="container-fluid">
    <div class="row">
        <div class="col-12">
            <div class="card mb-3">
                <div class="card-header d-flex justify-content-between align-items-center">
                    <h4 class="card-title mb-0">{{ __('ملخص الدفعات') }}</h4>
                    <a href="{{ route('item.shein.batches.index') }}" class="btn btn-outline-secondary btn-sm">
                        <i class="fas fa-arrow-right"></i> {{ __('العودة إلى الدفعات') }}
                    </a>
                </div>
                <div class="card-body">
                    <div class="row text-center">
                        <div class="col-md-4 mb-3">
                            <div class="border rounded p-3 bg-light">
                                <h6 class="text-muted">{{ __('إجمالي الودائع') }}</h6>
                                <p class="h4 mb-0">{{ number_format($totals['deposit'], 2) }}</p>
                            </div>
                        </div>
                        <div class="col-md-4 mb-3">
                            <div class="border rounded p-3 bg-light">
                                <h6 class="text-muted">{{ __('إجمالي البواقي') }}</h6>
                                <p class="h4 mb-0">{{ number_format($totals['outstanding'], 2) }}</p>
                            </div>
                        </div>
                        <div class="col-md-4 mb-3">
                            <div class="border rounded p-3 bg-light">
                                <h6 class="text-muted">{{ __('إجمالي التحصيل') }}</h6>
                                <p class="h4 mb-0">{{ number_format($totals['collected'], 2) }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h5 class="card-title mb-0">{{ __('تفاصيل الدفعات') }}</h5>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-striped mb-0">
                            <thead>
                                <tr>
                                    <th>{{ __('المرجع') }}</th>
                                    <th>{{ __('التاريخ') }}</th>
                                    <th>{{ __('الحالة') }}</th>
                                    <th>{{ __('عدد الطلبات') }}</th>
                                    <th>{{ __('إجمالي الطلبات') }}</th>
                                    <th>{{ __('التحصيل') }}</th>
                                    <th>{{ __('الودائع') }}</th>
                                    <th>{{ __('البواقي') }}</th>
                                    <th>{{ __('الرصيد المتبقي') }}</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($summaries as $summary)
                                    <tr>
                                        <td>{{ $summary['batch']->reference }}</td>
                                        <td>{{ optional($summary['batch']->batch_date)->format('Y-m-d') ?? __('غير محدد') }}</td>
                                        <td>{{ __($summary['batch']->status) }}</td>
                                        <td>{{ number_format($summary['orders_count']) }}</td>
                                        <td>{{ number_format($summary['total_final_amount'], 2) }}</td>
                                        <td>{{ number_format($summary['total_collected_amount'], 2) }}</td>
                                        <td>{{ number_format($summary['deposit_amount'], 2) }}</td>
                                        <td>{{ number_format($summary['outstanding_amount'], 2) }}</td>
                                        <td>{{ number_format($summary['remaining_balance'], 2) }}</td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="9" class="text-center py-4">{{ __('لا توجد بيانات تقارير حالياً.') }}</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection