import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';

abstract class WifiAddNetworkFormState<T extends StatefulWidget>
    extends State<T> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  PlatformFile? _logoFile;
  PlatformFile? _loginScreenshotFile;
  PlatformFile? _voucherFile;
  List<WifiPlan> _availablePlans = <WifiPlan>[];
  WifiPlan? _selectedPlan;
  bool _isLoadingPlans = false;
  String? _plansError;
  bool _isSubmitting = false;

  WifiRepository get repository;

  @protected
  void handleCompletion(Map<String, dynamic> result);

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

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
    bool showIntroTitle = true,
  }) {
    final color = context.color;
    final EdgeInsetsGeometry effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 16);

    return ListView(
      controller: controller,
      padding: effectivePadding,
      children: [
        if (showIntroTitle) ...[
    Text(
    'أضف شبكتك',
    style: TextStyle(
    color: color.textDefaultColor,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _nameController,
          enabled: !_isSubmitting,
          decoration: const InputDecoration(
            labelText: 'اسم الشبكة',
          ),
        ),
        const SizedBox(height: 16),
        _buildPlansDropdown(color),
        if (_isLoadingPlans) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ] else if (_plansError != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _isSubmitting ? null : _loadPlans,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ] else if (_availablePlans.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'لا توجد باقات متاحة للرفع حاليًا.',
            style: TextStyle(
              color: color.textDefaultColor.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 16),
        WifiFilePickerTile(
          title: 'شعار الشبكة',
          placeholder: 'ارفع صورة الشعار',
          fileName: _logoFile?.name,
          isBusy: _isSubmitting,
          onTap: () => _pickImage(isLogo: true),
        ),
        const SizedBox(height: 16),
        WifiFilePickerTile(
          title: 'صورة صفحة الدخول',
          placeholder: 'ارفع صورة توضح صفحة الدخول',
          fileName: _loginScreenshotFile?.name,
          isBusy: _isSubmitting,
          onTap: () => _pickImage(isLogo: false),
        ),
        const SizedBox(height: 16),
        WifiFilePickerTile(
          title: 'ملف أكواد القسائم',
          placeholder: 'ارفع ملف CSV أو XLS أو XLSX يحتوي على الأكواد',
          fileName: _voucherFile?.name,
          isBusy: _isSubmitting,
          onTap: _pickVoucherFile,
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

  Widget buildSubmitButton({
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
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

    if (_selectedPlan == null) {
      _showError('يرجى اختيار الباقة المستهدفة.');
      return;
    }
    if (_voucherFile == null) {
      _showError('يرجى رفع ملف أكواد القسائم.');
      return;
    }

    final MultipartFile? logoMultipart = _prepareMultipart(_logoFile!);
    final MultipartFile? loginMultipart =
        _prepareMultipart(_loginScreenshotFile!);
    final MultipartFile? voucherMultipart =
        _prepareVoucherMultipart(_voucherFile!);

    if (logoMultipart == null ||
        loginMultipart == null ||
        voucherMultipart == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final Map<String, dynamic> response = await repository.createOwnerRequest(
        name: name,
        contact: contact,
        logo: logoMultipart,
        loginScreenshot: loginMultipart,
        notes: _stringify(_notesController.text),
      );

      final Map<String, dynamic> batchResponse =
          await repository.uploadPlanBatch(
        planId: _selectedPlan!.id,
        file: voucherMultipart,
      );

      final Map<String, dynamic> batchPayload =
          _extractBatchPayload(batchResponse)..['plan_id'] = _selectedPlan!.id;

      final String batchMessage = _buildBatchMessage(batchPayload);

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
        'batch': batchPayload,
      }..removeWhere((key, value) => value == null);

      final String? existingMessage = result['message'] as String?;
      final String? combinedMessage =
          _combineMessages(existingMessage, batchMessage);

      if (combinedMessage != null) {
        result['message'] = combinedMessage;
      }

      if (!mounted) {
        return;
      }

      setState(() => _isSubmitting = false);

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
        _showError(
          'صيغة الملف غير مدعومة. يرجى اختيار صورة بصيغة PNG أو JPG أو WEBP.',
        );

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
    } catch (_) {
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

  MultipartFile? _prepareVoucherMultipart(PlatformFile file) {
    final String extension = (file.extension ?? '').toLowerCase();
    if (!_allowedVoucherExtensions.contains(extension)) {
      _showError(
        'صيغة ملف القسائم غير مدعومة. يرجى اختيار ملف بصيغة CSV أو XLS أو XLSX.',
      );

      return null;
    }

    if (file.size > _maxVoucherUploadSizeBytes) {
      _showError('حجم ملف القسائم يتجاوز الحد المسموح (5 ميجابايت).');
      return null;
    }

    return _prepareMultipart(file);
  }

  void _showError(String message) {
    HelperUtils.showSnackBarMessage(
      context,
      message,
      type: MessageType.error,
    );
  }

  Future<void> _loadPlans() async {
    if (_isLoadingPlans || _isSubmitting) return;
    setState(() {
      _isLoadingPlans = true;
      _plansError = null;
    });

    try {
      final plans = await repository.fetchManagedPlans();
      if (!mounted) return;
      setState(() {
        _availablePlans = plans;
        if (_selectedPlan != null) {
          final int selectedId = _selectedPlan!.id;
          final WifiPlan? refreshed = plans.firstWhere(
            (plan) => plan.id == selectedId,
            orElse: () => _selectedPlan!,
          );
          _selectedPlan = refreshed;
        }
        _isLoadingPlans = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _plansError = error.toString().isEmpty
            ? 'تعذّر تحميل الباقات المتاحة.'
            : error.toString();
        _isLoadingPlans = false;
      });
    }
  }

  Widget _buildPlansDropdown(ColorScheme color) {
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(
        labelText: 'الباقة المستهدفة',
        errorText: _plansError,
      ),
      value: _selectedPlan?.id,
      items: _availablePlans
          .map(
            (plan) => DropdownMenuItem<int>(
              value: plan.id,
              child: Text(plan.name),
            ),
          )
          .toList(),
      onChanged: _isSubmitting || _isLoadingPlans || _availablePlans.isEmpty
          ? null
          : (value) {
              if (value == null) {
                setState(() => _selectedPlan = null);
                return;
              }
              setState(() {
                _selectedPlan =
                    _availablePlans.firstWhere((plan) => plan.id == value);
              });
            },
    );
  }

  Future<void> _pickVoucherFile() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedVoucherExtensions,
        withData: kIsWeb,
      );

      if (result == null) {
        return;
      }

      final PlatformFile file = result.files.single;
      final MultipartFile? prepared = _prepareVoucherMultipart(file);
      if (prepared == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _voucherFile = file;
      });
    } catch (_) {
      _showError('تعذّر اختيار ملف الأكواد، حاول مرة أخرى.');
    }
  }

  Map<String, dynamic> _extractBatchPayload(Map<String, dynamic> response) {
    final dynamic rawData = response['data'] ?? response['batch'];
    if (rawData is Map<String, dynamic>) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData as Map);
    }
    return <String, dynamic>{};
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _buildBatchMessage(Map<String, dynamic> batch) {
    final int accepted = _parseInt(batch['accepted']);
    final int rejected = _parseInt(batch['rejected']);
    final int total = _parseInt(batch['total']);

    return 'تم رفع ملف الأكواد بنجاح (مقبول: $accepted، مرفوض: $rejected، الإجمالي: $total).';
  }

  String? _combineMessages(String? first, String? second) {
    final String? normalizedFirst = _stringify(first);
    final String? normalizedSecond = _stringify(second);

    if (normalizedFirst == null) return normalizedSecond;
    if (normalizedSecond == null) return normalizedFirst;
    return '$normalizedFirst\n$normalizedSecond';
  }

  @visibleForTesting
  void debugSetFiles({
    PlatformFile? logo,
    PlatformFile? login,
    PlatformFile? voucher,
  }) {
    _logoFile = logo;
    _loginScreenshotFile = login;
    _voucherFile = voucher;
  }

  @visibleForTesting
  void debugSelectPlan(WifiPlan? plan) {
    _selectedPlan = plan;
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  static const int _maxUploadSizeBytes = 4 * 1024 * 1024;
  static const List<String> _allowedImageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp'
  ];
  static const int _maxVoucherUploadSizeBytes = 5 * 1024 * 1024;
  static const List<String> _allowedVoucherExtensions = <String>[
    'csv',
    'xls',
    'xlsx'
  ];
}

