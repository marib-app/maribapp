part of 'ad_creation_wizard_screen.dart';



extension _ReviewStepBuilder on _AdCreationWizardScreenState {
  Widget _buildReviewStep() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    String displayValue(String value, [String placeholder = 'غير محدد']) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? placeholder : trimmed;
    }

    final List<_PendingMedia> images =
    _mediaFiles.where((media) => media.isImage).toList(growable: false);
    final List<_PendingMedia> videos =
    _mediaFiles.where((media) => media.isVideo).toList(growable: false);
    final bool isShein = _isSheinInterface;
    final String currencyLabel = _currencyLabel;
    final _MainCategoryOption? mainCategory = _selectedMainCategory;
    final _SubCategoryOption? subCategory = _selectedSubCategory;
    final List<_InventoryVariation> inventorySummary =
    _inventoryVariations.toList(growable: false);

    final String locationAddress = _locationAddressController.text.trim();
    final String locationLatitude = _locationLatitudeController.text.trim();
    final String locationLongitude = _locationLongitudeController.text.trim();
    final bool hasLocationSummary = locationAddress.isNotEmpty ||
        locationLatitude.isNotEmpty ||
        locationLongitude.isNotEmpty;

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
                  'العنوان: ${displayValue(_titleController.text)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'الفئة الرئيسية: ${mainCategory?.name ?? 'غير محدد'}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'الفئة الفرعية: ${subCategory?.name ?? 'غير محدد'}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'السعر: ${displayValue(_priceController.text)} $currencyLabel',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'رقم التواصل: ${displayValue(_contactController.text)}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (isShein) ...<Widget>[
                  const SizedBox(height: 12),
                  Text('معلومات شي إن', style: theme.textTheme.titleMedium),
                  Text(
                    'رابط المنتج: ${displayValue(_sheinProductLinkController.text, 'غير متوفر')}',
                  ),
                  Text(
                    'رابط المراجعة: ${displayValue(_sheinReviewLinkController.text, 'غير متوفر')}',
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
                if (images.isEmpty && videos.isEmpty && _videoLinks.isEmpty)
                  Text('لم يتم إضافة وسائط بعد.',
                      style: theme.textTheme.bodySmall)
                else ...<Widget>[
                  if (images.isNotEmpty) ...<Widget>[
                    Text('الصور (${images.length})',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
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
                  if (videos.isNotEmpty) ...<Widget>[
                    Text('الملفات المرئية (${videos.length})',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
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
                  if (_videoLinks.isNotEmpty) ...<Widget>[
                    Text('روابط الفيديو (${_videoLinks.length})',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final String link in _videoLinks)
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
    if (hasLocationSummary) ...<Widget>[
    const SizedBox(height: 16),
          Card(
    shape:
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[

                  Text('موقع الإعلان', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
    Text('العنوان: ${displayValue(locationAddress)}'),
    Text('خط العرض: ${displayValue(locationLatitude)}'),
    Text('خط الطول: ${displayValue(locationLongitude)}'),
                ],
              ),
            ),
          ),
    ],
        if (inventorySummary.isNotEmpty) ...<Widget>[

          const SizedBox(height: 16),
          Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[

                  Text('تنويعات المخزون', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final _InventoryVariation variation in inventorySummary)
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