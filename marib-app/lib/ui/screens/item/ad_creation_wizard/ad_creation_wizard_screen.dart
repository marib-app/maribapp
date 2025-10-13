import 'dart:async';

import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

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
    _WizardStep(label: 'الوسائط'),
    _WizardStep(label: 'التفاصيل النصية'),
    _WizardStep(label: 'الخريطة / إدارة المنتج'),
    _WizardStep(label: 'المراجعة النهائية'),
  ];

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
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) {
      return;
    }
    setState(() {
      _hasUnsavedChanges = false;
      _isSavingDraft = false;
    });
  }

  void _goNext() {
    if (_currentStep >= _steps.length - 1) {
      return;
    }
    if (_currentStep == 3 && _titleController.text.trim().isEmpty) {
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
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + context.mediaQuery.viewPadding.bottom),
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
                    onPressed: _goNext,
                    child: Text(
                      _currentStep == _steps.length - 1 ? 'نشر' : 'التالي',
                    ),
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
        return const Center(child: Text('ارفع صورك أو فيديو الإعلان.'));
      case 3:
        return _buildTextDetailsStep();
      case 4:
        return const Center(child: Text('حدد الموقع أو أضف بيانات المخزون.'));
      case 5:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMainCategoryStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('اختر الفئة الرئيسية للإعلان. يمكن تعديل هذا الاختيار لاحقًا.'),
      ],
    );
  }

  Widget _buildSubCategoryStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('اختر الفئة الفرعية المناسبة لإعلانك.'),
      ],
    );
  }

  Widget _buildTextDetailsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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