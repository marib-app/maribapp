import 'package:flutter/material.dart';
import 'package:marib/data/model/cart/checkout_models.dart';
import 'package:marib/data/model/item/cart_model.dart';

import 'shared_widgets.dart';
import 'package:marib/utils/currency_utils.dart';



/// ويدجت يقدم ملخص الطلب مع تفاصيل الأسعار والعملة والتنبيهات.
class OrderSummarySection extends StatelessWidget {

  const OrderSummarySection({
    super.key,
    required this.loading,
    required this.cartItems,
    required this.deliveryInfo,
    required this.deliveryFeeLabel,
    required this.freeShippingApplied,
    required this.shippingAmount,
    required this.shippingCurrency,
  });

  // حالة التحميل لعرض قوالب الانتظار.
  final bool loading;




  /// عناصر السلة التي سيتم عرضها داخل الجدول.
  final List<Cart> cartItems;

  /// بيانات التوصيل القادمة من الخادم (تُستخدم لالتقاط العملة).
  final CheckoutDeliveryInfo? deliveryInfo;

  /// التمثيل النصي لرسوم الشحن.
  final String deliveryFeeLabel;

  /// تحديد ما إذا كان الشحن المجاني مطبقًا.
  final bool freeShippingApplied;

  /// القيمة الرقمية لرسوم الشحن إن كانت متوفرة من الواجهة.
  final double? shippingAmount;

  /// العملة المرتبطة بقيمة الشحن.
  final String? shippingCurrency;


  String _resolveCurrency() {
    String? display;
    String? code;

    void considerDisplay(String? candidate) {
      if (display != null) {
        return;
      }
      final String? trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        display = trimmed;
      }
    }
    void considerCode(String? candidate) {
      if (code != null) {
        return;
      }
      final String? normalized = CurrencyUtils.normalizeCurrencyCode(candidate);
      if (normalized != null) {
        code = normalized;
      }
    }

    considerDisplay(shippingCurrency);
    considerCode(shippingCurrency);

    if (deliveryInfo != null) {
      considerDisplay(deliveryInfo!.currency);
      considerCode(deliveryInfo!.currencyCode);
      considerCode(deliveryInfo!.currency);
    }

    for (final Cart item in cartItems) {
      considerDisplay(item.currency);
      considerCode(item.currencyCode);
      considerCode(item.currency);
    }

    if (code == null) {
      considerCode(display);
    }

