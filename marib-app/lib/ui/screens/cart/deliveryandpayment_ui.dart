// ط§ظ„ظˆط§ط¬ظ‡ط© ظپظ‚ط·
import 'package:flutter/material.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marib/data/model/cart/checkout_models.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/data/model/cart/cart_discount.dart';

import 'components/delivery_and_payment/delivery_address_tab.dart';
import 'components/delivery_and_payment/order_summary_tab.dart';
import 'components/delivery_and_payment/payment_methods_tab.dart';
import 'components/delivery_and_payment/shared_widgets.dart';
import 'components/delivery_and_payment/payment_methods_section.dart';
import 'components/delivery_and_payment/return_and_deposit_tab.dart';
import 'components/delivery_and_payment/delivery_payment_timing_selector.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/money_formatter.dart';
import 'components/delivery_and_payment/manual_transfer_submission.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:marib/ui/widgets/store_status_card.dart';
import 'package:marib/utils/store_status_view_model.dart';

class DeliveryAndPaymentUI extends StatelessWidget {
  // ط­ط§ظ„ط© ط¹ط§ظ…ط©
  final bool loading;
  final bool depositRecalculating;
  final List<CartDiscount> discounts;
  final bool addressReady;
  final bool showAddressBlock;

  // ط§ظ„ط³ظ„ط©
  final List<Cart> cartItems;
  final TextEditingController couponController;
  final bool couponInProgress;
  final String? couponError;
  final VoidCallback onApplyCoupon;
  final ValueChanged<CartDiscount> onRemoveCoupon;
  final VoidCallback? onDismissCouponMessage;
  final String requiredAmountDisplay;

  // ط§ظ„ط¹ظ†ظˆط§ظ†
  final Map<String, dynamic>? address;
  final VoidCallback onManageAddresses;

  // ط§ظ„ط¯ظپط¹
  final List<CheckoutBank> banks;
  final int? selectedBankIndex;
  final String? selectedPaymentMethod;
  final void Function(int index) onSelectBank;
  final bool walletCurrencyMatchesOrder;
  final String? walletCurrencyCode;
  final String? walletCurrencyLabel;
  final String? orderCurrencyCode;
  final String? orderCurrencyLabel;
  final WalletSummary? walletSummary;
  final bool walletAvailable;
  final bool walletSelected;
  final bool walletEnabled;
  final VoidCallback? onSelectWallet;
  final double requiredAmount;
  final String paymentTimingLabel;
  final String? paymentTimingNote;
  final Map<String, dynamic>? shippingPayment;
  final bool freeShippingApplied;
  final double? shippingAmount;
  final String? shippingCurrency;
  final String? departmentNotice;

  /// ظ†طµ ط³ظٹط§ط³ط© ط§ظ„ط§ط³طھط±ط¬ط§ط¹ ط§ظ„ظ…ط±ط³ظ„ط© ظ…ظ† ط§ظ„ط´ط§ط´ط© ط§ظ„ط±ط¦ظٹط³ظٹط©.
  final String? returnPolicyText;

  /// ط¨ظٹط§ظ†ط§طھ ط§ظ„ظˆط¯ظٹط¹ط© ط§ظ„ظ…ظ†ط³ظ‘ظ‚ط© ظ„ظ„ط¹ط±ط¶ ط¶ظ…ظ† طھط¨ظˆظٹط¨ ط§ظ„ط³ظٹط§ط³ط§طھ.
  final Map<String, dynamic>? depositInfo;

  /// ط§ط³طھط¯ط¹ط§ط، ظٹط­ط¯ظ‘ط« ط­ط§ظ„ط© طھظپط¹ظٹظ„ ط§ظ„ط¯ظپط¹ط© ط§ظ„ظ…ظ‚ط¯ظ…ط© ط¹ظ†ط¯ طھظˆظپط± ط®ظٹط§ط± ط§ظ„طھط¨ط¯ظٹظ„.
  final ValueChanged<bool>? onToggleDeposit;

