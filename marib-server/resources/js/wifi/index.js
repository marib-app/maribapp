import axios from 'axios';

const $ = window.jQuery;
const bootstrap = window.bootstrap || {};

const config = {
    baseUrl: '/api/wifi/admin',
    ownerBaseUrl: '/api/wifi/owner',
    csrf: document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') ?? '',
};

const state = {
    filters: {
        networkSearch: '',
        networkStatus: '',
        reportStatus: '',
        reportNetwork: '',
    },
    selectedNetwork: null,
    selectedReport: null,
    tables: {},
};

const statusLabels = {
    active: 'نشط',
    inactive: 'متوقف',
    suspended: 'معلّق',
};

const statusBadgeClasses = {
    active: 'bg-success text-white',
    inactive: 'bg-secondary text-white',
    suspended: 'bg-warning text-dark',
};

const reportStatusLabels = {
    open: 'مفتوح',
    investigating: 'قيد المتابعة',
    resolved: 'تم الحل',
    dismissed: 'مرفوض',
};

const reportBadgeClasses = {
    open: 'bg-danger text-white',
    investigating: 'bg-warning text-dark',
    resolved: 'bg-success text-white',
    dismissed: 'bg-secondary text-white',
};

const batchStatusLabels = {
    uploaded: 'مرفوع',
    validated: 'قيد المراجعة',
    active: 'مفعل',
    archived: 'مؤرشف',
};

const batchBadgeClasses = {
    uploaded: 'bg-secondary text-white',
    validated: 'bg-info text-dark',
    active: 'bg-success text-white',
    archived: 'bg-dark text-white',
};

const toasts = {
    success(message) {
        if (typeof window.showSuccessToast === 'function') {
            window.showSuccessToast(message);
        } else {
            console.info(message);
        }
    },
    error(message) {
        if (typeof window.showErrorToast === 'function') {
            window.showErrorToast(message);
        } else {
            console.error(message);
        }
    },
};

function debounce(fn, delay = 300) {
    let timeout;
    return (...args) => {
        clearTimeout(timeout);
        timeout = window.setTimeout(() => fn.apply(null, args), delay);
    };
}

function formatNumber(value) {
    const number = Number.parseFloat(value);
    if (Number.isNaN(number)) {
        return '—';
    }
    return number.toLocaleString(undefined, { maximumFractionDigits: 2 });
}

function formatDateValue(value) {
    if (!value) {
        return '—';
    }
    try {
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) {
            return value;
        }
        return date.toLocaleString();
    } catch (error) {
        return value;
    }
}

function parseErrorMessage(error) {
    if (!error) {
        return 'حدث خطأ غير متوقع.';
    }

    if (error.response?.data) {
        const data = error.response.data;
        if (typeof data.message === 'string') {
            return data.message;
        }
        if (data.errors && typeof data.errors === 'object') {
            return Object.values(data.errors).flat().join(' ');
        }
    }

    if (error.message) {
        return error.message;
    }

    return 'حدث خطأ غير متوقع.';
}

function normalizeBootstrapResponse(payload) {
    if (!payload || typeof payload !== 'object') {
        return { total: 0, rows: [] };
    }

    if (Array.isArray(payload)) {
        return { total: payload.length, rows: payload };
    }

    if (Array.isArray(payload.rows) && typeof payload.total === 'number') {
        return { total: payload.total, rows: payload.rows };
    }

    if (Array.isArray(payload.data)) {
        const total = payload.total ?? payload.meta?.total ?? payload.data.length;
        return { total, rows: payload.data };
    }

    const rows = payload.items ?? payload.list ?? [];
    const total = payload.total ?? payload.meta?.total ?? rows.length;
    return { total, rows };
}

function buildPaginationParams(params) {
    const limit = Number.parseInt(params.limit ?? 10, 10);
    const offset = Number.parseInt(params.offset ?? 0, 10);
    const page = limit > 0 ? Math.floor(offset / limit) + 1 : 1;

    return { limit, offset, page };
}

