// lib/new_code/ui/classified_ads/units/continue_directive.dart
//
// مسؤول عن:
// 1) تحليل توجيه "متابعة" من داخل HTML عبر التعليقة:
//    <!-- marib:continue=pay amount=25 currency=SAR note="..." -->
//    <!-- marib:continue=fields schema=https://... -->
//    <!-- marib:continue=none -->
//
// 2) توفير ContinueNavigator.handle(...) لتوجيه المستخدم للروت المناسب
//    وتمرير (amount/currency/...) إن وُجدت.
//
// ملاحظات:
// - لا يعتمد على ثيم/ألوان. ملف منطقي صرف.
// - استخدمه من أي صفحة عبر الاستيراد ثم:
//    final directive = DirectiveParser.parseFromHtml(html);
//    await ContinueNavigator.handle(context, directive: directive, ...);

import 'package:flutter/material.dart';

/// أنواع تصرّف زر "متابعة"
enum ContinueAction { showDefault, none, pay, fields }

/// معطيات الدفع (اختيارية)
class PaymentParams {
  /// القيمة النصية كما جاءت من HTML (قد تحتوي فاصلة عشرية)
  final String? amountRaw;

  /// القيمة العددية (إن أمكن تحويلها)
  final double? amount;

  /// العملة (مثال: SAR, USD, ر.س)
  final String? currency;

  /// ملاحظة/وصف قصير (اختياري)
  final String? note;

  /// أي مفاتيح إضافية ستمر من التعليقة (schema/plan/...الخ)
  final Map<String, String> extras;

  const PaymentParams({
    this.amountRaw,
    this.amount,
    this.currency,
    this.note,
    this.extras = const {},
  });

  factory PaymentParams.fromMap(Map<String, String> kv) {
    final raw = kv['amount'];
    double? parsed;
    if (raw != null) {
      // نحاول تحويلها إلى double بأكبر قدر ممكن من التسامح
      final normalized = raw.replaceAll(',', '.');
      parsed = double.tryParse(normalized);
    }
    return PaymentParams(
      amountRaw: raw,
      amount: parsed,
      currency: kv['currency'] ?? kv['curr'] ?? kv['عملة'],
      note: kv['note'] ?? kv['desc'] ?? kv['description'],
      extras: Map<String, String>.from(kv),
    );
  }

  /// تمثيل مختصر للمبلغ والعملة (مثال: "25 SAR")
  String? compact() {
    final amt =
        amount ?? (amountRaw != null ? double.tryParse(amountRaw!) : null);
    final cur = currency?.trim();
    if (amt != null && cur != null && cur.isNotEmpty) {
      // بدون تنسيق معقّد كي لا نعتمد على intl هنا
      final txt = (amt % 1 == 0) ? amt.toStringAsFixed(0) : amt.toString();
      return '$txt $cur';
    }
    if (amountRaw != null && (cur?.isNotEmpty ?? false)) {
      return '${amountRaw!} $cur';
    }
    return null;
  }
}

/// التوجيه المستخرج من HTML
class ContinueDirective {
  final ContinueAction action;

  /// المعاملات النصية كما جاءت (amount, currency, note, schema ...)
  final Map<String, String> params;

  /// معطيات الدفع (إن كان action = pay)
  final PaymentParams? payment;

  const ContinueDirective(
    this.action, {
    this.params = const {},
    this.payment,
  });

  bool get isHidden => action == ContinueAction.none;
  bool get isPay => action == ContinueAction.pay;
  bool get isFields => action == ContinueAction.fields;

  /// عنوان الزر المقترح (يمكنك تجاهله واستخدام عنوانك الخاص)
  String buttonTitle({String defaultLabel = 'متابعة'}) {
    if (isPay) {
      final p = payment;
      final tag = p?.compact();
      return tag != null ? 'ادفع الآن • $tag' : 'ادفع الآن';
    }
    if (isFields) return 'متابعة (حقول)';
    return defaultLabel;
  }
}

/// محلّل التعليقة داخل HTML
class DirectiveParser {
  // نبحث عن آخر تعليقة من هذا الشكل:
  // <!-- marib:continue=pay amount=25 currency=SAR note="..." -->
  static final RegExp _commentRe = RegExp(
    r'<!--\s*marib:continue=([a-zA-Z]+)([^>]*)-->',
    caseSensitive: false,
    dotAll: true,
  );

  // Regex لاستخراج أزواج key=value مع دعم القيم المحاطة بعلامتي اقتباس
  // ملاحظة: استخدمنا raw triple-quoted string لتجنّب مشاكل الهروب
  static final RegExp _kvRe = RegExp(
    r'''([a-zA-Z_]+)\s*=\s*([^\s"'=]+|"(?:[^"]*)"|'(?:[^']*)')''',
  );

  /// يحوّل tail النصي (بعد الكلمة الرئيسية) إلى خريطة key=>value
  static Map<String, String> _parseKeyValues(String tail) {
    final out = <String, String>{};
    for (final m in _kvRe.allMatches(tail)) {
      final k = (m.group(1) ?? '').trim().toLowerCase();
      var v = (m.group(2) ?? '').trim();
      // إزالة علامات الاقتباس المحيطة إن وجدت
      if ((v.startsWith('"') && v.endsWith('"')) ||
          (v.startsWith("'") && v.endsWith("'"))) {
        v = v.substring(1, v.length - 1);
      }
      out[k] = v;
    }
    return out;
  }

