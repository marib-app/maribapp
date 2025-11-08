@extends('layouts.main')

@section('title')
    {{ __('إضافة سلايدر') }}
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
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <div class="card-header">
                        <h5 class="mb-0">{{ __('إنشاء سلايدر جديد') }}</h5>
                    </div>
                    <div class="card-content">
                        <div class="card-body">
                            {!! Form::open(['url' => route('slider.store'), 'files' => true, 'class' => 'create-form', 'id' => 'slider-form', 'data-pre-submit-function' => 'customValidation']) !!}
                            <div class="row mt-1">
                                <div class="form-group col-md-12 col-sm-12 mandatory">
                                    {{ Form::label('image', __('Image'), ['class' => 'col-md-12 col-sm-12 col-12 form-label']) }}
                                    {{ Form::file('image', ['class' => 'form-control', 'accept' => 'image/*', 'data-parsley-required' => 'true']) }}
                                    @if (count($errors) > 0)
                                        @foreach ($errors->all() as $error)
                                            <div class="alert alert-danger error-msg">{{ $error }}</div>
                                        @endforeach
                                    @endif
                                </div>

                                <div class="form-group col-md-12 col-sm-12 mandatory">
                                    {{ Form::label('interface_type', __('Interface Type'), ['class' => 'col-md-12 col-sm-12 col-12 form-label']) }}
                                    <select name="interface_type" class="form-select" required>
                                        @foreach($interfaceTypeOptions as $type)
                                            <option value="{{ $type }}" @selected($type === $defaultInterfaceType)>{{ $interfaceTypeLabels[$type] ?? $type }}</option>
                                        @endforeach
                                    </select>
                                    <small class="text-muted">{{ __('حدد القسم الذي سيظهر فيه هذا السلايدر') }}</small>
                                </div>

                                <div class="form-group col-md-6">
                                    {{ Form::label('status', __('الحالة'), ['class' => 'col-form-label']) }}
                                    <select name="status" id="status" class="form-select" required>
                                        @foreach($sliderStatuses as $status)
                                            <option value="{{ $status }}">{{ $sliderStatusLabels[$status] ?? __(ucwords(str_replace('_', ' ', $status))) }}</option>
                                        @endforeach
                                    </select>
                                </div>

                                <div class="form-group col-md-3">
                                    {{ Form::label('priority', __('الأولوية'), ['class' => 'col-form-label']) }}
                                    {{ Form::number('priority', 0, ['class' => 'form-control', 'min' => 0]) }}
                                </div>

                                <div class="form-group col-md-3">
                                    {{ Form::label('weight', __('الوزن'), ['class' => 'col-form-label']) }}
                                    {{ Form::number('weight', 1, ['class' => 'form-control', 'min' => 1]) }}
                                </div>

                                <div class="form-group col-md-6">
                                    {{ Form::label('share_of_voice', __('حصة الظهور (%)'), ['class' => 'col-form-label']) }}
                                    {{ Form::number('share_of_voice', 0, ['class' => 'form-control', 'min' => 0, 'max' => 100, 'step' => '0.01']) }}
                                    <small class="text-muted">{{ __('حدد نسبة الظهور المستهدفة، واتركها صفرًا لتستخدم الوزن.') }}</small>
                                </div>

                                <div class="form-group col-md-6">
                                    {{ Form::label('dayparting_json', __('التقسيم الزمني (JSON)'), ['class' => 'col-form-label']) }}
                                    {{ Form::textarea('dayparting_json', '', ['class' => 'form-control', 'rows' => 3, 'placeholder' => '{"monday": [{"start": "08:00", "end": "18:00"}]}']) }}
                                    <small class="text-muted">{{ __('استخدم صيغة JSON لتحديد أوقات العرض لكل يوم.') }}</small>
                                </div>

                                <div class="form-group col-md-6">
                                    {{ Form::label('starts_at', __('تاريخ البدء'), ['class' => 'col-form-label']) }}
                                    {{ Form::input('datetime-local', 'starts_at', '', ['class' => 'form-control']) }}
                                </div>

                                <div class="form-group col-md-6">
                                    {{ Form::label('ends_at', __('تاريخ الانتهاء'), ['class' => 'col-form-label']) }}
                                    {{ Form::input('datetime-local', 'ends_at', '', ['class' => 'form-control']) }}
                                </div>

                                <div class="form-group col-md-6">
                                    {{ Form::label('per_user_per_day_limit', __('حد الظهور للمستخدم في اليوم'), ['class' => 'col-form-label']) }}
                                    {{ Form::number('per_user_per_day_limit', '', ['class' => 'form-control', 'min' => 1, 'placeholder' => __('غير محدود')]) }}
                                </div>

                                <div class="form-group col-md-6">
                                    {{ Form::label('per_user_per_session_limit', __('حد الظهور في الجلسة'), ['class' => 'col-form-label']) }}
                                    {{ Form::number('per_user_per_session_limit', '', ['class' => 'form-control', 'min' => 1, 'placeholder' => __('غير محدود')]) }}
                                </div>

                                <div class="form-group col-md-12">
                                    {{ Form::label('target_type', __('نوع الوجهة'), ['class' => 'form-label']) }}
                                    <select name="target_type" id="target_type" class="form-select">
                                        <option value="none">{{ __('بدون توجيه محدد') }}</option>
                                        @foreach($targetTypeOptions as $type)
                                            <option value="{{ $type }}">{{ $targetTypeLabels[$type] ?? $type }}</option>
                                        @endforeach
                                    </select>
                                    <small class="text-muted">{{ __('اختر الوجهة التي سيفتحها السلايدر عند النقر.') }}</small>
                                </div>
                                {{ Form::hidden('target_id', '', ['id' => 'slider_target_id']) }}

                                <div class="col-md-12 target-option" data-target-option="item" style="display: none;">
                                    <div class="form-group">
                                        <label for="target_item_id" class="form-label">{{ __('Item') }}</label>
                                        <select name="target_item_id" class="form-select select2" id="target_item_id" data-target-input>
                                            <option value="">{{ __('Select Item') }}</option>
                                            @foreach ($items as $row)
                                                <option value="{{ $row->id }}">{{ $row->name }}</option>
                                            @endforeach
                                        </select>
                                        <small class="text-muted">{{ __('سيتم توجيه المستخدم إلى تفاصيل المنتج المحدد.') }}</small>
                                    </div>
                                </div>

                                <div class="col-md-12 target-option" data-target-option="category" style="display: none;">
                                    <div class="form-group">
                                        <label for="target_category_id" class="form-label">{{ __('Category') }}</label>
                                        <select name="target_category_id" id="target_category_id" class="form-select" data-target-input>
                                            <option value="">{{ __('Select a Category') }}</option>
                                            @include('category.dropdowntree', ['categories' => $categories])
                                        </select>
                                        <small class="text-muted">{{ __('يعيد المستخدم إلى قائمة العناصر ضمن الفئة المختارة.') }}</small>
                                    </div>
                                </div>

                                <div class="col-md-12 target-option" data-target-option="blog" style="display: none;">
                                    <div class="form-group">
                                        <label for="target_blog_id" class="form-label">{{ __('صفحة') }}</label>
                                        <select name="target_blog_id" id="target_blog_id" class="form-select" data-target-input>
                                            <option value="">{{ __('اختر صفحة') }}</option>
                                            @foreach ($blogs as $blog)
                                                <option value="{{ $blog->id }}">{{ $blog->title }}</option>
                                            @endforeach
                                        </select>
                                        <small class="text-muted">{{ __('يمكنك توجيه المستخدم إلى صفحة ثابتة داخل التطبيق.') }}</small>
                                    </div>
                                </div>

                                <div class="col-md-12 target-option" data-target-option="user" style="display: none;">
                                    <div class="form-group">
                                        <label for="target_user_id" class="form-label">{{ __('مستخدم') }}</label>
                                        <select name="target_user_id" id="target_user_id" class="form-select select2" data-target-input>
                                            <option value="">{{ __('اختر مستخدمًا') }}</option>
                                            @foreach ($users as $user)
                                                <option value="{{ $user->id }}">{{ $user->name }}</option>
                                            @endforeach
                                        </select>
                                        <small class="text-muted">{{ __('يفتح ملف المستخدم الشخصي أو يبدأ الدردشة عند اختيار إجراء مناسب.') }}</small>
                                    </div>
                                </div>

                                <div class="col-md-12 target-option" data-target-option="service" style="display: none;">
                                    <div class="form-group">
                                        <label for="target_service_id" class="form-label">{{ __('خدمة') }}</label>
                                        <select name="target_service_id" id="target_service_id" class="form-select select2" data-target-input>
                                            <option value="">{{ __('اختر خدمة') }}</option>
                                            @foreach ($services as $service)
                                                <option value="{{ $service->id }}">{{ $service->name }}</option>
                                            @endforeach
                                        </select>
                                        <small class="text-muted">{{ __('يعرض تفاصيل الخدمة المحددة في التطبيق.') }}</small>
                                    </div>
                                </div>

                                <div class="form-group col-md-12 mt-3">
                                    {{ Form::label('action_type', __('نوع الإجراء'), ['class' => 'form-label']) }}
                                    <select name="action_type" id="action_type" class="form-select">
                                    <option value="none">{{ __('بدون إجراء إضافي') }}</option>
                                        @foreach($actionTypeOptions as $action)
                                            <option value="{{ $action }}">{{ $actionTypeLabels[$action] ?? $action }}</option>
                                        @endforeach
                                    </select>
                                    <small class="text-muted">{{ __('يمكنك اختيار إجراء سريع يتم تنفيذه مباشرة بعد تفاعل المستخدم.') }}</small>
                                </div>

                                <div class="col-md-12 action-option" data-action-option="open_chat" style="display: none;">
                                    <div class="form-group">
                                        <label for="action_chat_user_id" class="form-label">{{ __('اختر المستخدم للدردشة') }}</label>
                                        <select name="action_chat_user_id" id="action_chat_user_id" class="form-select select2">
                                            <option value="">{{ __('اختر مستخدمًا') }}</option>
                                            @foreach ($users as $user)
                                                <option value="{{ $user->id }}">{{ $user->name }}</option>
                                            @endforeach
                                        </select>
                                        <small class="text-muted">{{ __('إذا لم يتم اختيار مستخدم هنا فسيتم استخدام الوجهة المحددة من نوع المستخدم.') }}</small>
                                    </div>
                                </div>

                                <div class="col-md-12 action-option" data-action-option="apply_coupon" style="display: none;">
                                    <div class="row g-2">
                                        <div class="form-group col-md-6">
                                            {{ Form::label('action_coupon_code', __('رمز الكوبون'), ['class' => 'form-label']) }}
                                            {{ Form::text('action_coupon_code', '', ['class' => 'form-control', 'id' => 'action_coupon_code', 'placeholder' => __('مثال: SAVE10')]) }}
                                        </div>
                                        <div class="form-group col-md-6">
                                            {{ Form::label('action_coupon_label', __('عنوان مختصر'), ['class' => 'form-label']) }}
                                            {{ Form::text('action_coupon_label', '', ['class' => 'form-control', 'id' => 'action_coupon_label', 'placeholder' => __('نص يظهر للمستخدم')]) }}
                                        </div>
                                        <div class="form-group col-md-12">
                                            {{ Form::label('action_coupon_description', __('وصف إضافي'), ['class' => 'form-label']) }}
                                            {{ Form::textarea('action_coupon_description', '', ['class' => 'form-control', 'rows' => 2, 'id' => 'action_coupon_description', 'placeholder' => __('تفاصيل اختيارية عن الكوبون')]) }}
                                        </div>
                                    </div>
                                </div>

                                <div class="col-md-12 action-option" data-action-option="open_link" style="display: none;">
                                    <div class="form-group">
                                        {{ Form::label('action_link_url', __('الرابط الخارجي'), ['class' => 'form-label']) }}
                                        {{ Form::text('action_link_url', '', ['class' => 'form-control', 'id' => 'action_link_url', 'placeholder' => __('https://example.com')]) }}
                                        <small class="text-muted">{{ __('سيتم فتح هذا الرابط عند النقر على السلايدر.') }}</small>
                                    </div>
                                    <div class="form-group mt-2">
                                        {{ Form::label('action_link_title', __('عنوان للرابط (اختياري)'), ['class' => 'form-label']) }}
                                        {{ Form::text('action_link_title', '', ['class' => 'form-control', 'id' => 'action_link_title', 'placeholder' => __('نص يظهر للمستخدم')]) }}
                                    </div>
                                </div>

                                <div class="form-group col-md-12 mt-3">
                                    {{ Form::label('link', __('رابط خارجي بسيط (اختياري)'), ['class' => 'form-label']) }}
                                    {{ Form::text('link', '', [
                                        'class' => 'form-control',
                                        'placeholder' => __('https://example.com'),
                                        'id' => 'link',
                                        'data-parsley-errors-messages-disabled'
                                    ]) }}
                                    <small class="text-muted">{{ __('يمكن استخدام هذا الرابط كوجهة مباشرة في حال عدم اختيار هدف أو إجراء.') }}</small>
                                </div>

                                <div class="invalid-form-error-message"></div>
                                <div class="col-12 d-flex justify-content-end mt-2" style="padding: 1% 2%;">
                                    {{ Form::submit(__('Save'), ['class' => 'btn btn-primary me-1 mb-1']) }}
                                </div>
                            </div>
                            {!! Form::close() !!}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection

