part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

class _AddNetworkScreen extends StatefulWidget {
  const _AddNetworkScreen({this.userLatLng, WifiRepository? repository})
      : repository = repository ?? const WifiRepository();

  final LatLng? userLatLng;
  final WifiRepository repository;

  @override
  State<_AddNetworkScreen> createState() => _AddNetworkScreenState();
}

class _AddNetworkScreenState extends _AddNetworkFormState<_AddNetworkScreen> {
  @override
  LatLng? get userLatLng => widget.userLatLng;

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

class _NetworkLocationPicker extends StatefulWidget {
  const _NetworkLocationPicker({required this.initialPosition});

  final LatLng initialPosition;

  @override
  State<_NetworkLocationPicker> createState() => _NetworkLocationPickerState();
}

class _NetworkLocationPickerState extends State<_NetworkLocationPicker> {
  late LatLng _current;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _current = widget.initialPosition;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _updateSelection(LatLng value) async {
    if (!mounted) return;
    setState(() => _current = value);
    await _controller?.animateCamera(
      CameraUpdate.newLatLng(value),
    );
  }

  void _confirm() {
    Navigator.of(context).pop(_current);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حدد موقع الشبكة'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('تم'),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _current, zoom: 14.5),
        markers: {
          Marker(
            markerId: const MarkerId('selected_location'),
            position: _current,
            draggable: true,
            onDragEnd: (value) {
              unawaited(_updateSelection(value));
            },
          ),
        },
        onMapCreated: (controller) => _controller = controller,
        onTap: (value) {
          unawaited(_updateSelection(value));
        },
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirm,
        icon: const Icon(Icons.check),
        label: const Text('تأكيد'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}