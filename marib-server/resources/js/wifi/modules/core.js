import axios from 'axios';

const $ = window.jQuery;
const bootstrap = window.bootstrap || {};

const config = {
    baseUrl: '/api/wifi/admin',
    ownerBaseUrl: '/api/wifi/owner',
    csrf: document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') ?? '',
    detailUrlTemplate: '',
};

axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';
axios.defaults.withCredentials = true;
if (config.csrf) {
    axios.defaults.headers.common['X-CSRF-TOKEN'] = config.csrf;
}

let sanctumCsrfCookiePromise = null;

function ensureSanctumCsrfCookie() {
    if (sanctumCsrfCookiePromise) {
        return sanctumCsrfCookiePromise;
    }
    sanctumCsrfCookiePromise = axios.get('/sanctum/csrf-cookie', {
        withCredentials: true,
    }).catch((error) => {
        console.error('Failed to initialize Sanctum CSRF cookie', error);
        sanctumCsrfCookiePromise = null;
        throw error;
    });
    return sanctumCsrfCookiePromise;
}

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

export {
    $,
    axios,
    batchBadgeClasses,
    batchStatusLabels,
    bootstrap,
    config,
    reportBadgeClasses,
    reportStatusLabels,
    state,
    statusBadgeClasses,
    statusLabels,
    toasts,
    ensureSanctumCsrfCookie,
};
