import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;


class MetalsHeader extends StatelessWidget {
  const MetalsHeader({
    super.key,
    required this.updatedAt,
    required this.source,
    required this.governorateLabel,
    required this.onShare,
    required this.brand,
    required this.onBackground,
    required this.borderColor,
  });

  final DateTime? updatedAt;
  final String? source;
  final String governorateLabel;
  final VoidCallback onShare;
  final Color brand;
  final Color onBackground;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final String updatedLabel = updatedAt == null
        ? 'آخر تحديث غير متاح'
        : DateFormat('yyyy-MM-dd HH:mm').format(updatedAt!);

    final String resolvedSource = (source == null || source!.isEmpty)
        ? 'غير متاح'
        : source!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 18,
            color: onBackground.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'أسعار المعادن الثمينة — $updatedLabel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: onBackground.withOpacity(0.85),
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: ui.TextDirection.rtl,

                ),
                const SizedBox(height: 2),
                Text(
                  'المصدر: $resolvedSource',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: onBackground.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: ui.TextDirection.rtl,

                ),
                const SizedBox(height: 2),
                Text(
                  'المحافظة المعروضة: $governorateLabel',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: onBackground.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: ui.TextDirection.rtl,

                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onShare,
            icon: Icon(Icons.ios_share, size: 18, color: brand),
            splashRadius: 18,
            tooltip: 'مشاركة',
          ),
        ],
      ),
    );
  }
}