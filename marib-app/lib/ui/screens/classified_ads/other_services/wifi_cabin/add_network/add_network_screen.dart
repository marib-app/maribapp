part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

class _AddNetworkScreen extends StatefulWidget {
  const _AddNetworkScreen({WifiRepository? repository})
      : repository = repository ?? const WifiRepository();


  final WifiRepository repository;

  @override
  State<_AddNetworkScreen> createState() => _AddNetworkScreenState();
}

class _AddNetworkScreenState extends _AddNetworkFormState<_AddNetworkScreen> {


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