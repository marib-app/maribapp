import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/ui/screens/widgets/lazy_network_image.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/money_formatter.dart';
import 'package:marib/utils/store_status_view_model.dart';

class StoreStatusCard extends StatelessWidget {
  const StoreStatusCard({
    super.key,
    required this.store,
    this.moneyFormatter,
    this.margin,
    this.showManualBanks = true,
  });

  final StoreStatusViewModel store;
  final MoneyFormatter? moneyFormatter;
  final EdgeInsetsGeometry? margin;
  final bool showManualBanks;

  @override
  Widget build(BuildContext context) {
    if (!store.hasData) {
      return const SizedBox.shrink();
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = store.isOpenNow ? Colors.green : Colors.redAccent;
    final List<Widget> infoLines = <Widget>[];
    final String? nextOpenLabel = store.formatNextOpenLabel();

    if (!store.isOpenNow) {
      infoLines.add(_buildInfoLine(
        context,
        nextOpenLabel != null
            ? 'المتجر مغلق حاليًا، يفتح في $nextOpenLabel'
            : 'المتجر مغلق حاليًا.',
        icon: Icons.schedule_outlined,
        color: accent,
      ));
    } else if (store.browseOnly) {
      infoLines.add(_buildInfoLine(
        context,
        'المتجر في وضع التصفح فقط، لا يمكن إكمال الطلب حالياً.',
        icon: Icons.visibility_outlined,
        color: Colors.orangeAccent,
      ));
    }

    if (store.manualClosureReason != null &&
        store.manualClosureReason!.trim().isNotEmpty &&
        !store.isOpenNow) {
      infoLines.add(_buildInfoLine(
        context,
        store.manualClosureReason!.trim(),
        icon: Icons.info_outline,
        color: Colors.redAccent,
      ));
    }

    if (store.minOrderAmount != null && store.minOrderAmount! > 0) {
      final String? amountDisplay =
          moneyFormatter?.format(store.minOrderAmount!);
      if (amountDisplay != null) {
        infoLines.add(_buildInfoLine(
          context,
          'الحد الأدنى للطلب $amountDisplay',
          icon: Icons.attach_money,
          color: Colors.teal,
        ));
      }
    }

    if (store.checkoutNotice != null &&
        store.checkoutNotice!.trim().isNotEmpty) {
      infoLines.add(_buildInfoLine(
        context,
        store.checkoutNotice!.trim(),
        icon: Icons.campaign_outlined,
        color: Colors.blueGrey,
      ));
    }

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2B2F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name ?? 'متجر إلكتروني',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        store.isOpenNow ? 'مفتوح الآن' : 'مغلق مؤقتاً',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (infoLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...infoLines,
          ],
          if (showManualBanks && store.manualBankAccounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'تفاصيل الحسابات البنكية',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ...store.manualBankAccounts
                .take(4)
                .map(
                  (StoreManualBankAccount account) => _buildBankDetails(
                    context,
                    account: account,
                    isDark: isDark,
                  ),
                )
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildLogo() {
    const double size = 48;
    if (store.logoUrl != null && store.logoUrl!.trim().isNotEmpty) {
      final String url = store.logoUrl!.trim();
      if (url.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LazyNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.storefront_outlined,
        color: Colors.orange,
      ),
    );
  }

  Widget _buildInfoLine(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline,
    Color? color,
  }) {
    final Color resolvedColor =
        color ?? Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: resolvedColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: resolvedColor.withOpacity(0.9),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetails(
    BuildContext context, {
    required StoreManualBankAccount account,
    required bool isDark,
  }) {
    final Color borderColor = isDark ? Colors.white10 : Colors.grey.shade200;
    final List<Widget> rows = <Widget>[
      Text(
        account.displayLabel,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    ];

    if (account.beneficiaryName != null &&
        account.beneficiaryName!.trim().isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'المستفيد: ${account.beneficiaryName}',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              fontSize: 12.5,
            ),
          ),
        ),
      );
    }

    if (account.branch != null && account.branch!.trim().isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'الفرع: ${account.branch}',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    if (account.accountNumber != null &&
        account.accountNumber!.trim().isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _buildCopyTile(
            context,
            label: 'رقم الحساب',
            value: account.accountNumber!.trim(),
            isDark: isDark,
          ),
        ),
      );
    }

    if (account.iban != null && account.iban!.trim().isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _buildCopyTile(
            context,
            label: 'رقم الآيبان',
            value: account.iban!.trim(),
            isDark: isDark,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _buildCopyTile(
    BuildContext context, {
    required String label,
    required String value,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _copyToClipboard(context, value, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.copy_rounded,
              size: 18,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String value,
    String label,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    HelperUtils.showSnackBarMessage(
      context,
      'تم نسخ $label',
      messageDuration: 1,
    );
  }
}
