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
