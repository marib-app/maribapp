window.languageEvents = {
    'click .edit_btn': function (e, value, row) {
        $('.filepond').filepond('removeFile')
        $("#edit_name").val(row.name);
        $("#edit_name_in_english").val(row.name_in_english);
        $("#edit_code").val(row.code);
        $("#edit_rtl_switch").prop('checked', row.rtl);
        $("#edit_rtl").val(row.rtl ? 1 : 0);
    },
    'click .language': function (e, value, row) {

    },
};

window.SeoSettingEvents = {
    'click .edit_btn': function (e, value, row) {
        $('.filepond').filepond('removeFile')
        $("#edit_page").val(row.page);
        $("#edit_title").val(row.title);
        $("#edit_description").val(row.description);
        $("#edit_keywords").val(row.keywords);
    }
};
window.customFieldValueEvents = {
    'click .edit_btn': function (e, value, row) {
        $("#new_custom_field_value").val(row.value);
        $("#old_custom_field_value").val(row.value);
    }
}
window.verificationFieldValueEvents = {
    'click .edit_btn': function (e, value, row) {
        $("#new_verification_field_value").val(row.value);
        $("#old_verification_field_value").val(row.value);
    }
}


window.itemEvents = {


    'click .edit-status': function (e, value, row) {
        $('#status').val(row.status).trigger('change');
        $('#rejected_reason').val(row.rejected_reason);
    }
};

window.packageEvents = {
    'click .edit_btn': function (e, value, row) {
        $('#edit_price').val(row.price);
        $('#edit_discount_in_percentage').val(row.discount_in_percentage);
        $('#edit_final_price').val(row.final_price);
        $('#edit_name').val(row.name);
        $('#edit_description').val(row.description);
        $('#edit_ios_product_id').val(row.ios_product_id);

        // Assuming 'id' is a variable containing the ID you are working with
        if (row.duration.toLowerCase() === "unlimited") {
            // "Unlimited" value, set unlimited duration
            // $('input[type="radio"][name="duration_type"][value="unlimited"]').prop('checked', true);
            $('#edit_duration_type_unlimited').prop('checked', true);
            $('#edit_durationLimit').val();
            $('#edit_limitation_for_duration').hide();
        } else {
            // Numeric value, set limited duration
            // $('input[type="radio"][name="duration_type"][value="limited"]').prop('checked', true);
            $('#edit_duration_type_limited').prop('checked', true);
            $('#edit_limitation_for_duration').show();
            $('#edit_durationLimit').val(row.duration);
        }


        if (row.item_limit.toLowerCase() === "unlimited") {
            // "Unlimited" value, set unlimited duration
            // $('input[type="radio"][name="item_limit_type"][value="unlimited"]').prop('checked', true);
            $('#edit_item_limit_type_unlimited').prop('checked', true);
            $('#edit_ForLimit').val();
            $('#edit_limitation_for_limit').hide();
        } else {
            // Numeric value, set limited duration
            // $('input[type="radio"][name="item_limit_type"][value="limited"]').prop('checked', true);
            $('#edit_item_limit_type_limited').prop('checked', true);
            $('#edit_limitation_for_limit').show();
            $('#edit_ForLimit').val(row.item_limit);
        }
    }
};

window.advertisementPackageEvents = {
    'click .edit_btn': function (e, value, row) {
        $('#edit_name').val(row.name);
        $('#edit_price').val(row.price);
        $('#edit_discount_in_percentage').val(row.discount_in_percentage);
        $('#edit_final_price').val(row.final_price);
        $("#edit_duration").val(row.duration);
        $('#edit_durationLimit').val(row.duration);
        $('#edit_ForLimit').val(row.item_limit);
        $('#edit_description').val(row.description);
        $('#edit_ios_product_id').val(row.ios_product_id);
    }
};

window.reportReasonEvents = {
    'click .edit_btn': function (e, value, row) {
        $("#edit_reason").val(row.reason);
    }
}


