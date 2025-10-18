{{-- resources/views/wifi/edit.blade.php --}}
@extends('layouts.main')

@php
    $networkName = data_get($network ?? [], 'name', __('WiFi Cabin Details'));



    $networkId = data_get($network ?? [], 'id');
    $logoPath = data_get($network ?? [], 'logo_path');
    $loginScreenshotPath = data_get($network ?? [], 'login_screenshot_path');
    $logoUrl = $logoPath ? \Illuminate\Support\Facades\Storage::disk('public')->url($logoPath) : null;
    $loginScreenshotUrl = $loginScreenshotPath ? \Illuminate\Support\Facades\Storage::disk('public')->url($loginScreenshotPath) : null;
    $contactsCollection = collect(data_get($network ?? [], 'contacts', []))->filter();
    $contactsTextarea = $contactsCollection->implode("\n");
    $oldContacts = old('contacts');
    if (is_array($oldContacts)) {
        $contactsFieldValue = implode("\n", array_filter($oldContacts));
    } elseif ($oldContacts !== null) {
        $contactsFieldValue = $oldContacts;
    } else {
        $contactsFieldValue = $contactsTextarea;
    }


@endphp

@section('title')
    {{ $networkName }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4 class="mb-1">{{ $networkName }}</h4>
                <p class="text-muted mb-0">{{ __('Adjust plan availability, review stock and monitor alerts for this cabin.') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                <div class="d-flex justify-content-md-end gap-2 mt-3 mt-md-0">
                    <a href="{{ route('wifi.index') }}" class="btn btn-outline-secondary">
                        <i class="bi bi-arrow-right-circle"></i>
                        {{ __('Back to WiFi dashboard') }}
                    </a>
                </div>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-4">
            <div class="col-12 col-xl-4">
                <div class="card shadow-sm h-100">
                    <div class="card-header border-0 pb-0">
                        <h5 class="card-title mb-1">{{ __('Network overview') }}</h5>
                        <p class="text-muted small mb-0">{{ __('Key identifiers and operational metadata for this WiFi cabin.') }}</p>
                    </div>
                    <div class="card-body">
                        @php
                            $status = data_get($network, 'status', __('Unknown'));
                            $statusClass = $status === 'active' ? 'bg-success' : ($status === 'inactive' ? 'bg-secondary' : 'bg-warning');
                        @endphp
                        <div class="d-flex align-items-center gap-3 mb-3">
                            <div class="avatar avatar-lg bg-primary-subtle text-primary fw-semibold">
                                <i class="bi bi-hdd-network"></i>
                            </div>
                            <div>
                                <h5 class="mb-1">{{ data_get($network, 'name', __('Unnamed Network')) }}</h5>
                                <span class="badge {{ $statusClass }} text-uppercase">{{ \Illuminate\Support\Str::upper($status) }}</span>
                            </div>
                        </div>
                        <dl class="row mb-0 small">
                            <dt class="col-5 text-muted">{{ __('Identifier') }}</dt>
                            <dd class="col-7 fw-semibold">{{ data_get($network, 'identifier', data_get($network, 'code', '—')) }}</dd>


                            <dt class="col-5 text-muted">{{ __('Slug') }}</dt>
                            <dd class="col-7 fw-semibold">{{ data_get($network, 'slug', '—') }}</dd>




                            <dt class="col-5 text-muted">{{ __('Wallet') }}</dt>
                            <dd class="col-7 fw-semibold">{{ data_get($network, 'wallet.currency', data_get($network, 'wallet_id', __('Not available'))) }}</dd>


                              <dt class="col-5 text-muted">{{ __('Support contacts') }}</dt>
                            <dd class="col-7">
                                <div class="d-flex flex-wrap gap-1">
                                    @forelse($contactsCollection as $contact)
                                        <span class="badge bg-light border text-muted">{{ $contact }}</span>
                                    @empty
                                        <span class="text-muted">{{ __('Not available') }}</span>
                                    @endforelse
                                </div>
                            </dd>

                            @php($notes = data_get($network, 'notes'))
                            <dt class="col-5 text-muted">{{ __('Notes') }}</dt>
                            <dd class="col-7">
                                @if($notes)
                                    {!! nl2br(e(\Illuminate\Support\Str::limit($notes, 160))) !!}
                                @else
                                    {{ __('Not available') }}
                                @endif
                            </dd>



                            <dt class="col-5 text-muted">{{ __('Last Sync') }}</dt>
                            <dd class="col-7 fw-semibold">{{ data_get($network, 'synced_at', __('Not available')) }}</dd>

                            <dt class="col-5 text-muted">{{ __('Gateway status') }}</dt>
                            <dd class="col-7 fw-semibold">{{ data_get($network, 'gateway.status', __('Unknown')) }}</dd>
                        </dl>
                    </div>
                    <div class="card-footer bg-transparent border-0 pt-0">
                        <button type="button" class="btn btn-outline-primary w-100">
                            <i class="bi bi-sliders"></i>
                            {{ __('Update Network Settings') }}
                        </button>
                    </div>
                </div>

                <div class="card shadow-sm mt-4">
                    <div class="card-header border-0 pb-0">
                        <h5 class="card-title mb-1">{{ __('Branding assets') }}</h5>
                        <p class="text-muted small mb-0">{{ __('Preview the uploaded logo and login screen imagery for this network.') }}</p>
                    </div>
                    <div class="card-body">
                        <div class="mb-4">
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <span class="fw-semibold small text-uppercase text-muted">{{ __('Logo') }}</span>
                                @if($logoUrl)
                                    <span class="badge bg-success-subtle text-success">{{ __('Uploaded') }}</span>
                                @else
                                    <span class="badge bg-secondary-subtle text-secondary">{{ __('Pending') }}</span>
                                @endif
                            </div>
                            @if($logoUrl)
                                <div class="border rounded-3 p-3 text-center bg-light-subtle">
                                    <img src="{{ $logoUrl }}" alt="{{ $networkName }} Logo" class="img-fluid" style="max-height: 180px; object-fit: contain;">
                                </div>
                            @else
                                <div class="border rounded-3 p-4 text-center text-muted small">
                                    <i class="bi bi-image display-6 d-block mb-2"></i>
                                    {{ __('No logo uploaded yet.') }}
                                </div>
                            @endif
                        </div>
                        <div>
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <span class="fw-semibold small text-uppercase text-muted">{{ __('Login screenshot') }}</span>
                                @if($loginScreenshotUrl)
                                    <span class="badge bg-success-subtle text-success">{{ __('Uploaded') }}</span>
                                @else
                                    <span class="badge bg-secondary-subtle text-secondary">{{ __('Pending') }}</span>
                                @endif
                            </div>
                            @if($loginScreenshotUrl)
                                <div class="border rounded-3 p-3 text-center bg-light-subtle">
                                    <img src="{{ $loginScreenshotUrl }}" alt="{{ $networkName }} Login Screenshot" class="img-fluid" style="max-height: 220px; object-fit: contain;">
                                </div>
                            @else
                                <div class="border rounded-3 p-4 text-center text-muted small">
                                    <i class="bi bi-phones display-6 d-block mb-2"></i>
                                    {{ __('No login screen provided yet.') }}
                                </div>
                            @endif
                        </div>
                    </div>
                </div>

            </div>

            <div class="col-12 col-xl-8">


                @if($networkId)
                    <div class="card shadow-sm mb-4">
                        <div class="card-header border-0 pb-0">
                            <h5 class="card-title mb-1">{{ __('Network settings & branding') }}</h5>
                            <p class="text-muted small mb-0">{{ __('Update the public slug, support contacts and upload branded assets.') }}</p>
                        </div>
                        <div class="card-body">
                            <form action="{{ route('wifi.networks.update', $networkId) }}" method="post" enctype="multipart/form-data" class="row g-3">
                                @csrf
                                @method('PUT')

                                <div class="col-12">
                                    <label for="wifi-slug" class="form-label">{{ __('Slug') }}</label>
                                    <input type="text" name="slug" id="wifi-slug" class="form-control" value="{{ old('slug', data_get($network, 'slug')) }}" maxlength="255" placeholder="cabin-01">
                                    <div class="form-text">{{ __('Slug is used for friendly URLs. Leave blank to auto-generate.') }}</div>
                                </div>


                                <div class="col-12">
                                    <label for="wifi-contacts" class="form-label">{{ __('Support contacts') }}</label>
                                    <textarea name="contacts" id="wifi-contacts" rows="3" class="form-control" placeholder="+9677xxxxxxx&#10;+9671xxxxxxx">{{ $contactsFieldValue }}</textarea>
                                    <div class="form-text">{{ __('Separate multiple phone numbers with commas or new lines.') }}</div>
                                </div>

                                <div class="col-12">
                                    <label for="wifi-notes" class="form-label">{{ __('Internal notes') }}</label>
                                    <textarea name="notes" id="wifi-notes" rows="4" class="form-control" placeholder="{{ __('Add any field instructions or site details...') }}">{{ old('notes', data_get($network, 'notes')) }}</textarea>
                                </div>

                                <div class="col-md-6">
                                    <label for="wifi-logo" class="form-label">{{ __('Network logo') }}</label>
                                    <input type="file" name="logo" id="wifi-logo" class="form-control" accept="image/*">
                                    <div class="form-text">{{ __('Upload a square logo in PNG, JPG or WEBP format (max 4 MB).') }}</div>
                                    @if($logoUrl)
                                        <div class="border rounded-3 mt-2 p-2 text-center bg-light-subtle">
                                            <img src="{{ $logoUrl }}" alt="{{ $networkName }} logo" class="img-fluid" style="max-height: 120px; object-fit: contain;">
                                        </div>
                                    @endif
                                </div>

                                <div class="col-md-6">
                                    <label for="wifi-login-screenshot" class="form-label">{{ __('Login screen screenshot') }}</label>
                                    <input type="file" name="login_screenshot" id="wifi-login-screenshot" class="form-control" accept="image/*">
                                    <div class="form-text">{{ __('Showcase the captive portal landing page (max 4 MB).') }}</div>
                                    @if($loginScreenshotUrl)
                                        <div class="border rounded-3 mt-2 p-2 text-center bg-light-subtle">
                                            <img src="{{ $loginScreenshotUrl }}" alt="{{ $networkName }} login screen" class="img-fluid" style="max-height: 160px; object-fit: contain;">
                                        </div>
                                    @endif
                                </div>

                                <div class="col-12">
                                    <div class="alert alert-light border d-flex align-items-center" role="alert">
                                        <i class="bi bi-wallet2 me-2"></i>
                                        <div>
                                            <strong>{{ __('Wallet link') }}:</strong>
                                            {{ data_get($network, 'wallet.currency', data_get($network, 'wallet_id', __('Not linked yet'))) }}
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 text-end">
                                    <button type="submit" class="btn btn-primary">
                                        <i class="bi bi-save"></i>
                                        {{ __('Save network settings') }}
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                @endif

                <div class="card shadow-sm mb-4">
                    <div class="card-header border-0 pb-0">
                        <h5 class="card-title mb-1">{{ __('Plans assigned to this cabin') }}</h5>
                        <p class="text-muted small mb-0">{{ __('Enable, disable or monitor sales performance of the included plans.') }}</p>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-hover align-middle">
                                <thead>
                                <tr>
                                    <th>{{ __('Plan Name') }}</th>
                                    <th class="text-center">{{ __('Price') }}</th>
                                    <th class="text-center">{{ __('Available') }}</th>
                                    <th class="text-center">{{ __('Sold') }}</th>
                                    <th class="text-center">{{ __('Total Codes') }}</th>
                                    <th class="text-center">{{ __('Owner Net') }}</th>
                                    <th class="text-center">{{ __('Gross Sales') }}</th>


                                    <th class="text-end">{{ __('Status') }}</th>
                                </tr>
                                </thead>
                                <tbody>
                                @forelse($plans as $plan)
                                    @php
                                        $active = (bool) data_get($plan, 'active', true);
                                        $currency = data_get($plan, 'currency');
                                        $rawPrice = data_get($plan, 'price');
                                        $priceLabel = $rawPrice;

                                        if ($currency && $rawPrice !== null) {
                                            $priceLabel = trim($rawPrice . ' ' . $currency);
                                        }

                                        $allowanceLabel = data_get($plan, 'data_allowance_label', data_get($plan, 'allowance', '—'));
                                        $validityLabel = data_get($plan, 'validity_label', data_get($plan, 'validity', '—'));
                                        $speedLabel = data_get($plan, 'speed_label', '—');

                                        $availableCount = (int) data_get($plan, 'available_count', data_get($plan, 'stock.available', 0));
                                        $reservedCount = (int) data_get($plan, 'stock.reserved', 0);
                                        $issuedCount = (int) data_get($plan, 'stock.issued', 0);
                                        $soldCount = (int) data_get($plan, 'sold_count', $reservedCount + $issuedCount);
                                        $totalCodes = (int) data_get($plan, 'total_codes', $availableCount + $soldCount);

                                        $ownerNetAmount = (float) data_get($plan, 'owner_net_amount', 0);
                                        $grossRevenueAmount = (float) data_get($plan, 'gross_revenue_amount', 0);

                                        $ownerNetLabel = number_format($ownerNetAmount, 2);
                                        $grossRevenueLabel = number_format($grossRevenueAmount, 2);

                                        if ($currency) {
                                            $ownerNetLabel = trim($ownerNetLabel . ' ' . $currency);
                                            $grossRevenueLabel = trim($grossRevenueLabel . ' ' . $currency);
                                        }

                                    @endphp
                                    <tr>
                                        <td>
                                            <div class="fw-semibold">{{ data_get($plan, 'name', __('Unnamed Plan')) }}</div>
                                            <div class="text-muted small">{{ data_get($plan, 'description', __('No description provided.')) }}</div>
                                        </td>

                                        <td class="text-center">{{ $priceLabel ?? '—' }}</td>
                                        <td class="text-center"><span class="badge bg-light text-body-secondary">{{ number_format($availableCount) }}</span></td>
                                        <td class="text-center"><span class="badge bg-warning-subtle text-warning fw-semibold">{{ number_format($soldCount) }}</span></td>
                                        <td class="text-center"><span class="badge bg-secondary-subtle text-secondary">{{ number_format($totalCodes) }}</span></td>
                                        <td class="text-center"><span class="badge bg-success-subtle text-success">{{ $ownerNetLabel }}</span></td>
                                        <td class="text-center"><span class="badge bg-info-subtle text-info">{{ $grossRevenueLabel }}</span></td>

                                        <td class="text-end">
                                            <span class="badge {{ $active ? 'bg-success' : 'bg-secondary' }}">{{ $active ? __('Active') : __('Disabled') }}</span>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="8" class="text-center text-muted py-4">
                                            <i class="bi bi-card-text display-6 d-block mb-2"></i>
                                            <span>{{ __('No plans configured yet.') }}</span>
                                        </td>
                                    </tr>
                                @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>

                <div class="row g-4">
                    <div class="col-12 col-lg-6">
                        <div class="card shadow-sm h-100">
                            <div class="card-header border-0 pb-0">
                                <h5 class="card-title mb-1">{{ __('Stock Overview') }}</h5>
                                <p class="text-muted small mb-0">{{ __('Distribution of vouchers and balances for the cabin.') }}</p>
                            </div>
                            <div class="card-body">
                                <div class="row g-2 small text-muted">
                                    <div class="col-6">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Available Balance') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($stock, 'available', '—') }}</div>
                                        </div>
                                    </div>
                                    <div class="col-6">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Reserved Balance') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($stock, 'reserved', '—') }}</div>
                                        </div>
                                    </div>
                                    <div class="col-6">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Total Issued') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($stock, 'issued', '—') }}</div>
                                        </div>
                                    </div>
                                    <div class="col-6">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Remaining Vouchers') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($stock, 'remaining', '—') }}</div>
                                        </div>
                                    </div>
                                    <div class="col-12">
                                        <div class="p-2 border rounded-3 h-100">
                                            <div class="text-uppercase fw-semibold small">{{ __('Last Sync') }}</div>
                                            <div class="fs-6 fw-semibold text-dark">{{ data_get($stock, 'synced_at', __('Not available')) }}</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-12 col-lg-6">
                        <div class="card shadow-sm h-100">
                            <div class="card-header border-0 pb-0">
                                <h5 class="card-title mb-1">{{ __('Alerts') }}</h5>
                                <p class="text-muted small mb-0">{{ __('Focused alerts related to this cabin and its operations.') }}</p>
                            </div>
                            <div class="card-body">
                                @forelse($alerts as $alert)
                                    @php
                                        $severity = strtolower((string) data_get($alert, 'severity', 'info'));
                                        $badgeClass = match ($severity) {
                                            'critical', 'error' => 'bg-danger',
                                            'warning' => 'bg-warning text-dark',
                                            'success' => 'bg-success',
                                            default => 'bg-info',
                                        };
                                    @endphp
                                    <div class="alert alert-light border shadow-sm mb-3" role="alert">
                                        <div class="d-flex justify-content-between align-items-start mb-1">
                                            <h6 class="mb-0">{{ data_get($alert, 'title', __('Service Alert')) }}</h6>
                                            <span class="badge {{ $badgeClass }} text-uppercase">{{ \Illuminate\Support\Str::upper($severity) }}</span>
                                        </div>
                                        <p class="mb-2 text-muted">{{ data_get($alert, 'message', __('No additional details provided.')) }}</p>
                                        <div class="d-flex justify-content-between small text-muted">
                                            <span><i class="bi bi-clock"></i> {{ data_get($alert, 'reported_at', __('Not available')) }}</span>
                                            <span><i class="bi bi-shield-exclamation"></i> {{ data_get($alert, 'category', __('General')) }}</span>
                                        </div>
                                    </div>
                                @empty
                                    <div class="text-center text-muted py-4">
                                        <i class="bi bi-bell-slash display-6 d-block mb-2"></i>
                                        <span>{{ __('No alerts for now.') }}</span>
                                    </div>
                                @endforelse
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection