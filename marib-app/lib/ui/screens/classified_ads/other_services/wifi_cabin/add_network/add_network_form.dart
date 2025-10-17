part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

abstract class _AddNetworkFormState<T extends StatefulWidget> extends State<T> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  PlatformFile? _logoFile;
  PlatformFile? _loginScreenshotFile;
  bool _isSubmitting = false;


  WifiRepository get repository;



  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _notesController.dispose();
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
          enabled: !_isSubmitting,
          decoration: const InputDecoration(
            labelText: 'اسم الشبكة',
          ),
        ),
        const SizedBox(height: 16),
        _FilePickerTile(
          title: 'شعار الشبكة',
          placeholder: 'ارفع صورة الشعار',
          fileName: _logoFile?.name,
          isBusy: _isSubmitting,
          onTap: () => _pickImage(isLogo: true),
        ),
        const SizedBox(height: 16),
        _FilePickerTile(
          title: 'صورة صفحة الدخول',
          placeholder: 'ارفع صورة توضح صفحة الدخول',
          fileName: _loginScreenshotFile?.name,
          isBusy: _isSubmitting,
          onTap: () => _pickImage(isLogo: false),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _contactController,
          enabled: !_isSubmitting,
          decoration: const InputDecoration(
            labelText: 'وسيلة التواصل',
            hintText: 'مثال: 777123456 أو @account',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          enabled: !_isSubmitting,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'ملاحظات إضافية (اختياري)',
          ),
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



  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('يرجى إدخال اسم الشبكة.');
      return;
    }
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      _showError('يرجى إدخال وسيلة للتواصل.');
      return;
    }
    if (_logoFile == null) {
      _showError('يرجى رفع صورة شعار الشبكة.');
      return;
    }
    if (_loginScreenshotFile == null) {
      _showError('يرجى رفع صورة لصفحة الدخول.');
      return;
    }

    final MultipartFile? logoMultipart = _prepareMultipart(_logoFile!);
    final MultipartFile? loginMultipart = _prepareMultipart(_loginScreenshotFile!);

    if (logoMultipart == null || loginMultipart == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final Map<String, dynamic> response =
      await repository.createOwnerRequest(
        name: name,
        contact: contact,
        logo: logoMultipart,
        loginScreenshot: loginMultipart,
        notes: _stringify(_notesController.text),
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



  Future<void> _pickImage({required bool isLogo}) async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedImageExtensions,
        withData: kIsWeb,
      );

      if (result == null) {
        return;
      }

      final PlatformFile file = result.files.single;
      final String extension = (file.extension ?? '').toLowerCase();
      if (!_allowedImageExtensions.contains(extension)) {
        _showError('صيغة الملف غير مدعومة. يرجى اختيار صورة بصيغة PNG أو JPG أو WEBP.');
        return;
      }

      if (file.size > _maxUploadSizeBytes) {
        _showError('حجم الملف يتجاوز الحد المسموح (4 ميجابايت).');
        return;
      }

      if (!mounted) return;

      setState(() {
        if (isLogo) {
          _logoFile = file;
        } else {
          _loginScreenshotFile = file;
        }
      });
    } catch (error) {
      _showError('تعذّر اختيار الملف، حاول مرة أخرى.');
    }
  }

  MultipartFile? _prepareMultipart(PlatformFile file) {
    try {
      if (!kIsWeb && file.path != null) {
        return MultipartFile.fromFileSync(
          file.path!,
          filename: file.name,
        );
      }

      final Uint8List? bytes = file.bytes;
      if (bytes != null) {
        return MultipartFile.fromBytes(
          bytes,
          filename: file.name,
        );
      }
    } catch (_) {
      _showError('تعذّر تجهيز الملف المرفوع (${file.name}).');
      return null;
    }

    _showError('تعذّر قراءة الملف المرفوع (${file.name}).');
    return null;
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static const int _maxUploadSizeBytes = 4 * 1024 * 1024;
  static const List<String> _allowedImageExtensions = <String>['jpg', 'jpeg', 'png', 'webp'];

  String? _stringify(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  void handleCompletion(Map<String, dynamic> result);

}

class _FilePickerTile extends StatelessWidget {
  const _FilePickerTile({
    required this.title,
    required this.placeholder,
    required this.onTap,
    required this.isBusy,
    this.fileName,
  });

  final String title;
  final String placeholder;
  final String? fileName;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final color = context.color;
    final bool hasFile = fileName != null && fileName!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color.textDefaultColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isBusy ? null : onTap,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: color.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.borderColor.darken(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: color.territoryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasFile ? fileName! : placeholder,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasFile
                          ? color.textDefaultColor
                          : color.textDefaultColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}