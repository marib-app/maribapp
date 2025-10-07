import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// عناصر مساعدة مشتركة بين أقسام التوصيل والدفع في شاشة السلة.
Widget buildShimmerLine(
    BuildContext context, {
      double height = 12,
      double width = 120,
    }) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return Shimmer.fromColors(
    baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
    highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
    child: Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

/// صف يعرض السعر مع ملاحظة جانبية داخل شريط الدفع السفلي.
Widget buildPriceRow(
    BuildContext context, {
      required String title,
      required String note,
      required String value,
      required bool loading,
      Color? valueColor,
      FontWeight valueWeight = FontWeight.bold,
      TextStyle? titleStyle,
      TextStyle? noteStyle,
    }) {
  final TextStyle resolvedTitleStyle = titleStyle ??
      TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      );

  final TextStyle resolvedNoteStyle = noteStyle ??
      TextStyle(
        fontSize: 12,
        color: Colors.grey.shade600,
      );

  final bool showNote = note.trim().isNotEmpty;


  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            Flexible(
              child: Text(
                title,
                style: resolvedTitleStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showNote) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  note,
                  style: resolvedNoteStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
      loading
          ? buildShimmerLine(context, width: 60, height: 14)
          : Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: valueWeight,
          color: valueColor ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );

}

/// بطاقة جاهزة تعرض نص سياسة الاسترجاع بتنسيق موحد.
Widget buildReturnPolicyCard(BuildContext context, String policyText) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF262629) : const Color(0xFFFFF3E0),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: const <Widget>[
            Icon(Icons.policy_outlined, color: Colors.orangeAccent),
            SizedBox(width: 6),
            Text(
              'سياسة الاسترجاع',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          policyText,
          style: const TextStyle(height: 1.5, fontSize: 13.5),
        ),
      ],
    ),
  );

}