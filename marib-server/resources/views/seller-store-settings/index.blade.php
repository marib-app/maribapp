@extends('layouts.main')

@section('title')
    {{ __('Store Settings') }}
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
        <div class="card">
            <div class="card-body">
                <ul class="nav nav-tabs" id="sellerStoreSettingsTabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button
                            class="nav-link active"
                            id="seller-store-terms-tab"
                            data-bs-toggle="tab"
                            data-bs-target="#seller-store-terms"
                            type="button"
                            role="tab"
                            aria-controls="seller-store-terms"
                            aria-selected="true"
                        >
                            {{ __('Store Terms & Conditions') }}
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button
                            class="nav-link"
                            id="seller-store-gateways-tab"
                            data-bs-toggle="tab"
                            data-bs-target="#seller-store-gateways"
                            type="button"
                            role="tab"
                            aria-controls="seller-store-gateways"
                            aria-selected="false"
                        >
                            {{ __('Store Payment Gateways') }}
                        </button>
                    </li>
                </ul>

                <div class="tab-content mt-4" id="sellerStoreSettingsTabsContent">
                    <div
                        class="tab-pane fade show active"
                        id="seller-store-terms"
                        role="tabpanel"
                        aria-labelledby="seller-store-terms-tab"
                    >
                        <form
                            class="create-form-without-reset"
                            action="{{ route('seller-store-settings.terms.store') }}"
                            method="post"
                        >
                            @csrf

                            <div class="mb-3">
                                <label class="form-label" for="store_terms_editor">
                                    {{ __('Store Terms & Conditions') }}
                                </label>
                                <textarea
                                    id="store_terms_editor"
                                    name="store_terms_conditions"
                                    class="form-control"
                                    rows="12"
                                >{{ old('store_terms_conditions', $storeTerms) }}</textarea>
                            </div>

                            <div class="d-flex justify-content-end">
                                <button type="submit" class="btn btn-primary">
                                    {{ __('Save Terms') }}
                                </button>
                            </div>
                        </form>
                    </div>

                    <div
                        class="tab-pane fade"
                        id="seller-store-gateways"
                        role="tabpanel"
                        aria-labelledby="seller-store-gateways-tab"
                    >
                        <div class="row g-3">
                            <div class="col-12">
                                <div class="alert alert-info" role="alert">
                                    {{ __('Overview of the store payment gateways configured for sellers.') }}
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="table-responsive">
                                    <table class="table table-striped align-middle mb-0">
                                        <thead>
                                            <tr>
                                                <th>{{ __('Gateway') }}</th>
                                                <th>{{ __('Status') }}</th>
                                                <th>{{ __('Updated At') }}</th>
                                                <th>{{ __('Notes') }}</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            @forelse ($storePaymentGateways as $gateway)
                                                @php
                                                    $updatedAt = $gateway->updated_at;
                                                    $lastUpdated = $updatedAt
                                                        ? $updatedAt->timezone(config('app.timezone', 'UTC'))->format('M j, Y H:i')
                                                        : __('Never');
                                                @endphp
                                                <tr>
                                                    <td>
                                                        <div class="d-flex align-items-center gap-2">
                                                            @if($gateway->logo_url)
                                                                <img
                                                                    src="{{ $gateway->logo_url }}"
                                                                    alt="{{ $gateway->display_name ?? $gateway->payment_method }}"
                                                                    class="rounded border"
                                                                    style="width: 40px; height: 40px; object-fit: contain;"
                                                                >
                                                            @else
                                                                <span class="badge bg-light text-body-secondary border">
                                                                    {{ strtoupper(\Illuminate\Support\Str::limit($gateway->payment_method, 3, '')) }}
                                                                </span>
                                                            @endif
                                                            <div>
                                                                <div class="fw-semibold">{{ $gateway->display_name ?: __('Unnamed Gateway') }}</div>
                                                                <div class="small text-muted text-break">{{ $gateway->payment_method }}</div>
                                                            </div>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        @if($gateway->status)
                                                            <span class="badge bg-success">{{ __('Enabled') }}</span>
                                                        @else
                                                            <span class="badge bg-secondary">{{ __('Disabled') }}</span>
                                                        @endif
                                                    </td>
                                                    <td class="text-nowrap">{{ $lastUpdated }}</td>
                                                    <td class="text-break">
                                                        @if($gateway->note)
                                                            {!! nl2br(e($gateway->note)) !!}
                                                        @else
                                                            <span class="text-muted">{{ __('No notes added') }}</span>
                                                        @endif
                                                    </td>
                                                </tr>
                                            @empty
                                                <tr>
                                                    <td colspan="4" class="text-center text-muted py-4">
                                                        {{ __('No payment gateways configured yet.') }}
                                                    </td>
                                                </tr>
                                            @endforelse
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection

@push('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            if (typeof tinymce !== 'undefined') {
                tinymce.init({
                    selector: '#store_terms_editor',
                    height: 350,
                    menubar: false,
                    directionality: document.documentElement.getAttribute('dir') || 'ltr',
                    plugins: ['advlist autolink lists link charmap preview anchor', 'searchreplace visualblocks code fullscreen', 'insertdatetime media table paste code help wordcount'],
                    toolbar: 'undo redo | formatselect | bold italic backcolor | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | removeformat | help'
                });
            }
        });
    </script>
@endpush