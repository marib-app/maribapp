@php
    use App\Enums\Wifi\WifiNetworkStatus;
    use App\Enums\Wifi\WifiPlanStatus;
    use Carbon\Carbon;
@endphp

@extends('layouts.main')

@section('title')
    {{ __('إدارة شبكة: :name', ['name' => $network->name]) }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center g-2">
            <div class="col-12 col-md-6 order-md-1 order-last text-center text-md-start">
                <h4 class="mb-0">@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-center text-md-end">
                <nav aria-label="breadcrumb" class="breadcrumb-header">
                    <ol class="breadcrumb mb-0 justify-content-center justify-content-md-end">
                        <li class="breadcrumb-item"><a href="{{ route('home') }}">{{ __('لوحة التحكم') }}</a></li>
                        <li class="breadcrumb-item"><a href="{{ route('wifi.index') }}">{{ __('كبائن الواي فاي') }}</a></li>
                        <li class="breadcrumb-item active" aria-current="page">{{ $network->name }}</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-3">
            <div class="col-12">
                @if (session('status'))
                    <div class="alert alert-success" role="alert">
                        {{ session('status') }}
                    </div>
                @endif
            </div>

            <div class="col-xl-3 col-lg-6 col-md-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <span class="badge bg-primary-subtle text-primary"><i class="bi bi-diagram-3"></i></span>
                            <span class="badge bg-primary">{{ __('الخطط') }}</span>
                        </div>
                        <h3 class="fw-bold mb-0">{{ number_format($networkStats['plans_total']) }}</h3>
                        <p class="text-muted small mb-0">{{ __('نشطة: :active', ['active' => number_format($networkStats['plans_active'])]) }}</p>
                    </div>
                </div>
            </div>
            <div class="col-xl-3 col-lg-6 col-md-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <span class="badge bg-warning-subtle text-warning"><i class="bi bi-box"></i></span>
                            <span class="badge bg-warning text-dark">{{ __('الدفعات') }}</span>
                        </div>
                        <h3 class="fw-bold mb-0">{{ number_format($networkStats['batches_total']) }}</h3>
                        <p class="text-muted small mb-0">{{ __('مفعّلة: :active', ['active' => number_format($networkStats['batches_active'])]) }}</p>
                    </div>
                </div>
            </div>
            <div class="col-xl-3 col-lg-6 col-md-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <span class="badge bg-info-subtle text-info"><i class="bi bi-key"></i></span>
                            <span class="badge bg-info text-dark">{{ __('إجمالي الأكواد') }}</span>
                        </div>
                        <h3 class="fw-bold mb-0">{{ number_format($networkStats['codes_total']) }}</h3>
                        <p class="text-muted small mb-0">{{ __('متاحة: :available | مباعة: :sold', [
                            'available' => number_format($networkStats['codes_available']),
                            'sold' => number_format($networkStats['codes_sold'])
                        ]) }}</p>
                    </div>
                </div>
            </div>
            <div class="col-xl-3 col-lg-6 col-md-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-2">
                            <span class="badge bg-secondary-subtle text-secondary"><i class="bi bi-gear"></i></span>
                            <span class="badge bg-secondary text-white">{{ __('إعدادات') }}</span>
                        </div>
                        <h3 class="fw-bold mb-0">{{ number_format(data_get($network->settings, 'commission_rate', 0) * 100, 2) }}%</h3>
                        <p class="text-muted small mb-0">{{ __('عمولة الشبكة الحالية') }}</p>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card shadow-sm border-0">
                    <div class="card-header border-0 bg-white d-flex justify-content-between align-items-center">
                        <div>
                            <h5 class="card-title mb-1">{{ __('معلومات الشبكة') }}</h5>
                            <p class="text-muted small mb-0">{{ __('قم بمراجعة بيانات الشبكة والتحديث عبر واجهة الإدارة.') }}</p>
                        </div>
                        <a href="{{ $adminApiEndpoints['reports'] }}" target="_blank" class="btn btn-sm btn-outline-secondary">
                            <i class="bi bi-box-arrow-up-right"></i> {{ __('عرض بلاغات المالك') }}
                        </a>
                    </div>
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <div class="border rounded p-3 h-100">
                                    <h6 class="fw-semibold mb-3">{{ __('بيانات عامة') }}</h6>
                                    <dl class="row mb-0">
                                        <dt class="col-sm-4 text-muted">{{ __('المرجع') }}</dt>
                                        <dd class="col-sm-8">{{ $network->reference_code ?? '—' }}</dd>

                                        <dt class="col-sm-4 text-muted">{{ __('الحالة') }}</dt>
                                        <dd class="col-sm-8"><span class="badge bg-light text-dark">{{ $network->status->label() }}</span></dd>

                                        <dt class="col-sm-4 text-muted">{{ __('الموقع') }}</dt>
                                        <dd class="col-sm-8">{{ $network->address ?? __('غير متوفر') }}</dd>

                                        <dt class="col-sm-4 text-muted">{{ __('الإحداثيات') }}</dt>
                                        <dd class="col-sm-8">{{ $network->latitude }}, {{ $network->longitude }}</dd>

                                        <dt class="col-sm-4 text-muted">{{ __('نطاق التغطية (كم)') }}</dt>
                                        <dd class="col-sm-8">{{ number_format($network->coverage_radius_km ?? 0, 2) }}</dd>
                                    </dl>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="border rounded p-3 h-100">
                                    <h6 class="fw-semibold mb-3">{{ __('بيانات المالك') }}</h6>
                                    <dl class="row mb-0">
                                        <dt class="col-sm-4 text-muted">{{ __('الاسم') }}</dt>
                                        <dd class="col-sm-8">{{ $network->owner?->name ?? __('غير متوفر') }}</dd>

                                        <dt class="col-sm-4 text-muted">{{ __('البريد الإلكتروني') }}</dt>
                                        <dd class="col-sm-8">{{ $network->owner?->email ?? __('غير متوفر') }}</dd>

                                        <dt class="col-sm-4 text-muted">{{ __('الهاتف') }}</dt>
                                        <dd class="col-sm-8">{{ $network->owner?->mobile ?? __('غير متوفر') }}</dd>

                                        <dt class="col-sm-4 text-muted">{{ __('محفظة مالية') }}</dt>
                                        <dd class="col-sm-8">{{ $network->walletAccount?->number ?? __('غير مرتبط') }}</dd>
                                    </dl>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-lg-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-header border-0 bg-white">
                        <h5 class="card-title mb-0">{{ __('تعديل حالة الشبكة') }}</h5>
                    </div>
                    <div class="card-body">
                        <form id="network-status-form" data-endpoint="{{ $adminApiEndpoints['network_status'] }}">
                            <div class="mb-3">
                                <label for="network_status" class="form-label">{{ __('الحالة') }}</label>
                                <select id="network_status" name="status" class="form-select" required>
                                    @foreach(WifiNetworkStatus::cases() as $status)
                                        <option value="{{ $status->value }}" @selected($network->status === $status)>{{ $status->label() }}</option>
                                    @endforeach
                                </select>
                            </div>
                            <div class="mb-3">
                                <label for="network_status_reason" class="form-label">{{ __('سبب التعديل') }}</label>
                                <input type="text" id="network_status_reason" name="reason" class="form-control" maxlength="255" placeholder="{{ __('اختياري') }}">
                            </div>
                            <div class="d-flex justify-content-end gap-2">
                                <button type="button" class="btn btn-light" data-action="reset-status">{{ __('إعادة تعيين') }}</button>
                                <button type="submit" class="btn btn-primary">{{ __('حفظ الحالة') }}</button>
                            </div>
                            <div class="form-text text-muted mt-2" id="network-status-feedback"></div>
                        </form>
                    </div>
                </div>
            </div>

            <div class="col-lg-6">
                <div class="card shadow-sm border-0 h-100">
                    <div class="card-header border-0 bg-white">
                        <h5 class="card-title mb-0">{{ __('تحديث عمولة الشبكة') }}</h5>
                    </div>
                    <div class="card-body">
                        <form id="network-commission-form" data-endpoint="{{ $adminApiEndpoints['commission'] }}">
                            <div class="mb-3">
                                <label for="commission_rate" class="form-label">{{ __('النسبة (0 - 50%)') }}</label>
                                <div class="input-group">
                                    <input type="number" step="0.01" min="0" max="0.5" id="commission_rate" name="commission_rate" value="{{ number_format(data_get($network->settings, 'commission_rate', 0), 2, '.', '') }}" class="form-control" required>
                                    <span class="input-group-text">{{ __('من الأرباح') }}</span>
                                </div>
                                <div class="form-text">{{ __('القيمة يجب أن تكون بين 0 و 0.5 (أي 0% - 50%).') }}</div>
                            </div>
                            <div class="d-flex justify-content-end gap-2">
                                <button type="submit" class="btn btn-success">{{ __('تحديث العمولة') }}</button>
                            </div>
                            <div class="form-text text-muted mt-2" id="commission-feedback"></div>
                        </form>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card shadow-sm border-0">
                    <div class="card-header border-0 bg-white">
                        <h5 class="card-title mb-0">{{ __('الخطط المرتبطة') }}</h5>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover align-middle mb-0">
                                <thead class="table-light">
                                <tr>
                                    <th>{{ __('الخطة') }}</th>
                                    <th>{{ __('الحالة') }}</th>
                                    <th>{{ __('السعر') }}</th>
                                    <th>{{ __('الأكواد المتاحة') }}</th>
                                    <th>{{ __('الأكواد المباعة') }}</th>
                                    <th>{{ __('تنبيهات المخزون') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @forelse($plans as $plan)
                                    <tr>
                                        <td>
                                            <div class="d-flex flex-column">
                                                <strong>{{ $plan->name }}</strong>
                                                <small class="text-muted">{{ __('آخر تحديث: :date', ['date' => optional($plan->updated_at)->format('Y-m-d H:i')]) }}</small>
                                            </div>
                                        </td>
                                        <td><span class="badge bg-light text-dark">{{ $plan->status->label() }}</span></td>
                                        <td>{{ number_format((float) $plan->price, 2) }} {{ $plan->currency }}</td>
                                        <td>{{ number_format($plan->codes_available_count) }}</td>
                                        <td>{{ number_format($plan->codes_sold_count) }}</td>
                                        <td>
                                            @php
                                                $lastAvailable = data_get($plan->meta, 'alerts.low_stock.last_available');
                                                $lastTriggered = data_get($plan->meta, 'alerts.low_stock.last_triggered_at');
                                                $threshold = data_get($plan->meta, 'alerts.low_stock.threshold');
                                            @endphp
                                            <div class="d-flex flex-column">
                                                <span>{{ __('المتاح الأخير: :count', ['count' => number_format($lastAvailable ?? 0)]) }}</span>
                                                <span>{{ __('آخر تنبيه: :at', ['at' => $lastTriggered ? Carbon::parse($lastTriggered)->diffForHumans() : __('لا يوجد')]) }}</span>
                                                <span>{{ __('الحد: :threshold', ['threshold' => $threshold !== null ? number_format($threshold) : __('افتراضي')]) }}</span>
                                            </div>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="6" class="text-center text-muted py-4">{{ __('لا توجد خطط مرتبطة بهذه الشبكة.') }}</td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card shadow-sm border-0">
                    <div class="card-header border-0 bg-white d-flex justify-content-between align-items-center">
                        <h5 class="card-title mb-0">{{ __('دفعات الأكواد') }}</h5>
                        <a href="{{ route('wifi.create') }}" class="btn btn-sm btn-primary">
                            <i class="bi bi-upload"></i> {{ __('رفع دفعة جديدة') }}
                        </a>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover align-middle mb-0">
                                <thead class="table-light">
                                <tr>
                                    <th>{{ __('الخطة') }}</th>
                                    <th>{{ __('الوسم') }}</th>
                                    <th>{{ __('الحالة') }}</th>
                                    <th>{{ __('الأكواد المتاحة') }}</th>
                                    <th>{{ __('الأكواد الإجمالية') }}</th>
                                    <th>{{ __('تم الرفع في') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @forelse($batches as $batch)
                                    <tr>
                                        <td>{{ $batch->plan?->name ?? '—' }}</td>
                                        <td>{{ $batch->label }}</td>
                                        <td><span class="badge bg-light text-dark">{{ $batch->status->label() }}</span></td>
                                        <td>{{ number_format($batch->available_codes ?? 0) }}</td>
                                        <td>{{ number_format($batch->total_codes ?? 0) }}</td>
                                        <td>{{ optional($batch->created_at)->format('Y-m-d H:i') }}</td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="6" class="text-center text-muted py-4">{{ __('لا توجد دفعات بعد.') }}</td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                    <div class="card-footer bg-white border-0">
                        {{ $batches->links() }}
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection

@push('scripts')
    <script>
        const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

        async function submitJsonForm(form, endpoint, payload, feedback) {
            if (feedback) {
                feedback.textContent = '{{ __('جاري المعالجة...') }}';
            }

            try {
                const response = await fetch(endpoint, {
                    method: 'PATCH',
                    headers: {
                        'Accept': 'application/json',
                        'Content-Type': 'application/json',
                        'X-CSRF-TOKEN': csrfToken,
                        'X-Requested-With': 'XMLHttpRequest',
                    },
                    body: JSON.stringify(payload),
                });

                let data = {};
                try {
                    data = await response.json();
                } catch (e) {
                    data = {};
                }

                if (!response.ok) {
                    throw new Error(data.message || Object.values(data.errors || {}).flat().join(' '));
                }

                if (feedback) {
                    feedback.textContent = '{{ __('تم التحديث بنجاح.') }}';
                }
            } catch (error) {
                if (feedback) {
                    feedback.textContent = error.message || '{{ __('حدث خطأ غير متوقع.') }}';
                }
            }
        }

        document.addEventListener('DOMContentLoaded', () => {
            const statusForm = document.getElementById('network-status-form');
            const commissionForm = document.getElementById('network-commission-form');
            const statusFeedback = document.getElementById('network-status-feedback');
            const commissionFeedback = document.getElementById('commission-feedback');

            statusForm.addEventListener('submit', async event => {
                event.preventDefault();
                const endpoint = statusForm.dataset.endpoint;
                const payload = {
                    status: statusForm.status.value,
                    reason: statusForm.reason.value || null,
                };
                await submitJsonForm(statusForm, endpoint, payload, statusFeedback);
                statusForm.reason.value = '';
            });

            statusForm.querySelector('[data-action="reset-status"]').addEventListener('click', () => {
                statusForm.reset();
                if (statusFeedback) {
                    statusFeedback.textContent = '';
                }
            });

            commissionForm.addEventListener('submit', async event => {
                event.preventDefault();
                const endpoint = commissionForm.dataset.endpoint;
                const payload = {
                    commission_rate: Number(commissionForm.commission_rate.value),
                };
                await submitJsonForm(commissionForm, endpoint, payload, commissionFeedback);
            });
        });
    </script>
@endpush
