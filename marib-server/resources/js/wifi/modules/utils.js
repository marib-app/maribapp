const EMPTY_SYMBOL = '—';

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
        return EMPTY_SYMBOL;
    }
    return number.toLocaleString(undefined, { maximumFractionDigits: 2 });
}

function formatDateValue(value) {
    if (!value) {
        return EMPTY_SYMBOL;
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
    const ownerName = row.owner_name ?? row.owner?.name ?? meta.owner?.name ?? EMPTY_SYMBOL;
    const ownerEmail = row.owner_email ?? row.owner?.email ?? meta.owner?.email ?? EMPTY_SYMBOL;
    const ownerPhone = row.owner?.mobile ?? row.owner?.phone ?? meta.owner?.mobile ?? meta.owner?.phone ?? EMPTY_SYMBOL;

    const codesStats = row.codes_summary ?? statistics.codes ?? meta.codes ?? {};
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
        network_name: row.network?.name ?? row.meta?.network_name ?? `#${row.network_id ?? EMPTY_SYMBOL}`,
        created_at: row.created_at ?? row.reported_at ?? row.updated_at,
    };
}

export {
    buildPaginationParams,
    debounce,
    formatDateValue,
    formatNumber,
    normalizeBootstrapResponse,
    parseErrorMessage,
    prepareNetworkRow,
    prepareReportRow,
};
