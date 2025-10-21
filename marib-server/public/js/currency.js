$(function () {
    const tableSelector = '#table_list';
    const createForm = $('.create-form');
    const editForm = $('.edit-form');
    const editIconInput = $('#edit_icon');
    const editIconAltInput = $('#edit_icon_alt');
    const editRemoveIconInput = $('#edit_remove_icon');

    const editOriginalIconUrl = editForm.length ? (editForm.data('original-icon-url') || '') : '';
    const editOriginalIconAlt = editForm.length ? (editForm.data('original-icon-alt') || '') : '';
    let editRemovalPending = false;


    function refreshTable() {
        const table = $(tableSelector);
        if (table.length && table.data('bootstrap.table')) {
            table.bootstrapTable('refresh');
        }
    
    }

    function resetCreateForm() {
        if (!createForm.length) {
            return;
        }

        createForm.trigger('reset');
        togglePreview('create', null, null);
    }

    function togglePreview(context, imageUrl, altText) {
        const wrapper = $(`.currency-icon-preview[data-preview="${context}"]`);
        const input = context === 'create' ? $('#create_icon') : editIconInput;
        const altInput = context === 'create' ? createForm.find('input[name="icon_alt"]') : editIconAltInput;

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

        if (context === 'create' && !imageUrl) {
            input.val('');
        }
    }

    function setEditRemovalPending(pending) {
        editRemovalPending = Boolean(pending);

        if (editRemoveIconInput.length) {
            editRemoveIconInput.val(editRemovalPending ? '1' : '0');
        }
    }

    function getEditPreviewState() {
        if (editRemovalPending) {
            return { url: null, alt: '' };
        }

        return {
            url: editOriginalIconUrl || null,
            alt: editOriginalIconAlt || ''
        };
    }


    function readFilePreview(input, context) {
        if (!input.files || !input.files.length) {
            if (context === 'create') {
                togglePreview('create', null, null);
            } else if (context === 'edit') {
                const baseline = getEditPreviewState();
                togglePreview('edit', baseline.url, baseline.alt);
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
            setEditRemovalPending(false);
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
    if (createForm.length) {
        createForm.on('submit', function (e) {
            e.preventDefault();
            submitForm(this, 'POST');
        });
    }

    $('#create_icon').on('change', function () {
        readFilePreview(this, 'create');
    });

    if (editIconInput.length) {
        editIconInput.on('change', function () {
            readFilePreview(this, 'edit');
        });
    }


    $(document).on('click', '.clear-icon', function () {
        const target = $(this).data('target');

        if (target === 'create') {
            togglePreview('create', null, null);
            return;
        }

        if (!editForm.length) {

            return;
        }

        const fileInput = editIconInput.get(0);

        if (fileInput && fileInput.files && fileInput.files.length) {
            editIconInput.val('');
            const baseline = getEditPreviewState();
            togglePreview('edit', baseline.url, baseline.alt);


            return;
        }

        if (editRemovalPending) {
            setEditRemovalPending(false);
            togglePreview('edit', editOriginalIconUrl || null, editOriginalIconAlt || '');
            editIconAltInput.val(editOriginalIconAlt || '');
            
            return;
        }

        if (!editOriginalIconUrl) {
            togglePreview('edit', null, '');
            return;
        }


        if (!confirm('هل أنت متأكد من حذف الأيقونة الحالية؟')) {
            return;
        }

        editIconInput.val('');
        setEditRemovalPending(true);
        togglePreview('edit', null, '');
        editIconAltInput.val('');
    });

    if (editRemoveIconInput.length) {
        setEditRemovalPending(false);
    }
});