function prepareNetworkRow(row) {
    const meta = row.meta ?? {};
    const settings = row.settings ?? {};
    const statistics = row.statistics ?? meta.statistics ?? {};
    const coverage = row.coverage_radius_km ?? meta.coverage_radius_km ?? null;
    const ownerName = meta.owner?.name ?? row.owner?.name ?? '—';
    const ownerEmail = meta.owner?.email ?? row.owner?.email ?? '—';
    const ownerPhone = meta.owner?.mobile ?? meta.owner?.phone ?? '—';

    const codesStats = statistics.codes ?? meta.codes ?? {};
    const sold = codesStats.sold ?? meta.codes_sold ?? null;
    const available = codesStats.available ?? meta.codes_available ?? null;
    const total = codesStats.total ?? meta.codes_total ?? null;

    return {
        ...row,
        owner_name: ownerName,
        owner_email: ownerEmail,
        owner_phone: ownerPhone,
        coverage_radius_km: coverage,
        commission_rate: settings.commission_rate ?? meta.commission_rate ?? null,
        codes_summary: {
            available,
            sold,
            total,
        },
        active_plans: statistics.plans?.active ?? row.active_plans_count ?? row.plan_count ?? null,
    };
}

function prepareReportRow(row) {
    return {
        ...row,
        network_name: row.network?.name ?? row.meta?.network_name ?? `#${row.network_id ?? '—'}`,
        created_at: row.created_at ?? row.reported_at ?? row.updated_at,
    };
}

async function fetchTableData(url, params, queryBuilder) {
    const query = typeof queryBuilder === 'function' ? queryBuilder(params) : params.data;
    try {
        const response = await axios.get(url, { params: query });
        params.success(response.data);
    } catch (error) {
        params.error(error);
        toasts.error(parseErrorMessage(error));
    }
}

async function sendPatch(endpoint, payload) {
    return axios.patch(endpoint, payload, {
        headers: {
            'X-CSRF-TOKEN': config.csrf,
            'X-Requested-With': 'XMLHttpRequest',
        },
    });
}

async function sendPost(endpoint, payload) {
    return axios.post(endpoint, payload, {
        headers: {
            'X-CSRF-TOKEN': config.csrf,
            'X-Requested-With': 'XMLHttpRequest',
        },
    });
}

function updateNetworkModalDetails(row) {
    const modal = document.querySelector('[data-wifi-network-modal]');
    if (!modal || !row) {
        return;
    }

    const setText = (selector, value) => {
        const element = modal.querySelector(selector);
        if (!element) {
            return;
        }
        element.textContent = value ?? '—';
    };

    setText('[data-network-name]', row.name ?? '—');
    const subtitleMessage = 'عرض تفاصيل الشبكة والعمليات المتاحة.';
    setText('[data-network-subtitle]', row.slug ? `#${row.slug}` : subtitleMessage);
    setText('[data-network-status-label]', statusLabels[row.status] ?? row.status ?? '—');

    const commission = row.commission_rate ?? row.settings?.commission_rate ?? row.meta?.commission_rate;
    setText('[data-network-commission]', commission !== undefined && commission !== null ? `${formatNumber(commission * 100)}%` : '—');

    setText('[data-network-address]', row.address ?? row.meta?.address ?? '—');
    setText('[data-network-owner]', row.owner_name ?? row.meta?.owner?.name ?? '—');
    setText('[data-network-owner-email]', row.owner_email ?? row.meta?.owner?.email ?? '—');
    setText('[data-network-owner-phone]', row.owner_phone ?? row.meta?.owner?.mobile ?? '—');
    setText('[data-network-support-channel]', row.meta?.support_channel ?? '—');
    setText('[data-network-active-plans]', formatNumber(row.active_plans ?? 0));

    const codes = row.codes_summary ?? {};
    setText('[data-network-total-codes]', formatNumber(codes.total ?? 0));
    setText('[data-network-available-codes]', formatNumber(codes.available ?? 0));
    setText('[data-network-sold-codes]', formatNumber(codes.sold ?? 0));

    const updatedAt = row.updated_at ?? row.created_at;
    setText('[data-network-updated-at]', formatDateValue(updatedAt));

    const logo = modal.querySelector('[data-network-logo]');
    if (logo) {
        const fallback = logo.getAttribute('data-custom-image') ?? logo.getAttribute('src');
        logo.setAttribute('src', row.icon_path ?? row.meta?.icon_path ?? fallback);
    }

    const mapWrapper = modal.querySelector('[data-network-map]');
    if (mapWrapper) {
        mapWrapper.innerHTML = '';
        const latitude = row.location?.latitude ?? row.meta?.location?.latitude;
        const longitude = row.location?.longitude ?? row.meta?.location?.longitude;
        if (latitude !== undefined && latitude !== null && longitude !== undefined && longitude !== null) {
            const iframe = document.createElement('iframe');
            const encoded = encodeURIComponent(`${latitude},${longitude}`);
            iframe.src = `https://maps.google.com/maps?q=${encoded}&z=14&output=embed`;
            iframe.loading = 'lazy';
            mapWrapper.appendChild(iframe);
        } else {
            const placeholder = document.createElement('div');
            placeholder.className = 'wifi-network-map__placeholder';
            placeholder.innerHTML = '<i class="bi bi-geo-alt-fill"></i><span>لم يتم توفير موقع جغرافي بعد.</span>';
            mapWrapper.appendChild(placeholder);
        }
    }

    const plansContainer = modal.querySelector('[data-network-plans-container]');
    if (plansContainer) {
        plansContainer.innerHTML = '<p class="text-muted mb-0">يتم تحميل البيانات...</p>';
    }

    const batchesContainer = modal.querySelector('[data-network-batches-container]');
    if (batchesContainer) {
        batchesContainer.innerHTML = '<p class="text-muted mb-0">يتم تحميل البيانات...</p>';
    }
}

