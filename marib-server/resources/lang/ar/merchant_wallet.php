<?php

return [
    'page' => [
        'title' => 'محفظة المتجر',
        'subtitle' => 'تابع رصيدك والحركات المالية وطلبات السحب بكل سهولة.',
        'back' => 'العودة للوحة المتجر',
        'close' => 'إغلاق',
    ],
    'tabs' => [
        'summary' => 'نظرة عامة',
        'transactions' => 'الحركات',
        'withdrawals' => 'طلبات السحب',
        'request' => 'طلب جديد',
    ],
    'messages' => [
        'unavailable' => 'بيانات المحفظة غير متاحة حالياً.',
        'insufficient' => 'رصيد المحفظة غير كافٍ لإتمام السحب.',
        'error' => 'تعذر معالجة الطلب الآن، يرجى المحاولة لاحقاً.',
        'success' => 'تم إرسال طلب السحب بنجاح وبانتظار المراجعة.',
    ],
    'summary' => [
        'balance_title' => 'رصيد المحفظة الحالي',
        'balance_updated' => 'آخر تحديث: :datetime',
        'pending_title' => 'الطلبات قيد المراجعة',
        'pending_caption' => 'طلبات سحب بانتظار المراجعة (:count)',
        'activity_title' => 'نشاط المحفظة',
        'activity_transactions' => 'عدد الحركات',
        'activity_withdrawals' => 'عدد طلبات السحب',
        'latest_transactions' => 'أحدث الحركات',
        'latest_withdrawals' => 'أحدث طلبات السحب',
        'view_all' => 'عرض الكل',
        'empty' => 'لا توجد بيانات حتى الآن.',
    ],
    'table' => [
        'type' => 'النوع',
        'amount' => 'المبلغ',
        'balance_after' => 'الرصيد بعد العملية',
        'date' => 'التاريخ',
        'method' => 'طريقة التحويل',
        'status' => 'الحالة',
    ],
    'transaction_types' => [
        'credit' => 'إيداع',
        'debit' => 'سحب',
    ],
    'transactions' => [
        'title' => 'الحركات',
        'empty' => 'لا توجد حركات بعد.',
    ],
    'withdrawals' => [
        'title' => 'طلبات السحب',
        'empty' => 'لا توجد طلبات سحب بعد.',
        'status' => [
            'pending' => 'قيد المراجعة',
            'approved' => 'معتمد',
            'rejected' => 'مرفوض',
        ],
    ],
    'form' => [
        'title' => 'إنشاء طلب سحب',
        'hint' => 'الحد الأدنى لكل طلب هو :amount :currency.',
        'amount' => 'مبلغ السحب',
        'method' => 'طريقة التحويل',
        'notes' => 'ملاحظات إضافية',
        'submit' => 'إرسال الطلب',
    ],
];
