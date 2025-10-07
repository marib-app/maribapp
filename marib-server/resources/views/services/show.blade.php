{{-- resources/views/services/show.blade.php --}}
@extends('layouts.main')

@section('title')
    {{ __('Service Details') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                <nav aria-label="breadcrumb" class="breadcrumb-header float-end float-lg-end">
                    <ol class="breadcrumb">
                        <li class="breadcrumb-item">
                            <a href="{{ route('services.index') }}" class="btn btn-outline-primary">
                                <i class="bi bi-arrow-left"></i> {{ __('Back to Services') }}
                            </a>
                        </li>
                        @can('service-edit')
                        <li class="breadcrumb-item">
                            <a href="{{ route('services.edit', $service->id) }}" class="btn btn-primary">
                                <i class="bi bi-pencil"></i> {{ __('Edit') }}
                            </a>
                        </li>
                        @endcan
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
<section class="section">
    <div class="card">
        <div class="card-body">
            {{-- ======= بيانات أساسية ======= --}}
            <div class="row g-4">

                {{-- الصورة والأيقونة --}}
                <div class="col-md-4">
                    <div class="mb-3">
                        <label class="form-label d-block">{{ __('Image') }}</label>
                        @if($service->image)
                            <img src="{{ asset('storage/' . $service->image) }}" alt="image" class="img-fluid rounded border" style="max-height: 200px">
                        @else
                            <span class="text-muted">{{ __('No image') }}</span>
                        @endif
                    </div>
                    <div>
                        <label class="form-label d-block">{{ __('Icon') }}</label>
                        @if($service->icon)
                            <img src="{{ asset('storage/' . $service->icon) }}" alt="icon" class="img-thumbnail rounded" style="height: 80px">
                        @else
                            <span class="text-muted">{{ __('No icon') }}</span>
                        @endif
                    </div>
                </div>

                {{-- الحقول النصية والبادجات --}}
                <div class="col-md-8">
                    <div class="row g-3">

                        <div class="col-12">
                            <h5 class="mb-1">{{ $service->title }}</h5>
                            <div class="small text-muted">
                                {{ __('ID') }}: {{ $service->id }}
                                @if(!empty($service->service_uid))
                                    &nbsp; • &nbsp; {{ __('UID') }}: <code>{{ $service->service_uid }}</code>
                                @endif
                            </div>
                        </div>

                        <div class="col-md-6">
                            <label class="form-label d-block">{{ __('Category') }}</label>
                            <div>{{ optional($service->category)->name }} @if($service->category_id) <span class="text-muted">(ID: {{ $service->category_id }})</span>@endif</div>
                        </div>



                        <div class="col-md-6">
                            <label class="form-label d-block">{{ __('Service Owner') }}</label>
                            @if($service->owner)
                                <div>{{ $service->owner->name }} <span class="text-muted">(ID: {{ $service->owner->id }})</span></div>
                                @if($service->owner->email)
                                    <div class="small text-muted">{{ $service->owner->email }}</div>
                                @endif
                            @else
                                <span class="text-muted">{{ __('No owner assigned') }}</span>
                            @endif
                        </div>


                        <div class="col-md-6">
                            <label class="form-label d-block">{{ __('Status') }}</label>
                            @if($service->status)
                                <span class="badge bg-success">{{ __('Active') }}</span>
                            @else
                                <span class="badge bg-danger">{{ __('Inactive') }}</span>
                            @endif
                        </div>

                        <div class="col-md-6">
                            <label class="form-label d-block">{{ __('Is Main Service') }}</label>
                            @if($service->is_main)
                                <span class="badge bg-primary">{{ __('Yes') }}</span>
                            @else
                                <span class="badge bg-secondary">{{ __('No') }}</span>
                            @endif
                        </div>

                        <div class="col-md-6">
                            <label class="form-label d-block">{{ __('Views') }}</label>
                            <div>{{ $service->views ?? 0 }}</div>
                        </div>

                        <div class="col-md-6">
                            <label class="form-label d-block">{{ __('Expiry Date') }}</label>
                            <div>
                                {{ $service->expiry_date ? \Illuminate\Support\Carbon::parse($service->expiry_date)->format('Y-m-d') : __('No expiry') }}
                            </div>
                        </div>

                        {{-- ======= خيارات الدفع ======= --}}
                        <div class="col-12"><hr class="my-2"></div>

                        <div class="col-md-4">
                            <label class="form-label d-block">{{ __('Is Paid') }}</label>
                            @if($service->is_paid)
                                <span class="badge bg-success">{{ __('Yes') }}</span>
                            @else
                                <span class="badge bg-secondary">{{ __('No') }}</span>
                            @endif
                        </div>

                        <div class="col-md-4">
                            <label class="form-label d-block">{{ __('Price') }}</label>
                            <div>
                                @if($service->is_paid && $service->price !== null)
                                    {{ number_format((float)$service->price, 2) }}
                                @else
                                    <span class="text-muted">-</span>
                                @endif
                            </div>
                        </div>

                        <div class="col-md-4">
                            <label class="form-label d-block">{{ __('Currency') }}</label>
                            <div>
                                @if($service->is_paid && $service->currency)
                                    {{ $service->currency }}
                                @else
                                    <span class="text-muted">-</span>
                                @endif
                            </div>
                        </div>

                        @if($service->is_paid && $service->price_note)
                        <div class="col-12">
                            <label class="form-label d-block">{{ __('Price Note') }}</label>
                            <div class="text-wrap">{{ $service->price_note }}</div>
                        </div>
                        @endif

                        {{-- ======= الحقول المخصصة ======= --}}
                        <div class="col-12"><hr class="my-2"></div>

                        <div class="col-md-6">
                            <label class="form-label d-block">{{ __('Has Custom Fields') }}</label>
                            @if($service->has_custom_fields)
                                <span class="badge bg-info">{{ __('Yes') }}</span>
                            @else
                                <span class="badge bg-secondary">{{ __('No') }}</span>
                            @endif
                            <div class="small text-muted mt-1">
                                {{ __('When enabled, the app uses the category custom fields in the continue/apply flow.') }}
                            </div>
                        </div>

                        {{-- ======= التوجيه للدردشة المباشرة ======= --}}
                        <div class="col-md-6">
                            <label class="form-label d-block">{{ __('Direct To User') }}</label>
                            @if($service->direct_to_user)
                                <span class="badge bg-info">{{ __('Yes') }}</span>
                                <div class="mt-1">
                                    <span class="text-muted">{{ __('Advertiser') }}:</span>
                                    @if(isset($service->directUser))
                                        {{ $service->directUser->name }} <span class="text-muted">(ID: {{ $service->direct_user_id }})</span>
                                    @elseif($service->direct_user_id)
                                        <span class="text-muted">ID: {{ $service->direct_user_id }}</span>
                                    @else
                                        <span class="text-muted">-</span>
                                    @endif
                                </div>
                            @else
                                <span class="badge bg-secondary">{{ __('No') }}</span>
                            @endif
                        </div>

                        {{-- ======= النوع (إن استُخدم) ======= --}}
                        @if(!empty($service->service_type))
                        <div class="col-md-6">
                            <label class="form-label d-block">{{ __('Service Type') }}</label>
                            <div>{{ $service->service_type }}</div>
                        </div>
                        @endif

                    </div>
                </div>

                {{-- الوصف --}}
                <div class="col-12">
                    <hr class="my-3">
                    <label class="form-label d-block">{{ __('Description') }}</label>
                    @if(!empty($service->description))
                        <div class="border rounded p-3 bg-light">
                            {!! $service->description !!}
                        </div>
                    @else
                        <div class="text-muted">{{ __('No description') }}</div>
                    @endif
                </div>

            </div>
        </div>
    </div>
</section>
@endsection
