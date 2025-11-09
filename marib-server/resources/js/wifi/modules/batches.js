import { $, axios, config, ensureSanctumCsrfCookie, toasts } from './core';
import { parseErrorMessage } from './utils';

function refreshNetworkBatches(networkId) {
    const table = $('#wifi-network-batches-table');
    if (!table.length || !networkId) {
        return;
    }

    table.bootstrapTable('removeAll');

    ensureSanctumCsrfCookie()
        .then(() => axios.get(`${config.ownerBaseUrl}/networks/${networkId}`))
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

    ensureSanctumCsrfCookie()
        .then(() => axios.get(`${config.baseUrl}/reports`, { params: { per_page: 5 } }))
        .then(() => {
            // Placeholder request so axios permissions stay active until dedicated batches API is ready.
        })
        .catch(() => {
            // Ignore silently for now.
        });
}

export { hydrateBatchesTable, refreshNetworkBatches };