  final bool allowPayNow;
  final bool allowPayOnDelivery;
  final double? codFeeAmount;
  final String? codFeeDisplay;
  final bool payOnDeliverySelected;

  // ط§ظ„طھظˆطµظٹظ„
  final CheckoutDeliveryInfo? deliveryInfo;
  final String? deliveryPrice;

  // ط§ظ„ط´ط±ظٹط· ط§ظ„ط³ظپظ„ظٹ
  final bool canProceed;
  final bool submitting;
  final Future<void> Function(ManualTransferSubmissionData? manualTransfer)
      onConfirm;
  final String? checkoutErrorMessage;
  final bool checkoutErrorIsAddressIssue;
  final bool checkoutErrorCanRetry;
  final Future<void> Function()? onRetryCheckout;
  final List<dynamic>? deliveryPaymentOptions;
  final String? deliveryPaymentTiming;
  final ValueChanged<String>? onSelectDeliveryPaymentTiming;
  final Map<String, dynamic>? store;

  const DeliveryAndPaymentUI({
    super.key,
    required this.loading,
    this.depositRecalculating = false,
    required this.cartItems,
    required this.addressReady,
    required this.showAddressBlock,
    required this.requiredAmountDisplay,
    required this.couponController,
    required this.couponInProgress,
    required this.couponError,
    required this.onApplyCoupon,
    required this.onRemoveCoupon,
    this.onDismissCouponMessage,
    required this.walletCurrencyMatchesOrder,
    required this.walletCurrencyCode,
    required this.walletCurrencyLabel,
    required this.orderCurrencyCode,
    required this.orderCurrencyLabel,
    required this.discounts,
    required this.paymentTimingLabel,
    required this.shippingPayment,
    required this.freeShippingApplied,
    required this.shippingAmount,
    required this.shippingCurrency,
    required this.departmentNotice,
    this.returnPolicyText,
    this.depositInfo,
    this.onToggleDeposit,
    required this.allowPayNow,
    required this.allowPayOnDelivery,
    required this.codFeeAmount,
    required this.codFeeDisplay,
    required this.payOnDeliverySelected,
    this.paymentTimingNote,
    required this.address,
    required this.onManageAddresses,
    required this.walletSummary,
    required this.walletAvailable,
    required this.walletSelected,
    required this.walletEnabled,
    required this.onSelectWallet,
    required this.requiredAmount,
    required this.banks,
    required this.selectedBankIndex,
    required this.selectedPaymentMethod,
    required this.onSelectBank,
    required this.deliveryInfo,
    required this.deliveryPrice,
    required this.submitting,
    required this.canProceed,
    required this.onConfirm,
    this.deliveryPaymentOptions,
    this.deliveryPaymentTiming,
    this.onSelectDeliveryPaymentTiming,
    this.checkoutErrorMessage,
    this.checkoutErrorIsAddressIssue = false,
    this.checkoutErrorCanRetry = false,
    this.onRetryCheckout,
    this.store,
  });