const FEATURE_SECTION_TYPE_ALIAS_MAP = {
    real_estate_services: 'real_estate',
    realestateservices: 'real_estate',
    itemslistrealestate: 'real_estate',
    tourism_services: 'tourism',
    tourismservices: 'tourism',
    itemslisttourism: 'tourism',
    e_store: 'merchants',
    estore: 'merchants',
    itemslistseller: 'merchants',
    shein_products: 'shein',
    sheinproducts: 'shein',
    itemslistshein: 'shein',
    computer_section: 'computer',
    computersection: 'computer',
    itemslistcomputer: 'computer',
    public_ads: 'public',
    publicads: 'public',
    itemslistpublic: 'public',
    homepage: 'public',
    home_page: 'public',

};




const FEATURE_SECTION_DEFAULT_TYPE = (function () {
    if (typeof window.featureSectionDefaultType === 'string') {
        const trimmed = window.featureSectionDefaultType.trim();

        if (trimmed !== '') {
            return trimmed;
        }
    }

    return null;
})();



function normalizeFeatureSectionTypeValue(value) {
    if (typeof value !== 'string' || value.trim() === '') {
        return value;
    }

    const original = value.trim();
    const lower = original.toLowerCase();
    const aliasMap = window.featureSectionTypeAliasMap || {};

    if (Object.prototype.hasOwnProperty.call(aliasMap, lower)) {
        return aliasMap[lower];
    }

    if (Object.prototype.hasOwnProperty.call(FEATURE_SECTION_TYPE_ALIAS_MAP, lower)) {
        return FEATURE_SECTION_TYPE_ALIAS_MAP[lower];
    }

    return lower;
}


window.featuredSectionEvents = {
    'click .edit_btn': function (e, value, row) {
        $('#edit_title').val(row.title);
        $('#edit_description').val(row.description);
        const $editSlug = $('#edit_slug');
        if ($editSlug.length) {
            const slugValue = (row.slug || '').toString();
            $editSlug.data('featureSectionCurrentSlug', slugValue);
            $editSlug.data('featureSectionPreferredSlug', slugValue);
        }


        const sectionType = normalizeFeatureSectionTypeValue(row.section_type || FEATURE_SECTION_DEFAULT_TYPE || '');
        const $editSectionType = $('#edit_section_type');


        if ($editSectionType.length) {
            const effectiveSectionType = sectionType || FEATURE_SECTION_DEFAULT_TYPE || null;
            if (effectiveSectionType !== null) {
                $editSectionType.val(effectiveSectionType).trigger('change');
            } else {
                $editSectionType.val(null).trigger('change');
            }
        
        }


        $('#edit_filter').val(row.filter).trigger('change');


        const $editModal = $('#editModal');
        const $styleInputs = $editModal.find('input[name="style"]');
        $styleInputs.prop('checked', false);

        const $styleInput = $styleInputs.filter('[value="' + row.style + '"]');
        $styleInput.prop('checked', true);

        $editModal.find('.radio-img').removeClass('selected');
        if ($styleInput.length) {
            $styleInput.closest('.radio-img').addClass('selected');
        }

        
        const $editIsActive = $('#edit_is_active');
        if ($editIsActive.length) {
            $editIsActive.prop('checked', Boolean(row.is_active));
        }

    }
};






