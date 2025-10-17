part of 'ad_creation_wizard_screen.dart';

extension _CustomFieldsStepView on _AdCreationWizardScreenState {
  Widget _buildCustomFieldsStep() => _CustomFieldsStepContent(screen: this);
}

class _CustomFieldsStepContent extends StatelessWidget {
  const _CustomFieldsStepContent({required this.screen});

  final _AdCreationWizardScreenState screen;

  @override
  Widget build(BuildContext context) {
    final _MainCategoryOption? mainCategory = screen._selectedMainCategory;
    final _SubCategoryOption? subCategory = screen._selectedSubCategory;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('املأ الحقول المخصّصة المرتبطة بالفئة الفرعية المختارة.'),
        const SizedBox(height: 12),
        if (mainCategory == null)
          screen._buildInfoCard(
              'يرجى اختيار الفئة الرئيسية قبل الانتقال إلى الحقول المخصّصة.')
        else if (subCategory == null)
          screen._buildInfoCard('يرجى اختيار الفئة الفرعية لمتابعة الحقول المخصّصة.')
        else if (screen._isLoadingCustomFields)
            const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ))
          else if (screen._customFieldError != null)
              screen._buildErrorCard(
                message: 'تعذّر تحميل الحقول المخصّصة. حاول مجددًا.',
                onRetry: screen._fetchCustomFieldSchema,
              )
            else
              DynamicCustomFieldsForm(
                key: screen._customFieldsFormKey,
                fields: screen._customFieldSchemas,
                values: Map<String, dynamic>.unmodifiable(screen._customFieldValues),
                onChanged: (Map<String, dynamic> values) {
                  screen.setState(() {
                    screen._customFieldValues = values;
                  });
                  screen._markDirty();
                },
              ),
      ],
    );
  }
}