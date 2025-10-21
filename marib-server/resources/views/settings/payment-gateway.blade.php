@extends('layouts.main')

@section('title')
    {{ __('Manual Bank Settings') }}

@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first"></div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
                @php
                $eastYemenLastUpdated = $eastYemenGateway->updated_at?->timezone(config('app.timezone', 'UTC'));
                $eastYemenLastUpdatedDisplay = $eastYemenLastUpdated ? $eastYemenLastUpdated->format('M j, Y H:i') : __('Never');
            @endphp

            <div class="col-12 mb-4">
                <div class="card">
                    <div class="card-body">
                        <div class="divider pt-3">
                            <h6 class="divider-text">{{ __('East Yemen Bank') }}</h6>
                        </div>
                        <form
                            id="east_yemen_gateway_form"
                            action="{{ route('settings.payment-gateway.east-yemen-bank') }}"
                            method="post"
                            class="create-form-without-reset"
                            data-success-function="handleEastYemenGatewaySuccess"
                            enctype="multipart/form-data"

                        >
                        
                        
                        @csrf
                            <div class="row g-3 align-items-end">

                                <div class="col-md-4">
                                    <label class="form-label d-block" for="east_yemen_bank_status_toggle">{{ __('Status') }}</label>


                                    <div class="form-check form-switch">
                                        <input type="hidden" name="status" value="{{ $eastYemenGateway->status ? 1 : 0 }}">
                                        <input
                                            class="form-check-input switch-input status-switch"
                                            type="checkbox"
                                            role="switch"
                                            id="east_yemen_bank_status_toggle"
                                            {{ $eastYemenGateway->status ? 'checked' : '' }}
                                        >

                                    </div>
                                </div>

                                <div class="col-md-4">
                                    <label for="east_yemen_display_name" class="form-label">{{ __('Display Name') }}</label>
                                    <input
                                        id="east_yemen_display_name"
                                        type="text"
                                        name="display_name"
                                        value="{{ old('display_name', $eastYemenGateway->display_name) }}"
                                        class="form-control"
                                        placeholder="{{ __('Enter display name') }}"
                                    >
                                </div>
                                <div class="col-md-4">
                                    <label for="east_yemen_logo" class="form-label">{{ __('Gateway Icon') }}</label>
                                    <input
                                        id="east_yemen_logo"
                                        type="file"
                                        name="logo"
                                        class="form-control"
                                        accept="image/*"
                                    >
                                </div>

                                <div class="col-md-4">
                                    <label for="east_yemen_app_key" class="form-label">{{ __('X-APP-KEY') }}</label>
                                    <input
                                        id="east_yemen_app_key"
                                        type="text"
                                        name="app_key"
                                        value="{{ old('app_key', $eastYemenGateway->secret_key) }}"
                                        class="form-control"
                                        placeholder="{{ __('Enter X-APP-KEY') }}"
                                        data-required-toggle="east-yemen-bank"
                                    >


                                </div>
                                <div class="col-md-4">
                                    <label for="east_yemen_api_key" class="form-label">{{ __('X-API-KEY') }}</label>
                                    <input
                                        id="east_yemen_api_key"
                                        type="text"
                                        name="api_key"
                                        value="{{ old('api_key', $eastYemenGateway->api_key) }}"
                                        class="form-control"
                                        placeholder="{{ __('Enter X-API-KEY') }}"
                                        data-required-toggle="east-yemen-bank"
                                    >
                                </div>



                                <div class="col-12">
                                    <label for="east_yemen_note" class="form-label">{{ __('Internal Note') }}</label>
                                    <textarea
                                        id="east_yemen_note"
                                        name="note"
                                        class="form-control"
                                        rows="3"
                                        placeholder="{{ __('Add private details about this gateway for staff reference') }}"
                                    >{{ old('note', $eastYemenGateway->note) }}</textarea>
                                </div>



                                <div class="col-12">
                                    <div
                                        id="east_yemen_gateway_summary"
                                        class="bg-light border rounded px-3 py-2 small text-muted mt-2"
                                        data-app-key="{{ $eastYemenGateway->secret_key ?? '' }}"
                                        data-api-key="{{ $eastYemenGateway->api_key ?? '' }}"

                                        data-display-name="{{ e($eastYemenGateway->display_name ?? '') }}"
                                        data-note="{{ e($eastYemenGateway->note ?? '') }}"
                                        data-logo-url="{{ e($eastYemenGateway->logo_url ?? '') }}"
                                        data-status="{{ $eastYemenGateway->status ? '1' : '0' }}"
                                        data-updated-at="{{ $eastYemenLastUpdated?->toIso8601String() ?? '' }}"
                                    >
                                        <div class="fw-semibold text-body-secondary mb-1">{{ __('Gateway record summary') }}</div>
                                        <div>{{ __('Status') }}: <span id="east_yemen_status_text">{{ $eastYemenGateway->status ? __('Enabled') : __('Disabled') }}</span></div>

                                        <div>{{ __('Display Name') }}: <span id="east_yemen_display_name_text">{{ $eastYemenGateway->display_name ?: __('Not set') }}</span></div>
                                        <div class="text-break">{{ __('Stored X-APP-KEY') }}: <span id="east_yemen_app_key_text">{{ $eastYemenGateway->secret_key ?: __('Not set') }}</span></div>
                                        <div class="text-break">{{ __('Stored X-API-KEY') }}: <span id="east_yemen_api_key_text">{{ $eastYemenGateway->api_key ?: __('Not set') }}</span></div>



                                        <div>{{ __('Internal Note') }}:
                                            <span id="east_yemen_note_text">
                                                @if($eastYemenGateway->note)
                                                    {!! nl2br(e($eastYemenGateway->note)) !!}
                                                @else
                                                    {{ __('Not set') }}
                                                @endif
                                            </span>
                                        </div>
                                        <div class="d-flex align-items-center gap-2 mt-2">
                                            <span>{{ __('Gateway Icon') }}:</span>
                                            @php($eastYemenLogoUrl = $eastYemenGateway->logo_url)
                                            <div class="d-flex align-items-center" id="east_yemen_logo_wrapper">
                                                @if($eastYemenLogoUrl)
                                                    <img
                                                        id="east_yemen_logo_preview"
                                                        src="{{ $eastYemenLogoUrl }}"
                                                        alt="{{ $eastYemenGateway->display_name ?? __('East Yemen Bank') }}"
                                                        class="rounded border"
                                                        style="width: 48px; height: 48px; object-fit: contain;"
                                                    >
                                                @else
                                                    <div
                                                        id="east_yemen_logo_placeholder"
                                                        class="bg-white border rounded d-flex align-items-center justify-content-center"
                                                        style="width: 48px; height: 48px;"
                                                    >
                                                        <i class="bi bi-image text-muted"></i>
                                                    </div>
                                                @endif
                                            </div>
                                        </div>


                                        <div>{{ __('Last updated') }}: <span id="east_yemen_last_updated_text">{{ $eastYemenLastUpdatedDisplay }}</span></div>
                                    </div>
                                </div>
                            </div>
                            <div class="d-flex justify-content-end mt-4">
                                <button type="submit" class="btn btn-primary">{{ __('Save Gateway Settings') }}</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>

            
            <div class="col-lg-4">
                <div class="card">
                    <div class="card-body">
                        <div class="divider pt-3">
                            <h6 class="divider-text">{{ __('Add Manual Bank') }}</h6>
                        </div>
                        <form class="create-form-without-reset" action="{{ route('settings.payment-gateway.store') }}" method="post" enctype="multipart/form-data">
                            @csrf
                            <div class="form-group mb-3">
                                <label for="manual_bank_name" class="form-label">{{ __('Bank Name') }}</label>
                                <input id="manual_bank_name" name="name" type="text" class="form-control" placeholder="{{ __('Enter bank name') }}" required>
                            </div>

                            <div class="form-group mb-3">
                                <label for="manual_bank_beneficiary" class="form-label">{{ __('Beneficiary Name') }}</label>
                                <input id="manual_bank_beneficiary" name="beneficiary_name" type="text" class="form-control" placeholder="{{ __('Enter beneficiary name') }}">


                            </div>
                            <div class="form-group mb-3">
                                <label for="manual_bank_note" class="form-label">{{ __('Note / Instructions') }}</label>
                                <textarea id="manual_bank_note" name="note" class="form-control" rows="4" placeholder="{{ __('Payment instructions or additional notes') }}"></textarea>
                            </div>

                            <div class="form-group mb-3">
                                <label for="manual_bank_display_order" class="form-label">{{ __('Display Order') }}</label>
                                <input id="manual_bank_display_order" name="display_order" type="number" class="form-control" min="0" value="0">
                            </div>
                            <div class="form-group mb-3">
                                <label class="form-label">{{ __('Status') }}</label>
                                <div class="form-check form-switch">
                                    <input type="hidden" name="status" value="1">
                                    <input class="form-check-input switch-input status-switch" type="checkbox" role="switch" checked>
                                </div>

                            </div>
                            <div class="form-group mb-4">
                                <label for="manual_bank_logo" class="form-label">{{ __('Bank Logo') }}</label>
                                <input id="manual_bank_logo" name="logo" type="file" class="form-control" accept="image/*">
                            </div>
                            <div class="d-flex justify-content-end">
                                <button type="submit" class="btn btn-primary">{{ __('Save Bank') }}</button>

                            </div>
                        </form>
                    </div>
                </div>
            </div>
            <div class="col-lg-8">
                <div class="card">
                    <div class="card-body">
                        <div class="divider pt-3">
                            <h6 class="divider-text">{{ __('Bank Transfer') }}</h6>
                        </div>
                        @forelse($manualBanks as $manualBank)
                            <div class="border rounded p-3 mb-4">
                                <div class="d-flex justify-content-between align-items-start flex-wrap gap-2 mb-3">
                                    <div class="d-flex align-items-center gap-3">
                                        @if($manualBank->logo_url)
                                            <img src="{{ $manualBank->logo_url }}" alt="{{ $manualBank->name }}" class="rounded" style="width: 56px; height: 56px; object-fit: contain;">
                                        @else
                                            <div class="bg-light border rounded d-flex align-items-center justify-content-center" style="width: 56px; height: 56px;">
                                                <i class="bi bi-bank fs-4 text-muted"></i>
                                            </div>
                                        @endif
                                        <div>
                                            <h6 class="mb-1">{{ $manualBank->name }}</h6>
                                            <small class="text-muted">{{ __('Display Order') }}: {{ $manualBank->display_order }}</small>
                                        </div>
                                    <form action="{{ route('settings.manual-banks.destroy', $manualBank) }}" method="post" onsubmit="return confirm('{{ __('Are you sure you want to delete this bank?') }}');">
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="btn btn-outline-danger btn-sm">{{ __('Delete') }}</button>
                                    </form>
                                </div>
                                <form class="create-form-without-reset" action="{{ route('settings.manual-banks.update', $manualBank) }}" method="post" enctype="multipart/form-data">
                                    @csrf
                                    @method('PUT')
                                    <div class="row">
                                        <div class="col-md-6 mb-3">
                                            <label class="form-label" for="manual_bank_name_{{ $manualBank->id }}">{{ __('Bank Name') }}</label>
                                            <input id="manual_bank_name_{{ $manualBank->id }}" type="text" name="name" class="form-control" value="{{ $manualBank->name }}" required>
                                        </div>
                                        <div class="col-md-6 mb-3">
                                            <label class="form-label" for="manual_bank_beneficiary_{{ $manualBank->id }}">{{ __('Beneficiary Name') }}</label>
                                            <input id="manual_bank_beneficiary_{{ $manualBank->id }}" type="text" name="beneficiary_name" class="form-control" value="{{ $manualBank->beneficiary_name }}">
                                        </div>
                                        <div class="col-12 mb-3">
                                            <label class="form-label" for="manual_bank_note_{{ $manualBank->id }}">{{ __('Note / Instructions') }}</label>
                                            <textarea id="manual_bank_note_{{ $manualBank->id }}" name="note" class="form-control" rows="3">{{ $manualBank->note }}</textarea>
                                        </div>
                                        <div class="col-md-4 mb-3">
                                            <label class="form-label" for="manual_bank_display_order_{{ $manualBank->id }}">{{ __('Display Order') }}</label>
                                            <input id="manual_bank_display_order_{{ $manualBank->id }}" type="number" name="display_order" class="form-control" min="0" value="{{ $manualBank->display_order }}">
                                        </div>
                                        <div class="col-md-4 mb-3">
                                            <label class="form-label d-block">{{ __('Status') }}</label>
                                            <div class="form-check form-switch">
                                                <input type="hidden" name="status" value="{{ $manualBank->status ? 1 : 0 }}">
                                                <input class="form-check-input switch-input status-switch" type="checkbox" role="switch" {{ $manualBank->status ? 'checked' : '' }}>
                                            </div>
                                        </div>
                                        <div class="col-md-4 mb-3">
                                            <label class="form-label" for="manual_bank_logo_{{ $manualBank->id }}">{{ __('Bank Logo') }}</label>
                                            <input id="manual_bank_logo_{{ $manualBank->id }}" type="file" name="logo" class="form-control" accept="image/*">
                                        </div>
                                    </div>
                                    <div class="d-flex justify-content-end">
                                        <button type="submit" class="btn btn-primary">{{ __('Update Bank') }}</button>
                                    </div>
                                </form>

                                </div>
                        @empty
                            <div class="alert alert-light border text-center mb-0" role="alert">
                                {{ __('No manual banks have been added yet.') }}
                            </div>
                        @endforelse


                            </div>
                        </div>



                    </div>
                </div>

            </div>

    </section>