@section('script')
<script>
    const sliderDefaultInterfaceType = @json($defaultInterfaceType);
    window.sliderDefaultInterfaceType = sliderDefaultInterfaceType;

    const sliderTargetContainers = $('.target-option');
    const sliderActionContainers = $('.action-option');
    const sliderTargetHiddenInput = $('#slider_target_id');

    function updateSliderTargetId() {
        const selectedType = $('#target_type').val();
        let value = '';

        if (selectedType && selectedType !== 'none') {
            const active = sliderTargetContainers.filter('[data-target-option="' + selectedType + '"]');

            if (active.length) {
                const input = active.find('[data-target-input]').first();
                if (input.length) {
                    value = input.val() || '';
                }
            }
        }

        sliderTargetHiddenInput.val(value);
    }

    window.updateSliderTargetId = updateSliderTargetId;

    function toggleSliderTargetOptions() {
        const selectedType = $('#target_type').val();

        sliderTargetContainers.each(function () {
            const container = $(this);
            const type = container.data('target-option');
            const inputs = container.find('[data-target-input]');

            if (selectedType === type) {
                container.show();
                inputs.prop('disabled', false);
            } else {
                container.hide();
                inputs.each(function () {
                    const input = $(this);
                    if (input.is('select')) {
                        input.val('').trigger('change');
                    } else {
                        input.val('');
                    }
                    input.prop('disabled', true);
                });
            }
        });

        updateSliderTargetId();
    }

    function toggleSliderActionOptions() {
        const selectedAction = $('#action_type').val();

        sliderActionContainers.each(function () {
            const container = $(this);
            const type = container.data('action-option');
            const inputs = container.find('input, select, textarea');

            if (selectedAction === type) {
                container.show();
                inputs.prop('disabled', false);
            } else {
                container.hide();
                inputs.each(function () {
                    const input = $(this);
                    if (input.is('select')) {
                        input.val('').trigger('change');
                    } else {
                        input.val('');
                    }
                    input.prop('disabled', true);
                });
            }
        });

        if (selectedAction === 'open_link') {
            const linkField = $('#action_link_url');
            if (linkField.length && !linkField.val()) {
                linkField.val($('#link').val());
            }
        }
    }

    $(document).ready(function () {
        $('#target_type').on('change', toggleSliderTargetOptions);
        $(document).on('change', '[data-target-input]', updateSliderTargetId);
        $('#action_type').on('change', toggleSliderActionOptions);

        toggleSliderTargetOptions();
        toggleSliderActionOptions();

        $('#link').on('change', function () {
            if ($('#action_type').val() === 'open_link') {
                const actionLink = $('#action_link_url');
                if (actionLink.length && !actionLink.val()) {
                    actionLink.val($(this).val());
                }
            }
        });
    });
</script>
@endsection
