@extends('layouts.main')

@section('title')
    {{ __('Metal Rates Management') }}
@endsection

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
            @can('metal-rate-create')
                <div class="col-lg-4">
                <div class="card h-100">
                    <div class="card-header">
                        <h5 class="card-title mb-0">{{ __('Add metal rate') }}</h5>
                    </div>
                    <div class="card-body">
                        <form action="{{ route('metal-rates.store') }}" method="POST" class="needs-validation" novalidate>
                            @csrf
                            <div class="mb-3">
                                <label for="metal_type" class="form-label">{{ __('Metal type') }}</label>
                                <select name="metal_type" id="metal_type" class="form-select" required>
                                    <option value="" disabled selected>{{ __('Select type') }}</option>
                                    <option value="gold" @selected(old('metal_type') === 'gold')>{{ __('Gold') }}</option>
                                    <option value="silver" @selected(old('metal_type') === 'silver')>{{ __('Silver') }}</option>
                                </select>
                            </div>

                            <div class="mb-3">
                                <label for="karat" class="form-label">{{ __('Karat (for gold only)') }}</label>
                                <input type="number" step="0.01" min="0" max="999" class="form-control" id="karat" name="karat" value="{{ old('karat') }}" placeholder="24">
                                <div class="form-text">{{ __('Leave empty for silver.') }}</div>
                            </div>

                            <div class="row g-2">
                                <div class="col-6">
                                    <label for="buy_price" class="form-label">{{ __('Buy price') }}</label>
                                    <input type="number" step="0.001" min="0" class="form-control" id="buy_price" name="buy_price" value="{{ old('buy_price') }}" required>
                                </div>
                                <div class="col-6">
                                    <label for="sell_price" class="form-label">{{ __('Sell price') }}</label>
                                    <input type="number" step="0.001" min="0" class="form-control" id="sell_price" name="sell_price" value="{{ old('sell_price') }}" required>
                                </div>
                            </div>

                            <div class="mb-3 mt-3">
                                <label for="source" class="form-label">{{ __('Source (optional)') }}</label>
                                <input type="text" class="form-control" id="source" name="source" value="{{ old('source') }}">
                            </div>

                            <div class="mb-3">
                                <label for="quoted_at" class="form-label">{{ __('Quote timestamp (optional)') }}</label>
                                <input type="datetime-local" class="form-control" id="quoted_at" name="quoted_at" value="{{ old('quoted_at') }}">
                            </div>

                            <div class="d-grid">
                                <button type="submit" class="btn btn-primary">{{ __('Save metal rate') }}</button>
                            </div>
                        </form>
                    </div>
                </div>
                </div>
            @endcan

            <div class="{{ auth()->user()?->can('metal-rate-create') ? 'col-lg-8' : 'col-lg-12' }}">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('Existing metal rates') }}</h5>
                        <span class="badge bg-light text-dark">{{ $metalRates->count() }}</span>
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
                                                    <div class="text-muted small">
                                                        <span class="me-2">{{ __('Buy') }}: <strong>{{ number_format((float) $rate->buy_price, 3) }}</strong></span>
                                                        <span class="me-2">{{ __('Sell') }}: <strong>{{ number_format((float) $rate->sell_price, 3) }}</strong></span>
                                                        <span>{{ __('Updated at') }}: {{ optional($rate->updated_at)->format('Y-m-d H:i') }}</span>
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
                                                            <form action="{{ route('metal-rates.update', $rate) }}" method="POST" class="mb-3">
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
                                                                <div class="row g-2">
                                                                    <div class="col-6">
                                                                        <label class="form-label">{{ __('Buy price') }}</label>
                                                                        <input type="number" step="0.001" min="0" class="form-control" name="buy_price" value="{{ $rate->buy_price }}" required>
                                                                    </div>
                                                                    <div class="col-6">
                                                                        <label class="form-label">{{ __('Sell price') }}</label>
                                                                        <input type="number" step="0.001" min="0" class="form-control" name="sell_price" value="{{ $rate->sell_price }}" required>
                                                                    </div>
                                                                </div>
                                                                <div class="mb-3 mt-3">
                                                                    <label class="form-label">{{ __('Source') }}</label>
                                                                    <input type="text" class="form-control" name="source" value="{{ $rate->source }}">
                                                                </div>
                                                                <div class="mb-3">
                                                                    <label class="form-label">{{ __('Quote timestamp') }}</label>
                                                                    <input type="datetime-local" class="form-control" name="quoted_at" value="{{ optional($rate->quoted_at)->format('Y-m-d\TH:i') }}">
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