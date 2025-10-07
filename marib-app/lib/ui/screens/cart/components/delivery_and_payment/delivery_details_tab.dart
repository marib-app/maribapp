import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/data/model/cart/checkout_models.dart';
import 'package:marib/utils/app_icon.dart';

import 'package:marib/ui/screens/cart/components/delivery_and_payment/delivery_details_section.dart';

/// تبويب يقدّم معلومات التوصيل من مسافة وسعر وتفاصيل أخرى.
class CartDeliveryDetailsTab extends StatelessWidget {
  const CartDeliveryDetailsTab({
    super.key,
    required this.loading,
    required this.addressReady,
    required this.cartItems,
    required this.deliveryInfo,
    required this.deliveryPrice,
    required this.paymentTimingLabel,
    this.paymentTimingNote,
    required this.distanceFutureGetter,
    required this.freeShippingApplied,
    required this.shippingAmount,
    required this.shippingCurrency,
    required this.departmentNotice,
    this.initiallyExpanded = true,
  });

  /// حالة التحميل لعرض مؤثرات الانتظار.
  final bool loading;

  /// جاهزية العنوان لحساب بيانات التوصيل.
  final bool addressReady;

  /// عناصر السلة التي تؤثر على خيارات التوصيل.
  final List<Cart> cartItems;

  /// معلومات التوصيل التفصيلية القادمة من واجهة البرمجة.
  final CheckoutDeliveryInfo? deliveryInfo;

  /// قيمة التوصيل الحالية للعرض ضمن التبويب.
  final String deliveryPrice;

  /// التسمية التوضيحية لتوقيت الدفع.
  final String paymentTimingLabel;

  /// ملاحظة إضافية حول توقيت الدفع.
  final String? paymentTimingNote;

  /// دالة لجلب المسافة من الخادم عند الحاجة.
  final Future<double?> Function()? distanceFutureGetter;

  /// تحديد ما إذا كان الشحن المجاني مطبقًا.
  final bool freeShippingApplied;

  /// قيمة الشحن الرقمية (إن وُجدت).
  final double? shippingAmount;

  /// عملة الشحن المرتبطة بالقيمة الرقمية.
  final String? shippingCurrency;

  /// أي تنبيهات خاصة بالقسم أو الإدارة.
  final String? departmentNotice;

  /// ضبط التوسع الابتدائي للتبويب.
  final bool initiallyExpanded;

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
          leading: SvgPicture.asset(AppIcons.delivery, width: 24, height: 24),
          title: const Text(
            'التوصيل',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            DeliveryDetailsSection(
              loading: loading,
              addressReady: addressReady,
              cartItems: cartItems,
              deliveryInfo: deliveryInfo,
              deliveryPrice: deliveryPrice,
              paymentTimingLabel: paymentTimingLabel,
              paymentTimingNote: paymentTimingNote,
              distanceFutureGetter: distanceFutureGetter,
              freeShippingApplied: freeShippingApplied,
              shippingAmount: shippingAmount,
              shippingCurrency: shippingCurrency,
              departmentNotice: departmentNotice,
            ),
          ],
        ),
      ),
    );
  }
}
