import 'package:flutter/material.dart';

class ConvertActionButtons extends StatelessWidget {
  const ConvertActionButtons({
    super.key,
    required this.brand,
    required this.onConvert,
    required this.onReset,
  });

  final Color brand;
  final VoidCallback onConvert;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color onBackground = isDark ? Colors.white : Colors.black;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 0),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('convertAction'),
                onPressed: onConvert,
                icon: const Icon(Icons.check),
                label: const Text('تحويل'),
                style: FilledButton.styleFrom(
                  backgroundColor: brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('resetAction'),
                onPressed: onReset,
                icon: Icon(Icons.refresh, color: onBackground),
                label: const Text('تصفير'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: onBackground.withOpacity(0.25)),
                  foregroundColor: onBackground,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
