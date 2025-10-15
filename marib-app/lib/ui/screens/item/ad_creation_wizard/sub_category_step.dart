import 'package:flutter/material.dart';

import 'ad_creation_wizard_models.dart';

class SubCategoryStep extends StatelessWidget {
  const SubCategoryStep({
    super.key,
    required this.controller,
    this.onNext,
    this.onBack,
    this.onDraftChanged,
  });

  final AdCreationWizardController controller;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onDraftChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final WizardCategory? mainCategory = controller.selectedMainCategory;
        final List<WizardCategory> subCategories = controller.visibleSubCategories;
        final WizardCategory? selectedSub = controller.selectedSubCategory;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'رجوع',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    mainCategory == null
                        ? 'اختر فئة رئيسية أولاً'
                        : 'الفئة الرئيسية: ${mainCategory.name}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: subCategories.isEmpty
                  ? Center(
                child: Text(
                  mainCategory == null
                      ? 'يرجى اختيار فئة رئيسية للمتابعة.'
                      : 'لا توجد فئات فرعية متاحة لهذه الفئة.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
                  : ListView.separated(
                itemBuilder: (BuildContext context, int index) {
                  final WizardCategory category = subCategories[index];
                  return Card(
                    child: RadioListTile<int>(
                      value: category.id,
                      groupValue: selectedSub?.id,
                      title: Text(category.name),
                      onChanged: (_) {
                        controller.selectSubCategory(category);
                        onDraftChanged?.call();
                        onNext?.call();
                      },
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: subCategories.length,
              ),
            ),
            if (selectedSub != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: () {
                    onDraftChanged?.call();
                    onNext?.call();
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('متابعة'),
                ),
              ),
          ],
        );
      },
    );
  }
}