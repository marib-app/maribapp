import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('أضف شبكتك'),
      ),
      backgroundColor: context.color.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: buildFormContent(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              ),
            ),
            buildSubmitButton(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            ),
          ],
        ),
      ),
    );
  }

}