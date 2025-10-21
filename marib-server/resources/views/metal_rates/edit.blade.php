@extends('layouts.main')

@php
    use Illuminate\Support\Facades\Storage;
@endphp

@section('title')
    {{ __('Edit metal rate') }}
@endsection

@can('governorate-create')
    @isset($governorateStoreUrl)
        @include('governorates.partials.quick-create-modal', ['storeUrl' => $governorateStoreUrl])
    @endisset
@endcan

@push('scripts')
    @include('metal_rates.partials.icon_preview_scripts')
    @include('metal_rates.partials.quote_table_scripts')
@endpush

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-start text-md-end">
                <a href="{{ route('metal-rates.index') }}" class="btn btn-outline-secondary">{{ __('Back to metal rates') }}</a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-12">
                @if ($errors->any())
                    <div class="alert alert-danger">
                        <ul class="mb-0">
                            @foreach ($errors->all() as $error)
                                <li>{{ $error }}</li>
                            @endforeach
                        </ul>
                    </div>
                @endif

                @if (session('success'))
                    <div class="alert alert-success alert-dismissible fade show" role="alert">
                        {{ session('success') }}
                        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                    </div>
                @endif
            </div>
        </div>

        <div class="row g-4">
            <div class="col-12 col-xl-7">
                <div class="card">
                    <div class="card-header">
                        <h5 class="card-title mb-0">{{ __('Update rate details') }}</h5>
                    </div>
                    <div class="card-body">
                        @can('metal-rate-edit')
                            <form action="{{ route('metal-rates.update', $metalRate) }}" method="POST" class="needs-validation" novalidate enctype="multipart/form-data">
                                @csrf
                                @method('PUT')

                                <input type="hidden" name="metal_type" value="{{ $metalRate->metal_type }}">

                                <div class="mb-3">
                                    <label class="form-label">{{ __('Metal type') }}</label>
                                    <input type="text" class="form-control" value="{{ $metalRate->display_name }}" disabled>
                                    <div class="form-text">{{ __('Metal type cannot be changed after creation.') }}</div>
                                </div>

                                <div class="mb-3">
                                    <label for="edit_karat" class="form-label">{{ __('Karat (for gold only)') }}</label>
                                    <input type="number" step="0.01" min="0" max="999" class="form-control" id="edit_karat" name="karat" value="{{ $metalRate->karat }}" @if($metalRate->metal_type === 'silver') disabled @endif>
                                    @if($metalRate->metal_type === 'silver')
                                        <input type="hidden" name="karat" value="">
                                    @endif
                                    <div class="form-text">{{ __('Leave empty for silver metals.') }}</div>
                                </div>

                                <div class="mb-4">
                                    <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-2">
                                        <label class="form-label mb-0">{{ __('Governorate quotes') }}</label>
                                        <div class="d-flex align-items-center gap-2">
                                            <span class="badge bg-light text-dark">{{ __('Inline editable') }}</span>
                                            @can('governorate-create')
                                                <button type="button" class="btn btn-sm btn-outline-primary"
                                                        data-bs-toggle="modal"
                                                        data-bs-target="#governorateQuickCreateModal">
                                                    {{ __('Add governorate') }}
                                                </button>
                                            @endcan
                                        </div>
                                    </div>

                                    @include('metal_rates.partials.quote-table', [
                                        'governorates' => $governorates,
                                        'quotes' => $quotes,
                                        'context' => 'edit-' . $metalRate->id,
                                        'defaultGovernorateId' => $defaultGovernorateId,
                                    ])
                                </div>

                                <div class="mb-3">
                                    <label for="metal_icon_{{ $metalRate->id }}" class="form-label">{{ __('Icon (optional)') }}</label>
                                    <input type="file" class="form-control" id="metal_icon_{{ $metalRate->id }}" name="icon" accept="image/png,image/jpeg,image/jpg,image/webp,image/svg+xml" data-metal-icon-input data-metal-icon-preview="metal_icon_preview_{{ $metalRate->id }}" data-metal-icon-wrapper="metal_icon_wrapper_{{ $metalRate->id }}" data-metal-rate-id="{{ $metalRate->id }}">
                                    <div class="form-text">{{ __('Uploading a new file replaces the previous icon.') }}</div>
                                    <div class="mt-2 {{ $metalRate->icon_path ? '' : 'd-none' }}" id="metal_icon_wrapper_{{ $metalRate->id }}" data-metal-icon-preview-container>
                                        <img src="{{ $metalRate->icon_path ? Storage::url($metalRate->icon_path) : '#' }}" alt="{{ $metalRate->icon_alt ?? __('Current icon') }}" id="metal_icon_preview_{{ $metalRate->id }}" class="img-thumbnail" style="max-height: 120px; {{ $metalRate->icon_path ? '' : 'display:none;' }}" data-original-src="{{ $metalRate->icon_path ? Storage::url($metalRate->icon_path) : '' }}" data-original-alt="{{ $metalRate->icon_alt ?? '' }}">
                                        <div class="mt-2 d-flex gap-2" data-metal-icon-actions>
                                            @if($metalRate->icon_path)
                                                <button type="submit" name="remove_icon" value="1" class="btn btn-outline-danger btn-sm" formnovalidate data-metal-icon-remove="{{ $metalRate->id }}">{{ __('Remove icon') }}</button>
                                            @endif
                                            <button type="button" class="btn btn-outline-secondary btn-sm" data-metal-icon-clear-input="metal_icon_{{ $metalRate->id }}">{{ __('Clear selection') }}</button>
                                        </div>
                                    </div>
                                </div>

                                <div class="mb-3">
                                    <label for="metal_icon_alt_{{ $metalRate->id }}" class="form-label">{{ __('Icon alternative text') }}</label>
                                    <input type="text" class="form-control" id="metal_icon_alt_{{ $metalRate->id }}" name="icon_alt" value="{{ $metalRate->icon_alt }}" maxlength="255" placeholder="{{ __('Describe the icon for screen readers') }}">
                                </div>

                                <div class="d-flex flex-wrap gap-2">
                                    <button type="submit" class="btn btn-primary">{{ __('Save changes') }}</button>
                                </div>
                            </form>
                            @can('metal-rate-delete')
                                <form action="{{ route('metal-rates.destroy', $metalRate) }}" method="POST" class="d-inline-block mt-3" onsubmit="return confirm('{{ __('Are you sure?') }}');">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="btn btn-outline-danger">{{ __('Delete metal') }}</button>
                                </form>
                            @endcan
                        @else
                            <p class="text-muted mb-0">{{ __('You do not have permission to edit this metal rate.') }}</p>
                        @endcan
                    </div>
                </div>
            </div>

            <div class="col-12 col-xl-5">
                <div class="card h-100">
                    <div class="card-header">
                        <h5 class="card-title mb-0">{{ __('Schedule future update') }}</h5>
                    </div>
                    <div class="card-body">
                        @can('metal-rate-schedule')
                            <form action="{{ route('metal-rates.schedule', $metalRate) }}" method="POST" class="mb-4">
                                @csrf
                                <div class="row g-2">
                                    <div class="col-6">
                                        <label class="form-label">{{ __('Buy price') }}</label>
                                        <input type="number" step="0.001" min="0" class="form-control" name="buy_price" required>
                                    </div>
                                    <div class="col-6">
                                        <label class="form-label">{{ __('Sell price') }}</label>
                                        <input type="number" step="0.001" min="0" class="form-control" name="sell_price" required>
                                    </div>
                                </div>
                                <div class="mb-3 mt-3">
                                    <label class="form-label">{{ __('Source (optional)') }}</label>
                                    <input type="text" class="form-control" name="source">
                                </div>
                                <div class="mb-3">
                                    <label class="form-label">{{ __('Run at') }}</label>
                                    <input type="datetime-local" class="form-control" name="scheduled_for" required>
                                </div>
                                <div class="d-grid">
                                    <button type="submit" class="btn btn-outline-primary">{{ __('Schedule update') }}</button>
                                </div>
                            </form>
                        @else
                            <p class="text-muted">{{ __('You do not have permission to schedule updates.') }}</p>
                        @endcan

                        <h6 class="mb-3">{{ __('Upcoming schedules') }}</h6>
                        @if($metalRate->pendingUpdates->isEmpty())
                            <p class="text-muted mb-0">{{ __('No pending schedules.') }}</p>
                        @else
                            <ul class="list-group">
                                @foreach($metalRate->pendingUpdates as $update)
                                    <li class="list-group-item d-flex justify-content-between align-items-center">
                                        <div>
                                            <div class="fw-semibold">{{ __('Run at') }}: {{ optional($update->scheduled_for)->format('Y-m-d H:i') }}</div>
                                            <div class="text-muted small">
                                                {{ __('Buy') }}: {{ number_format((float) $update->buy_price, 3) }} ·
                                                {{ __('Sell') }}: {{ number_format((float) $update->sell_price, 3) }}
                                            </div>
                                        </div>
                                        @can('metal-rate-schedule')
                                            <form action="{{ route('metal-rates.schedule.cancel', $update) }}" method="POST" onsubmit="return confirm('{{ __('Cancel this schedule?') }}');">
                                                @csrf
                                                @method('DELETE')
                                                <button type="submit" class="btn btn-sm btn-outline-danger">{{ __('Cancel') }}</button>
                                            </form>
                                        @endcan
                                    </li>
                                @endforeach
                            </ul>
                        @endif
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection