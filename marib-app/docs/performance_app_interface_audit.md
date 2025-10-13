+61
-0

# تقرير فحص أداء واجهة التطبيق (الأسئلة 1–18)

1. **FPS وزمن الإطار (P50/P95) للشاشات الرئيسية، القوائم، التفاصيل، السلة، الدفع على جهاز ضعيف.**
    - لا يوجد أي قياس آلي لأزمنة الإطارات في المستودع؛ اختبارات التكامل الموجودة تقتصر على التحقق من مسارات تسجيل الدخول دون تسجيل أي بيانات أداء أو FrameTiming.【F:marib-app/test/app_test.dart†L1-L38】【F:marib-app/test/widget_test.dart†L1-L28】

2. **نسبة الإطارات المفقودة (dropped frames/jank) لكل شاشة.**
    - لا يتوافر نظام رصد للإطارات المفقودة أو التقارير المرتبطة بها؛ حتى إعدادات DevTools خالية من أي ملحقات أو ضبط لمراقبة الجانك.【F:marib-app/devtools_options.yaml†L1-L1】

3. **زمن Time-To-First-Frame (TTFF) وFirst Meaningful Paint (FMP).**
    - لا توجد أدوات قياس أو اختبارات تقيس TTFF أو FMP؛ الاختبارات الحالية لا تجمع أي مؤشرات زمنية أثناء الإقلاع.【F:marib-app/test/app_test.dart†L1-L38】

4. **متوسط عدد إعادة البناء (rebuilds) لكل إطار عند تمرير 100 عنصر.**
    - لم يتم إعداد أي تتبع لإعادة البناء في الشيفرة أو الاختبارات، لذا لا يمكن استخراج المتوسط المطلوب.【F:marib-app/test/app_test.dart†L1-L38】

5. **استخدام ListView/GridView.builder مع itemExtent ثابت وshrinkWrap=false في القوائم.**
    - قائمة العناصر الرئيسية تستخدم `ListView.builder` مع `shrinkWrap: true` ودون تحديد `itemExtent`، ما يعني استمرار حسابات القياس لكل عنصر.【F:marib-app/lib/ui/screens/item/items_list.dart†L673-L687】
    - البحث في الصفحة الرئيسية يعتمد `ListView.separated` مع `shrinkWrap: true` وتعطيل الفيزياء، وبالتالي لا يوجد `itemExtent` ثابت.【F:marib-app/lib/ui/screens/home/search_screen.dart†L622-L659】

6. **وجود مفاتيح (Keys) ثابتة للعناصر داخل القوائم ونسبتها التقريبية.**
    - عناصر `ItemsList` تُنشأ بدون أي `Key` مرفق، ما يجعل إعادة الترتيب مكلفة.【F:marib-app/lib/ui/screens/item/items_list.dart†L673-L687】
    - بعض القوائم (مثل المفضلة) تضيف `ValueKey` فريدة عند استخدام `Dismissible`، لكنها حالات محدودة مقارنة بباقي القوائم، ما يجعل التغطية الإجمالية أقل من 30% تقديرياً.【F:marib-app/lib/ui/screens/other/favorite_screen.dart†L182-L235】

7. **أبعاد المصغّرات في القوائم (160–240px) ومنع تحميل الصورة الأصلية.**
    - بطاقة العناصر الأفقية تضبط العرض الافتراضي على ~100px والارتفاع على ~122px، أي أصغر من النطاق المقترح، كما أنها تستدعي رابط الصورة الأصلي `item.image` مباشرة دون توليد نسخة منخفضة الدقة.【F:marib-app/lib/ui/screens/item/cards/horizontal_card.dart†L71-L118】【F:marib-app/lib/ui/screens/item/cards/horizontal_card.dart†L548-L593】

8. **متوسط حجم صورة المصغّر (P95) بالكيلوبايت.**
    - لا توجد أي أدوات تسجيل أو تحليل لحجم الصور داخل التطبيق، وبالتالي لا تتوفر قيمة فعلية لـP95.【F:marib-app/test/app_test.dart†L1-L38】

9. **متوسط حجم JSON (P95) لصفحات القوائم.**
    - لا يتضمن التطبيق أي طبقة مراقبة لحجم الاستجابات JSON أو تخزينها، لذا لا يمكن تزويد القيمة المطلوبة.【F:marib-app/test/app_test.dart†L1-L38】

