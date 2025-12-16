@extends('layouts.app')
@section('title')
    {{ __('User Reports') }}
@endsection

@section('content')
<section class="section">
    <div class="dashboard_title mb-3">{{ __('User Reports') }}</div>
    
    <div class="row">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">{{ __('User Reports') }}</h3>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-12">
                            <div id="filters">
                                <div class="row mb-3 g-2">
                                    <div class="col-12 col-md-4">
                                        <label for="department_filter">{{ __('Department') }}</label>
                                        <select class="form-control" id="department_filter">
                                            <option value="">{{ __('All') }}</option>
                                            @foreach($departments as $key => $label)
                                                <option value="{{ $key }}">{{ $label }}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                    <div class="col-12 col-md-4">


                                        <label for="user_filter">{{__("User")}}</label>
                                        <select class="form-control bootstrap-table-filter-control-user_id" id="user_filter">
                                            <option value="">{{__("All")}}</option>
                                            @foreach($users as $user)
                                                <option value="{{$user->id}}">{{$user->name}}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                    <div class="col-12 col-md-4">

                                    <label for="item_filter">{{__("Item")}}</label>
                                        <select class="form-control bootstrap-table-filter-control-item_id" id="item_filter">
                                            <option value="">{{__("All")}}</option>
                                            @foreach($items as $item)
                                                <option value="{{$item->id}}">{{$item->name}}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                </div>
                            </div>
                            <div class="table-responsive">
                                <table class="table-borderless table-striped" aria-describedby="mydesc"
                                       id="table_list" data-toggle="table" data-url="{{  route('report-reasons.user-reports.show') }}"
                                       data-click-to-select="true" data-responsive="true" data-side-pagination="server"
                                       data-pagination="true" data-page-list="[5, 10, 20, 50, 100, 200]"
                                       data-search="true" data-show-columns="true"
                                       data-show-refresh="true" data-fixed-columns="true" data-fixed-number="1"
                                       data-fixed-right-number="1" data-trim-on-search="false" data-sort-name="id"
                                       data-sort-order="desc" data-pagination-successively-size="3" data-query-params="queryParams"
                                       data-escape="true"
                                       data-show-export="true" data-export-options='{"fileName": "user-reports","ignoreColumn": ["operate"]}' data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']"
                                       data-mobile-responsive="true" data-filter-control="true" data-filter-control-container="#filters" data-toolbar="#filters">
                                    <thead class="thead-dark">
                                    <tr>
                                        <th scope="col" data-field="id" data-align="center" data-sortable="true">{{ __('ID') }}</th>
                                        <th scope="col" data-field="reason" data-align="center">{{ __('Reason') }}</th>
                                        <th scope="col" data-field="details" data-align="center">{{ __('Details') }}</th>
                                        <th scope="col" data-field="user.name" data-sort-name="user_name" data-align="center" data-sortable="true">{{ __('User') }}</th>
                                        <th scope="col" data-field="item.name" data-sort-name="item_name" data-align="center" data-sortable="true">{{ __('Item') }}</th>
                                        <th scope="col" data-field="department_label" data-sort-name="department" data-align="center" data-sortable="true">{{ __('Department') }}</th>
                                        <th scope="col" data-field="reported_at" data-sort-name="created_at" data-align="center" data-sortable="true">{{ __('Reported At') }}</th>

                                        <th scope="col" data-field="item_id" data-align="center" data-sortable="true" data-visible="false" data-filter-control="select" data-filter-data="">{{ __('Item ID') }}</th>
                                        <th scope="col" data-field="user_id" data-align="center" data-sortable="true" data-visible="false" data-filter-control="select" data-filter-data="">{{ __('User ID') }}</th>
                                        <th scope="col" data-field="item_status" data-visible="true" data-formatter="itemStatusSwitchFormatter">{{ __('Item Status') }}</th>
                                        <th scope="col" data-field="user_status" data-visible="true" data-formatter="userStatusSwitchFormatter">{{ __('User status') }}</th>
                                    </tr>
                                    </thead>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</section>
@endsection




@push('scripts')
    <script>
        (function () {
            const departmentFilter = document.getElementById('department_filter');
            const userFilter = document.getElementById('user_filter');
            const itemFilter = document.getElementById('item_filter');
            const table = $('#table_list');

            function refreshTable() {
                table.bootstrapTable('refresh');
            }

            [departmentFilter, userFilter, itemFilter].forEach(function (element) {
                element.addEventListener('change', refreshTable);
            });

            window.queryParams = function (params) {
                const filters = {};

                if (departmentFilter.value) {
                    params.department = departmentFilter.value;
                    filters.department = departmentFilter.value;
                }

                if (userFilter.value) {
                    filters.user_id = userFilter.value;
                }

                if (itemFilter.value) {
                    filters.item_id = itemFilter.value;
                }

                if (Object.keys(filters).length > 0) {
                    params.filter = JSON.stringify(filters);
                } else if (params.filter) {
                    delete params.filter;
                }

                return params;
            };
        })();
    </script>
@endpush