async function loadNetworkAssociations(networkId) {
    const modal = document.querySelector('[data-wifi-network-modal]');
    if (!modal || !networkId) {
        return;
    }

    const plansContainer = modal.querySelector('[data-network-plans-container]');
    const plansCountBadge = modal.querySelector('[data-network-plans-count]');
    const batchesContainer = modal.querySelector('[data-network-batches-container]');
    const batchesCountBadge = modal.querySelector('[data-network-batches-count]');

    try {
        const response = await axios.get(`${config.ownerBaseUrl}/networks/${networkId}`);
        const resource = response.data?.data ?? response.data;
        const plans = resource?.plans ?? [];

        if (plansContainer) {
            if (Array.isArray(plans) && plans.length > 0) {
                plansContainer.innerHTML = '';
                plans.forEach((plan) => {
                    const item = document.createElement('div');
                    item.className = 'wifi-network-plans__item';
                    item.innerHTML = `
                        <div>
                            <strong>${plan.name ?? '—'}</strong>
                            <div class="text-muted small">${plan.status ?? ''}</div>
                        </div>
                        <div class="text-end">
                            <div>${formatNumber(plan.price ?? 0)} ${plan.currency ?? ''}</div>
                            <div class="text-muted small">${formatNumber(plan.code_batches_count ?? plan.meta?.code_batches_count ?? 0)} دفعات</div>
                        </div>
                    `;
                    plansContainer.appendChild(item);
                });
            } else {
                plansContainer.innerHTML = '<p class="text-muted mb-0">لا توجد خطط متاحة للشبكة.</p>';
            }
        }

        if (plansCountBadge) {
            plansCountBadge.textContent = String(plans?.length ?? 0);
        }

        const batches = plans?.flatMap((plan) => plan.code_batches ?? []) ?? [];
        if (batchesContainer) {
            if (batches.length > 0) {
                batchesContainer.innerHTML = '';
                batches.slice(0, 5).forEach((batch) => {
                    const item = document.createElement('div');
                    item.className = 'wifi-network-plans__item';
                    item.innerHTML = `
                        <div>
                            <strong>${batch.label ?? '—'}</strong>
                            <div class="text-muted small">${batchStatusLabels[batch.status] ?? batch.status ?? '—'}</div>
                        </div>
                        <div class="text-end">
                            <div>${formatNumber(batch.available_codes ?? 0)} / ${formatNumber(batch.total_codes ?? 0)}</div>
                            <div class="text-muted small">${formatDateValue(batch.created_at)}</div>
                        </div>
                    `;
                    batchesContainer.appendChild(item);
                });
            } else {
                batchesContainer.innerHTML = '<p class="text-muted mb-0">لا توجد دفعات مسجلة لهذه الشبكة.</p>';
            }
        }

        if (batchesCountBadge) {
            batchesCountBadge.textContent = String(batches.length);
        }
    } catch (error) {
        if (plansContainer) {
            plansContainer.innerHTML = '<p class="text-danger mb-0">تعذر تحميل الخطط المرتبطة.</p>';
        }
        if (batchesContainer) {
            batchesContainer.innerHTML = '<p class="text-danger mb-0">تعذر تحميل دفعات الأكواد.</p>';
        }
        toasts.error(parseErrorMessage(error));
    }
}

function openModal(element) {
    if (!element) {
        return null;
    }
    const modalInstance = bootstrap.Modal ? bootstrap.Modal.getOrCreateInstance(element) : null;
    modalInstance?.show();
    return modalInstance;
}

function closeModal(element) {
    if (!element) {
        return;
    }
    const modalInstance = bootstrap.Modal ? bootstrap.Modal.getInstance(element) : null;
    modalInstance?.hide();
}

