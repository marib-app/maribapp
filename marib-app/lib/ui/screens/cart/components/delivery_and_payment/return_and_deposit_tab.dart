import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/utils/app_icon.dart';

import 'deposit_summary_card.dart';
import 'shared_widgets.dart';

/// تبويب مخصص لعرض تفاصيل الوديعة وسياسة الإرجاع التابعة للقسم الحالي.
class CartReturnAndDepositTab extends StatelessWidget {
  const CartReturnAndDepositTab({
    super.key,
    required this.loading,
    this.returnPolicyText,
    this.depositInfo,
    this.onToggleDeposit,
    this.initiallyExpanded = false,
    this.storageKey,
  });

  /// حالة التحميل العامة للشاشة، لإظهار هيكل عظمى عند عدم توفر البيانات بعد.
  final bool loading;

  /// نص سياسة الإرجاع الخاصة بالقسم.
  final String? returnPolicyText;

  /// التفاصيل المنسّقة للوديعة المطلوبة.
  final Map<String, dynamic>? depositInfo;

  /// رد الفعل عند تغيير حالة تفعيل الدفعة المقدمة.
  final ValueChanged<bool>? onToggleDeposit;

  /// ما إذا كان التبويب يجب أن يظهر موسعًا بشكل افتراضي.
  final bool initiallyExpanded;

  /// مفتاح تخزين حالة التوسيع لئلا يُغلق بعد أول فتح.
  final Key? storageKey;

  bool get _hasReturnPolicy =>
      returnPolicyText != null && returnPolicyText!.trim().isNotEmpty;

  bool get _hasDepositContent {
    final Map<String, dynamic>? data = depositInfo;
    if (data == null) return false;
    final dynamic amount = data['amountDueNow'] ?? data['effectiveAmountDueDisplay'];
    final dynamic total = data['totalAmount'] ?? data['effectiveTotalDisplay'];
    final dynamic percent = data['percent'];
    final dynamic goodsValue = data['goodsValue'];
    final dynamic remaining = data['remainingBalance'] ?? data['effectiveRemainingDisplay'];
    final dynamic includesShipping = data['includesShipping'];
    final dynamic message = data['message'];
    final bool hasToggle = data['toggleAllowed'] == true || data['toggleRequired'] == true;
    return _isNonEmptyString(amount) ||
        _isNonEmptyString(total) ||

        _isNonEmptyString(percent) ||
        _isNonEmptyString(goodsValue) ||
        _isNonEmptyString(remaining) ||
        _isNonEmptyString(message) ||
        includesShipping != null ||
        hasToggle;
  }

  bool get _hasContent => _hasReturnPolicy || _hasDepositContent;

  @override
  Widget build(BuildContext context) {
    if (!_hasContent && !loading) {
      return const SizedBox.shrink();
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildLoadingSkeleton() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildShimmerLine(context, width: 200, height: 14),
            const SizedBox(height: 12),
            buildShimmerLine(context, width: 260, height: 48),
            const SizedBox(height: 10),
            buildShimmerLine(context, width: 220, height: 12),
            const SizedBox(height: 6),
            buildShimmerLine(context, width: 180, height: 12),
          ],
        ),
      );
    }

    final Widget body = (loading || !_hasContent)
        ? buildLoadingSkeleton()
        : Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasDepositContent)
            DepositSummaryCard(
              data: depositInfo,
              onToggle: onToggleDeposit,
            ),
          if (_hasDepositContent && _hasReturnPolicy)
            const SizedBox(height: 12),
          if (_hasReturnPolicy)
            buildReturnPolicyCard(context, returnPolicyText!),
        ],
      ),
    );

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
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: storageKey ?? const PageStorageKey<String>('cart_return_deposit'),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: SvgPicture.asset(AppIcons.money, width: 24, height: 24),
          title: const Text(
            'الوديعة وسياسة الإرجاع',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          childrenPadding:
          const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          children: [body],
        ),
      ),
    );
  }

  bool _isNonEmptyString(dynamic value) {
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    return value != null;
  }
}
