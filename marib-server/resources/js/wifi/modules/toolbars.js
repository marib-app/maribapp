import { $, state } from './core';
import { debounce } from './utils';

function setupNetworkToolbar() {
    const searchInput = document.querySelector('[data-network-search]');
    const statusSelect = document.querySelector('[data-network-status-filter]');
    const refreshButton = document.querySelector('[data-action="refresh-networks"]');

    if (searchInput) {
        searchInput.addEventListener('input', debounce((event) => {
            state.filters.networkSearch = event.target.value ?? '';
            state.tables.networks?.bootstrapTable('refresh');
        }, 400));
    }

    if (statusSelect) {
        statusSelect.addEventListener('change', (event) => {
            state.filters.networkStatus = event.target.value ?? '';
            state.tables.networks?.bootstrapTable('refresh');
        });
    }

    if (refreshButton) {
        refreshButton.addEventListener('click', () => {
            state.tables.networks?.bootstrapTable('refresh');
        });
    }
}

function setupReportToolbar() {
    const statusFilter = document.querySelector('[data-report-status-filter]');
    const networkFilter = document.querySelector('[data-report-network-filter]');
    const refreshButton = document.querySelector('[data-action="refresh-reports"]');

    if (statusFilter) {
        statusFilter.addEventListener('change', (event) => {
            state.filters.reportStatus = event.target.value ?? '';
            state.tables.reports?.bootstrapTable('refresh');
        });
    }

    if (networkFilter) {
        networkFilter.addEventListener('change', (event) => {
            const value = event.target.value;
            state.filters.reportNetwork = value ? Number.parseInt(value, 10) || '' : '';
            state.tables.reports?.bootstrapTable('refresh');
        });
    }

    if (refreshButton) {
        refreshButton.addEventListener('click', () => {
            state.tables.reports?.bootstrapTable('refresh');
        });
    }
}

function setupBatchToolbar() {
    const statusFilter = document.querySelector('[data-batch-status-filter]');
    if (statusFilter) {
        statusFilter.addEventListener('change', () => {
            const table = $('#wifi-network-batches-table');
            const status = statusFilter.value;
            if (!table.length) {
                return;
            }
            if (!status) {
                table.bootstrapTable('refreshOptions', { data: table.bootstrapTable('getData') });
                return;
            }
            const filtered = table.bootstrapTable('getData').filter((row) => row.status === status);
            table.bootstrapTable('load', filtered);
        });
    }

    const mainStatusFilter = document.querySelector('[data-batch-status-filter-main]');
    if (mainStatusFilter) {
        mainStatusFilter.addEventListener('change', () => {
            const rows = $('#wifi-batches-table').bootstrapTable('getData');
            if (!Array.isArray(rows)) {
                return;
            }
            const status = mainStatusFilter.value;
            if (!status) {
                $('#wifi-batches-table').bootstrapTable('load', rows);
                return;
            }
            const filtered = rows.filter((row) => row.status === status);
            $('#wifi-batches-table').bootstrapTable('load', filtered);
        });
    }
}

export { setupBatchToolbar, setupNetworkToolbar, setupReportToolbar };
