@extends('layouts.main')

@section('title')
    {{ $pageTitle }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>{{ $pageTitle }}</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first"></div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-body">
                @if(session('success'))
                    <div class="alert alert-success" role="alert">
                        {{ session('success') }}
                    </div>
                @endif

                @if($errors->any())
                    <div class="alert alert-danger" role="alert">
                        <ul class="mb-0">
                            <li>{{ $errors->first() }}</li>
                        </ul>
                    </div>
                @endif

                <form method="GET" action="{{ route('item.computer.delegates') }}" class="row g-3 align-items-end mb-4">
                    <div class="col-lg-6 col-md-7">
                        <label for="search" class="form-label">{{ __('البحث عن المستخدمين') }}</label>
                        <input type="text" id="search" name="search" value="{{ $search }}" class="form-control"
                               placeholder="{{ __('ابحث بالاسم أو المعرف أو الهاتف') }}">
                    </div>
                    <div class="col-lg-3 col-md-3">
                        <button type="submit" class="btn btn-primary w-100">{{ __('بحث') }}</button>
                    </div>
                    <div class="col-lg-3 col-md-2">
                        <a href="{{ route('item.computer.delegates') }}" class="btn btn-outline-secondary w-100">{{ __('إعادة تعيين') }}</a>
                    </div>
                </form>

                <form method="POST" action="{{ route('item.computer.delegates.update') }}" {{ $canUpdate ? "onsubmit=\"return confirm('" . __('هل أنت متأكد من حفظ التغييرات؟') . "');\"" : 'onsubmit="return false;"' }}>
                    @csrf
                    <div class="row g-3">
                        @forelse($users as $user)
                            <div class="col-12">
                                <div class="card border {{ in_array($user->id, $delegateIds, true) ? 'border-success' : 'border-light' }} shadow-sm">
                                    <div class="card-body d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center">
                                        <div class="mb-3 mb-md-0">
                                            <h5 class="mb-1 d-flex flex-wrap align-items-center gap-2">
                                                <span>{{ $user->name }}</span>
                                                <span class="text-muted fs-6">
                                                    @if(!empty($user->mobile))
                                                        ({{ $user->mobile }})
                                                    @else
                                                        (#{{ $user->id }})
                                                    @endif
                                                </span>
                                            </h5>
                                            <p class="mb-1 text-muted">{{ __('المعرف:') }} #{{ $user->id }}</p>
                                            @if(!empty($user->mobile))
                                                <p class="mb-0 text-muted">{{ __('الهاتف:') }} {{ $user->mobile }}</p>
                                            @else
                                                <p class="mb-0 text-muted">{{ __('لا يوجد رقم هاتف مسجل.') }}</p>
                                            @endif
                                        </div>
                                        <div class="form-check form-switch">
                                            <input class="form-check-input" type="checkbox" id="delegate-{{ $user->id }}" name="delegates[]"
                                                   value="{{ $user->id }}" {{ in_array($user->id, $delegateIds, true) ? 'checked' : '' }} {{ $canUpdate ? '' : 'disabled' }}>
                                            <label class="form-check-label" for="delegate-{{ $user->id }}">
                                                {{ __('تعيين كمندوب') }}
                                            </label>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        @empty
                            <div class="col-12">
                                <div class="alert alert-light border text-center mb-0" role="alert">
                                    {{ __('لا توجد نتائج مطابقة لبحثك في الوقت الحالي.') }}
                                </div>
                            </div>
                        @endforelse
                    </div>

                    @if($canUpdate)
                        <div class="mt-4 d-flex justify-content-end">
                            <button type="submit" class="btn btn-success">
                                <i class="bi bi-check-circle me-2"></i> {{ __('حفظ التغييرات') }}
                            </button>
                        </div>
                    @else
                        <div class="mt-4 alert alert-info mb-0" role="alert">
                            {{ __('ليس لديك صلاحية لتعديل قائمة المندوبين.') }}
                        </div>
                    @endif
                </form>
            </div>
        </div>
    </section>
@endsection
