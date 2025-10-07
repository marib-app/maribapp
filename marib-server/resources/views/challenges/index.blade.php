@extends('layouts.main')

@section('title')
    {{ __('المسابقات') }}
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
        @can('challenge-create')
            <div class="col-md-4">
                <div class="card">
                    <div class="card-body">
                        {!! Form::open(['route' => 'challenges.store', 'method' => 'POST', 'data-parsley-validate', 'class'=>'create-form', 'id' => 'challenge-create-form']) !!}
                        <div class="row">
                            <div class="col-md-12 col-12 form-group mandatory">
                                {{ Form::label('title', __('العنوان'), ['class' => 'form-label']) }}
                                {{ Form::text('title', '', [
                                    'class' => 'form-control',
                                    'placeholder' => __('أدخل عنوان المسابقة'),
                                    'data-parsley-required' => 'true',
                                ]) }}
                            </div>

                            <div class="col-md-12 col-12 form-group mandatory">
                                {{ Form::label('description', __('الوصف'), ['class' => 'form-label']) }}
                                {{ Form::textarea('description', '', [
                                    'class' => 'form-control',
                                    'rows' => '3',
                                    'placeholder' => __('أدخل وصف المسابقة'),
                                    'data-parsley-required' => 'true',
                                    'id' => 'description'
                                ]) }}
                            </div>

                            <div class="col-md-6 col-12 form-group mandatory">
                                {{ Form::label('required_referrals', __('الإحالات المطلوبة'), ['class' => 'form-label']) }}
                                {{ Form::number('required_referrals', '', [
                                    'class' => 'form-control',
                                    'min' => '1',
                                    'data-parsley-required' => 'true',
                                ]) }}
                            </div>

                            <div class="col-md-6 col-12 form-group mandatory">
                                {{ Form::label('points_per_referral', __('النقاط لكل إحالة'), ['class' => 'form-label']) }}
                                {{ Form::number('points_per_referral', '10', [
                                    'class' => 'form-control',
                                    'min' => '0',
                                    'data-parsley-required' => 'true',
                                ]) }}
                            </div>

                            <div class="col-md-12 col-12 form-group">
                                <div class="form-check form-switch">
                                    {{ Form::checkbox('is_active', '1', true, ['class' => 'form-check-input', 'id' => 'is_active']) }}
                                    {{ Form::label('is_active', __('تفعيل المسابقة'), ['class' => 'form-check-label']) }}
                                </div>
                            </div>



                            <div class="col-12 text-end form-group">
                                {{ Form::submit(__('إضافة المسابقة'), ['class' => 'btn btn-primary']) }}
                            </div>
                        </div>
                        {!! Form::close() !!}
                    </div>
                </div>
            </div>
        @endcan

        <div class="{{Illuminate\Support\Facades\Auth::user()->can('challenge-create') ? 'col-md-8' : 'col-md-12' }}">
                <div class="card">
                    <div class="card-body">
                        <div class="row">
                            <div class="col-12">
                                <table class="table table-borderless table-striped" aria-describedby="mydesc"
                                       id="table_list" data-toggle="table" data-url="{{ route('challenges.list') }}"
                                       data-click-to-select="true" data-side-pagination="server" data-pagination="true"
                                       data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true"
                                       data-show-columns="true" data-show-refresh="true"
                                       data-fixed-columns="true" data-fixed-number="1"
                                       data-trim-on-search="false" data-mobile-responsive="true"
                                       data-sort-name="id" data-sort-order="desc"
                                       data-pagination-successively-size="3" data-query-params="queryParams">
                                    <thead>
                                    <tr>
                                        <th scope="col" data-field="id" data-sortable="true">{{ __('ID') }}</th>
                                        <th scope="col" data-field="title" data-sortable="true">{{ __('العنوان') }}</th>
                                        <th scope="col" data-field="description" data-sortable="true">{{ __('الوصف') }}</th>
                                        <th scope="col" data-field="required_referrals" data-sortable="true">{{ __('الإحالات المطلوبة') }}</th>
                                        <th scope="col" data-field="points_per_referral" data-sortable="true">{{ __('النقاط لكل إحالة') }}</th>
                                        <th scope="col" data-field="is_active" data-sortable="true" data-formatter="statusFormatter">{{ __('الحالة') }}</th>
                                        <th scope="col" data-field="updated_at" data-sortable="true" data-formatter="dateFormatter">{{ __('تاريخ التحديث') }}</th>
                                        @can('challenge-edit')
                                            <th scope="col" data-field="operate" data-events="challengeEvents"
                                                data-formatter="operateFormatter" data-escape="false">{{ __('الإجراءات') }}</th>
                                        @endcan
                                    </tr>
                                    </thead>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
    </div>