  @override
  Widget build(BuildContext context) {
    final List<DeliveryPaymentTimingOption> timingOptions =
        normalizeDeliveryPaymentTimingOptions(deliveryPaymentOptions);
    final DeliveryPaymentTimingOption? selectedTimingOption =
        findDeliveryPaymentTimingOption(
      timingOptions,
      deliveryPaymentTiming,
    );

    final String resolvedPaymentTimingLabel =
        selectedTimingOption?.label ?? paymentTimingLabel;
    final String? resolvedPaymentTimingNote =
        (selectedTimingOption?.description?.trim().isNotEmpty ?? false)
            ? selectedTimingOption!.description
            : paymentTimingNote;

    final String resolvedDeliveryFee = freeShippingApplied
        ? 'ظ…ط¬ط§ظ†ظ‹ط§'
        : _resolveDeliveryFee(deliveryPrice);

    final bool showCheckoutError =
        checkoutErrorMessage != null && checkoutErrorMessage!.trim().isNotEmpty;
    final bool depositLoading = loading || depositRecalculating;
    final bool hasReturnDepositTab = _hasReturnDepositToShow();
    final StoreStatusViewModel storeStatus =
        StoreStatusViewModel.fromMap(store);
    final String resolvedStoreName =
        (storeStatus.name?.trim().isNotEmpty ?? false)
            ? storeStatus.name!.trim()
            : 'ط§ظ„ظ…طھط¬ط±';
    final Map<String, dynamic>? assurance =
        store?['assurance'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(store!['assurance'])
            : null;
    final bool showAssuranceBanner = assurance?['active'] == true;
    final String assuranceMessage = assurance?['message'] ??
        'ظ‡ط°ط§ ط§ظ„ط·ظ„ط¨ ظٹط®ط¶ط¹ ظ„ط¶ظ…ط§ظ† طھط§ط¬ط± ظ…ظˆط«ظ‘ظژظ‚طŒ ظˆط³ظٹطھظ… ط­ظ…ط§ظٹط© ط§ظ„ظ…ط¨ظ„ط؛ ط£ظˆ طھط¹ظˆظٹط¶ظƒ ط¹ظ†ط¯ ط­ط¯ظˆط« ظ…ط´ظƒظ„ط© ط¨ط§ظ„ط¯ظپط¹.';
    final MoneyFormatter totalFormatter = MoneyFormatter.fromCartCurrency(
      currency: orderCurrencyLabel,
      currencyCode: orderCurrencyCode,
      fallbackLabel: orderCurrencyLabel ?? orderCurrencyCode,
    );

    return Scaffold(
      bottomNavigationBar: addressReady
          ? _buildBottomCheckoutBar(
              context,
              requiredAmountDisplay,
              canProceed,
              submitting,
              totalFormatter,
              storeStatus,
              resolvedStoreName,
              depositLoading: depositLoading,
            )
          : null,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF0F2F4),
      appBar: UiUtils.buildAppBar(
        context,
        title: 'ط¨ظٹط§ظ†ط§طھ ط§ظ„طھظˆطµظٹظ„ ظˆط§ظ„ط¯ظپط¹',
        bottomHeight: 20,
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (storeStatus.hasData && storeStatus.isOpenNow) ...[
                StoreStatusCard(
                  store: storeStatus,
                  moneyFormatter: totalFormatter,
                ),
                const SizedBox(height: 11),
              ],
              if (showAssuranceBanner) ...[
                _TradeAssuranceBanner(message: assuranceMessage),
                const SizedBox(height: 11),
              ],
              if (showAddressBlock)
                CartDeliveryAddressTab(
                  loading: loading,
                  address: address,
                  onManageAddresses: onManageAddresses,
                  initiallyExpanded: true,
                ),
              if (showCheckoutError) ...[
                const SizedBox(height: 11),
                _CheckoutErrorBanner(
                  message: checkoutErrorMessage!,
                  isAddressIssue: checkoutErrorIsAddressIssue,
                  showRetry: checkoutErrorCanRetry && onRetryCheckout != null,
                  onRetry: onRetryCheckout,
                ),
                const SizedBox(height: 11),
              ],
              if (addressReady) ...[
                if (!showCheckoutError) const SizedBox(height: 11),
                CartOrderSummaryTab(
                  loading: loading,
                  cartItems: cartItems,
                  deliveryInfo: deliveryInfo,
                  deliveryFeeLabel: resolvedDeliveryFee,
                  freeShippingApplied: freeShippingApplied,
                  shippingAmount: shippingAmount,
                  shippingCurrency: shippingCurrency,
                  discounts: discounts,
                  onRemoveCoupon: onRemoveCoupon,
                  couponInProgress: couponInProgress,
                  initiallyExpanded: true,
                ),
                const SizedBox(height: 11),
                if (hasReturnDepositTab) ...[
                  CartReturnAndDepositTab(
                    loading: depositLoading,
                    returnPolicyText: returnPolicyText,
                    depositInfo: depositInfo,
                    onToggleDeposit: onToggleDeposit,
                    initiallyExpanded: false,
                    storageKey:
                        const PageStorageKey<String>('cart_return_deposit_tab'),
                  ),
                  const SizedBox(height: 11),
                ],
                CartPaymentMethodsTab(
                  loading: loading,
                  addressReady: addressReady,
                  banks: banks,
                  selectedBankIndex: selectedBankIndex,
                  onSelectBank: onSelectBank,
                  walletSummary: walletSummary,
                  walletAvailable: walletAvailable,
                  walletSelected: walletSelected,
                  walletEnabled: walletEnabled,
                  walletCurrencyMatchesOrder: walletCurrencyMatchesOrder,
                  walletCurrencyCode: walletCurrencyCode,
                  walletCurrencyLabel: walletCurrencyLabel,
                  orderCurrencyCode: orderCurrencyCode,
                  orderCurrencyLabel: orderCurrencyLabel,
                  onSelectWallet: onSelectWallet,
                  requiredAmount: requiredAmount,
                  allowPayNow: allowPayNow,
                  allowPayOnDelivery: allowPayOnDelivery,
                  payOnDeliverySelected: payOnDeliverySelected,
                  deliveryPaymentTimingOptions: timingOptions,
                  selectedDeliveryPaymentTiming: deliveryPaymentTiming,
                  onSelectDeliveryPaymentTiming: onSelectDeliveryPaymentTiming,
                  initiallyExpanded: true,
                  storeStatus: storeStatus,
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCheckoutBar(
    BuildContext context,
    String totalAmountDisplay,
    bool isButtonEnabled,
    bool submitting,
    MoneyFormatter totalFormatter,
    StoreStatusViewModel storeStatus,
    String storeName, {
    bool depositLoading = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    String? restrictionMessage;
    if (payOnDeliverySelected && !allowPayOnDelivery) {
      restrictionMessage =
          'ًںڑ« ط®ظٹط§ط± ط§ظ„ط¯ظپط¹ ط¹ظ†ط¯ ط§ظ„ط§ط³طھظ„ط§ظ… ط؛ظٹط± ظ…طھط§ط­ ظ„ظ‡ط°ظ‡ ط§ظ„ط·ظ„ط¨ظٹط©.';
    } else if (!payOnDeliverySelected && !allowPayNow) {
      restrictionMessage =
          'ًںڑ« ط®ظٹط§ط± ط§ظ„ط¯ظپط¹ ط§ظ„ط¢ظ† ط؛ظٹط± ظ…طھط§ط­ ظ„ظ‡ط°ظ‡ ط§ظ„ط·ظ„ط¨ظٹط©.';
    }
    final bool buttonEnabled = isButtonEnabled;

    final String? paymentNotice = _resolvePaymentNotice();
    final bool hasCouponError =
        couponError != null && couponError!.trim().isNotEmpty;

    final Iterable<CartDiscount> appliedDiscounts = discounts.where(
      (CartDiscount discount) => discount.isApplied,
    );

    final double totalDiscountAmount = appliedDiscounts.fold<double>(
      0,
      (double sum, CartDiscount discount) {
        if (!discount.isApplied) {
          return sum;
        }
        final num? amount = discount.amount;
        if (amount == null) {
          return sum;
        }
        return sum + amount.toDouble();
      },
    );

    const double discountEpsilon = 0.009;
    final double discountedTotal = requiredAmount;
    final double originalTotal =
        math.max(0, discountedTotal + totalDiscountAmount);
    final bool showOriginalTotal = totalDiscountAmount > discountEpsilon &&
        (originalTotal - discountedTotal) > discountEpsilon;

    final String discountedTotalDisplay =
        totalFormatter.format(discountedTotal);
    final String resolvedDiscountedDisplay =
        discountedTotalDisplay.trim().isNotEmpty
            ? discountedTotalDisplay
            : totalAmountDisplay;
    final String? originalTotalDisplay =
        showOriginalTotal ? totalFormatter.format(originalTotal) : null;

    Widget buildCouponErrorBanner(String message) {
      final Color accent = Colors.redAccent;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            if (onDismissCouponMessage != null)
              IconButton(
                onPressed: onDismissCouponMessage,
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, color: accent),
              ),
          ],
        ),
      );
    }

    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? Colors.white24 : const Color(0xFFD4DAE2),
      ),
    );
    final Color inputFillColor =
        isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF4F6FA);

