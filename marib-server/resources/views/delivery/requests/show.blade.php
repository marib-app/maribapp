@extends('layouts.main')

@section('title', __('طلب توصيل #:id', ['id' => $deliveryRequest->id]))

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-subtitle text-muted">
                    {{ __('تفاصيل الطلب الجاهز للتوصيل ومتابعة حالته.') }}
                </p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-md-end">
                <a href="{{ route('delivery.requests.index') }}" class="btn btn-outline-secondary">
                    <i class="bi bi-arrow-left"></i> {{ __('العودة للقائمة') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-12 col-lg-7 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('بيانات الطلب') }}</h6>
                    </div>
                    <div class="card-body">
                        <dl class="row mb-0">
                            <dt class="col-sm-4">{{ __('رقم الطلب') }}</dt>
                            <dd class="col-sm-8">#{{ $deliveryRequest->order?->order_number ?? $deliveryRequest->order_id }}</dd>

                            <dt class="col-sm-4">{{ __('القيمة') }}</dt>
                            <dd class="col-sm-8">{{ number_format($deliveryRequest->order?->final_amount ?? 0, 2) }} {{ __('ر.ي') }}</dd>

                            <dt class="col-sm-4">{{ __('الحالة الحالية') }}</dt>
                            <dd class="col-sm-8">
                                <span class="badge bg-primary">{{ __($deliveryRequest->status) }}</span>
                            </dd>

                            <dt class="col-sm-4">{{ __('المصدر') }}</dt>
                            <dd class="col-sm-8">{{ $deliveryRequest->source ?? __('غير محدد') }}</dd>

                            <dt class="col-sm-4">{{ __('ملاحظات') }}</dt>
                            <dd class="col-sm-8">{{ $deliveryRequest->notes ?? __('لا يوجد') }}</dd>
                        </dl>
                    </div>
                </div>
            </div>

            <div class="col-12 mb-3">
                <div class="card">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h6 class="mb-0">{{ __('تفاصيل الطلب الكامل') }}</h6>
                    </div>
                    <div class="card-body">
                        @if ($deliveryRequest->order && $deliveryRequest->order->items?->isNotEmpty())
                            <div class="table-responsive">
                                <table class="table table-sm">
                                    <thead>
                                        <tr>
                                            <th>{{ __('المنتج') }}</th>
                                            <th>{{ __('الكمية') }}</th>
                                            <th>{{ __('السعر') }}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        @foreach ($deliveryRequest->order->items as $item)
                                            <tr>
                                                <td>{{ $item->item_name }}</td>
                                                <td>{{ $item->quantity }}</td>
                                                <td>{{ number_format($item->subtotal ?? 0, 2) }} {{ __('ر.ي') }}</td>
                                            </tr>
                                        @endforeach
                                    </tbody>
                                </table>
                            </div>
                        @else
                            <p class="text-muted mb-0">{{ __('لا تتوفر عناصر مرتبطة بالطلب.') }}</p>
                        @endif
                    </div>
                </div>
            </div>

            <div class="col-12 col-lg-6 mb-3">

            <div class="col-12 col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('تحديث الحالة') }}</h6>
                    </div>
                    <div class="card-body">
                        <form method="post" action="{{ route('delivery.requests.update', $deliveryRequest) }}">
                            @csrf
                            @method('patch')

                            <div class="mb-3">
                                <label class="form-label">{{ __('الحالة') }}</label>
                                <select name="status" class="form-select">
                                    @foreach ($statuses as $key => $label)
                                        <option value="{{ $key }}" @selected($deliveryRequest->status === $key)>{{ $label }}</option>
                                    @endforeach
                                </select>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">{{ __('المكلف بالتوصيل') }}</label>
                                <select name="assigned_to" class="form-select">
                                    <option value="">{{ __('غير معيّن') }}</option>
                                    @foreach ($availableAgents as $agent)
                                        <option value="{{ $agent->id }}" @selected($deliveryRequest->assigned_to === $agent->id)>
                                            {{ $agent->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">{{ __('ملاحظات') }}</label>
                                <textarea name="notes" rows="3" class="form-control">{{ old('notes', $deliveryRequest->notes) }}</textarea>
                            </div>

                            <button type="submit" class="btn btn-primary w-100">
                                {{ __('حفظ التحديثات') }}
                            </button>
                        </form>
                    </div>
                </div>
            </div>
            <div class="col-12 col-lg-6 mb-3">
                <div class="card">
                    <div class="card-header">
                        <h6 class="mb-0">{{ __('إرسال إشعار لمندوب داخلي') }}</h6>
                    </div>
                    <div class="card-body">
                        <form method="post" action="{{ route('delivery.requests.notify', $deliveryRequest) }}">
                            @csrf
                            <div class="mb-3">
                                <label class="form-label">{{ __('المندوب') }}</label>
                                @if ($availableAgents->isEmpty())
                                    <div class="alert alert-warning mb-0">
                                        {{ __('لا يوجد مندوبون مضافون. يرجى إضافة من خلال "مندوبو التوصيل".') }}
                                    </div>
                                @else
                                    <select name="agent_id" class="form-select">
                                        @foreach ($availableAgents as $agent)
                                            <option value="{{ $agent->id }}">{{ $agent->name }}</option>
                                        @endforeach
                                    </select>
                                @endif
                            </div>
                            <div class="mb-3">
                                <label class="form-label">{{ __('رسالة مخصصة') }}</label>
                                <textarea name="message" rows="3" class="form-control" placeholder="{{ __('رسالة تظهر للمندوب داخل التطبيق') }}"></textarea>
                            </div>
                            <button type="submit" class="btn btn-outline-primary w-100" {{ $availableAgents->isEmpty() ? 'disabled' : '' }}>
                                {{ __('إرسال الإشعار') }}
                            </button>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection
