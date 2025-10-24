// lib/new_code/ui/classified_ads/units/service_payment_page.dart
//
// شاشة دفع عامة لطلبات الخدمات.
// - تستقبل من الـ Route arguments قيم: amount, currency, serviceTitle, itemId, pay_url, note, returnTo
// - تعرض ملخص الدفع (العنوان + المبلغ + العملة + الملاحظة)
// - زر "ادفع الآن" مع حارس نقرات + محاولة فتح pay_url (إن وُجد)
// - fallback ذكي للمفاتيح القديمة: price/total, price_note/payment_note, currency_code/...
//
// ملاحظات:
// * لا نستخدم أي Gateway هنا؛ هذه صفحة وسطية تعرض المبلغ والعملة وتطلق التدفّق (رابط دفع خارجي/محاكاة).
// * يمكنك لاحقًا توصيل بوابة دفع حقيقية داخل _startPayment.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

// (اختياري) لفتح روابط الدفع الخارجية إن كانت متوفرة
import 'package:url_launcher/url_launcher.dart';
import 'package:marib/utils/currency_utils.dart';

class ServicePaymentPage extends StatefulWidget {
  const ServicePaymentPage({super.key, this.args = const {}});
  final Map<String, dynamic> args;

  /// ✅ استدعاء قياسي من routes.dart:
  /// case Routes.servicePaymentPage: return ServicePaymentPage.route(routeSettings);
  static Route route(RouteSettings routeSettings) {
    final Map<String, dynamic> args =
        (routeSettings.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    return MaterialPageRoute(
      builder: (_) => ServicePaymentPage(args: args),
      settings: routeSettings,
    );
  }

  @override
  State<ServicePaymentPage> createState() => _ServicePaymentPageState();
}

class _ServicePaymentPageState extends State<ServicePaymentPage> {
  // مدخلات قادمة من arguments
  late final int? _itemId;
  late final String _serviceTitle;
  late final num? _amount;
  late final String? _currency;      // كود العملة إن وُجد (USD/SAR/...)
  late final String? _currencyLabel; // وصف/رمز العملة إن أُرسل (مثل "SAR ر.س" أو "﷼")
  late final String? _note;
  late final String? _payUrl;     // رابط دفع خارجي إن وجد
  late final String? _returnTo;   // اسم Route للعودة عند نجاح الدفع

  // حالة الواجهة
  bool _processing = false;
  String? _error;

  // اختيار وسيلة الدفع (واجهة فقط - وهمية)
  String _selectedMethod = 'card'; // card / bank / wallet

  @override
  void initState() {
    super.initState();

    num? _toNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    }

    int? _toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      if (v is num) return v.toInt();
      return null;
    }

    String? _toStr(dynamic v) => (v is String) ? v.trim() : v?.toString().trim();

    // ===== قراءات مع Fallback للأسماء القديمة =====
    final a = widget.args;

    _itemId       = _toInt(a['itemId'] ?? a['id']);
    _serviceTitle = _toStr(a['serviceTitle']) ?? 'دفع خدمة';

    // amount ← price/total (fallback)
    _amount   = _toNum(a['amount'] ?? a['price'] ?? a['total']);

    // currency (أولوية للكود، مع حفظ label/الرمز لو متوفر)
    _currency      = _toStr(a['currency'] ?? a['currency_code']);
    _currencyLabel = _toStr(a['currency_label'] ?? a['currencyLabel'] ?? a['currency_symbol']);

    // note ← price_note/payment_note (fallback)
    _note     = _toStr(a['note'] ?? a['price_note'] ?? a['payment_note']);

