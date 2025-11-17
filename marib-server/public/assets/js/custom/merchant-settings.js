(function () {
    const codSwitch = document.getElementById('allowCodSwitch');
    if (!codSwitch) {
        return;
    }

    codSwitch.addEventListener('change', function (event) {
        if (!event.target.checked) {
            return;
        }

        const warningTitle = codSwitch.dataset.codWarningTitle || '';
        const warningMessage = codSwitch.dataset.codWarning || '';
        const confirmText = codSwitch.dataset.codConfirmText || 'Confirm';
        const cancelText = codSwitch.dataset.codCancelText || 'Cancel';

        if (typeof window.Swal === 'undefined') {
            const confirmed = window.confirm(warningMessage);
            if (!confirmed) {
                event.target.checked = false;
            }
            return;
        }

        window.Swal.fire({
            icon: 'warning',
            title: warningTitle || undefined,
            text: warningMessage,
            showCancelButton: true,
            confirmButtonText: confirmText,
            cancelButtonText: cancelText,
            reverseButtons: true,
        }).then((result) => {
            if (!result.isConfirmed) {
                event.target.checked = false;
            }
        });
    });

    const methodSelect = document.getElementById('walletWithdrawalMethod');
    if (methodSelect) {
        const methodFieldSets = document.querySelectorAll('[data-wallet-method-fields]');

        const toggleMethodFields = () => {
            const current = methodSelect.value;
            methodFieldSets.forEach((wrapper) => {
                if (wrapper.getAttribute('data-wallet-method-fields') === current) {
                    wrapper.style.removeProperty('display');
                } else {
                    wrapper.style.setProperty('display', 'none');
                }
            });
        };

        methodSelect.addEventListener('change', toggleMethodFields);
        toggleMethodFields();
    }
})();
