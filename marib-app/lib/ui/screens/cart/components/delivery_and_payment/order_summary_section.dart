import 'package:flutter/material.dart';
import 'package:marib/data/model/cart/checkout_models.dart';
import 'package:marib/data/model/item/cart_model.dart';

import 'shared_widgets.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/money_formatter.dart';
import 'package:marib/data/model/cart/cart_discount.dart';

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
    required this.discounts,
    required this.onRemoveCoupon,
    required this.couponInProgress,
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

  /// قائمة الخصومات المطبقة على السلة.
  final List<CartDiscount> discounts;

  /// رد الفعل عند إزالة إحدى القسائم.
  final ValueChanged<CartDiscount> onRemoveCoupon;

  /// حالة انشغال واجهة القسائم (لمنع التفاعل أثناء التحديث).
  final bool couponInProgress;

  static const double _discountEpsilon = 0.0001;

  CurrencyParseResult _resolveCurrencyInfo() {
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
      if (normalized != null && normalized.isNotEmpty) {
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
    final List<CurrencyParseResult> itemCandidates = <CurrencyParseResult>[];

    for (final Cart item in cartItems) {
      considerDisplay(item.currency);
      considerCode(item.currencyCode);
      considerCode(item.currency);

      final String? trimmedCurrency = item.currency?.trim();
      final String? trimmedCode = item.currencyCode?.trim();
      final String? normalizedCode =
          CurrencyUtils.normalizeCurrencyCode(trimmedCode ?? trimmedCurrency);

      if ((trimmedCurrency != null && trimmedCurrency.isNotEmpty) ||
          (normalizedCode != null && normalizedCode.isNotEmpty)) {
        itemCandidates.add(
          CurrencyParseResult(
            code: normalizedCode,
            display: trimmedCurrency ?? trimmedCode,
          ),
        );
      }
    }

    if (itemCandidates.isNotEmpty) {
      final Set<String> itemCodes = itemCandidates
          .map((CurrencyParseResult candidate) => candidate.code)
          .whereType<String>()
          .where((String value) => value.trim().isNotEmpty)
          .map((String value) => value.trim())
          .toSet();

      if (itemCodes.length == 1) {
        code = itemCodes.first;
      } else if (code == null && itemCodes.isNotEmpty) {
        code = itemCodes.first;
      }

      final String? currentDisplayNormalized =
          CurrencyUtils.normalizeCurrencyCode(display);
      if (code != null &&
          (currentDisplayNormalized == null ||
              currentDisplayNormalized != code)) {
        for (final CurrencyParseResult candidate in itemCandidates) {
          final String? candidateDisplay = candidate.display?.trim();
          if (candidateDisplay == null || candidateDisplay.isEmpty) {
            continue;
          }
          if (candidate.code != null && candidate.code == code) {
            display = candidateDisplay;
            break;
          }
        }
      }

      if (display == null || display!.trim().isEmpty) {
        final Iterable<String> displays = itemCandidates
            .map((CurrencyParseResult candidate) => candidate.display?.trim())
            .whereType<String>()
            .where((String value) => value.isNotEmpty);
        final Set<String> uniqueDisplays = displays.toSet();
        if (uniqueDisplays.length == 1) {
          display = uniqueDisplays.first;
        } else if (display == null && displays.isNotEmpty) {
          display = displays.first;
        }
      }
    }

    if (code == null) {
      considerCode(display);
    }

    return CurrencyParseResult(code: code, display: display?.trim());
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
    final Color tableBackground =
        isDark ? const Color(0xFF1F1F23) : Colors.white;
    final Color headerColor =
        isDark ? const Color(0xFF2C2C30) : const Color(0xFFE9EEF3);
    final Color evenRowColor = isDark ? const Color(0xFF232327) : Colors.white;
    final Color oddRowColor =
        isDark ? const Color(0xFF1B1B1D) : const Color(0xFFF7FAFC);
    final Color totalRowColor =
        isDark ? const Color(0xFF2C2C30) : const Color(0xFFE6F2FF);
    final Color textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);

    final BorderRadius borderRadius = BorderRadius.circular(14);

    final CurrencyParseResult currencyInfo = _resolveCurrencyInfo();
    final MoneyFormatter moneyFormatter = MoneyFormatter.fromCartCurrency(
      currency: currencyInfo.display,
      currencyCode: currencyInfo.code,
      fallbackLabel: currencyInfo.display ?? currencyInfo.code,
    );

    String formatAmount(double amount) {
      return moneyFormatter.format(amount);
    }

    final double itemsTotal = cartItems.fold<double>(
      0,
      (double sum, Cart item) => sum + item.subtotalAmount,
    );
    final double shippingFee = _resolveShippingFeeValue();
    const double taxAmount = 0.0;
    final List<CartDiscount> appliedDiscounts =
        discounts.where((CartDiscount discount) => discount.isApplied).toList();

    final double totalDiscountAmount = appliedDiscounts.fold<double>(
      0,
      (double sum, CartDiscount discount) =>
          sum + _normalizeDiscountAmount(discount),
    );

    final double normalizedDiscountTotal =
        totalDiscountAmount <= _discountEpsilon ? 0 : totalDiscountAmount;

    final double rawGrandTotal =
        itemsTotal + shippingFee + taxAmount - normalizedDiscountTotal;
    final double grandTotal = rawGrandTotal < 0 ? 0 : rawGrandTotal;

    final String shippingLabel = _resolveShippingLabel(
      shippingFee,
      formatAmount,
    );

    final Color removeIconColor =
        isDark ? Colors.white60 : Colors.blueGrey.shade400;

    final List<_SummaryRowData> rows = <_SummaryRowData>[
      _SummaryRowData(
          title: 'إجمالي سعر المنتجات', value: formatAmount(itemsTotal)),
      _SummaryRowData(title: 'رسوم الشحن', value: shippingLabel),
      _SummaryRowData(title: 'الضريبة', value: formatAmount(taxAmount)),
      _SummaryRowData(
        title: 'تخفيض',
        value: normalizedDiscountTotal <= _discountEpsilon
            ? formatAmount(0)
            : formatAmount(-normalizedDiscountTotal),
      ),
      ...appliedDiscounts.map((CartDiscount discount) {
        final double? signedAmount = _resolveDiscountSignedAmount(discount);
        final String discountValue = signedAmount == null
            ? '—'
            : formatAmount(
                signedAmount.abs() <= _discountEpsilon ? 0 : signedAmount,
              );
        final bool removalDisabled = couponInProgress;
        final Color iconColor = removalDisabled
            ? removeIconColor.withOpacity(0.45)
            : removeIconColor;
        return _SummaryRowData(
          title: _buildDiscountTitle(discount),
          value: discountValue,
          trailing: IconButton(
            onPressed: removalDisabled ? null : () => onRemoveCoupon(discount),
            icon: Icon(Icons.close, size: 18, color: iconColor),
            tooltip: 'إزالة القسيمة',
            splashRadius: 18,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
          ),
        );
      }),
    ];

    Widget buildRow({
      required String title,
      required String value,
      required Color backgroundColor,
      bool emphasizeValue = false,
      bool showDivider = true,
      FontWeight titleWeight = FontWeight.w600,
      double fontSize = 13.5,
      Widget? trailing,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: emphasizeValue
                              ? theme.colorScheme.primary
                              : textColor,
                          fontSize: fontSize,
                          fontWeight: emphasizeValue
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trailing != null) ...<Widget>[
                      const SizedBox(width: 4),
                      trailing,
                    ],
                  ],
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
              final Color background =
                  index.isEven ? evenRowColor : oddRowColor;
              return buildRow(
                title: data.title,
                value: data.value,
                backgroundColor: background,
                showDivider: !isLast,
                trailing: data.trailing,
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

  double _normalizeDiscountAmount(CartDiscount discount) {
    final num? amount = discount.amount;
    if (amount == null) {
      return 0;
    }
    final double value = amount.toDouble();
    if (value.isNaN || value.isInfinite) {
      return 0;
    }
    return value < 0 ? -value : value;
  }

  double? _resolveDiscountSignedAmount(CartDiscount discount) {
    final num? amount = discount.amount;
    if (amount == null) {
      return null;
    }
    final double value = amount.toDouble();
    if (value.isNaN || value.isInfinite) {
      return 0;
    }
    if (value < 0) {
      return value;
    }
    return -value;
  }

  String _buildDiscountTitle(CartDiscount discount) {
    final String? rawLabel = discount.label?.trim();
    final String? rawCode = discount.code?.trim();

    final String label = rawLabel ?? '';
    final String code = rawCode ?? '';

    if (label.isEmpty && code.isEmpty) {
      return discount.displayTitle;
    }

    if (label.isEmpty) {
      return code.toUpperCase();
    }

    if (code.isEmpty) {
      return label;
    }

    final String normalizedLabel = label.toLowerCase();
    final String normalizedCode = code.toLowerCase();
    if (normalizedLabel.contains(normalizedCode)) {
      return label;
    }

    return '$label (${code.toUpperCase()})';
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
    final String sanitized = normalized.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (sanitized.isEmpty) {
      return null;
    }
    return double.tryParse(sanitized);
  }

  String _normalizeLocalizedDigits(String value) {
    return value.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (Match match) {
      final int codeUnit = match.group(0)!.codeUnitAt(0);
      final int base =
          (codeUnit >= 0x06F0 && codeUnit <= 0x06F9) ? 0x06F0 : 0x0660;
      return (codeUnit - base).toString();
    });
  }
}

class _SummaryRowData {
  const _SummaryRowData({
    required this.title,
    required this.value,
    this.trailing,
  });

  final String title;
  final String value;
  final Widget? trailing;
}