  /// تحويل الكلمة الرئيسية إلى ContinueAction
  static ContinueAction _toAction(String kw) {
    switch (kw.toLowerCase().trim()) {
      case 'none':
        return ContinueAction.none;
      case 'pay':
        return ContinueAction.pay;
      case 'fields':
        return ContinueAction.fields;
      default:
        return ContinueAction.showDefault;
    }
  }

  /// تحليل HTML وإرجاع ContinueDirective
  static ContinueDirective parseFromHtml(String html) {
    if (html.trim().isEmpty) {
      return const ContinueDirective(ContinueAction.showDefault);
    }

    // نأخذ آخر تعليقة (إن تعددت) لتكون هي الحاكمة
    final matches = _commentRe.allMatches(html).toList();
    if (matches.isNotEmpty) {
      final last = matches.last;
      final kw = last.group(1) ?? '';
      final tail = last.group(2) ?? '';
      final params = _parseKeyValues(tail);

      final action = _toAction(kw);
      if (action == ContinueAction.pay) {
        return ContinueDirective(
          action,
          params: params,
          payment: PaymentParams.fromMap(params),
        );
      }
      return ContinueDirective(action, params: params);
    }

    // احتياطي (إن لم توجد تعليقة)، نحاول استنتاج كلمات بسيطة في الأسطر الأخيرة
    final tailText =
        html.trim().split('\n').reversed.take(4).join(' ').toLowerCase();
    if (tailText.contains('الخدمة بدون زر')) {
      return const ContinueDirective(ContinueAction.none);
    }
    if (tailText.contains('الخدمة مدفوعة')) {
      return const ContinueDirective(ContinueAction.pay);
    }
    if (tailText.contains('حقول')) {
      return const ContinueDirective(ContinueAction.fields);
    }

    return const ContinueDirective(ContinueAction.showDefault);
  }
}

/// مُسهّل التنقل بحسب التوجيه
class ContinueNavigator {
  /// يوجّه المستخدم حسب نوع التوجيه. إن كان pay/fields سيقوم بعمل pushNamed.
  ///
  /// [payRouteName]   : اسم روت الدفع
  /// [fieldsRouteName]: اسم روت الحقول
  /// [itemId]         : معرّف الخدمة (إن توفر)
  /// [serviceTitle]   : عنوان الخدمة (إن توفر)
  static Future<void> handle(
    BuildContext context, {
    required ContinueDirective directive,
    required String payRouteName,
    required String fieldsRouteName,
    int? itemId,
    String? serviceTitle,
  }) async {
    if (directive.isHidden || directive.action == ContinueAction.showDefault) {
      // لا شيء: إمّا مُخفى أو الافتراضي (اترك الزر يتصرف من الخارج إن رغبت)
      return;
    }

    if (directive.isPay) {
      final args = <String, dynamic>{
        'itemId': itemId,
        'serviceTitle': serviceTitle ?? '',
        'amount': directive.payment?.amount ?? directive.payment?.amountRaw,
        'currency': directive.payment?.currency,
        'note': directive.payment?.note,
        'rawParams': directive.params, // قد تحتاجها في صفحة الدفع
      };
      await Navigator.pushNamed(context, payRouteName, arguments: args);
      return;
    }

    if (directive.isFields) {
      final args = <String, dynamic>{
        'itemId': itemId,
        'serviceTitle': serviceTitle ?? '',
        // إن كان لديك schema أو أي معاملات مطلوبة للحقول فهي هنا:
        'schema': directive.params['schema'] ??
            directive.params['schema_url'] ??
            directive.params['form'] ??
            '',
        'rawParams': directive.params,
      };
      await Navigator.pushNamed(context, fieldsRouteName, arguments: args);
      return;
    }
  }
}

/* =============================================================================
   تعليمات للمحتوى (للمبرمج/مدير المحتوى في السيرفر)
   -----------------------------------------------------------------------------
   ضع داخل HTML التعليقة التالية لتحديد ما يفعله زر "متابعة":

   1) إخفاء الزر نهائياً:
      <!-- marib:continue=none -->

   2) توجيه للحقول:
      <!-- marib:continue=fields schema=https://example.com/fields/123 -->

   3) توجيه للدفع + تمرير مبلغ/عملة/ملاحظة (أي مفاتيح إضافية مسموح بها):
      <!-- marib:continue=pay amount=25 currency=SAR note="باقة 7 أيام" -->

      - يمكن استخدام علامات اقتباس حول القيم التي تحتوي مسافات:
        note="حملة مميزة لمدة 14 يوم"

      - يمكن أيضاً تمرير مفاتيح إضافية مثل plan, product_id, ... إلخ:
        <!-- marib:continue=pay amount=99.99 currency=USD plan=premium -->

   كيف تُقرأ هذه القيم؟
   - يتم تحليل آخر تعليقة فقط داخل الصفحة.
   - في الكود، يتم استدعاء:
       final directive = DirectiveParser.parseFromHtml(html);
       await ContinueNavigator.handle(context,
         directive: directive,
         payRouteName: Routes.soon,
         fieldsRouteName: Routes.addMoreDetailsScreen,
         itemId: item.id,
         serviceTitle: item.title,
       );

   - لعرض المبلغ في نص الزر تلقائيًا، يمكنك استخدام:
       directive.buttonTitle(defaultLabel: 'continue'.translate(context))

   ملاحظات:
   - إذا لم توجد التعليقة، نحاول استنتاج بعض الكلمات في الذيل ("الخدمة مدفوعة", "حقول", "الخدمة بدون زر")
     وإلا يكون التصرّف الافتراضي showDefault.
   - ملف منطقي فقط؛ صفحة الدفع/الحقول هي من تقرر كيف تعرض amount/currency وتمضي بالعملية.
============================================================================= */
