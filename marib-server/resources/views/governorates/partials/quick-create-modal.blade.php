@push('modals')
    <div class="modal fade" id="governorateQuickCreateModal" tabindex="-1" aria-labelledby="governorateQuickCreateLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="governorateQuickCreateLabel">{{ __('Add governorate') }}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="{{ __('Close') }}"></button>
                </div>
                <div class="modal-body">
                    <div class="alert d-none" role="alert" data-feedback></div>
                    <form id="governorateQuickCreateForm" action="{{ $storeUrl }}" method="post">
                        @csrf
                        <div class="mb-3">
                            <label for="quick_governorate_name" class="form-label">{{ __('Name') }}</label>
                            <input type="text" name="name" id="quick_governorate_name" class="form-control" maxlength="255" required>
                        </div>
                        <div class="mb-3">
                            <label for="quick_governorate_code" class="form-label">{{ __('Code') }}</label>
                            <input type="text" name="code" id="quick_governorate_code" class="form-control text-uppercase" maxlength="20" required placeholder="{{ __('e.g. NATL') }}">
                            <div class="form-text">{{ __('Codes will be converted to uppercase automatically.') }}</div>
                        </div>
                        <div class="form-check form-switch mb-4">
                            <input class="form-check-input" type="checkbox" name="is_active" id="quick_governorate_active" value="1" checked>
                            <label class="form-check-label" for="quick_governorate_active">{{ __('Active') }}</label>
                        </div>
                        <div class="d-grid">
                            <button type="submit" class="btn btn-primary">{{ __('Save governorate') }}</button>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <a href="{{ route('governorates.index') }}" class="btn btn-outline-secondary" target="_blank">
                        {{ __('Manage all governorates') }}
                    </a>
                </div>
            </div>
        </div>
    </div>
@endpush

