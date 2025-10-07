function queryParams(p) {
    return p;
}

function reportReasonQueryParams(p) {
    return {
        ...p,
        "status": $('#filter_status').val(),
    };
}

function userListQueryParams(p) {
    return {
        ...p,
        "status": $('#filter_status').val(),
    };
}

function notificationUserList(p) {
    const sendTo = $('#send_to').val();
    const params = {
        ...p,
        notification_list: 1
    };
    
    // إذا كان نوع المستخدم هو فردي أو تجاري أو عقاري، نستخدمه كمعيار تصفية
    if (['individual', 'business', 'real_estate'].includes(sendTo)) {
        params.account_type = sendTo;
    }
    
    return params;
}



window.itemListQueryParams = function (p) {
    const params = {
        ...queryParams(p),

    };



    const isValidValue = (value) => value !== undefined && value !== null && value !== '' && value !== 'undefined' && value !== 'null';

    const statusElement = $('#filter');
    if (statusElement.length) {
        const statusValue = statusElement.val();
        if (isValidValue(statusValue)) {
            params.status = statusValue;
        }
    }

    const categoryElement = $('#category_filter');
    if (categoryElement.length) {
        const categoryValue = categoryElement.val();
        if (isValidValue(categoryValue)) {
            params.category_id = categoryValue;
        }
    }

    return params;


};