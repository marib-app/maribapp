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


    function toPositiveInteger(value, fallback) {
        if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
            return Math.floor(value);
        }

        if (typeof value === 'string' && value.trim() !== '') {
            const parsed = Number.parseInt(value, 10);

            if (Number.isFinite(parsed) && parsed > 0) {
                return parsed;
            }
        }

        return fallback;
    }

    function toNonNegativeInteger(value, fallback) {
        if (typeof value === 'number' && Number.isFinite(value) && value >= 0) {
            return Math.floor(value);
        }

        if (typeof value === 'string' && value.trim() !== '') {
            const parsed = Number.parseInt(value, 10);

            if (Number.isFinite(parsed) && parsed >= 0) {
                return parsed;
            }
        }

        return fallback;
    }

    function sanitizeBaseParams(baseParams) {
        const params = {};

        Object.keys(baseParams || {}).forEach(function (key) {
            const value = baseParams[key];

            if (value === undefined || value === null) {
                return;
            }

            if (typeof value === 'string') {
                const trimmed = value.trim();

                if (trimmed === '') {
                    return;
                }

                const normalized = trimmed.toLowerCase();
                if (['undefined', 'null'].includes(normalized)) {
                    return;
                }

                params[key] = trimmed;
                return;
            }

            params[key] = value;
        });

        const DEFAULT_LIMIT = 10;
        const MAX_LIMIT = 200;

        const rawLimit = params.limit ?? params.length ?? params.pageSize ?? params.page_size;
        const limit = Math.max(1, Math.min(MAX_LIMIT, toPositiveInteger(rawLimit, DEFAULT_LIMIT)));

        params.limit = limit;
        params.length = limit;
        delete params.pageSize;
        delete params.page_size;

        const rawPage = params.page ?? params.pageNumber ?? params.currentPage;
        const page = Math.max(1, toPositiveInteger(rawPage, 1));

        params.page = page;
        params.pageNumber = page;

        const computedOffset = (page - 1) * limit;
        const offset = toNonNegativeInteger(params.offset, computedOffset);
        params.offset = offset;

        if (typeof params.order === 'string') {
            const normalizedOrder = params.order.trim().toUpperCase();
            params.order = normalizedOrder === 'ASC' ? 'ASC' : 'DESC';
        }

        if (typeof params.sort === 'string') {
            const trimmedSort = params.sort.trim();
            params.sort = trimmedSort !== '' ? trimmedSort : 'id';
        } else {
            params.sort = 'id';
        }

        if (Object.prototype.hasOwnProperty.call(params, 'search')) {
            const search = sanitizeFilterValue(params.search);
            if (search === undefined) {
                delete params.search;
            } else {
                params.search = search;
            }
        }

        return params;
    }

    
    function applyFilterParams(baseParams, filters) {
        const params = sanitizeBaseParams(baseParams || {});


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
        return applyFilterParams(p || {}, {});


    };

    window.reportReasonQueryParams = function (p) {
        return applyFilterParams(window.queryParams(p), {

            status: $('#filter_status').val()
        });
    };

    window.userListQueryParams = function (p) {
        return applyFilterParams(window.queryParams(p), {

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
        return applyFilterParams(window.queryParams(p), {
            ...filters,
            notification_list: 1
        });
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


