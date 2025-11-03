import 'package:flutter/material.dart';
import 'package:marib/data/constants/color_catalog.dart';
import 'package:marib/utils/color_palette_utils.dart';

class ColorAttributeSelectorSection extends StatelessWidget {
  const ColorAttributeSelectorSection({
    super.key,
    required this.title,
    required this.values,
    required this.selectedValue,
    required this.onValueSelected,
    this.isRequired = false,
    this.emptyStateMessage = 'لا توجد قيم محددة لهذه السمة.',
  });

  final String title;
  final List<String> values;
  final String? selectedValue;
  final ValueChanged<String> onValueSelected;
  final bool isRequired;
  final String emptyStateMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentValue = selectedValue ?? '';
    final seenValues = <String>{};
    final descriptors = <ColorChoiceDescriptor>[];

    for (final raw in values) {
      if (raw.isEmpty || !seenValues.add(raw)) {
        continue;
      }
      final descriptor = ColorChoiceDescriptor.fromRawValue(
        rawValue: raw,
        context: context,
      );
      if (descriptor.displayLabel.isNotEmpty || descriptor.swatchColor != null) {
        descriptors.add(descriptor);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$title *' : title,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        if (descriptors.isEmpty)
          Text(
            emptyStateMessage,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          )
        else
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: descriptors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final descriptor = descriptors[index];
                final selected = currentValue == descriptor.rawValue;
                return ColorSwatchChip(
                  descriptor: descriptor,
                  selected: selected,
                  onTap: () => onValueSelected(descriptor.rawValue),
                );
              },
            ),
          ),
      ],
    );
  }
}

class ColorChoiceDescriptor {
  const ColorChoiceDescriptor({
    required this.rawValue,
    required this.displayLabel,
    required this.swatchColor,
  });

  final String rawValue;
  final String displayLabel;
  final Color? swatchColor;

  static final RegExp _hexPattern = RegExp(r'#?[0-9a-fA-F]{6}');

  factory ColorChoiceDescriptor.fromRawValue({
    required String rawValue,
    required BuildContext context,
  }) {
    final original = rawValue;
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return const ColorChoiceDescriptor(
        rawValue: '',
        displayLabel: '',
        swatchColor: null,
      );
    }

    String label = trimmed;
    Color? color;
    String? resolvedHex;

    final match = _hexPattern.firstMatch(trimmed);
    if (match != null) {
      resolvedHex = ColorCatalog.sanitizeHex(match.group(0)!);
    } else {
      final normalized = trimmed.toLowerCase();
      for (final entry in ColorPaletteHelper.entries) {
        final fallback = entry.fallbackLabel.toLowerCase();
        final englishKey = entry.labelKey.replaceFirst('colorPalette', '').toLowerCase();
        if (normalized == fallback || normalized == englishKey) {
          resolvedHex = entry.normalizedHex;
          break;
        }
      }
    }

    if (resolvedHex != null && resolvedHex.isNotEmpty) {
      color = ColorPaletteHelper.tryParseColor(resolvedHex);
      final cleaned = trimmed
          .replaceAll(_hexPattern, '')
          .replaceAll(RegExp(r'[|:_\\-]+'), ' ')
          .trim();

      final friendly = ColorCatalog.nameForHex(
        resolvedHex,
        context: context,
      );

      if (cleaned.isNotEmpty) {
        label = cleaned;
      } else if (friendly.isNotEmpty) {
        label = friendly;
      } else {
        label = '#$resolvedHex';
      }
    } else {
      final normalized = label.toLowerCase();
      for (final entry in ColorPaletteHelper.entries) {
        final fallback = entry.fallbackLabel.toLowerCase();
        final englishKey = entry.labelKey.replaceFirst('colorPalette', '').toLowerCase();
        if (normalized == fallback || normalized == englishKey) {
          color = entry.color;
          final friendly = entry.label(context);
          if (friendly.isNotEmpty) {
            label = friendly;
          } else {
            label = entry.fallbackLabel;
          }
          break;
        }
      }
    }

    if (label.isEmpty) {
      label = trimmed.isNotEmpty ? trimmed : original;
    }

    return ColorChoiceDescriptor(
      rawValue: original,
      displayLabel: label,
      swatchColor: color,
    );
  }
}

class ColorSwatchChip extends StatelessWidget {
  const ColorSwatchChip({
    super.key,
    required this.descriptor,
    required this.selected,
    required this.onTap,
  });

  final ColorChoiceDescriptor descriptor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final swatchColor = descriptor.swatchColor;
    final resolvedColor = swatchColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.9);
    final borderColor = selected ? colorScheme.primary : theme.dividerColor.withOpacity(0.3);
    final labelColor = selected
        ? colorScheme.primary
        : theme.textTheme.bodySmall?.color ?? colorScheme.onSurface.withOpacity(0.8);

    return Semantics(
      button: true,
      selected: selected,
      label: descriptor.displayLabel.isEmpty
          ? 'لون غير محدد'
          : 'لون ${descriptor.displayLabel}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(32),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: resolvedColor,
                  border: Border.all(
                    color: borderColor,
                    width: selected ? 3 : 1.4,
                  ),
                  boxShadow: selected
                      ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (swatchColor == null)
                      Icon(Icons.block, size: 22, color: theme.hintColor),
                    if (selected)
                      Icon(
                        Icons.check_rounded,
                        size: 26,
                        color: swatchColor == null
                            ? theme.hintColor
                            : _foregroundForSwatch(swatchColor),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (descriptor.displayLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 70,
              child: Text(
                descriptor.displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: labelColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ) ??
                    TextStyle(
                      color: labelColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _foregroundForSwatch(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }
}