# Phase 1 – Store Platform Data Model

> Last updated: 2024-08-15

هذه الوثيقة تلخّص الجداول والعلاقات التي تم تصميمها للمرحلة الأولى من قسم المتجر الإلكتروني. يتم تقسيم المعلومات إلى ستة محاور: الأساس، الإعدادات، التشغيل، الطاقم، الإحصاءات، والتكاملات.

## 1. الأساس (جوهر المتجر)

| الجدول | الهدف | الحقول الرئيسية |
| --- | --- | --- |
| `stores` | يمثل المتجر المرتبط بمستخدم مالك. | `user_id`, `name`, `slug`, `status`, `status_changed_at`, `rejection_reason`, `financial_policy_type`, `financial_policy_payload`, `contact_email`, `contact_phone`, `location_*`, `logo_path`, `banner_path`, `meta`. |
| `store_status_logs` | سجل قرارات الإدارة (قبول/رفض/تعليق). | `store_id`, `status`, `reason`, `context`, `changed_by`. |

### حالات المتجر (`stores.status`)
- `pending`
- `approved`
- `rejected`
- `suspended`
- `draft`

## 2. الإعدادات والسياسات

| الجدول | الهدف | الحقول |
| --- | --- | --- |
| `store_settings` | مفاتيح التحكم اليومية (إغلاق يدوي، الحد الأدنى للطلب، خيارات التوصيل/الاستلام). | `closure_mode`, `is_manually_closed`, `manual_closure_reason`, `manual_closure_expires_at`, `min_order_amount`, `allow_pickup`, `allow_delivery`, `allow_manual_payments`, `allow_wallet`, `allow_cod`, `auto_accept_orders`, `delivery_radius_km`, `checkout_notice`, `order_acceptance_buffer_minutes`. |
| `store_working_hours` | جدول الأسبوع (0=الأحد ... 6=السبت). | `weekday`, `is_open`, `opens_at`, `closes_at`. |
| `store_policies` | نصوص الاسترجاع/التبديل/الشحن. | `policy_type`, `title`, `content`, `is_required`, `is_active`, `display_order`. |

## 3. الطاقم والصلاحيات

| الجدول | الهدف |
| --- | --- |
| `store_staff` | يخزن الموظفين المرتبطين بالمتجر (يتضمن البريد المخصص عند الإنشاء). يدعم حالات الدعوة والتفعيل ويحتوي على `permissions` JSON لتفويض جزئي. يتم توليد بريد الموظف بالصيغة `username@maribsrv.com` مع التحقق من عدم تكراره. |

أدوار افتراضية: `owner`, `admin`, `manager`, `staff`, `viewer`.

## 4. المدفوعات والتكاملات

- تم توسيع جدول `store_gateway_accounts` الحالي ليحمل `store_id` إضافةً إلى `user_id`, مما يسمح بربط الحسابات البنكية بالمتجر مباشرةً.
- `items` أصبحت قادرة على الارتباط بمتجر عبر عمود `store_id` الجديد، إلى جانب `user_id` الحالي (لضمان التوافق مع المحتوى السابق).

## 5. الإحصاءات والتتبع

| الجدول | الهدف |
| --- | --- |
| `store_daily_metrics` | تخزين أرقام مجمعة لكل يوم (زيارات، إضافات للسلة، الطلبات، الإيراد، نسبة التحويل). يحتوي على حقل `payload` JSON لأي مقاييس إضافية. |
| `manual_payment_requests` | تمت إضافة العمود `store_id` لربط كل حوالة بصاحب متجر محدد حتى يمكن مراجعتها من واجهة التاجر. |

## 6. القيود والأمان

- جميع الجداول الجديدة تستخدم `bigIncrements` + مفاتيح خارجية مع `cascadeOnDelete` حيث يلزم.
- تمت إضافة فهارس فريدة مثل `(store_id, weekday)` و`(store_id, policy_type)` لضمان التكامل المنطقي.
- تم إعداد Enums (مثل `StoreStatus`, `StoreClosureMode`) في طبقة PHP لربط القيم النصية في قاعدة البيانات بالكود.

## علاقة الجداول (مختصر)

```
User 1 --- * Store
Store 1 --- 1 StoreSetting
Store 1 --- * StoreWorkingHour
Store 1 --- * StorePolicy
Store 1 --- * StoreStaff
Store 1 --- * StoreStatusLog
Store 1 --- * StoreDailyMetric
Store 1 --- * StoreGatewayAccount
Store 1 --- * Item
```

## الخطوة التالية

بعد دمج هذه البنية، يتم الانتقال للمرحلة الثانية لبناء واجهات التسجيل والاعتماد وربط التطبيق بالـ API الجديد.

### واجهات المرحلة الثانية (Onboarding APIs)
- `GET /api/store/onboarding`: جلب مسودة المتجر الحالية مع الإعدادات والساعات والسياسات.
- `POST /api/store/onboarding`: حفظ بيانات المتجر (الأساس + السياسات + الساعات + الموظفين).
- `POST /api/complete-registration`: ما زال مدعومًا لكنه أصبح يمرّر البيانات إلى خدمة التسجيل الجديدة لضمان التوافق مع التطبيق الحالي.
- **واجهات لوحة التاجر (المرحلة 3)**: `/merchant/dashboard`, `/merchant/orders`, `/merchant/manual-payments` داخل الويب تتيح للمالك وموظفه متابعة المؤشرات، الطلبات، والحوالات اليدوية الخاصة بمتجرهم (محميّة بوسيط `store.access`).
