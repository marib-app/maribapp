@extends('layouts.main')

@section('title')
    أكواد الشبكة: {{ $network->name }}
@endsection

@section('content')
    @php
        $statusLabels = [
            'available' => 'متاح',
            'reserved' => 'محجوز',
            'sold' => 'مباع',
            'expired' => 'منتهي',
        ];
        $statusClasses = [
            'available' => 'badge bg-success-subtle text-success',
            'reserved' => 'badge bg-warning-subtle text-warning',
            'sold' => 'badge bg-danger-subtle text-danger',
            'expired' => 'badge bg-secondary-subtle text-secondary',
        ];
    @endphp

    <div class="page-title mb-3">
        <div class="row align-items-center g-2">
            <div class="col-12 col-md-6 order-md-1 order-last text-center text-md-start">
                <h4 class="mb-1">@yield('title')</h4>
                <p class="text-muted mb-0">شبكة: {{ $network->name }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-center text-md-end">
                <div class="d-inline-flex gap-2">
                    <a href="{{ route('wifi.show', $network) }}" class="btn btn-outline-secondary">
                        <i class="bi bi-arrow-right"></i>
                        عودة لتفاصيل الشبكة
                    </a>
                </div>
            </div>
        </div>
    </div>

    <section class="section">
        <div class="card shadow-sm border-0">
            <div class="card-body">
                <form method="get" class="row g-2 align-items-end mb-3">
                    <div class="col-sm-4">
                        <label class="form-label form-label-sm">بحث عن الكود أو الرقم</label>
                        <input type="text" name="search" value="{{ $search }}" class="form-control" placeholder="الكود أو الرقم المختصر">
                    </div>
                    <div class="col-sm-3">
                        <label class="form-label form-label-sm">الحالة</label>
                        <select name="status" class="form-select">
                            <option value="">الكل</option>
                            @foreach ($statusLabels as $key => $label)
                                <option value="{{ $key }}" @selected($statusFilter === $key)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-sm-3">
                        <label class="form-label form-label-sm">عدد الصفوف</label>
                        <select name="per_page" class="form-select">
                            @foreach ([10, 25, 50, 100] as $size)
                                <option value="{{ $size }}" @selected(request('per_page', 25) == $size)>{{ $size }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-sm-2 d-flex gap-2">
                        <button type="submit" class="btn btn-primary w-100">تصفية</button>
                        <a href="{{ route('wifi.codes', $network) }}" class="btn btn-outline-secondary w-100">إعادة تعيين</a>
                    </div>
                </form>

                <div class="table-responsive">
                    <table class="table table-striped align-middle">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>الخطة</th>
                                <th>الكود</th>
                                <th>الحالة</th>
                                <th>المستخدم الحاصل على الكرت</th>
                                <th>تاريخ البيع</th>
                                <th>تاريخ التسليم</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($codes as $code)
                                @php
                                    $statusKey = $code->status instanceof \App\Enums\Wifi\WifiCodeStatus ? $code->status->value : ($code->status ?? 'available');
                                    $rowClass = in_array($statusKey, ['sold', 'reserved'], true) ? 'table-danger' : 'table-success';
                                @endphp
                                <tr class="{{ $rowClass }}">
                                    <td>{{ $code->id }}</td>
                                    <td>{{ $code->plan->name ?? '—' }}</td>
                                    <td>{{ $code->code_suffix ?? $code->code_last4 ?? '—' }}</td>
                                    <td>
                                        <span class="{{ $statusClasses[$statusKey] ?? 'badge bg-light text-dark' }}">
                                            {{ $statusLabels[$statusKey] ?? $statusKey }}
                                        </span>
                                    </td>
                                    <td>
                                        @if ($code->allocated_user_name || $code->allocated_user_email)
                                            <div class="fw-semibold">{{ $code->allocated_user_name ?? '—' }}</div>
                                            <div class="text-muted small">{{ $code->allocated_user_email ?? '' }}</div>
                                        @else
                                            <span class="text-muted">لم يُخصص بعد</span>
                                        @endif
                                    </td>
                                    <td>{{ optional($code->sold_at)->format('Y-m-d H:i') ?? '—' }}</td>
                                    <td>{{ optional($code->delivered_at)->format('Y-m-d H:i') ?? '—' }}</td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="7" class="text-center text-muted">لا توجد أكواد لعرضها.</td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>

                <div class="d-flex justify-content-between align-items-center mt-3">
                    <div class="text-muted small">
                        عرض {{ $codes->firstItem() ?? 0 }}–{{ $codes->lastItem() ?? 0 }} من {{ $codes->total() }} كود
                    </div>
                    <div>
                        {{ $codes->links() }}
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
