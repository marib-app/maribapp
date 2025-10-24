import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:marib/data/wifi/wifi_repository.dart';

import 'add_network_form.dart';

class WifiAddNetworkSheet extends StatefulWidget {
  const WifiAddNetworkSheet({super.key, WifiRepository? repository})
      : repository = repository ?? const WifiRepository();

  final WifiRepository repository;

  @override
  State<WifiAddNetworkSheet> createState() => WifiAddNetworkSheetState();
}

class WifiAddNetworkSheetState
    extends WifiAddNetworkFormState<WifiAddNetworkSheet> {
  @override
  WifiRepository get repository => widget.repository;

  @override
  void handleCompletion(Map<String, dynamic> result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) {
        final theme = Theme.of(context);
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Material(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                _buildSheetHeader(theme),
                const Divider(height: 1),
                Expanded(
                  child: buildFormContent(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    showIntroTitle: false,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: buildSubmitButton(
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetHeader(ThemeData theme) {
    final color = context.color;
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: onSurface.withOpacity(.18),
          borderRadius: BorderRadius.circular(8),
        ),
          ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أضف شبكتك',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'عرّف مجتمع كبائن واي فاي على شبكتك وشارك تفاصيل التواصل والباقات المتاحة.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: onSurface.withOpacity(.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.territoryColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: color.territoryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