10. **وجود Pagination فعلي (10–20 عنصر) وتحميل الصفحة التالية عند 70–80% تمرير.**
    - الحد الأقصى الافتراضي للصفحة مضبوط على 20 عنصراً عبر `apiDataLoadLimit`.【F:marib-app/lib/settings.dart†L45-L55】
    - جلب الصفحة التالية يحصل فقط عند الوصول لنهاية التمرير (`offset >= maxScrollExtent`)، ما يعني عدم وجود تحفيز مسبق عند 70–80%.【F:marib-app/lib/ui/screens/item/items_list.dart†L140-L158】【F:marib-app/lib/utils/ui_utils.dart†L1204-L1209】

11. **تفعيل debounce للبحث (300–500ms) وdedup للطلبات خلال 500–1000ms.**
    - شاشة القوائم تطبّق `Timer` بتأخير 500ms قبل تنفيذ البحث وتمنع تكرار الطلب عند تطابق النص السابق، وهو شكل من أشكال الـdebounce والـdedup ضمن نفس النافذة الزمنية.【F:marib-app/lib/ui/screens/item/items_list.dart†L114-L135】

12. **استخدام BlocSelector أو buildWhen في الشاشات الثقيلة.**
    - الشاشة الرئيسية تغلف البناء بـ`BlocBuilder` مع شرط `buildWhen` لتقليل إعادة البناء غير الضرورية.【F:marib-app/lib/ui/screens/home_screen/home_screen.dart†L161-L190】
    - شاشة تسجيل الدخول تستخدم `BlocSelector` لعزل إعادة البناء على حالة التحميل فقط.【F:marib-app/lib/ui/screens/auth/login/login_screen.dart†L683-L706】

13. **تغليف البنرات والبطاقات الكبيرة داخل RepaintBoundary.**
    - الواجهة الرئيسية والبنرات الأفقية تستخدم `RepaintBoundary` حول الكتل الكبيرة لتقليل عمليات الطلاء المتكرر.【F:marib-app/lib/ui/screens/home_screen/home_screen.dart†L161-L199】【F:marib-app/lib/ui/screens/home_screen/section/section_screen/widgets/slider_widget.dart†L147-L180】
    - بطاقات العناصر (`ItemHorizontalCard`) تعرض الصور مباشرة داخل `CachedNetworkImage` من دون `RepaintBoundary`، ما يعني أن بطاقات القوائم الكبيرة لا تزال خارج هذا العزل.【F:marib-app/lib/ui/screens/item/cards/horizontal_card.dart†L103-L118】

14. **تشغيل parsing JSON والفرز الثقيل داخل Isolates.**
    - نماذج البيانات مثل `ItemSummary`/`ItemModel` تُحوّل JSON إلى كائنات مباشرة على نفس الخيط عبر factory عادية، ولا يوجد استخدام لـ`compute` أو Isolates لتفريغ العمل الثقيل.【F:marib-app/lib/data/model/item/item_model.dart†L72-L134】

15. **قمة استخدام Dart heap / RSS على جهاز ضعيف خلال 10 دقائق.**
    - لا توجد أدوات مراقبة للذاكرة داخل التطبيق أو في الاختبارات، لذا لا يمكن توفير هذه القياسات.【F:marib-app/test/app_test.dart†L1-L38】

16. **إلغاء جميع Controllers/Streams/Timers في `dispose`.**
    - في `ItemsList` يتم إنشاء `Timer` للتأخير (`_searchDelay`) لكن `dispose` لا يستدعي `cancel` عليه، مما يشير إلى عدم اكتمال تنظيف الموارد في بعض الشاشات.【F:marib-app/lib/ui/screens/item/items_list.dart†L60-L111】

17. **سياسة prefetch (عدد العناصر المسبقة وإلغاءها عند تغيير الاتجاه).**
    - التحميل الإضافي يعتمد على الوصول إلى نهاية القائمة فقط ولا توجد آلية لتحديد عدد عناصر مسبقة أو لإلغاء الطلبات عند عكس الاتجاه، لأن شرط التحميل يعتمد على `offset >= maxScrollExtent`.【F:marib-app/lib/ui/screens/item/items_list.dart†L140-L158】【F:marib-app/lib/utils/ui_utils.dart†L1204-L1209】

18. **وضع للأجهزة الضعيفة لتعطيل المؤثرات الثقيلة وخفض جودة الوسائط تلقائياً.**
    - ملف الإعدادات المركزي يعرّف عدداً من الثوابت (مثل `apiDataLoadLimit`، جودة الرفع، أنواع الروابط) دون أي أعلام مرتبطة بوضع منخفض الموارد أو تخفيض جودة الوسائط تلقائياً.【F:marib-app/lib/settings.dart†L34-L105】

marib-server/docs/