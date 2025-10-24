import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/widgets/standard_bottom_sheet_scaffold.dart';

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
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  WifiRepository get repository => widget.repository;
  final theme = Theme.of(context);

  @override
  void handleCompletion(Map<String, dynamic> result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return StandardBottomSheetScaffold(
      header: StandardBottomSheetHeader(
        showCloseButton: true,
        onClosePressed: () => Navigator.of(context).maybePop(),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أضف شبكتك',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'عرّف مجتمع كبائن واي فاي على شبكتك وشارك تفاصيل التواصل والباقات المتاحة.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: theme.colorScheme.onSurface.withOpacity(.65),
              ),
            ),
          ],
        ),
      ),
      body: buildFormContent(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        showIntroTitle: false,
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: buildSubmitButton(
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
