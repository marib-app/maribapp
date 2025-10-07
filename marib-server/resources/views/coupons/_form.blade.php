@php
    $startsAtValue = old('starts_at');
    if (! empty($startsAtValue)) {
        $startsAtValue = \Illuminate\Support\Carbon::parse($startsAtValue)->format('Y-m-d\TH:i');
    } elseif (isset($coupon) && $coupon->starts_at) {
        $startsAtValue = $coupon->starts_at->format('Y-m-d\TH:i');
    }

    $endsAtValue = old('ends_at');
    if (! empty($endsAtValue)) {
        $endsAtValue = \Illuminate\Support\Carbon::parse($endsAtValue)->format('Y-m-d\TH:i');
    } elseif (isset($coupon) && $coupon->ends_at) {
        $endsAtValue = $coupon->ends_at->format('Y-m-d\TH:i');
    }
@endphp

<div class="row g-3">
    <div class="col-md-4">
        <label class="form-label" for="code">{{ __('رمز القسيمة') }} <span class="text-danger">*</span></label>
        <input type="text" id="code" name="code" class="form-control" value="{{ old('code', $coupon->code ?? '') }}" required>
        @error('code')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
    <div class="col-md-4">
        <label class="form-label" for="name">{{ __('اسم العرض') }} <span class="text-danger">*</span></label>
        <input type="text" id="name" name="name" class="form-control" value="{{ old('name', $coupon->name ?? '') }}" required>
        @error('name')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
    <div class="col-md-4">
        <label class="form-label" for="discount_type">{{ __('نوع الخصم') }} <span class="text-danger">*</span></label>
        <select id="discount_type" name="discount_type" class="form-select" required>
            <option value="percentage" @selected(old('discount_type', $coupon->discount_type ?? '') === 'percentage')>{{ __('نسبة مئوية') }}</option>
            <option value="fixed" @selected(old('discount_type', $coupon->discount_type ?? '') === 'fixed')>{{ __('قيمة ثابتة') }}</option>
        </select>
        @error('discount_type')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
    <div class="col-md-4">
        <label class="form-label" for="discount_value">{{ __('قيمة الخصم') }} <span class="text-danger">*</span></label>
        <input type="number" step="0.01" min="0" id="discount_value" name="discount_value" class="form-control" value="{{ old('discount_value', $coupon->discount_value ?? '') }}" required>
        @error('discount_value')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
    <div class="col-md-4">
        <label class="form-label" for="minimum_order_amount">{{ __('الحد الأدنى للطلب') }}</label>
        <input type="number" step="0.01" min="0" id="minimum_order_amount" name="minimum_order_amount" class="form-control" value="{{ old('minimum_order_amount', $coupon->minimum_order_amount ?? '') }}">
        @error('minimum_order_amount')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
    <div class="col-md-4">
        <label class="form-label" for="max_uses">{{ __('الحد الإجمالي للاستخدام') }}</label>
        <input type="number" min="1" id="max_uses" name="max_uses" class="form-control" value="{{ old('max_uses', $coupon->max_uses ?? '') }}">
        @error('max_uses')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
    <div class="col-md-4">
        <label class="form-label" for="max_uses_per_user">{{ __('حد الاستخدام لكل مستخدم') }}</label>
        <input type="number" min="1" id="max_uses_per_user" name="max_uses_per_user" class="form-control" value="{{ old('max_uses_per_user', $coupon->max_uses_per_user ?? '') }}">
        @error('max_uses_per_user')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
    <div class="col-md-4">
        <label class="form-label" for="starts_at">{{ __('تاريخ البداية') }}</label>
        <input type="datetime-local" id="starts_at" name="starts_at" class="form-control" value="{{ $startsAtValue }}">
        @error('starts_at')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
    <div class="col-md-4">
        <label class="form-label" for="ends_at">{{ __('تاريخ الانتهاء') }}</label>
        <input type="datetime-local" id="ends_at" name="ends_at" class="form-control" value="{{ $endsAtValue }}">
        @error('ends_at')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
    <div class="col-12">
        <label class="form-label" for="description">{{ __('الوصف') }}</label>
        <textarea id="description" name="description" class="form-control" rows="3">{{ old('description', $coupon->description ?? '') }}</textarea>
        @error('description')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
    <div class="col-12">
        <div class="form-check form-switch">
            <input class="form-check-input" type="checkbox" id="is_active" name="is_active" value="1" @checked(old('is_active', $coupon->is_active ?? true))>
            <label class="form-check-label" for="is_active">{{ __('القسيمة مفعّلة') }}</label>
        </div>
        @error('is_active')
            <div class="text-danger small">{{ $message }}</div>
        @enderror
    </div>
</div>