# Manual Test - NotificationController::store FCM key handling

هذه الخطوات توضح كيفية التحقق يدويًا من أن `NotificationController::store` لا يطرح استثناءً سواء وُجد مفتاح FCM أو فُقد، مع ظهور رسالة واضحة عند غيابه.

## المتطلبات المسبقة
- امتلاك حساب إداري أو أي حساب يمتلك صلاحية `notification-create`.
- القدرة على تسجيل الدخول إلى لوحة التحكم وتشغيل أوامر artisan.

## حالة وجود المفتاح
1. أضف قيمة لمفتاح FCM في إعدادات النظام (إما من لوحة التحكم أو عبر الأمر التالي):
   ```bash
   php artisan tinker --execute="\\App\\Models\\Setting::updateOrCreate(['name' => 'fcm_key'], ['value' => 'test-key']);"
   ```
2. من لوحة التحكم (أو باستخدام طلب `POST` إلى مسار `notification.store`) أرسل إشعارًا تجريبيًا بحقلي `title` و`message` وأي حقل مطلوب آخر.
3. تأكد من نجاح العملية وأنه لم يتم عرض أي رسالة خطأ متعلقة بمفتاح FCM.

## حالة غياب المفتاح
1. احذف قيمة المفتاح للتجربة:
   ```bash
   php artisan tinker --execute="\\App\\Models\\Setting::where('name', 'fcm_key')->delete();"
   ```
2. أعد إرسال الطلب نفسه إلى `notification.store`.
3. تأكد من تلقي استجابة JSON تحتوي على `error: true` و`message: "Server FCM Key Is Missing"` بدون ظهور استثناء في السجلات أو الواجهة.

باتّباع هاتين الحالتين يمكن التأكد من أن الدالة تعمل كما هو متوقع سواء توفر المفتاح أم لا.
