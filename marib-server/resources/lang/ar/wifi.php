<?php

return [
    'notifications' => [
        'network_submitted_title' => 'تم استلام طلب إضافة الشبكة',
        'network_submitted_body' => 'تم إرسال شبكتك ":name" إلى كبينة الواي فاي وهي الآن قيد المراجعة.',
        'network_status_title' => 'حالة شبكة الواي فاي تغيرت',
        'network_status_body' => 'تم تحديث حالة الشبكة ":name" إلى :status.',
        'network_status_reason' => 'السبب: :reason.',
        'status_active' => 'مقبولة',
        'status_inactive' => 'متوقفة مؤقتاً',
        'status_suspended' => 'معلقة',
        'commission_updated_title' => 'تم تحديث العمولة على شبكتك',
        'commission_updated_body' => 'تُطبَّق الآن عمولة بنسبة :rate% على مبيعاتك. مثال: في بطاقة قيمتها :amount :currency سيتم خصم :commission :currency، ويُضاف إلى محفظتك :net :currency.',
        'batch_approved_title' => 'تمت الموافقة على دفعة الأكواد',
        'batch_approved_body' => 'أصبحت الدفعة ":label" الخاصة بخطة ":plan" جاهزة للبيع.',
        'batch_rejected_title' => 'تم رفض دفعة الأكواد',
        'batch_rejected_body' => 'تم رفض الدفعة ":label" الخاصة بخطة ":plan".',
        'batch_rejected_reason' => 'السبب: :reason.',
        'purchase_success_title' => 'جاهز لاستخدام بطاقة الواي فاي',
        'purchase_success_body_with_code' => 'تم إصدار بطاقة الواي فاي من ":network". البطاقة: :code',
        'purchase_success_body_without_code' => 'تم إصدار بطاقة الواي فاي من ":network".',
        'owner_sale_title' => 'تم بيع بطاقة واي فاي جديدة',
        'owner_sale_body' => 'تم بيع بطاقة ":plan" بمبلغ :amount :currency. العمولة :commission% (:commission_value :currency). صافي الإيداع :net :currency. البطاقات المتبقية: :remaining.',
        'wallet_credit_title' => 'إيداع جديد في المحفظة',
        'wallet_credit_body' => 'تم إيداع مبلغ :amount :currency في محفظتك (رقم العملية #:transaction).',
    ],
];
