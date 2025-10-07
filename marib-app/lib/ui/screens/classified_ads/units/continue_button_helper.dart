/*

// lib/new_code/helpers/continue_button_helper.dart
import 'dart:convert';

enum ContinueType { none, pay, fields }

class PaymentInfo {
  final double amount;
  final String currency; // ISO (e.g., USD, SAR, YER) أو رمز (e.g., $)
  final String? label;   // تسمية اختيارية من الكود
  const PaymentInfo({required this.amount, required this.currency, this.label});

  String get currencySymbol {
    final cUp = currency.toUpperCase().trim();
    switch (cUp) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'SAR': return 'ر.س';
      case 'YER': return 'ر.ي';
      case 'AED': return 'د.إ';
      default:
        // إذا أرسلت رمزًا بدلاً من كود
        if (['$' , '€', '£', '¥', 'ر.س', 'ر.ي', 'د.إ'].contains(currency)) return currency;
        return currency;
    }
  }
}

class ContinueAction {
  final ContinueType type;
  final PaymentInfo? payment;
  final Map<String, dynamic>? fieldsMeta;
  const ContinueAction._(this.type, {this.payment, this.fieldsMeta});

  factory ContinueAction.none() => const ContinueAction._(ContinueType.none);
  factory ContinueAction.pay(PaymentInfo p) => ContinueAction._(ContinueType.pay, payment: p);
  factory ContinueAction.fields(Map<String, dynamic> m) => ContinueAction._(ContinueType.fields, fieldsMeta: m);
}

class ContinueButtonHelper {
  // يلتقط أول تعليق توجيهي مثل:
  // <!-- marib:continue=pay price=49.99 currency=USD label="حزمة ترويج" -->
  // <!-- marib:continue=fields schema=https://example.com/schema.json -->
  static final RegExp _directiveRe = RegExp(
    r'<!--\s*marib:continue\s*=\s*([a-zA-Z0-9_]+)([^-]*)-->',
    multiLine: true,
  );

  // key=value مع دعم علامات اقتباس
  static final RegExp _kvRe = RegExp(
    r'(\w+)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^\s"\'=<>`]+))',
  );

  static ContinueAction parse(String html) {
    if (html.isEmpty) return ContinueAction.none();
    final m = _directiveRe.firstMatch(html);
    if (m == null) return ContinueAction.none();

    final kindRaw = (m.group(1) ?? '').trim().toLowerCase();
    final attrRaw = (m.group(2) ?? '').trim();
    final attrs = <String, String>{};
    for (final kv in _kvRe.allMatches(attrRaw)) {
      final key = (kv.group(1) ?? '').trim().toLowerCase();
      final val = (kv.group(2) ?? kv.group(3) ?? kv.group(4) ?? '').trim();
      if (key.isNotEmpty) attrs[key] = val;
    }

    switch (kindRaw) {
      case 'none':
      case 'hide':
      case 'no':
        return ContinueAction.none();
      case 'fields':
      case 'form':
        // نعيد الميتا كما هي (مثلاً schema أو form_id)
        return ContinueAction.fields(attrs);
      case 'pay':
      case 'payment':
        final p = _parsePayment(attrs);
        return (p != null) ? ContinueAction.pay(p) : ContinueAction.none();
      default:
        return ContinueAction.none();
    }
  }

  static PaymentInfo? _parsePayment(Map<String, String> attrs) {
    // مفاتيح محتملة
    final priceStr = attrs['price'] ?? attrs['amount'] ?? attrs['amt'];
    final curStr   = attrs['currency'] ?? attrs['cur'] ?? attrs['code'] ?? attrs['symbol'];
    final label    = attrs['label'] ?? attrs['title'] ?? attrs['name'];

    if (priceStr == null || priceStr.trim().isEmpty) return null;

    final amount = _parseAmount(priceStr);
    if (amount == null) return null;

    final currency = (curStr == null || curStr.trim().isEmpty)
        ? 'USD' // افتراضي
        : curStr.trim();

    return PaymentInfo(amount: amount, currency: currency, label: label);
  }

  static double? _parseAmount(String raw) {
    var s = raw.trim();
    // إزالة رموز عملة معروفة
    for (final sym in const ['\$', '€', '£', '¥', 'ر.س', 'ر.ي', 'د.إ']) {
      s = s.replaceAll(sym, '');
    }
    s = s.replaceAll(',', ''); // 1,200.50 -> 1200.50
    s = s.replaceAll(RegExp(r'\s+'), '');
    return double.tryParse(s);
  }
}

 */