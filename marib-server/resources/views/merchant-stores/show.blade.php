@extends('layouts.main')

@php
    use App\Enums\StoreStatus;

    $statusColors = [
        StoreStatus::DRAFT->value => 'secondary',
        StoreStatus::PENDING->value => 'warning',
        StoreStatus::APPROVED->value => 'success',
        StoreStatus::REJECTED->value => 'danger',
        StoreStatus::SUSPENDED->value => 'dark',
    ];

    $statusLabels = [
        StoreStatus::DRAFT->value => 'مسودة',
        StoreStatus::PENDING->value => 'بانتظار المراجعة',
        StoreStatus::APPROVED->value => 'معتمد',
        StoreStatus::REJECTED->value => 'مرفوض',
        StoreStatus::SUSPENDED->value => 'معلّق',
    ];

    $weekdays = [
        0 => 'الأحد',
        1 => 'الإثنين',
        2 => 'الثلاثاء',
        3 => 'الأربعاء',
        4 => 'الخميس',
        5 => 'الجمعة',
        6 => 'السبت',
    ];
@endphp

@section('title', $store->name ?? 'تفاصيل المتجر')

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-md-8 col-12">
                <div class="d-flex align-items-center gap-3">
                    @if($store->logo_path)
                        <img
                            src="{{ url($store->logo_path) }}"
                            alt="{{ $store->name }}"
                            class="rounded-circle border"
                            width="60"
                            height="60"
                            style="object-fit: cover;"
                        >
                    @endif
                    <div>
                        <h4 class="mb-0">{{ $store->name ?? 'متجر بدون اسم' }}</h4>
                        <div class="text-muted small">
                            {{ 'المعرف' }}: {{ $store->slug ?? '—' }} · ID: #{{ $store->id }}
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-4 col-12 text-md-end mt-3 mt-md-0">
                <a href="{{ route('merchant-stores.index') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i> {{ 'العودة إلى القائمة' }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-4">
            <div class="col-lg-4">
                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
                        <h6 class="mb-0">{{ 'ملخص الحالة' }}</h6>
                        @php
                            $badgeClass = $statusColors[$store->status] ?? 'secondary';
                        @endphp
                        <span class="badge bg-{{ $badgeClass }}">{{ $statusLabels[$store->status] ?? $store->status }}</span>
                    </div>
                    <div class="card-body">
                        <dl class="row mb-0">
                            <dt class="col-5 text-muted">{{ 'آخر تحديث' }}</dt>
                            <dd class="col-7">{{ optional($store->status_changed_at)->diffForHumans() ?? '—' }}</dd>

                            <dt class="col-5 text-muted">{{ 'تاريخ الاعتماد' }}</dt>
                            <dd class="col-7">{{ optional($store->approved_at)->format('Y-m-d H:i') ?? '—' }}</dd>

                            <dt class="col-5 text-muted">{{ 'إغلاق يدوي' }}</dt>
                            <dd class="col-7">
                                @if($statusSnapshot['is_manually_closed'] ?? false)
                                    <span class="badge bg-dark">{{ 'مفعّل' }}</span>
                                    <div class="small text-muted">
                                        {{ 'حتى' }} {{ \Carbon\Carbon::parse($statusSnapshot['manual_closure_expires_at'])->format('Y-m-d H:i') }}
                                    </div>
                                @else
                                    <span class="text-success">{{ 'لا يوجد إغلاق يدوي' }}</span>
                                @endif
                            </dd>

                            <dt class="col-5 text-muted">{{ 'الوضع الحالي' }}</dt>
                            <dd class="col-7">
                                @if($statusSnapshot['is_open_now'])
                                    <span class="badge bg-success">{{ 'مفتوح' }}</span>
                                @else
                                    <span class="badge bg-secondary">{{ 'مغلق' }}</span>
                                @endif
                            </dd>

                            <dt class="col-5 text-muted">{{ 'أقرب موعد فتح' }}</dt>
                            <dd class="col-7">{{ $statusSnapshot['next_open_at'] ? \Carbon\Carbon::parse($statusSnapshot['next_open_at'])->format('Y-m-d H:i') : '—' }}</dd>
                        </dl>
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-header bg-transparent">
                        <h6 class="mb-0">{{ 'مالك المتجر وبيانات التواصل' }}</h6>
                    </div>
                    <div class="card-body">
                        <dl class="row mb-0">
                            <dt class="col-5 text-muted">{{ 'المالك' }}</dt>
                            <dd class="col-7">
                                {{ $store->owner?->name ?? '—' }}<br>
                                <small class="text-muted">{{ $store->owner?->email }}</small>
                            </dd>
                            <dt class="col-5 text-muted">{{ 'الهاتف' }}</dt>
                            <dd class="col-7">{{ $store->contact_phone ?? '—' }}</dd>
                            <dt class="col-5 text-muted">{{ 'واتساب' }}</dt>
                            <dd class="col-7">{{ $store->contact_whatsapp ?? '—' }}</dd>
                            <dt class="col-5 text-muted">{{ 'العنوان' }}</dt>
                            <dd class="col-7">
                                {{ $store->location_address ?? '—' }}<br>
                                <small class="text-muted">{{ $store->location_city }} · {{ $store->location_state }}</small>
                            </dd>
                        </dl>
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-header bg-transparent">
                        <h6 class="mb-0">{{ 'الأقسام المرتبطة' }}</h6>
                    </div>
                    <div class="card-body">
                        @if(!empty($categories))
                            <div class="d-flex flex-wrap gap-2">
                                @foreach($categories as $id => $name)
                                    <span class="badge bg-light text-dark border">
                                        #{{ $id }} · {{ $name }}
                                    </span>
                                @endforeach
                            </div>
                        @else
                            <p class="text-muted mb-0">{{ 'لا توجد أقسام مرتبطة حتى الآن.' }}</p>
                        @endif
                    </div>
                </div>

                <div class="card shadow-sm border-0">
                    <div class="card-header bg-transparent">
                        <h6 class="mb-0">{{ 'طرق الدفع المفضلة' }}</h6>
                    </div>
                    <div class="card-body">
                        @if(!empty($paymentMethods))
                            <ul class="list-unstyled mb-0">
                                @foreach($paymentMethods as $method)
                                    <li><i class="bi bi-credit-card me-1"></i> {{ strtoupper($method) }}</li>
                                @endforeach
                            </ul>
                        @else
                            <p class="text-muted mb-0">{{ 'لم يتم تحديد طرق دفع مفضلة بعد.' }}</p>
                        @endif
                    </div>
                </div>
            </div>

            <div class="col-lg-8">
                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
                        <h6 class="mb-0">{{ 'إجراءات الاعتماد' }}</h6>
                    </div>
                    <div class="card-body">
                        <form action="{{ route('merchant-stores.status', $store) }}" method="POST" class="row g-3">
                            @csrf
                            <div class="col-md-4">
                                <label class="form-label" for="status-select">{{ 'الحالة' }}</label>
                                <select id="status-select" name="status" class="form-select" required>
                                    @foreach($statuses as $status)
                                <option value="{{ $status->value }}" @selected($store->status === $status->value)>
                                    {{ $statusLabels[$status->value] ?? $status->value }}
                                </option>
                                    @endforeach
                                </select>
                            </div>
                            <div class="col-md-8">
                                <label class="form-label" for="status-reason">{{ 'السبب / الملاحظات' }}</label>
                                <input
                                    type="text"
                                    name="reason"
                                    id="status-reason"
                                    value="{{ old('reason', $store->rejection_reason) }}"
                                    class="form-control @error('reason') is-invalid @enderror"
                                    placeholder="{{ 'مطلوبة في حال الرفض أو التعليق' }}"
                                >
                                @error('reason')
                                <div class="invalid-feedback">{{ $message }}</div>
                                @enderror
                            </div>
                            <div class="col-12 text-end">
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-check2-circle"></i> {{ 'تحديث الحالة' }}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-header bg-transparent">
                        <h6 class="mb-0">{{ 'ساعات العمل' }}</h6>
                    </div>
                    <div class="card-body table-responsive">
                        <table class="table table-sm table-striped mb-0">
                            <thead>
                            <tr>
                                <th>{{ 'اليوم' }}</th>
                                <th>{{ 'وقت الفتح' }}</th>
                                <th>{{ 'وقت الإغلاق' }}</th>
                            </tr>
                            </thead>
                            <tbody>
                            @foreach($weekdays as $index => $label)
                                @php
                                    $entry = $store->workingHours->firstWhere('weekday', $index);
                                @endphp
                                <tr>
                                    <td>{{ $label }}</td>
                                    @if($entry && $entry->is_open)
                                        <td>{{ $entry->opens_at }}</td>
                                        <td>{{ $entry->closes_at }}</td>
                                    @else
                                        <td colspan="2">
                                            <span class="text-muted">{{ 'مغلق' }}</span>
                                        </td>
                                    @endif
                                </tr>
                            @endforeach
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-header bg-transparent">
                        <h6 class="mb-0">{{ 'سياسات المتجر' }}</h6>
                    </div>
                    <div class="card-body">
                        @forelse($store->policies as $policy)
                            <div class="mb-3">
                                <h6 class="fw-semibold">{{ $policy->title ?? 'سياسة' }}</h6>
                                <p class="text-muted mb-0">{!! nl2br(e($policy->content ?? 'غير متوفر')) !!}</p>
                            </div>
                        @empty
                            <p class="text-muted mb-0">{{ 'لا توجد سياسات حالياً.' }}</p>
                        @endforelse
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-header bg-transparent">
                        <h6 class="mb-0">{{ 'حسابات الدفع' }}</h6>
                    </div>
                    <div class="card-body table-responsive">
                        <table class="table table-sm table-hover mb-0">
                            <thead>
                            <tr>
                                <th>{{ 'البوابة' }}</th>
                                <th>{{ 'المستفيد' }}</th>
                                <th>{{ 'الحساب / الآيبان' }}</th>
                                <th>{{ 'الحالة' }}</th>
                            </tr>
                            </thead>
                            <tbody>
                            @forelse($store->gatewayAccounts as $account)
                                <tr>
                                    <td>{{ $account->storeGateway?->name ?? 'تحويل يدوي' }}</td>
                                    <td>{{ $account->beneficiary_name ?? '—' }}</td>
                                    <td>
                                        {{ $account->account_number ?? '—' }}
                                        @if($account->iban)
                                            <div class="text-muted small">{{ $account->iban }}</div>
                                        @endif
                                    </td>
                                    <td>
                                        <span class="badge {{ $account->is_active ? 'bg-success' : 'bg-secondary' }}">
                                            {{ $account->is_active ? 'مفعّل' : 'معطل' }}
                                        </span>
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="4" class="text-center text-muted">{{ 'لا توجد حسابات دفع مسجلة.' }}</td>
                                </tr>
                            @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-header bg-transparent">
                        <h6 class="mb-0">{{ 'طاقم المتجر والصلاحيات' }}</h6>
                    </div>
                    <div class="card-body table-responsive">
                        <table class="table table-sm mb-0">
                            <thead>
                            <tr>
                                <th>{{ 'العضو' }}</th>
                                <th>{{ 'الدور' }}</th>
                                <th>{{ 'الحالة' }}</th>
                                <th>{{ 'تاريخ الدعوة' }}</th>
                            </tr>
                            </thead>
                            <tbody>
                            @forelse($store->staff as $staffMember)
                                <tr>
                                    <td>
                                        {{ $staffMember->user?->name ?? $staffMember->email }}
                                        <div class="text-muted small">{{ $staffMember->email }}</div>
                                    </td>
                                    <td>{{ $staffMember->role ?? '—' }}</td>
                                    <td>
                                        <span class="badge bg-light text-dark border">
                                            {{ strtoupper($staffMember->status ?? 'pending') }}
                                        </span>
                                    </td>
                                    <td>{{ optional($staffMember->created_at)->format('Y-m-d H:i') ?? '—' }}</td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="4" class="text-center text-muted">
                                        {{ 'لا يوجد طاقم حتى الآن.' }}
                                    </td>
                                </tr>
                            @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="card shadow-sm border-0">
                    <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
                        <h6 class="mb-0">{{ 'سجل الحالات' }}</h6>
                    </div>
                    <div class="card-body">
                        @forelse($store->statusLogs as $log)
                            <div class="d-flex justify-content-between align-items-start border-bottom py-2">
                                <div>
                                    <div class="fw-semibold">{{ $statusLabels[$log->status] ?? $log->status }}</div>
                                    @if($log->reason)
                                        <div class="text-muted small">{{ $log->reason }}</div>
                                    @endif
                                </div>
                                <div class="text-end">
                                    <div class="small text-muted">{{ optional($log->created_at)->format('Y-m-d H:i') }}</div>
                                    <div class="text-muted small">{{ $log->actor?->name }}</div>
                                </div>
                            </div>
                        @empty
                            <p class="text-muted mb-0">{{ 'لا توجد تغييرات مسجلة.' }}</p>
                        @endforelse
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection

