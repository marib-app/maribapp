import { config, state, toasts } from './core';
import { closeModal } from './modals';
import { sendPatch } from './api';
import { parseErrorMessage } from './utils';

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
                const message = parseErrorMessage(error);
                if (feedback) {
                    feedback.textContent = message;
                }
                toasts.error(message);
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
                const message = parseErrorMessage(error);
                if (feedback) {
                    feedback.textContent = message;
                }
                toasts.error(message);
            });
    });
}

export { setupCommissionForm, setupStatusForm };