class WifiFilePickerTile extends StatelessWidget {
  const WifiFilePickerTile({
    super.key,
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

@visibleForTesting
void debugUpdateAddNetworkFormState(
  State state, {
  PlatformFile? logo,
  PlatformFile? login,
  PlatformFile? voucher,
  WifiPlan? selectedPlan,
}) {
  if (state is WifiAddNetworkFormState) {
    state
      ..debugSetFiles(logo: logo, login: login, voucher: voucher)
      ..debugSelectPlan(selectedPlan);
  }
}

@visibleForTesting
class AddNetworkFormTestHarness extends StatefulWidget {
  const AddNetworkFormTestHarness({
    super.key,
    required this.repository,
    this.onComplete,
  });

  final WifiRepository repository;
  final void Function(Map<String, dynamic>)? onComplete;

  @override
  State<AddNetworkFormTestHarness> createState() =>
      WifiAddNetworkFormTestHarnessState();
}

class WifiAddNetworkFormTestHarnessState
    extends WifiAddNetworkFormState<AddNetworkFormTestHarness> {
  @override
  WifiRepository get repository => widget.repository;

  @override
  void handleCompletion(Map<String, dynamic> result) {
    widget.onComplete?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: buildFormContent()),
            buildSubmitButton(),
          ],
        ),
      ),
    );
  }
}
