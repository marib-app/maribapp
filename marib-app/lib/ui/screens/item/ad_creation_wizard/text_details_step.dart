import 'package:flutter/material.dart';

import 'ad_creation_wizard_models.dart';

class TextDetailsStep extends StatelessWidget {
  const TextDetailsStep({
    super.key,
    required this.controller,
    this.onDraftChanged,
    this.onNext,
    this.onBack,
  });

  final AdCreationWizardController controller;
  final VoidCallback? onDraftChanged;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        return Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                children: <Widget>[
                  TextField(
                    controller: controller.titleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الإعلان',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onDraftChanged?.call(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller.descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'وصف الإعلان',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    onChanged: (_) => onDraftChanged?.call(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: controller.priceController,
                          decoration: InputDecoration(
                            labelText: 'السعر (${controller.currencyLabel})',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => onDraftChanged?.call(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: controller.contactController,
                          decoration: const InputDecoration(
                            labelText: 'رقم التواصل',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          onChanged: (_) => onDraftChanged?.call(),
                        ),
                      ),
                    ],
                  ),
                  if (controller.isSheinInterface) ...<Widget>[
                    const SizedBox(height: 12),
                    Text('معلومات شي إن', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller.sheinProductLinkController,
                      decoration: const InputDecoration(
                        labelText: 'رابط المنتج',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (_) => onDraftChanged?.call(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller.sheinReviewLinkController,
                      decoration: const InputDecoration(
                        labelText: 'رابط المراجعة',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (_) => onDraftChanged?.call(),
                    ),
                  ],
                ],
              ),
            ),
            Row(
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
            ),
          ],
        );
      },
    );
  }
}