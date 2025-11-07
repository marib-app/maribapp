import 'package:flutter/material.dart';
import 'package:marib/ui/screens/wallet/components/wallet_actions_card.dart';
import 'package:marib/ui/screens/wallet/wallet_manual_payments_section.dart';
import 'package:marib/utils/extensions/extensions.dart';

class WalletActionsPage extends StatelessWidget {
  const WalletActionsPage({
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'walletTopUpHeader'.translate(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            WalletActionsCard(
              onTopUp: onTopUp,
              onTransfer: onTransfer,
              onWithdrawal: onWithdrawal,
            ),
            const SizedBox(height: 24),
            WalletManualPaymentsSection(),
          ],
        ),
      ),
    );
  }
}
