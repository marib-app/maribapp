@extends('layouts.main')

@section('title', __('merchant_settings'))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">{{ __('merchant_settings_subtitle') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-end gap-2 flex-wrap">
                <a href="{{ route('merchant.dashboard') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i>
                    {{ __('merchant_settings_back_button') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    @php
        $availableTabs = ['general', 'payments', 'hours', 'policies', 'staff'];
        $activeTab = request('tab');
        if (! in_array($activeTab, $availableTabs, true)) {
            $activeTab = 'general';
        }
    @endphp
    <section class="section">
        <div class="row g-4">
            <div class="col-12">
                <div class="card">
                    <div class="card-body py-3">
                        <div class="nav nav-pills nav-fill flex-column flex-lg-row gap-2" id="storeSettingsTabs" role="tablist">
                            <button class="nav-link d-flex align-items-center justify-content-center gap-2 {{ $activeTab === 'general' ? 'active' : '' }}" id="tab-general-link" type="button"
                                    data-bs-toggle="pill" data-bs-target="#tab-general" role="tab" aria-controls="tab-general" aria-selected="{{ $activeTab === 'general' ? 'true' : 'false' }}">
                                <i class="bi bi-sliders"></i>
                                <span>{{ __('merchant_settings_tab_general') }}</span>
                            </button>
                            <button class="nav-link d-flex align-items-center justify-content-center gap-2 {{ $activeTab === 'payments' ? 'active' : '' }}" id="tab-payments-link" type="button"
                                    data-bs-toggle="pill" data-bs-target="#tab-payments" role="tab" aria-controls="tab-payments" aria-selected="{{ $activeTab === 'payments' ? 'true' : 'false' }}">
                                <i class="bi bi-bank"></i>
                                <span>{{ __('merchant_settings_tab_payments') }}</span>
                            </button>
                            <button class="nav-link d-flex align-items-center justify-content-center gap-2 {{ $activeTab === 'hours' ? 'active' : '' }}" id="tab-hours-link" type="button"
                                    data-bs-toggle="pill" data-bs-target="#tab-hours" role="tab" aria-controls="tab-hours" aria-selected="{{ $activeTab === 'hours' ? 'true' : 'false' }}">
                                <i class="bi bi-clock-history"></i>
                                <span>{{ __('merchant_settings_tab_hours') }}</span>
                            </button>
                            <button class="nav-link d-flex align-items-center justify-content-center gap-2 {{ $activeTab === 'policies' ? 'active' : '' }}" id="tab-policies-link" type="button"
                                    data-bs-toggle="pill" data-bs-target="#tab-policies" role="tab" aria-controls="tab-policies" aria-selected="{{ $activeTab === 'policies' ? 'true' : 'false' }}">
                                <i class="bi bi-file-earmark-text"></i>
                                <span>{{ __('merchant_settings_tab_policies') }}</span>
                            </button>
                            <button class="nav-link d-flex align-items-center justify-content-center gap-2 {{ $activeTab === 'staff' ? 'active' : '' }}" id="tab-staff-link" type="button"
                                    data-bs-toggle="pill" data-bs-target="#tab-staff" role="tab" aria-controls="tab-staff" aria-selected="{{ $activeTab === 'staff' ? 'true' : 'false' }}">
                                <i class="bi bi-people"></i>
                                <span>{{ __('merchant_settings_tab_staff') }}</span>
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="tab-content" id="storeSettingsTabsContent">
                    <div class="tab-pane fade {{ $activeTab === 'general' ? 'show active' : '' }}" id="tab-general" role="tabpanel" aria-labelledby="tab-general-link">
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">{{ __('merchant_settings_general_card_title') }}</h5>
                            </div>
                            <div class="card-body">
                                @php
                                    $statusData = $statusSummary ?? [];
                                    $manualClosed = (bool) ($statusData['is_manually_closed'] ?? false);
                                    $closureMode = $statusData['closure_mode'] ?? 'full';
                                    $isBrowseOnly = in_array($closureMode, ['browse', 'browse_only'], true);
                                    $isOpenNow = (bool) ($statusData['is_open_now'] ?? false);
                                    $statusTextKey = $manualClosed
                                        ? 'merchant_settings_status_manual_closed'
                                        : ($isBrowseOnly
                                            ? 'merchant_settings_status_browse_only'
                                            : ($isOpenNow ? 'merchant_settings_status_open' : 'merchant_settings_status_closed_hours'));
                                    $statusBadgeClass = $manualClosed
                                        ? 'bg-warning text-dark'
                                        : ($isBrowseOnly
                                            ? 'bg-info text-dark'
                                            : ($isOpenNow ? 'bg-success' : 'bg-secondary'));
                                    $paymentChips = [
                                        [
                                            'label' => __('merchant_settings_status_payments_manual'),
                                            'enabled' => (bool) ($statusData['allow_manual_payments'] ?? false),
                                        ],
                                        [
                                            'label' => __('merchant_settings_status_payments_wallet'),
                                            'enabled' => (bool) ($statusData['allow_wallet'] ?? false),
                                        ],
                                        [
                                            'label' => __('merchant_settings_status_payments_cod'),
                                            'enabled' => (bool) ($statusData['allow_cod'] ?? false),
                                        ],
                                    ];
                                    $hasEnabledPayments = collect($paymentChips)->first(static fn ($chip) => $chip['enabled']) !== null;
                                @endphp
                                <div class="row g-3 mb-4">
                                    <div class="col-lg-6">
                                        <div class="border rounded p-3 h-100 bg-light-subtle">
                                            <div class="d-flex align-items-center gap-2 mb-2">
                                                <span class="badge {{ $statusBadgeClass }}">{{ __('merchant_settings_status_title') }}</span>
                                                <span class="small text-muted">{{ $store->name }}</span>
                                            </div>
                                            <p class="mb-1 fw-semibold">{{ __($statusTextKey) }}</p>
                                            @if ($manualClosed)
                                                @if (! empty($statusData['closure_reason']))
                                                    <p class="text-muted small mb-1">
                                                        {{ __('merchant_settings_status_manual_reason', ['reason' => $statusData['closure_reason']]) }}
                                                    </p>
                                                @endif
                                                @if (! empty($statusData['manual_closure_expires_at']))
                                                    <p class="text-muted small mb-0">
                                                        {{ __('merchant_settings_status_manual_until', [
                                                            'datetime' => \Carbon\Carbon::parse($statusData['manual_closure_expires_at'])->format('Y-m-d H:i'),
                                                        ]) }}
                                                    </p>
                                                @endif
                                            @elseif (! $isOpenNow && ! empty($statusData['next_open_at']))
                                                <p class="text-muted small mb-0">
                                                    {{ __('merchant_settings_status_next_open', [
                                                        'datetime' => \Carbon\Carbon::parse($statusData['next_open_at'])->format('Y-m-d H:i'),
                                                    ]) }}
                                                </p>
                                            @elseif (! ($statusData['today_schedule']['is_open'] ?? false))
                                                <p class="text-muted small mb-0">{{ __('merchant_settings_status_closed_today') }}</p>
                                            @endif
                                        </div>
                                    </div>
                                    <div class="col-lg-6">
                                        <div class="border rounded p-3 h-100">
                                            <div class="d-flex align-items-center gap-2 mb-2">
                                                <span class="badge bg-secondary">{{ __('merchant_settings_status_payments_title') }}</span>
                                            </div>
                                            <div class="d-flex flex-wrap gap-2">
                                                @foreach ($paymentChips as $chip)
                                                    <span class="badge px-3 py-2 {{ $chip['enabled'] ? 'bg-success' : 'bg-light text-muted border' }}">
                                                        {{ $chip['label'] }}
                                                    </span>
                                                @endforeach
                                            </div>
                                            @unless ($hasEnabledPayments)
                                                <p class="text-muted small mb-0 mt-2">
                                                    {{ __('merchant_settings_status_payments_disabled') }}
                                                </p>
                                            @endunless
                                        </div>
                                    </div>
                                </div>
                                <div class="alert alert-info d-flex align-items-center gap-2">
                                    <i class="bi bi-truck"></i>
                                    <span>{{ __('merchant_settings_general_alert') }}</span>
                                </div>
                                <form method="post" action="{{ route('merchant.settings.general', ['tab' => 'general']) }}">
                                    @csrf
                                    <div class="row g-3">
                                        <div class="col-md-6">
                                            <label class="form-label">{{ __('merchant_settings_min_order_label') }}</label>
                                            @php($minOrderError = $errors->first('min_order_amount'))
                                            <input
                                                type="number"
                                                name="min_order_amount"
                                                step="0.01"
                                                min="0"
                                                class="form-control {{ $minOrderError ? 'is-invalid' : '' }}"
                                                value="{{ old('min_order_amount', $settings->min_order_amount) }}"
                                            >
                                            @if ($minOrderError)
                                                <div class="invalid-feedback">{{ $minOrderError }}</div>
                                            @endif
                                        </div>
                                        <div class="col-md-6">
                                            <label class="form-label">{{ __('merchant_settings_closure_mode_label') }}</label>
                                            @php($closureModeError = $errors->first('closure_mode'))
                                            <select
                                                name="closure_mode"
                                                class="form-select {{ $closureModeError ? 'is-invalid' : '' }}"
                                            >
                                                <option value="full" @selected(old('closure_mode', $settings->closure_mode) === 'full')>
                                                    {{ __('merchant_settings_closure_full_option') }}
                                                </option>
                                                <option value="browse" @selected(old('closure_mode', $settings->closure_mode) === 'browse')>
                                                    {{ __('merchant_settings_closure_browse_option') }}
                                                </option>
                                            </select>
                                            @if ($closureModeError)
                                                <div class="invalid-feedback">{{ $closureModeError }}</div>
                                            @endif
                                        </div>
                                        <div class="col-md-3">
                                            <div class="form-check form-switch mt-4">
                                                <input class="form-check-input" type="checkbox" role="switch" id="manualPaymentsSwitch"
                                                       name="allow_manual_payments" value="1" @checked(old('allow_manual_payments', $settings->allow_manual_payments))>
                                                <label class="form-check-label" for="manualPaymentsSwitch">{{ __('merchant_settings_allow_manual_payments') }}</label>
                                            </div>
                                        </div>
                                    <div class="col-md-3">
                                        <div class="form-check form-switch mt-4">
                                            <input class="form-check-input" type="checkbox" role="switch" id="walletSwitch"
                                                   name="allow_wallet" value="1" @checked(old('allow_wallet', $settings->allow_wallet))>
                                            <label class="form-check-label" for="walletSwitch">{{ __('merchant_settings_allow_wallet') }}</label>
                                        </div>
                                    </div>
                                    <div class="col-md-3">
                                        <div class="form-check form-switch mt-4">
                                            <input class="form-check-input" type="checkbox" role="switch" id="allowCodSwitch"
                                                   name="allow_cod" value="1"
                                                   data-cod-warning="{{ __('merchant_settings_cod_warning') }}"
                                                   data-cod-warning-title="{{ __('merchant_settings_cod_warning_title') }}"
                                                   data-cod-confirm-text="{{ __('merchant_settings_cod_confirm') }}"
                                                   data-cod-cancel-text="{{ __('merchant_settings_cod_cancel') }}"
                                                   @checked(old('allow_cod', $settings->allow_cod))>
                                            <label class="form-check-label" for="allowCodSwitch">{{ __('merchant_settings_allow_cod') }}</label>
                                        </div>
                                    </div>
                                        <div class="col-md-3">
                                            <div class="form-check form-switch mt-4">
                                                <input class="form-check-input" type="checkbox" role="switch" id="autoAcceptSwitch"
                                                       name="auto_accept_orders" value="1" @checked(old('auto_accept_orders', $settings->auto_accept_orders))>
                                                <label class="form-check-label" for="autoAcceptSwitch">{{ __('merchant_settings_auto_accept') }}</label>
                                            </div>
                                        </div>
                                        <div class="col-md-6">
                                            <label class="form-label">{{ __('merchant_settings_acceptance_buffer') }}</label>
                                            @php($bufferError = $errors->first('order_acceptance_buffer_minutes'))
                                            <input
                                                type="number"
                                                name="order_acceptance_buffer_minutes"
                                                min="0"
                                                max="1440"
                                                class="form-control {{ $bufferError ? 'is-invalid' : '' }}"
                                                value="{{ old('order_acceptance_buffer_minutes', $settings->order_acceptance_buffer_minutes) }}"
                                            >
                                            @if ($bufferError)
                                                <div class="invalid-feedback">{{ $bufferError }}</div>
                                            @endif
                                        </div>
                                        <div class="col-md-6">
                                            <div class="form-check form-switch mt-4">
                                                <input class="form-check-input" type="checkbox" role="switch" id="manualClosureSwitch"
                                                       name="is_manually_closed" value="1" @checked(old('is_manually_closed', $settings->is_manually_closed))>
                                                <label class="form-check-label" for="manualClosureSwitch">{{ __('merchant_settings_manual_closure') }}</label>
                                            </div>
                                        </div>
                                        <div class="col-md-6">
                                            <label class="form-label">{{ __('merchant_settings_manual_closure_reason') }}</label>
                                            @php($manualReasonError = $errors->first('manual_closure_reason'))
                                            <input
                                                type="text"
                                                name="manual_closure_reason"
                                                class="form-control {{ $manualReasonError ? 'is-invalid' : '' }}"
                                                maxlength="500"
                                                value="{{ old('manual_closure_reason', $settings->manual_closure_reason) }}"
                                            >
                                            @if ($manualReasonError)
                                                <div class="invalid-feedback">{{ $manualReasonError }}</div>
                                            @endif
                                        </div>
                                        <div class="col-md-6">
                                            <label class="form-label">{{ __('merchant_settings_manual_closure_until') }}</label>
                                            @php($manualUntilError = $errors->first('manual_closure_expires_at'))
                                            <input
                                                type="datetime-local"
                                                name="manual_closure_expires_at"
                                                class="form-control {{ $manualUntilError ? 'is-invalid' : '' }}"
                                                value="{{ old('manual_closure_expires_at', optional($settings->manual_closure_expires_at)->format('Y-m-d\\TH:i')) }}"
                                            >
                                            @if ($manualUntilError)
                                                <div class="invalid-feedback">{{ $manualUntilError }}</div>
                                            @endif
                                        </div>
                                        <div class="col-12">
                                            <label class="form-label">{{ __('merchant_settings_checkout_notice') }}</label>
                                            @php($checkoutNoticeError = $errors->first('checkout_notice'))
                                            <textarea
                                                name="checkout_notice"
                                                rows="3"
                                                class="form-control {{ $checkoutNoticeError ? 'is-invalid' : '' }}"
                                            >{{ old('checkout_notice', $settings->checkout_notice) }}</textarea>
                                            @if ($checkoutNoticeError)
                                                <div class="invalid-feedback">{{ $checkoutNoticeError }}</div>
                                            @endif
                                        </div>
                                    </div>
                                    <div class="d-flex justify-content-end mt-4">
                                        <button type="submit" class="btn btn-primary">
                                            <i class="bi bi-save"></i>
                                            {{ __('merchant_settings_save_button') }}
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>

                    <div class="tab-pane fade {{ $activeTab === 'payments' ? 'show active' : '' }}" id="tab-payments" role="tabpanel" aria-labelledby="tab-payments-link">
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">{{ __('merchant_settings_payment_methods_title') }}</h5>
                            </div>
                            <div class="card-body">
                                <h6 class="mb-3">{{ __('merchant_settings_payment_methods_form_title') }}</h6>
                        <form method="post" action="{{ route('merchant.settings.gateway-accounts.store', ['tab' => 'payments']) }}" class="row g-3 mb-4">
                                    @csrf
                                    <div class="col-md-4">
                                        <label class="form-label">{{ __('merchant_settings_payment_methods_select') }}</label>
                                        @php($gatewayError = $errors->first('store_gateway_id'))
                                        <select name="store_gateway_id" class="form-select {{ $gatewayError ? 'is-invalid' : '' }}">
                                            <option value="">{{ __('merchant_settings_payment_methods_select_placeholder') }}</option>
                                            @foreach ($storeGateways as $gateway)
                                                <option value="{{ $gateway->id }}" @selected(old('store_gateway_id') == $gateway->id)>{{ $gateway->name }}</option>
                                            @endforeach
                                        </select>
                                        @if ($gatewayError)
                                            <div class="invalid-feedback">{{ $gatewayError }}</div>
                                        @endif
                                    </div>
                                    <div class="col-md-4">
                                        <label class="form-label">{{ __('merchant_settings_payment_methods_beneficiary') }}</label>
                                        @php($beneficiaryError = $errors->first('beneficiary_name'))
                                        <input type="text" name="beneficiary_name" class="form-control {{ $beneficiaryError ? 'is-invalid' : '' }}"
                                               value="{{ old('beneficiary_name') }}" maxlength="255">
                                        @if ($beneficiaryError)
                                            <div class="invalid-feedback">{{ $beneficiaryError }}</div>
                                        @endif
                                    </div>
                                    <div class="col-md-4">
                                        <label class="form-label">{{ __('merchant_settings_payment_methods_account') }}</label>
                                        @php($accountError = $errors->first('account_number'))
                                        <input type="text" name="account_number" class="form-control {{ $accountError ? 'is-invalid' : '' }}"
                                               value="{{ old('account_number') }}" maxlength="255">
                                        @if ($accountError)
                                            <div class="invalid-feedback">{{ $accountError }}</div>
                                        @endif
                                    </div>
                                    <div class="col-md-3 form-check form-switch mt-4 pt-2">
                                        <input class="form-check-input" type="checkbox" id="createAccountActiveSwitch" name="is_active" value="1"
                                               @checked(old('is_active', true))>
                                        <label class="form-check-label" for="createAccountActiveSwitch">{{ __('merchant_settings_payment_methods_active') }}</label>
                                    </div>
                                    <div class="col-md-9 text-end mt-4 pt-2">
                                        <button type="submit" class="btn btn-success">
                                            <i class="bi bi-plus-circle"></i>
                                            {{ __('merchant_settings_payment_methods_add') }}
                                        </button>
                                    </div>
                                </form>

                                <h6 class="mb-3">{{ __('merchant_settings_payment_methods_existing') }}</h6>
                                @forelse ($gatewayAccounts as $account)
                                    <div class="border rounded p-3 mb-3">
                                <form method="post" action="{{ route('merchant.settings.gateway-accounts.update', ['storeGatewayAccount' => $account, 'tab' => 'payments']) }}">
                                            @csrf
                                            @method('put')
                                            <div class="row g-3 align-items-end">
                                                <div class="col-md-3">
                                                    <label class="form-label">{{ __('merchant_settings_payment_methods_select') }}</label>
                                                    <select name="store_gateway_id" class="form-select">
                                                        @foreach ($storeGateways as $gateway)
                                                            <option value="{{ $gateway->id }}" @selected(old('store_gateway_id', $account->store_gateway_id) == $gateway->id)>
                                                                {{ $gateway->name }}
                                                            </option>
                                                        @endforeach
                                                    </select>
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">{{ __('merchant_settings_payment_methods_beneficiary') }}</label>
                                                    <input type="text" name="beneficiary_name" class="form-control"
                                                           value="{{ old('beneficiary_name', $account->beneficiary_name) }}">
                                                </div>
                                                <div class="col-md-3">
                                                    <label class="form-label">{{ __('merchant_settings_payment_methods_account') }}</label>
                                                    <input type="text" name="account_number" class="form-control"
                                                           value="{{ old('account_number', $account->account_number) }}">
                                                </div>
                                                <div class="col-md-2">
                                                    <div class="form-check form-switch">
                                                        <input class="form-check-input" type="checkbox" id="account-active-{{ $account->id }}"
                                                               name="is_active" value="1" @checked(old('is_active', $account->is_active))>
                                                        <label class="form-check-label" for="account-active-{{ $account->id }}">{{ __('merchant_settings_payment_methods_active') }}</label>
                                                    </div>
                                                </div>
                                                <div class="col-md-1 text-end">
                                                    <button type="submit" class="btn btn-primary btn-sm w-100">
                                                        <i class="bi bi-save"></i>
                                                    </button>
                                                </div>
                                            </div>
                                        </form>
                                <form method="post" action="{{ route('merchant.settings.gateway-accounts.destroy', ['storeGatewayAccount' => $account, 'tab' => 'payments']) }}"
                                              class="mt-2 text-end">
                                            @csrf
                                            @method('delete')
                                            <button type="submit" class="btn btn-outline-danger btn-sm"
                                                    onclick="return confirm('{{ __('merchant_settings_payment_methods_delete_confirm') }}')">
                                                <i class="bi bi-trash"></i> {{ __('merchant_settings_payment_methods_delete') }}
                                            </button>
                                        </form>
                                    </div>
                                @empty
                                    <p class="text-muted mb-0">{{ __('merchant_settings_payment_methods_empty') }}</p>
                                @endforelse
                            </div>
                        </div>
                    </div>

                    <div class="tab-pane fade {{ $activeTab === 'hours' ? 'show active' : '' }}" id="tab-hours" role="tabpanel" aria-labelledby="tab-hours-link">
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">{{ __('merchant_settings_hours_title') }}</h5>
                            </div>
                            <div class="card-body">
                                <small class="text-muted d-block mb-3">{{ __('merchant_settings_hours_helper') }}</small>
                        <form method="post" action="{{ route('merchant.settings.hours', ['tab' => 'hours']) }}">
                                    @csrf
                                    <div class="table-responsive">
                                        <table class="table align-middle">
                                            <thead>
                                                <tr>
                                                    <th>{{ __('merchant_settings_hours_weekday') }}</th>
                                                    <th>{{ __('merchant_settings_hours_open') }}</th>
                                                    <th>{{ __('merchant_settings_hours_from') }}</th>
                                                    <th>{{ __('merchant_settings_hours_to') }}</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                @foreach ($weekdays as $day => $label)
                                                    @php($hour = $workingHours[$day])
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
                                                        <td>
                                                            @php($openError = $errors->first("hours.$day.opens_at"))
                                                            <input
                                                                type="time"
                                                                name="hours[{{ $day }}][opens_at]"
                                                                class="form-control {{ $openError ? 'is-invalid' : '' }}"
                                                                value="{{ old("hours.$day.opens_at", $hour['opens_at']) }}"
                                                            >
                                                            @if ($openError)
                                                                <div class="invalid-feedback">{{ $openError }}</div>
                                                            @endif
                                                        </td>
                                                        <td>
                                                            @php($closeError = $errors->first("hours.$day.closes_at"))
                                                            <input
                                                                type="time"
                                                                name="hours[{{ $day }}][closes_at]"
                                                                class="form-control {{ $closeError ? 'is-invalid' : '' }}"
                                                                value="{{ old("hours.$day.closes_at", $hour['closes_at']) }}"
                                                            >
                                                            @if ($closeError)
                                                                <div class="invalid-feedback">{{ $closeError }}</div>
                                                            @endif
                                                        </td>
                                                    </tr>
                                                @endforeach
                                            </tbody>
                                        </table>
                                    </div>
                                    <div class="d-flex justify-content-end">
                                        <button type="submit" class="btn btn-primary">
                                            <i class="bi bi-clock-history"></i>
                                            {{ __('merchant_settings_hours_save') }}
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>

                    <div class="tab-pane fade {{ $activeTab === 'policies' ? 'show active' : '' }}" id="tab-policies" role="tabpanel" aria-labelledby="tab-policies-link">
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">{{ __('merchant_settings_policies_title') }}</h5>
                            </div>
                            <div class="card-body">
                        <form method="post" action="{{ route('merchant.settings.policies', ['tab' => 'policies']) }}">
                                    @csrf
                                    <div class="mb-3">
                                        <label class="form-label">{{ __('merchant_settings_policies_label') }}</label>
                                        @php($policyError = $errors->first('policy_text'))
                                        <textarea
                                            name="policy_text"
                                            rows="4"
                                            class="form-control {{ $policyError ? 'is-invalid' : '' }}"
                                        >{{ old('policy_text', optional($policies['return'] ?? $policies['exchange'])->content) }}</textarea>
                                        @if ($policyError)
                                            <div class="invalid-feedback">{{ $policyError }}</div>
                                        @endif
                                    </div>
                                    <div class="d-flex justify-content-end">
                                        <button type="submit" class="btn btn-primary">
                                            <i class="bi bi-file-earmark-text"></i>
                                            {{ __('merchant_settings_policies_save') }}
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>

                    <div class="tab-pane fade {{ $activeTab === 'staff' ? 'show active' : '' }}" id="tab-staff" role="tabpanel" aria-labelledby="tab-staff-link">
                        <div class="card mb-4">
                            <div class="card-header">
                                <h5 class="mb-0">{{ __('merchant_settings_staff_title') }}</h5>
                            </div>
                            <div class="card-body">
                                <p class="text-muted">
                                    {{ __('merchant_settings_staff_intro') }}
                                </p>
                        <form method="post" action="{{ route('merchant.settings.staff', ['tab' => 'staff']) }}">
                                    @csrf
                                    <div class="mb-3">
                                        <label class="form-label">{{ __('merchant_settings_staff_prefix_label') }}</label>
                                        <div class="input-group">
                                            @php($staffPrefixError = $errors->first('staff_prefix'))
                                            <input
                                                type="text"
                                                name="staff_prefix"
                                                class="form-control {{ $staffPrefixError ? 'is-invalid' : '' }}"
                                                placeholder="store.team"
                                                value="{{ old('staff_prefix', optional($staff)->email ? strtok(optional($staff)->email, '@') : '') }}"
                                            >
                                            <span class="input-group-text">@maribsrv.com</span>
                                        </div>
                                        @if ($staffPrefixError)
                                            <div class="invalid-feedback d-block">{{ $staffPrefixError }}</div>
                                        @endif
                                        <small class="text-muted">
                                            {{ __('merchant_settings_staff_prefix_hint') }}
                                        </small>
                                    </div>
                                    <div class="d-flex justify-content-end">
                                        <button type="submit" class="btn btn-primary">
                                            <i class="bi bi-envelope-plus"></i>
                                            {{ __('merchant_settings_staff_save') }}
                                        </button>
                                    </div>
                                </form>

                                @if ($staff)
                                    <div class="alert alert-success mt-4 mb-0">
                                        <div class="d-flex justify-content-between align-items-center">
                                            <div>
                                                <span class="d-block fw-semibold">{{ $staff->email }}</span>
                                                <small class="text-muted">{{ __('merchant_settings_staff_status') }}: {{ __($staff->status) }}</small>
                                            </div>
                                        </div>
                                    </div>
                                @endif
                            </div>
                        </div>

                        <div class="card">
                            <div class="card-header">
                                <h6 class="mb-0">{{ __('merchant_settings_help_title') }}</h6>
                            </div>
                            <div class="card-body">
                                <p class="text-muted mb-2">
                                    {{ __('merchant_settings_help_body_one') }}
                                </p>
                                <p class="text-muted mb-0">
                                    {{ __('merchant_settings_help_body_two') }}
                                </p>
                            </div>
                        </div>
                    </div>

                </div>
            </div>
        </div>
    </section>
@endsection

@push('scripts')
    <script src="{{ asset('assets/js/custom/merchant-settings.js') }}"></script>
@endpush
