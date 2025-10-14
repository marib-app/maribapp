part of 'ad_creation_wizard_screen.dart';

extension _SubCategoryStepView on _AdCreationWizardScreenState {
  Widget _buildSubCategoryStep() => _SubCategoryStepContent(screen: this);
}

class _SubCategoryStepContent extends StatelessWidget {
  const _SubCategoryStepContent({required this.screen});

  final _AdCreationWizardScreenState screen;

  @override
  Widget build(BuildContext context) {
    final _MainCategoryOption? mainCategory = screen._selectedMainCategory;
    if (mainCategory == null) {
      return screen._buildPlaceholderMessage(
          'يرجى اختيار الفئة الرئيسية أولًا لمتابعة اختيار الفئة الفرعية.');
    }

    final List<_SubCategoryOption> subCategories = mainCategory.subCategories;
    if (subCategories.isEmpty) {
      return screen
          ._buildPlaceholderMessage('لا توجد فئات فرعية متاحة لهذه الفئة.');
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
              groupValue: screen._selectedSubCategory,
              title: Text(subCategory.name),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                screen._onSubCategorySelected(value);
              },
            ),
          ),
      ],
    );
  }
}