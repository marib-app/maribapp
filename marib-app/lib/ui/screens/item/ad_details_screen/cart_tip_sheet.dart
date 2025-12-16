import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';

class CartTipSheet extends StatelessWidget {
  final String titleText;
  final String descriptionText;
  final bool showSheinButton;
  final List<String> chips;
  final VoidCallback? onExternal;
  final VoidCallback onNavigate;
  final VoidCallback onClose;
  final Color textColor;
  final Color sheetBackground;
  final Color accentColor;
  final Color handleColor;
  final Color outlineForeground;
  final Color outlineBorder;
  final TextStyle titleStyle;
  final TextStyle descriptionStyle;

  const CartTipSheet({
    super.key,
    required this.titleText,
    required this.descriptionText,
    required this.showSheinButton,
    this.chips = const <String>[],
    required this.onExternal,
    required this.onNavigate,
    required this.onClose,
    required this.textColor,
    required this.sheetBackground,
    required this.accentColor,
    required this.handleColor,
    required this.outlineForeground,
    required this.outlineBorder,
    required this.titleStyle,
    required this.descriptionStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sheetBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 50,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Icon(
              Icons.info_outline,
              size: 50,
              color: accentColor,
            ),
            const SizedBox(height: 15),
            Text(
              titleText,
              textAlign: TextAlign.center,
              style: titleStyle,
            ),
            const SizedBox(height: 10),
            Text(
              descriptionText,
              textAlign: TextAlign.center,
              style: descriptionStyle,
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: chips
                    .map(
                      (chip) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: outlineBorder.withOpacity(0.6),
                          ),
                        ),
                        child: Text(
                          chip,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 15),
            Text(
              'ãä ãåã ÇÎÊíÇÑã, ãíÍÊã ÎÕã ÇáÃÕäÇÝ ãÊÆßÏÇ',
              textAlign: TextAlign.center,
              style: descriptionStyle,
            ),
            const SizedBox(height: 20),
            if (showSheinButton && onExternal != null) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: context.color.secondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text(
                  'ÇÝÊÍ ÇáÑÇÈØ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 15),
            ],
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onNavigate,
              child: const Text(
                'ÅÖÇÝÉ Åáì ÇáÓáÉ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: outlineForeground,
                side: BorderSide(color: outlineBorder),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onClose,
              child: const Text(
                'ÅÛáÇÞ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
