@extends('layouts.main')

@section('title')
    {{ __('سجل الإشعارات') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row align-items-center">
            <div class="col-12 col-md-7 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-muted mb-0">{{ __('تابع جميع الإشعارات المرسلة وعدد مرات ظهورها ونقر المستخدمين عليها.') }}</p>
            </div>
            <div class="col-12 col-md-5 order-md-2 order-first text-md-end mt-3 mt-md-0">
                @can('notification-create')
                    <a href="{{ route('notification.create') }}" class="btn btn-primary">
                        <i class="bi bi-send"></i> {{ __('إرسال إشعار جديد') }}
                    </a>
                @endcan
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card border shadow-sm">
            <div class="card-header bg-light d-flex justify-content-between align-items-center">
                <h5 class="mb-0">{{ __('سجل الإشعارات') }}</h5>
                <div id="toolbar" class="d-flex gap-2">
                    @can('notification-delete')
                        <a href="{{ route('notification.batch.delete') }}" class="btn btn-danger btn-sm btn-icon text-white" id="delete_multiple" title="{{ __('حذف الإشعارات المحددة') }}">
                            <em class='fa fa-trash'></em>
                        </a>
                    @endcan
                </div>
            </div>
            <div class="card-body">
                <table aria-describedby="notificationHistory" class='table-striped' id="table_list" data-toggle="table"
                       data-url="{{ route('notification.show',1) }}" data-click-to-select="true"
                       data-side-pagination="server" data-pagination="true"
                       data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true" data-toolbar="#toolbar"
                       data-show-columns="true" data-show-refresh="true" data-fixed-columns="true"
                       data-fixed-number="1" data-fixed-right-number="1" data-trim-on-search="false"
                       data-escape="true"
                       data-responsive="true" data-sort-name="id" data-sort-order="desc"
                       data-pagination-successively-size="3" data-show-export="true" data-export-options='{"fileName": "notification-history","ignoreColumn": ["operate"]}' data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']">
                    <thead>
                    <tr>
                        @can('notification-delete')
                            <th scope="col" data-field="state" data-checkbox="true"></th>
                        @endcan
                        <th scope="col" data-field="id" data-sortable="true">{{ __('المعرف') }}</th>
                        <th scope="col" data-field="title" data-sortable="true">{{ __('العنوان') }}</th>
                        <th scope="col" data-field="message" data-sortable="true">{{ __('المحتوى') }}</th>
                        <th scope="col" data-field="image" data-formatter="imageFormatter">{{ __('الصورة') }}</th>
                        <th scope="col" data-field="send_to" data-sortable="true">{{ __('الفئة المستهدفة') }}</th>
                        <th scope="col" data-field="category" data-sortable="true">{{ __('تصنيف الإشعار') }}</th>
                        <th scope="col" data-field="delivered_count" data-sortable="true">{{ __('مرات الظهور') }}</th>
                        <th scope="col" data-field="clicked_count" data-sortable="true">{{ __('مرات النقر') }}</th>
                        @can('notification-delete')
                            <th scope="col" data-field="operate" data-escape="false">{{ __('الإجراءات') }}</th>
                        @endcan
                    </tr>
                    </thead>
                </table>
            </div>
        </div>
    </section>
@endsection
