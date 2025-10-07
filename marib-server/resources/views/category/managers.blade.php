@extends('layouts.main')

@section('title')
    {{ __('Manage Category Managers') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-muted mb-0">{{ __('حدد العملاء الذين يمكنهم إدارة هذه الفئة عبر لوحة التحكم وطلبات الخدمة.') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                <nav aria-label="breadcrumb" class="breadcrumb-header float-end float-lg-end">
                    <ol class="breadcrumb">
                        <li class="breadcrumb-item">
                            <a href="{{ route('category.index') }}" class="btn btn-outline-primary">
                                <i class="bi bi-arrow-left"></i> {{ __('Back to Categories') }}
                            </a>
                        </li>
                        <li class="breadcrumb-item active" aria-current="page">{{ $category->name }}</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card shadow-sm">
            <div class="card-body">
                <div class="mb-4">
                    <h5 class="fw-semibold mb-1">{{ $category->name }}</h5>
                    <div class="text-muted small">
                        {{ __('Category ID') }}: {{ $category->id }}

                    </div>
                </div>

                @if(session('success'))
                    <div class="alert alert-success" role="alert">
                        {{ session('success') }}
                    </div>
                @endif

                @if($errors->any())
                    <div class="alert alert-danger" role="alert">
                        {{ $errors->first() }}
                    </div>
                @endif

                <form method="POST" action="{{ route('category.managers.update', $category) }}">
                    @csrf

                    <div class="row g-3 mb-4">
                        <div class="col-md-6">
                            <label for="managerSearch" class="form-label">{{ __('Search customers') }}</label>
                            <input type="text" id="managerSearch" class="form-control" placeholder="{{ __('Type to filter customers...') }}">
                        </div>
                        <div class="col-md-6 d-flex align-items-end justify-content-end gap-2">
                            <button type="button" id="selectAllManagers" class="btn btn-outline-secondary btn-sm">
                                <i class="bi bi-check2-all"></i> {{ __('Select all') }}
                            </button>
                            <button type="button" id="clearAllManagers" class="btn btn-outline-danger btn-sm">
                                <i class="bi bi-x-circle"></i> {{ __('Clear selection') }}
                            </button>
                        </div>
                    </div>

                    <div class="border rounded overflow-auto" style="max-height: 420px;">
                        <ul class="list-group list-group-flush" id="managersList">
                            @forelse($customers as $customer)
                                <li class="list-group-item d-flex align-items-center justify-content-between" data-filter-name="{{ \Illuminate\Support\Str::lower($customer->name . ' ' . ($customer->email ?? '')) }}">
                                    <div class="me-3">
                                        <div class="fw-semibold">{{ $customer->name }}</div>
                                        <div class="text-muted small">{{ $customer->email ?? __('No email') }}</div>
                                    </div>
                                    <div class="form-check form-switch mb-0">
                                        <input class="form-check-input" type="checkbox" id="manager-{{ $customer->id }}" name="managers[]" value="{{ $customer->id }}" @checked(in_array($customer->id, $assignedManagerIds, true))>
                                    </div>
                                </li>
                            @empty
                                <li class="list-group-item text-center text-muted py-4">
                                    {{ __('No customers available to assign.') }}
                                </li>
                            @endforelse
                        </ul>
                    </div>

                    <div class="d-flex justify-content-end mt-4">
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-save"></i> {{ __('Save changes') }}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </section>
@endsection

@push('scripts')
    <script>
        (function () {
            const searchInput = document.getElementById('managerSearch');
            const list = document.getElementById('managersList');
            const selectAllBtn = document.getElementById('selectAllManagers');
            const clearAllBtn = document.getElementById('clearAllManagers');

            if (!searchInput || !list) {
                return;
            }

            const items = Array.from(list.querySelectorAll('li[data-filter-name]'));

            searchInput.addEventListener('input', () => {
                const value = searchInput.value.trim().toLowerCase();

                items.forEach((item) => {
                    const name = item.getAttribute('data-filter-name') ?? '';
                    const matches = value === '' || name.includes(value);
                    item.classList.toggle('d-none', !matches);
                });
            });

            const toggleAll = (checked) => {
                items.forEach((item) => {
                    const checkbox = item.querySelector('input[type="checkbox"]');
                    if (checkbox && !checkbox.disabled && !item.classList.contains('d-none')) {
                        checkbox.checked = checked;
                    }
                });
            };

            selectAllBtn?.addEventListener('click', (event) => {
                event.preventDefault();
                toggleAll(true);
            });

            clearAllBtn?.addEventListener('click', (event) => {
                event.preventDefault();
                toggleAll(false);
            });
        })();
    </script>
@endpush