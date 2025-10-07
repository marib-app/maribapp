@extends('layouts.main')

@section('page-title')
    {{ __('Shein Items') }}
@endsection

@section('page-style')
<style>

    .card-body {
        overflow-x: hidden;
    }
    
    /* Reset default Select2 width */
    .select2-container {
        width: 100% !important;
    }
    
    /* Target category filter specifically with highest specificity */
    #filters .col-md-8 .select2-container,
    #filters .col-md-8 .select2-container.select2-container--default,
    #filters .col-md-8 .select2-container.select2-container--open,
    #category_filter + .select2-container {
        width: 100% !important;
        min-width: 400px !important;
    }
    
    /* Force width on dropdown */
    .select2-dropdown,
    .select2-dropdown.select2-dropdown--below,
    .select2-dropdown.select2-dropdown--above {
        width: auto !important;
        min-width: 400px !important;
    }
    
    /* Custom class for our dropdown */
    .category-filter-dropdown {
        width: 100% !important;
        min-width: 400px !important;
    }
    
    /* Force width on selection container */
    .select2-container .select2-selection {
        width: 100% !important;
        min-width: 400px !important;
    }

    #table_list {
        width: 100%;
    }
</style>
@endsection

@section('page-header')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>{{ __('Shein Items') }}</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first">
                @can('shein-products-create')
                    <div class="float-end">
                        <a href="{{ route('item.shein.create') }}" class="btn btn-primary">
                            <i class="bi bi-plus-circle"></i> {{ __('Add New Item') }}
                        </a>
                    </div>
                @endcan
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-body">
                <div class="row">
                    <div class="col-12">
                        <div id="filters" class="row mb-3">
                            <div class="col-md-4">
                                <label for="filter">{{__("Status")}}</label>
                                <select class="form-control bootstrap-table-filter-control-status" id="filter">
                                    <option value="">{{__("All")}}</option>
                                    <option value="review">{{__("Under Review")}}</option>
                                    <option value="approved">{{__("Approved")}}</option>
                                    <option value="rejected">{{__("Rejected")}}</option>
                                    <option value="sold out">{{__("Sold Out")}}</option>
                                </select>
                            </div>
                            <div class="col-md-8">
                                <label for="category_filter">{{__("Category")}}</label>
                                <select class="form-control select2" id="category_filter" name="category_filter">
                                    <option value="">{{__("All Categories")}}</option>
                                    @foreach($categories as $category)
                                        <option value="{{ $category->id }}" {{ $category->id == 4 ? 'selected' : '' }}>{{ $category->name }}</option>
                                    @endforeach
                                </select>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="row">
                    <div class="col-12 mb-3">
                        @can('shein-products-create')
                            <div class="float-end">
                                <a href="{{ route('item.shein.products.create') }}" class="btn btn-primary">
                                    <i class="bi bi-plus-circle"></i> {{ __('Add New Item') }}
                                </a>
                            </div>
                        @endcan
                    </div>
                </div>
                <div class="row">
                    <div class ="table-responsive">
                        <table class="table-borderless table-striped" aria-describedby="mydesc" id="table_list"
                               data-toggle="table" data-url="{{ route('item.shein.products.data') }}" data-click-to-select="true"
                               data-side-pagination="server" data-pagination="true"
                               data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true"
                               data-show-columns="true" data-show-refresh="true" data-fixed-columns="true"
                               data-fixed-number="1" data-fixed-right-number="1" data-trim-on-search="false"
                               data-escape="true"
                               data-responsive="true" data-sort-name="id" data-sort-order="desc"
                               data-pagination-successively-size="3" data-table="items" data-status-column="deleted_at"
                               data-show-export="true" data-export-options='{"fileName": "shein-item-list","ignoreColumn": ["operate"]}' data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']"
                               data-mobile-responsive="true" data-filter-control="true" data-filter-control-container="#filters" data-toolbar="#filters">
                            <thead class="thead-dark">
                            <tr>
                                <th scope="col" data-field="id" data-sortable="true">{{ __('ID') }}</th>
                                <th scope="col" data-field="name" data-sortable="true">{{ __('Name') }}</th>
                                <th scope="col" data-field="description" data-align="center" data-sortable="true" data-formatter="descriptionFormatter">{{ __('Description') }}</th>
                                <th scope="col" data-field="user.name" data-sort-name="user_name" data-sortable="true">{{ __('User') }}</th>
                                <th scope="col" data-field="price" data-sortable="true">{{ __('Price') }}</th>
                                <th scope="col" data-field="currency" data-sortable="true">{{ __('Currency') }}</th>
                                <th scope="col" data-field="image" data-sortable="false" data-escape="false" data-formatter="imageFormatter">{{ __('Image') }}</th>
                                <th scope="col" data-field="gallery_images" data-sortable="false" data-formatter="galleryImageFormatter" data-escape="false">{{ __('Other Images') }}</th>
                                <th scope="col" data-field="latitude" data-sortable="true" data-visible="false">{{ __('Latitude') }}</th>
                                <th scope="col" data-field="longitude" data-sortable="true" data-visible="false">{{ __('Longitude') }}</th>
                                <th scope="col" data-field="address" data-sortable="true" data-visible="false">{{ __('Address') }}</th>
                                <th scope="col" data-field="contact" data-sortable="true" data-visible="false">{{ __('Contact') }}</th>
                                <th scope="col" data-field="country" data-sortable="true" data-visible="true">{{ __('Country') }}</th>
                                <th scope="col" data-field="state" data-sortable="true" data-visible="true">{{ __('State') }}</th>
                                <th scope="col" data-field="city" data-sortable="true" data-visible="true">{{ __('City') }}</th>
                                <th scope="col" data-field="status" data-sortable="true" data-filter-control="select" data-filter-data="" data-escape="false" data-formatter="itemStatusFormatter">{{ __('Status') }}</th>
                                @can('item-update')
                                    <th scope="col" data-field="active_status" data-sortable="true" data-sort-name="deleted_at" data-visible="true" data-escape="false" data-formatter="statusSwitchFormatter">{{ __('Active') }}</th>
                                @endcan
                                <th scope="col" data-field="rejected_reason" data-sortable="true" data-visible="true">{{ __('Rejected Reason') }}</th>
                                <th scope="col" data-field="created_at" data-sortable="true" data-visible="false">{{ __('Created At') }}</th>
                                <th scope="col" data-field="updated_at" data-sortable="true" data-visible="false">{{ __('Updated At') }}</th>
                                <th scope="col" data-field="user_id" data-sortable="true" data-visible="false">{{ __('User ID') }}</th>
                                <th scope="col" data-field="category_id" data-sortable="true" data-visible="false">{{ __('Category ID') }}</th>
                                <th scope="col" data-field="likes" data-sortable="true" data-visible="false">{{ __('Likes') }}</th>
                                <th scope="col" data-field="clicks" data-sortable="true" data-visible="false">{{ __('Clicks') }}</th>
                                @canany(['shein-products-update','shein-products-delete'])
                                    <th scope="col" data-field="operate" data-align="center" data-sortable="false" data-events="itemEvents" data-escape="false">{{ __('Action') }}</th>
                                @endcanany
                            </tr>
                            </thead>
                        </table>
                        </div>
                </div>
            </div>
        </div>
        <div id="editModal" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="myModalLabel1"
             aria-hidden="true">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="myModalLabel1">{{ __('Item Details') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <div class="modal-body">
                        <div class="center" id="custom_fields"></div>
                    </div>
                </div>
            </div>
            <!-- /.modal-content -->
        </div>
        <div id="editStatusModal" class="modal fade" tabindex="-1" role="dialog" aria-labelledby="myModalLabel1"
             aria-hidden="true">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="myModalLabel1">{{ __('Status') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <div class="modal-body">
                        <form class="edit-form" action="" method="POST" data-success-function="updateApprovalSuccess">
                            @csrf
                            <div class="row">
                                <div class="col-md-12">
                                    <select name="status" class="form-select" id="status" aria-label="status">
                                        <option value="review">{{__("Under Review")}}</option>
                                        <option value="approved">{{__("Approve")}}</option>
                                        <option value="rejected">{{__("Reject")}}</option>
                                    </select>
                                </div>
                            </div>
                            <div id="rejected_reason_container" class="col-md-12" style="display: none;">
                                <label for="rejected_reason" class="mandatory form-label">{{ __('Reason') }}</label>
                                <textarea name="rejected_reason" id="rejected_reason" class="form-control" placeholder={{ __('Reason') }}></textarea>
                                {{-- <input type="text" name="rejected_reason" id="rejected_reason" class="form-control"> --}}
                            </div>
                            <input type="submit" value="{{__("Save")}}" class="btn btn-primary mt-3">
                        </form>
                    </div>
                </div>
            </div>
            <!-- /.modal-content -->
        </div>
    </section>
@endsection
@section('script')
    <script>
        function updateApprovalSuccess() {
            $('#editStatusModal').modal('hide');
        }

        function forceSelect2Width() {
            // Force the width of all Select2 elements
            $('.select2-container').css('width', '100%');
            
            // Specifically target category filter
            var $categorySelect = $('#category_filter');
            var $categoryContainer = $categorySelect.next('.select2-container');
            
            $categoryContainer.css({
                'width': '100%',
                'min-width': '400px'
            });
            
            $categoryContainer.find('.select2-selection').css({
                'width': '100%',
                'min-width': '400px'
            });
        }

        function itemEvents() {
            return {
                'click .editdata': function (e, value, row, index) {
                    var html = '';
                    $.each(row.custom_fields, function (key, val) {
                        html += '<div class="form-group">';
                        html += '<label>' + val.name + '</label>';
                        if (val.type === 'textarea') {
                            html += '<textarea class="form-control" readonly>' + (val.value ? val.value.value : '') + '</textarea>';
                        } else if (val.type === 'fileinput') {
                            if (val.value && val.value.value) {
                                html += '<div><img src="' + val.value.value + '" class="img-thumbnail" style="max-width:200px"></div>';
                            } else {
                                html += '<div>No Image</div>';
                            }
                        } else {
                            html += '<input type="text" class="form-control" value="' + (val.value ? val.value.value : '') + '" readonly>';
                        }
                        html += '</div>';
                    });
                    $('#custom_fields').html(html);
                },
                'click .edit-status': function (e, value, row, index) {
                    // Redirect to edit page instead of showing status modal
                    window.location.href = row.edit_url;
                },
                'click .edit-item': function (e, value, row, index) {
                    window.location.href = value;
                }
            };
        }

        function itemStatusFormatter(value, row) {
            let status = '';
            if (value === 'review') {
                status = '<span class="badge bg-warning">' + '{{ __("Under Review") }}' + '</span>';
            } else if (value === 'approved') {
                status = '<span class="badge bg-success">' + '{{ __("Approved") }}' + '</span>';
            } else if (value === 'rejected') {
                status = '<span class="badge bg-danger">' + '{{ __("Rejected") }}' + '</span>';
            } else if (value === 'sold out') {
                status = '<span class="badge bg-secondary">' + '{{ __("Sold Out") }}' + '</span>';
            }
            return status;
        }

        function statusSwitchFormatter(value, row) {
            let checked = value ? 'checked' : '';
            return '<div class="form-check form-switch"><input class="form-check-input" type="checkbox" ' + checked + ' disabled></div>';
        }

        function imageFormatter(value, row) {
            if (value) {
                return '<img src="' + value + '" class="img-thumbnail" style="max-width:100px">';
            }
            return '';
        }

        function galleryImageFormatter(value, row) {
            if (value && value.length > 0) {
                let html = '<div class="d-flex flex-wrap">';
                for (let i = 0; i < value.length; i++) {
                    html += '<img src="' + value[i].image + '" class="img-thumbnail me-1 mb-1" style="max-width:50px; max-height:50px;">';
                }
                html += '</div>';
                return html;
            }
            return '';
        }

        function sheinQueryParams(params) {
            params = params || {};

            params.section = 'shein';
            params.category_root = 4;

            var selectedCategory = $('#category_filter').val();
            if (selectedCategory && selectedCategory !== '' && selectedCategory !== '4') {
                params.category_id = selectedCategory;
            } else {
                delete params.category_id;
            }

            var statusFilter = $('#filter').val();
            if (statusFilter) {
                params.status = statusFilter;
            } else {
                delete params.status;
            }

            return params;
        }


        $(document).ready(function() {
            // Initialize Select2 with explicit width
            $('#category_filter').select2({
                placeholder: "{{__("Search Categories")}}",
                allowClear: true,
                width: '100%',
                dropdownCssClass: 'category-filter-dropdown'
            });

            // Set default category filter value for Shein page to category ID 4
            $('#category_filter').val(4).trigger('change');

            // Override queryParams to always include category_id=4
            var $table = $('#table_list');
            
            $table.bootstrapTable({
                queryParams: sheinQueryParams

            });

            // Force width immediately after initialization
            forceSelect2Width();
            
            // Force width again after a short delay
            setTimeout(forceSelect2Width, 100);
            
            // Force width periodically to handle any dynamic changes
            setInterval(forceSelect2Width, 500);
            
            // Force width when dropdown opens
            $('#category_filter').on('select2:open', function() {
                forceSelect2Width();
                $('.select2-dropdown').css({
                    'width': '100%',
                    'min-width': '400px'
                });
            });

            // Update filters and refresh table when category changes

            function refreshSheinTable() {
                $table.bootstrapTable('refresh', {
                    query: {
                        section: 'shein',
                        category_root: 4
                    }
                });
            }


            $('#category_filter').on('change', function() {
                refreshSheinTable();
                forceSelect2Width();
            });

            // Update filters and refresh table when status changes
            $('#filter').on('change', function() {
                refreshSheinTable();
            });

            $('#status').on('change', function() {
                if ($(this).val() == 'rejected') {
                    $('#rejected_reason_container').show();
                    $('#rejected_reason').attr('required', true);
                } else {
                    $('#rejected_reason_container').hide();
                    $('#rejected_reason').attr('required', false);
                }
            });
        });
    </script>
@endsection
