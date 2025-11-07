@extends('layouts.main')

@section('title')
    {{ __('رفع دفعة أكواد جديدة') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center g-2">
            <div class="col-12 col-md-6 order-md-1 order-last text-center text-md-start">
                <h4 class="mb-0">@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-center text-md-end">
                <nav aria-label="breadcrumb" class="breadcrumb-header">
                    <ol class="breadcrumb mb-0 justify-content-center justify-content-md-end">
                        <li class="breadcrumb-item"><a href="{{ route('home') }}">{{ __('لوحة التحكم') }}</a></li>
                        <li class="breadcrumb-item"><a href="{{ route('wifi.index') }}">{{ __('كبائن الواي فاي') }}</a></li>
                        <li class="breadcrumb-item active" aria-current="page">{{ __('رفع دفعة جديدة') }}</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row justify-content-center">
            <div class="col-lg-8">
                <div class="card shadow-sm border-0">
                    <div class="card-header border-0 bg-white d-flex justify-content-between align-items-center">
                        <div>
                            <h5 class="card-title mb-1">{{ __('إدخال بيانات الدفعة') }}</h5>
                            <p class="text-muted small mb-0">{{ __('استخدم نفس تنسيق الملفات المدعوم لدى المالكين (CSV / XLSX).') }}</p>
                        </div>
                        <a href="{{ route('wifi.index') }}" class="btn btn-sm btn-light">
                            <i class="bi bi-arrow-right"></i> {{ __('عودة للقائمة') }}
                        </a>
                    </div>
                    <div class="card-body">
                        <form method="post" action="{{ route('wifi.voucher-batches.store') }}" enctype="multipart/form-data" class="needs-validation" novalidate>
                            @csrf
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label for="network_id" class="form-label">{{ __('الشبكة') }}</label>
                                    <select id="network_id" class="form-select">
                                        <option value="">{{ __('اختر الشبكة') }}</option>
                                        @foreach($networks as $network)
                                            <option value="{{ $network->id }}">{{ $network->name }}</option>
                                        @endforeach
                                    </select>
                                </div>
                                <div class="col-md-6">
                                    <label for="wifi_plan_id" class="form-label">{{ __('الخطة') }}</label>
                                    <select id="wifi_plan_id" name="wifi_plan_id" class="form-select" required>
                                        <option value="">{{ __('اختر الخطة') }}</option>
                                        @foreach($plans as $plan)
                                            <option value="{{ $plan->id }}" data-network="{{ $plan->wifi_network_id }}">
                                                {{ $plan->network?->name }} — {{ $plan->name }}
                                            </option>
                                        @endforeach
                                    </select>
                                    @error('wifi_plan_id')
                                        <div class="text-danger small">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-6">
                                    <label for="label" class="form-label">{{ __('وسم الدفعة') }}</label>
                                    <input type="text" id="label" name="label" value="{{ old('label') }}" class="form-control" required maxlength="255">
                                    @error('label')
                                        <div class="text-danger small">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-3">
                                    <label for="total_codes" class="form-label">{{ __('عدد الأكواد الكلي') }}</label>
                                    <input type="number" id="total_codes" name="total_codes" value="{{ old('total_codes') }}" class="form-control" min="1" max="50000">
                                    @error('total_codes')
                                        <div class="text-danger small">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-md-3">
                                    <label for="available_codes" class="form-label">{{ __('الأكواد المتاحة فورًا') }}</label>
                                    <input type="number" id="available_codes" name="available_codes" value="{{ old('available_codes') }}" class="form-control" min="0">
                                    @error('available_codes')
                                        <div class="text-danger small">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-12">
                                    <label for="notes" class="form-label">{{ __('ملاحظات') }}</label>
                                    <textarea id="notes" name="notes" rows="3" class="form-control" placeholder="{{ __('ملاحظات إضافية حول الدفعة (اختياري).') }}">{{ old('notes') }}</textarea>
                                    @error('notes')
                                        <div class="text-danger small">{{ $message }}</div>
                                    @enderror
                                </div>
                                <div class="col-12">
                                    <label for="source_file" class="form-label">{{ __('ملف الأكواد') }}</label>
                                    <input type="file" id="source_file" name="source_file" class="form-control" accept=".csv,.txt,.xlsx" required>
                                    @error('source_file')
                                        <div class="text-danger small">{{ $message }}</div>
                                    @enderror
                                </div>
                            </div>
                            <div class="d-flex justify-content-end mt-4 gap-2">
                                <a href="{{ route('wifi.index') }}" class="btn btn-light">{{ __('إلغاء') }}</a>
                                <button type="submit" class="btn btn-primary">
                                    <i class="bi bi-upload"></i> {{ __('رفع الدفعة') }}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection

@push('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            const networkSelect = document.getElementById('network_id');
            const planSelect = document.getElementById('wifi_plan_id');
            const originalOptions = Array.from(planSelect.options);
            const initialPlan = '{{ old('wifi_plan_id') }}';

            if (initialPlan) {
                const matchedOption = originalOptions.find(option => option.value === initialPlan);
                if (matchedOption) {
                    networkSelect.value = matchedOption.dataset.network ?? '';
                }
            }

            function filterPlans() {
                const networkId = networkSelect.value;
                const currentValue = planSelect.value;

                planSelect.innerHTML = '';
                const placeholder = document.createElement('option');
                placeholder.value = '';
                placeholder.textContent = '{{ __('اختر الخطة') }}';
                planSelect.appendChild(placeholder);

                originalOptions.forEach(option => {
                    if (!option.value) {
                        return;
                    }

                    if (!networkId || option.dataset.network === networkId) {
                        planSelect.appendChild(option.cloneNode(true));
                    }
                });

                if (currentValue && planSelect.querySelector(`option[value="${currentValue}"]`)) {
                    planSelect.value = currentValue;
                }
            }

            networkSelect.addEventListener('change', filterPlans);
            filterPlans();

            if (initialPlan && planSelect.querySelector(`option[value="${initialPlan}"]`)) {
                planSelect.value = initialPlan;
            }
        });
    </script>
@endpush