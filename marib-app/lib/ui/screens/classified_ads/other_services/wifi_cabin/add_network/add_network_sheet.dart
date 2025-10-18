import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';


  import 'package:marib/data/wifi/wifi_repository.dart';
  import 'package:marib/utils/extensions/extensions.dart';

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
    final color = context.color;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: color.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: color.secondaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: buildFormContent(controller: controller),
              ),
              buildSubmitButton(),
            ],
          ),
        );
      },
    );
  }
}