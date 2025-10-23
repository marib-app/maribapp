import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/data/model/cart/cart_discount.dart';
import 'package:marib/data/model/cart/checkout_models.dart';
import 'package:marib/utils/app_icon.dart';

import 'order_summary_section.dart';

/// تبويب يستعرض تفاصيل ملخص الطلب من أصناف وخصومات وكوبونات.
class CartOrderSummaryTab extends StatelessWidget {
  const CartOrderSummaryTab({
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
    this.initiallyExpanded = true,
  });

  /// حالة التحميل لعرض قوالب الانتظار.
  final bool loading;


  /// عناصر السلة المراد تلخيصها.
  final List<Cart> cartItems;

  /// بيانات التوصيل الآتية من الخادم.
  final CheckoutDeliveryInfo? deliveryInfo;

  /// النص الظاهر في واجهة المستخدم لرسوم الشحن.
  final String deliveryFeeLabel;

  /// توضيح ما إذا كان الشحن المجاني مطبقًا.
  final bool freeShippingApplied;

  /// القيمة الرقمية لرسوم الشحن (إن توافرت).
  final double? shippingAmount;

  /// العملة المصاحبة لقيمة الشحن الرقمية.
  final String? shippingCurrency;


  /// التحكم في ما إذا كان التبويب مفتوحًا افتراضيًا.
  final bool initiallyExpanded;

  /// الخصومات المطبقة على السلة.
  final List<CartDiscount> discounts;

  /// الاستدعاء المستخدم لإزالة القسائم من السلة.
  final ValueChanged<CartDiscount> onRemoveCoupon;

  /// تحديد ما إذا كانت عملية تطبيق القسيمة قيد التنفيذ حاليًا.
  final bool couponInProgress;



  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: SvgPicture.asset(AppIcons.summary, width: 24, height: 24),
          title: const Text(
            'ملخص الطلب',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            OrderSummarySection(
              loading: loading,
              cartItems: cartItems,
              deliveryInfo: deliveryInfo,
              deliveryFeeLabel: deliveryFeeLabel,
              freeShippingApplied: freeShippingApplied,
              shippingAmount: shippingAmount,
              shippingCurrency: shippingCurrency,
              discounts: discounts,
              onRemoveCoupon: onRemoveCoupon,
              couponInProgress: couponInProgress,
            ),
          ],
        ),
      ),
    );
  }
}