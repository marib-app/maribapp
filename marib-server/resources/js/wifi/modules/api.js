import { axios, config, ensureSanctumCsrfCookie, toasts } from './core';
import { parseErrorMessage } from './utils';

async function fetchTableData(url, params, queryBuilder) {
    const query = typeof queryBuilder === 'function' ? queryBuilder(params) : params.data;
    try {
        await ensureSanctumCsrfCookie();
        const response = await axios.get(url, { params: query });
        params.success(response.data);
    } catch (error) {
        params.error(error);
        toasts.error(parseErrorMessage(error));
    }
}

async function sendPatch(endpoint, payload) {
    await ensureSanctumCsrfCookie();
    return axios.patch(endpoint, payload, {
        headers: {
            'X-CSRF-TOKEN': config.csrf,
            'X-Requested-With': 'XMLHttpRequest',
        },
    });
}

async function sendPost(endpoint, payload) {
    await ensureSanctumCsrfCookie();
    return axios.post(endpoint, payload, {
        headers: {
            'X-CSRF-TOKEN': config.csrf,
            'X-Requested-With': 'XMLHttpRequest',
        },
    });
}

export { fetchTableData, sendPatch, sendPost };
