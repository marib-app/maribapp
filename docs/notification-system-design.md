# تصميم نظام الإشعارات (المرحلة ١)

هذه الوثيقة توضح ناتج تحليل المتطلبات والتصميم التفصيلي لطبقة البيانات والـpayload الموحد قبل البدء بالتنفيذ.

## ١. مخطط البيانات

### ١.١ جدول `notification_preferences`
| العمود | النوع المقترح | الوصف |
| --- | --- | --- |
| `user_id` | `uuid/bigint` | مفتاح خارجي للمستخدم. جزء من المفتاح المركب. |
| `type` | `varchar(64)` | معرف نوع الإشعار (order.status، payment.request، …). جزء من المفتاح المركب. |
| `enabled` | `boolean` (افتراضي `true`) | يوقف/يفعل الإشعارات لهذا النوع. |
| `sound` | `boolean` | يحدد تشغيل الصوت على الأجهزة التي تدعمه. |
| `quiet_hours` | `jsonb` ( `{ "start":"22:00", "end":"07:00", "tz":"Asia/Aden" }` ) | نطاق الصمت لكل مستخدم/نوع. |
| `frequency` | `varchar(16)` (instant/digest/daily/weekly) | أسلوب الإرسال. |
| `channel` | `varchar(16)` (push/email/inbox) | القناة المفضلة. |
| `updated_at` | `timestamp` | آخر تغيير (للكاش والـaudit). |

الفهارس:
- مفتاح أساسي مركب (`user_id`,`type`).
- فهرس جزئي `WHERE enabled = true` لخدمة الاستعلامات السريعة أثناء الإرسال.
- كاش Redis: `preferences:{userId}` (TTL 5 دقائق) يحوي كل الأنواع لتقليل ضربات قاعدة البيانات.

### ١.٢ جدول `notification_deliveries` (توسعة)
أعمدة جديدة:
- `opened_at timestamp NULL` (وقت فتح الرسالة داخل التطبيق).
- `clicked_at timestamp NULL` (وقت الضغط على الإشعار من النظام).
- `device jsonb` ( `{ "token":"xxx", "platform":"android/ios/web", "app_version":"1.2.3" }` ).
- `fingerprint varchar(255)` (hash يجمع `user_id:type:entity:entity_id` لضمان الإدراج مرّة واحدة).
- `collapse_key varchar(64)` لتخزين القيمة المستخدمة فعلياً (مطابقة للسياسة).

فهارس جديدة:
- `idx_notification_deliveries_unread` على `(user_id, opened_at)` مع شرط `WHERE opened_at IS NULL`.
- `idx_notification_deliveries_clicked` على `(type, clicked_at)` لتحليل CTR لكل نوع.
- `idx_notification_deliveries_user_created` على `(user_id, created_at DESC)` لدعم استرجاع البريد الوارد.
- فهرس فريد على `fingerprint` لضمان الـidempotency عند الإدراج.

سيتم تحديث `notification_deliveries.unread_count_cached` (إن وجد) أو الاعتماد على Redis (انظر قسم ٤).

### ١.٣ جدول `action_requests` (اختياري لكنه موصى به)
| العمود | النوع | الوصف |
| --- | --- | --- |
| `id` | `uuid` PK | معرف الطلب (يُستخدم في deeplink). |
| `user_id` | `uuid/bigint` | صاحب الطلب. |
| `kind` | `varchar(32)` | `payment.request`, `kyc.request`, `document.upload`, إلخ. |
| `entity` | `varchar(32)` | order/wallet/chat/merchant… |
| `entity_id` | `varchar(64)` | معرف الكيان المرتبط. |
| `amount` | `numeric(18,2)` | قيمة الطلب (للدفع). |
| `currency` | `varchar(3)` | ISO 4217 أو رمز داخلي. |
| `status` | `varchar(16)` | pending/approved/rejected/expired. |
| `due_at` | `timestamp` | موعد الاستحقاق. |
| `expires_at` | `timestamp` | صلاحية الرابط/الطلب. |
| `meta` | `jsonb` | تفاصيل إضافية (مرفقات، ملاحظات KYC…). |
| `hmac_token` | `varchar(128)` | التوكن الموقّع للروابط أحادية الاستخدام. |
| `used_at` | `timestamp` | وقت استهلاك التوكن. |
| `used_ip` | `varchar(45)` | عنوان IP عند التنفيذ. |
| `used_device` | `varchar(128)` | وصف الجهاز/العميل. |
| `created_at/updated_at` | `timestamp` | تتبع زمني. |

