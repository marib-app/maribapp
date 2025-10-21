import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import '../../state/state.dart';

class ConvertHeader extends StatelessWidget {
  const ConvertHeader({
    super.key,
    required this.state,
    required this.brand,
  });

  final CurrencyViewState state;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color onBackground = isDark ? Colors.white : Colors.black;
    final Color cardColor = isDark ? Colors.white.withOpacity(0.04) : Colors.white;
    final Color borderColor = isDark ? Colors.white12 : Colors.black12;

    final DateTime? lastUpdated = state.lastUpdatedAt;
    final String updatedLabel = lastUpdated == null
        ? 'آخر تحديث غير متاح'
        : DateFormat('yyyy-MM-dd HH:mm').format(lastUpdated);

    final String appliedGovernorate =
        state.appliedGovernorateName ?? state.appliedGovernorateCode ?? 'المتوسط الوطني';

    final String fromCurrency = state.fromCurrency.isEmpty ? 'اختر العملة' : state.fromCurrency;
    final String toCurrency = state.toCurrency.isEmpty ? 'اختر العملة' : state.toCurrency;
    final String amountText = state.amountText.isEmpty ? '---' : state.amountText;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: brand.withOpacity(0.12),
                  foregroundColor: brand,
                  radius: 20,
                  child: const Icon(Icons.currency_exchange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'محول العملات',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: onBackground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'آخر تحديث: $updatedLabel',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onBackground.withOpacity(0.75),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'المحافظة النشطة: $appliedGovernorate',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onBackground.withOpacity(0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'المسار الحالي: $amountText → $fromCurrency → $toCurrency',
              style: theme.textTheme.labelLarge?.copyWith(
                color: onBackground.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}