    _payUrl   = _toStr(a['pay_url'] ?? a['payment_url']);
    _returnTo = _toStr(a['returnTo'] ?? a['return_to']);
  }

  // ======== Helpers ========

  String _currencyLabelFromCode(String? code) {
    final String trimmed = (code ?? '').trim();
    final String? preferred = CurrencyUtils.preferredDisplayFor(trimmed);
    if (preferred != null) {
      return preferred;
    }

    final String upper = trimmed.toUpperCase();
    switch (upper) {
      case 'EUR':
        return 'EUR €';
      case 'AED':
        return 'AED د.إ';
      case 'KWD':
        return 'KWD د.ك';
      case 'OMR':
        return 'OMR ر.ع';
      case 'QAR':
        return 'QAR ر.ق';
      case 'BHD':
        return 'BHD د.ب';
      case 'TRY':
        return 'TRY ₺';
      case 'GBP':
        return 'GBP £';
      case 'YRI':
      case 'YERR':
      return CurrencyUtils.preferredDisplayFor('YER') ?? upper;
      default:
        return upper.isEmpty
            ? CurrencyUtils.preferredDisplayFor('YER') ?? 'YER'
            : upper;
    }
  }

  String _formatAmount(num? amount, String? currencyCode, String? currencyLabel) {
    if (amount == null) return '—';
    final fixed = amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toString();
    // إن وُجد label مخصص من السيرفر استخدمه، وإلا كوّن من الكود
    final label = (currencyLabel?.isNotEmpty == true)
        ? currencyLabel!
        : _currencyLabelFromCode(currencyCode);
    return '$fixed $label';
  }

  Future<void> _launchPayUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذّر فتح رابط الدفع: $url')),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح رابط الدفع')),
      );
    }
  }

  Future<void> _startPayment() async {
    // حارس داخل الدالة — لا تخرج null من onPressed
    if (_processing) return;

    final hasAmount = _amount != null && (_amount ?? 0) > 0;
    if (!hasAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المبلغ غير محدد — لا يمكن متابعة الدفع')),
      );
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      // 1) لو فيه pay_url من الـ HTML/سيرفر — افتحه
      if (_payUrl != null && _payUrl!.isNotEmpty) {
        await _launchPayUrl(_payUrl!);
        // يمكن لاحقًا انتظار Webhook/Callback — الآن ننتقل مباشرة لنجاح شكلي
      } else {
        // 2) لا توجد بوابة — محاكاة عملية دفع
        await Future.delayed(const Duration(seconds: 1));
      }

      // عند "النجاح": لو فيه returnTo نروح له، غير كذا نعرض رسالة ونغلق
      if (!mounted) return;

      if (_returnTo != null && _returnTo!.isNotEmpty) {
        Navigator.of(context).pushNamed(
          _returnTo!,
          arguments: {
            'itemId': _itemId,
            'serviceTitle': _serviceTitle,
            'amount': _amount,
            'currency': _currency ?? _currencyLabel, // نحافظ على اللي نعرفه
            'method': _selectedMethod,
            'note': _note,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الدفع بنجاح')),
        );
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الدفع: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ======== UI ========

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txt = context.color.textColorDark;

    final hasAmount = _amount != null && (_amount ?? 0) > 0;

    return Scaffold(
      backgroundColor: context.color.primaryColor,

      // AppBar بنفس ستايل المشروع (رجوع سلس بدون وميض)
      appBar: AppBar(
        backgroundColor: context.color.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
          color: txt,
          tooltip: 'رجوع',
        ),
        title: Text(
          'الدفع',
          style: TextStyle(color: txt),
        ),
      ),

      // زر سفلي بنفس UiUtils مع حارس داخلي
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: UiUtils.buildButton(
            context,
            buttonTitle: _processing
                ? 'جارٍ المعالجة…'
                : hasAmount
                ? 'ادفع الآن • ${_formatAmount(_amount, _currency, _currencyLabel)}'
                : 'المبلغ غير محدد',
            radius: 12,
            height: 54,
            onPressed: () {
              if (!hasAmount || _processing) return; // حارس
              _startPayment();
            },
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(

          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ملخص الخدمة
              _SummaryCard(
                title: _serviceTitle,
                itemId: _itemId,
                amountText: _formatAmount(_amount, _currency, _currencyLabel),
                note: _note,
                currencyCode: _currency,
                currencyLabel: _currencyLabel,
              ),

              const SizedBox(height: 12),

              // اختيار وسيلة الدفع (عرض فقط - لا بوابة فعلية)
              _PaymentMethodCard(
                selected: _selectedMethod,
                onChanged: (v) => setState(() => _selectedMethod = v),
              ),

              const SizedBox(height: 12),

              // معلومات إضافية/تحذير
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.primary.withOpacity(.10)
                      : theme.colorScheme.primaryContainer.withOpacity(.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _payUrl != null && _payUrl!.isNotEmpty
                            ? 'سيتم فتح بوابة الدفع في متصفح خارجي.'
                            : 'لا توجد بوابة دفع مفعّلة. سيتم تنفيذ دفع تجريبي (Mock) للتجربة.',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4, color: txt.withOpacity(0.85)),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text('خطأ: $_error', style: TextStyle(color: Colors.red.shade400)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.itemId,
    required this.amountText,
    this.note,
    this.currencyCode,
    this.currencyLabel,
  });

  final String title;
  final int? itemId;
  final String amountText;
  final String? note;
  final String? currencyCode;
  final String? currencyLabel;

  @override
  Widget build(BuildContext context) {
    final txt = context.color.textColorDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: txt.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: txt),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تفاصيل الطلب', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: txt)),
            const SizedBox(height: 10),
            _kv('الخدمة', title, txt),
            if (itemId != null) _kv('المعرف', '#$itemId', txt),
            _kv('المبلغ المطلوب', amountText, txt),
            if ((currencyCode ?? currencyLabel)?.isNotEmpty == true && amountText == '—')
              _kv('العملة', (currencyLabel?.isNotEmpty == true ? currencyLabel! : currencyCode!) , txt),
            if ((note ?? '').isNotEmpty) _kv('ملاحظة', note!, txt),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, Color txt) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(k, style: TextStyle(color: txt.withOpacity(0.65)))),
          const SizedBox(width: 6),
          Expanded(child: Text(v, style: TextStyle(fontWeight: FontWeight.w600, color: txt))),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final txt = context.color.textColorDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: txt.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: txt)),
          const SizedBox(height: 8),
          _radio(context, 'card', 'بطاقة (Visa/Mastercard)'),
          _radio(context, 'bank', 'تحويل بنكي'),
          _radio(context, 'wallet', 'محفظة رقمية'),
        ],
      ),
    );
  }

  Widget _radio(BuildContext context, String value, String label) {
    final txt = context.color.textColorDark;
    return RadioListTile<String>(
      value: value,
      groupValue: selected,
      onChanged: (v) => onChanged(v ?? value),
      title: Text(label, style: TextStyle(color: txt)),
      activeColor: txt,
      contentPadding: EdgeInsets.zero,
    );
  }
}
