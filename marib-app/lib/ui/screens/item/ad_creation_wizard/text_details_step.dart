part of 'ad_creation_wizard_screen.dart';

extension _TextDetailsStepView on _AdCreationWizardScreenState {
  Widget _buildTextDetailsStep() => _TextDetailsStepContent(screen: this);
}

class _TextDetailsStepContent extends StatelessWidget {
  const _TextDetailsStepContent({required this.screen});

  final _AdCreationWizardScreenState screen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isShein = screen._isSheinInterface;
    final List<Widget> customFieldWidgets = screen._customFieldWidgets;
    final TextStyle? sectionStyle = theme.textTheme.titleMedium;

    return Form(
      key: screen._textDetailsFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('المراجعة النهائية', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          screen._buildInfoCard(
              'تحقق من التفاصيل قبل الإرسال. يمكنك العودة لتعديل أي خطوة.'),
          const SizedBox(height: 16),
          Text('معلومات الإعلان', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
              'العنوان: ${screen._titleController.text.isEmpty ? 'غير محدد' : screen._titleController.text}'),
          const SizedBox(height: 6),
          Text(
              'الوصف: ${screen._descriptionController.text.isEmpty ? 'غير محدد' : screen._descriptionController.text}'),
          const SizedBox(height: 6),
          Text(
              'السعر: ${screen._priceController.text.isEmpty ? 'غير محدد' : screen._priceController.text} ${screen._currencyLabel}'),
          const SizedBox(height: 6),
          Text(
              'رقم التواصل: ${screen._contactController.text.isEmpty ? 'غير محدد' : screen._contactController.text}'),
          const SizedBox(height: 16),
          Text('الفئات المختارة', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('الفئة الرئيسية: ${screen._selectedMainCategory?.name ?? 'غير محدد'}'),
          Text('الفئة الفرعية: ${screen._selectedSubCategory?.name ?? 'غير محدد'}'),
          Text(
              'واجهة العرض: ${screen._selectedMainCategory?.interfaceType ?? 'غير محدد'}'),
          const SizedBox(height: 16),
          Text('الحقول المخصّصة', style: sectionStyle),
          const SizedBox(height: 8),
          if (customFieldWidgets.isEmpty)
            Text('لا توجد قيم محفوظة للحقول المخصّصة.',
                style: theme.textTheme.bodySmall)
          else
            ...customFieldWidgets,
          const Divider(height: 32),
          Text('معلومات الإعلان', style: sectionStyle),
          const SizedBox(height: 12),
          TextFormField(
            controller: screen._titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'عنوان الإعلان',
              helperText: '10 - 90 حرفًا',
            ),
            maxLength: 90,
            validator: screen._validateTitle,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: screen._descriptionController,
            minLines: 4,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'الوصف التفصيلي',
              helperText: 'يُنصح بوصف واضح لا يقل عن 30 حرفًا.',
            ),
            validator: screen._validateDescription,
          ),
          const SizedBox(height: 16),
          Text('التسعير والعملات', style: sectionStyle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: screen._priceController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'السعر',
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  validator: screen._validatePrice,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: screen._selectedCurrency,
                  decoration: InputDecoration(
                    labelText: 'العملة',
                    errorText: screen._serverFieldErrors['currency'],
                  ),
                  items: screen._currencyOptions.entries
                      .map(
                        (MapEntry<String, String> entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    screen.setState(() => screen._selectedCurrency = value);
                    screen._clearServerFieldError('currency');
                    screen._markDirty();
                  },
                  validator: (String? value) {
                    if (value == null) {
                      return 'يرجى اختيار العملة.';
                    }
                    return screen._serverFieldErrors['currency'];
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('بيانات التواصل', style: sectionStyle),
          const SizedBox(height: 12),
          TextFormField(
            controller: screen._contactController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'رقم التواصل',
              helperText: 'يمكن أن يبدأ بعلامة + ثم أرقام فقط.',
            ),
            maxLength: 16,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            ],
            validator: screen._validateContact,
          ),
          if (isShein) ...[
            const SizedBox(height: 16),
            Text('روابط شي إن', style: sectionStyle),
            const SizedBox(height: 12),
            TextFormField(
              controller: screen._sheinProductLinkController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'رابط المنتج في شي إن',
              ),
              validator: screen._validateSheinProductLink,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: screen._sheinReviewLinkController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'رابط مراجعة موثوقة (اختياري)',
              ),
              validator: screen._validateSheinReviewLink,
            ),
          ],
        ],
      ),
    );
  }
}