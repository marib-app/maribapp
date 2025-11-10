import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:path/path.dart' as p;

class WifiCabinRequestScreen extends StatefulWidget {
  const WifiCabinRequestScreen({super.key});

  @override
  State<WifiCabinRequestScreen> createState() => _WifiCabinRequestScreenState();
}

class _WifiCabinRequestScreenState extends State<WifiCabinRequestScreen> {
  final WifiRepository _repository = const WifiRepository();
  final ImagePicker _imagePicker = ImagePicker();

  final GlobalKey<FormState> _networkFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _plansFormKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<_ContactFieldData> _contactFields = <_ContactFieldData>[
    _ContactFieldData(),
  ];

  final List<_PlanFormData> _plans = <_PlanFormData>[
    _PlanFormData(),
  ];

  XFile? _logoFile;
  XFile? _loginScreenshotFile;

  bool _isSubmitting = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController..dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    for (final _ContactFieldData contact in _contactFields) {
      contact.dispose();
    }
    for (final _PlanFormData plan in _plans) {
      plan.dispose();
    }
    super.dispose();
  }

  void _switchStep(int target) {
    if (_currentStep == target) {
      return;
    }
    setState(() => _currentStep = target);
  }

  void _showMessage(String message) {
    _log(message);
    UiUtils.showSoftSnackBar(
      context,
      message: message,
    );
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[WifiCabinRequest] $message');
    } else {
      developer.log(message, name: 'WifiCabinRequest');
    }
  }

  Future<void> _pickLogo() async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) {
      return;
    }
    setState(() {
      _logoFile = file;
    });
  }

  Future<void> _pickLoginScreenshot() async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) {
      return;
    }
    setState(() {
      _loginScreenshotFile = file;
    });
  }

  Future<void> _pickVoucherFile(_PlanFormData plan) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowMultiple: false,
      allowedExtensions: const <String>['csv', 'txt', 'xls', 'xlsx'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    setState(() {
      plan.voucherFile = result.files.first;
    });
  }

  bool _validateAllSteps() {
    final bool networkValid = _validateNetworkStep();
    if (!networkValid) {
      _log('Network form validation failed.');
      _switchStep(0);
      return false;
    }
    final bool plansValid = _plansFormKey.currentState?.validate() ?? false;
    if (!plansValid) {
      _log('Plans form validation failed.');
      _switchStep(1);
      return false;
    }
    return true;
  }

  bool _validateNetworkStep() {
    final List<String> missing = [];
    if (_nameController.text.trim().isEmpty) {
      missing.add('اسم الشبكة');
    }
    if (_logoFile == null) {
      missing.add('شعار الشبكة');
    }
    if (_loginScreenshotFile == null) {
      missing.add('صورة شاشة تسجيل الدخول');
    }
    if (missing.isNotEmpty) {
      final String message = 'أكمل الحقول: ${missing.join('، ')}';
      _showMessage(message);
      return false;
    }
    return true;
  }

  Future<MultipartFile> _multipartFromXFile(XFile file) async {
    return MultipartFile.fromFile(file.path, filename: p.basename(file.path));
  }

  Future<MultipartFile> _multipartFromPlatformFile(PlatformFile file) async {
    if (file.path != null) {
      return MultipartFile.fromFile(file.path!, filename: file.name);
    }
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }
    throw StateError('ملف غير صالح، يرجى إعادة رفعه.');
  }

  String _formatApiHttpError(ApiHttpException error) {
    final dynamic payload = error.payload;
    final String baseMessage =
        (payload?['message'] ?? error.errorMessage ?? error.toString())
            .toString();
    final dynamic errors = payload?['errors'];
    if (errors is Map) {
      final List<String> details = [];
      errors.forEach((_, value) {
        if (value is Iterable) {
          details.addAll(value.map((item) => item?.toString() ?? ''));
        } else if (value != null) {
          details.add(value.toString());
        }
      });
      final String detailMessage = details
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toSet()
          .join('\n');
      if (detailMessage.isNotEmpty) {
        return '$baseMessage\n$detailMessage';
      }
    }
    return baseMessage;
  }

  Future<void> _rollbackIncompleteSubmission({
    WifiNetwork? network,
    List<int> planIds = const <int>[],
  }) async {
    if (network == null) {
      return;
    }
    try {
      await _repository.deleteOwnerNetwork(network.id);
      _log('Rolled back network ${network.id} after submission failure.');
      return;
    } catch (error) {
      _log('Failed to delete network ${network.id}: $error');
    }

    final Set<int> uniquePlanIds = planIds.where((id) => id > 0).toSet();
    for (final int planId in uniquePlanIds) {
      try {
        await _repository.deleteNetworkPlan(planId);
        _log('Deleted plan $planId during rollback.');
      } catch (planError) {
        _log('Failed to delete plan $planId: $planError');
      }
    }
  }

  String _buildBatchLabel(_PlanFormData plan, int index) {
    final String planName =
        plan.name.isNotEmpty ? plan.name : 'Plan ${index + 1}';
    final String fallbackBatch = 'Batch ${index + 1}';
    final String? rawFileName = plan.voucherFile?.name;
    final String fileName = rawFileName?.trim() ?? '';
    final String composedLabel = fileName.isEmpty
        ? '$planName - $fallbackBatch'
        : '$planName - $fileName';
    if (composedLabel.length <= 255) {
      return composedLabel;
    }
    return composedLabel.substring(0, 255);
  }

  Future<void> _submitRequest() async {
    if (!_validateAllSteps()) {
      _log('Submission blocked because validation failed.');
      return;
    }

    final List<Map<String, String>> contacts = _contactFields
        .map((field) => field.asMap())
        .where((contact) => contact['value']?.isNotEmpty ?? false)
        .toList();

    if (contacts.isEmpty) {
      _showMessage('أضف رقم تواصل واحدًا على الأقل.');
      _switchStep(0);
      return;
    }

    if (_plans.any((plan) => plan.voucherFile == null)) {
      _showMessage(
        'يجب رفع ملف الأكواد لكل فئة قبل إرسال الطلب.',
      );
      _switchStep(1);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    WifiNetwork? createdNetwork;
    final List<int> createdPlanIds = <int>[];

    try {
      final MultipartFile? logo =
          _logoFile != null ? await _multipartFromXFile(_logoFile!) : null;
      final MultipartFile? loginScreenshot = _loginScreenshotFile != null
          ? await _multipartFromXFile(_loginScreenshotFile!)
          : null;

      final WifiNetwork network = await _repository.submitOwnerNetworkRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        contacts: contacts,
        logo: logo,
        loginScreenshot: loginScreenshot,
      );
      createdNetwork = network;

      for (int index = 0; index < _plans.length; index++) {
        final _PlanFormData plan = _plans[index];
        final int parsedDuration =
            int.tryParse(plan.durationController.text.trim()) ?? 1;
        final int durationDays = parsedDuration.clamp(1, 365).toInt();

        final double? dataValue =
            double.tryParse(plan.dataController.text.trim());
        double? dataCapGb;
        if (dataValue != null) {
          final double normalized =
              plan.dataUnit == _DataUnit.gb ? dataValue : (dataValue / 1024);
          dataCapGb = double.parse(normalized.toStringAsFixed(4));
        }

        final num price = num.tryParse(plan.priceController.text.trim()) ?? 0;
        final num? speed = num.tryParse(plan.speedController.text.trim());

        final createdPlan = await _repository.createNetworkPlan(
          networkId: network.id,
          name: plan.name,
          description: plan.description,
          durationDays: durationDays,
          price: price,
          currency: 'YER',
          dataCapGb: dataCapGb,
          speedMbps: speed,
          isActive: false,
          meta: <String, dynamic>{
            'source': 'mobile_app',
            'form_step': 'wifi_cabin_onboarding',
          },
        );
        createdPlanIds.add(createdPlan.id);

        final MultipartFile batchFile =
            await _multipartFromPlatformFile(plan.voucherFile!);
        await _repository.createPlanBatch(
          planId: createdPlan.id,
          sourceFile: batchFile,
          label: _buildBatchLabel(plan, index),
          meta: <String, dynamic>{
            'source': 'mobile_app',
            'origin_file': plan.voucherFile?.name,
          },
        );
      }
      _log(
        'تم إرسال طلب شبكة جديدة (${network.id}) بعدد ${_plans.length} فئات.',
      );

      if (!mounted) return;
      final bool? goBack = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم استلام الطلب'),
          content: const Text(
            'سيتم مراجعة الشبكة وسيصلك إشعار عند التفعيل. شكرًا لانضمامك إلى Marib Wi-Fi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إغلاق'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('العودة للشبكات'),
            ),
          ],
        ),
      );
      if (!mounted || goBack != true) {
        _log('اكتملت العملية وبقي المستخدم في نفس الصفحة.');
        return;
      }
      _log('اكتملت العملية وتمت العودة لقائمة الشبكات.');
      Navigator.pop(context, true);
    } catch (error, _) {
      await _rollbackIncompleteSubmission(
        network: createdNetwork,
        planIds: createdPlanIds,
      );
      if (!mounted) return;
      if (error is ApiHttpException) {
        final String serverMessage = _formatApiHttpError(error);
        final dynamic serverErrors = error.payload?['errors'];
        _log(
          'فشل إرسال الطلب [${error.statusCode}] $serverMessage '
          'errors: ${serverErrors ?? 'n/a'}',
        );
        _showMessage(serverMessage);
      } else {
        _log('Failed to submit request: ${error.toString()}');
        _showMessage(ErrorFilter.check(error).error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _addContactField() {
    setState(() {
      _contactFields.add(_ContactFieldData());
    });
  }

  void _removeContactField(int index) {
    if (_contactFields.length == 1) {
      return;
    }
    setState(() {
      _contactFields.removeAt(index).dispose();
    });
  }

  void _addPlan() {
    setState(() {
      _plans.add(_PlanFormData());
    });
  }

  void _removePlan(int index) {
    if (_plans.length == 1) {
      return;
    }
    setState(() {
      _plans.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: 'طلب إضافة شبكة',
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepHeader(currentStep: _currentStep),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _currentStep == 0
                        ? _buildNetworkForm(context)
                        : _buildPlansForm(context),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _switchStep(_currentStep - 1),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            label: const Text('السابق'),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            if (_currentStep == 0) {
                              final valid = _validateNetworkStep();
                              if (valid) {
                                _switchStep(1);
                              }
                            } else {
                              if (_plansFormKey.currentState?.validate() ??
                                  false) {
                                _submitRequest();
                              }
                            }
                          },
                          icon: Icon(_currentStep == 0
                              ? Icons.arrow_forward_ios_rounded
                              : Icons.send_rounded),
                          label: Text(
                            _currentStep == 0 ? 'التالي' : 'إرسال الطلب',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.35),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNetworkForm(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _networkFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بيانات الشبكة',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'املأ التفاصيل كما سترغب في ظهورها للمستخدمين داخل التطبيق ولوحة الواي فاي.',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textLightColor,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: _wifiInputDecoration(
              context,
              'اسم الشبكة',
              hint: 'مثال: شبكة النور',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال اسم الشبكة';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 4,
            decoration: _wifiInputDecoration(
              context,
              'وصف الشبكة (اختياري)',
              hint: 'نبذة عن التغطية، نوع العملاء أو المزايا.',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: _wifiInputDecoration(
              context,
              'ملاحظات داخلية لفريق Marib (اختياري)',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'الملفات المطلوبة',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _FilePickerTile(
            title: 'شعار الشبكة',
            description: 'يظهر داخل التطبيق واللوحة.',
            fileName: _logoFile != null ? p.basename(_logoFile!.path) : null,
            onPick: _pickLogo,
          ),
          const SizedBox(height: 12),
          _FilePickerTile(
            title: 'صورة شاشة تسجيل الدخول',
            description: 'تساعد فريق المراجعة على مطابقة بيانات الشبكة.',
            fileName: _loginScreenshotFile != null
                ? p.basename(_loginScreenshotFile!.path)
                : null,
            onPick: _pickLoginScreenshot,
          ),
          const SizedBox(height: 24),
          Text(
            'قنوات التواصل',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'أضف أرقام الهاتف أو واتساب التي ينبغي التواصل معها أثناء المراجعة والتشغيل.',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textLightColor,
            ),
          ),
          const SizedBox(height: 12),
          ..._contactFields.asMap().entries.map((entry) {
            final int index = entry.key;
            final _ContactFieldData contact = entry.value;
            final bool canRemove = _contactFields.length > 1;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _contactFields.length - 1 ? 0 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'قناة تواصل ${index + 1}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (canRemove)
                        IconButton(
                          onPressed: () => _removeContactField(index),
                          icon: Icon(Icons.close_rounded, color: colors.error),
                          tooltip: 'إزالة هذه القناة',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ContactType>(
                    value: contact.type,
                    decoration: _wifiInputDecoration(context, 'النوع'),
                    items: ContactType.values
                        .map(
                          (type) => DropdownMenuItem<ContactType>(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => contact.type = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: contact.controller,
                    decoration: _wifiInputDecoration(
                      context,
                      'رقم الهاتف / واتساب',
                      hint: '7xxxxxxxx',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _addContactField,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة قناة جديدة'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ملاحظة: تأكد أن القنوات المضافة نشطة حتى يتم قبول الطلب بسرعة.',
            style: textTheme.bodySmall?.copyWith(
              color: colors.textLightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansForm(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _plansFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فئات الأكواد',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف كل فئة مع سعرها وسعتها ثم أرفق ملف الأكواد الخاص بها.',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textLightColor,
            ),
          ),
          const SizedBox(height: 16),
          ..._plans.asMap().entries.map((entry) {
            final int index = entry.key;
            final _PlanFormData plan = entry.value;
            return _PlanCard(
              plan: plan,
              index: index,
              onPickFile: () => _pickVoucherFile(plan),
              onRemove: _plans.length > 1 ? () => _removePlan(index) : null,
            );
          }),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _addPlan,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة فئة جديدة'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'إذا اختلف السعر أو مدة الصلاحية فقم بإنشاء فئة مستقلة لضمان وضوح الخيارات.',
            style: textTheme.bodySmall?.copyWith(
              color: colors.textLightColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    const steps = ['بيانات الشبكة', 'فئات الكروت'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تقدم الطلب',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textDefaultColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: colors.secondaryColor,
            border: Border.all(color: colors.borderColor.withOpacity(.4)),
          ),
          child: Row(
            children: List.generate(steps.length, (index) {
              final bool isActive = index == currentStep;
              final bool isCompleted = index < currentStep;
              final Color stepColor = isActive || isCompleted
                  ? colors.territoryColor
                  : colors.borderColor.withOpacity(.5);
              return Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 28,
                      child: Row(
                        children: [
                          if (index != 0)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: index <= currentStep
                                    ? colors.territoryColor
                                    : colors.borderColor.withOpacity(.3),
                              ),
                            ),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: stepColor,
                            child: isCompleted
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : colors.textDefaultColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          if (index != steps.length - 1)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: index < currentStep
                                    ? colors.territoryColor
                                    : colors.borderColor.withOpacity(.3),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      steps[index],
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive
                            ? colors.textDefaultColor
                            : colors.textLightColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.index,
    required this.onPickFile,
    this.onRemove,
  });

  final _PlanFormData plan;
  final int index;
  final Future<void> Function() onPickFile;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index != 0) const Divider(height: 32),
        Row(
          children: [
            Text(
              'فئة ${index + 1}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                tooltip: 'حذف الفئة',
                icon: Icon(Icons.delete_outline, color: colors.error),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: plan.nameController,
          decoration: _wifiInputDecoration(
            context,
            'اسم الفئة',
            hint: 'مثال: باقة يومية أو باقة 5 جيجا',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'أدخل اسم الفئة';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: plan.priceController,
          decoration: _wifiInputDecoration(
            context,
            'السعر',
            hint: 'بالريال اليمني',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            final num? parsed = num.tryParse(value ?? '');
            if (parsed == null || parsed <= 0) {
              return 'أدخل سعرًا صالحًا';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: plan.durationController,
                decoration: _wifiInputDecoration(
                  context,
                  'مدة الصلاحية (أيام)',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final int? parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'أدخل عدد الأيام';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: plan.speedController,
                decoration: _wifiInputDecoration(
                  context,
                  'السرعة (Mbps) - اختياري',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: plan.dataController,
                decoration: _wifiInputDecoration(
                  context,
                  'سعة البيانات',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<_DataUnit>(
                value: plan.dataUnit,
                decoration: _wifiInputDecoration(context, 'الوحدة'),
                onChanged: (value) {
                  if (value != null) {
                    plan.dataUnit = value;
                  }
                },
                items: _DataUnit.values
                    .map(
                      (unit) => DropdownMenuItem<_DataUnit>(
                        value: unit,
                        child: Text(unit.label),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: plan.descriptionController,
          minLines: 2,
          maxLines: 3,
          decoration: _wifiInputDecoration(
            context,
            'وصف الفئة (اختياري)',
            hint: 'اكتب تفاصيل إضافية تساعد المستخدم على اختيار الخطة.',
          ),
        ),
        const SizedBox(height: 12),
        FormField<PlatformFile?>(
          validator: (_) {
            if (plan.voucherFile == null) {
              return 'يرجى رفع ملف الأكواد';
            }
            return null;
          },
          builder: (state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilePickerTile(
                  title: 'ملف الأكواد',
                  description: 'CSV أو XLSX يحتوي على الأكواد لهذه الفئة.',
                  fileName: plan.voucherFile?.name,
                  onPick: () async {
                    await Future<void>.sync(onPickFile);
                    state.didChange(plan.voucherFile);
                  },
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(
                        color: colors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ContactFieldData {
  _ContactFieldData({ContactType initialType = ContactType.phone})
      : controller = TextEditingController(),
        type = initialType;

  final TextEditingController controller;
  ContactType type;

  void dispose() {
    controller.dispose();
  }

  Map<String, String> asMap() {
    return {
      'type': type.apiValue,
      'value': controller.text.trim(),
    };
  }
}

enum ContactType { phone, whatsapp, other }

extension on ContactType {
  String get label {
    switch (this) {
      case ContactType.phone:
        return 'هاتف';
      case ContactType.whatsapp:
        return 'واتساب';
      case ContactType.other:
        return 'أخرى';
    }
  }

  String get apiValue {
    switch (this) {
      case ContactType.phone:
        return 'phone';
      case ContactType.whatsapp:
        return 'whatsapp';
      case ContactType.other:
        return 'other';
    }
  }
}

class _PlanFormData {
  _PlanFormData()
      : nameController = TextEditingController(),
        priceController = TextEditingController(),
        dataController = TextEditingController(),
        durationController = TextEditingController(),
        speedController = TextEditingController(),
        descriptionController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController dataController;
  final TextEditingController durationController;
  final TextEditingController speedController;
  final TextEditingController descriptionController;

  PlatformFile? voucherFile;
  _DataUnit dataUnit = _DataUnit.gb;

  String get name => nameController.text.trim();
  String? get description => descriptionController.text.trim().isEmpty
      ? null
      : descriptionController.text.trim();

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    dataController.dispose();
    durationController.dispose();
    speedController.dispose();
    descriptionController.dispose();
  }
}

enum _DataUnit { mb, gb }

extension on _DataUnit {
  String get label => this == _DataUnit.gb ? 'جيجابايت' : 'ميجابايت';
}

class _FilePickerTile extends StatelessWidget {
  const _FilePickerTile({
    required this.title,
    required this.description,
    required this.onPick,
    this.fileName,
  });

  final String title;
  final String description;
  final String? fileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;
    final bool hasFile = fileName != null && fileName!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textDefaultColor,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                hasFile ? fileName! : description,
                style: textTheme.bodySmall?.copyWith(
                  color:
                      hasFile ? colors.territoryColor : colors.textLightColor,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onPick,
              icon: Icon(
                hasFile ? Icons.edit_outlined : Icons.upload_file_rounded,
              ),
              label: Text(hasFile ? 'تغيير' : 'اختيار'),
            ),
          ],
        ),
      ],
    );
  }
}

InputDecoration _wifiInputDecoration(
  BuildContext context,
  String label, {
  String? hint,
  String? helper,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final colors = context.color;
  final OutlineInputBorder baseBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: colors.borderColor.withOpacity(.4)),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: colors.secondaryColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: baseBorder,
    enabledBorder: baseBorder,
    focusedBorder: baseBorder.copyWith(
      borderSide: BorderSide(color: colors.territoryColor, width: 1.6),
    ),
  );
}
