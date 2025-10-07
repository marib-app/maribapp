part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

abstract class _AddNetworkFormState<T extends StatefulWidget> extends State<T> {
  final TextEditingController _nameController = TextEditingController();
  LatLng? _selected;
  double _coverage = 3;
  bool _isSubmitting = false;

  static const LatLng _defaultLatLng = LatLng(15.3694, 44.1910);

  LatLng? get userLatLng;
  WifiRepository get repository;

  @override
  void initState() {
    super.initState();
    _selected = userLatLng;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget buildFormContent({
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
  }) {
    final color = context.color;
    final EdgeInsetsGeometry effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 16);

    return ListView(
      controller: controller,
      padding: effectivePadding,
      children: [
        Text(
          'أضف شبكتك',
          style: TextStyle(
            color: color.textDefaultColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'اسم الشبكة',
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _isSubmitting ? null : _selectLocation,
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: color.secondaryColor.withOpacity(0.2),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map_outlined,
                  color: color.textDefaultColor.withOpacity(0.65),
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  _selected == null
                      ? 'اضغط لاختيار الموقع على الخريطة'
                      : 'الموقع المحدد: ${_selected!.latitude.toStringAsFixed(4)}, ${_selected!.longitude.toStringAsFixed(4)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color.textDefaultColor.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'نطاق التغطية (كم)',
          style: TextStyle(
            color: color.textDefaultColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        Slider(
          value: _coverage,
          min: 1,
          max: 10,
          divisions: 9,
          label: _coverage.toStringAsFixed(0),
          onChanged: _isSubmitting
              ? null
              : (value) {
            setState(() => _coverage = value);
          },
        ),
      ],
    );
  }

  Widget buildSubmitButton({EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _onSubmit,
          child: _isSubmitting
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
              : const Text('إرسال الطلب'),
        ),
      ),
    );
  }

  Future<void> _selectLocation() async {
    FocusScope.of(context).unfocus();
    final LatLng initial = _selected ?? userLatLng ?? _defaultLatLng;
    final LatLng? result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _NetworkLocationPicker(initialPosition: initial),
      ),
    );

    if (result != null && mounted) {
      setState(() => _selected = result);
    }
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('يرجى إدخال اسم الشبكة.');
      return;
    }
    if (_selected == null) {
      _showError('يرجى اختيار موقع الشبكة على الخريطة.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final double coverage = double.parse(_coverage.toStringAsFixed(1));
      final Map<String, dynamic> response =
      await repository.createOwnerRequest(
        name: name,
        latitude: _selected!.latitude,
        longitude: _selected!.longitude,
        coverageKm: coverage,
      );

      Map<String, dynamic> payload = <String, dynamic>{};
      final dynamic rawData = response['data'] ??
          response['network'] ??
          response['request'] ??
          response['payload'];
      if (rawData is Map<String, dynamic>) {
        payload = Map<String, dynamic>.from(rawData);
      } else if (rawData is Map) {
        payload = Map<String, dynamic>.from(rawData as Map);
      }

      final Map<String, dynamic> result = <String, dynamic>{
        'name': payload['name'] ?? name,
        'status': payload['status'] ??
            payload['state'] ??
            payload['request_status'] ??
            response['status'] ??
            response['state'],
        'message': _stringify(
          response['message'] ??
              response['note'] ??
              payload['message'] ??
              payload['status_message'],
        ),
        'id': payload['id'] ?? response['id'],
      }..removeWhere((key, value) => value == null);

      if (!mounted) {
        return;
      }

      handleCompletion(result);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.toString());
      setState(() => _isSubmitting = false);
    } catch (_) {
      if (!mounted) return;
      _showError('تعذّر إرسال الطلب، حاول لاحقًا.');
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  void handleCompletion(Map<String, dynamic> result);
}