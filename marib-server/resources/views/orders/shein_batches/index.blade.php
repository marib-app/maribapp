@extends('layouts.main')

@section('title', __('دفعات طلبات شي إن'))

@section('content')
<div class="container-fluid">
    <div class="row">
        <div class="col-12">
            <div class="card">
                <div class="card-header d-flex justify-content-between align-items-center">
                    <h4 class="card-title mb-0">{{ __('دفعات طلبات شي إن') }}</h4>
                    <div class="d-flex gap-2">
                        <a href="{{ route('item.shein.batches.report') }}" class="btn btn-outline-secondary btn-sm">
                            <i class="fas fa-chart-line"></i> {{ __('تقرير الدفعات') }}
                        </a>
                        <a href="{{ route('item.shein.batches.create') }}" class="btn btn-primary btn-sm">
                            <i class="fas fa-plus"></i> {{ __('إنشاء دفعة جديدة') }}
                        </a>
                    </div>
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
                                    <th></th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($batches as $batch)
                                    <tr>
                                        <td>{{ $batch->reference }}</td>
                                        <td>{{ optional($batch->batch_date)->format('Y-m-d') ?? __('غير محدد') }}</td>
                                        <td>{{ __($batch->status) }}</td>
                                        <td>{{ number_format($batch->orders_count) }}</td>
                                        <td>{{ number_format($batch->total_final_amount ?? 0, 2) }}</td>
                                        <td>{{ number_format($batch->total_collected_amount ?? 0, 2) }}</td>
                                        <td>{{ number_format($batch->deposit_amount ?? 0, 2) }}</td>
                                        <td>{{ number_format($batch->outstanding_amount ?? 0, 2) }}</td>
                                        <td class="text-right">
                                            <a href="{{ route('item.shein.batches.show', $batch) }}" class="btn btn-link btn-sm">
                                                {{ __('إدارة') }}
                                            </a>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="9" class="text-center py-4">{{ __('لا توجد دفعات مسجلة حتى الآن.') }}</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>
                @if($batches instanceof \Illuminate\Pagination\LengthAwarePaginator)
                    <div class="card-footer">{{ $batches->links() }}</div>
                @endif
            </div>
        </div>
    </div>
</div>
@endsection