فهارس:
- مركب على `(user_id, status, due_at desc)` لعرض الطلبات في الـInbox.
- فهرس `idx_action_requests_entity` على `(entity, entity_id)` لربط الإشعار بالطلب.

## ٢. الـPayload الموحد

الصيغة المعتمدة (جيسون):
```json
{
  "id": "notif_9eab6",
  "type": "payment.request",
  "title": "مطلوب دفع 12,500 ريال",
  "body": "يرجى إكمال الدفع قبل 3 مساءً.",
  "deeplink": "marib://action-request/notif_9eab6",
  "collapse_key": "wallet:tx_884",
  "ttl": 1800,
  "priority": "high",
  "data": {
    "entity": "wallet",
    "entity_id": "tx_884",
    "request_id": "req_c245",
    "amount": 12500,
    "currency": "YER",
    "status": "pending"
  }
}
```

شرح الحقول:
- `id`: معرف فريد للإشعار (يستل من سجل `notification_deliveries`).
- `type`: يحدد تصنيف الإشعار (مطلوب لتفضيلات المستخدم والسياسات).
- `title`/`body`: نص متعدد اللغات باستخدام قوالب i18n. يجب أن يُشتق من نفس المصدر بين push وInbox.
- `deeplink`: رابط داخلي موحّد (`marib://…`) يوجه إلى الشاشة المناسبة (طلب دفع، تفاصيل طلبية، إلخ).
- `collapse_key`: صيغة `entity:entityId` لضمان دمج الإشعارات المكررة.
- `ttl`: زمن حياة الرسالة (ثوانٍ). الافتراض 1800 (30 دقيقة) ويمكن تعديله حسب النوع.
- `priority`: `high` للطلبات العاجلة (`payment.request`, `kyc.request`)، `normal` للتحديثات العادية.
- `data`: معلومات إضافية (يجب أن تبقى صغيرة < 2KB) وتستخدمها شاشة الـInbox والعميل لتحديث الحالة دون استدعاء فوري.

### ٢.١ مصفوفة السياسة (collapse/ttl/priority)
| النوع | collapse_key | TTL (ثانية) | priority | ملاحظات |
| --- | --- | --- | --- | --- |
| `payment.request` | `wallet:{entity_id}` | 1800 | high | يتطلب deeplink إلى ActionRequest + HMAC. |
| `kyc.request` | `kyc:{entity_id}` | 86400 | high | لا يتغير إلا عند طلب جديد. |
| `order.status` | `order:{entity_id}` | 14400 | normal | collapse لمنع سيل التحديثات. |
| `wallet.alert` | `wallet:{entity_id}` | 3600 | high عند السحب > حد. |
| `broadcast.marketing` | `topic:{topic}` | 43200 | normal | يستخدم تفضيلات التوبيك. |

هذه المصفوفة يجب أن تحفظ في ملف إعدادات (YAML/JSON) مرقّم (`version`) وتُحمَّل داخل `NotificationService`. عند تحديث النسخة يجب تسجيلها في جدول/سجل داخلي لضمان الرجوع، كما يجب تخزين `collapse_key` الناتج داخل سجل `notification_deliveries`.

## ٣. Redis (dedupe & throttle)

