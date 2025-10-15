part of 'ad_creation_wizard_screen.dart';



enum _PendingMediaType { image, video }

class _PendingMedia {
  _PendingMedia._(this.file, this.type, this.sizeInBytes);

  factory _PendingMedia.image(File file) =>
      _PendingMedia._(file, _PendingMediaType.image, _resolveSize(file));

  factory _PendingMedia.video(File file) =>
      _PendingMedia._(file, _PendingMediaType.video, _resolveSize(file));

  final File file;
  final _PendingMediaType type;
  final int sizeInBytes;

  static int _resolveSize(File file) {
    try {
      return file.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  bool get isImage => type == _PendingMediaType.image;

  bool get isVideo => type == _PendingMediaType.video;

  String get displayName {
    final List<String> segments = file.uri.pathSegments;
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return file.path;
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'type': type.name,
    'path': file.path,
    'size': sizeInBytes,
    'name': displayName,
  };
}

class _InventoryVariation {
  _InventoryVariation({
    required this.id,
    this.name = '',
    this.sku = '',
    this.priceText = '',
    this.quantityText = '',
  });

  final String id;
  String name;
  String sku;
  String priceText;
  String quantityText;

  Map<String, dynamic> toPayload() {
    final String trimmedName = name.trim();
    final String trimmedSku = sku.trim();
    final double? price = double.tryParse(priceText.trim());
    final int? quantity = int.tryParse(quantityText.trim());
    final Map<String, dynamic> payload = <String, dynamic>{
      'id': id,
      if (trimmedName.isNotEmpty) 'name': trimmedName,
      if (trimmedSku.isNotEmpty) 'sku': trimmedSku,
      if (price != null) 'price': price,
      if (quantity != null) 'quantity': quantity,
    };
    return payload;
  }

  bool get isComplete {
    final double? price = double.tryParse(priceText.trim());
    final int? quantity = int.tryParse(quantityText.trim());
    return name.trim().isNotEmpty &&
        price != null &&
        price > 0 &&
        quantity != null &&
        quantity >= 0;
  }
}

class _WizardSectionConfig {
  const _WizardSectionConfig({
    this.requiresLocation = false,
    this.requiresInventory = false,
  });

  final bool requiresLocation;
  final bool requiresInventory;
}

class _MediaPreviewCard extends StatelessWidget {
  const _MediaPreviewCard(
      {super.key, required this.media, required this.onRemove});

  final _PendingMedia media;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    Widget buildPreview() {
      if (media.isImage) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            media.file,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
              return Container(
                color: colors.surfaceVariant,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              );
            },
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.play_circle_fill, size: 42, color: colors.tertiary),
      );
    }

    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(child: buildPreview()),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: colors.error.withOpacity(0.9),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            media.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            HelperUtils.getFileSizeString(
                bytes: media.sizeInBytes, decimals: 1),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (media.isVideo)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.movie_filter_outlined,
                      size: 16, color: colors.tertiary),
                  const SizedBox(width: 4),
                  Text('ملف فيديو', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WizardStep {
  const _WizardStep({
    required this.id,
    required this.label,
    this.isOptional = false,
    this.isVisible = true,
  });

  final _WizardStepId id;
  final String label;
  final bool isOptional;
  final bool isVisible;
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.index,
    required this.isCurrent,
    required this.isCompleted,
    required this.isOptional,
  });

  final String label;
  final int index;
  final bool isCurrent;
  final bool isCompleted;
  final bool isOptional;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.color;
    final ThemeData theme = Theme.of(context);
    final Color background = isCompleted
        ? colors.territoryColor.withOpacity(0.1)
        : isCurrent
        ? colors.territoryColor.withOpacity(0.12)
        : colors.secondaryColor;
    final Color borderColor = isCompleted
        ? colors.territoryColor
        : isCurrent
        ? colors.territoryColor.withOpacity(0.6)
        : colors.borderColor.withOpacity(0.4);
    final Color labelColor =
    isCompleted ? colors.territoryColor : colors.textDefaultColor;

    final Color badgeBackground = isOptional
        ? colors.deactivateColor.withOpacity(isCompleted ? 0.24 : 0.14)
        : colors.territoryColor.withOpacity(isCompleted ? 0.24 : 0.14);
    final Color badgeTextColor =
    isOptional ? colors.textDefaultColor : colors.territoryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color:
              isCompleted ? colors.territoryColor : colors.secondaryColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted
                    ? colors.territoryColor
                    : colors.borderColor.withOpacity(isCurrent ? 0.6 : 0.4),
              ),
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
              '${index + 1}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isCurrent
                    ? colors.territoryColor
                    : colors.textDefaultColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: labelColor,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOptional ? 'اختياري' : 'مطلوب',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: badgeTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MainCategoryOption {
  const _MainCategoryOption({
    required this.id,
    required this.name,
    required this.interfaceType,
    this.imageUrl,
    this.subCategories = const <_SubCategoryOption>[],
  });

  final int id;
  final String name;
  final String? imageUrl;
  final String interfaceType;
  final List<_SubCategoryOption> subCategories;

  factory _MainCategoryOption.fromCategoryModel(CategoryModel model) {
    String resolveName(String? value) {
      final String trimmed = (value ?? '').trim();
      return trimmed.isEmpty ? 'فئة بدون اسم' : trimmed;
    }

    final List<_SubCategoryOption> subCategories =
    (model.children ?? const <CategoryModel>[])
        .where((CategoryModel child) => child.id != null)
        .map((CategoryModel child) => _SubCategoryOption(
      id: child.id!,
      name: resolveName(child.name),
      imageUrl: child.url,
    ))
        .toList(growable: false);

    return _MainCategoryOption(
      id: model.id!,
      name: resolveName(model.name),
      interfaceType: (model.interfaceType ?? '').trim(),
      imageUrl: model.url,
      subCategories: subCategories,
    );
  }

  String get normalizedInterfaceType {
    final String trimmed = interfaceType.trim();
    return trimmed.isEmpty ? '' : trimmed.toLowerCase();
  }

}

class _SubCategoryOption {
  const _SubCategoryOption({
    required this.id,
    required this.name,
    this.imageUrl,
  });


  final int id;
  final String name;
  final String? imageUrl;
}