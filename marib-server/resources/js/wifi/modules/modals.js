import { axios, batchStatusLabels, bootstrap, config, state, statusLabels, toasts } from './core';
import { formatDateValue, formatNumber, parseErrorMessage } from './utils';

const CONTACT_TYPE_LABELS = {
    owner: 'مالك الشبكة',
    manager: 'المسؤول',
    phone: 'الهاتف',
    whatsapp: 'واتساب',
    email: 'البريد الإلكتروني',
    support: 'قناة الدعم',
};

const LOADING_TEXT = 'جارٍ تحميل البيانات...';
const NO_CONTACTS_TEXT = 'لا تتوفر بيانات اتصال.';
const NO_DETAILS_TEXT = 'لا توجد تفاصيل إضافية.';
const NO_PLANS_TEXT = 'لا توجد خطط بعد.';
const NO_BATCHES_TEXT = 'لا توجد دفعات مرتبطة.';

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

function setText(modal, selector, value, formatter = (val) => (val ?? '—')) {
    const element = modal.querySelector(selector);
    if (element) {
        element.textContent = formatter(value);
    }
}

function updateNetworkModalDetails(row) {
    const modal = document.querySelector('[data-wifi-network-modal]');
    if (!modal || !row) {
        return;
    }

    setText(modal, '[data-network-name]', row.name);
    setText(modal, '[data-network-subtitle]', row.slug ? `#${row.slug}` : NO_DETAILS_TEXT);
    setText(modal, '[data-network-status-label]', statusLabels[row.status] ?? row.status ?? '—');

    const commission = row.commission_rate ?? row.settings?.commission_rate ?? row.meta?.commission_rate;
    setText(modal, '[data-network-commission]', commission, (value) => (
        value !== undefined && value !== null ? `${formatNumber(value * 100)}%` : '—'
    ));

    setText(modal, '[data-network-address]', row.address ?? row.meta?.address);
    setText(modal, '[data-network-owner]', row.owner_name ?? row.meta?.owner?.name);
    setText(modal, '[data-network-owner-email]', row.owner_email ?? row.meta?.owner?.email);
    setText(modal, '[data-network-owner-phone]', row.owner_phone ?? row.meta?.owner?.mobile);
    setText(modal, '[data-network-support-channel]', row.meta?.support_channel);

    const updatedAt = row.updated_at ?? row.created_at;
    setText(modal, '[data-network-updated-at]', formatDateValue(updatedAt));

    const logo = modal.querySelector('[data-network-logo]');
    if (logo) {
        const fallback = logo.getAttribute('data-custom-image') ?? logo.getAttribute('src');
        logo.setAttribute('src', row.icon_path ?? row.meta?.icon_path ?? fallback);
    }

    applyNetworkStats(modal, row.statistics, row);
    renderContactList(modal, row.contacts);

    const plansContainer = modal.querySelector('[data-network-plans-container]');
    if (plansContainer) {
        plansContainer.innerHTML = `<p class="text-muted mb-0">${LOADING_TEXT}</p>`;
    }

    const batchesContainer = modal.querySelector('[data-network-batches-container]');
    if (batchesContainer) {
        batchesContainer.innerHTML = `<p class="text-muted mb-0">${LOADING_TEXT}</p>`;
    }
}

function applyNetworkStats(modal, statistics = {}, fallbackRow = {}) {
    const plansStats = statistics.plans ?? {};
    const codesStats = statistics.codes ?? fallbackRow.codes_summary ?? {};

    setText(modal, '[data-network-active-plans]', plansStats.active ?? fallbackRow.active_plans_count ?? 0, formatNumber);
    setText(modal, '[data-network-total-codes]', codesStats.total ?? 0, formatNumber);
    setText(modal, '[data-network-available-codes]', codesStats.available ?? 0, formatNumber);
    setText(modal, '[data-network-sold-codes]', codesStats.sold ?? 0, formatNumber);
}

function renderContactList(modal, contacts) {
    const list = modal.querySelector('[data-network-contacts]');
    if (!list) {
        return;
    }

    const contactItems = Array.isArray(contacts) ? contacts : [];
    if (contactItems.length === 0) {
        list.innerHTML = `<li class="wifi-network-info__item text-muted">${NO_CONTACTS_TEXT}</li>`;
        return;
    }

    list.innerHTML = '';
    contactItems.forEach((contact) => {
        const item = document.createElement('li');
        item.className = 'wifi-network-info__item';
        const label = CONTACT_TYPE_LABELS[contact.type] ?? contact.type ?? '—';
        const value = contact.value ?? '—';
        item.innerHTML = `<span>${label}</span><span>${value}</span>`;
        list.appendChild(item);
    });
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
        const merged = { ...state.selectedNetwork, ...resource };
        state.selectedNetwork = merged;
        updateNetworkModalDetails(merged);

        const plans = resource?.plans ?? [];
        if (plansContainer) {
            if (plans.length > 0) {
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
                plansContainer.innerHTML = `<p class="text-muted mb-0">${NO_PLANS_TEXT}</p>`;
            }
        }

        if (plansCountBadge) {
            plansCountBadge.textContent = String(plans.length);
        }

        const batches = plans.flatMap((plan) => plan.code_batches ?? []);
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
                batchesContainer.innerHTML = `<p class="text-muted mb-0">${NO_BATCHES_TEXT}</p>`;
            }
        }

        if (batchesCountBadge) {
            batchesCountBadge.textContent = String(batches.length);
        }

        const statistics = buildStatisticsFromPlans(plans, batches);
        applyNetworkStats(modal, statistics, merged);
        renderContactList(modal, resource.contacts ?? merged.contacts);
    } catch (error) {
        toasts.error(parseErrorMessage(error));
    }
}

function buildStatisticsFromPlans(plans, batches) {
    const activePlans = plans.filter((plan) => (plan.status ?? '').toLowerCase() === 'active').length;
    const totalPlans = plans.length;

    const codes = batches.reduce((acc, batch) => {
        const total = Number(batch.total_codes ?? 0);
        const available = Number(batch.available_codes ?? 0);
        acc.total += total;
        acc.available += available;
        acc.sold += Math.max(total - available, 0);
        return acc;
    }, { total: 0, available: 0, sold: 0 });

    return {
        plans: {
            active: activePlans,
            total: totalPlans,
        },
        codes,
    };
}

export { closeModal, loadNetworkAssociations, openModal, updateNetworkModalDetails };
