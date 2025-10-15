import 'package:flutter/material.dart';

import 'ad_creation_wizard_models.dart';
import 'models/custom_field_schema.dart';

class CustomFieldsStep extends StatelessWidget {
  const CustomFieldsStep({
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
        if (controller.isLoadingCustomFields) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<CustomFieldSchema> fields = controller.customFields;
        if (fields.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: Text(
                    'لا توجد حقول إضافية لهذه الفئة.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              _NavigationRow(onBack: onBack, onNext: onNext),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ListView.separated(
                itemBuilder: (BuildContext context, int index) {
                  final CustomFieldSchema field = fields[index];
                  return _CustomFieldTile(
                    controller: controller,
                    field: field,
                    onDraftChanged: onDraftChanged,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: fields.length,
              ),
            ),
            const SizedBox(height: 12),
            _NavigationRow(onBack: onBack, onNext: onNext),
          ],
        );
      },
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({this.onBack, this.onNext});

  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (onBack != null)
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('السابق'),
          ),
        if (onBack != null) const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('متابعة'),
        ),
      ],
    );
  }
}

class _CustomFieldTile extends StatelessWidget {
  const _CustomFieldTile({
    required this.controller,
    required this.field,
    this.onDraftChanged,
  });

  final AdCreationWizardController controller;
  final CustomFieldSchema field;
  final VoidCallback? onDraftChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(field.label, style: theme.textTheme.titleMedium),
            if (field.description != null && field.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  field.description!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            switch (field.type) {
              CustomFieldType.text => _buildTextField(context),
              CustomFieldType.singleChoice => _buildSingleChoiceField(context),
              CustomFieldType.multiChoice => _buildMultiChoiceField(context),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    final TextEditingController textController =
    controller.customFieldTextController(field.id);

    final String value = controller.customFieldValues[field.id]?.toString() ?? '';
    if (textController.text != value) {
      textController.text = value;
    }

    return TextFormField(
      controller: textController,
      decoration: InputDecoration(
        labelText: 'اكتب ${field.label.toLowerCase()}',
        border: const OutlineInputBorder(),
      ),
      onChanged: (String value) {
        controller.setCustomFieldTextValue(field.id, value);
        onDraftChanged?.call();
      },
    );
  }

  Widget _buildSingleChoiceField(BuildContext context) {
    final String? selectedValue =
    controller.customFieldValues[field.id]?.toString();

    return DropdownButtonFormField<String>(
      value: selectedValue?.isEmpty ?? true ? null : selectedValue,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      hint: Text('اختر ${field.label}'),
      onChanged: (String? value) {
        controller.setCustomFieldSingleChoice(field.id, value);
        onDraftChanged?.call();
      },
      items: field.options
          .map(
            (CustomFieldOption option) => DropdownMenuItem<String>(
          value: option.value,
          child: Text(option.label),
        ),
      )
          .toList(growable: false),
    );
  }

  Widget _buildMultiChoiceField(BuildContext context) {
    final Set<String> selectedValues =
    <String>{...(controller.customFieldValues[field.id] as List<dynamic>? ?? const <dynamic>[]).map((dynamic e) => e.toString())};

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: field.options
          .map(
            (CustomFieldOption option) => FilterChip(
          label: Text(option.label),
          selected: selectedValues.contains(option.value),
          onSelected: (_) {
            controller.toggleCustomFieldMultiChoice(field.id, option.value);
            onDraftChanged?.call();
          },
        ),
      )
          .toList(growable: false),
    );
  }
}