</section>

@endsection

<!-- Modal for Edit Challenge -->
<div class="modal fade" id="editChallengeModal" tabindex="-1" aria-labelledby="editChallengeModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="editChallengeModalLabel">{{ __('تعديل المسابقة') }}</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                {!! Form::open(['route' => ['challenges.update', ''], 'method' => 'PUT', 'data-parsley-validate', 'class'=>'edit-form', 'id' => 'edit-challenge-form']) !!}
                {{ Form::hidden('id', '', ['id' => 'edit_id']) }}
                <div class="row">
                    <div class="col-md-12 col-12 form-group mandatory">
                        {{ Form::label('edit_title', __('العنوان'), ['class' => 'form-label']) }}
                        {{ Form::text('title', '', [
                            'class' => 'form-control',
                            'placeholder' => __('أدخل عنوان المسابقة'),
                            'data-parsley-required' => 'true',
                            'id' => 'edit_title',
                        ]) }}
                    </div>

                    <div class="col-md-12 col-12 form-group mandatory">
                        {{ Form::label('edit_description', __('الوصف'), ['class' => 'form-label']) }}
                        {{ Form::textarea('description', '', [
                            'class' => 'form-control',
                            'rows' => '3',
                            'placeholder' => __('أدخل وصف المسابقة'),
                            'data-parsley-required' => 'true',
                            'id' => 'edit_description'
                        ]) }}
                    </div>

                    <div class="col-md-6 col-12 form-group mandatory">
                        {{ Form::label('edit_required_referrals', __('الإحالات المطلوبة'), ['class' => 'form-label']) }}
                        {{ Form::number('required_referrals', '', [
                            'class' => 'form-control',
                            'min' => '1',
                            'data-parsley-required' => 'true',
                            'id' => 'edit_required_referrals',
                        ]) }}
                    </div>

                    <div class="col-md-6 col-12 form-group mandatory">
                        {{ Form::label('edit_points_per_referral', __('النقاط لكل إحالة'), ['class' => 'form-label']) }}
                        {{ Form::number('points_per_referral', '', [
                            'class' => 'form-control',
                            'min' => '0',
                            'data-parsley-required' => 'true',
                            'id' => 'edit_points_per_referral',
                        ]) }}
                    </div>



                    <div class="col-md-12 col-12 form-group">
                        <div class="form-check form-switch">
                            {{ Form::checkbox('is_active', '1', false, ['class' => 'form-check-input', 'id' => 'edit_is_active']) }}
                            {{ Form::label('edit_is_active', __('تفعيل المسابقة'), ['class' => 'form-check-label']) }}
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">{{ __('إلغاء') }}</button>
                    {{ Form::submit(__('حفظ التغييرات'), ['class' => 'btn btn-primary']) }}
                </div>
                {!! Form::close() !!}
            </div>
        </div>
    </div>
</div>

