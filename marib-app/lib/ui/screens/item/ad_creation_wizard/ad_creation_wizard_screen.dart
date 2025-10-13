import 'dart:async';

import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'models/custom_field_schema.dart';
import 'services/category_inventory_service.dart';
import 'widgets/dynamic_custom_fields_form.dart';
import 'package:flutter/material.dart';




/// Simplified ad creation wizard showcasing a multi-step flow with
/// progress indicator, navigation guards and auto-save hooks.
class AdCreationWizardScreen extends StatefulWidget {
  const AdCreationWizardScreen({super.key});

  static Route<void> route(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const AdCreationWizardScreen(),
      settings: settings,
    );
  }

  @override
  State<AdCreationWizardScreen> createState() => _AdCreationWizardScreenState();
}

class _AdCreationWizardScreenState extends State<AdCreationWizardScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final List<_WizardStep> _steps = const <_WizardStep>[
    _WizardStep(label: 'الفئة الرئيسية'),
    _WizardStep(label: 'الفئة الفرعية'),
    _WizardStep(label: 'الحقول المخصّصة'),
    _WizardStep(label: 'الوسائط'),
    _WizardStep(label: 'التفاصيل النصية'),
    _WizardStep(label: 'الخريطة / إدارة المنتج'),
    _WizardStep(label: 'المراجعة النهائية'),
  ];

  final CategoryInventoryService _inventoryService = CategoryInventoryService();
  final AdPublishingService _adPublishingService = AdPublishingService();
  final List<_MainCategoryOption> _mainCategories = <_MainCategoryOption>[
    _MainCategoryOption(
      id: 1,
      name: 'إعلانات عامة',
      interfaceType: 'public_ads',
      subCategories: const <_SubCategoryOption>[
        const _SubCategoryOption(id: 101, name: 'سيارات للبيع'),
        const _SubCategoryOption(id: 102, name: 'عقارات للإيجار'),
      ],
    ),
    _MainCategoryOption(
      id: 2,
      name: 'الخدمات',
      interfaceType: 'services',
      subCategories: const <_SubCategoryOption>[
        const _SubCategoryOption(id: 201, name: 'خدمات الصيانة'),
        const _SubCategoryOption(id: 202, name: 'استشارات الأعمال'),
      ],
    ),
  ];
  final GlobalKey<DynamicCustomFieldsFormState> _customFieldsFormKey =
  GlobalKey<DynamicCustomFieldsFormState>();
  final Map<String, List<CustomFieldSchema>> _customFieldSchemaCache =
  <String, List<CustomFieldSchema>>{};
  _MainCategoryOption? _selectedMainCategory;
  _SubCategoryOption? _selectedSubCategory;
  List<CustomFieldSchema> _customFieldSchemas = const <CustomFieldSchema>[];
  Map<String, dynamic> _customFieldValues = <String, dynamic>{};
  bool _isLoadingCustomFields = false;
  String? _customFieldError;
  bool _isPublishing = false;

  Timer? _autoSaveTimer;
  int _currentStep = 0;
  bool _hasUnsavedChanges = false;
  bool _isSavingDraft = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markDirty);
    _descriptionController.addListener(_markDirty);
    _contactController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _markDirty() {
    _hasUnsavedChanges = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), _autoSaveDraft);
  }

  Future<void> _autoSaveDraft() async {
    if (!_hasUnsavedChanges || _isSavingDraft) {
      return;
    }
    setState(() => _isSavingDraft = true);
    try {
      final Map<String, dynamic> payload = _buildAdPayload(isDraft: true);
      await _adPublishingService.saveDraft(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasUnsavedChanges = false;
      });
    } catch (error) {
      if (mounted) {
        _showMessage('تعذّر حفظ المسودة: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDraft = false);
      }
    }

  }

  void _goNext() {
    if (_currentStep >= _steps.length - 1) {
      return;
    }
    if (_currentStep == 0 && _selectedMainCategory == null) {
      _showMessage('يرجى اختيار الفئة الرئيسية قبل المتابعة.');
      return;
    }
    if (_currentStep == 1 && _selectedSubCategory == null) {
      _showMessage('يرجى اختيار الفئة الفرعية قبل المتابعة.');
      return;
    }
    if (_currentStep == 2) {
      final bool valid = _customFieldsFormKey.currentState?.validate() ?? true;
      if (!valid) {
        _showMessage('يرجى إكمال الحقول المخصّصة المطلوبة قبل المتابعة.');
        return;
      }
    }
    if (_currentStep == 4 && _titleController.text.trim().isEmpty) {
      _showMessage('يرجى إدخال عنوان للإعلان قبل المتابعة.');
      return;
    }
    setState(() => _currentStep += 1);
  }

  void _goPrevious() {
    if (_currentStep == 0) {
      return;
    }
    setState(() => _currentStep -= 1);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_currentStep + 1) / _steps.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('معالج إنشاء إعلان'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < _steps.length; i++)
                      _StepChip(
                        label: _steps[i].label,
                        index: i,
                        isCurrent: i == _currentStep,
                        isCompleted: i < _currentStep,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildStepBody()),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16.0, 12.0, 16.0, 12.0 + MediaQuery.of(context).viewPadding.bottom,
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSavingDraft ? null : _autoSaveDraft,
                    child: _isSavingDraft
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('حفظ كمسودة'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('إلغاء'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentStep == 0 ? null : _goPrevious,
                    child: const Text('رجوع'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                    _isPublishing ? null : (_currentStep == _steps.length - 1 ? _publishAd : _goNext),
                    child: _currentStep == _steps.length - 1
                        ? (_isPublishing
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('نشر'))
                        : const Text('التالي'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_currentStep) {
      case 0:
        return _buildMainCategoryStep();
      case 1:
        return _buildSubCategoryStep();
      case 2:
        return _buildCustomFieldsStep();
      case 3:
        return const Center(child: Text('ارفع صورك أو فيديو الإعلان.'));

      case 4:
        return _buildTextDetailsStep();
      case 5:
        return const Center(child: Text('حدد الموقع أو أضف بيانات المخزون.'));
      case 6:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMainCategoryStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('اختر الفئة الرئيسية للإعلان. يمكن تعديل هذا الاختيار لاحقًا.'),
        const SizedBox(height: 12),
        for (final _MainCategoryOption category in _mainCategories)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<_MainCategoryOption>(
              value: category,
              groupValue: _selectedMainCategory,
              title: Text(category.name),
              subtitle: Text('واجهة العرض: ${category.interfaceType}'),
              onChanged: (value) {
                if (value == null) return;
                _onMainCategorySelected(value);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSubCategoryStep() {
    final _MainCategoryOption? mainCategory = _selectedMainCategory;
    if (mainCategory == null) {
      return _buildPlaceholderMessage('يرجى اختيار الفئة الرئيسية أولًا لمتابعة اختيار الفئة الفرعية.');
    }

    final List<_SubCategoryOption> subCategories = mainCategory.subCategories;
    if (subCategories.isEmpty) {
      return _buildPlaceholderMessage('لا توجد فئات فرعية متاحة لهذه الفئة.');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('اختر الفئة الفرعية المناسبة لإعلانك ضمن ${mainCategory.name}.'),
        const SizedBox(height: 12),
        for (final _SubCategoryOption subCategory in subCategories)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<_SubCategoryOption>(
              value: subCategory,
              groupValue: _selectedSubCategory,
              title: Text(subCategory.name),
              onChanged: (value) {
                if (value == null) return;
                _onSubCategorySelected(value);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCustomFieldsStep() {
    final _MainCategoryOption? mainCategory = _selectedMainCategory;
    final _SubCategoryOption? subCategory = _selectedSubCategory;



    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('املأ الحقول المخصّصة المرتبطة بالفئة الفرعية المختارة.'),
        const SizedBox(height: 12),
        if (mainCategory == null)
          _buildInfoCard('يرجى اختيار الفئة الرئيسية قبل الانتقال إلى الحقول المخصّصة.')
        else if (subCategory == null)
          _buildInfoCard('يرجى اختيار الفئة الفرعية لمتابعة الحقول المخصّصة.')
        else if (_isLoadingCustomFields)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ))
          else if (_customFieldError != null)
              _buildErrorCard(
                message: 'تعذّر تحميل الحقول المخصّصة. حاول مجددًا.',
                onRetry: _fetchCustomFieldSchema,
              )
            else
              DynamicCustomFieldsForm(
                key: _customFieldsFormKey,
                fields: _customFieldSchemas,
                values: Map<String, dynamic>.unmodifiable(_customFieldValues),
                onChanged: (Map<String, dynamic> values) {
                  setState(() {
                    _customFieldValues = values;
                  });
                  _markDirty();
                },
              ),
      ],
    );
  }


  void _onMainCategorySelected(_MainCategoryOption category) {
    if (_selectedMainCategory?.id == category.id) {
      return;
    }
    setState(() {
      _selectedMainCategory = category;
      _selectedSubCategory = null;
      _customFieldSchemas = const <CustomFieldSchema>[];
      _customFieldValues = <String, dynamic>{};
      _customFieldError = null;
      _isLoadingCustomFields = false;
    });
    _customFieldsFormKey.currentState?.clearValidationErrors();
    _markDirty();
  }

  void _onSubCategorySelected(_SubCategoryOption subCategory) {
    if (_selectedSubCategory?.id == subCategory.id) {
      return;
    }
    setState(() {
      _selectedSubCategory = subCategory;
      _customFieldValues = <String, dynamic>{};
      _customFieldError = null;
    });
    _customFieldsFormKey.currentState?.clearValidationErrors();
    _markDirty();
    _fetchCustomFieldSchema();
  }

  Future<void> _fetchCustomFieldSchema() async {
    final _MainCategoryOption? mainCategory = _selectedMainCategory;
    final _SubCategoryOption? subCategory = _selectedSubCategory;
    if (mainCategory == null || subCategory == null) {
      return;
    }

    final String cacheKey = '${mainCategory.interfaceType}:${subCategory.id}';
    final List<CustomFieldSchema>? cached = _customFieldSchemaCache[cacheKey];
    if (cached != null) {
      _applyCustomFieldSchema(cached);
      return;
    }

    setState(() {
      _isLoadingCustomFields = true;
      _customFieldError = null;
      _customFieldSchemas = const <CustomFieldSchema>[];
    });

    try {
      final List<CustomFieldSchema> fields = await _inventoryService.fetchCustomFieldSchema(
        interfaceType: mainCategory.interfaceType,
        categoryId: subCategory.id,
      );
      if (!mounted) {
        return;
      }
      _customFieldSchemaCache[cacheKey] = fields;
      _applyCustomFieldSchema(fields);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _customFieldError = error.toString();
        _customFieldSchemas = const <CustomFieldSchema>[];
        _isLoadingCustomFields = false;
      });
    }
  }

  void _applyCustomFieldSchema(List<CustomFieldSchema> fields) {
    final Map<String, dynamic> previousValues = Map<String, dynamic>.from(_customFieldValues);
    setState(() {
      _customFieldSchemas = fields;
      _customFieldError = null;
      _isLoadingCustomFields = false;
      final Set<String> allowed = fields.map((CustomFieldSchema f) => f.id).toSet();
      _customFieldValues = <String, dynamic>{
        for (final MapEntry<String, dynamic> entry in previousValues.entries)
          if (allowed.contains(entry.key)) entry.key: entry.value,
      };
    });
    if (_customFieldValues.length != previousValues.length) {
      _markDirty();
    }
    _customFieldsFormKey.currentState?.clearValidationErrors();
  }

  Widget _buildPlaceholderMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildInfoCard(String message) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  Widget _buildErrorCard({required String message, required VoidCallback onRetry}) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildAdPayload({required bool isDraft}) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'interface_type': _selectedMainCategory?.interfaceType,
      'main_category_id': _selectedMainCategory?.id,
      'sub_category_id': _selectedSubCategory?.id,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'contact': _contactController.text.trim(),
      'status': isDraft ? 'draft' : 'pending',
      'has_custom_fields': _customFieldSchemas.isNotEmpty,
    };

    if (_customFieldValues.isNotEmpty) {
      payload['custom_fields'] = Map<String, dynamic>.from(_customFieldValues);
    }

    payload.removeWhere((String key, dynamic value) {
      if (value == null) {
        return true;
      }
      if (value is String) {
        return value.trim().isEmpty;
      }
      if (value is Map && value.isEmpty) {
        return true;
      }
      return false;
    });

    return payload;
  }

  Future<void> _publishAd() async {
    if (_selectedMainCategory == null) {
      _showMessage('يرجى اختيار الفئة الرئيسية قبل النشر.');
      return;
    }
    if (_selectedSubCategory == null) {
      _showMessage('يرجى اختيار الفئة الفرعية قبل النشر.');
      return;
    }
    if (_customFieldSchemas.isNotEmpty) {
      final bool valid = _customFieldsFormKey.currentState?.validate() ?? true;
      if (!valid) {
        _showMessage('يرجى إكمال الحقول المخصّصة المطلوبة قبل النشر.');
        return;
      }
    }
    if (_titleController.text.trim().isEmpty) {
      _showMessage('يرجى إدخال عنوان الإعلان قبل النشر.');
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final Map<String, dynamic> payload = _buildAdPayload(isDraft: false);
      await _adPublishingService.publish(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasUnsavedChanges = false;
      });
      _showMessage('تم إرسال الإعلان للنشر بنجاح.');
    } catch (error) {
      if (mounted) {
        _showMessage('تعذّر نشر الإعلان: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }


  Widget _buildTextDetailsStep() {

    final ThemeData theme = Theme.of(context);
    final List<Widget> customFieldWidgets = <Widget>[];
    for (final CustomFieldSchema field in _customFieldSchemas) {
      final dynamic value = _customFieldValues[field.id];
      final String displayValue = field.formatValue(value).isEmpty ? 'غير محدد' : field.formatValue(value);
      customFieldWidgets
        ..add(Text(
          field.label,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ))
        ..add(const SizedBox(height: 4))
        ..add(Text(displayValue))
        ..add(const SizedBox(height: 12));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('الفئة الرئيسية: ${_selectedMainCategory?.name ?? 'غير محدد'}'),
        const SizedBox(height: 8),
        Text('الفئة الفرعية: ${_selectedSubCategory?.name ?? 'غير محدد'}'),
        const SizedBox(height: 8),
        Text('واجهة العرض: ${_selectedMainCategory?.interfaceType ?? 'غير محدد'}'),
        const Divider(height: 32),
        Text('الحقول المخصّصة', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (customFieldWidgets.isEmpty)
          Text('لا توجد قيم محفوظة للحقول المخصّصة.', style: theme.textTheme.bodySmall)
        else
          ...customFieldWidgets,
        const Divider(height: 32),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'عنوان الإعلان',
            helperText: '10 - 90 حرفًا',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'الوصف التفصيلي',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contactController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'رقم التواصل',
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('العنوان: ${_titleController.text}'),
        const SizedBox(height: 8),
        Text('الوصف: ${_descriptionController.text}'),
        const SizedBox(height: 8),
        Text('التواصل: ${_contactController.text}'),
      ],
    );
  }
}

class _WizardStep {
  const _WizardStep({required this.label});
  final String label;
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.index,
    required this.isCurrent,
    required this.isCompleted,
  });

  final String label;
  final int index;
  final bool isCurrent;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.color;
    final Color background = isCurrent
        ? colors.territoryColor.withOpacity(0.14)
        : colors.secondaryColor;
    final Color border = isCompleted
        ? colors.territoryColor
        : colors.borderColor.withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor:
            isCompleted ? colors.territoryColor : Colors.transparent,
            child: isCompleted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('${index + 1}',
                style: TextStyle(color: colors.textDefaultColor)),
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MainCategoryOption {
  const _MainCategoryOption({
    required this.id,
    required this.name,
    required this.interfaceType,
    this.subCategories = const <_SubCategoryOption>[],
  });

  final int id;
  final String name;
  final String interfaceType;
  final List<_SubCategoryOption> subCategories;
}

class _SubCategoryOption {
  const _SubCategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}