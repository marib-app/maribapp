@extends('layouts.main')

@section('title')
    {{ __('إعدادات الأقسام المميزة') }}
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
        @if ($errors->any())
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                <ul class="mb-0">
                    @foreach ($errors->all() as $validationError)
                        <li>{{ $validationError }}</li>
                    @endforeach
                </ul>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('إغلاق') }}"></button>
            </div>
        @endif

        @if (session('success'))
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                {{ session('success') }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('إغلاق') }}"></button>
            </div>
        @endif

        @if (session('flushed_keys'))
            <div class="alert alert-info alert-dismissible fade show" role="alert">
                <p class="mb-1">{{ __('تم تفريغ المفاتيح التالية:') }}</p>
                <code class="d-block text-break">{{ implode(', ', session('flushed_keys')) }}</code>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('إغلاق') }}"></button>
            </div>
        @endif

        <div class="card mb-4">
            <div class="card-header">
                <h5 class="card-title mb-0">{{ __('الإعدادات العامة') }}</h5>
            </div>
            <div class="card-body">
                <form action="{{ route('feature-section.settings.update') }}" method="POST" class="row g-3">
                    @csrf
                    @method('PUT')

                    <div class="col-md-4">
                        <label for="cache-ttl-seconds" class="form-label">{{ __('مدة التخزين في الكاش (ثواني)') }}</label>
                        <input
                            type="number"
                            min="1"
                            max="86400"
                            step="1"
                            class="form-control"
                            id="cache-ttl-seconds"
                            name="cache_ttl_seconds"
                            value="{{ old('cache_ttl_seconds', $cacheTtl) }}"
                        >
                        <small class="form-text text-muted">{{ __('القيمة الافتراضية في الملف: :value ثانية.', ['value' => $defaultTtl]) }}</small>
                    </div>

                    <div class="col-md-4">
                        <label for="section-item-limit" class="form-label">{{ __('الحد الافتراضي لعدد العناصر') }}</label>
                        <input
                            type="number"
                            min="1"
                            max="{{ \App\Services\FeaturedSectionService::MAX_SECTION_LIMIT }}"
                            step="1"
                            class="form-control"
                            id="section-item-limit"
                            name="section_item_limit"
                            value="{{ old('section_item_limit', $defaultLimit) }}"
                        >
                        <small class="form-text text-muted">{{ __('القيمة الافتراضية في الملف: :value عنصر.', ['value' => $defaultSectionLimit]) }}</small>
                    </div>

                    <div class="col-md-12">
                        <hr>
                        <h6 class="fw-bold">{{ __('ربط أنواع الأقسام بالجذور') }}</h6>
                        <p class="text-muted mb-3">
                            {{ __('يمكنك تحديد معرف الفئة أو مسار الجذر لكل نوع قسم. اترك الحقل فارغًا لاستخدام القيمة الافتراضية.') }}
                        </p>

                        <div class="table-responsive">
                            <table class="table table-bordered align-middle">
                                <thead>
                                    <tr>
                                        <th style="width: 220px;">{{ __('نوع القسم') }}</th>
                                        <th>{{ __('معرف الجذر أو اللواصق') }}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                @foreach ($identifierValues as $sectionType => $value)
                                    @php
                                        $fieldName = 'root_identifiers.' . $sectionType;
                                        $inputValue = old($fieldName, $value);
                                    @endphp
                                    <tr>
                                        <td>
                                            <span class="badge bg-primary">{{ $sectionType }}</span>
                                        </td>
                                        <td>
                                            <input
                                                type="text"
                                                class="form-control @error($fieldName) is-invalid @enderror"
                                                name="root_identifiers[{{ $sectionType }}]"
                                                value="{{ $inputValue }}"
                                                placeholder="{{ __('مثال: real_estate_services أو 12,45,87') }}"
                                            >
                                            @error($fieldName)
                                                <div class="invalid-feedback">{{ $message }}</div>
                                            @else
                                                <small class="form-text text-muted">
                                                    {{ __('القيمة الحالية: :value', ['value' => $value === '' ? __('افتراضي') : $value]) }}
                                                </small>
                                            @enderror
                                        </td>
                                    </tr>
                                @endforeach
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <div class="col-12">
                        <button type="submit" class="btn btn-primary">
                            {{ __('حفظ التغييرات') }}
                        </button>
                    </div>
                </form>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h5 class="card-title mb-0">{{ __('تفريغ الكاش') }}</h5>
            </div>
            <div class="card-body">
                <p class="text-muted">{{ __('استخدم هذا الزر لمسح جميع مفاتيح الكاش الحالية للأقسام المميزة بعد تعديل الإعدادات.') }}</p>
                <form action="{{ route('feature-section.settings.flush-cache') }}" method="POST">
                    @csrf
                    <button type="submit" class="btn btn-outline-danger">
                        <i class="bi bi-arrow-repeat me-1"></i>
                        {{ __('تفريغ الكاش') }}
                    </button>
                </form>
            </div>
        </div>
    </section>
@endsection