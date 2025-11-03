{{-- resources/views/services/index.blade.php --}}
@extends('layouts.main')

@section('title')
    {{ __('Services Management') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-muted mb-0">{{ __('Select a category to manage its services.') }}</p>


            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                <div class="float-end d-flex gap-2">
                    @can('service-create')
                        @php $categoriesCount = $categories->count(); @endphp
                        @if($categoriesCount === 1)
                            @php $singleCategory = $categories->first(); @endphp
                            <a class="btn btn-primary" href="{{ route('services.create', ['category_id' => $singleCategory['id']]) }}">
                                <i class="bi bi-plus-circle"></i> {{ __('Create Service') }}
                            </a>
                        @elseif($categoriesCount > 1)
                            <div class="btn-group">
                                <button type="button" class="btn btn-primary dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false">
                                    <i class="bi bi-plus-circle"></i> {{ __('Create Service') }}
                                </button>
                                <ul class="dropdown-menu dropdown-menu-end">
                                    <li><h6 class="dropdown-header">{{ __('Select Category') }}</h6></li>
                                    @foreach($categories as $categoryOption)
                                        <li>
                                            <a class="dropdown-item" href="{{ route('services.create', ['category_id' => $categoryOption['id']]) }}">
                                                {{ $categoryOption['name'] }}
                                            </a>
                                        </li>
                                    @endforeach
                                </ul>
                            </div>
                        @endif
                    @endcan
                </div>
            </div>
        </div>
    </div>
@endsection








@section('content')
    <section class="section">




            <div class="row g-4">
            @forelse($categories as $category)
                <div class="col-12 col-sm-6 col-lg-4 col-xl-3">
                    <div class="card h-100 shadow-sm border-0 category-card" data-category-url="{{ route('services.category', $category['id']) }}">
                        <div class="ratio ratio-16x9 bg-light rounded-top overflow-hidden">
                            @if(!empty($category['image']))
                                <img src="{{ $category['image'] }}" alt="{{ $category['name'] }}" class="w-100 h-100 object-fit-cover">
                            @else
                                <div class="d-flex align-items-center justify-content-center h-100 text-muted">
                                    <i class="bi bi-collection-play fs-1"></i>
                                </div>
                            @endif

                        </div>



                        <div class="card-body d-flex flex-column">
                            <h5 class="card-title mb-1">{{ $category['name'] }}</h5>
                            <p class="text-muted small mb-3">{{ __('Manage and review services within this category.') }}</p>

                            <ul class="list-unstyled small mb-4">
                                <li class="d-flex justify-content-between align-items-center mb-1">
                                    <span><i class="bi bi-grid me-1"></i>{{ __('Total services') }}</span>
                                    <span class="fw-semibold">{{ number_format($category['total_services']) }}</span>
                                </li>
                                <li class="d-flex justify-content-between align-items-center mb-1">
                                    <span><i class="bi bi-check-circle me-1 text-success"></i>{{ __('Active services') }}</span>
                                    <span class="fw-semibold text-success">{{ number_format($category['active_services']) }}</span>
                                </li>
                                <li class="d-flex justify-content-between align-items-center">
                                    <span><i class="bi bi-wallet2 me-1 text-warning"></i>{{ __('Paid services') }}</span>
                                    <span class="fw-semibold text-warning">{{ number_format($category['paid_services']) }}</span>
                                </li>
                            </ul>

                            <div class="mt-auto">
                                <button type="button" class="btn btn-outline-primary w-100 js-open-category">
                                    <i class="bi bi-box-arrow-in-right"></i> {{ __('Enter category') }}
                                </button>
                            </div>


                        </div>
                    </div>
                </div>
            @empty
                <div class="col-12">
                    <div class="card border-0 shadow-sm">
                        <div class="card-body text-center text-muted py-5">
                            <i class="bi bi-grid-3x3-gap display-6 d-block mb-3"></i>
                            <p class="mb-0">{{ __('No categories available for management.') }}</p>
                        </div>
                    </div>
                </div>
            @endforelse


            </div>
    </section>


  



@endsection

@section('script')



    <script>
        document.addEventListener('DOMContentLoaded', function () {
            document.querySelectorAll('.category-card').forEach(function (card) {
                const targetUrl = card.getAttribute('data-category-url');
                if (!targetUrl) {
                    return;

                }

                const button = card.querySelector('.js-open-category');
                if (button) {
                    button.addEventListener('click', function (event) {
                        event.preventDefault();
                        window.location.href = targetUrl;
                    });
                }



                card.addEventListener('click', function (event) {
                    if (event.target.closest('button, a, input, select, textarea')) {
                        return;
                    }



                    window.location.href = targetUrl;
                });
            });


           
        });
        </script>


@endsection
