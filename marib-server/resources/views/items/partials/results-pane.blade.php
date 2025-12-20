<div class="table-responsive">
    <table
        class="table table-borderless table-striped align-middle mb-0"
        aria-describedby="items-list"
        id="table_list"
        data-toggle="table"
        data-url="{{ route('item.list') }}"
        data-click-to-select="true"
        data-side-pagination="server"
        data-pagination="true"
        data-page-list="[5, 10, 20, 50, 100, 200]"
        data-search="true"
        data-search-align="right"
        data-show-refresh="true"
        data-show-columns="true"
        data-show-columns-toggle-all="true"
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
        data-mobile-responsive="false"
        data-filter-control="true"
        data-filter-control-container="#filters"
        data-query-params="itemListQueryParams"
        data-toolbar="#filters"
    >
        <thead class="thead-dark">
        <tr>
            <th scope="col" data-field="id" data-sortable="true">{{ __('ID') }}</th>
            <th scope="col" data-field="name" data-sortable="true">{{ __('Name') }}</th>
            <th scope="col" data-field="user_name" data-sort-name="user_name" data-sortable="true">{{ __('User') }}</th>
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