### ٣.١ مفاتيح dedupe
- المفتاح: `dedupe:{type}:{userId}:{entity}:{entityId}`
- القيمة: معرف الإشعار الأخير.
- TTL: 1 ساعة للأنواع الحساسة (payment/kyc)، 15 دقيقة لغيرها.
- السلوك: قبل إدخال مهمة الإرسال، يتم فحص المفتاح. إذا وُجد، تُسجل محاولة dedupe ويُمنع إرسال مكرر. عند انتهاء TTL أو اختلاف `entityId`، يُسمح بالإرسال.

### ٣.٢ مفاتيح throttle
- المفتاح: `throttle:{type}:{userId}`
- القيمة: ختم زمني لآخر إرسال.
- TTL: يساوي نافذة التحديد (مثال: order.status = 60 ثانية، marketing broadcast = 3600 ثانية).
- الحالات الخاصة: يمكن تجاوز الـthrottle عند تغيير `priority` إلى high في أوضاع الطوارئ.

### ٣.٣ التسجيل والـmetrics
- كل hit على dedupe/throttle يُسجَّل في `notification_events` أو يرسل إلى نظام المراقبة (Prometheus/Mixpanel).
- مقاييس أساسية: `dedupe_hits_total{type}`, `throttle_hits_total{type}`, `send_latency_ms`, `queue_depth`.

## ٤. فتح/نقر الإشعار وعدّاد غير المقروء

1. **إدراج الإشعار**: عند إضافة سجل `notification_deliveries` يعاد حساب `unread_count` للمستخدم ويخزن في Redis (`unread_count:{userId}`).
2. **فتح من داخل التطبيق**: عند عرض رسالة في Inbox يتم استدعاء `POST /notifications/mark-read`. الخادم يحدّث `opened_at` (timestamp server-side) ويخصم من العدّاد ثم يبطل كاش `unread_count`.
3. **الضغط على Push**: مستمع `onMessageOpenedApp` يرسل `POST /notifications/mark-read` مع العلم بأن الـAPI تسجل `clicked_at` إذا لم تكن موجودة.
4. **المزامنة الدورية**: `GET /notifications/unread-count` يتحقق من Redis أولاً، وفي حالة الفقد يعيد حساب `COUNT(*) WHERE opened_at IS NULL` ويخزن النتيجة لمدة 60 ثانية.
5. **bulk mark-all**: عند استخدام `POST /notifications/mark-all-read` يتم تحديث كل السجلات التي لا تحوي `opened_at` دفعة واحدة (مع قفل تفاؤلي) ثم تعيين الكاش إلى صفر.

## ٥. اعتبارات إضافية
- كل تفضيل جديد أو تعديل على سياسة `collapse/ttl/priority` يجب أن يمر عبر مراجعة ويُحدّث في الوثيقة نفسها لضمان اتساق الخادم والعميل.
- يجب توحيد أسمية الأنواع (`type`) بين الخادم وFlutter عبر ملف ثابت مشترك (مثلاً `notification_types.dart`/`notification_types.rb`).
- عند إنشاء `action_requests` يجب توليد `hmac_token` باستخدام سر وظيفي، وتضمينه في `deeplink` كرابط أحادي الاستخدام (صلاحية 15 دقيقة). يجب أيضاً تسجيل `used_at/used_ip/used_device` عند تنفيذ الطلب.
- يتم حفظ نسخة من الـpayload النهائي في `notification_deliveries.payload` (json أو jsonb حسب قاعدة البيانات). إذا كانت القاعدة MySQL، تستخدم أعمدة `JSON`.
- الحد الأعلى لبيانات `data` داخل payload يجب أن يبقى < 4KB ليتوافق مع حدود FCM. أي حقول كبيرة توضع في الـAPI فقط.
- الإرسال يتم عبر Job Queue مع backoff (مثلاً exponential retry حتى 3 مرات) وتسجيل نتيجة كل محاولة (نجاح/فشل) لكل Device Token.
- الـdeeplink الخاص بـ`action_requests` يعتمد على `request_id` وليس معرف الإشعار لضمان رابط ثابت لذات الطلب.
