import 'package:flutter/material.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

class TransactionErrorBanner extends StatelessWidget {
  const TransactionErrorBanner({
    super.key,
    required this.onRetry,
    this.includeRetry = false,
  });

  final VoidCallback onRetry;
  final bool includeRetry;

  @override
  Widget build(BuildContext context) {
    final Color color = Colors.red.shade600;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حدث خطأ أثناء تحديث معاملات التحويل البنكي. سيتم إعادة المحاولة تلقائيًا.',
                ).size(context.font.small).color(color),
              ),
            ],
          ),
          if (includeRetry) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('إعادة المحاولة'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}