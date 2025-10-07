<div class="items-results">
    <div class="items-results__header d-flex flex-column flex-lg-row align-items-lg-center justify-content-between gap-2 gap-lg-3">
        <div class="flex-grow-1" aria-hidden="true"></div>
        <div class="d-flex align-items-center gap-2 justify-content-lg-end">

            <button class="btn btn-light btn-sm" type="button" data-refresh-table aria-label="{{ __('Refresh table') }}">
                <i class="fa fa-rotate"></i>
            </button>
        </div>
    </div>

    <div class="items-results__table card border-0 shadow-sm">
        <div class="card-body p-0">
            <div class="table-responsive">
                <table
                    class="table table-hover table-striped align-middle mb-0"
                    aria-describedby="items-list"
                    id="table_list"
                    data-toggle="table"
                    data-url="{{ route('item.list') }}"
                    data-click-to-select="true"
                    data-side-pagination="server"
                    data-pagination="true"
                    data-page-list="[5, 10, 20, 50, 100, 200]"
                    data-search="true"
                    data-show-refresh="true"
                    data-fixed-columns="true"
                    data-fixed-number="1"
                    data-fixed-right-number="1"
                    data-trim-on-search="false"
                    data-escape="true"
                    data-responsive="true"
                    data-sort-name="id"
                    data-sort-order="desc"
                    data-pagination-successively-size="3"
                    data-table="items"
                    data-status-column="deleted_at"
                    data-show-export="true"
                    data-export-options='{"fileName": "item-list","ignoreColumn": ["operate"]}'
                    data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']"
                    data-mobile-responsive="true"
                    data-filter-control="true"
                    data-filter-control-container="#filters"
                    data-query-params="itemListQueryParams"
                    data-toolbar="#filters"
                >
                    <thead class="table-light">
                    <tr>
                        <th scope="col" data-field="id" data-sortable="true">{{ __('ID') }}</th>
                        <th scope="col" data-field="name" data-sortable="true">{{ __('Name') }}</th>
                        <th scope="col" data-field="user.name" data-sort-name="user_name" data-sortable="true">{{ __('User') }}</th>
                        <th scope="col" data-field="price" data-sortable="true">{{ __('Price') }}</th>
                        <th scope="col" data-field="currency" data-sortable="true">{{ __('Currency') }}</th>
                        <th scope="col" data-field="image" data-sortable="false" data-escape="false" data-formatter="imageFormatter">{{ __('Image') }}</th>
                        <th scope="col" data-field="city" data-sortable="true" data-visible="true">{{ __('City') }}</th>
                        <th scope="col" data-field="status" data-sortable="true" data-filter-control="select" data-filter-data="" data-escape="false" data-formatter="itemStatusFormatter">{{ __('Status') }}</th>
                        @can('item-update')
                            <th scope="col" class="active-column-header" data-field="active_status" data-sortable="true" data-sort-name="deleted_at" data-visible="true" data-escape="false" data-formatter="statusSwitchFormatter" data-classes="active-column-cell">{{ __('Active') }}</th>
                        @endcan
                        @canany(['item-update','item-delete'])
                            <th scope="col" data-field="operate" data-align="center" data-sortable="false" data-events="itemEvents" data-escape="false">{{ __('Action') }}</th>
                        @endcanany
                    </tr>
                    </thead>
                </table>
            </div>
        </div>
    </div>
</div>

<div class="offcanvas offcanvas-end items-preview" tabindex="-1" id="itemPreviewOffcanvas" aria-labelledby="itemPreviewOffcanvasLabel">
    <div class="offcanvas-header border-bottom">
        <h5 class="offcanvas-title" id="itemPreviewOffcanvasLabel" data-preview-heading="{{ __('Ad Preview') }}">{{ __('Ad Preview') }}</h5>
        <button type="button" class="btn-close text-reset" data-bs-dismiss="offcanvas" aria-label="{{ __('Close') }}"></button>
    </div>
    <div class="offcanvas-body">
        <div class="items-preview__loading d-flex align-items-center gap-2 text-muted" data-preview-loading>
            <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
            <span>{{ __('Loading details...') }}</span>
        </div>
        <div class="items-preview__error alert alert-danger d-none" role="alert" data-preview-error data-error-message="{{ __('Unable to load preview.') }}"></div>
        <div class="items-preview__content d-none" data-preview-content></div>
    </div>
</div>