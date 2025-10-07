import 'package:flutter/material.dart';
import 'package:marib/data/model/cart/checkout_models.dart';
import 'package:marib/data/model/item/cart_model.dart';

import 'shared_widgets.dart';

/// ويدجت يشرح تفاصيل التوصيل بما في ذلك المسافة والشرائح والرسوم.
class DeliveryDetailsSection extends StatelessWidget {
  final bool loading;
  final bool addressReady;

  final List<Cart> cartItems;
  final CheckoutDeliveryInfo? deliveryInfo;
  final String? deliveryPrice;
  final Future<double?> Function()? distanceFutureGetter;
  final String? paymentTimingLabel;
  final String? paymentTimingNote;
  final bool freeShippingApplied;
  final double? shippingAmount;
  final String? shippingCurrency;
  final String? departmentNotice;


  const DeliveryDetailsSection({
    super.key,
    required this.loading,
    required this.addressReady,

    required this.cartItems,
    required this.deliveryInfo,
    required this.deliveryPrice,
    required this.distanceFutureGetter,
    this.paymentTimingLabel,
    this.paymentTimingNote,
    required this.freeShippingApplied,
    required this.shippingAmount,
    required this.shippingCurrency,
    required this.departmentNotice,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return buildShimmerLine(context, width: double.infinity, height: 50);
    }


    if (!addressReady) {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'يرجى إضافة عنوان توصيل لتحديث تفاصيل المسافة ورسوم التوصيل.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 8),
              Text(
                'بعد اختيار عنوان يضم إحداثيات دقيقة ستظهر تفاصيل المسافة والرسوم المتاحة.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? Colors.grey.shade900 : Colors.white;
    final Color borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final Color subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    final double orderWeight = cartItems.fold(
      0.0,
          (total, item) => total + (item.weight ?? 0.0) * item.quantity,
    );
    final String sizeKey = _weightSizeKey(orderWeight);
    final String sizeLabel = _arabicSize(sizeKey);

    final CheckoutDeliveryInfo? info = deliveryInfo;
    final List<CheckoutDeliveryTier> tiers = info?.tiers ?? const <CheckoutDeliveryTier>[];
    final String currencyLabel = _resolveCurrency();
    final String currencySuffix = currencyLabel.isNotEmpty ? ' $currencyLabel' : '';

    final String? trimmedDeliveryPrice = deliveryPrice?.trim();
    String resolvedPrice;
    if (freeShippingApplied) {
      resolvedPrice = 'مجانًا';
    } else if (trimmedDeliveryPrice != null &&
        trimmedDeliveryPrice.isNotEmpty &&
        trimmedDeliveryPrice != '—') {
      resolvedPrice = trimmedDeliveryPrice;
    } else if (shippingAmount != null) {
      resolvedPrice = _formatAmount(shippingAmount!, currencyLabel);
    } else if (info?.fee != null) {
      resolvedPrice = '${info!.fee}$currencySuffix';
    } else {
      resolvedPrice = '—';
    }

    final String normalizedResolvedPrice = resolvedPrice.trim();
    final bool hasDeliveryFee = normalizedResolvedPrice.isNotEmpty &&
        normalizedResolvedPrice != '—' &&
        normalizedResolvedPrice != 'مجانًا';
    final String deliveryFeeHint = freeShippingApplied
        ? '🎉 تم تطبيق الشحن المجاني على هذا الطلب.'
        : hasDeliveryFee
        ? '🚚 رسوم التوصيل تُدفع للسائق مباشرة.'
        : '🚚 سيتم الاتفاق على أي رسوم توصيل مع السائق عند التسليم (إن وُجدت).';

    final Future<double?> future =
        distanceFutureGetter?.call() ?? Future<double?>.value(info?.distanceKm);

    return FutureBuilder<double?>(
      future: future,
      builder: (context, snapshot) {
        final double? distance = snapshot.data ?? info?.distanceKm;
        final String distanceText =
        distance != null ? '${distance.toStringAsFixed(2)} كم' : 'جاري التحديد...';

        return Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚚 بيانات التوصيل',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                ),
                const SizedBox(height: 12),
                if (freeShippingApplied)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.green.shade800 : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.greenAccent.shade100 : Colors.green.shade400,
                      ),
                    ),
                    child: Text(
                      '🎉 شحن مجاني',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.green.shade700,
                      ),
                    ),
                  ),
                if (tiers.isNotEmpty) ...[
                  Text(
                    'شرائح الأحجام حسب النظام',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  ...tiers.map(
                        (tier) => _buildTierRow(
                      tier,
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      currencySuffix: currencySuffix,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Table(
                  border: TableBorder.all(color: borderColor, width: 1, borderRadius: BorderRadius.circular(12)),
                  columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2)},
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE),
                      ),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Center(child: Text('عنصر')),
                        ),
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Center(child: Text('القيمة')),
                        ),
                      ],
                    ),
                    _row('📦 وزن الطلب', '${orderWeight.toStringAsFixed(1)} كجم ($sizeLabel)', textColor),
                    _row('📍 المسافة إلى التاجر', distanceText, textColor),
                    _row('💸 رسوم التوصيل', resolvedPrice, textColor),
                  ],
                ),
                const SizedBox(height: 10),
                if (paymentTimingLabel != null && paymentTimingLabel!.trim().isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⏱ ${paymentTimingLabel!.trim()}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (paymentTimingNote != null && paymentTimingNote!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              paymentTimingNote!.trim(),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),


                if (departmentNotice != null && departmentNotice!.trim().isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.orange.shade200 : const Color(0xFFFFEEBA),
                      ),
                    ),
                    child: Text(
                      departmentNotice!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.orange.shade100 : const Color(0xFF856404),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: freeShippingApplied
                        ? (isDark ? Colors.green.shade900 : const Color(0xFFE8F5E9))
                        : (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFFFF3F3)),

                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    deliveryFeeHint,
                    style: TextStyle(
                      fontSize: 13,
                      color: freeShippingApplied
                          ? (isDark ? Colors.greenAccent.shade100 : Colors.green.shade700)
                          : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  TableRow _row(String title, String value, Color textColor) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(title, style: TextStyle(fontSize: 13, color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
          ),
        ),
      ],
    );
  }


  String _resolveCurrency() {
    final String? fromShipping = shippingCurrency?.trim();
    if (fromShipping != null && fromShipping.isNotEmpty) {
      return fromShipping;
    }
    final String? fromInfo = deliveryInfo?.currency?.trim();
    if (fromInfo != null && fromInfo.isNotEmpty) {
      return fromInfo;
    }
    return 'ر.س';
  }

  String _formatAmount(double amount, String currency) {
    final bool hasFraction = amount % 1 != 0;
    final String formatted =
    hasFraction ? amount.toStringAsFixed(2) : amount.toStringAsFixed(0);
    return '$formatted $currency';
  }



  Widget _buildTierRow(
      CheckoutDeliveryTier tier, {
        required bool isDark,
        required Color textColor,
        required Color subTextColor,
        required String currencySuffix,
      }) {
    final String priceText = (tier.priceDisplay?.trim().isNotEmpty ?? false)
        ? tier.priceDisplay!.trim()
        : (tier.price != null ? '${tier.price}$currencySuffix' : '—');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                ),
                if (tier.description != null && tier.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      tier.description!.trim(),
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            priceText,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
          ),
        ],
      ),
    );
  }

  String _weightSizeKey(double weight) {
    if (weight <= 5) return 'small';
    if (weight <= 20) return 'medium';
    return 'large';
  }

  String _arabicSize(String sizeKey) {
    switch (sizeKey) {
      case 'small':
        return 'صغير';
      case 'medium':
        return 'متوسط';
      case 'large':
        return 'كبير';
      default:
        return sizeKey;
    }
  }
}