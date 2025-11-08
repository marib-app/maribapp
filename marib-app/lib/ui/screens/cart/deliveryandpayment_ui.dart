// الواجهة فقط
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
import 'package:marib/ui/widgets/store_status_card.dart';
import 'package:marib/utils/store_status_view_model.dart';

class DeliveryAndPaymentUI extends StatelessWidget {
  // حالة عامة
  final bool loading;
  final List<CartDiscount> discounts;
  final bool addressReady;
  final bool showAddressBlock;

  // السلة
  final List<Cart> cartItems;
  final TextEditingController couponController;
  final bool couponInProgress;
  final String? couponError;
  final VoidCallback onApplyCoupon;
  final ValueChanged<CartDiscount> onRemoveCoupon;
  final VoidCallback? onDismissCouponMessage;
  final String requiredAmountDisplay;

  // العنوان
  final Map<String, dynamic>? address;
  final VoidCallback onManageAddresses;

  // الدفع
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

  /// نص سياسة الاسترجاع المرسلة من الشاشة الرئيسية.
  final String? returnPolicyText;

  /// بيانات الوديعة المنسّقة للعرض ضمن تبويب السياسات.
  final Map<String, dynamic>? depositInfo;

  /// استدعاء يحدّث حالة تفعيل الدفعة المقدمة عند توفر خيار التبديل.
  final ValueChanged<bool>? onToggleDeposit;

  final bool allowPayNow;
  final bool allowPayOnDelivery;
  final double? codFeeAmount;
  final String? codFeeDisplay;
  final bool payOnDeliverySelected;

  // التوصيل
  final CheckoutDeliveryInfo? deliveryInfo;
  final String? deliveryPrice;

  // الشريط السفلي
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

    final String resolvedDeliveryFee =
        freeShippingApplied ? 'مجانًا' : _resolveDeliveryFee(deliveryPrice);

    final bool showCheckoutError =
        checkoutErrorMessage != null && checkoutErrorMessage!.trim().isNotEmpty;
    final bool hasReturnDepositTab = _hasReturnDepositToShow();
    final StoreStatusViewModel storeStatus =
        StoreStatusViewModel.fromMap(store);
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
            )
          : null,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF0F2F4),
      appBar: UiUtils.buildAppBar(
        context,
        title: 'بيانات التوصيل والدفع',
        bottomHeight: 20,
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (storeStatus.hasData) ...[
                StoreStatusCard(
                  store: storeStatus,
                  moneyFormatter: totalFormatter,
                ),
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
                    loading: loading,
                    returnPolicyText: returnPolicyText,
                    depositInfo: depositInfo,
                    onToggleDeposit: onToggleDeposit,
                    initiallyExpanded: true,
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
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    String? restrictionMessage;
    if (payOnDeliverySelected && !allowPayOnDelivery) {
      restrictionMessage = '🚫 خيار الدفع عند الاستلام غير متاح لهذه الطلبية.';
    } else if (!payOnDeliverySelected && !allowPayNow) {
      restrictionMessage = '🚫 خيار الدفع الآن غير متاح لهذه الطلبية.';
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
                                  hintText: 'أدخل رمز الكوبون',
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
                                      'تطبيق الكوبون',
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('المبلغ الإجمالي', style: totalLabelStyle),
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
                            context, 'اختر بنكًا أولًا');

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
                            context, 'اختر بنكًا أولًا');

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
                    HelperUtils.showSnackBarMessage(context, 'حدد طريقة الدفع');
                  },
                  buttonTitle: 'إكمال الدفع',
                  radius: 12,
                  height: 50,
                  showElevation: false,
                  isInProgress: submitting,
                  disabled: !buttonEnabled,
                  onTapDisabledButton: () {
                    final String feedbackMessage = restrictionMessage ??
                        'يرجى إكمال بيانات التوصيل والدفع أولًا.';
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
    if (trimmed != null && trimmed.isNotEmpty && trimmed != '—') {
      return trimmed;
    }
    if (shippingAmount != null) {
      if (shippingAmount == 0) {
        return '0 ${_currencyLabel}';
      }
      return _formatAmount(shippingAmount!);
    }
    return '—';
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
                'تنبيه',
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
                  'إعادة المحاولة',
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
