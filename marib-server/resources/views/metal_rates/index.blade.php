@extends('layouts.main')



@php
    use Illuminate\Support\Facades\Storage;
@endphp



@section('title')
    {{ __('Metal Rates Management') }}
@endsection



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

        <div class="row">
            <div class="col-12">

                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('Existing metal rates') }}</h5>
                        <div class="d-flex align-items-center gap-2">
                            <span class="badge bg-light text-dark">{{ $metalRates->count() }}</span>
                            @can('metal-rate-create')
                                <a href="{{ route('metal-rates.create') }}" class="btn btn-primary btn-sm">{{ __('Add metal rate') }}</a>
                            @endcan
                        </div>
                    
                    </div>
                    <div class="card-body">
                        @if ($metalRates->isEmpty())
                            <p class="text-muted mb-0">{{ __('No metal rates have been configured yet.') }}</p>
                        @else
                            <div class="accordion" id="metalRatesAccordion">
                                @foreach ($metalRates as $rate)
                                    <div class="accordion-item mb-3 border">
                                        <h2 class="accordion-header" id="heading{{ $rate->id }}">
                                            <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapse{{ $rate->id }}" aria-expanded="false" aria-controls="collapse{{ $rate->id }}">
                                                <div class="d-flex flex-column flex-md-row w-100">
                                                    <strong class="me-md-3">{{ $rate->display_name }}</strong>


                                                    @php
                                                        $defaultQuote = $rate->quotes->firstWhere('is_default', true);
                                                        $displayBuy = $defaultQuote?->buy_price ?? $rate->buy_price;
                                                        $displaySell = $defaultQuote?->sell_price ?? $rate->sell_price;
                                                        $displaySource = $defaultQuote?->source ?? $rate->source;
                                                        $displayQuotedAt = optional($defaultQuote?->quoted_at ?? $rate->quoted_at)->format('Y-m-d H:i');
                                                    @endphp

                                                    <div class="text-muted small">
                                                        <span class="me-2">{{ __('Buy') }}: <strong>{{ $displayBuy !== null ? number_format((float) $displayBuy, 3) : '—' }}</strong></span>
                                                        <span class="me-2">{{ __('Sell') }}: <strong>{{ $displaySell !== null ? number_format((float) $displaySell, 3) : '—' }}</strong></span>
                                                        <span class="me-2">{{ __('Source') }}: {{ $displaySource ?: '—' }}</span>
                                                        <span>{{ __('Updated at') }}: {{ $displayQuotedAt ?: '—' }}</span>
                                                    </div>
                                                </div>
                                            </button>
                                        </h2>
                                        <div id="collapse{{ $rate->id }}" class="accordion-collapse collapse" aria-labelledby="heading{{ $rate->id }}" data-bs-parent="#metalRatesAccordion">
                                            <div class="accordion-body">
                                                <div class="row g-4">
                                                    <div class="col-md-6">
                                                        <h6>{{ __('Update rate') }}</h6>
                                                        @can('metal-rate-edit')
                                                            <form action="{{ route('metal-rates.update', $rate) }}" method="POST" class="mb-3" enctype="multipart/form-data">
                                                                @csrf
                                                                @method('PUT')
                                                                <input type="hidden" name="metal_type" value="{{ $rate->metal_type }}">
                                                                <div class="mb-3">
                                                                    <label class="form-label">{{ __('Karat') }}</label>
                                                                    <input type="number" step="0.01" min="0" max="999" class="form-control" name="karat" value="{{ $rate->karat }}" @if($rate->metal_type === 'silver') disabled @endif>
                                                                    @if($rate->metal_type === 'silver')
                                                                        <input type="hidden" name="karat" value="">
                                                                    @endif
                                                                </div>
                                                                 <div class="mb-4">
                                                                    <label class="form-label">{{ __('Governorate quotes') }}</label>
                                                                    @php
                                                                        $quoteMap = $rate->quotes
                                                                            ->mapWithKeys(fn($quote) => [
                                                                                $quote->governorate_id => [
                                                                                    'governorate_id' => $quote->governorate_id,
                                                                                    'sell_price' => $quote->sell_price,
                                                                                    'buy_price' => $quote->buy_price,
                                                                                    'source' => $quote->source,
                                                                                    'quoted_at' => optional($quote->quoted_at)->toIso8601String(),
                                                                                    'is_default' => (bool) $quote->is_default,
                                                                                ],
                                                                            ])
                                                                            ->all();
                                                                        $defaultQuoteId = optional($rate->quotes->firstWhere('is_default', true))->governorate_id ?? $defaultGovernorateId;
                                                                    @endphp
                                                                    @include('metal_rates.partials.quote-table', [
                                                                        'governorates' => $governorates,
                                                                        'quotes' => $quoteMap,
                                                                        'context' => 'update-' . $rate->id,
                                                                        'defaultGovernorateId' => $defaultQuoteId,
                                                                    ])
                                                                </div>


                                                                <div class="mb-3">
                                                                    <label class="form-label" for="metal_icon_{{ $rate->id }}">{{ __('Icon (optional)') }}</label>
                                                                    <input type="file" class="form-control" id="metal_icon_{{ $rate->id }}" name="icon" accept="image/png,image/jpeg,image/jpg,image/webp,image/svg+xml" data-metal-icon-input data-metal-icon-preview="metal_icon_preview_{{ $rate->id }}" data-metal-icon-wrapper="metal_icon_wrapper_{{ $rate->id }}" data-metal-rate-id="{{ $rate->id }}">
                                                                    <div class="form-text">{{ __('Uploading a new file replaces the previous icon.') }}</div>
                                                                    <div class="mt-2 {{ $rate->icon_path ? '' : 'd-none' }}" id="metal_icon_wrapper_{{ $rate->id }}" data-metal-icon-preview-container>
                                                                        <img src="{{ $rate->icon_path ? Storage::url($rate->icon_path) : '#' }}" alt="{{ $rate->icon_alt ?? __('Current icon') }}" id="metal_icon_preview_{{ $rate->id }}" class="img-thumbnail" style="max-height: 120px; {{ $rate->icon_path ? '' : 'display:none;' }}" data-original-src="{{ $rate->icon_path ? Storage::url($rate->icon_path) : '' }}" data-original-alt="{{ $rate->icon_alt ?? '' }}">
                                                                        @if($rate->icon_path)
                                                                            <div class="mt-2 d-flex gap-2" data-metal-icon-actions>
                                                                                <button type="submit" name="remove_icon" value="1" class="btn btn-outline-danger btn-sm" formnovalidate data-metal-icon-remove="{{ $rate->id }}">{{ __('Remove icon') }}</button>
                                                                                <button type="button" class="btn btn-outline-secondary btn-sm" data-metal-icon-clear-input="metal_icon_{{ $rate->id }}">{{ __('Clear selection') }}</button>
                                                                            </div>
                                                                        @else
                                                                            <div class="mt-2 d-flex gap-2">
                                                                                <button type="button" class="btn btn-outline-secondary btn-sm" data-metal-icon-clear-input="metal_icon_{{ $rate->id }}">{{ __('Clear selection') }}</button>
                                                                            </div>
                                                                        @endif
                                                                    </div>
                                                                </div>
                                                                <div class="mb-3">
                                                                    <label class="form-label" for="metal_icon_alt_{{ $rate->id }}">{{ __('Icon alternative text') }}</label>
                                                                    <input type="text" class="form-control" id="metal_icon_alt_{{ $rate->id }}" name="icon_alt" value="{{ $rate->icon_alt }}" maxlength="255" placeholder="{{ __('Describe the icon for screen readers') }}">
                                                                </div>


                                                                <div class="d-flex gap-2">
                                                                    <button type="submit" class="btn btn-primary">{{ __('Save changes') }}</button>
                                                                </div>
                                                            </form>
                                                        @else
                                                            <p class="text-muted">{{ __('You do not have permission to edit this rate.') }}</p>
                                                        @endcan

                                                        @can('metal-rate-delete')
                                                            <form action="{{ route('metal-rates.destroy', $rate) }}" method="POST" onsubmit="return confirm('{{ __('Are you sure?') }}');" class="mt-2">
                                                                @csrf
                                                                @method('DELETE')
                                                                <button type="submit" class="btn btn-outline-danger">{{ __('Delete') }}</button>
                                                            </form>
                                                        @endcan
                                                    </div>
                                                    <div class="col-md-6">
                                                        <h6>{{ __('Schedule future update') }}</h6>
                                                        @can('metal-rate-schedule')
                                                            <form action="{{ route('metal-rates.schedule', $rate) }}" method="POST" class="mb-3">
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

                                                        <h6>{{ __('Upcoming schedules') }}</h6>
                                                        @if($rate->pendingUpdates->isEmpty())
                                                            <p class="text-muted">{{ __('No pending schedules.') }}</p>
                                                        @else
                                                            <ul class="list-group">
                                                                @foreach($rate->pendingUpdates as $update)
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
                                    </div>
                                @endforeach
                            </div>
                        @endif
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection