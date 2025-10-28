import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/payment/manual_payment.dart';

class ManualPaymentSummaryCard extends StatelessWidget {
  const ManualPaymentSummaryCard({
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
    final colors = context.color;
    final statusColor = manualPayment.statusColor;
    final statusLabel = manualPayment.statusLabelAr;
    final subtitle = _buildSubtitle();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.secondaryColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 18),
        child: Row(
          children: <Widget>[
            _LeadingIcon(
              statusColor: statusColor,
              icon: _resolveIcon(manualPayment),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _resolveTitle(manualPayment),
                  )
                      .bold(weight: FontWeight.w700)
                      .size(context.font.normal)
                      .color(colors.onSurface),
                  const SizedBox(height: 6),
                  if (subtitle != null) ...<Widget>[
                    Text(subtitle)
                        .size(context.font.small)
                        .color(colors.onSurfaceVariant.withOpacity(0.8)),
                    const SizedBox(height: 6),
                  ],
                  _MetaRow(
                    identifier: manualPayment.displayTransactionIdentifier,
                    gateway: manualPayment.gatewayLabel,
                    dateText:
                        dateFormat.format(manualPayment.createdAt.toLocal()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(manualPayment.amountLabel)
                    .bold(weight: FontWeight.w700)
                    .size(16)
                    .color(colors.territoryColor),
                const SizedBox(height: 10),
                _StatusChip(color: statusColor, label: statusLabel),
                const SizedBox(height: 12),
                Icon(Icons.chevron_left_rounded,
                    color: colors.onSurfaceVariant.withOpacity(0.7)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _buildSubtitle() {
    final details = <String?>[
      manualPayment.categoryLabelAr,
      manualPayment.serviceDetailsLabel,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();

    if (details.isEmpty) {
      return null;
    }
    final unique = <String>{};
    final filtered = <String>[];
    for (final entry in details) {
      if (unique.add(entry)) {
        filtered.add(entry);
      }
    }
    return filtered.join(' - ');
  }

  String _resolveTitle(ManualPayment payment) {
    final candidates = <String?>[
      payment.payableSummary,
      payment.categoryLabelAr,
      payment.gatewayLabel,
      payment.manualPaymentDisplayId,
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return 'Transaction details';
  }

  IconData _resolveIcon(ManualPayment payment) {
    if (payment.categoryIcon != null) {
      return payment.categoryIcon!;
    }

    final type = payment.payableType?.toLowerCase().trim() ?? '';

    if (payment.isServiceRequest || type.contains('service')) {
      return Icons.home_repair_service_outlined;
    }
    if (type.contains('package') || type.contains('subscription')) {
      return Icons.card_giftcard_outlined;
    }
    if (type.contains('order')) {
      return Icons.shopping_bag_outlined;
    }
    if (type.contains('wallet')) {
      return Icons.account_balance_wallet_outlined;
    }

    return Icons.receipt_long_outlined;
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.statusColor, required this.icon});

  final Color statusColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: statusColor, size: 28),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label).size(12).color(color).bold(weight: FontWeight.w600),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.identifier,
    required this.gateway,
    required this.dateText,
  });

  final String identifier;
  final String? gateway;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant.withOpacity(0.7);
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: color,
      fontSize: 12,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.confirmation_number_outlined, size: 18, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(identifier,
                  overflow: TextOverflow.ellipsis, style: textStyle),
            ),
            if (gateway != null && gateway!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(gateway!)
                    .size(11)
                    .color(theme.colorScheme.primary)
                    .bold(weight: FontWeight.w600),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Icon(Icons.schedule_outlined, size: 18, color: color),
            const SizedBox(width: 4),
            Text(dateText, style: textStyle),
          ],
        ),
      ],
    );
  }
}
