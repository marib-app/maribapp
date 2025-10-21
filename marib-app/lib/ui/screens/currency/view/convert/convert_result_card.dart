import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class ConvertResultCard extends StatelessWidget {
  const ConvertResultCard({
    super.key,
    required this.brand,
    required this.isDark,
    required this.convertedAmount,
    required this.hasCalculated,
    required this.toCurrency,
    required this.onShowAdvancedDetails,
    required this.actions,
  });

  final Color brand;
  final bool isDark;
  final double convertedAmount;
  final bool hasCalculated;
  final String toCurrency;
  final VoidCallback? onShowAdvancedDetails;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final Color onBackground = isDark ? Colors.white : Colors.black;
    final String convertedValue = hasCalculated
        ? "${NumberFormat('#,##0.##').format(convertedAmount)} $toCurrency"
        : '---';

    return Card(
      key: const Key('conversionResultCard'),
      color: isDark ? Colors.white10 : Colors.white,
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: brand.withOpacity(0.1),
                  foregroundColor: brand,
                  child: const Icon(Icons.currency_exchange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'المبلغ المحول',
                    style: TextStyle(
                      color: onBackground.withOpacity(0.75),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    textDirection: ui.TextDirection.rtl,

                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              convertedValue,
              key: const Key('convertedValueText'),
              style: TextStyle(
                color: onBackground,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('advancedDetailsButton'),
                onPressed: onShowAdvancedDetails,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('التفاصيل المتقدمة'),
                style: TextButton.styleFrom(
                  foregroundColor: brand,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            actions,
          ],
        ),
      ),
    );
  }
}