@push('scripts')
    <script>
        (function () {
            const modalId = 'governorateQuickCreateModal';

            function ensureDefaultSelected(table) {
                const radios = table.querySelectorAll('.default-governorate-radio');
                if (radios.length && !Array.from(radios).some((radio) => radio.checked)) {
                    radios[0].checked = true;
                }
            }

            function attachDefaultHandlers() {
                document.querySelectorAll('.quotes-table').forEach((table) => {
                    if (table.dataset.governorateDefaultBound === 'true') {
                        ensureDefaultSelected(table);
                        return;
                    }

                    table.addEventListener('change', (event) => {
                        if (!event.target.classList.contains('default-governorate-radio')) {
                            return;
                        }

                        table.querySelectorAll('.default-governorate-radio').forEach((radio) => {
                            if (radio !== event.target) {
                                radio.checked = false;
                            }
                        });
                    });

                    table.dataset.governorateDefaultBound = 'true';
                    ensureDefaultSelected(table);
                });
            }

            function resolveNextQuoteIndex(table) {
                const rowCount = table.querySelectorAll('tbody tr').length;
                const stored = parseInt(table.dataset.nextQuoteIndex || rowCount.toString(), 10);
                const base = Number.isNaN(stored) ? rowCount : Math.max(stored, rowCount);
                table.dataset.nextQuoteIndex = String(base + 1);

                return base;
            }


            function appendGovernorateRow(table, governorate) {
                const tbody = table.querySelector('tbody');
                if (!tbody) {
                    return;
                }

                if (tbody.querySelector(`[data-governorate-row="${governorate.id}"]`)) {
                    const nameLabel = tbody.querySelector(`[data-governorate-row="${governorate.id}"] [data-label="name"]`);
                    if (nameLabel) {
                        nameLabel.textContent = governorate.name;
                    }
                    return;
                }

                const sampleRow = tbody.querySelector('tr');
                const sellInput = sampleRow?.querySelector('input[data-field="sell_price"]');
                const buyInput = sampleRow?.querySelector('input[data-field="buy_price"]');
                const sourceInput = sampleRow?.querySelector('input[data-field="source"]');
                const sellStep = sellInput?.getAttribute('step') || '0.0001';
                const sellPlaceholder = sellInput?.getAttribute('placeholder') || '0.0000';
                const buyStep = buyInput?.getAttribute('step') || '0.0001';
                const buyPlaceholder = buyInput?.getAttribute('placeholder') || '0.0000';
                const sourcePlaceholder = sourceInput?.getAttribute('placeholder') || '';
                const nextIndex = resolveNextQuoteIndex(table);

                const row = document.createElement('tr');
                row.setAttribute('data-governorate-row', governorate.id);
                row.innerHTML = `
                    <td>
                        <span class="fw-semibold" data-label="name">${governorate.name}</span>
                        <input type="hidden" name="quotes[${nextIndex}][governorate_id]" value="${governorate.id}" data-field="governorate_id" data-governorate="${governorate.id}">
                    </td>
                    <td>
                        <input type="number" name="quotes[${nextIndex}][sell_price]" value="" class="form-control form-control-sm quote-input quote-sell-input" min="0" step="${sellStep}" data-field="sell_price" data-governorate="${governorate.id}" placeholder="${sellPlaceholder}">
                    </td>
                    <td>
                        <input type="number" name="quotes[${nextIndex}][buy_price]" value="" class="form-control form-control-sm quote-input quote-buy-input" min="0" step="${buyStep}" data-field="buy_price" data-governorate="${governorate.id}" placeholder="${buyPlaceholder}">
                    </td>
                    <td>
                        <input type="text" name="quotes[${nextIndex}][source]" value="" class="form-control form-control-sm quote-input quote-source-input" maxlength="255" data-field="source" data-governorate="${governorate.id}" placeholder="${sourcePlaceholder}">
                    </td>
                    <td>
                        <input type="datetime-local" name="quotes[${nextIndex}][quoted_at]" value="" class="form-control form-control-sm quote-input quote-quoted-at-input" data-field="quoted_at" data-governorate="${governorate.id}">
                    </td>
                    <td class="text-center">
                        <div class="form-check form-check-inline">
                            <input class="form-check-input default-governorate-radio" type="radio" name="default_governorate_id" value="${governorate.id}">
                        </div>
                    </td>
                `;

                tbody.appendChild(row);
                ensureDefaultSelected(table);
            }

            window.addEventListener('governorate:created', (event) => {
                const detail = event.detail || {};
                if (!detail.governorate) {
                    return;
                }

                document.querySelectorAll('.quotes-table').forEach((table) => {
                    appendGovernorateRow(table, detail.governorate);
                });

                attachDefaultHandlers();
            });

            document.addEventListener('DOMContentLoaded', () => {
                attachDefaultHandlers();

                const modalElement = document.getElementById(modalId);
                if (!modalElement) {
                    return;
                }

                const form = modalElement.querySelector('form');
                const feedback = modalElement.querySelector('[data-feedback]');
                const submitButton = form.querySelector('button[type="submit"]');
                const nameInput = form.querySelector('input[name="name"]');

                modalElement.addEventListener('shown.bs.modal', () => {
                    form.reset();
                    form.querySelector('input[name="is_active"]').checked = true;
                    if (feedback) {
                        feedback.classList.add('d-none');
                        feedback.textContent = '';
                    }
                    if (submitButton) {
                        submitButton.disabled = false;
                    }
                    nameInput?.focus();
                });

                form.addEventListener('submit', (event) => {
                    event.preventDefault();

                    if (submitButton) {
                        submitButton.disabled = true;
                    }
                    if (feedback) {
                        feedback.classList.add('d-none');
                        feedback.textContent = '';
                    }

                    const formData = new FormData(form);
                    const codeValue = (formData.get('code') || '').toString().trim().toUpperCase();
                    formData.set('code', codeValue);
                    formData.set('is_active', formData.has('is_active') ? '1' : '0');

                    fetch(form.action, {
                        method: 'POST',
                        headers: {
                            'Accept': 'application/json',
                            'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
                        },
                        body: formData,
                    })
                        .then(async (response) => {
                            const data = await response.json().catch(() => ({}));

                            if (!response.ok) {
                                throw { status: response.status, data };
                            }

                            return data;
                        })
                        .then((data) => {
                            form.reset();
                            window.dispatchEvent(new CustomEvent('governorate:created', { detail: data }));

                            if (feedback) {
                                feedback.className = 'alert alert-success';
                                feedback.textContent = data.message || '{{ __('Governorate created successfully.') }}';
                                feedback.classList.remove('d-none');
                            }

                            const modalInstance = window.bootstrap ? window.bootstrap.Modal.getOrCreateInstance(modalElement) : null;
                            if (modalInstance) {
                                setTimeout(() => {
                                    modalInstance.hide();
                                }, 600);
                            }
                        })
                        .catch((error) => {
                            if (submitButton) {
                                submitButton.disabled = false;
                            }

                            const messages = [];

                            if (error.status === 422 && error.data?.errors) {
                                Object.values(error.data.errors).forEach((value) => {
                                    if (Array.isArray(value)) {
                                        messages.push(...value);
                                    }
                                });
                            } else if (typeof error.data?.message === 'string') {
                                messages.push(error.data.message);
                            } else {
                                messages.push('{{ __('Unable to save governorate. Please try again.') }}');
                            }

                            if (feedback) {
                                feedback.className = 'alert alert-danger';
                                feedback.textContent = messages.join('\n');
                                feedback.classList.remove('d-none');
                            }
                        })
                        .finally(() => {
                            if (submitButton) {
                                submitButton.disabled = false;
                            }
                        });
                });
            });
        })();
    </script>
@endpush