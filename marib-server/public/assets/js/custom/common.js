/*
* Common JS is used to write code which is generally used for all the UI components
* Specific component related code won't be written here
*/

"use strict";
$(document).ready(function () {
    $('#table_list').on('all.bs.table', function () {
        $('#toolbar').parent().addClass('col-12  col-md-7 col-lg-7 p-0');
    })
    $(function () {
        $('[data-toggle="tooltip"]').tooltip()
    })


    function getBootstrapWrapper($table) {
        if (!$table || !$table.length) {
            return null;
        }

        const $wrapper = $table.closest('.bootstrap-table');

        if ($wrapper.length) {
            return $wrapper;
        }

        return null;
    }

    function ensureTableLoadingOverlay($table) {
        const $wrapper = getBootstrapWrapper($table);

        if (!$wrapper) {
            return null;
        }

        let $overlay = $wrapper.children('.table-loading-overlay');

        if (!$overlay.length) {
            const shimmerGroup = $('<div class="table-loading-shimmer-group" />')
                .append('<div class="table-loading-shimmer"></div>')
                .append('<div class="table-loading-shimmer"></div>')
                .append('<div class="table-loading-shimmer"></div>');

            $overlay = $('<div class="table-loading-overlay" role="status" aria-live="polite"></div>').append(shimmerGroup);
            $wrapper.append($overlay);
        }

        return $overlay;
    }

    function showTableLoading($table) {
        const $wrapper = getBootstrapWrapper($table);

        if (!$wrapper) {
            window.requestAnimationFrame(function () {
                showTableLoading($table);
            });
            return;
        }

        const $overlay = ensureTableLoadingOverlay($table);

        if ($overlay) {
            $wrapper.addClass('is-loading');
            window.requestAnimationFrame(function () {
                $overlay.addClass('is-visible');
            });
        }
    }

    function hideTableLoading($table) {
        const $wrapper = getBootstrapWrapper($table);

        if (!$wrapper) {
            return;
        }

        const $overlay = $wrapper.children('.table-loading-overlay');

        if ($overlay.length) {
            $overlay.removeClass('is-visible');
        }

        $wrapper.removeClass('is-loading');
        $table.data('tableInitialLoadComplete', true);
    }


    function refreshBootstrapTable($table) {
        const tableState = $table.data('bootstrap.table');

        if (!tableState || !tableState.options) {
            window.requestAnimationFrame(function () {
                refreshBootstrapTable($table);
            });
            return;
        }

        const hasRemoteSource = Boolean(tableState.options.url) || typeof tableState.options.ajax === 'function';
        if (!hasRemoteSource) {
            return;
        }

        if (tableState.options.pageNumber && tableState.options.pageNumber !== 1) {
            $table.bootstrapTable('refreshOptions', {
                pageNumber: 1
            });
        }
        showTableLoading($table);

        $table.bootstrapTable('refresh', {
            silent: true
        });
    }

    function initializeBootstrapTables() {
        const $bootstrapTables = $('table[data-toggle="table"]');

        if (!$bootstrapTables.length) {
            return;
        }



        $bootstrapTables.each(function () {
            const $table = $(this);

            if ($table.data('autoLoadInitialized')) {
                return;
            }

            if (typeof $.fn.bootstrapTable !== 'function') {
                return;
            }

            $table.data('autoLoadInitialized', true);

            if (!$table.data('bootstrap.table')) {
                $table.bootstrapTable();
            }

            if (!$table.data('tableLoadingEventsBound')) {
                $table.data('tableLoadingEventsBound', true);

                $table.on('load-success.bs.table load-error.bs.table post-body.bs.table', function () {
                    hideTableLoading($table);
                });

                $table.on('refresh.bs.table page-change.bs.table search.bs.table column-switch.bs.table', function () {
                    showTableLoading($table);
                });
            }

            showTableLoading($table);


            window.requestAnimationFrame(function () {
                refreshBootstrapTable($table);
            });
        });
    }

    function whenBootstrapTableReady(callback) {
        if (typeof $.fn.bootstrapTable === 'function') {
            callback();
            return;
        }

        let attempts = 0;
        const maxAttempts = 20;
        const intervalId = window.setInterval(function () {
            if (typeof $.fn.bootstrapTable === 'function') {
                window.clearInterval(intervalId);
                callback();
                return;
            }

            attempts += 1;


            if (attempts >= maxAttempts) {
                window.clearInterval(intervalId);
            }
        }, 100);
    }


    whenBootstrapTableReady(function () {
        initializeBootstrapTables();

        if (typeof MutationObserver === 'function') {
            const observer = new MutationObserver(function () {
                initializeBootstrapTables();
            });

            observer.observe(document.body || document.documentElement, {
                childList: true,
                subtree: true
            });
        }
    });


    if ($('.permission-tree').length > 0) {
        $(function () {
            $('.permission-tree').on('changed.jstree', function (e, data) {
                // let i, j = [];
                let html = "";
                for (let i = 0, j = data.selected.length; i < j; i++) {
                    let permissionName = data.instance.get_node(data.selected[i]).data.name;
                    if (permissionName) {
                        html += "<input type='hidden' name='permission[]' value='" + permissionName + "'/>"
                    }
                }
                $('#permission-list').html(html);
            }).jstree({
                "plugins": ["checkbox"],
            });
        });
    }
})
//Setup CSRF Token default in AJAX Request
$.ajaxSetup({
    headers: {
        'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
    }
});

