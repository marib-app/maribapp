import 'package:flutter/material.dart';

import 'ad_creation_wizard_models.dart';

class MediaStep extends StatelessWidget {
  const MediaStep({
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
        final List<PendingMedia> mediaFiles = controller.mediaFiles;
        final List<String> videoLinks = controller.videoLinks;
        final List<InventoryVariation> variations = controller.inventoryVariations;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ListView(
                children: <Widget>[
                  _SectionHeader(title: 'الوسائط المرفقة', theme: theme),
                  _AddMediaField(
                    controller: controller,
                    onDraftChanged: onDraftChanged,
                  ),
                  const SizedBox(height: 12),
                  if (mediaFiles.isEmpty)
                    Text(
                      'لم يتم إضافة أي وسائط بعد.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: mediaFiles
                          .map(
                            (PendingMedia media) => Chip(
                          label: Text(media.displayName),
                          onDeleted: () {
                            controller.removeMedia(media.id);
                            onDraftChanged?.call();
                          },
                        ),
                      )
                          .toList(growable: false),
                    ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'روابط الفيديو', theme: theme),
                  _AddVideoField(
                    controller: controller,
                    onDraftChanged: onDraftChanged,
                  ),
                  const SizedBox(height: 12),
                  ...videoLinks.map(
                        (String link) => ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(link),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          controller.removeVideoLink(link);
                          onDraftChanged?.call();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'تنويعات المخزون', theme: theme),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      controller.addInventoryVariation();
                      onDraftChanged?.call();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة تنويعة'),
                  ),
                  const SizedBox(height: 12),
                  if (variations.isEmpty)
                    Text(
                      'أضف تنويعات المخزون مثل الحجم أو اللون.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else
                    Column(
                      children: variations
                          .map(
                            (InventoryVariation variation) => _InventoryVariationForm(
                          variation: variation,
                          onRemove: () {
                            controller.removeInventoryVariation(variation.id);
                            onDraftChanged?.call();
                          },
                          onDraftChanged: onDraftChanged,
                        ),
                      )
                          .toList(growable: false),
                    ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.titleMedium,
    );
  }
}

class _AddMediaField extends StatelessWidget {
  const _AddMediaField({required this.controller, this.onDraftChanged});

  final AdCreationWizardController controller;
  final VoidCallback? onDraftChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller.mediaLabelController,
            decoration: const InputDecoration(
              labelText: 'اسم الوسيط أو الوصف',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _handleAdd(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _handleAdd,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('إضافة'),
        ),
      ],
    );
  }

  void _handleAdd() {
    final String label = controller.mediaLabelController.text.trim();
    if (label.isEmpty) {
      return;
    }
    controller.addMediaEntry(label: label);
    controller.mediaLabelController.clear();
    onDraftChanged?.call();
  }
}

class _AddVideoField extends StatelessWidget {
  const _AddVideoField({required this.controller, this.onDraftChanged});

  final AdCreationWizardController controller;
  final VoidCallback? onDraftChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller.videoLinkController,
            decoration: const InputDecoration(
              labelText: 'رابط الفيديو',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _handleAdd(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _handleAdd,
          icon: const Icon(Icons.add_link),
          label: const Text('إضافة'),
        ),
      ],
    );
  }

  void _handleAdd() {
    final String link = controller.videoLinkController.text.trim();
    if (link.isEmpty) {
      return;
    }
    controller.addVideoLink(link);
    controller.videoLinkController.clear();
    onDraftChanged?.call();
  }
}

class _InventoryVariationForm extends StatelessWidget {
  const _InventoryVariationForm({
    required this.variation,
    required this.onRemove,
    this.onDraftChanged,
  });

  final InventoryVariation variation;
  final VoidCallback onRemove;
  final VoidCallback? onDraftChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: variation.nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم التنويعة',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onDraftChanged?.call(),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: variation.priceController,
                    decoration: const InputDecoration(
                      labelText: 'السعر',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onDraftChanged?.call(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: variation.quantityController,
                    decoration: const InputDecoration(
                      labelText: 'الكمية',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onDraftChanged?.call(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'استخدم التنويعات لتحديد اختلافات المنتج مثل اللون أو الحجم.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}