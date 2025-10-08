(function (window, $) {
    'use strict';

    function sanitizeFilterValue(value) {
        if (Array.isArray(value)) {
            const sanitized = value
                .map(function (entry) {
                    return typeof entry === 'string' ? entry.trim() : entry;
                })
                .filter(function (entry) {
                    if (entry === undefined || entry === null) {
                        return false;
                    }

                    if (typeof entry === 'string') {
                        const normalized = entry.trim().toLowerCase();
                        if (normalized === '' || normalized === 'undefined' || normalized === 'null' || normalized === 'all') {
                            return false;
                        }
                    }

                    return true;
                });

            return sanitized.length ? sanitized : undefined;
        }

        if (value === undefined || value === null) {
            return undefined;
        }

        if (typeof value === 'string') {
            const trimmed = value.trim();

            if (trimmed === '') {
                return undefined;
            }

            const normalized = trimmed.toLowerCase();
            if (normalized === 'undefined' || normalized === 'null' || normalized === 'all') {
                return undefined;
            }

            return trimmed;
        }

        return value;
    }
    
    function applyFilterParams(baseParams, filters) {
        const params = {
            ...baseParams
        };

        Object.keys(filters || {}).forEach(function (key) {
            const sanitizedValue = sanitizeFilterValue(filters[key]);



            if (sanitizedValue === undefined) {
                delete params[key];
                return;
            }

            params[key] = sanitizedValue;
        });

        return params;
    }

    window.queryParams = function (p) {
        return applyFilterParams({
            ...p
        });

    };

    window.reportReasonQueryParams = function (p) {
        return applyFilterParams({
            ...p
        }, {
            status: $('#filter_status').val()
        });
    };

    window.userListQueryParams = function (p) {
        return applyFilterParams({
            ...p
        }, {
            status: $('#filter_status').val()
        });
    };

    window.notificationUserList = function (p) {
        const sendTo = sanitizeFilterValue($('#send_to').val());
        const allowedAccountTypes = ['individual', 'business', 'real_estate'];
        const filters = {};

        if (typeof sendTo === 'string' && allowedAccountTypes.includes(sendTo)) {
            filters.account_type = sendTo;
        }
        return applyFilterParams({
            ...p,
            notification_list: 1
        }, filters);
    };

    window.itemListQueryParams = function (p) {
        const filters = {};
        const statusElement = $('#filter');
        const categoryElement = $('#category_filter');

        if (statusElement.length) {
            filters.status = statusElement.val();

        }

        if (categoryElement.length) {
            filters.category_id = categoryElement.val();
        }

        return applyFilterParams(window.queryParams(p), filters);
    };

}(window, window.jQuery));


