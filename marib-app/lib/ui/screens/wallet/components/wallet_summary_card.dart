import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class WalletSummaryCard extends StatelessWidget {
  const WalletSummaryCard({
    super.key,
    this.balanceText,
    this.lastUpdated,
    this.isLoading = false,
  });

  final String? balanceText;
  final DateTime? lastUpdated;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final accent = context.color.territoryColor;
    final secondaryAccent = context.color.forthColor.withOpacity(0.9);
    final captionColor = onPrimary.withOpacity(0.75);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, secondaryAccent],
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: secondaryAccent.withOpacity(0.28),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -18,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -44,
              left: -12,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 24,
                          color: onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'walletBalance'.translate(context),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: onPrimary,
                            fontWeight: FontWeight.w600,
                          ) ??
                              TextStyle(
                                color: onPrimary,
                                fontSize:
                                theme.textTheme.titleMedium?.fontSize ?? 18,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (isLoading)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Text(
                      balanceText ?? '--',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: onPrimary,
                        fontWeight: FontWeight.w800,
                      ) ??
                          TextStyle(
                            color: onPrimary,
                            fontSize:
                            theme.textTheme.displaySmall?.fontSize ?? 36,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 18, color: captionColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lastUpdated == null
                              ? 'walletLastUpdatedUnknown'.translate(context)
                              : UiUtils.formatDate(
                              lastUpdated!.toIso8601String()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: captionColor,
                            fontWeight: FontWeight.w500,
                          ) ??
                              TextStyle(
                                color: captionColor,
                                fontSize:
                                theme.textTheme.bodySmall?.fontSize ?? 12,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}