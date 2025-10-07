@extends('layouts.main')

@section('title', 'إيصالات الوديعة للطلب #' . $order->order_number)

@section('content')
<div class="container-fluid">
    <div class="row mb-3">
        <div class="col-12 d-flex justify-content-between align-items-center">
            <h2>إيصالات الوديعة للطلب #{{ $order->order_number }}</h2>
            <a href="{{ route('orders.show', $order) }}" class="btn btn-outline-secondary">
                <i class="fa fa-arrow-right"></i>
                العودة إلى تفاصيل الطلب
            </a>
        </div>
    </div>

    <div class="card">
        <div class="card-header">
            <h4 class="card-title mb-0">تفاصيل الإيصالات</h4>
        </div>
        <div class="card-body">
            <div class="table-responsive">
                <table class="table table-striped align-middle">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>المبلغ</th>
                            <th>البوابة</th>
                            <th>المرجع</th>
                            <th>تاريخ السداد</th>
                            <th>المعاملة المرتبطة</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($receipts as $index => $receipt)
                            @php
                                $paidAt = $receipt['paid_at'] ? \Carbon\Carbon::parse($receipt['paid_at'])->timezone(config('app.timezone')) : null;
                                $transaction = $receipt['transaction'] ?? null;
                            @endphp
                            <tr>
                                <td>{{ $index + 1 }}</td>
                                <td>{{ number_format((float) ($receipt['amount'] ?? 0), 2) }} {{ $receipt['currency'] ?? config('app.currency', 'SAR') }}</td>
                                <td>{{ $receipt['gateway'] ?? '—' }}</td>
                                <td>{{ $receipt['reference'] ?? '—' }}</td>
                                <td>{{ $paidAt ? $paidAt->translatedFormat('Y-m-d H:i') : '—' }}</td>
                                <td>
                                    @if ($transaction)
                                        <span class="badge bg-success">#{{ $transaction->id }}</span>
                                    @else
                                        —
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
@endsection