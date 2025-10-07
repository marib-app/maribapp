@extends('layouts.main')

@section('title')
    {{ __('إضافة صورة افتراضية للسلايدر') }}
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
        <div class="row justify-content-center">
            <div class="col-lg-6 col-md-8">
                <div class="card">
                    <div class="card-header">
                        <h5 class="mb-0">{{ __('إضافة صورة افتراضية للسلايدر') }}</h5>
                    </div>
                    <div class="card-body">
                        <form action="{{ route('slider.defaults.store') }}" method="POST" enctype="multipart/form-data">
                            @csrf

                            <div class="mb-3">
                                <label for="interface_type" class="form-label">{{ __('نوع الواجهة') }}</label>
                                <select id="interface_type" name="interface_type" class="form-select @error('interface_type') is-invalid @enderror" required>
                                    @foreach($interfaceTypeOptions as $interfaceType)
                                        <option value="{{ $interfaceType }}" {{ old('interface_type') === $interfaceType ? 'selected' : '' }}>
                                            {{ $interfaceTypeLabels[$interfaceType] ?? $interfaceType }}
                                        </option>
                                    @endforeach
                                </select>
                                @error('interface_type')
                                    <div class="invalid-feedback">{{ $message }}</div>
                                @enderror
                            </div>

                            <div class="mb-3">
                                <label for="image" class="form-label">{{ __('الصورة') }}</label>
                                <input type="file" id="image" name="image" class="form-control @error('image') is-invalid @enderror" accept="image/*" required>
                                @error('image')
                                    <div class="invalid-feedback">{{ $message }}</div>
                                @enderror
                            </div>

                            <div class="d-flex justify-content-between align-items-center">
                                <a href="{{ route('slider.index') }}" class="btn btn-outline-secondary">{{ __('رجوع') }}</a>
                                <button type="submit" class="btn btn-primary">{{ __('حفظ') }}</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection