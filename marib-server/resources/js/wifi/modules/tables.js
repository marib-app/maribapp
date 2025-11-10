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
        const label = statusLabels[value] ?? value ?? '—';
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
            <small class="text-muted">متاح: ${available} | مبيع: ${sold}</small>
        </div>
    `;
    };

    globalTables.formatCommission = (value, row) => {
        const commission = value ?? row.commission_rate ?? row.settings?.commission_rate;
        if (commission === undefined || commission === null) {
            return '<span class="text-muted">—</span>';
        }
        const percent = Number.parseFloat(commission) * 100;
        return `${percent.toFixed(2)}%`;
    };

    globalTables.formatNetworkActions = () => `
    <div class="btn-group btn-group-sm" role="group">
        <button type="button" class="btn btn-outline-primary" data-action="view-network" title="عرض التفاصيل">
            <i class="bi bi-eye"></i>
        </button>
        <button type="button" class="btn btn-outline-warning" data-action="edit-status" title="تحديث الحالة">
            <i class="bi bi-shield-check"></i>
        </button>
        <button type="button" class="btn btn-outline-success" data-action="edit-commission" title="تعديل العمولة">
            <i class="bi bi-cash-stack"></i>
        </button>
        <button type="button" class="btn btn-outline-secondary" data-action="manage-batches" title="إدارة الدفعات">
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
                    ? `دفعات الأكواد للشبكة: ${row.name}`
                    : 'دفعات الأكواد المرتبطة بالشبكة.';
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
        const label = reportStatusLabels[value] ?? value ?? '—';
        return `<span class="badge ${badge}">${label}</span>`;
    };

    globalTables.formatReportActions = () => `
    <div class="btn-group btn-group-sm" role="group">
        <button type="button" class="btn btn-outline-primary" data-action="view-report" title="عرض البلاغ">
            <i class="bi bi-eye"></i>
        </button>
        <button type="button" class="btn btn-outline-secondary dropdown-toggle dropdown-toggle-split" data-bs-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
            <span class="visually-hidden">تغيير الحالة</span>
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
                window.alert('لا توجد تفاصيل إضافية لهذا البلاغ.');
            }
        },
        'click [data-action="report-status"]'(event, value, row) {
            const targetStatus = event.currentTarget?.getAttribute('data-status');
            if (!targetStatus) {
                return;
            }
            const confirmChange = window.confirm(`هل ترغب بتحديث حالة البلاغ إلى "${reportStatusLabels[targetStatus] ?? targetStatus}"؟`);
            if (!confirmChange) {
                return;
            }
            sendPatch(`${config.baseUrl}/reports/${row.id}`, { status: targetStatus })
                .then(() => {
                    toasts.success('تم تحديث حالة البلاغ بنجاح.');
                    state.tables.reports?.bootstrapTable('refresh');
                })
                .catch((error) => {
                    toasts.error(parseErrorMessage(error));
                });
        },
    };

    globalTables.formatBatchStatus = (value) => {
        const badge = batchBadgeClasses[value] ?? 'bg-light text-dark';
        const label = batchStatusLabels[value] ?? value ?? '—';
        return `<span class="badge ${badge}">${label}</span>`;
    };

    globalTables.formatBatchActions = () => `
    <div class="btn-group btn-group-sm" role="group">
        <button type="button" class="btn btn-outline-primary" data-action="open-batch" title="عرض التفاصيل">
            <i class="bi bi-eye"></i>
        </button>
        <button type="button" class="btn btn-outline-success" data-action="activate-batch" title="تفعيل">
            <i class="bi bi-check-circle"></i>
        </button>
    </div>
`;

    globalTables.batchActionEvents = {
        'click [data-action="open-batch"]'(event, value, row) {
            const message = `الوسم: ${row.label}\nالخطة: ${row.plan ?? '—'}\nالإجمالي: ${row.total_codes ?? 0}`;
            window.alert(message);
        },
        'click [data-action="activate-batch"]'(event, value, row) {
            if (!row?.id) {
                return;
            }
            const endpoint = `${config.ownerBaseUrl}/batches/${row.id}/status`;
            const confirmed = window.confirm('سيتم تحديث حالة الدفعة إلى \"active\"، هل ترغب بالاستمرار؟');
            if (!confirmed) {
                return;
            }
            sendPatch(endpoint, { status: 'active' })
                .then(() => {
                    toasts.success('تم إرسال طلب تفعيل الدفعة.');
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