const globalTables = window.MaribWifiAdminTables ?? (window.MaribWifiAdminTables = {});

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
            subtitle.textContent = row.name ? `دفعات الأكواد للشبكة: ${row.name}` : 'دفعات الأكواد المرتبطة بالشبكة.';
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
    'click [data-action="report-status"]'(event, value, row, index) {
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
        const confirmed = window.confirm('سيتم تحديث حالة الدفعة إلى "active"، هل ترغب بالاستمرار؟');
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

function refreshNetworkBatches(networkId) {
    const table = $('#wifi-network-batches-table');
    if (!table.length || !networkId) {
        return;
    }

    table.bootstrapTable('removeAll');

    axios.get(`${config.ownerBaseUrl}/networks/${networkId}`)
        .then((response) => {
            const resource = response.data?.data ?? response.data;
            const batches = (resource?.plans ?? []).flatMap((plan) => {
                const planName = plan.name ?? '—';
                return (plan.code_batches ?? []).map((batch) => ({
                    ...batch,
                    plan: planName,
                }));
            });
            if (Array.isArray(batches)) {
                table.bootstrapTable('append', batches);
            }
        })
        .catch((error) => {
            toasts.error(parseErrorMessage(error));
        });
}

function hydrateBatchesTable() {
    const table = $('#wifi-batches-table');
    if (!table.length) {
        return;
    }

    axios.get(`${config.baseUrl}/reports`, { params: { per_page: 5 } })
        .then(() => {
            // Placeholder to ensure axios has permission; real batches endpoint to be integrated later.
        })
        .catch(() => {
            // Ignore silently; table will remain empty until API is provided.
        });
}

function setupStatusForm() {
    const form = document.querySelector('[data-network-status-form]');
    if (!form) {
        return;
    }

    form.addEventListener('submit', (event) => {
        event.preventDefault();
        if (!state.selectedNetwork?.id) {
            toasts.error('يرجى اختيار شبكة أولاً.');
            return;
        }
        const status = form.querySelector('[name="status"]').value;
        const reason = form.querySelector('[name="reason"]').value;
        const feedback = form.querySelector('[data-network-status-feedback]');
        if (feedback) {
            feedback.textContent = 'جاري معالجة الطلب...';
        }
        sendPatch(`${config.baseUrl}/networks/${state.selectedNetwork.id}/status`, { status, reason })
            .then(() => {
                if (feedback) {
                    feedback.textContent = 'تم تحديث الحالة بنجاح.';
                }
                toasts.success('تم تحديث حالة الشبكة.');
                state.tables.networks?.bootstrapTable('refresh');
                closeModal(document.querySelector('[data-wifi-status-modal]'));
            })
            .catch((error) => {
                if (feedback) {
                    feedback.textContent = parseErrorMessage(error);
                }
                toasts.error(parseErrorMessage(error));
            });
    });
}

function setupCommissionForm() {
    const form = document.querySelector('[data-network-commission-form]');
    if (!form) {
        return;
    }

    form.addEventListener('submit', (event) => {
        event.preventDefault();
        if (!state.selectedNetwork?.id) {
            toasts.error('يرجى اختيار شبكة أولاً.');
            return;
        }
        const rateField = form.querySelector('[name="commission_rate"]');
        const feedback = form.querySelector('[data-network-commission-feedback]');
        const percent = Number.parseFloat(rateField?.value ?? '0');
        if (Number.isNaN(percent)) {
            toasts.error('يرجى إدخال قيمة صالحة.');
            return;
        }
        if (feedback) {
            feedback.textContent = 'جاري تحديث العمولة...';
        }
        const payload = { commission_rate: percent / 100 };
        sendPatch(`${config.ownerBaseUrl}/networks/${state.selectedNetwork.id}/commission`, payload)
            .then(() => {
                if (feedback) {
                    feedback.textContent = 'تم تحديث العمولة بنجاح.';
                }
                toasts.success('تم تحديث عمولة الشبكة.');
                state.tables.networks?.bootstrapTable('refresh');
                closeModal(document.querySelector('[data-wifi-commission-modal]'));
            })
            .catch((error) => {
                if (feedback) {
                    feedback.textContent = parseErrorMessage(error);
                }
                toasts.error(parseErrorMessage(error));
            });
    });
}

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

function initWifiAdmin() {
    const root = document.querySelector('[data-wifi-admin-root]');
    if (!root || root.dataset.initialized || typeof $ === 'undefined') {
        return;
    }

    root.dataset.initialized = 'true';
    config.baseUrl = root.dataset.baseUrl || config.baseUrl;
    config.ownerBaseUrl = root.dataset.ownerBaseUrl || config.ownerBaseUrl;

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