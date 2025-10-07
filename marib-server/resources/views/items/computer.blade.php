@extends('layouts.main')

@section('title')
    {{ __('إعلانات الكمبيوتر') }}
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
                                        <option value="{{ $category->id }}">{{ $category->name }}</option>
                                    @endforeach
                                </select>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="row">


                         <div class ="table-responsive">
                        <table class="table-borderless table-striped" aria-describedby="mydesc" id="table_list"
                               data-toggle="table" data-url="{{ route('item.show',1) }}" data-click-to-select="true"
                                data-side-pagination="server" data-pagination="true"
                               data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true"
                               data-show-columns="true" data-show-refresh="true" data-fixed-columns="true"
                               data-fixed-number="1" data-fixed-right-number="1" data-trim-on-search="false"
                               data-escape="true"
                               data-responsive="true" data-sort-name="id" data-sort-order="desc"
                               data-pagination-successively-size="3" data-table="items" data-status-column="deleted_at"
                               data-show-export="true" data-export-options='{"fileName": "item-list","ignoreColumn": ["operate"]}' data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']"
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
                                @can('computer-ads-update')
                                    <th scope="col" data-field="active_status" data-sortable="true" data-sort-name="deleted_at" data-visible="true" data-escape="false" data-formatter="statusSwitchFormatter">{{ __('Active') }}</th>
                                @endcan
                                <th scope="col" data-field="rejected_reason" data-sortable="true" data-visible="true">{{ __('Rejected Reason') }}</th>
                                <th scope="col" data-field="created_at" data-sortable="true" data-visible="false">{{ __('Created At') }}</th>
                                <th scope="col" data-field="updated_at" data-sortable="true" data-visible="false">{{ __('Updated At') }}</th>
                                <th scope="col" data-field="user_id" data-sortable="true" data-visible="false">{{ __('User ID') }}</th>
                                <th scope="col" data-field="category_id" data-sortable="true" data-visible="false">{{ __('Category ID') }}</th>
                                <th scope="col" data-field="likes" data-sortable="true" data-visible="false">{{ __('Likes') }}</th>
                                <th scope="col" data-field="clicks" data-sortable="true" data-visible="false">{{ __('Clicks') }}</th>
                                @canany(['computer-ads-update','computer-ads-delete'])
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


                function computerQueryParams(params) {
            params = params || {};

            params.section = 'computer';
            params.category_root = 5;

            var selectedCategory = $('#category_filter').val();
            if (selectedCategory) {
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



            var $table = $('#table_list');

            $table.bootstrapTable({
                queryParams: computerQueryParams
            });

            function refreshComputerTable() {
                $table.bootstrapTable('refresh', {
                    query: {
                        section: 'computer',
                        category_root: 5
                    }
                });
            }




            $('#category_filter').on('change', function() {
                refreshComputerTable();
                forceSelect2Width();
            });

            $('#filter').on('change', function() {
                refreshComputerTable();
            });

        });
    </script>
@endsection