    final TextStyle totalLabelStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
    );
    final TextStyle totalValueStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 18,
      color: Theme.of(context).colorScheme.primary,
    );
    final TextStyle originalTotalStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: Colors.redAccent.shade200,
      decoration: TextDecoration.lineThrough,
    );
    final double viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final double bottomKeyboardPadding = viewInsets > 0 ? 20 : 24;
    final bool storeClosed = storeStatus.hasData &&
        !storeStatus.isOpenNow &&
        !storeStatus.browseOnly;

    Future<void> showStoreClosedSheet() async {
      const String fallbackStore = '\u0627\u0644\u0645\u062a\u062c\u0631';
      final String storeName = (storeStatus.name?.trim().isNotEmpty ?? false)
          ? storeStatus.name!.trim()
          : fallbackStore;
      final String? nextOpen = storeStatus.formatNextOpenLabel(locale: 'ar');
      final String sixHoursHint = DateFormat('EEEE d MMM, h:mm a', 'ar')
          .format(DateTime.now().add(const Duration(hours: 6)));

      Widget buildIconLine({
        required IconData icon,
        required Color color,
        required String text,
        TextStyle? style,
      }) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: style)),
          ],
        );
      }

      await showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (BuildContext sheetContext) {
          final Color accent = Colors.orange;
          final TextStyle? titleStyle = Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800);
          final TextStyle? bodyStyle = Theme.of(context).textTheme.bodyMedium;

          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.lock_clock, color: accent, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '\u0627\u0644\u0645\u062a\u062c\u0631  \u0645\u063a\u0644\u0642 \u0627\u0644\u0622\u0646',
                        style: titleStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildIconLine(
                        icon: Icons.error_outline,
                        color: accent,
                        text:
                            '\u0644\u0627 \u064a\u0645\u0643\u0646 \u0625\u062a\u0645\u0627\u0645 \u0627\u0644\u062f\u0641\u0639 \u0623\u0648 \u0627\u0644\u062a\u0648\u0635\u064a\u0644 \u0623\u062b\u0646\u0627\u0621 \u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u0645\u062a\u062c\u0631.',
                        style: bodyStyle,
                      ),
                      if (nextOpen != null && nextOpen.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        buildIconLine(
                          icon: Icons.schedule_outlined,
                          color: Colors.teal,
                          text:
                              '\u0627\u0644\u0641\u062a\u062d \u0627\u0644\u0642\u0627\u062f\u0645: ',
                          style: bodyStyle,
                        ),
                      ],
                      const SizedBox(height: 10),
                      buildIconLine(
                        icon: Icons.lightbulb_outline,
                        color: Colors.blueGrey,
                        text:
                            '\u062c\u0631\u0651\u0628 \u0627\u0644\u0631\u062c\u0648\u0639 \u0628\u0639\u062f 6 \u0633\u0627\u0639\u0627\u062a \u0645\u0646 \u0627\u0644\u0622\u0646 ().',
                        style: bodyStyle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '\u0644\u0627 \u064a\u0645\u0643\u0646\u0646\u0627 \u0627\u0633\u062a\u0644\u0627\u0645 \u0627\u0644\u0637\u0644\u0628 \u0648\u0645\u0639\u0627\u0644\u062c\u062a\u0647 \u0623\u062b\u0646\u0627\u0621 \u0627\u0644\u0625\u063a\u0644\u0627\u0642. \u0633\u0646\u0643\u0648\u0646 \u062c\u0627\u0647\u0632\u064a\u0646 \u0644\u062e\u062f\u0645\u062a\u0643 \u0628\u0645\u062c\u0631\u062f \u0641\u062a\u062d \u0627\u0644\u0645\u062a\u062c\u0631.',
                  style: bodyStyle?.copyWith(color: Colors.blueGrey.shade700),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '\u062d\u0633\u0646\u0627\u064b \u0641\u0647\u0645\u062a',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, 14, 16, bottomKeyboardPadding),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(
                  isDark ? 0.7 : 0.95,
                ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (restrictionMessage != null) ...[
                  Text(
                    restrictionMessage!,
                    style: TextStyle(
                      color: Colors.redAccent.shade200,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                if (paymentNotice != null) ...[
                  Text(
                    paymentNotice,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.blueGrey.shade200
                          : Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                if (departmentNotice != null &&
                    departmentNotice!.trim().isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.orange.shade200
                            : const Color(0xFFFFEEBA),
                      ),
                    ),
                    child: Text(
                      departmentNotice!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.orange.shade100
                            : const Color(0xFF856404),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (hasCouponError) ...[
                  buildCouponErrorBanner(couponError!.trim()),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE3E7ED),
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: TextField(
                                controller: couponController,
                                enabled: !couponInProgress && !submitting,
                                autocorrect: false,
                                enableSuggestions: false,
                                textCapitalization:
                                    TextCapitalization.characters,
                                textInputAction: TextInputAction.done,
                                scrollPadding: EdgeInsets.only(
                                  bottom: viewInsets + 120,
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  hintText: 'ط£ط¯ط®ظ„ ط±ظ…ط² ط§ظ„ظƒظˆط¨ظˆظ†',
                                  filled: true,
                                  fillColor: inputFillColor,
                                  border: inputBorder,
                                  enabledBorder: inputBorder,
                                  focusedBorder: inputBorder.copyWith(
                                    borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 1.2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 0,
                                  ),
                                ),
                                onSubmitted: (_) => onApplyCoupon(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: (!couponInProgress && !submitting)
                                  ? onApplyCoupon
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: couponInProgress
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text(
                                      'طھط·ط¨ظٹظ‚ ط§ظ„ظƒظˆط¨ظˆظ†',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFE7ECF3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: depositLoading
                      ? Shimmer.fromColors(
                          baseColor: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          highlightColor: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade100,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    height: 14,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 16,
                                    width: 110,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text('ط§ظ„ظ…ط¨ظ„ط؛ ط§ظ„ط¥ط¬ظ…ط§ظ„ظٹ',
                                  style: totalLabelStyle),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (originalTotalDisplay != null) ...[
                                  Text(
                                    originalTotalDisplay,
                                    style: originalTotalStyle,
                                    textAlign: TextAlign.right,
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(
                                  resolvedDiscountedDisplay,
                                  style: totalValueStyle,
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                UiUtils.buildButton(
                  context,
                  onPressed: () async {
                    if (!buttonEnabled || submitting) return;

                    final String pm =
                        (selectedPaymentMethod ?? '').trim().toLowerCase();

                    if (storeClosed) {
                      await showStoreClosedSheet();
                      return;
                    }

                    if (pm == 'wallet') {
                      await onConfirm(null);
                      return;
                    }
                    final bool isBank = pm.contains('bank');
                    final bool isCode = pm.contains('code');

                    final int? idx = isBank
                        ? (selectedBankIndex ?? (banks.length == 1 ? 0 : null))
                        : selectedBankIndex;

                    final CheckoutBank? selectedBank =
                        (idx != null && idx >= 0 && idx < banks.length)
                            ? banks[idx]
                            : null;

                    final String bankMethod =
                        (selectedBank?.paymentMethod ?? '')
                            .trim()
                            .toLowerCase();

                    if (requiresPurchaseCodeGateway(pm) ||
                        requiresPurchaseCodeGateway(bankMethod)) {
                      if (selectedBank == null && banks.length > 1) {
                        HelperUtils.showSnackBarMessage(
                            context, 'ط§ط®طھط± ط¨ظ†ظƒظ‹ط§ ط£ظˆظ„ظ‹ط§');

                        return;
                      }
                      PaymentMethodsSection.showPurchaseCodeDialog(
                        context,
                        () => onConfirm(null),
                      );

                      return;
                    }
                    if (selectedBank != null || isBank) {
                      if (selectedBank == null) {
                        HelperUtils.showSnackBarMessage(
                            context, 'ط§ط®طھط± ط¨ظ†ظƒظ‹ط§ ط£ظˆظ„ظ‹ط§');

                        return;
                      }

                      final bool isManualBank =
                          isManualBankGateway(bankMethod) ||
                              isManualBankGateway(pm);

                      if (isManualBank) {
                        final String accountNum =
                            (selectedBank.accountNumber?.trim().isNotEmpty ==
                                    true)
                                ? selectedBank.accountNumber!.trim()
                                : (selectedBank.iban ?? '');

                        PaymentMethodsSection.showBankTransferDialog(
                          context,
                          bank: selectedBank,
                          onConfirm: (data) async {
                            await onConfirm(data);
                          },
                        );
                        return;
                      }

                      await onConfirm(null);
                      return;
                    }

                    if (isCode) {
                      PaymentMethodsSection.showPurchaseCodeDialog(
                        context,
                        () => onConfirm(null),
                      );
                      return;
                    }
                    HelperUtils.showSnackBarMessage(
                        context, 'ط­ط¯ط¯ ط·ط±ظٹظ‚ط© ط§ظ„ط¯ظپط¹');
                  },
                  buttonTitle: 'ط¥ظƒظ…ط§ظ„ ط§ظ„ط¯ظپط¹',
                  radius: 12,
                  height: 50,
                  showElevation: false,
                  isInProgress: submitting,
                  disabled: !buttonEnabled,
                  onTapDisabledButton: () {
                    final String feedbackMessage = restrictionMessage ??
                        'ظٹط±ط¬ظ‰ ط¥ظƒظ…ط§ظ„ ط¨ظٹط§ظ†ط§طھ ط§ظ„طھظˆطµظٹظ„ ظˆط§ظ„ط¯ظپط¹ ط£ظˆظ„ظ‹ط§.';
                    HelperUtils.showSnackBarMessage(context, feedbackMessage);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveDeliveryFee(String? deliveryFee) {
    final String? trimmed = deliveryFee?.trim();
    if (trimmed != null && trimmed.isNotEmpty && trimmed != 'â€”') {
      return trimmed;
    }
    if (shippingAmount != null) {
      if (shippingAmount == 0) {
        return '0 ${_currencyLabel}';
      }
      return _formatAmount(shippingAmount!);
    }
    return 'â€”';
  }

  String _formatAmount(double amount) {
    final MoneyFormatter formatter = MoneyFormatter.fromCartCurrency(
      currency: shippingCurrency ?? orderCurrencyLabel,
      currencyCode: orderCurrencyCode,
      fallbackLabel: orderCurrencyLabel ?? orderCurrencyCode,
    );
    return formatter.format(amount);
  }

  String get _currencyLabel {
    final String? fromShipping = shippingCurrency?.trim();
    if (fromShipping != null && fromShipping.isNotEmpty) {
      return fromShipping;
    }
    final String? fromDelivery = deliveryInfo?.currency?.trim();
    if (fromDelivery != null && fromDelivery.isNotEmpty) {
      return fromDelivery;
    }
    final String? orderLabel = orderCurrencyLabel?.trim();
    if (orderLabel != null && orderLabel.isNotEmpty) {
      return orderLabel;
    }
    final String? orderCode = orderCurrencyCode?.trim();
    if (orderCode != null && orderCode.isNotEmpty) {
      return orderCode;
    }
    return '';
  }

  String? _resolvePaymentNotice() {
    final dynamic rawNotice = shippingPayment?['notice'] ??
        shippingPayment?['message'] ??
        shippingPayment?['note'];
    if (rawNotice is String) {
      final String trimmed = rawNotice.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  bool _hasReturnDepositToShow() {
    bool hasDeposit = false;
    final Map<String, dynamic>? deposit = depositInfo;
    if (deposit != null) {
      final dynamic amount =
          deposit['amountDueNow'] ?? deposit['effectiveAmountDueDisplay'];
      final dynamic total =
          deposit['totalAmount'] ?? deposit['effectiveTotalDisplay'];

      final dynamic percent = deposit['percent'];
      final dynamic goodsValue = deposit['goodsValue'];
      final dynamic remaining =
          deposit['remainingBalance'] ?? deposit['effectiveRemainingDisplay'];
      final dynamic message = deposit['message'];
      final dynamic includesShipping = deposit['includesShipping'];
      final bool hasToggle =
          deposit['toggleAllowed'] == true || deposit['toggleRequired'] == true;

      hasDeposit = _isNonEmptyString(amount) ||
          _isNonEmptyString(total) ||
          _isNonEmptyString(percent) ||
          _isNonEmptyString(goodsValue) ||
          _isNonEmptyString(remaining) ||
          _isNonEmptyString(message) ||
          includesShipping != null ||
          hasToggle;
    }

    return hasDeposit || _isNonEmptyString(returnPolicyText);
  }

  bool _isNonEmptyString(dynamic value) {
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    return false;
  }
}

class _TradeAssuranceBanner extends StatelessWidget {
  const _TradeAssuranceBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.color.successColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutErrorBanner extends StatelessWidget {
  const _CheckoutErrorBanner({
    required this.message,
    this.isAddressIssue = false,
    this.showRetry = false,
    this.onRetry,
  });

  final String message;
  final bool isAddressIssue;
  final bool showRetry;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark
        ? Colors.red.shade900.withOpacity(0.25)
        : const Color(0xFFFFF3F3);
    final Color borderColor =
        isDark ? Colors.red.shade400 : Colors.red.shade200;
    final Color textColor = isDark ? Colors.red.shade100 : Colors.red.shade900;
    final IconData icon =
        isAddressIssue ? Icons.location_off_outlined : Icons.error_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor),
              const SizedBox(width: 6),
              Text(
                'طھظ†ط¨ظٹظ‡',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: textColor,
              height: 1.4,
            ),
            textAlign: TextAlign.start,
          ),
          if (showRetry)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onRetry == null
                    ? null
                    : () {
                        onRetry!();
                      },
                icon: Icon(Icons.refresh, color: textColor),
                label: Text(
                  'ط¥ط¹ط§ط¯ط© ط§ظ„ظ…ط­ط§ظˆظ„ط©',
                  style: TextStyle(color: textColor),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

bool requiresPurchaseCodeGateway(String? method) {
  final String normalized = (method ?? '').trim().toLowerCase();
  return normalized == 'east_yemen_bank';
}

bool isManualBankGateway(String? method) {
  final String normalized = (method ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }

  if (normalized.startsWith('manual_')) {
    return true;
  }

  const Set<String> manualAliases = {
    'manualbank',
    'manualpayment',
    'manualtransfer',
    'manualdeposit',
  };

  final String collapsed = normalized.replaceAll('_', '');
  return manualAliases.contains(normalized) ||
      manualAliases.contains(collapsed);
}
