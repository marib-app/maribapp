<script>
    document.addEventListener('DOMContentLoaded', () => {
        const managerRoot = document.getElementById('delivery-policy-manager');
        if (!managerRoot) {
            return;
        }

        const policyStateElement = document.getElementById('delivery-policy-state');
        let policyState = { weight_tiers: [] };

        if (policyStateElement) {
            try {
                const parsed = JSON.parse(policyStateElement.textContent || 'null');
                if (parsed && typeof parsed === 'object') {
                    policyState = parsed;
                }
            } catch (error) {
                console.error('فشل في قراءة بيانات السياسة:', error);
            }
        }

        const weightTiers = Array.isArray(policyState.weight_tiers) ? policyState.weight_tiers : [];

        const getTierById = (tierId) => weightTiers.find((tier) => tier.id === tierId);



        const priceTypeLabels = {
            flat: 'سعر ثابت',
            per_km: 'سعر لكل كيلومتر',
        };

        const priceTypeDescriptions = {
            flat: 'يطبق السعر كما هو على هذا المجال.',
            per_km: 'يتم ضرب السعر بالمسافة المقطوعة.',
        };

        const formatNumber = (value, decimals = 2) => {
            const numericValue = typeof value === 'number' ? value : Number(String(value ?? '').replace(/,/g, ''));
            if (!Number.isFinite(numericValue)) {
                return Number(0).toFixed(decimals);
            }

            return numericValue.toLocaleString(undefined, {
                minimumFractionDigits: decimals,
                maximumFractionDigits: decimals,
            });
        };

        const formatCurrency = (value, currency, decimals = 2) => {
            const formatted = formatNumber(value, decimals);
            const code = currency ? String(currency).toUpperCase() : '';
            return code ? `${formatted} ${code}` : formatted;
        };

        const updateTierSummary = (form) => {
            if (!form) {
                return;
            }

            const tierId = form.getAttribute('data-tier-id');
            if (!tierId || tierId === 'new') {
                return;
            }

            const summary = managerRoot.querySelector(`[data-tier-summary="${tierId}"]`);
            if (!summary) {
                return;
            }

            const currency = summary.getAttribute('data-currency') || '';
            const baseField = summary.querySelector('[data-summary-field="base_price"]');
            if (baseField) {
                const baseValue = form.querySelector('input[name="base_price"]')?.value ?? '';
                baseField.textContent = formatCurrency(baseValue || 0, currency);
            }

            const perKmField = summary.querySelector('[data-summary-field="price_per_km"]');
            if (perKmField) {
                const perKmValue = form.querySelector('input[name="price_per_km"]')?.value ?? '';
                perKmField.textContent = `${formatCurrency(perKmValue || 0, currency)} لكل كم`;
            }

            const flatFeeField = summary.querySelector('[data-summary-field="flat_fee"]');
            if (flatFeeField) {
                const flatFeeValue = form.querySelector('input[name="flat_fee"]')?.value ?? '';
                flatFeeField.textContent = formatCurrency(flatFeeValue || 0, currency);
            }

            const sortOrderField = summary.querySelector('[data-summary-field="sort_order"]');
            if (sortOrderField) {
                const sortValue = form.querySelector('input[name="sort_order"]')?.value ?? '';
                sortOrderField.textContent = sortValue !== '' ? sortValue : '0';
            }

            const notesField = summary.querySelector('[data-summary-field="notes"]');
            if (notesField) {
                const emptyText = notesField.getAttribute('data-empty-text') || '';
                const notesValue = form.querySelector('textarea[name="notes"]')?.value?.trim();
                notesField.textContent = notesValue ? notesValue : emptyText;
            }
        };

        const updateRuleSummary = (form) => {
            if (!form) {
                return;
            }

            const ruleId = form.getAttribute('data-rule-id');
            if (!ruleId || ruleId === 'new') {
                return;
            }

            const summaryRow = managerRoot.querySelector(`tr[data-distance-rule="${ruleId}"]`);
            if (!summaryRow) {
                return;
            }

            const minInput = form.querySelector('input[name="min_distance"]');
            const maxInput = form.querySelector('input[name="max_distance"]');
            const priceInput = form.querySelector('input[name="price"]');
            const currencyInput = form.querySelector('input[name="currency"]');
            const priceTypeSelect = form.querySelector('select[name="price_type"]');
            const sortInput = form.querySelector('input[name="sort_order"]');
            const notesInput = form.querySelector('textarea[name="notes"]');
            const statusToggle = form.querySelector('input[name="status"]');
            const freeToggle = form.querySelector('.distance-free-toggle');

            const minField = summaryRow.querySelector('[data-distance-summary-field="min_distance"]');
            if (minField && minInput) {
                minField.textContent = formatNumber(minInput.value || 0);
            }

            const maxField = summaryRow.querySelector('[data-distance-summary-field="max_distance"]');
            if (maxField && maxInput) {
                if (maxInput.value === '' || maxInput.value === null) {
                    maxField.textContent = maxField.getAttribute('data-empty-text') || '';
                } else {
                    maxField.textContent = formatNumber(maxInput.value);
                }
            }

            const priceAmount = summaryRow.querySelector('[data-distance-summary-field="price_amount"]');
            const priceValueField = summaryRow.querySelector('[data-distance-summary-field="price_value"]');
            const currencyField = summaryRow.querySelector('[data-distance-summary-field="price_currency"]');
            const priceUnitField = summaryRow.querySelector('[data-distance-summary-field="price_unit"]');
            const freeBadge = summaryRow.querySelector('[data-distance-summary-field="free_badge"]');
            const priceTypeText = summaryRow.querySelector('[data-distance-summary-field="price_type_text"]');

            const currencyCode = currencyInput?.value?.toUpperCase() || currencyField?.textContent || '';
            const isFreeShipping = freeToggle?.checked;

            if (isFreeShipping) {
                priceAmount?.classList.add('d-none');
                if (freeBadge) {
                    freeBadge.classList.remove('d-none');
                }
            } else {
                priceAmount?.classList.remove('d-none');
                if (freeBadge) {
                    freeBadge.classList.add('d-none');
                }
                if (priceValueField && priceInput) {
                    priceValueField.textContent = formatNumber(priceInput.value || 0);
                }
                if (currencyField) {
                    currencyField.textContent = currencyCode;
                }
            }

            if (priceUnitField && priceTypeSelect) {
                priceUnitField.textContent = priceTypeLabels[priceTypeSelect.value] || '';
            }

            if (priceTypeText && priceTypeSelect) {
                priceTypeText.textContent = priceTypeDescriptions[priceTypeSelect.value] || '';
            }

            const sortField = summaryRow.querySelector('[data-distance-summary-field="sort_order"]');
            if (sortField) {
                const value = sortInput?.value ?? '';
                sortField.textContent = value !== '' ? value : '0';
            }

            const notesField = summaryRow.querySelector('[data-distance-summary-field="notes"]');
            if (notesField) {
                const emptyText = notesField.getAttribute('data-empty-text') || '';
                const value = notesInput?.value?.trim();
                notesField.textContent = value ? value : emptyText;
            }

            const statusBadge = summaryRow.querySelector('[data-distance-summary-field="status_badge"]');
            if (statusBadge && statusToggle) {
                const activeText = statusBadge.getAttribute('data-active-text') || 'نشطة';
                const inactiveText = statusBadge.getAttribute('data-inactive-text') || 'موقوفة';
                if (statusToggle.checked) {
                    statusBadge.textContent = activeText;
                    statusBadge.classList.remove('bg-secondary');
                    statusBadge.classList.add('bg-success-subtle', 'text-success-emphasis');
                } else {
                    statusBadge.textContent = inactiveText;
                    statusBadge.classList.remove('bg-success-subtle', 'text-success-emphasis');
                    statusBadge.classList.add('bg-secondary');
                }
            }
        };







        const departmentSelect = document.getElementById('delivery-policy-department');
        if (departmentSelect) {
            departmentSelect.addEventListener('change', () => {
                const value = departmentSelect.value || '';
                const url = new URL(window.location.href);
                if (value) {
                    url.searchParams.set('department', value);
                } else {
                    url.searchParams.delete('department');
                }
                window.location.assign(url.toString());
            });
        }



        const vendorSelect = document.getElementById('delivery-policy-vendor');
        if (vendorSelect) {
            vendorSelect.addEventListener('change', () => {
                const value = vendorSelect.value || '';
                const url = new URL(window.location.href);
                if (value) {
                    url.searchParams.set('vendor', value);
                } else {
                    url.searchParams.delete('vendor');
                }
                window.location.assign(url.toString());
            });
        }


        const policyFreeToggle = document.getElementById('policy-free-shipping');
        const policyThreshold = document.getElementById('policy-free-shipping-threshold');
        if (policyFreeToggle && policyThreshold) {
            const syncPolicyThreshold = () => {
                if (policyFreeToggle.checked) {
                    policyThreshold.removeAttribute('disabled');
                } else {
                    policyThreshold.value = '';
                    policyThreshold.setAttribute('disabled', 'disabled');
                }
            };
            policyFreeToggle.addEventListener('change', syncPolicyThreshold);
            syncPolicyThreshold();
        }

        const toggleRuleButtons = managerRoot.querySelectorAll('.toggle-rule-form');
        toggleRuleButtons.forEach((button) => {
            button.addEventListener('click', () => {
                const targetSelector = button.getAttribute('data-target');
                if (!targetSelector) {
                    return;
                }
                const row = document.querySelector(targetSelector);
                if (row) {
                    row.classList.toggle('show');
                }
            });
        });

        const freeShippingToggles = managerRoot.querySelectorAll('.distance-free-toggle');
        freeShippingToggles.forEach((toggle) => {
            toggle.addEventListener('change', () => {
                const form = toggle.closest('form');
                if (!form) {
                    return;
                }
                const priceInput = form.querySelector('input[name="price"]');
                if (!priceInput) {
                    return;
                }

                if (toggle.checked) {
                    priceInput.value = '';
                    priceInput.setAttribute('disabled', 'disabled');
                } else {
                    priceInput.removeAttribute('disabled');
                }


                updateRuleSummary(form);


            });
        });

        const clearFormErrors = (form) => {
            form.querySelectorAll('.form-validation-error').forEach((node) => node.remove());
        };

        const showFormError = (form, message) => {
            const errorElement = document.createElement('div');
            errorElement.className = 'form-validation-error text-danger small mt-2';
            errorElement.textContent = message;
            form.appendChild(errorElement);
        };

        const rangesOverlap = (minA, maxA, minB, maxB) => {
            const effectiveMaxA = typeof maxA === 'number' ? maxA : Number.POSITIVE_INFINITY;
            const effectiveMaxB = typeof maxB === 'number' ? maxB : Number.POSITIVE_INFINITY;
            const effectiveMinB = typeof minB === 'number' ? minB : 0;
            return minA <= effectiveMaxB && effectiveMaxA >= effectiveMinB;
        };

        const weightTierForms = managerRoot.querySelectorAll('.weight-tier-form');
        weightTierForms.forEach((form) => {

            form.addEventListener('input', () => updateTierSummary(form));
            form.addEventListener('change', () => updateTierSummary(form));
            updateTierSummary(form);




            form.addEventListener('submit', (event) => {
                clearFormErrors(form);
                const tierIdRaw = form.getAttribute('data-tier-id');
                const tierId = tierIdRaw && tierIdRaw !== 'new' ? Number(tierIdRaw) : null;
                const minInput = form.querySelector('input[name="min_weight"]');
                const maxInput = form.querySelector('input[name="max_weight"]');

                const min = minInput ? Number(minInput.value || '0') : 0;
                const max = maxInput && maxInput.value !== '' ? Number(maxInput.value) : null;

                if (max !== null && max <= min) {
                    event.preventDefault();
                    showFormError(form, 'يجب أن يكون الوزن الأقصى أكبر من الوزن الأدنى.');
                    return;
                }

                const conflict = weightTiers.find((tier) => {
                    if (tierId !== null && tier.id === tierId) {
                        return false;
                    }
                    return rangesOverlap(min, max, Number(tier.min_weight), tier.max_weight);
                });

                if (conflict) {
                    event.preventDefault();
                    showFormError(form, `يتداخل هذا المجال مع الشريحة "${conflict.name}".`);
                }
            });
        });

        const distanceForms = managerRoot.querySelectorAll('.distance-rule-form');
        distanceForms.forEach((form) => {

            form.addEventListener('input', () => updateRuleSummary(form));
            form.addEventListener('change', () => updateRuleSummary(form));
            updateRuleSummary(form);



            
            form.addEventListener('submit', (event) => {
                clearFormErrors(form);

                const tierIdRaw = form.getAttribute('data-tier-id');
                const tierId = tierIdRaw ? Number(tierIdRaw) : null;
                if (!tierId) {
                    return;
                }

                const tier = getTierById(tierId);
                if (!tier) {
                    return;
                }

                const ruleIdRaw = form.getAttribute('data-rule-id');
                const ruleId = ruleIdRaw && ruleIdRaw !== 'new' ? Number(ruleIdRaw) : null;

                const minInput = form.querySelector('input[name="min_distance"]');
                const maxInput = form.querySelector('input[name="max_distance"]');
                const priceInput = form.querySelector('input[name="price"]');
                const freeToggle = form.querySelector('.distance-free-toggle');

                const min = minInput ? Number(minInput.value || '0') : 0;
                const max = maxInput && maxInput.value !== '' ? Number(maxInput.value) : null;

                if (max !== null && max <= min) {
                    event.preventDefault();
                    showFormError(form, 'يجب أن تكون المسافة الأقصى أكبر من المسافة الأدنى.');
                    return;
                }

                const conflict = (tier.distance_rules || []).find((rule) => {
                    if (ruleId !== null && rule.id === ruleId) {
                        return false;
                    }
                    return rangesOverlap(min, max, Number(rule.min_distance), rule.max_distance);
                });

                if (conflict) {
                    event.preventDefault();
                    showFormError(form, 'يتداخل مجال المسافة مع قاعدة أخرى في هذه الشريحة.');
                    return;
                }

                if (freeToggle && freeToggle.checked) {
                    return;
                }

                if (priceInput && priceInput.hasAttribute('disabled')) {
                    event.preventDefault();
                    showFormError(form, 'يرجى تعطيل خيار الشحن المجاني أو تحديد سعر صالح.');
                    return;
                }

                if (priceInput && (priceInput.value === '' || Number(priceInput.value) < 0)) {
                    event.preventDefault();
                    showFormError(form, 'يجب إدخال سعر صالح عندما لا يكون الشحن مجانيًا.');
                }
            });
        });

        const simulatorForm = document.getElementById('delivery-simulator-form');
        const simulatorResult = document.getElementById('delivery-simulator-result');
        const simulatorMode = document.getElementById('simulator-mode');
        const simulatorWeightWrapper = document.getElementById('simulator-weight-wrapper');
        const currentDepartment = managerRoot.getAttribute('data-current-department') || '';

        const syncSimulatorWeight = () => {
            if (!simulatorMode || !simulatorWeightWrapper) {
                return;
            }
            if (simulatorMode.value === 'weight_distance') {
                simulatorWeightWrapper.removeAttribute('hidden');
            } else {
                simulatorWeightWrapper.setAttribute('hidden', 'hidden');
                const weightInput = simulatorWeightWrapper.querySelector('input[name="weight"]');
                if (weightInput) {
                    weightInput.value = '';
                }
            }
        };

        simulatorMode?.addEventListener('change', syncSimulatorWeight);
        syncSimulatorWeight();

        simulatorForm?.addEventListener('submit', async (event) => {
            event.preventDefault();
            if (!simulatorResult) {
                return;
            }

            const formData = new FormData(simulatorForm);
            const payload = {
                mode: formData.get('mode'),
                distance: Number(formData.get('distance') || 0),
                order_total: formData.get('order_total') ? Number(formData.get('order_total')) : null,
                department: currentDepartment || null,
            };

            const weightValue = formData.get('weight');
            if (payload.mode === 'weight_distance') {
                payload.weight = weightValue ? Number(weightValue) : null;
            }

            const alertBox = simulatorResult.querySelector('.alert');
            const breakdownBox = simulatorResult.querySelector('.simulator-breakdown');

            simulatorResult.hidden = false;
            breakdownBox.innerHTML = '';

            try {
                const response = await fetch('/api/delivery-prices/calculate', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                    },
                    body: JSON.stringify(payload),
                });

                const data = await response.json();

                if (response.ok && data?.status) {
                    alertBox.className = 'alert alert-success';
                    alertBox.textContent = data.message || 'تم حساب التكلفة بنجاح.';

                    const details = data.data || {};
                    const lines = [];
                    lines.push(`<div class="fw-semibold">التكلفة الإجمالية: ${Number(details.total ?? 0).toFixed(2)} ${details.currency ?? ''}</div>`);
                    lines.push(`<div>الشحن المجاني: ${details.free_shipping_applied ? 'نعم' : 'لا'}</div>`);
                    breakdownBox.innerHTML = lines.join('');

                    if (Array.isArray(details.breakdown) && details.breakdown.length > 0) {
                        const list = document.createElement('ul');
                        list.className = 'mt-2 mb-0';
                        details.breakdown.forEach((item) => {
                            const li = document.createElement('li');
                            li.textContent = `${item.description ?? ''} (${Number(item.amount ?? 0).toFixed(2)})`;
                            list.appendChild(li);
                        });
                        breakdownBox.appendChild(list);
                    }
                } else {
                    alertBox.className = 'alert alert-danger';
                    alertBox.textContent = data?.message || 'تعذر حساب التكلفة، يرجى المحاولة مرة أخرى.';
                }
            } catch (error) {
                alertBox.className = 'alert alert-danger';
                alertBox.textContent = 'حدث خطأ غير متوقع أثناء الاتصال بالخادم.';
                console.error(error);
            }
        });
    });
</script>