    return CurrencyUtils.displayToken(
      label: display,
      fallback: code,
      code: code,
    ) ??
        code ??
        '';
  }


  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(
          5,
              (int index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: buildShimmerLine(
              context,
              width: double.infinity,
              height: 28,
            ),
          ),
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color borderColor = isDark ? Colors.white24 : const Color(0xFFE0E6ED);
    final Color tableBackground = isDark ? const Color(0xFF1F1F23) : Colors.white;
    final Color headerColor = isDark ? const Color(0xFF2C2C30) : const Color(0xFFE9EEF3);
    final Color evenRowColor = isDark ? const Color(0xFF232327) : Colors.white;
    final Color oddRowColor = isDark ? const Color(0xFF1B1B1D) : const Color(0xFFF7FAFC);
    final Color totalRowColor = isDark ? const Color(0xFF2C2C30) : const Color(0xFFE6F2FF);
    final Color textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);

    final BorderRadius borderRadius = BorderRadius.circular(14);

    final String currencyLabel = _resolveCurrency();


    String formatAmount(double amount) {
      final double absolute = amount.abs();
      final String formatted = absolute.toStringAsFixed(2);
      if (currencyLabel.isEmpty) {
        return amount < 0 ? '-$formatted' : formatted;
      }
      final String valueWithCurrency = '$formatted $currencyLabel';
      return amount < 0 ? '-$valueWithCurrency' : valueWithCurrency;
    }


    final double itemsTotal = cartItems.fold<double>(
      0,
          (double sum, Cart item) => sum + item.subtotalAmount,
    );
    final double shippingFee = _resolveShippingFeeValue();
    const double taxAmount = 0.0;
    const double discountAmount = 0.0;
    final double grandTotal = itemsTotal + shippingFee + taxAmount - discountAmount;

    final String shippingLabel = _resolveShippingLabel(
      shippingFee,
      formatAmount,
    );

    final List<_SummaryRowData> rows = <_SummaryRowData>[
      _SummaryRowData(title: 'إجمالي سعر المنتجات', value: formatAmount(itemsTotal)),
      _SummaryRowData(title: 'رسوم الشحن', value: shippingLabel),
      _SummaryRowData(title: 'الضريبة', value: formatAmount(taxAmount)),
      _SummaryRowData(title: 'تخفيض', value: formatAmount(-discountAmount)),
    ];

    Widget buildRow({
      required String title,
      required String value,
      required Color backgroundColor,
      bool emphasizeValue = false,
      bool showDivider = true,
      FontWeight titleWeight = FontWeight.w600,
      double fontSize = 13.5,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: showDivider
              ? Border(
            bottom: BorderSide(
              color: borderColor,
              width: 0.7,
            ),
          )
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: fontSize,
                    fontWeight: titleWeight,
                  ),
                ),
              ),
            ),
      Expanded(
      child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
      value,
      style: TextStyle(
      color: emphasizeValue ? theme.colorScheme.primary : textColor,
      fontSize: fontSize,
      fontWeight: emphasizeValue ? FontWeight.w700 : FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,

                ),
              ),
      ),
          ],
        ),
      );
    }


    if (cartItems.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tableBackground,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Text(
            'لا توجد منتجات في السلة حاليًا.',
            style: TextStyle(
              color: textColor.withOpacity(0.75),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tableBackground,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            buildRow(
              title: 'عنصر',
              value: 'المبلغ',
              backgroundColor: headerColor,
              titleWeight: FontWeight.w700,
              fontSize: 14,
            ),
            ...rows.asMap().entries.map((MapEntry<int, _SummaryRowData> entry) {
              final int index = entry.key;
              final _SummaryRowData data = entry.value;
              final bool isLast = index == rows.length - 1;
              final Color background = index.isEven ? evenRowColor : oddRowColor;
              return buildRow(
                title: data.title,
                value: data.value,
                backgroundColor: background,
                showDivider: !isLast,
              );
            }),
            buildRow(
              title: 'المبلغ الإجمالي',
              value: formatAmount(grandTotal),
              backgroundColor: totalRowColor,
              emphasizeValue: true,
              showDivider: false,
              fontSize: 14,
            ),

          ],
        ),
      ),
    );
  }





  String _resolveShippingLabel(
      double shippingFee,
      String Function(double value) formatAmount,
      ) {
    final String trimmedOverride = deliveryFeeLabel.trim();
    if (trimmedOverride.isNotEmpty && trimmedOverride != '—') {
      return trimmedOverride;
    }

    if (freeShippingApplied) {
      return 'مجانًا';
    }

    final String? feeDisplay = deliveryInfo?.feeDisplay?.trim();
    if (feeDisplay != null && feeDisplay.isNotEmpty) {
      return feeDisplay;
    }

    if (deliveryInfo?.fee != null || shippingAmount != null) {
      return formatAmount(shippingFee);
    }

    return '—';
  }

  double _resolveShippingFeeValue() {
    if (shippingAmount != null) {
      return shippingAmount!;
    }
    if (freeShippingApplied) {
      return 0;
    }
    final num? deliveryFee = deliveryInfo?.fee;
    if (deliveryFee != null) {
      return deliveryFee.toDouble();
    }
    final double? parsed = _parseShippingFeeFromLabel(deliveryFeeLabel);
    if (parsed != null) {
      return parsed;
    }
    return 0;
  }

  double? _parseShippingFeeFromLabel(String label) {
    final String trimmed = label.trim();
    if (trimmed.isEmpty || trimmed == '—') {
      return null;
    }
    final String normalized = _normalizeLocalizedDigits(trimmed)
        .replaceAll('٫', '.')
        .replaceAll('٬', '')
        .replaceAll('،', '')
        .replaceAll(',', '');
    final String sanitized =
    normalized.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (sanitized.isEmpty) {
      return null;
    }
    return double.tryParse(sanitized);
  }

  String _normalizeLocalizedDigits(String value) {
    return value.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (Match match) {
      final int codeUnit = match.group(0)!.codeUnitAt(0);
      final int base = (codeUnit >= 0x06F0 && codeUnit <= 0x06F9) ? 0x06F0 : 0x0660;
      return (codeUnit - base).toString();
    });
  }



}

class _SummaryRowData {
  const _SummaryRowData({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;
}