$('#create-form,.create-form,.create-form-without-reset').on('submit', function (e) {
    e.preventDefault();
    let formElement = $(this);
    let submitButtonElement = $(this).find(':submit');
    let url = $(this).attr('action');

    let preSubmitFunction = $(this).data('pre-submit-function');
    if (preSubmitFunction) {
        //If custom function name is set in the Form tag then call that function using eval
        if (eval(preSubmitFunction + "()") == false) {
            return false;
        }
    }

    const beforeAjaxEvent = $.Event('form:beforeAjax');
    formElement.trigger(beforeAjaxEvent, [formElement, submitButtonElement]);
    if (beforeAjaxEvent.isDefaultPrevented()) {
        return false;
    }

    // [SCHEMA SYNC] اجمع سكيمة الحقول قبل إنشاء الـFormData
    if (document.getElementById('service_fields_schema')) {
        const schemaInput = $('#service_fields_schema');
        if (!schemaInput.val() && window.ServiceFields && typeof ServiceFields.toJSON === 'function') {
            schemaInput.val(JSON.stringify(ServiceFields.toJSON()));
        }
    }

    let data = new FormData(this);

    // [SCHEMA SYNC] ضمّن السكيمة داخل الـFormData حتى لو لم تُلتقط تلقائياً
    if (document.getElementById('service_fields_schema')) {
        data.set('service_fields_schema', $('#service_fields_schema').val() || '[]');
    }

    let customSuccessFunction = $(this).data('success-function');

    // noinspection JSUnusedLocalSymbols
    function successCallback(response) {
        if (!$(formElement).hasClass('create-form-without-reset')) {
            formElement[0].reset();
            $(".select2").val("").trigger('change');
            $('.filepond').filepond('removeFile')
        }
        $('#table_list').bootstrapTable('refresh');
        if (customSuccessFunction) {
            //If custom function name is set in the Form tag then call that function using eval
            eval(customSuccessFunction + "(response)");
        }
    }

    formAjaxRequest('POST', url, data, formElement, submitButtonElement, successCallback);
})

$('#edit-form,.edit-form').on('submit', function (e) {
    e.preventDefault();
    let formElement = $(this);
    let submitButtonElement = $(this).find(':submit');
    $(formElement).parents('modal').modal('hide');
    // let url = $(this).attr('action') + "/" + data.get('edit_id');
    let url = $(this).attr('action');
    let preSubmitFunction = $(this).data('pre-submit-function');
    if (preSubmitFunction) {
        //If custom function name is set in the Form tag then call that function using eval
        eval(preSubmitFunction + "()");
    }

    const beforeAjaxEvent = $.Event('form:beforeAjax');
    formElement.trigger(beforeAjaxEvent, [formElement, submitButtonElement]);
    if (beforeAjaxEvent.isDefaultPrevented()) {
        return false;
    }

    // [SCHEMA SYNC] اجمع سكيمة الحقول قبل إنشاء الـFormData (نفس منطق الإنشاء)
    if (document.getElementById('service_fields_schema')) {
        const schemaInput = $('#service_fields_schema');
        if (!schemaInput.val() && window.ServiceFields && typeof ServiceFields.toJSON === 'function') {
            schemaInput.val(JSON.stringify(ServiceFields.toJSON()));
        }
    }

    let data = new FormData(this);

    // [SCHEMA SYNC] ضمّن السكيمة داخل الـFormData
    if (document.getElementById('service_fields_schema')) {
        data.set('service_fields_schema', $('#service_fields_schema').val() || '[]');
    }

    let customSuccessFunction = $(this).data('success-function');

    // noinspection JSUnusedLocalSymbols
    function successCallback(response) {
        $('#table_list').bootstrapTable('refresh');
        setTimeout(function () {
            $('#editModal').modal('hide');
            $(formElement).parents('.modal').modal('hide');
        }, 1000)
        if (customSuccessFunction) {
            //If custom function name is set in the Form tag then call that function using eval
            eval(customSuccessFunction + "(response)");
        }
    }

    formAjaxRequest('PUT', url, data, formElement, submitButtonElement, successCallback);
})