@section('script')
<script src="https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.29.4/moment.min.js"></script>
<!-- إضافة DOCTYPE لضمان وضع المعايير لـ TinyMCE -->
<script type="text/javascript">
    function dateFormatter(value, row, index) {
        if (value) {
            return moment(value).format('YYYY-MM-DD HH:mm');
        } else {
            return '-';
        }
    }
    
    function statusFormatter(value, row, index) {
        if (value == 1) {
            return '<span class="badge bg-success">{{ __('مفعلة') }}</span>';
        } else {
            return '<span class="badge bg-danger">{{ __('غير مفعلة') }}</span>';
        }
    }

    function operateFormatter(value, row, index) {
        return [
            '<a class="edit-challenge btn btn-sm btn-primary" href="javascript:void(0)" title="{{ __('تعديل') }}">', 
            '<i class="bi bi-pencil-square"></i> {{ __('تعديل') }}',
            '</a> ',
      
        ].join('');
    }

    window.challengeEvents = {
        'click .edit-challenge': function (e, value, row, index) {
            if (!e || !e.target) return; // التحقق من وجود الهدف قبل محاولة الوصول إليه
            const id = row.id;
            $.ajax({
                url: "{{ url('challenges') }}/" + id + "/edit",
                method: 'GET',
                success: function(response) {
                    $('#edit_id').val(response.id);
                    $('#edit_title').val(response.title);
                    $('#edit_description').val(response.description);
                    $('#edit_required_referrals').val(response.required_referrals);
                    $('#edit_points_per_referral').val(response.points_per_referral);
                    $('#edit_is_active').prop('checked', response.is_active == 1);
                    $('#editChallengeModal').modal('show');
                },
                error: function(xhr) {
                    toastr.error('حدث خطأ أثناء تحميل بيانات المسابقة');
                }
            });
        },
        'click .delete-challenge': function (e, value, row, index) {
            const id = row.id;
            if (confirm('هل أنت متأكد من حذف هذه المسابقة؟')) {
                $.ajax({
                    url: "{{ url('challenges') }}/" + id,
                    method: 'DELETE',
                    data: {
                        _token: '{{ csrf_token() }}'
                    },
                    success: function(response) {
                        $('#table_list').bootstrapTable('refresh');
                        toastr.success('تم حذف المسابقة بنجاح');
                    },
                    error: function(xhr) {
                        toastr.error('حدث خطأ أثناء حذف المسابقة');
                    }
                });
            }
        }
    };

    $(function () {
        // التحقق من وجود العناصر قبل استخدامها
        if ($('#table_list').length) {
            $('#table_list').bootstrapTable();
        }

     $('#challenge-create-form').off('submit').on('submit', function(e) {
            e.preventDefault();
            var submitBtn = $(this).find('button[type="submit"]');
            submitBtn.prop('disabled', true);
            
            // Use a hardcoded URL to avoid any routing issues
            $.ajax({
               url: '{{ route("challenges.store") }}',
                method: 'POST',
                data: $(this).serialize(),
                success: function(response) {
                    $('.create-form')[0].reset();
                    if ($('#table_list').length) {
                        $('#table_list').bootstrapTable('refresh');
                    }
                    toastr.success('تمت إضافة المسابقة بنجاح');
                },
                error: function(xhr) {
                    toastr.error('حدث خطأ أثناء إضافة المسابقة');
                }
            });
        });

        $('.edit-form').on('submit', function(e) {
            e.preventDefault();
            const id = $('#edit_id').val();
            // تحديث مسار النموذج ديناميكيًا بمعرف المسابقة
            if ($('#edit-challenge-form').length) {
                $('#edit-challenge-form').attr('action', '{{ url("challenges") }}/' + id);
            }
            $.ajax({
                url: $(this).attr('action'),
                method: 'PUT',
                data: $(this).serialize(),
                success: function(response) {
                    if ($('#editChallengeModal').length) {
                        $('#editChallengeModal').modal('hide');
                    }
                    if ($('#table_list').length) {
                        $('#table_list').bootstrapTable('refresh');
                    }
                    toastr.success('تم تحديث المسابقة بنجاح');
                },
                error: function(xhr) {
                    toastr.error('حدث خطأ أثناء تحديث المسابقة');
                }
            });
        });
        
        // منع طلب ملفات SVG غير موجودة
        $(document).on('error', 'img', function() {
            $(this).hide();
        });
    });
</script>
@endsection