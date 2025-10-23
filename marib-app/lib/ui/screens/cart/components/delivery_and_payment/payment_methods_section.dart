import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/data/model/cart/checkout_models.dart';

import 'shared_widgets.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/ui/screens/widgets/lazy_network_image.dart';
import 'package:marib/utils/money_formatter.dart';
import 'manual_transfer_submission.dart';

/// ويدجت يعرض طرق الدفع المتاحة ويتعامل مع الحوارات الخاصة بالحوالة أو الكود.
class PaymentMethodsSection extends StatelessWidget {
  final bool loading;
  final bool addressReady;

  final List<CheckoutBank> banks;
  final int? selectedBankIndex;
  final void Function(int index) onSelectBank;
  final WalletSummary? walletSummary;
  final bool walletAvailable;
  final bool walletSelected;
  final bool walletEnabled;
  final VoidCallback? onSelectWallet;
  final double requiredAmount;
  final bool allowPayNow;
  final bool allowPayOnDelivery;
  final bool payOnDeliverySelected;
  final bool walletCurrencyMatchesOrder;
  final String? walletCurrencyCode;
  final String? walletCurrencyLabel;
  final String? orderCurrencyCode;
  final String? orderCurrencyLabel;

  const PaymentMethodsSection({
    super.key,
    required this.loading,
    required this.addressReady,
    required this.walletCurrencyMatchesOrder,
    required this.walletCurrencyCode,
    required this.walletCurrencyLabel,
    required this.orderCurrencyCode,
    required this.orderCurrencyLabel,
    required this.banks,
    required this.selectedBankIndex,
    required this.onSelectBank,
    required this.walletSummary,
    required this.walletAvailable,
    required this.walletSelected,
    required this.walletEnabled,
    required this.onSelectWallet,
    required this.requiredAmount,
    required this.allowPayNow,
    required this.allowPayOnDelivery,
    required this.payOnDeliverySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return buildShimmerLine(context, width: double.infinity, height: 50);
    }

    if (!addressReady) {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'اختر عنوان التوصيل أولًا لعرض طرق الدفع المتاحة.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 8),
            Text(
              'بمجرد تحديد عنوان بصلاحية جغرافية، ستظهر خيارات الدفع والمحفظة هنا.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondaryColor = const Color(0xFFFF8000);
    final Color accentColor = const Color(0xFFE0E0E0);
    final Color lightBackground =
        isDark ? Colors.grey.shade800 : const Color(0xFFF9F9F9);
    final Color textColor = isDark ? Colors.white : const Color(0xFF222222);
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final Color borderColor = isDark ? Colors.grey.shade600 : accentColor;

    final List<Widget> paymentOptions = [];

    if (walletAvailable || walletSummary != null) {
      paymentOptions.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _buildWalletCard(
            context,
            isDark: isDark,
            textColor: textColor,
            backgroundColor: backgroundColor,
            lightBackground: lightBackground,
            borderColor: borderColor,
            secondaryColor: secondaryColor,
            allowPayNow: allowPayNow,
            payOnDeliverySelected: payOnDeliverySelected,
          ),
        ),
      );
    }

    for (var index = 0; index < banks.length; index++) {
      paymentOptions.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _buildBankCard(
            context,
            bank: banks[index],
            index: index,
            isSelected: selectedBankIndex == index,
            isDark: isDark,
            textColor: textColor,
            backgroundColor: backgroundColor,
            lightBackground: lightBackground,
            borderColor: borderColor,
            secondaryColor: secondaryColor,
            isEnabled: allowPayNow,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paymentOptions,
    );
  }

  Widget _buildWalletCard(
    BuildContext context, {
    required bool isDark,
    required Color textColor,
    required Color backgroundColor,
    required Color lightBackground,
    required Color borderColor,
    required Color secondaryColor,
    required bool allowPayNow,
    required bool payOnDeliverySelected,
  }) {
    final WalletSummary? summary = walletSummary;
    final double balance = summary?.balance ?? 0;
    String? sanitize(String? value) {
      if (value == null) {
        return null;
      }
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final String? summaryDisplay = sanitize(summary?.currency);
    final String? summaryCode = CurrencyUtils.normalizeCurrencyCode(
      summary?.currencyCode ?? summaryDisplay,
    );

    final String? resolvedWalletCode = CurrencyUtils.normalizeCurrencyCode(
      walletCurrencyCode ??
          summaryCode ??
          walletCurrencyLabel ??
          summaryDisplay,
    );

    final String? resolvedOrderCode = CurrencyUtils.normalizeCurrencyCode(
      orderCurrencyCode ?? orderCurrencyLabel,
    );

    final String? walletDisplay = CurrencyUtils.displayToken(
      label: sanitize(walletCurrencyLabel) ?? summaryDisplay,
      fallback: sanitize(orderCurrencyLabel) ??
          resolvedWalletCode ??
          resolvedOrderCode,
      code: resolvedWalletCode,
    );

    final String? orderDisplay = CurrencyUtils.displayToken(
      label: sanitize(orderCurrencyLabel),
      fallback: walletDisplay ?? resolvedOrderCode ?? resolvedWalletCode,
      code: resolvedOrderCode,
    );

    final MoneyFormatter orderFormatter = MoneyFormatter.fromCartCurrency(
      currency: orderDisplay ?? walletDisplay,
      currencyCode: resolvedOrderCode ?? resolvedWalletCode,
      fallbackLabel: orderDisplay ??
          walletDisplay ??
          resolvedOrderCode ??
          resolvedWalletCode,
    );
    final MoneyFormatter balanceFormatter = MoneyFormatter.fromCartCurrency(
      currency: walletDisplay ?? orderDisplay,
      currencyCode: resolvedWalletCode ?? resolvedOrderCode,
      fallbackLabel: orderDisplay ??
          walletDisplay ??
          resolvedWalletCode ??
          resolvedOrderCode,
    );
    final String balanceText =
        summary == null ? '—' : balanceFormatter.format(balance);

    final String walletMessageLabel = walletDisplay ??
        resolvedWalletCode ??
        orderDisplay ??
        resolvedOrderCode ??
        '—';
    final String orderMessageLabel = orderDisplay ??
        resolvedOrderCode ??
        walletDisplay ??
        resolvedWalletCode ??
        '—';
    String statusText;
    Color statusColor;

    final bool payOnDeliveryAllowed = allowPayOnDelivery;
    final bool canInteract = walletAvailable &&
        walletEnabled &&
        summary != null &&
        addressReady &&
        allowPayNow;
    if (!walletAvailable) {
      statusText = 'المحفظة غير متاحة حاليًا';
      statusColor = Colors.orange;
    } else if (summary == null) {
      statusText = 'تعذر تحميل رصيد المحفظة';
      statusColor = Colors.orange;
    } else if (!walletCurrencyMatchesOrder) {
      statusText =
          'لا يمكن استخدام المحفظة بعملة $walletMessageLabel لطلب عملته $orderMessageLabel.';
      statusColor = Colors.orange;
    } else if (!walletEnabled) {
      final String requiredAmountText = orderFormatter.format(requiredAmount);
      statusText = 'الرصيد غير كافٍ لإجمالي $requiredAmountText';

      statusColor = Colors.redAccent;
    } else {
      statusText = 'الرصيد متاح للدفع';
      statusColor = Colors.green;
    }

    String? restrictionText;
    if (!payOnDeliveryAllowed) {
      restrictionText = payOnDeliverySelected
          ? '🚫 تم تعطيل الدفع عند الاستلام لهذه الطلبية. يرجى اختيار طريقة أخرى.'
          : '🚫 الدفع عند الاستلام غير متاح لهذه الطلبية.';
    }

    final Color cardBorderColor = walletSelected ? secondaryColor : borderColor;

    final Color cardBackgroundColor =
        walletSelected ? lightBackground : backgroundColor;

    return Opacity(
      opacity: canInteract ? 1 : 0.65,
      child: Material(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canInteract ? onSelectWallet : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: cardBorderColor,
                width: 1.4,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDark
                        ? Colors.deepPurple.shade400
                        : Colors.deepPurple.shade100,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: isDark ? Colors.white : Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المحفظة الإلكترونية',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'الرصيد المتاح: $balanceText',
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (restrictionText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          restrictionText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent.shade200,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (walletSelected)
                  Icon(Icons.check_circle, color: secondaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankCard(
    BuildContext context, {
    required CheckoutBank bank,
    required int index,
    required bool isSelected,
    required bool isDark,
    required Color textColor,
    required Color backgroundColor,
    required Color lightBackground,
    required Color borderColor,
    required Color secondaryColor,
    required bool isEnabled,
  }) {
    final String accountDisplay = bank.accountNumber?.trim().isNotEmpty == true
        ? bank.accountNumber!.trim()
        : (bank.iban?.trim() ?? '');
    final String accountName = bank.accountName?.trim() ?? '';
    final String notes = bank.notes?.trim() ?? '';
    final Color cardBackgroundColor =
        isSelected ? lightBackground : backgroundColor;
    final Color cardBorderColor = isSelected ? secondaryColor : borderColor;
    final Color infoBackgroundColor =
        isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF5F5F5);
    final Color infoBorderColor =
        isDark ? Colors.white.withOpacity(0.14) : const Color(0xFFE0E0E0);
    final Color iconColor = isDark ? Colors.white70 : const Color(0xFF616161);

    final String? restrictionText =
        isEnabled ? null : '🚫 الدفع الآن غير متاح لهذه الطلبية.';

    return Opacity(
      opacity: isEnabled ? 1 : 0.6,
      child: Material(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isEnabled ? () => onSelectBank(index) : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: cardBorderColor,
                width: 1.4,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBankLogo(bank, isDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bank.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      if (accountName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          accountName,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                      if (accountDisplay.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: isEnabled
                              ? () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: accountDisplay),
                                  );
                                  HelperUtils.showSnackBarMessage(
                                    context,
                                    'تم نسخ رقم الحساب',
                                    messageDuration: 1,
                                  );
                                  onSelectBank(index);
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: infoBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: infoBorderColor),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    accountDisplay,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 18,
                                  color: iconColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notes,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                      if (restrictionText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          restrictionText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent.shade200,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? secondaryColor : borderColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankLogo(CheckoutBank bank, bool isDark) {
    const double size = 45;
    final BorderRadius radius = BorderRadius.circular(10);
    final String? rawLogo = bank.logoUrl?.trim();

    if (rawLogo != null && rawLogo.isNotEmpty) {
      if (rawLogo.startsWith('http')) {
        return ClipRRect(
          borderRadius: radius,
          child: LazyNetworkImage(
            imageUrl: rawLogo,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: _fallbackBankIcon(isDark),
            placeholder: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: radius,
              ),
            ),
          ),
        );
      }

      return ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          rawLogo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackBankIcon(isDark),
        ),
      );
    }

    return _fallbackBankIcon(isDark);
  }

  Widget _fallbackBankIcon(bool isDark) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade700 : const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.account_balance,
        color: isDark ? Colors.white : const Color(0xFF444444),
      ),
    );
  }

  static void showPurchaseCodeDialog(
    BuildContext context,
    Future<void> Function() onConfirm,
  ) {
    final TextEditingController codeController = TextEditingController();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        title: const Text('🧾 كود الشراء'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'يرجى إدخال كود الشراء المرسل من البنك لإتمام العملية.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'أدخل كود الشراء هنا',
                filled: true,
                fillColor:
                    isDark ? Colors.grey.shade800 : const Color(0xFFF3F3F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                '🔒 يتم مراجعة الكود من قبل النظام قبل إتمام الطلب.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8000),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (codeController.text.trim().isEmpty) {
                HelperUtils.showSnackBarMessage(
                  context,
                  'يرجى إدخال كود الشراء',
                );
                return;
              }
              Navigator.pop(context);
              await onConfirm();
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  static void showBankTransferDialog(
    BuildContext context, {
    required CheckoutBank bank,
    required Future<void> Function(ManualTransferSubmissionData data) onConfirm,
  }) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController transferCodeController =
        TextEditingController();
    final ValueNotifier<bool> isUploading = ValueNotifier(false);
    final ValueNotifier<File?> receiptImage = ValueNotifier(null);

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fieldColor =
        isDark ? Colors.grey.shade800 : const Color(0xFFF5F5F5);
    final Color mainColor = const Color(0xFFFF8000);

    final String bankName = bank.name.trim();
    final String accountName = bank.accountName?.trim() ?? '';
    final String accountNumber = bank.accountNumber?.trim() ?? '';
    final String iban = bank.iban?.trim() ?? '';

    Widget buildCopyTile(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                if (value.isEmpty) return;
                await Clipboard.setData(ClipboardData(text: value));
                HelperUtils.showSnackBarMessage(
                  context,
                  'تم نسخ $label',
                  messageDuration: 1,
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        title: const Text('💳 الدفع عن طريق حوالة مصرفية'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bankName.isNotEmpty) buildCopyTile('اسم البنك', bankName),
              if (accountName.isNotEmpty)
                buildCopyTile('اسم المستفيد', accountName),
              if (iban.isNotEmpty) buildCopyTile('رقم الآيبان', iban),
              if (accountNumber.isNotEmpty)
                buildCopyTile('رقم الحساب', accountNumber),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم *',
                  filled: true,
                  fillColor: fieldColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: transferCodeController,
                decoration: InputDecoration(
                  labelText: 'رقم الحوالة *',
                  filled: true,
                  fillColor: fieldColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: isUploading,
                builder: (context, uploading, _) {
                  return ValueListenableBuilder<File?>(
                    valueListenable: receiptImage,
                    builder: (context, file, __) {
                      return Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? picked = await picker.pickImage(
                                  source: ImageSource.gallery);
                              if (picked != null) {
                                isUploading.value = true;

                                receiptImage.value = File(picked.path);
                                isUploading.value = false;
                              }
                            },
                            child: const Text('📎 صورة الإشعار'),
                          ),
                          const SizedBox(width: 12),
                          if (uploading)
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (file != null)
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 20),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'تم إرفاق ${file.path.split(RegExp(r'[\\/]')).last}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.green),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Text('اختياري',
                                style: TextStyle(color: Colors.grey)),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isUploading,
            builder: (context, uploading, _) {
              final bool valid = nameController.text.trim().isNotEmpty &&
                  transferCodeController.text.trim().isNotEmpty;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (uploading || !valid) ? Colors.grey : mainColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (uploading || !valid)
                    ? null
                    : () async {
                        final data = ManualTransferSubmissionData(
                          senderName: nameController.text,
                          transferCode: transferCodeController.text,
                          receiptFile: receiptImage.value,
                        );
                        Navigator.pop(context);
                        await onConfirm(data);
                      },
                child: const Text('تقديم'),
              );
            },
          ),
        ],
      ),
    );
  }
}
