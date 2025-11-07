import 'dart:async';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
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
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();

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
  bool _slugManuallyEdited = false;
  bool _isUpdatingSlug = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
    _slugController.addListener(_handleSlugEdited);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    _slugController
      ..removeListener(_handleSlugEdited)
      ..dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    for (final _ContactFieldData contact in _contactFields) {
      contact.dispose();
    }
    for (final _PlanFormData plan in _plans) {
      plan.dispose();
    }
    super.dispose();
  }

  void _handleNameChanged() {
    if (_slugManuallyEdited) {
      return;
    }
    _isUpdatingSlug = true;
    final String slug = _generateSlug(_nameController.text);
    _slugController.text = slug;
    _slugController.selection = TextSelection.fromPosition(
      TextPosition(offset: slug.length),
    );
    _isUpdatingSlug = false;
  }

  void _handleSlugEdited() {
    if (_isUpdatingSlug) {
      return;
    }
    _slugManuallyEdited = true;
  }

  String _generateSlug(String value) {
    final String trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }
    final String sanitized =
        trimmed.replaceAll(RegExp(r'[^a-z0-9\\s-]'), '').replaceAll(' ', '-');
    return sanitized.replaceAll(RegExp('-+'), '-');
  }

  void _switchStep(int target) {
    if (_currentStep == target) {
      return;
    }
    setState(() => _currentStep = target);
  }

  void _showMessage(String message) {
    UiUtils.showSoftSnackBar(
      context,
      message: message,
    );
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
      allowedExtensions: const <String>['csv', 'xls', 'xlsx'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    setState(() {
      plan.voucherFile = result.files.first;
    });
  }

  bool _validateAllSteps() {
    final bool networkValid = _networkFormKey.currentState?.validate() ?? false;
    if (!networkValid) {
      _switchStep(0);
      return false;
    }
    final bool plansValid = _plansFormKey.currentState?.validate() ?? false;
    if (!plansValid) {
      _switchStep(1);
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

  Future<void> _submitRequest() async {
    if (!_validateAllSteps()) {
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

    try {
      final double? latitude = double.tryParse(_latitudeController.text.trim());
      final double? longitude =
          double.tryParse(_longitudeController.text.trim());
      final double? coverage = double.tryParse(_radiusController.text.trim());

      final MultipartFile? logo =
          _logoFile != null ? await _multipartFromXFile(_logoFile!) : null;
      final MultipartFile? loginScreenshot = _loginScreenshotFile != null
          ? await _multipartFromXFile(_loginScreenshotFile!)
          : null;

      final network = await _repository.submitOwnerNetworkRequest(
        name: _nameController.text.trim(),
        slug: _slugController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        coverageRadiusKm: coverage,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
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

      for (final _PlanFormData plan in _plans) {
        final int durationDays =
            int.tryParse(plan.durationController.text.trim()) ?? 1;
        final int durationMinutes = durationDays * 24 * 60;

        final double? dataValue =
            double.tryParse(plan.dataController.text.trim());
        int? dataAllowanceMb;
        if (dataValue != null) {
          dataAllowanceMb = plan.dataUnit == _DataUnit.gb
              ? (dataValue * 1024).round()
              : dataValue.round();
        }

        final num price = num.tryParse(plan.priceController.text.trim()) ?? 0;
        final num? speed = num.tryParse(plan.speedController.text.trim());

        final createdPlan = await _repository.createNetworkPlan(
          networkId: network.id,
          name: plan.name,
          description: plan.description,
          durationMinutes: durationMinutes,
          price: price,
          currency: 'YER',
          dataAllowanceMb: dataAllowanceMb,
          validityDays: durationDays,
          speedMbps: speed,
          isActive: false,
        );

        final MultipartFile batchFile =
            await _multipartFromPlatformFile(plan.voucherFile!);
        await _repository.createPlanBatch(
          planId: createdPlan.id,
          file: batchFile,
        );
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم استلام الطلب'),
          content: const Text(
            'سيتم مراجعة الشبكة وسيصلك إشعار عند التفعيل. شكرًا لانضمامك إلى Marib Wi-Fi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(ErrorFilter.check(error).error);
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
                          child: OutlinedButton(
                            onPressed: () => _switchStep(_currentStep - 1),
                            child: const Text('السابق'),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentStep == 0) {
                              final valid =
                                  _networkFormKey.currentState?.validate() ??
                                      false;
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
                          child: Text(
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
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _networkFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بيانات الشبكة',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'اسم الشبكة',
            child: TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال اسم الشبكة';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'الاسم المختصر (Slug)',
            helper:
                'يُستخدم في روابط لوحة التحكم والتكامل. يتم توليده تلقائيًا ويمكنك تعديله.',
            child: TextFormField(
              controller: _slugController,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'يرجى إدخال الاسم المختصر';
                }
                if (!RegExp(r'^[a-z0-9-]+$').hasMatch(text)) {
                  return 'مسموح بالأحرف الإنجليزية، الأرقام، والشرطات فقط';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          _FilePickerTile(
            title: 'شعار الشبكة',
            description: 'يظهر داخل التطبيق واللوحة.',
            fileName: _logoFile != null ? p.basename(_logoFile!.path) : null,
            onPick: _pickLogo,
          ),
          const SizedBox(height: 12),
          _FilePickerTile(
            title: 'صورة شاشة تسجيل الدخول',
            description: 'لمساعدة فريق المراجعة على ضبط معلومات الشبكة.',
            fileName: _loginScreenshotFile != null
                ? p.basename(_loginScreenshotFile!.path)
                : null,
            onPick: _pickLoginScreenshot,
          ),
          const SizedBox(height: 16),
          Text(
            'الموقع والتغطية',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latitudeController,
                  decoration: const InputDecoration(labelText: 'خط العرض'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _longitudeController,
                  decoration: const InputDecoration(labelText: 'خط الطول'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _radiusController,
                  decoration:
                      const InputDecoration(labelText: 'نصف القطر (كم)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'العنوان التفصيلي',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'وصف الشبكة (اختياري)',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات إضافية (اختياري)',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'أرقام التواصل',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Column(
            children: _contactFields.asMap().entries.map((entry) {
              final index = entry.key;
              final _ContactFieldData contact = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<ContactType>(
                        value: contact.type,
                        decoration: const InputDecoration(labelText: 'النوع'),
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: contact.controller,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف / واتساب',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'أدخل الرقم أو قم بحذفه';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removeContactField(index),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _addContactField,
              icon: const Icon(Icons.add),
              label: const Text('إضافة رقم آخر'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansForm(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _plansFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فئات الكروت',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._plans.asMap().entries.map((entry) {
            final index = entry.key;
            final _PlanFormData data = entry.value;
            return _PlanCard(
              plan: data,
              index: index,
              onPickFile: () => _pickVoucherFile(data),
              onRemove: _plans.length == 1 ? null : () => _removePlan(index),
            );
          }),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _addPlan,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('إضافة فئة أخرى'),
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

    return Row(
      children: List.generate(steps.length, (index) {
        final bool isActive = index == currentStep;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isActive
                    ? colors.territoryColor
                    : colors.borderColor.withOpacity(.4),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.white : colors.textDefaultColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[index],
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.helper,
  });

  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(helper!, style: textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        child,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderColor.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'فئة ${index + 1}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.delete_outline, color: colors.error),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: plan.nameController,
            decoration: const InputDecoration(labelText: 'اسم الفئة'),
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
            decoration: const InputDecoration(
              labelText: 'السعر (ريال يمني)',
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
                  decoration:
                      const InputDecoration(labelText: 'مدة الصلاحية (أيام)'),
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
                  decoration: const InputDecoration(
                    labelText: 'السرعة (Mbps) - اختياري',
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
                  decoration: const InputDecoration(
                    labelText: 'سعة البيانات',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<_DataUnit>(
                  value: plan.dataUnit,
                  decoration: const InputDecoration(labelText: 'الوحدة'),
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
            decoration: const InputDecoration(
              labelText: 'وصف الفئة (اختياري)',
            ),
            maxLines: 2,
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
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Future<void>.sync(onPickFile);
                      state.didChange(plan.voucherFile);
                    },
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      plan.voucherFile?.name ?? 'رفع ملف الأكواد (CSV / XLSX)',
                    ),
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
      ),
    );
  }
}

class _ContactFieldData {
  _ContactFieldData({this.type = ContactType.phone})
      : controller = TextEditingController();

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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor.withOpacity(.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fileName ?? description,
                  style: textTheme.bodySmall?.copyWith(
                    color: fileName == null
                        ? colors.textLightColor
                        : colors.territoryColor,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.attach_file),
            label: Text(fileName == null ? 'اختيار' : 'تغيير'),
          ),
        ],
      ),
    );
  }
}
