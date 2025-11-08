@extends('layouts.main')

@section('title', __('مندوبو التوصيل'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('إدارة المندوبين المعتمدين وتفعيلهم لإستلام الطلبات.') }}
                </p>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-12 col-lg-4 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('إضافة مندوب') }}</h6>
                    </div>
                    <div class="card-body">
                        <form method="post" action="{{ route('delivery.agents.store') }}">
                            @csrf
                            <div class="mb-3">
                                <label class="form-label">{{ __('البريد/الهاتف/المعرف') }}</label>
                                <input type="text" name="identifier" class="form-control" placeholder="{{ __('أدخل البريد الإلكتروني أو رقم الهاتف أو معرف المستخدم') }}" required>
                            </div>
                            <div class="mb-3">
                                <label class="form-label">{{ __('نوع المركبة') }}</label>
                                <input type="text" name="vehicle_type" class="form-control" placeholder="{{ __('اختياري') }}">
                            </div>
                            <button type="submit" class="btn btn-primary w-100">
                                {{ __('إضافة') }}
                            </button>
                        </form>
                    </div>
                </div>
            </div>
            <div class="col-12 col-lg-8">
                <div class="card">
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table align-middle">
                                <thead>
                                    <tr>
                                        <th>{{ __('الاسم') }}</th>
                                        <th>{{ __('الهاتف') }}</th>
                                        <th>{{ __('الحالة') }}</th>
                                        <th></th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse ($agents as $agent)
                                        <tr>
                                            <td>{{ $agent->name }}</td>
                                            <td>{{ $agent->phone ?? '—' }}</td>
                                            <td>
                                                <span class="badge bg-{{ $agent->is_active ? 'success' : 'secondary' }}">
                                                    {{ $agent->is_active ? __('مفعل') : __('معطل') }}
                                                </span>
                                            </td>
                                            <td class="text-end">
                                                <form action="{{ route('delivery.agents.toggle', $agent) }}" method="post" class="d-inline">
                                                    @csrf
                                                    <button class="btn btn-sm btn-outline-secondary" type="submit">
                                                        {{ $agent->is_active ? __('تعطيل') : __('تفعيل') }}
                                                    </button>
                                                </form>
                                                <form action="{{ route('delivery.agents.destroy', $agent) }}" method="post" class="d-inline ms-1" onsubmit="return confirm('{{ __('تأكيد الحذف؟') }}')">
                                                    @csrf
                                                    @method('delete')
                                                    <button class="btn btn-sm btn-outline-danger" type="submit">
                                                        <i class="bi bi-trash"></i>
                                                    </button>
                                                </form>
                                            </td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="4" class="text-center text-muted py-4">
                                                {{ __('لم يتم إضافة مندوبين بعد.') }}
                                            </td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                        <div class="mt-3">
                            {{ $agents->links() }}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
