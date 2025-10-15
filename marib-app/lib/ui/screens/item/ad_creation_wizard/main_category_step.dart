import 'package:flutter/material.dart';

import 'ad_creation_wizard_models.dart';

class MainCategoryStep extends StatelessWidget {
  const MainCategoryStep({
    super.key,
    required this.controller,
    this.onNext,
    this.onDraftChanged,
  });

  final AdCreationWizardController controller;
  final VoidCallback? onNext;
  final VoidCallback? onDraftChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final List<WizardCategory> categories = controller.mainCategories;
        final WizardCategory? selected = controller.selectedMainCategory;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('اختر الفئة الرئيسية', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: categories.isEmpty
                  ? Center(
                child: Text(
                  'لا توجد فئات متاحة.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
                  : ListView.builder(
                itemCount: categories.length,
                itemBuilder: (BuildContext context, int index) {
                  final WizardCategory category = categories[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: RadioListTile<int>(
                      value: category.id,
                      groupValue: selected?.id,
                      title: Text(category.name, style: theme.textTheme.bodyLarge),
                      subtitle: category.children.isEmpty
                          ? null
                          : Text(
                        '${category.children.length} فئات فرعية',
                        style: theme.textTheme.bodySmall,
                      ),
                      onChanged: (_) {
                        controller.selectMainCategory(category);
                        onDraftChanged?.call();
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: selected == null
                    ? null
                    : () {
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