@extends('layouts.main')

@section('title')
    {{__("Custom Fields")}} / {{__("Sub Category")}}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">



        @php
            $flashError = session('errors');
            if ($flashError instanceof \Illuminate\Support\ViewErrorBag) {
                $flashError = null;
            }
        @endphp

        @if ($errors->any())
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                <ul class="mb-0">
                    @foreach ($errors->all() as $validationError)
                        <li>{{ $validationError }}</li>
                    @endforeach
                </ul>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('Close') }}"></button>
            </div>
        @endif

        @if ($flashError)
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                {{ is_array($flashError) ? implode(' ', \Illuminate\Support\Arr::wrap($flashError)) : $flashError }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('Close') }}"></button>
            </div>
        @endif

        @if (session('success'))
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                {{ session('success') }}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="{{ __('Close') }}"></button>
            </div>
        @endif


        <div class="row">
            <div class="col-md-10">
                <div class="buttons text-start">
                    <a href="{{ route('category.index', $p_id) }}" class="btn btn-primary">< {{__("Back To Category")}} </a>
                    <a href="{{ route('custom-fields.create', ['id' => $cat_id]) }}" class="btn btn-primary">+ {{__("Create Custom Field")}} / {{ $category_name }}</a>
                    @if($customFieldsCount > 1)
                        <a href="{{ route('custom-fields.order', $cat_id) }}" class="btn btn-secondary"><i class="fa fa-list-ol"></i> {{__("Reorder Custom Fields")}}</a>
                    @endif




                    @can('category-create')
                        <button type="button" class="btn btn-outline-primary" data-bs-toggle="modal" data-bs-target="#cloneCategoryModal">
                            <i class="fas fa-clone me-1"></i> {{ __('نسخ الفئة الحالية') }}
                        </button>
                    @endcan



                </div>
            </div>
        </div>


        <div class="modal fade" id="cloneCategoryModal" tabindex="-1" aria-labelledby="cloneCategoryModalLabel" aria-hidden="true">
            <div class="modal-dialog">
                <form method="POST" action="{{ route('custom-fields.clone', $cat_id) }}" class="modal-content">
                    @csrf
                    <div class="modal-header">
                        <h5 class="modal-title" id="cloneCategoryModalLabel">{{ __('نسخ الفئة الحالية إلى قسم آخر') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('Close') }}"></button>
                    </div>
                    <div class="modal-body">
                        <p class="text-muted">{{ __('اختر القسم أو الفئة الهدف لنسخ هذه الفئة وحقولها المخصصة إليه.') }}</p>
                        <input type="hidden" name="source_category_id" value="{{ $cat_id }}">

                        @if(empty($cloneTargetOptions))
                            <div class="alert alert-warning mb-0" role="alert">
                                {{ __('لا توجد فئات متاحة لنسخ الفئة إليها حالياً.') }}
                            </div>
                        @else
                            <div class="mb-3">
                                <label for="target_parent_category_id" class="form-label">{{ __('الفئة الهدف') }}</label>
                                <select name="target_parent_category_id" id="target_parent_category_id" class="form-select" required>
                                    <option value="" disabled selected>{{ __('اختر الفئة الهدف') }}</option>
                                    @foreach($cloneTargetOptions as $option)
                                        <option value="{{ $option['id'] }}" @selected((int) old('target_parent_category_id') === (int) $option['id'])>{{ $option['label'] }}</option>
                                    @endforeach
                                </select>
                                @error('target_parent_category_id')
                                    <div class="text-danger small mt-1">{{ $message }}</div>
                                @enderror
                            </div>
                        @endif
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">{{ __('إلغاء') }}</button>
                        <button type="submit" class="btn btn-primary" @if(empty($cloneTargetOptions)) disabled @endif>{{ __('نسخ') }}</button>
                    </div>
                </form>
            </div>
        </div>



        <div class="col-md-12 col-sm-12">
            <div class="card">
                <div class="card-body">
                    <table class="table table-borderless table-striped" aria-describedby="mydesc" id="table_list"
                           data-toggle="table" data-url="{{ route('category.custom-fields.show', $cat_id) }}"
                           data-click-to-select="true" data-side-pagination="server" data-pagination="true"
                           data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true" data-search-align="right"
                           data-escape="true"
                           data-toolbar="#toolbar" data-show-columns="true" data-show-refresh="true" data-fixed-columns="true"
                           data-fixed-number="1" data-fixed-right-number="1" data-trim-on-search="false" data-responsive="true"
                           data-sort-name="id" data-sort-order="desc" data-pagination-successively-size="3"
                           data-query-params="queryParams" data-mobile-responsive="true">
                        <thead class="thead-dark">
                        <tr>
                            <th scope="col" data-field="state" data-checkbox="true"></th>
                            <th scope="col" data-field="id" data-align="center" data-sortable="true">{{ __('ID') }}</th>
                            <th scope="col" data-field="image" data-align="center" data-formatter='imageFormatter'>{{ __('Image') }}</th>
                            <th scope="col" data-field="name" data-align="center" data-sortable="true">{{ __('Custom Field') }}</th>
                            <th scope="col" data-field="operate" data-escape="false" data-sortable="false">{{ __('Action') }}</th>
                        </tr>
                        </thead>
                    </table>
                </div>
            </div>
        </div>
    </section>
@endsection


@section('script')
    @if ($errors->has('target_parent_category_id'))
        <script>
            document.addEventListener('DOMContentLoaded', function () {
                const modalElement = document.getElementById('cloneCategoryModal');
                if (modalElement && typeof bootstrap !== 'undefined') {
                    const cloneModal = bootstrap.Modal.getOrCreateInstance(modalElement);
                    cloneModal.show();
                }
            });
        </script>
    @endif
@endsection
