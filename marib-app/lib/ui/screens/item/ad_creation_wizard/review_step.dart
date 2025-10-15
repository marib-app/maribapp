import 'package:flutter/material.dart';

import 'ad_creation_wizard_models.dart';


class ReviewStep extends StatelessWidget {
  const ReviewStep({
    super.key,
    required this.controller,
  });

  final AdCreationWizardController controller;


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    String displayValue(String value, [String placeholder = 'غير محدد']) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? placeholder : trimmed;
    }

    final List<PendingMedia> images = controller.mediaFiles
        .where((PendingMedia media) => media.isImage)
        .toList(growable: false);
    final List<PendingMedia> videos = controller.mediaFiles
        .where((PendingMedia media) => media.isVideo)
        .toList(growable: false);
    final bool isShein = controller.isSheinInterface;
    final String currencyLabel = controller.currencyLabel;
    final Map<String, dynamic>? locationSummary = controller.locationSummary;
    final List<InventoryVariation> inventorySummary =
    controller.inventoryVariations.toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[

        Card(
          elevation: 0,
          color: colors.surfaceVariant.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[

                Text('ملخص الإعلان', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'العنوان: ${displayValue(controller.titleController.text)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'الفئة الرئيسية: ${controller.selectedMainCategory?.name ?? 'غير محدد'}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'الفئة الفرعية: ${controller.selectedSubCategory?.name ?? 'غير محدد'}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'السعر: ${displayValue(controller.priceController.text)} $currencyLabel',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'رقم التواصل: ${displayValue(controller.contactController.text)}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (isShein) ...<Widget>[
                  const SizedBox(height: 12),
                  Text('معلومات شي إن', style: theme.textTheme.titleMedium),
                  Text(
                    'رابط المنتج: ${displayValue(controller.sheinProductLinkController.text, 'غير متوفر')}',
                  ),
                  Text(
                    'رابط المراجعة: ${displayValue(controller.sheinReviewLinkController.text, 'غير متوفر')}',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('الوسائط المرفقة', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (images.isEmpty && videos.isEmpty && controller.videoLinks.isEmpty)
                  Text('لم يتم إضافة وسائط بعد.', style: theme.textTheme.bodySmall)
                else ...<Widget>[
                  if (images.isNotEmpty) ...<Widget>[
                    Text('الصور (${images.length})', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final PendingMedia media in images)
                          Chip(
                            label: SizedBox(
                              width: 180,
                              child: Text(
                                media.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (videos.isNotEmpty) ...<Widget>[
                    Text('الملفات المرئية (${videos.length})', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final PendingMedia media in videos)
                          Chip(
                            label: SizedBox(
                              width: 180,
                              child: Text(
                                media.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (controller.videoLinks.isNotEmpty) ...<Widget>[
                    Text('روابط الفيديو (${controller.videoLinks.length})',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final String link in controller.videoLinks)
                          Chip(
                            avatar: const Icon(Icons.link, size: 16),
                            label: SizedBox(
                              width: 200,
                              child: Text(
                                link,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (locationSummary != null)
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[

                  Text('موقع الإعلان', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('العنوان: ${locationSummary['address']}'),
                  Text('خط العرض: ${locationSummary['latitude']}'),
                  Text('خط الطول: ${locationSummary['longitude']}'),
                ],
              ),
            ),
          ),
        if (inventorySummary.isNotEmpty) ...<Widget>[

          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[

                  Text('تنويعات المخزون', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final InventoryVariation variation in inventorySummary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            variation.name.isEmpty
                                ? 'تنويعة بدون اسم'
                                : variation.name,
                          ),
                          Text(
                            'السعر: ${variation.priceText.isEmpty ? 'غير محدد' : variation.priceText}',
                          ),
                          Text(
                            'الكمية: ${variation.quantityText.isEmpty ? 'غير محدد' : variation.quantityText}',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}