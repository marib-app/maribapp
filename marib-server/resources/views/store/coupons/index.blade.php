@extends('layouts.main')

@section('title', __('merchant_coupons.page_title'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('merchant_coupons.page_lead') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end align-items-start gap-2 flex-wrap">
                <a href="{{ route('merchant.coupons.create') }}" class="btn btn-primary">
                    <i class="bi bi-plus-lg"></i>
                    {{ __('merchant_coupons.create_button') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        @if(session('success'))
            <div class="alert alert-success">{{ session('success') }}</div>
        @endif

        <div class="card">
            <div class="card-body table-responsive">
                <table class="table align-middle">
                    <thead>
                        <tr>
                            <th>{{ __('merchant_coupons.table_code') }}</th>
                            <th>{{ __('merchant_coupons.table_name') }}</th>
                            <th>{{ __('merchant_coupons.table_type') }}</th>
                            <th>{{ __('merchant_coupons.table_discount') }}</th>
                            <th>{{ __('merchant_coupons.table_usage') }}</th>
                            <th>{{ __('merchant_coupons.table_schedule') }}</th>
                            <th>{{ __('merchant_coupons.table_status') }}</th>
                            <th class="text-end">{{ __('merchant_coupons.table_actions') }}</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($coupons as $coupon)
                            <tr>
                                <td class="fw-semibold">{{ $coupon->code }}</td>
                                <td>{{ $coupon->name }}</td>
                                <td>
                                    @if($coupon->discount_type === 'percentage')
                                        <span class="badge bg-info">{{ __('merchant_coupons.discount_type_percentage') }}</span>
                                    @else
                                        <span class="badge bg-secondary">{{ __('merchant_coupons.discount_type_fixed') }}</span>
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
                                    <div>{{ __('merchant_coupons.usage_total') }}: {{ $coupon->max_uses ?? __('merchant_coupons.not_set') }}</div>
                                    <div>{{ __('merchant_coupons.usage_per_user') }}: {{ $coupon->max_uses_per_user ?? __('merchant_coupons.not_set') }}</div>
                                </td>
                                <td>
                                    <div>{{ __('merchant_coupons.schedule_start') }}: {{ optional($coupon->starts_at)->format('Y-m-d H:i') ?? __('merchant_coupons.not_set') }}</div>
                                    <div>{{ __('merchant_coupons.schedule_end') }}: {{ optional($coupon->ends_at)->format('Y-m-d H:i') ?? __('merchant_coupons.not_set') }}</div>
                                </td>
                                <td>
                                    @if($coupon->is_active)
                                        <span class="badge bg-success">{{ __('merchant_coupons.status_active') }}</span>
                                    @else
                                        <span class="badge bg-danger">{{ __('merchant_coupons.status_inactive') }}</span>
                                    @endif
                                </td>
                                <td class="text-end d-flex gap-2 justify-content-end">
                                    <form action="{{ route('merchant.coupons.toggle', $coupon) }}" method="POST">
                                        @csrf
                                        @method('patch')
                                        <button type="submit" class="btn btn-sm btn-outline-secondary">
                                            {{ __('merchant_coupons.toggle_button') }}
                                        </button>
                                    </form>
                                    <a href="{{ route('merchant.coupons.edit', $coupon) }}" class="btn btn-sm btn-outline-primary">
                                        {{ __('merchant_coupons.edit_button') }}
                                    </a>
                                    <form action="{{ route('merchant.coupons.destroy', $coupon) }}" method="POST" onsubmit="return confirm('{{ __('merchant_coupons.confirm_delete') }}');">
                                        @csrf
                                        @method('delete')
                                        <button type="submit" class="btn btn-sm btn-outline-danger">
                                            {{ __('merchant_coupons.delete_button') }}
                                        </button>
                                    </form>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="8" class="text-center text-muted py-4">
                                    {{ __('merchant_coupons.empty_state') }}
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>

                <div class="mt-3">
                    {{ $coupons->links() }}
                </div>
            </div>
        </div>
    </section>
@endsection
