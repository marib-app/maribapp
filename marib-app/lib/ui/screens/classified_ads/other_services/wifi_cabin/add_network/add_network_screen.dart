import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';

import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'add_network_form.dart';

class WifiAddNetworkScreen extends StatefulWidget {
  const WifiAddNetworkScreen({super.key, WifiRepository? repository})
      : repository = repository ?? const WifiRepository();

  final WifiRepository repository;

  @override
  State<WifiAddNetworkScreen> createState() => WifiAddNetworkScreenState();
}

class WifiAddNetworkScreenState
    extends WifiAddNetworkFormState<WifiAddNetworkScreen> {
  @override
  WifiRepository get repository => widget.repository;

  @override
  void handleCompletion(Map<String, dynamic> result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildPageHeader(theme),
            const Divider(height: 1),
            Expanded(
              child: buildFormContent(
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
  }

  Widget _buildPageHeader(ThemeData theme) {
    final color = context.color;
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
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
    );
  }
}
