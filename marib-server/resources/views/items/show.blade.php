@extends('layouts.main')

@section('title')
    {{ __('Item Details') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-12 col-md-8">
                <h4 class="mb-0">{{ __('Item Details') }}</h4>
                <p class="text-muted mb-0">{{ $item->name }}</p>
            </div>
            <div class="col-12 col-md-4 text-md-end mt-3 mt-md-0">
                <a href="{{ url()->previous() }}" class="btn btn-outline-secondary">
                    <i class="fa fa-arrow-left"></i> {{ __('Back') }}
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
                    <div class="card-header border-bottom-0 bg-light">
                        <h5 class="mb-0">{{ __('Basic Information') }}</h5>
                    </div>
                    <div class="card-body">

                        @php
                            $hasCoordinates = filled($item->latitude) && filled($item->longitude);
                            $coordinateDisplay = $hasCoordinates ? sprintf('%s, %s', $item->latitude, $item->longitude) : null;
                            $videoLink = $item->video_link;
                            $isPremiumOnly = filter_var($item->show_only_to_premium, FILTER_VALIDATE_BOOLEAN);
                        @endphp

                        <dl class="row mb-0">
                            <dt class="col-sm-4 text-muted">{{ __('ID') }}</dt>
                            <dd class="col-sm-8">{{ $item->id }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Name') }}</dt>
                            <dd class="col-sm-8">{{ $item->name }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Slug') }}</dt>
                            <dd class="col-sm-8">{{ $item->slug ?? __('Not Available') }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Owner') }}</dt>
                            <dd class="col-sm-8">{{ optional($item->user)->name ?? __('Not Available') }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Category') }}</dt>
                            <dd class="col-sm-8">{{ optional($item->category)->name ?? __('Not Available') }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Country') }}</dt>
                            <dd class="col-sm-8">{{ $item->country ?? __('Not Available') }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('State') }}</dt>
                            <dd class="col-sm-8">{{ $item->state ?? __('Not Available') }}</dd>


                            <dt class="col-sm-4 text-muted">{{ __('Price') }}</dt>
                            <dd class="col-sm-8">{{ $item->price }} {{ $item->currency }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Status') }}</dt>
                            <dd class="col-sm-8">
                                <span class="badge bg-primary">{{ ucfirst($item->status) }}</span>
                                <small class="text-muted ms-2">{{ __('Original') }}: {{ ucfirst($item->getRawOriginal('status')) }}</small>
                            </dd>

                            <dt class="col-sm-4 text-muted">{{ __('City') }}</dt>
                            <dd class="col-sm-8">{{ $item->city ?? __('Not Available') }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Area') }}</dt>
                            <dd class="col-sm-8">{{ optional($item->area)->name ?? __('Not Available') }}</dd>



                            <dt class="col-sm-4 text-muted">{{ __('Address') }}</dt>
                            <dd class="col-sm-8">{{ $item->address ?? __('Not Available') }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Coordinates') }}</dt>
                            <dd class="col-sm-8">{{ $coordinateDisplay ?? __('Not Available') }}</dd>


                            <dt class="col-sm-4 text-muted">{{ __('Contact') }}</dt>
                            <dd class="col-sm-8">{{ $item->contact ?? __('Not Available') }}</dd>


                            <dt class="col-sm-4 text-muted">{{ __('Video Link') }}</dt>
                            <dd class="col-sm-8">
                                @if(!empty($videoLink))
                                    <a href="{{ $videoLink }}" class="text-decoration-underline" target="_blank" rel="noopener">
                                        {{ __('Watch Video') }}
                                    </a>
                                @else
                                    {{ __('Not Available') }}
                                @endif
                            </dd>

                            <dt class="col-sm-4 text-muted">{{ __('Premium Visibility') }}</dt>
                            <dd class="col-sm-8">
                                <span class="badge {{ $isPremiumOnly ? 'bg-warning text-dark' : 'bg-success' }}">
                                    {{ $isPremiumOnly ? __('Restricted to Premium') : __('Visible to All') }}
                                </span>
                            </dd>

                            <dt class="col-sm-4 text-muted">{{ __('Views') }}</dt>
                            <dd class="col-sm-8">{{ number_format((int) ($item->clicks ?? 0)) }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Likes') }}</dt>
                            <dd class="col-sm-8">{{ number_format($item->favourites?->count() ?? 0) }}</dd>



                            <dt class="col-sm-4 text-muted">{{ __('Created At') }}</dt>
                            <dd class="col-sm-8">{{ optional($item->created_at)->format('Y-m-d H:i') }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Updated At') }}</dt>
                            <dd class="col-sm-8">{{ optional($item->updated_at)->format('Y-m-d H:i') }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Deleted At') }}</dt>
                            <dd class="col-sm-8">{{ optional($item->deleted_at)->format('Y-m-d H:i') ?? __('Active') }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Expiry Date') }}</dt>
                            <dd class="col-sm-8">{{ $item->expiry_date ? \Illuminate\Support\Carbon::parse($item->expiry_date)->format('Y-m-d') : __('Not Available') }}</dd>

                            <dt class="col-sm-4 text-muted">{{ __('Sold To') }}</dt>
                            <dd class="col-sm-8">{{ $item->sold_to ?? __('Not Available') }}</dd>
                        </dl>
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light">
                        <h5 class="mb-0">{{ __('Description') }}</h5>
                    </div>
                    <div class="card-body">
                        <p class="mb-0">{!! nl2br(e($item->description ?? __('No description provided.'))) !!}</p>
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('Custom Fields') }}</h5>
                        <span class="badge bg-secondary">{{ $customFields->count() }}</span>
                    </div>
                    <div class="card-body">
                        <div class="row g-3 custom-field-grid">
                            @forelse($customFields as $field)
                                <div class="col-md-6 col-xl-4">
                                    <div class="custom-field-card h-100">
                                        <div class="custom-field-heading">
                                            @if(!empty($field['image']))
                                                <img src="{{ $field['image'] }}" alt="{{ $field['name'] }}" class="custom-field-icon" onerror="onErrorImage(event)">
                                            @endif
                                            
                                            <div class="flex-grow-1">
                                                <div class="d-flex align-items-start justify-content-between gap-2">
                                                    <div>
                                                        <h6 class="custom-field-name mb-0">{{ $field['name'] }}</h6>
                                                        <small class="text-muted text-uppercase">{{ $field['type'] }}</small>
                                                    </div>
                                                    @if(!empty($field['description']))
                                                        <small class="text-muted text-end custom-field-description">{{ $field['description'] }}</small>
                                                    @endif
                                                </div>
                                            </div>

                                        </div>
                                        <div class="custom-field-body">
                                            @if($field['type'] === 'fileinput')
                                                <div class="custom-field-files">
                                                    @forelse($field['file_urls'] as $fileUrl)
                                                        <a href="{{ $fileUrl }}" target="_blank" class="custom-field-file-link">
                                                            <i class="fa fa-file"></i> {{ __('View File') }}
                                                        </a>
                                                    @empty
                                                        <span class="text-muted">{{ __('Not Available') }}</span>
                                                    @endforelse
                                                </div>
                                            @else
                                                <p class="custom-field-value mb-0">{{ $field['display_value'] ?? __('Not Available') }}</p>
                                            @endif
                                        </div>
                                    </div>
                                </div>
                            @empty
                                <div class="col-12">
                                    <div class="text-center text-muted py-4">
                                        <i class="fa fa-info-circle fa-2x mb-2"></i>
                                        <p class="mb-0">{{ __('No custom fields available for this item.') }}</p>
                                    </div>
                                </div>
                            @endforelse
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-lg-4">





                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light">
                        <h5 class="mb-0">{{ __('Location') }}</h5>
                    </div>
                    <div class="card-body">
                        @php
                            $locationDetails = collect([
                                ['label' => __('Address'), 'value' => $item->address],
                                ['label' => __('City'), 'value' => $item->city],
                                ['label' => __('State'), 'value' => $item->state],
                                ['label' => __('Country'), 'value' => $item->country],
                                ['label' => __('Area'), 'value' => optional($item->area)->name],
                                ['label' => __('Coordinates'), 'value' => $coordinateDisplay ?? null],
                            ])->filter(static fn ($detail) => filled($detail['value']));
                        @endphp

                        <ul class="list-unstyled mb-0 small">
                            @forelse($locationDetails as $detail)
                                <li class="d-flex justify-content-between align-items-start py-1">
                                    <span class="text-muted me-2">{{ $detail['label'] }}</span>
                                    <span class="fw-semibold text-end text-break">{{ $detail['value'] }}</span>
                                </li>
                            @empty
                                <li class="text-muted text-center py-2">{{ __('No location details available.') }}</li>
                            @endforelse
                        </ul>

                        @if(!empty($mapsLink))
                            <div class="mt-3 text-center">
                                <a href="{{ $mapsLink }}" class="btn btn-outline-primary btn-sm" target="_blank" rel="noopener">
                                    <i class="fa fa-map-marker-alt"></i> {{ __('Open in Maps') }}
                                </a>
                            </div>
                        @endif
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light">
                        <h5 class="mb-0">{{ __('Statistics') }}</h5>
                    </div>
                    <div class="card-body">
                        <div class="row g-3">
                            @forelse($statistics as $statistic)
                                <div class="col-6">
                                    <div class="border rounded-3 p-3 text-center h-100">
                                        @if(!empty($statistic['icon']))
                                            <span class="d-inline-flex justify-content-center align-items-center rounded-circle bg-light text-primary mb-2" style="width: 36px; height: 36px;">
                                                <i class="fa {{ $statistic['icon'] }}"></i>
                                            </span>
                                        @endif
                                        <div class="text-uppercase text-muted small">{{ $statistic['label'] }}</div>
                                        <div class="fs-5 fw-semibold mt-1">{{ $statistic['value'] }}</div>
                                    </div>
                                </div>
                            @empty
                                <div class="col-12">
                                    <p class="text-muted text-center mb-0">{{ __('No statistics available.') }}</p>
                                </div>
                            @endforelse
                        </div>
                    </div>
                </div>





                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light">
                        <h5 class="mb-0">{{ __('Actions') }}</h5>
                    </div>
                    <div class="card-body">
                        @php
                            $availableEditRoutes = collect();
                            if($isSheinItem && \Illuminate\Support\Facades\Route::has('item.shein.products.edit')) {
                                $availableEditRoutes = $availableEditRoutes->push([
                                    'url' => route('item.shein.products.edit', $item->id),
                                    'label' => __('Edit All Data (Shein)'),
                                ]);
                            }
                            if(\Illuminate\Support\Facades\Route::has('item.edit')) {
                                $availableEditRoutes = $availableEditRoutes->push([
                                    'url' => route('item.edit', $item->id),
                                    'label' => __('Edit'),
                                ]);
                            }
                        @endphp

                        @if($canUpdate)
                            @foreach($availableEditRoutes as $route)
                                <a href="{{ $route['url'] }}" class="btn btn-primary w-100 mb-2">
                                    <i class="fa fa-edit"></i> {{ $route['label'] }}
                                </a>
                            @endforeach

                            <form action="{{ route('item.approval', $item->id) }}" method="POST" class="border rounded-3 p-3 mb-3">
                                @csrf
                                @method('PUT')
                                <h6 class="fw-semibold mb-3">{{ __('Update Status') }}</h6>
                                <div class="mb-3">
                                    <label for="status_select" class="form-label">{{ __('Status') }}</label>
                                    <select name="status" id="status_select" class="form-select">
                                        @foreach($statusOptions as $statusKey => $label)
                                            <option value="{{ $statusKey }}" @selected($item->getRawOriginal('status') === $statusKey)>
                                                {{ $label }}
                                            </option>
                                        @endforeach
                                    </select>
                                </div>
                                <div class="mb-3" id="rejected_reason_container" style="display: none;">
                                    <label for="rejected_reason_field" class="form-label">{{ __('Reason') }}</label>
                                    <textarea name="rejected_reason" id="rejected_reason_field" class="form-control" rows="3">{{ $item->rejected_reason }}</textarea>
                                </div>
                                <button type="submit" class="btn btn-outline-primary w-100">
                                    <i class="fa fa-save"></i> {{ __('Save Changes') }}
                                </button>
                            </form>
                        @endif

                        @if($canFeature)
                            <form action="{{ route('item.feature', $item->id) }}" method="POST" class="mb-3" onsubmit="return confirm('{{ __('Are you sure you want to feature this item?') }}');">
                                @csrf
                                <button type="submit" class="btn btn-warning w-100">
                                    <i class="fa fa-star"></i> {{ __('Feature Item') }}
                                </button>
                            </form>
                        @endif

                        @if($canDelete)
                            <form action="{{ route('item.destroy', $item->id) }}" method="POST" onsubmit="return confirm('{{ __('Are you sure you want to delete this item?') }}');">
                                @csrf
                                @method('DELETE')
                                <button type="submit" class="btn btn-outline-danger w-100">
                                    <i class="fa fa-trash"></i> {{ __('Delete Item') }}
                                </button>
                            </form>
                        @endif
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light">
                        <h5 class="mb-0">{{ __('Images') }}</h5>
                    </div>
                    <div class="card-body">
                        <div class="mb-3 text-center">
                            <img src="{{ $item->image }}" alt="{{ $item->name }}" class="img-fluid rounded shadow" onerror="onErrorImage(event)">
                            <p class="text-muted small mt-2 mb-0">{{ __('Primary Image') }}</p>
                        </div>
                        <div class="row g-2">
                            @forelse($item->gallery_images as $image)
                                <div class="col-6">
                                    <img src="{{ $image->image }}" alt="{{ $item->name }}" class="img-fluid rounded" onerror="onErrorImage(event)">
                                </div>
                            @empty
                                <div class="col-12">
                                    <span class="text-muted">{{ __('No gallery images available.') }}</span>
                                </div>
                            @endforelse
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-4 mt-1">
            <div class="col-12">
                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('Featured Records') }}</h5>
                        <span class="badge bg-secondary">{{ $item->featured_items->count() }}</span>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped align-middle mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('Start Date') }}</th>
                                        <th>{{ __('End Date') }}</th>
                                        <th>{{ __('Created At') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($item->featured_items as $feature)
                                        <tr>
                                            <td>{{ $feature->start_date ? \Illuminate\Support\Carbon::parse($feature->start_date)->format('Y-m-d') : __('Not Available') }}</td>
                                            <td>{{ $feature->end_date ? \Illuminate\Support\Carbon::parse($feature->end_date)->format('Y-m-d') : __('Ongoing') }}</td>
                                            <td>{{ optional($feature->created_at)->format('Y-m-d H:i') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="text-center text-muted">{{ __('No featured records found.') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('Offers') }}</h5>
                        <span class="badge bg-secondary">{{ $item->item_offers->count() }}</span>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped align-middle mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('ID') }}</th>
                                        <th>{{ __('Amount') }}</th>
                                        <th>{{ __('Seller') }}</th>
                                        <th>{{ __('Buyer') }}</th>
                                        <th>{{ __('Created At') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($item->item_offers as $offer)
                                        <tr>
                                            <td>{{ $offer->id }}</td>
                                            <td>{{ $offer->amount }}</td>
                                            <td>{{ optional($offer->seller)->name ?? __('Not Available') }}</td>
                                            <td>{{ optional($offer->buyer)->name ?? __('Not Available') }}</td>
                                            <td>{{ optional($offer->created_at)->format('Y-m-d H:i') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="5" class="text-center text-muted">{{ __('No offers found.') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('Favourites') }}</h5>
                        <span class="badge bg-secondary">{{ $item->favourites->count() }}</span>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped align-middle mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('ID') }}</th>
                                        <th>{{ __('User ID') }}</th>
                                        <th>{{ __('Created At') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($item->favourites as $favourite)
                                        <tr>
                                            <td>{{ $favourite->id }}</td>
                                            <td>{{ $favourite->user_id }}</td>
                                            <td>{{ optional($favourite->created_at)->format('Y-m-d H:i') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="3" class="text-center text-muted">{{ __('No favourites found.') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('Cart Items') }}</h5>
                        <span class="badge bg-secondary">{{ $item->cartItems->count() }}</span>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped align-middle mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('ID') }}</th>
                                        <th>{{ __('User') }}</th>
                                        <th>{{ __('Quantity') }}</th>
                                        <th>{{ __('Unit Price') }}</th>
                                        <th>{{ __('Currency') }}</th>
                                        <th>{{ __('Created At') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($item->cartItems as $cartItem)
                                        <tr>
                                            <td>{{ $cartItem->id }}</td>
                                            <td>{{ optional($cartItem->user)->name ?? __('Not Available') }}</td>
                                            <td>{{ $cartItem->quantity }}</td>
                                            <td>{{ $cartItem->getLockedUnitPrice() }}</td>
                                            <td>{{ $cartItem->currency }}</td>
                                            <td>{{ optional($cartItem->created_at)->format('Y-m-d H:i') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="6" class="text-center text-muted">{{ __('No cart records found.') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('User Reports') }}</h5>
                        <span class="badge bg-secondary">{{ $item->user_reports->count() }}</span>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped align-middle mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('ID') }}</th>
                                        <th>{{ __('Reporter') }}</th>
                                        <th>{{ __('Reason') }}</th>
                                        <th>{{ __('Department') }}</th>
                                        <th>{{ __('Created At') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($item->user_reports as $report)
                                        <tr>
                                            <td>{{ $report->id }}</td>
                                            <td>{{ optional($report->user)->name ?? __('Not Available') }}</td>
                                            <td>{{ optional($report->report_reason)->reason ?? $report->reason ?? __('Not Available') }}</td>
                                            <td>{{ $report->department ?? __('Not Available') }}</td>
                                            <td>{{ optional($report->created_at)->format('Y-m-d H:i') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="5" class="text-center text-muted">{{ __('No reports found.') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('Reviews') }}</h5>
                        <span class="badge bg-secondary">{{ $item->review->count() }}</span>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped align-middle mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('ID') }}</th>
                                        <th>{{ __('Rating') }}</th>
                                        <th>{{ __('Review') }}</th>
                                        <th>{{ __('Seller') }}</th>
                                        <th>{{ __('Buyer') }}</th>
                                        <th>{{ __('Created At') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($item->review as $review)
                                        <tr>
                                            <td>{{ $review->id }}</td>
                                            <td>{{ $review->ratings }}</td>
                                            <td>{{ $review->review }}</td>
                                            <td>{{ optional($review->seller)->name ?? __('Not Available') }}</td>
                                            <td>{{ optional($review->buyer)->name ?? __('Not Available') }}</td>
                                            <td>{{ optional($review->created_at)->format('Y-m-d H:i') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="6" class="text-center text-muted">{{ __('No reviews found.') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card mb-4">
                    <div class="card-header border-bottom-0 bg-light d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('Sliders') }}</h5>
                        <span class="badge bg-secondary">{{ $item->sliders->count() }}</span>
                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-striped align-middle mb-0">
                                <thead>
                                    <tr>
                                        <th>{{ __('ID') }}</th>
                                        <th>{{ __('Name') }}</th>
                                        <th>{{ __('Sequence') }}</th>
                                        <th>{{ __('Third Party Link') }}</th>
                                        <th>{{ __('Created At') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    @forelse($item->sliders as $slider)
                                        <tr>
                                            <td>{{ $slider->id }}</td>
                                            <td>{{ $slider->name }}</td>
                                            <td>{{ $slider->sequence }}</td>
                                            <td>
                                                @if($slider->third_party_link)
                                                    <a href="{{ $slider->third_party_link }}" target="_blank">{{ $slider->third_party_link }}</a>
                                                @else
                                                    <span class="text-muted">{{ __('Not Available') }}</span>
                                                @endif
                                            </td>
                                            <td>{{ optional($slider->created_at)->format('Y-m-d H:i') }}</td>
                                        </tr>
                                    @empty
                                        <tr>
                                            <td colspan="5" class="text-center text-muted">{{ __('No sliders linked to this item.') }}</td>
                                        </tr>
                                    @endforelse
                                </tbody>
                            </table>
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
            const statusSelect = document.getElementById('status_select');
            const reasonContainer = document.getElementById('rejected_reason_container');
            const reasonField = document.getElementById('rejected_reason_field');

            if (!statusSelect || !reasonContainer) {
                return;
            }

            const toggleReason = function () {
                if (statusSelect.value === 'rejected') {
                    reasonContainer.style.display = '';
                    reasonField?.setAttribute('required', 'required');
                } else {
                    reasonContainer.style.display = 'none';
                    reasonField?.removeAttribute('required');
                }
            };

            statusSelect.addEventListener('change', toggleReason);
            toggleReason();
        });
    </script>
@endsection