window.featureSectionStatusEvents = {
    'change .feature-section-status-toggle': function (e, value, row, index) {
        const $toggle = $(e.currentTarget);
        const isChecked = $toggle.is(':checked');
        const previousState = Boolean(row.is_active);
        const csrfToken = $('meta[name="csrf-token"]').attr('content');
        const template = typeof window.featureSectionStatusRouteTemplate === 'string'
            ? window.featureSectionStatusRouteTemplate
            : null;
        const url = row.status_update_url || (template ? template.replace('__ID__', row.id) : null);

        if (!url || !csrfToken) {
            $toggle.prop('checked', previousState);
            return;
        }

        $toggle.prop('disabled', true);

        $.ajax({
            url,
            method: 'PATCH',
            data: {
                _token: csrfToken,
                is_active: isChecked ? 1 : 0,
            },
            success(response) {
                const message = response?.message || (window.featureSectionStatusMessages?.success ?? trans('Status updated.'));
                if (typeof showSuccessToast === 'function') {
                    showSuccessToast(message);
                }

                const updatedRow = response?.data;
                const $table = $('#table_list');

                if ($table.length && typeof $table.bootstrapTable === 'function' && updatedRow) {
                    $table.bootstrapTable('updateRow', {
                        index,
                        row: updatedRow,
                    });
                } else {
                    row.is_active = isChecked;
                }
            },
            error(xhr) {
                const message = xhr?.responseJSON?.message || (window.featureSectionStatusMessages?.error ?? trans('Error Occurred'));
                if (typeof showErrorToast === 'function') {
                    showErrorToast(message);
                }
                $toggle.prop('checked', previousState);
            },
            complete() {
                $toggle.prop('disabled', false);
            },
        });
    },
};



window.staffEvents = {
    'click .edit_btn': function (e, value, row) {
        $('#edit_role').val(row.roles[0].id);
        $('#edit_name').val(row.name);
        $('#edit_email').val(row.email);
    }
}
window.verificationfeildEvents = {
    'click .edit_btn': function (e, value, row) {
        $('#edit_name').val(row.name);
        $('#edit_is_required').val(row.is_required)
    }
}

window.userEvents = {
    'click .assign_package': function (e, value, row) {
        $("#user_id").val(row.id);
        $('.package_type').prop('checked', false);

        $('#item-listing-package-div').hide();
        $('#advertisement-package-div').hide();

        $('#advertisement-package').attr('required', false);
        $('#item-listing-package').attr('required', false);

        $('#package_details').hide();
        $('.payment').hide();
        $('.cheque').hide();
    }
}

window.faqEvents = {
    'click .edit_btn': function (e, value, row) {
        $('#edit_question').val(row.question);
        $('#edit_answer').val(row.answer);
    }
}
window.areaEvents = {
    'click .edit_btn': function (e, value, row) {
        $('#edit_name').val(row.name);
    }
}
window.cityEvents = {
    'click .edit_btn': function (e, value, row) {
        $('#edit_country').val(row.country_id);
        $('#edit_state').val(row.state_id);
        $('#edit_name').val(row.name);
        $('#edit_latitude').val(row.latitude);
        $('#edit_longitude').val(row.longitude);
    }
}

window.verificationEvents = {
    'click .view-verification-fields': function (e, value, row) {
        let html = `<table class="table">
            <tr>
                <th width="10%">${trans("No.")}</th>
                <th width="25%">${trans("Name")}</th>
                <th width="65%">${trans("Value")}</th>
            </tr>`;

        console.log(row.verification_field_values);

        $.each(row.verification_field_values, function (key, field) {

            let fieldName = field.verification_field.name;
            let fieldValue = field.value;

            let displayValue = '';
            if (fieldValue) {
                try {
                    if(fieldValue.includes('verification_field_files')){
                        displayValue = "<a class='text-decoration-underline' href='"+fieldValue+"' target='_blank'>"+trans('Click Here')+"</a>";
                    }else{
                        displayValue = Array.isArray(fieldValue) ? fieldValue.join(', ') : fieldValue;
                    }

                } catch (e) {
                    displayValue = fieldValue;
                }
            } else {
                displayValue = 'No value provided';
            }

            html += `<tr class="mb-2">
                <td>${key + 1}</td>
                <td>${fieldName}</td>
                <td class="text-break">${displayValue}</td>
            </tr>`;
        });

        html += "</table>";
        $('#verification_fields').html(html);
        $('#editModal').modal('show');
    },

    'click .edit_btn': function (e, value, row) {
        $('#status').val(row.status).trigger('change');
        $('#rejection_reason').val(row.rejection_reason);
    }
};

window.reviewReportEvents = {
    'click .edit-status': function (e, value, row) {
        $('#status').val(row.report_status).trigger('change');
        $('#report_rejected_reason').val(row.report_rejected_reason);
    }
}