@endsection



@section('script')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            var statusToggle = document.getElementById('east_yemen_bank_status_toggle');
            if (!statusToggle) {
                return;
            }

            var requiredFields = document.querySelectorAll('[data-required-toggle="east-yemen-bank"]');

            var updateRequiredState = function () {
                var enabled = statusToggle.checked;

                requiredFields.forEach(function (field) {
                    if (enabled) {
                        field.setAttribute('required', 'required');
                        field.setAttribute('aria-required', 'true');
                        field.setAttribute('data-parsley-required', 'true');
                    } else {
                        field.removeAttribute('required');
                        field.removeAttribute('aria-required');
                        field.removeAttribute('data-parsley-required');

                        if (window.Parsley && typeof window.Parsley.get === 'function') {
                            var parsleyField = window.Parsley.get(field);
                            if (parsleyField) {
                                parsleyField.reset();
                            }
                        }
                    }
                });
            };

            updateRequiredState();
            statusToggle.addEventListener('change', updateRequiredState);
        });

        function handleEastYemenGatewaySuccess(response) {
            var form = document.getElementById('east_yemen_gateway_form');
            var summary = document.getElementById('east_yemen_gateway_summary');

            if (!form || !summary) {
                return;
            }

            var statusToggle = document.getElementById('east_yemen_bank_status_toggle');

            var appKeyField = form.querySelector('[name="app_key"]');
            var apiKeyField = form.querySelector('[name="api_key"]');

            var displayNameField = form.querySelector('[name="display_name"]');
            var noteField = form.querySelector('[name="note"]');

            var gatewayData = response && response.gateway ? response.gateway : null;

            





            var trimmedAppKey = appKeyField && typeof appKeyField.value === 'string' ? appKeyField.value.trim() : '';
            var trimmedApiKey = apiKeyField && typeof apiKeyField.value === 'string' ? apiKeyField.value.trim() : '';


            var trimmedDisplayName = displayNameField && typeof displayNameField.value === 'string' ? displayNameField.value.trim() : '';
            var noteValue = noteField && typeof noteField.value === 'string' ? noteField.value : '';
            var noteValueTrimmed = noteValue.trim();




            var previousAppKey = summary.dataset.appKey || '';
            var previousApiKey = summary.dataset.apiKey || '';


            var previousDisplayName = summary.dataset.displayName || '';
            var previousNote = summary.dataset.note || '';
            var previousLogoUrl = summary.dataset.logoUrl || '';
            var previousStatus = summary.dataset.status === '1';

            var storedAppKey = gatewayData && typeof gatewayData.app_key === 'string'
                ? gatewayData.app_key
                : (trimmedAppKey !== '' ? trimmedAppKey : previousAppKey);


            var storedApiKey = gatewayData && typeof gatewayData.api_key === 'string'
                ? gatewayData.api_key
                : (trimmedApiKey !== '' ? trimmedApiKey : previousApiKey);

            var storedDisplayName = gatewayData && typeof gatewayData.display_name === 'string'
                ? gatewayData.display_name
                : (trimmedDisplayName !== '' ? trimmedDisplayName : previousDisplayName);

            var storedNote = gatewayData && typeof gatewayData.note === 'string'
                ? gatewayData.note
                : (noteValueTrimmed !== '' || (noteField && noteField.value === '') ? noteValue : previousNote);

            var storedLogoUrl = gatewayData && typeof gatewayData.logo_url === 'string'
                ? gatewayData.logo_url
                : previousLogoUrl;

            var storedStatus = gatewayData && typeof gatewayData.status !== 'undefined'
                ? Boolean(gatewayData.status)
                : (statusToggle ? statusToggle.checked : previousStatus);

            if (statusToggle) {
                statusToggle.checked = storedStatus;
            }

            summary.dataset.appKey = storedAppKey;
            summary.dataset.apiKey = storedApiKey;
            summary.dataset.displayName = storedDisplayName;
            summary.dataset.note = storedNote;
            summary.dataset.logoUrl = storedLogoUrl;
            summary.dataset.status = storedStatus ? '1' : '0';

            var updatedIso = gatewayData && gatewayData.updated_at ? gatewayData.updated_at : null;
            var updatedDate = updatedIso ? new Date(updatedIso) : new Date();
            if (Number.isNaN(updatedDate.getTime())) {
                updatedDate = new Date();
            }
            summary.dataset.updatedAt = updatedDate.toISOString();




            var statusTextElement = document.getElementById('east_yemen_status_text');
            if (statusTextElement) {
                statusTextElement.textContent = storedStatus ? '{{ __('Enabled') }}' : '{{ __('Disabled') }}';
            }

            var notSetText = '{{ __('Not set') }}';

            var appKeyTextElement = document.getElementById('east_yemen_app_key_text');
            if (appKeyTextElement) {
                appKeyTextElement.textContent = storedAppKey !== '' ? storedAppKey : notSetText;
            }

            var apiKeyTextElement = document.getElementById('east_yemen_api_key_text');
            if (apiKeyTextElement) {
                apiKeyTextElement.textContent = storedApiKey !== '' ? storedApiKey : notSetText;
            }



            var displayNameTextElement = document.getElementById('east_yemen_display_name_text');
            if (displayNameTextElement) {
                displayNameTextElement.textContent = storedDisplayName !== '' ? storedDisplayName : notSetText;
            }

            var noteTextElement = document.getElementById('east_yemen_note_text');
            if (noteTextElement) {
                if (storedNote !== '') {
                    noteTextElement.innerHTML = storedNote.replace(/\n/g, '<br>');
                } else {
                    noteTextElement.textContent = notSetText;
                }
            }

            var logoWrapper = document.getElementById('east_yemen_logo_wrapper');
            if (logoWrapper) {
                var logoPreview = document.getElementById('east_yemen_logo_preview');
                var logoPlaceholder = document.getElementById('east_yemen_logo_placeholder');

                if (storedLogoUrl) {
                    if (!logoPreview) {
                        logoPreview = document.createElement('img');
                        logoPreview.id = 'east_yemen_logo_preview';
                        logoPreview.className = 'rounded border';
                        logoPreview.style.width = '48px';
                        logoPreview.style.height = '48px';
                        logoPreview.style.objectFit = 'contain';
                        logoWrapper.innerHTML = '';
                        logoWrapper.appendChild(logoPreview);
                    } else if (logoPlaceholder) {
                        logoPlaceholder.remove();
                    }

                    logoPreview.src = storedLogoUrl;
                    logoPreview.alt = storedDisplayName !== '' ? storedDisplayName : '{{ __('East Yemen Bank') }}';
                } else {
                    if (!logoPlaceholder) {
                        logoPlaceholder = document.createElement('div');
                        logoPlaceholder.id = 'east_yemen_logo_placeholder';
                        logoPlaceholder.className = 'bg-white border rounded d-flex align-items-center justify-content-center';
                        logoPlaceholder.style.width = '48px';
                        logoPlaceholder.style.height = '48px';
                        logoPlaceholder.innerHTML = '<i class="bi bi-image text-muted"></i>';
                        logoWrapper.innerHTML = '';
                        logoWrapper.appendChild(logoPlaceholder);
                    }

                    if (logoPreview) {
                        logoPreview.remove();
                    }
                }
            }








            var updatedElement = document.getElementById('east_yemen_last_updated_text');
            if (updatedElement) {
                try {
                    var formatted = new Intl.DateTimeFormat(undefined, {
                        year: 'numeric',
                        month: 'short',
                        day: '2-digit',
                        hour: '2-digit',
                        minute: '2-digit'
                    }).format(updatedDate);

                    updatedElement.textContent = formatted;
                } catch (error) {
                    updatedElement.textContent = now.toLocaleString();
                }
            }
        }
    </script>
@endsection




