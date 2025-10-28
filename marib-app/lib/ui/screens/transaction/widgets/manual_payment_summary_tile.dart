import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/utils/extensions/extensions.dart';

class ManualPaymentSummaryTile extends StatelessWidget {
  const ManualPaymentSummaryTile({
    super.key,
    required this.manualPayment,
    required this.dateFormat,
    required this.onTap,
  });

  final ManualPayment manualPayment;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ManualPayment mp = manualPayment;
    final Color statusColor = mp.statusColor;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String amount = mp.currencyLabel != null
        ? '${mp.amountValueLabel} ${mp.currencyLabel}'
        : mp.amountValueLabel;
    final String createdAt = dateFormat.format(mp.createdAt.toLocal());
    final String identifier = mp.displayTransactionIdentifier;
    final String statusLabel = mp.statusLabelAr;
    final String gatewayLabel = mp.gatewayLabel;

    return Material(
      color: context.color.secondaryColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 6,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadiusDirectional.only(
                    topEnd: Radius.circular(4),
                    bottomEnd: Radius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(amount)
                        .bold(weight: FontWeight.w700)
                        .size(18)
                        .color(context.color.territoryColor),
                    const SizedBox(height: 6),
                    Text(gatewayLabel)
                        .size(context.font.small)
                        .color(colors.onSurface.withOpacity(0.7)),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        _StatusChip(
                          label: statusLabel,
                          color: statusColor,
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time,
                            size: context.font.small,
                            color: colors.onSurfaceVariant.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(createdAt)
                            .size(context.font.smaller)
                            .color(colors.onSurfaceVariant.withOpacity(0.7)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(identifier)
                        .size(context.font.small)
                        .color(colors.onSurface.withOpacity(0.9)),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left,
                color: colors.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label).color(color).size(context.font.smaller),
    );
  }
}
