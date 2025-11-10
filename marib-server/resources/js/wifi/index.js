import { $, config, state } from './modules/core';
import { registerTables } from './modules/tables';
import { hydrateBatchesTable } from './modules/batches';
import { setupBatchToolbar, setupNetworkToolbar, setupReportToolbar } from './modules/toolbars';
import { setupCommissionForm, setupStatusForm } from './modules/forms';

registerTables();

function initWifiAdmin() {
    const root = document.querySelector('[data-wifi-admin-root]');
    if (!root || root.dataset.initialized || typeof $ === 'undefined') {
        return;
    }

    root.dataset.initialized = 'true';
    config.baseUrl = root.dataset.baseUrl || config.baseUrl;
    config.ownerBaseUrl = root.dataset.ownerBaseUrl || config.ownerBaseUrl;
    config.detailUrlTemplate = root.dataset.detailUrl || config.detailUrlTemplate;

    state.tables.networks = $('#wifi-networks-table');
    state.tables.reports = $('#wifi-reports-table');

    setupNetworkToolbar();
    setupReportToolbar();
    setupBatchToolbar();
    setupStatusForm();
    setupCommissionForm();
    hydrateBatchesTable();

    if (state.tables.networks?.length) {
        state.tables.networks.bootstrapTable('refresh');
    }
    if (state.tables.reports?.length) {
        state.tables.reports.bootstrapTable('refresh');
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initWifiAdmin, { once: true });
} else {
    initWifiAdmin();
}

export { initWifiAdmin };
