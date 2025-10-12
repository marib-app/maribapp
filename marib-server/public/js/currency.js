$(function () {
    const tableSelector = '#table_list';
    const createForm = $('.create-form');
    const editForm = $('.edit-form');
    const editModal = $('#editModal');

    function refreshTable() {
        $(tableSelector).bootstrapTable('refresh');
    }

    function resetCreateForm() {
        createForm.trigger('reset');
        togglePreview('create', null, null);
    }

    function togglePreview(context, imageUrl, altText) {
        const wrapper = $(`.currency-icon-preview[data-preview="${context}"]`);
        const input = context === 'create' ? $('#create_icon') : $('#edit_icon');
        const altInput = context === 'create' ? createForm.find('input[name="icon_alt"]') : $('#edit_icon_alt');

        if (imageUrl) {
            wrapper.removeClass('d-none');
            wrapper.find('.preview-image').attr('src', imageUrl);
            wrapper.find('.preview-image').attr('alt', altText || '');
            wrapper.find('.current-icon-alt').text(altText || '');
        } else {
            wrapper.addClass('d-none');
            wrapper.find('.preview-image').attr('src', '');
            wrapper.find('.preview-image').attr('alt', '');
            wrapper.find('.current-icon-alt').text('');
        }

        if (typeof altText !== 'undefined') {
            altInput.val(altText || '');
        }

        if (context === 'edit') {
            if (!imageUrl) {
                $('#edit_remove_icon').val('0');
            }
            editModal.data('has-existing-icon', Boolean(imageUrl));
        }

        if (context === 'create' && !imageUrl) {
            input.val('');
        }
    }

    function readFilePreview(input, context) {
        if (!input.files || !input.files.length) {
            if (context === 'create') {
                togglePreview(context, null, null);
            } else {
                const original = editModal.data('currency-row') || {};
                togglePreview('edit', original.icon_url || null, original.icon_alt ?? '');
            }
                        return;
        }


        const file = input.files[0];
        const reader = new FileReader();
        reader.onload = function (e) {
            togglePreview(context, e.target.result, undefined);
        };
        reader.readAsDataURL(file);

        if (context === 'edit') {
            $('#edit_remove_icon').val('0');
        }
    }

    function submitForm(formElement, method) {
        const $form = $(formElement);
        const url = $form.attr('action');
        const formData = new FormData(formElement);
        
        $.ajax({
            url,
            type: method,
            data: formData,
            processData: false,
            contentType: false,
            headers: {
                'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
            },
            success(response) {


                if (response.success) {
                    refreshTable();
                    showSuccessToast(response.message || 'تم الحفظ بنجاح');
                    if ($form.is(createForm)) {
                        resetCreateForm();
                    } else {
                        editModal.modal('hide');
                    }
                }
            },
            error(xhr) {
                if (xhr.status === 422 && xhr.responseJSON?.errors) {
                    const errors = xhr.responseJSON.errors;
                    Object.keys(errors).forEach((key) => {
                        showErrorToast(errors[key][0]);
                    });
                } else {
                    showErrorToast('حدث خطأ غير متوقع، حاول مرة أخرى.');

                }
            }
        });

            }

    createForm.on('submit', function (e) {
        e.preventDefault();
        submitForm(this, 'POST');
    });

    editForm.on('submit', function (e) {
        e.preventDefault();
        submitForm(this, 'POST');
    });

    $('#create_icon').on('change', function () {
        readFilePreview(this, 'create');
    });

    $('#edit_icon').on('change', function () {
        readFilePreview(this, 'edit');
    });

    $(document).on('click', '.clear-icon', function () {
        const target = $(this).data('target');

        if (target === 'create') {
            togglePreview('create', null, null);
            return;
        }

        const originalRow = editModal.data('currency-row') || {};
        const fileInput = $('#edit_icon')[0];

        if (fileInput.files && fileInput.files.length) {
            $('#edit_icon').val('');
            togglePreview('edit', originalRow.icon_url || null, originalRow.icon_alt || null);
            return;
        }

        if (!originalRow.icon_url) {
            togglePreview('edit', null, null);
            return;
        }

        if (!confirm('هل أنت متأكد من حذف الأيقونة الحالية؟')) {
            return;
        }

        const currencyId = originalRow.id;

        $.ajax({
            url: `/currency/${currencyId}/icon`,
            type: 'DELETE',
            headers: {
                'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
            },
            success(response) {
                if (response.success) {
                    showSuccessToast(response.message || 'تم حذف الأيقونة.');
                    editModal.data('currency-row', Object.assign({}, originalRow, { icon_url: null, icon_alt: null }));
                    togglePreview('edit', null, null);
                    refreshTable();
                }
            },
            error() {
                showErrorToast('تعذر حذف الأيقونة، حاول مرة أخرى.');
            }
        });
    });

    $(document).on('currency:edit-open', function (_event, row) {
        editModal.data('currency-row', row);
        togglePreview('edit', row.icon_url || null, row.icon_alt || null);
    });

    editModal.on('hidden.bs.modal', function () {
        $('#edit_icon').val('');
        $('#edit_remove_icon').val('0');
        togglePreview('edit', null, null);
        editModal.data('currency-row', null);
    });
});