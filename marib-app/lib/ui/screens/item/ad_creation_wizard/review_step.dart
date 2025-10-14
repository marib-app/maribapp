part of 'ad_creation_wizard_screen.dart';

extension _ReviewStepView on _AdCreationWizardScreenState {
  Widget _buildReviewStep() => _ReviewStepContent(screen: this);
}

class _ReviewStepContent extends StatelessWidget {
  const _ReviewStepContent({required this.screen});

  final _AdCreationWizardScreenState screen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    String displayValue(String value, [String placeholder = 'غير محدد']) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? placeholder : trimmed;
    }

    final List<_PendingMedia> images = screen._mediaFiles
        .where((media) => media.isImage)
        .toList(growable: false);
    final List<_PendingMedia> videos = screen._mediaFiles
        .where((media) => media.isVideo)
        .toList(growable: false);
    final bool isShein = screen._isSheinInterface;
    final String currencyLabel = screen._currencyLabel;
    final Map<String, dynamic>? locationSummary = screen._buildLocationPayload();
    final List<_InventoryVariation> inventorySummary =
    screen._inventoryVariations.toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: colors.surfaceVariant.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ملخص الإعلان', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'العنوان: ${displayValue(screen._titleController.text)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'الفئة الرئيسية: ${screen._selectedMainCategory?.name ?? 'غير محدد'}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'الفئة الفرعية: ${screen._selectedSubCategory?.name ?? 'غير محدد'}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'السعر: ${displayValue(screen._priceController.text)} $currencyLabel',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'رقم التواصل: ${displayValue(screen._contactController.text)}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (isShein) ...[
                  const SizedBox(height: 12),
                  Text('معلومات شي إن', style: theme.textTheme.titleMedium),
                  Text(
                    'رابط المنتج: ${displayValue(screen._sheinProductLinkController.text, 'غير متوفر')}',
                  ),
                  Text(
                    'رابط المراجعة: ${displayValue(screen._sheinReviewLinkController.text, 'غير متوفر')}',
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
              children: [
                Text('الوسائط المرفقة', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (images.isEmpty && videos.isEmpty && screen._videoLinks.isEmpty)
                  Text('لم يتم إضافة وسائط بعد.',
                      style: theme.textTheme.bodySmall)
                else ...[
                  if (images.isNotEmpty) ...[
                    Text('الصور (${images.length})',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final _PendingMedia media in images)
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
                  if (videos.isNotEmpty) ...[
                    Text('الفيديوهات (${videos.length})',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final _PendingMedia media in videos)
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
                  if (screen._videoLinks.isNotEmpty) ...[
                    Text('روابط الفيديو (${screen._videoLinks.length})',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final String link in screen._videoLinks)
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
                children: [
                  Text('موقع الإعلان', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('العنوان: ${locationSummary['address']}'),
                  Text('خط العرض: ${locationSummary['latitude']}'),
                  Text('خط الطول: ${locationSummary['longitude']}'),
                ],
              ),
            ),
          ),
        if (inventorySummary.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تنويعات المخزون', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final _InventoryVariation variation in inventorySummary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(variation.name.isEmpty
                              ? 'تنويعة بدون اسم'
                              : variation.name),
                          Text('السعر: ${variation.priceText.isEmpty ? 'غير محدد' : variation.priceText}'),
                          Text('الكمية: ${variation.quantityText.isEmpty ? 'غير محدد' : variation.quantityText}'),
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