@once
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const inputs = document.querySelectorAll('[data-metal-icon-input]');

            inputs.forEach(function (input) {
                const previewId = input.dataset.metalIconPreview;
                const wrapperId = input.dataset.metalIconWrapper;
                const preview = previewId ? document.getElementById(previewId) : null;
                const wrapper = wrapperId ? document.getElementById(wrapperId) : (preview ? preview.closest('[data-metal-icon-preview-container]') : null);
                const rateId = input.dataset.metalRateId;
                let objectUrl = null;

                const resetPreview = function () {
                    if (preview) {
                        const originalSrc = preview.getAttribute('data-original-src') || '';
                        const originalAlt = preview.getAttribute('data-original-alt') || '';

                        if (objectUrl) {
                            URL.revokeObjectURL(objectUrl);
                            objectUrl = null;
                        }

                        if (originalSrc) {
                            preview.src = originalSrc;
                            preview.alt = originalAlt || preview.alt || '';
                            preview.style.display = '';
                            if (wrapper) {
                                wrapper.classList.remove('d-none');
                                wrapper.dataset.hasOriginal = '1';
                            }
                        } else {
                            preview.src = '#';
                            preview.alt = '';
                            preview.style.display = 'none';
                            if (wrapper) {
                                wrapper.classList.add('d-none');
                                wrapper.dataset.hasOriginal = '';
                            }
                        }
                    }
                };

                if (wrapper && preview) {
                    const originalSrc = preview.getAttribute('data-original-src') || '';
                    if (originalSrc) {
                        wrapper.dataset.hasOriginal = '1';
                        preview.style.display = '';
                    } else if (!(input.files && input.files.length)) {
                        preview.style.display = 'none';
                    }
                }

                input.addEventListener('change', function () {
                    if (objectUrl) {
                        URL.revokeObjectURL(objectUrl);
                        objectUrl = null;
                    }

                    if (input.files && input.files[0]) {
                        const file = input.files[0];
                        objectUrl = URL.createObjectURL(file);

                        if (preview) {
                            preview.src = objectUrl;
                            preview.alt = file.name;
                            preview.style.display = '';
                        }

                        if (wrapper) {
                            wrapper.classList.remove('d-none');
                            wrapper.dataset.hasOriginal = wrapper.dataset.hasOriginal || '';
                        }
                    } else {
                        resetPreview();
                    }
                });

                const clearButtons = document.querySelectorAll('[data-metal-icon-clear-input="' + input.id + '"]');
                clearButtons.forEach(function (button) {
                    button.addEventListener('click', function (event) {
                        event.preventDefault();
                        input.value = '';
                        resetPreview();
                    });
                });

                if (rateId) {
                    const removeButton = document.querySelector('[data-metal-icon-remove="' + rateId + '"]');
                    if (removeButton) {
                        removeButton.addEventListener('click', function () {
                            if (preview) {
                                preview.setAttribute('data-original-src', '');
                                preview.setAttribute('data-original-alt', '');
                            }

                            const altField = document.getElementById('metal_icon_alt_' + rateId);
                            if (altField) {
                                altField.value = '';
                            }

                            input.value = '';
                            resetPreview();
                        });
                    }
                }
            });
        });
    </script>
@endonce