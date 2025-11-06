import 'package:flutter/material.dart';
import 'package:marib/utils/ui_utils.dart';

class UnsupportedProductManagement extends StatelessWidget {
  const UnsupportedProductManagement({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        title: 'إدارة المنتج',
        showBackButton: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: colorScheme.primary.withOpacity(0.8),
              ),
              const SizedBox(height: 16),
              Text(
                'خيارات إدارة المنتج متاحة فقط لإعلانات أقسام المتجر أو الكمبيوتر أو شي إن.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('عودة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}