$(document).on('click', '.delete-form', function (e) {
    e.preventDefault();
    showDeletePopupModal($(this).attr('href'), {
        successCallBack: function () {
            $('#table_list').bootstrapTable('refresh');
        }, errorCallBack: function (response) {
            // showErrorToast(response.message);
        }
    })
})

$(document).on('click', '.restore-data', function (e) {
    e.preventDefault();
    showRestorePopupModal($(this).attr('href'), {
        successCallBack: function () {
            $('#table_list').bootstrapTable('refresh');
        }
    })
})

$(document).on('click', '.trash-data', function (e) {
    e.preventDefault();
    showPermanentlyDeletePopupModal($(this).attr('href'), {
        successCallBack: function () {
            $('#table_list').bootstrapTable('refresh');
        }
    })
})

$(document).on('click', '.set-form-url', function (e) {
    //This event will be called when user clicks on the edit button of the bootstrap table
    e.preventDefault();
    $('#edit-form,.edit-form').attr('action', $(this).attr('href'));
})

$(document).on('click', '.delete-form-reload', function (e) {
    e.preventDefault();
    showDeletePopupModal($(this).attr('href'), {
        successCallBack: function () {
            setTimeout(() => {
                window.location.reload();
            }, 1000);
        }
    })
})

// Change event for Status toggle change in Bootstrap-table
$(document).on('change', '.update-status', function () {
    let tableElement = $(this).parents('table');
    let url = $(tableElement).data('custom-status-change-url') || window.baseurl + "common/change-status";
    ajaxRequest('PUT', url, {
        id: $(this).attr('id'),
        table: $(tableElement).data('table'),
        column: $(tableElement).data('status-column') || "",
        status: $(this).is(':checked') ? 1 : 0
    }, null, function (response) {
        showSuccessToast(response.message);
    }, function (error) {
        showErrorToast(error.message);
    })
})


//Fire Ajax request when the Bootstrap-table rows are rearranged
$('#table_list').on('reorder-row.bs.table', function (element, rows) {
    let url = $(element.currentTarget).data('custom-reorder-row-url') || window.baseurl + "common/change-row-order";
    ajaxRequest('PUT', url, {
        table: $(element.currentTarget).data('table'),
        column: $(element.currentTarget).data('reorder-column') || "",
        data: rows
    }, null, function (success) {
        $('#table_list').bootstrapTable('refresh');
        showSuccessToast(success.message);
    }, function (error) {
        showErrorToast(error.message);
    })
})


$('.img_input').click(function () {
    $('#edit_cs_image').click();
});
$('.preview-image-file').on('change', function () {
    const [file] = this.files
    if (file) {
        $('.preview-image').attr('src', URL.createObjectURL(file));
    }
})


$('.form-redirection').on('submit', function (e) {
    let parsley = $(this).parsley({
        excluded: 'input[type=button], input[type=submit], input[type=reset], :hidden'
    });
    parsley.validate();
    if (parsley.isValid()) {
        $(this).find(':submit').attr('disabled', true);
    }
})

$('#editlanguage-form,.editlanguage-form').on('submit', function (e) {
    e.preventDefault();
    let formElement = $(this);
    let submitButtonElement = $(this).find(':submit');

    // [SCHEMA SYNC] احترازياً (لن يؤثر إن لم تكن صفحة الخدمة)
    if (document.getElementById('service_fields_schema')) {
        const schemaInput = $('#service_fields_schema');
        if (!schemaInput.val() && window.ServiceFields && typeof ServiceFields.toJSON === 'function') {
            schemaInput.val(JSON.stringify(ServiceFields.toJSON()));
        }
    }

    let data = new FormData(this);

    // [SCHEMA SYNC]
    if (document.getElementById('service_fields_schema')) {
        data.set('service_fields_schema', $('#service_fields_schema').val() || '[]');
    }

    $(formElement).parents('modal').modal('hide');
    // let url = $(this).attr('action') + "/" + data.get('edit_id');
    let url = $(this).attr('action');
    let preSubmitFunction = $(this).data('pre-submit-function');
    if (preSubmitFunction) {
        //If custom function name is set in the Form tag then call that function using eval
        eval(preSubmitFunction + "()");
    }
    let customSuccessFunction = $(this).data('success-function');

    // noinspection JSUnusedLocalSymbols
    function successCallback(response) {
        setTimeout(() => {
            window.location.reload();
        }, 1000);
    }
    formAjaxRequest('PUT', url, data, formElement, submitButtonElement, successCallback);
})
