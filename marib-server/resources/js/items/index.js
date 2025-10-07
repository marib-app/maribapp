const state = {
    previewController: null,
};

function getjQuery() {
    return window.jQuery ?? window.$ ?? null;
}

function refreshTable(options = { silent: true }) {

    const $ = getjQuery();
    if (!$) {


        return;
    }

    const $table = $('#table_list');
    if ($table && $table.length) {
        $table.bootstrapTable('refresh', options);
    }
}



function initFilters() {
    const $ = getjQuery();

    if (!$) {
        console.warn('jQuery is required for the items index page.');
        return;
    }

    const $categoryFilter = $('#category_filter');

    if ($categoryFilter.length) {
        const placeholder = $categoryFilter.data('placeholder') ?? '';

        if (typeof $categoryFilter.select2 === 'function') {
            $categoryFilter.select2({
                placeholder,
                allowClear: true,
                dropdownAutoWidth: true,
                width: '100%',
                theme: 'bootstrap-5',
            });
        }
    }

    $('#filter, #category_filter').on('change', () => {
        refreshTable({});
    });
}




function initRefreshTrigger(root) {
    const refreshTrigger = root.querySelector('[data-refresh-table]');
    if (!refreshTrigger) {
        return;
    }

    refreshTrigger.addEventListener('click', () => {
        refreshTable({});
    });
}



function initGlobals() {
    window.updateApprovalSuccess = function updateApprovalSuccess() {
        const $ = getjQuery();
        if ($) {
            $('#editStatusModal').modal('hide');
        }
    };

    window.itemListQueryParams = function itemListQueryParams(p) {
        const params = typeof window.queryParams === 'function' ? window.queryParams(p) : { ...p };

        const statusValue = document.querySelector('#filter')?.value ?? '';
        const categoryValue = document.querySelector('#category_filter')?.value ?? '';

        const status = statusValue.trim();
        const categoryId = categoryValue.trim();

        if (status) {
            params.status = status;
            
        } else {
            delete params.status;

        }

        if (categoryId) {
            params.category_id = categoryId;
        } else {
            delete params.category_id;

        }

        return params;
    };
}

function init() {
    const pageRoot = document.querySelector('[data-page="items-index"]');
    if (!pageRoot) {
        return;
    }

    initGlobals();
    initFilters();
    initRefreshTrigger(pageRoot);

}

document.addEventListener('DOMContentLoaded', init);