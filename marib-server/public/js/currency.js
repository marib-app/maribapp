$(function () {
    // تهيئة الجدول مع تنسيق التاريخ
    $('#table_list').bootstrapTable({
        onLoadSuccess: function (data) {
            // تنسيق عمود التاريخ
            $('.last-updated-column').each(function() {
                var date = $(this).text();
                if (date) {
                    var formattedDate = moment(date).format('YYYY-MM-DD HH:mm:ss');
                    $(this).text(formattedDate);
                }
            });
        },
        columns: [{
            field: 'last_updated_at',
            formatter: function(value) {
                return value ? moment(value).format('YYYY-MM-DD HH:mm:ss') : '';
            }
        }]
    });

    // تعريف أحداث العملة
    window.currencyEvents = {
        'click .edit-currency': function (e, value, row, index) {
            $('#edit_id').val(row.id);
            $('#edit_currency_name').val(row.currency_name);
            $('#edit_sell_price').val(row.sell_price);
            $('#edit_buy_price').val(row.buy_price);
            $('#editModal').modal('show');
        },
        'click .delete-currency': function (e, value, row, index) {
            if (confirm('هل أنت متأكد من حذف هذه العملة؟')) {
                $.ajax({
                    url: '/currency/' + row.id,
                    type: 'DELETE',
                    success: function (response) {
                        if (response.success) {
                            $('#table_list').bootstrapTable('refresh');
                            showSuccessToast(response.message);
                        }
                    },
                    error: function (xhr) {
                        showErrorToast('حدث خطأ أثناء حذف العملة');
                    }
                });
            }
        }
    };

    // معالجة نموذج التعديل
    $('.edit-form').on('submit', function (e) {
        e.preventDefault();
        var form = $(this);
        var id = $('#edit_id').val();
        
        $.ajax({
            url: '/currency/' + id,
            type: 'POST',
            data: form.serialize(),
            success: function (response) {
                if (response.success) {
                    $('#editModal').modal('hide');
                    $('#table_list').bootstrapTable('refresh');
                    showSuccessToast(response.message);
                }
            },
            error: function (xhr) {
                if (xhr.status === 422) {
                    var errors = xhr.responseJSON.errors;
                    Object.keys(errors).forEach(function (key) {
                        showErrorToast(errors[key][0]);
                    });
                }
            }
        });
    });

    // تحديث الجدول تلقائياً
    $('#table_list').bootstrapTable('refresh');
});