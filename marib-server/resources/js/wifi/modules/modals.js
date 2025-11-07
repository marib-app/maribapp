import { axios, batchStatusLabels, bootstrap, config, statusLabels, toasts } from './core';
import { formatDateValue, formatNumber, parseErrorMessage } from './utils';

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
    const subtitleMessage = 'عرض تفاصيل الشبكة والعملاء المتاحة.';
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
                plansContainer.innerHTML = '<p class="text-muted mb-0">لا توجد خطط متاحة لهذه الشبكة.</p>';
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
                batchesContainer.innerHTML = '<p class="text-muted mb-0">لا توجد دفعات مرتبطة بالشبكة.</p>';
            }
        }

        if (batchesCountBadge) {
            batchesCountBadge.textContent = String(batches.length);
        }
    } catch (error) {
        toasts.error(parseErrorMessage(error));
    }
}

export { closeModal, loadNetworkAssociations, openModal, updateNetworkModalDetails };
