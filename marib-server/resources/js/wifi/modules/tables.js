import {
    batchBadgeClasses,
    batchStatusLabels,
    config,
    reportBadgeClasses,
    reportStatusLabels,
    state,
    statusBadgeClasses,
    statusLabels,
    toasts,
} from './core';
import {
    buildPaginationParams,
    formatDateValue,
    formatNumber,
    normalizeBootstrapResponse,
    parseErrorMessage,
    prepareNetworkRow,
    prepareReportRow,
} from './utils';
import { fetchTableData, sendPatch } from './api';
import { loadNetworkAssociations, openModal, updateNetworkModalDetails } from './modals';
import { refreshNetworkBatches } from './batches';

function registerTables() {
    const globalTables = window.MaribWifiAdminTables ?? (window.MaribWifiAdminTables = {});
    if (globalTables.__initialized) {
        return globalTables;
    }
    globalTables.__initialized = true;

    globalTables.formatDate = (value) => formatDateValue(value);

    globalTables.formatNetworkStatus = (value) => {
        const badgeClass = statusBadgeClasses[value] ?? 'bg-light text-dark';
        const label = statusLabels[value] ?? value ?? 'â€”';
        return `<span class="badge ${badgeClass}">${label}</span>`;
    };

    globalTables.formatCodesSummary = (value, row) => {
        const summary = value ?? row.codes_summary ?? {};
        const total = formatNumber(summary.total ?? 0);
        const available = formatNumber(summary.available ?? 0);
        const sold = formatNumber(summary.sold ?? 0);
        return `
        <div class="d-flex flex-column">
            <span class="fw-semibold">${total}</span>
            <small class="text-muted">المتاح: ${available} | المباع: ${sold}</small>
        </div>
    `;
    };

    globalTables.formatCommission = (value, row) => {
        const commission = value ?? row.commission_rate ?? row.settings?.commission_rate;
        if (commission === undefined || commission === null) {
            return '<span class="text-muted">â€”</span>';
        }
        const percent = Number.parseFloat(commission) * 100;
        return `${percent.toFixed(2)}%`;
    };

    globalTables.formatNetworkActions = () => `
    <div class="btn-group btn-group-sm" role="group">
        <button type="button" class="btn btn-outline-primary" data-action="view-network" title="ط¹ط±ط¶ ط§ظ„طھظپط§طµظٹظ„">
            <i class="bi bi-eye"></i>
        </button>
        <button type="button" class="btn btn-outline-warning" data-action="edit-status" title="طھط­ط¯ظٹط« ط§ظ„ط­ط§ظ„ط©">
            <i class="bi bi-shield-check"></i>
        </button>
        <button type="button" class="btn btn-outline-success" data-action="edit-commission" title="طھط¹ط¯ظٹظ„ ط§ظ„ط¹ظ…ظˆظ„ط©">
            <i class="bi bi-cash-stack"></i>
        </button>
        <button type="button" class="btn btn-outline-secondary" data-action="manage-batches" title="ط¥ط¯ط§ط±ط© ط§ظ„ط¯ظپط¹ط§طھ">
            <i class="bi bi-collection"></i>
        </button>
    </div>
`;

    globalTables.networkActionEvents = {
        'click [data-action="view-network"]'(event, value, row) {
            if (config.detailUrlTemplate) {
                const target = config.detailUrlTemplate.replace('__NETWORK__', row.id);
                window.location.href = target;
                return;
            }
            state.selectedNetwork = row;
            updateNetworkModalDetails(row);
            openModal(document.querySelector('[data-wifi-network-modal]'));
            loadNetworkAssociations(row.id);
        },
        'click [data-action="edit-status"]'(event, value, row) {
            state.selectedNetwork = row;
            const modal = document.querySelector('[data-wifi-status-modal]');
            if (!modal) {
                toasts.error('تعذر فتح نافذة تحديث الحالة.');
                return;
            }
            const select = modal?.querySelector('#wifi_network_status');
            if (select) {
                select.value = row.status ?? '';
            }
            const textarea = modal?.querySelector('#wifi_network_reason');
            if (textarea) {
                textarea.value = '';
            }
            openModal(modal);
        },
        'click [data-action="edit-commission"]'(event, value, row) {
            state.selectedNetwork = row;
            const modal = document.querySelector('[data-wifi-commission-modal]');
            const input = modal?.querySelector('#wifi_network_commission');
            if (input) {
                const commission = row.commission_rate ?? row.settings?.commission_rate ?? 0;
                input.value = (Number.parseFloat(commission) * 100).toFixed(2);
            }
            openModal(modal);
        },
        'click [data-action="manage-batches"]'(event, value, row) {
            state.selectedNetwork = row;
            const modal = document.querySelector('[data-wifi-batches-modal]');
            const subtitle = modal?.querySelector('[data-network-batches-subtitle]');
            if (subtitle) {
                subtitle.textContent = row.name
                    ? `ط¯ظپط¹ط§طھ ط§ظ„ط£ظƒظˆط§ط¯ ظ„ظ„ط´ط¨ظƒط©: ${row.name}`
                    : 'ط¯ظپط¹ط§طھ ط§ظ„ط£ظƒظˆط§ط¯ ط§ظ„ظ…ط±طھط¨ط·ط© ط¨ط§ظ„ط´ط¨ظƒط©.';
            }
            openModal(modal);
            refreshNetworkBatches(row.id);
        },
    };

    globalTables.fetchNetworks = (params) => fetchTableData(
        `${config.baseUrl}/networks`,
        params,
        (incoming) => {
            const requestData = incoming.data ?? {};
            const pagination = buildPaginationParams(requestData);
            const query = {
                per_page: pagination.limit,
                page: pagination.page,
            };
            if (requestData.sort) {
                query.sort = requestData.sort;
                query.direction = requestData.order ?? 'desc';
            }
            if (state.filters.networkStatus) {
                query.status = state.filters.networkStatus;
            }
            if (state.filters.networkSearch) {
                query.q = state.filters.networkSearch;
            }
            return query;
        },
    );

    globalTables.networkQueryParams = (params) => params;

    globalTables.transformNetworkResponse = (response) => {
        const normalized = normalizeBootstrapResponse(response);
        return {
            total: normalized.total,
            rows: normalized.rows.map(prepareNetworkRow),
        };
    };

    globalTables.fetchReports = (params) => fetchTableData(
        `${config.baseUrl}/reports`,
        params,
        (incoming) => {
            const requestData = incoming.data ?? {};
            const pagination = buildPaginationParams(requestData);
            const query = {
                per_page: pagination.limit,
                page: pagination.page,
            };
            if (requestData.sort) {
                query.sort = requestData.sort;
                query.direction = requestData.order ?? 'desc';
            }
            if (state.filters.reportStatus) {
                query.status = state.filters.reportStatus;
            }
            if (state.filters.reportNetwork) {
                query.network_id = state.filters.reportNetwork;
            }
            return query;
        },
    );

    globalTables.reportQueryParams = (params) => params;

    globalTables.transformReportResponse = (response) => {
        const normalized = normalizeBootstrapResponse(response);
        return {
            total: normalized.total,
            rows: normalized.rows.map(prepareReportRow),
        };
    };

    globalTables.formatReportStatus = (value) => {
        const badge = reportBadgeClasses[value] ?? 'bg-light text-dark';
        const label = reportStatusLabels[value] ?? value ?? 'â€”';
        return `<span class="badge ${badge}">${label}</span>`;
    };

    globalTables.formatReportActions = () => `
    <div class="btn-group btn-group-sm" role="group">
        <button type="button" class="btn btn-outline-primary" data-action="view-report" title="ط¹ط±ط¶ ط§ظ„ط¨ظ„ط§ط؛">
            <i class="bi bi-eye"></i>
        </button>
        <button type="button" class="btn btn-outline-secondary dropdown-toggle dropdown-toggle-split" data-bs-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
            <span class="visually-hidden">طھط؛ظٹظٹط± ط§ظ„ط­ط§ظ„ط©</span>
        </button>
        <ul class="dropdown-menu dropdown-menu-end">
            <li><button class="dropdown-item" data-action="report-status" data-status="open">${reportStatusLabels.open}</button></li>
            <li><button class="dropdown-item" data-action="report-status" data-status="investigating">${reportStatusLabels.investigating}</button></li>
            <li><button class="dropdown-item" data-action="report-status" data-status="resolved">${reportStatusLabels.resolved}</button></li>
            <li><button class="dropdown-item" data-action="report-status" data-status="dismissed">${reportStatusLabels.dismissed}</button></li>
        </ul>
    </div>
`;

    globalTables.reportActionEvents = {
        'click [data-action="view-report"]'(event, value, row) {
            const messageParts = [row.title, row.description].filter(Boolean);
            const message = messageParts.join('\n\n');
            if (message) {
                window.alert(message);
            } else {
                window.alert('ظ„ط§ طھظˆط¬ط¯ طھظپط§طµظٹظ„ ط¥ط¶ط§ظپظٹط© ظ„ظ‡ط°ط§ ط§ظ„ط¨ظ„ط§ط؛.');
            }
        },
        'click [data-action="report-status"]'(event, value, row) {
            const targetStatus = event.currentTarget?.getAttribute('data-status');
            if (!targetStatus) {
                return;
            }
            const confirmChange = window.confirm(`ظ‡ظ„ طھط±ط؛ط¨ ط¨طھط­ط¯ظٹط« ط­ط§ظ„ط© ط§ظ„ط¨ظ„ط§ط؛ ط¥ظ„ظ‰ "${reportStatusLabels[targetStatus] ?? targetStatus}"طں`);
            if (!confirmChange) {
                return;
            }
            sendPatch(`${config.baseUrl}/reports/${row.id}`, { status: targetStatus })
                .then(() => {
                    toasts.success('طھظ… طھط­ط¯ظٹط« ط­ط§ظ„ط© ط§ظ„ط¨ظ„ط§ط؛ ط¨ظ†ط¬ط§ط­.');
                    state.tables.reports?.bootstrapTable('refresh');
                })
                .catch((error) => {
                    toasts.error(parseErrorMessage(error));
                });
        },
    };

    globalTables.formatBatchStatus = (value) => {
        const badge = batchBadgeClasses[value] ?? 'bg-light text-dark';
        const label = batchStatusLabels[value] ?? value ?? 'â€”';
        return `<span class="badge ${badge}">${label}</span>`;
    };

    globalTables.formatBatchActions = () => `
    <div class="btn-group btn-group-sm" role="group">
        <button type="button" class="btn btn-outline-primary" data-action="open-batch" title="ط¹ط±ط¶ ط§ظ„طھظپط§طµظٹظ„">
            <i class="bi bi-eye"></i>
        </button>
        <button type="button" class="btn btn-outline-success" data-action="activate-batch" title="طھظپط¹ظٹظ„">
            <i class="bi bi-check-circle"></i>
        </button>
    </div>
`;

    globalTables.batchActionEvents = {
        'click [data-action="open-batch"]'(event, value, row) {
            const message = `ط§ظ„ظˆط³ظ…: ${row.label}\nط§ظ„ط®ط·ط©: ${row.plan ?? 'â€”'}\nط§ظ„ط¥ط¬ظ…ط§ظ„ظٹ: ${row.total_codes ?? 0}`;
            window.alert(message);
        },
        'click [data-action="activate-batch"]'(event, value, row) {
            if (!row?.id) {
                return;
            }
            const endpoint = `${config.ownerBaseUrl}/batches/${row.id}/status`;
            const confirmed = window.confirm('ط³ظٹطھظ… طھط­ط¯ظٹط« ط­ط§ظ„ط© ط§ظ„ط¯ظپط¹ط© ط¥ظ„ظ‰ \"active\"طŒ ظ‡ظ„ طھط±ط؛ط¨ ط¨ط§ظ„ط§ط³طھظ…ط±ط§ط±طں');
            if (!confirmed) {
                return;
            }
            sendPatch(endpoint, { status: 'active' })
                .then(() => {
                    toasts.success('طھظ… ط¥ط±ط³ط§ظ„ ط·ظ„ط¨ طھظپط¹ظٹظ„ ط§ظ„ط¯ظپط¹ط©.');
                    refreshNetworkBatches(state.selectedNetwork?.id);
                })
                .catch((error) => {
                    toasts.error(parseErrorMessage(error));
                });
        },
    };

    return globalTables;
}

export { registerTables };

