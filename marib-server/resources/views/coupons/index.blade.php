@extends('layouts.main')

@section('title')
    {{ __('إدارة القسائم') }}
@endsection

@section('content')
    <div class="content-wrapper">
        <div class="page-header">
            <h3 class="page-title">{{ __('إدارة القسائم') }}</h3>
            <div class="buttons d-flex gap-2">
                @can('coupon-create')
                    <a href="{{ route('coupons.create') }}" class="btn btn-primary">{{ __('إضافة قسيمة') }}</a>
                @endcan
            </div>
        </div>

        <div class="row grid-margin">
            <div class="col-lg-12">
                @if(session('success'))
                    <div class="alert alert-success">{{ session('success') }}</div>
                @endif

                <div class="card">
                    <div class="card-body table-responsive">
                        <table class="table align-middle">
                            <thead>
                                <tr>
                                    <th>{{ __('الرمز') }}</th>
                                    <th>{{ __('الاسم') }}</th>
                                    <th>{{ __('نوع الخصم') }}</th>
                                    <th>{{ __('القيمة') }}</th>
                                    <th>{{ __('حد الاستخدام') }}</th>
                                    <th>{{ __('الفترة الزمنية') }}</th>
                                    <th>{{ __('الحالة') }}</th>
                                    <th>{{ __('إجراءات') }}</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($coupons as $coupon)
                                    <tr>
                                        <td class="fw-semibold">{{ $coupon->code }}</td>
                                        <td>{{ $coupon->name }}</td>
                                        <td>
                                            @if($coupon->discount_type === 'percentage')
                                                <span class="badge bg-info">{{ __('نسبة') }}</span>
                                            @else
                                                <span class="badge bg-secondary">{{ __('قيمة ثابتة') }}</span>
                                            @endif
                                        </td>
                                        <td>
                                            @if($coupon->discount_type === 'percentage')
                                                {{ number_format($coupon->discount_value, 2) }}%
                                            @else
                                                {{ number_format($coupon->discount_value, 2) }}
                                            @endif
                                        </td>
                                        <td>
                                            <div>{{ __('الإجمالي') }}: {{ $coupon->max_uses ?? __('غير محدد') }}</div>
                                            <div>{{ __('لكل مستخدم') }}: {{ $coupon->max_uses_per_user ?? __('غير محدد') }}</div>
                                        </td>
                                        <td>
                                            <div>{{ optional($coupon->starts_at)->format('Y-m-d H:i') ?? __('بدون بداية') }}</div>
                                            <div>{{ optional($coupon->ends_at)->format('Y-m-d H:i') ?? __('بدون نهاية') }}</div>
                                        </td>
                                        <td>
                                            @if($coupon->is_active)
                                                <span class="badge bg-success">{{ __('مفعّل') }}</span>
                                            @else
                                                <span class="badge bg-danger">{{ __('معطّل') }}</span>
                                            @endif
                                        </td>
                                        <td>
                                            @can('coupon-edit')
                                                <a href="{{ route('coupons.edit', $coupon) }}" class="btn btn-sm btn-outline-primary">{{ __('تعديل') }}</a>
                                            @endcan
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="8" class="text-center text-muted">{{ __('لا توجد قسائم مسجلة حالياً.') }}</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>

                        <div class="mt-3">
                            {{ $coupons->links() }}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
@endsection