@extends('layouts.main')

@section('title', __('إعدادات المتجر'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('اضبط سياسات متجرك، ساعات العمل، وخيارات الإغلاق من مكان واحد.') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end gap-2 flex-wrap">
                <a href="{{ route('merchant.dashboard') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i>
                    {{ __('العودة للوحة التاجر') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-4">
            <div class="col-lg-8">
                <div class="card mb-4">
                    <div class="card-header">
                        <h5 class="mb-0">{{ __('الإعدادات العامة') }}</h5>
                    </div>
                    <div class="card-body">
                        <form method="post" action="{{ route('merchant.settings.general') }}">
                            @csrf
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('الحد الأدنى للطلب') }}</label>
                                    <input
                                        type="number"
                                        name="min_order_amount"
                                        step="0.01"
                                        min="0"
                                        class="form-control @error('min_order_amount') is-invalid @enderror"
                                        value="{{ old('min_order_amount', $settings->min_order_amount) }}"
                                    >
                                    @error('min_order_amount')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('نمط الإغلاق عند التعطيل') }}</label>
                                    <select
                                        name="closure_mode"
                                        class="form-select @error('closure_mode') is-invalid @enderror"
                                    >
                                        <option value="full" @selected(old('closure_mode', $settings->closure_mode) === 'full')>
                                            {{ __('إغلاق كامل (منع التصفح)') }}
                                        </option>
                                        <option value="browse" @selected(old('closure_mode', $settings->closure_mode) === 'browse')>
                                            {{ __('السماح بالتصفح فقط') }}
                                        </option>
                                    </select>
                                    @error('closure_mode')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-4">
                                    <div class="form-check form-switch mt-4">
                                        <input class="form-check-input" type="checkbox" role="switch" id="allowDeliverySwitch"
                                               name="allow_delivery" value="1"
                                               @checked(old('allow_delivery', $settings->allow_delivery))>
                                        <label class="form-check-label" for="allowDeliverySwitch">
                                            {{ __('السماح بالتوصيل') }}
                                        </label>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="form-check form-switch mt-4">
                                        <input class="form-check-input" type="checkbox" role="switch" id="allowPickupSwitch"
                                               name="allow_pickup" value="1"
                                               @checked(old('allow_pickup', $settings->allow_pickup))>
                                        <label class="form-check-label" for="allowPickupSwitch">
                                            {{ __('السماح بالاستلام من المتجر') }}
                                        </label>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="form-check form-switch mt-4">
                                        <input class="form-check-input" type="checkbox" role="switch" id="manualPaymentsSwitch"
                                               name="allow_manual_payments" value="1"
                                               @checked(old('allow_manual_payments', $settings->allow_manual_payments))>
                                        <label class="form-check-label" for="manualPaymentsSwitch">
                                            {{ __('السماح بالحوالات اليدوية') }}
                                        </label>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch" id="walletSwitch"
                                               name="allow_wallet" value="1"
                                               @checked(old('allow_wallet', $settings->allow_wallet))>
                                        <label class="form-check-label" for="walletSwitch">
                                            {{ __('السماح بالدفع بالمحفظة') }}
                                        </label>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                        <div class="form-check form-switch">
                                            <input class="form-check-input" type="checkbox" role="switch" id="codSwitch"
                                                   name="allow_cod" value="1"
                                                   @checked(old('allow_cod', $settings->allow_cod))>
                                            <label class="form-check-label" for="codSwitch">
                                                {{ __('السماح بالدفع نقداً عند التسليم') }}
                                            </label>
                                        </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch" id="autoAcceptSwitch"
                                               name="auto_accept_orders" value="1"
                                               @checked(old('auto_accept_orders', $settings->auto_accept_orders))>
                                        <label class="form-check-label" for="autoAcceptSwitch">
                                            {{ __('قبول الطلبات تلقائياً') }}
                                        </label>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('مهلة قبول الطلب (دقائق)') }}</label>
                                    <input
                                        type="number"
                                        name="order_acceptance_buffer_minutes"
                                        class="form-control @error('order_acceptance_buffer_minutes') is-invalid @enderror"
                                        value="{{ old('order_acceptance_buffer_minutes', $settings->order_acceptance_buffer_minutes) }}"
                                        min="0"
                                        max="1440"
                                    >
                                    @error('order_acceptance_buffer_minutes')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('نطاق التوصيل (كم)') }}</label>
                                    <input
                                        type="number"
                                        name="delivery_radius_km"
                                        step="0.1"
                                        min="0"
                                        class="form-control @error('delivery_radius_km') is-invalid @enderror"
                                        value="{{ old('delivery_radius_km', $settings->delivery_radius_km) }}"
                                    >
                                    @error('delivery_radius_km')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-12">
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" role="switch" id="manualClosureSwitch"
                                               name="is_manually_closed" value="1"
                                               @checked(old('is_manually_closed', $settings->is_manually_closed))>
                                        <label class="form-check-label" for="manualClosureSwitch">
                                            {{ __('إغلاق المتجر يدوياً') }}
                                        </label>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('سبب الإغلاق') }}</label>
                                    <textarea
                                        name="manual_closure_reason"
                                        class="form-control @error('manual_closure_reason') is-invalid @enderror"
                                        rows="2"
                                    >{{ old('manual_closure_reason', $settings->manual_closure_reason) }}</textarea>
                                    @error('manual_closure_reason')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">{{ __('ينتهي الإغلاق في') }}</label>
                                    <input
                                        type="datetime-local"
                                        name="manual_closure_expires_at"
                                        class="form-control @error('manual_closure_expires_at') is-invalid @enderror"
                                        value="{{ old('manual_closure_expires_at', optional($settings->manual_closure_expires_at)->format('Y-m-d\TH:i')) }}"
                                    >
                                    @error('manual_closure_expires_at')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-12">
                                    <label class="form-label">{{ __('رسالة تظهر في صفحة الدفع') }}</label>
                                    <textarea
                                        name="checkout_notice"
                                        rows="3"
                                        class="form-control @error('checkout_notice') is-invalid @enderror"
                                    >{{ old('checkout_notice', $settings->checkout_notice) }}</textarea>
                                    @error('checkout_notice')
                                        <div class="invalid-feedback">{{ $message }}</div>
                                    @enderror
                                </div>
                            </div>
                            <div class="d-flex justify-content-end mt-4">
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-save"></i>
                                    {{ __('حفظ الإعدادات') }}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('ساعات العمل الأسبوعية') }}</h5>
                        <small class="text-muted">{{ __('استخدم صيغة 24 ساعة (مثال 09:00)') }}</small>
                    </div>
                    <div class="card-body">
                        <form method="post" action="{{ route('merchant.settings.hours') }}">
                            @csrf
                            <div class="table-responsive">
                                <table class="table align-middle">
                                    <thead>
                                        <tr>
                                            <th>{{ __('اليوم') }}</th>
                                            <th>{{ __('مفتوح') }}</th>
                                            <th>{{ __('يفتح') }}</th>
                                            <th>{{ __('يغلق') }}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        @foreach ($weekdays as $day => $label)
                                            @php
                                                $hour = $workingHours[$day];
                                            @endphp
                                            <tr>
                                                <td>
                                                    {{ $label }}
                                                    <input type="hidden" name="hours[{{ $day }}][weekday]" value="{{ $day }}">
                                                </td>
                                                <td>
                                                    <div class="form-check form-switch">
                                                        <input
                                                            class="form-check-input"
                                                            type="checkbox"
                                                            name="hours[{{ $day }}][is_open]"
                                                            value="1"
                                                            @checked(old("hours.$day.is_open", $hour['is_open']))
                                                        >
                                                    </div>
                                                </td>
                                                <td style="max-width: 140px;">
                                                    <input
                                                        type="time"
                                                        class="form-control @error(\"hours.$day.opens_at\") is-invalid @enderror"
                                                        name="hours[{{ $day }}][opens_at]"
                                                        value="{{ old("hours.$day.opens_at", $hour['opens_at']) }}"
                                                    >
                                                    @error("hours.$day.opens_at")
                                                        <div class="invalid-feedback">{{ $message }}</div>
                                                    @enderror
                                                </td>
                                                <td style="max-width: 140px;">
                                                    <input
                                                        type="time"
                                                        class="form-control @error(\"hours.$day.closes_at\") is-invalid @enderror"
                                                        name="hours[{{ $day }}][closes_at]"
                                                        value="{{ old("hours.$day.closes_at", $hour['closes_at']) }}"
                                                    >
                                                    @error("hours.$day.closes_at")
                                                        <div class="invalid-feedback">{{ $message }}</div>
                                                    @enderror
                                                </td>
                                            </tr>
                                        @endforeach
                                    </tbody>
                                </table>
                            </div>
                            <div class="d-flex justify-content-end">
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-clock-history"></i>
                                    {{ __('حفظ الساعات') }}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header">
                        <h5 class="mb-0">{{ __('السياسات الإلزامية') }}</h5>
                    </div>
                    <div class="card-body">
                        <form method="post" action="{{ route('merchant.settings.policies') }}">
                            @csrf
                            <div class="mb-3">
                                <label class="form-label">{{ __('سياسة الاسترجاع') }}</label>
                                <textarea
                                    name="return_policy"
                                    rows="4"
                                    class="form-control @error('return_policy') is-invalid @enderror"
                                >{{ old('return_policy', optional($policies['return'])->content) }}</textarea>
                                @error('return_policy')
                                    <div class="invalid-feedback">{{ $message }}</div>
                                @enderror
                            </div>
                            <div class="mb-3">
                                <label class="form-label">{{ __('سياسة الاستبدال') }}</label>
                                <textarea
                                    name="exchange_policy"
                                    rows="4"
                                    class="form-control @error('exchange_policy') is-invalid @enderror"
                                >{{ old('exchange_policy', optional($policies['exchange'])->content) }}</textarea>
                                @error('exchange_policy')
                                    <div class="invalid-feedback">{{ $message }}</div>
                                @enderror
                            </div>
                            <div class="d-flex justify-content-end">
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-file-earmark-text"></i>
                                    {{ __('حفظ السياسات') }}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>

            <div class="col-lg-4">
                <div class="card mb-4">
                    <div class="card-header">
                        <h5 class="mb-0">{{ __('بريد لوحة المتجر') }}</h5>
                    </div>
                    <div class="card-body">
                        <p class="text-muted">
                            {{ __('قم باختيار معرف المستخدم ليتم إنشاء بريد تلقائي للتحكم في المتجر عبر لوحة الويب.') }}
                        </p>
                        @if ($staff)
                            <div class="alert alert-success d-flex justify-content-between align-items-center">
                                <div>
                                    <span class="d-block fw-semibold">{{ __('البريد المفعل') }}</span>
                                    <small>{{ $staff->email }}</small>
                                </div>
                                <span class="badge bg-{{ $staff->status === 'active' ? 'success' : 'warning' }}">
                                    {{ __($staff->status) }}
                                </span>
                            </div>
                        @endif
                        <form method="post" action="{{ route('merchant.settings.staff') }}">
                            @csrf
                            <div class="mb-3">
                                <label class="form-label">{{ __('المعرف المطلوب') }}</label>
                                <div class="input-group">
                                    <input
                                        type="text"
                                        name="staff_prefix"
                                        class="form-control @error('staff_prefix') is-invalid @enderror"
                                        placeholder="store.team"
                                        value="{{ old('staff_prefix') }}"
                                    >
                                    <span class="input-group-text">@maribsrv.com</span>
                                    @error('staff_prefix')
                                        <div class="invalid-feedback d-block">{{ $message }}</div>
                                    @enderror
                                </div>
                                <small class="text-muted">
                                    {{ __('يجب أن يكون فريداً ويحوي أحرفاً أو أرقاماً أو شرطات/نقاط فقط.') }}
                                </small>
                            </div>
                            <div class="d-flex justify-content-end">
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-envelope-plus"></i>
                                    {{ $staff ? __('تحديث البريد') : __('حجز البريد') }}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('نصائح سريعة') }}</h6>
                    </div>
                    <div class="card-body">
                        <ul class="list-unstyled mb-0">
                            <li class="mb-3">
                                <strong>{{ __('الإغلاق اليدوي:') }}</strong>
                                <span class="text-muted">{{ __('استخدمه عند الإجازات أو الصيانة، وحدد تاريخ العودة.') }}</span>
                            </li>
                            <li class="mb-3">
                                <strong>{{ __('ساعات العمل:') }}</strong>
                                <span class="text-muted">{{ __('تظهر للعملاء لمعرفة أوقات فتح المتجر وإغلاقه.') }}</span>
                            </li>
                            <li>
                                <strong>{{ __('البريد المخصص:') }}</strong>
                                <span class="text-muted">{{ __('سيُستخدم هذا البريد للدخول إلى لوحة المتجر وإدارة الطلبات.') }}</span>
                            </li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
