import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

class WalletActionsCard extends StatelessWidget {
  const WalletActionsCard({
    super.key,
    required this.onTopUp,
    required this.onTransfer,
    required this.onWithdrawal,
  });

  final VoidCallback onTopUp;
  final VoidCallback onTransfer;
  final VoidCallback onWithdrawal;

  @override
  Widget build(BuildContext context) {
    final borderColor = context.color.borderColor.withOpacity(0.2);
    final backgroundColor = context.color.secondaryColor;

    return Card(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WalletPrimaryButton(
              title: 'walletTopUpAction'.translate(context),
              icon: Icons.account_balance_wallet_outlined,
              onPressed: onTopUp,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onTransfer,
              icon: const Icon(Icons.swap_horiz),
              label: Text('walletTransferAction'.translate(context)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onWithdrawal,
              icon: const Icon(Icons.arrow_circle_down_outlined),
              label: Text('walletWithdrawalAction'.translate(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletPrimaryButton extends StatelessWidget {
  const _WalletPrimaryButton({
    required this.title,
    required this.onPressed,
    this.icon,
  });

  final String title;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = context.color.territoryColor;
    final onBackground = theme.colorScheme.onPrimary;

    final textStyle = theme.textTheme.titleMedium?.copyWith(
      color: onBackground,
      fontWeight: FontWeight.w700,
    ) ??
        TextStyle(
          color: onBackground,
          fontWeight: FontWeight.w700,
          fontSize: theme.textTheme.titleMedium?.fontSize ?? 16,
        );

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        backgroundColor: background,
        foregroundColor: onBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ).merge(
        ButtonStyle(
          overlayColor: WidgetStatePropertyAll(onBackground.withOpacity(0.12)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}