import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/data/model/cart/checkout_models.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/store_status_view_model.dart';
import 'package:marib/utils/store_status_view_model.dart';
import 'delivery_payment_timing_selector.dart';

import 'payment_methods_section.dart';

/// تبويب يحتوي على خيارات الدفع المتاحة بما في ذلك البنوك والمحفظة.
class CartPaymentMethodsTab extends StatelessWidget {
  const CartPaymentMethodsTab({
    super.key,
    required this.loading,
    required this.addressReady,
    required this.banks,
    required this.selectedBankIndex,
    required this.onSelectBank,
    required this.walletSummary,
    required this.walletAvailable,
    required this.walletCurrencyMatchesOrder,
    required this.walletCurrencyCode,
    required this.walletCurrencyLabel,
    required this.orderCurrencyCode,
    required this.orderCurrencyLabel,
    required this.walletSelected,
    required this.walletEnabled,
    required this.onSelectWallet,
    required this.requiredAmount,
    required this.allowPayNow,
    required this.allowPayOnDelivery,
    required this.payOnDeliverySelected,
    this.deliveryPaymentTimingOptions = const <DeliveryPaymentTimingOption>[],
    this.selectedDeliveryPaymentTiming,
    this.onSelectDeliveryPaymentTiming,
    this.initiallyExpanded = true,
    this.storeStatus,
  });

  /// حالة التحميل لعرض مؤشر مناسب في التبويب.
  final bool loading;

  /// جاهزية العنوان التي تسمح بعرض خيارات الدفع الكاملة.
  final bool addressReady;

  /// قائمة البنوك أو مزودي الدفع المتاحة للعميل.
  final List<CheckoutBank> banks;

  /// الفهرس الحالي للبنك المختار.
  final int? selectedBankIndex;

  /// رد الفعل عند اختيار بنك من القائمة.
  final void Function(int index) onSelectBank;

  /// ملخص المحفظة الرقمية للمستخدم.
  final WalletSummary? walletSummary;

  /// ما إذا كانت المحفظة متاحة في هذا السيناريو.
  final bool walletAvailable;

  /// تحديد ما إذا كانت المحفظة هي طريقة الدفع المختارة حاليًا.
  final bool walletSelected;

  /// حالة تمكين المحفظة بناءً على الرصيد والشروط.
  final bool walletEnabled;

  /// رد الفعل عند اختيار المحفظة كطريقة دفع.
  final VoidCallback? onSelectWallet;

  /// ما إذا كانت عملة المحفظة تطابق عملة الطلب الحالية.
  final bool walletCurrencyMatchesOrder;

  /// رمز عملة المحفظة بعد التطبيع إن وجد.
  final String? walletCurrencyCode;

  /// نص عرض عملة المحفظة.
  final String? walletCurrencyLabel;

  /// رمز عملة الطلب الحالية بعد التطبيع إن وجد.
  final String? orderCurrencyCode;

  /// نص عرض عملة الطلب الحالية.
  final String? orderCurrencyLabel;

  /// إجمالي المبلغ المطلوب للدفع.
  final double requiredAmount;

  /// تمكين الدفع الآن.
  final bool allowPayNow;

  /// تمكين الدفع عند الاستلام.
  final bool allowPayOnDelivery;

  /// ما إذا كان خيار الدفع عند الاستلام هو المختار حاليًا.
  final bool payOnDeliverySelected;

  /// تحديد حالة التوسع المبدئي للتبويب.
  final bool initiallyExpanded;

  /// خيارات توقيت الدفع المتاحة للتحديد.
  final List<DeliveryPaymentTimingOption> deliveryPaymentTimingOptions;

  /// القيمة الحالية لتوقيت الدفع المختار.
  final String? selectedDeliveryPaymentTiming;

  /// رد الفعل عند اختيار توقيت دفع مختلف.
  final ValueChanged<String>? onSelectDeliveryPaymentTiming;
  final StoreStatusViewModel? storeStatus;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool manualPaymentsEnabled = storeStatus?.allowManualPayments ?? true;
    String? manualPaymentsMessage;
    if (!manualPaymentsEnabled) {
      manualPaymentsMessage = 'قام التاجر بتعطيل الحوالات اليدوية مؤقتاً.';
    } else if (!(storeStatus?.isOpenNow ?? true)) {
      manualPaymentsMessage = storeStatus?.browseOnly == true
          ? 'المتجر في وضع التصفح فقط حالياً؛ قد تتأخر معالجة الحوالات.'
          : 'المتجر مغلق حالياً وقد تتأخر معالجة الحوالة اليدوية.';
    }

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
          leading: SvgPicture.asset(AppIcons.money, width: 24, height: 24),
          title: const Text(
            'الدفع',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            if (deliveryPaymentTimingOptions.isNotEmpty) ...[
              DeliveryPaymentTimingSelector(
                options: deliveryPaymentTimingOptions,
                selectedValue: selectedDeliveryPaymentTiming,
                onSelect: onSelectDeliveryPaymentTiming,
                isLoading: loading,
                enabled: addressReady && onSelectDeliveryPaymentTiming != null,
              ),
              const SizedBox(height: 16),
            ],
            PaymentMethodsSection(
              loading: loading,
              addressReady: addressReady,
              banks: banks,
              selectedBankIndex: selectedBankIndex,
              onSelectBank: onSelectBank,
              walletSummary: walletSummary,
              walletAvailable: walletAvailable,
              walletSelected: walletSelected,
              walletEnabled: walletEnabled,
              onSelectWallet: onSelectWallet,
              requiredAmount: requiredAmount,
              allowPayNow: allowPayNow,
              allowPayOnDelivery: allowPayOnDelivery,
              payOnDeliverySelected: payOnDeliverySelected,
              walletCurrencyMatchesOrder: walletCurrencyMatchesOrder,
              walletCurrencyCode: walletCurrencyCode,
              walletCurrencyLabel: walletCurrencyLabel,
              orderCurrencyCode: orderCurrencyCode,
              orderCurrencyLabel: orderCurrencyLabel,
              manualPaymentsEnabled: manualPaymentsEnabled,
              manualPaymentsMessage: manualPaymentsMessage,
            ),
          ],
        ),
      ),
    );
  }
}
