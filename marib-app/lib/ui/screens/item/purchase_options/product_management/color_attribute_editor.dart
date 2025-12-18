import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:marib/data/constants/color_catalog.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_color_field.dart'
    show ColorWheelPickerSheet;

import 'product_management_color_utils.dart';
import 'package:marib/ui/theme/theme.dart';



class ColorAttributeEditor {
  const ColorAttributeEditor._();

  static Future<void> show({
    required BuildContext context,
    required String attributeKey,
    required String attributeName,
    required List<CustomFieldColorEntry> currentEntries,
    required Set<String> suggestedCodes,
    required ValueChanged<List<CustomFieldColorEntry>> onSave,
  }) async {
    final String title = attributeName.isEmpty
        ? 'إدارة ألوان السمة'
        : 'إدارة ألوان $attributeName';

    final List<CustomFieldColorEntry> initial = currentEntries
        .map(
          (CustomFieldColorEntry entry) =>
              CustomFieldColorEntry(code: entry.code),
        )
        .toList(growable: false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return ColorAttributeEditorSheet(
          title: title,
          entries: initial,
          suggestedCodes: suggestedCodes,
          onSave: onSave,
        );
      },
    );
  }
}

class ColorAttributeEditorSheet extends StatefulWidget {
  const ColorAttributeEditorSheet({
    super.key,
    required this.title,
    required this.entries,
    required this.suggestedCodes,
    required this.onSave,
  });

  final String title;
  final List<CustomFieldColorEntry> entries;
  final Set<String> suggestedCodes;
  final ValueChanged<List<CustomFieldColorEntry>> onSave;

  @override
  State<ColorAttributeEditorSheet> createState() =>
      _ColorAttributeEditorSheetState();
}

class _ColorAttributeEditorSheetState
    extends State<ColorAttributeEditorSheet> {
  late LinkedHashMap<String, CustomFieldColorEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = LinkedHashMap<String, CustomFieldColorEntry>();
    for (final CustomFieldColorEntry entry in widget.entries) {
      final String code = entry.code.toUpperCase();
      _entries[code] = CustomFieldColorEntry(code: code);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _displayColorLabel(BuildContext context, String code) {
    final String label = ColorCatalog.nameForHex(code, context: context).trim();
    if (label.isEmpty) {
      return 'لون';
    }
    if (label.startsWith('#')) {
      return 'لون مخصص';
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final List<Map<String, String>> paletteEntries = ColorCatalog.basePalette;
    final Set<String> paletteCodes = <String>{
      for (final Map<String, String> entry in paletteEntries)
        if (ProductManagementColorUtils.normalizeColorValue(entry['hex']) != null)
          ProductManagementColorUtils.normalizeColorValue(entry['hex'])!,
    };
    final List<String> customSelectedCodes = _entries.keys
        .where((String code) => !paletteCodes.contains(code))
        .toList(growable: false)
      ..sort();

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: palette.secondaryColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.borderColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'الألوان الشائعة',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          ...paletteEntries.map((Map<String, String> entry) {
                            final String? rawHex = entry['hex'];
                            final String? normalized =
                                ProductManagementColorUtils.normalizeColorValue(
                                    rawHex);
                            if (normalized == null) {
                              return const SizedBox.shrink();
                            }
                            final bool selected = _entries.containsKey(normalized);
                            final String label =
                                _displayColorLabel(context, normalized);
                            return ColorChoiceChip(
                              code: normalized,
                              label: label,
                              selected: selected,
                              onTap: () => _toggleColor(normalized),
                            );
                          }),
                          ...customSelectedCodes.map(
                            (String code) => ColorChoiceChip(
                              code: code,
                              label: _displayColorLabel(context, code),
                              selected: true,
                              onTap: () => _toggleColor(code),
                            ),
                          ),
                          ActionChip(
                            avatar: Icon(
                              Icons.colorize_outlined,
                              color: palette.territoryColor,
                            ),
                            label: Text(
                              'لون مخصص',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: palette.territoryColor,
                              ),
                            ),
                            onPressed: _openCustomColorPicker,
                            backgroundColor: palette.secondaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: palette.borderColor.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_entries.isEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          'اختر لونًا واحدًا أو أكثر.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textDefaultColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.territoryColor,
                          foregroundColor: palette.buttonColor,
                        ),
                        child: const Text('حفظ'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleColor(String value) {
    setState(() {
      final String? normalized =
          ProductManagementColorUtils.normalizeColorValue(value);
      if (normalized == null) {
        return;
      }
      if (_entries.containsKey(normalized)) {
        _entries.remove(normalized);
      } else {
        _entries[normalized] = CustomFieldColorEntry(code: normalized);
      }
    });
  }

  Future<void> _openCustomColorPicker() async {
    final String? hex = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ColorWheelPickerSheet(),
    );

    if (!mounted || hex == null || hex.trim().isEmpty) {
      return;
    }

    final String? normalized =
        ProductManagementColorUtils.normalizeColorValue(hex);
    if (normalized == null) {
      return;
    }

    setState(() {
      _entries[normalized] = CustomFieldColorEntry(code: normalized);
    });
  }

  void _save() {
    widget.onSave(_entries.values.toList(growable: false));
    Navigator.of(context).pop();
  }
}

class ColorChoiceChip extends StatelessWidget {
  const ColorChoiceChip({
    super.key,
    required this.code,
    required this.selected,
    required this.onTap,
    this.label,
    this.muted = false,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final Color color =
        ProductManagementColorUtils.colorFromHex(code) ??
            palette.borderColor;
    String displayLabel = (label ?? '').trim();
    if (displayLabel.isEmpty) {
      displayLabel = ColorCatalog.nameForHex(code, context: context).trim();
    }
    if (displayLabel.isEmpty || displayLabel.startsWith('#')) {
      displayLabel = 'لون مخصص';
    }

    return ChoiceChip(
      label: Text(displayLabel),
      avatar: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: palette.textDefaultColor.withOpacity(0.18),
            width: 1,
          ),
        ),
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? palette.territoryColor
            : (muted
                ? palette.textDefaultColor.withOpacity(0.65)
                : palette.textDefaultColor),
      ),
      selectedColor: palette.territoryColor.withOpacity(0.18),
      backgroundColor: palette.secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class ColorSelectionChip extends StatelessWidget {
  const ColorSelectionChip({super.key, required this.entry});

  final CustomFieldColorEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final Color color =
        ProductManagementColorUtils.colorFromHex(entry.code) ??
            palette.borderColor;
    String displayLabel =
        ColorCatalog.nameForHex(entry.code, context: context).trim();
    if (displayLabel.isEmpty || displayLabel.startsWith('#')) {
      displayLabel = 'لون مخصص';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderColor.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: palette.textDefaultColor.withOpacity(0.18),
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            displayLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.textDefaultColor,
            ),
          ),
        ],
      ),
    );
  }
}

class ColorAttributeChip extends StatelessWidget {
  const ColorAttributeChip({
    super.key,
    required this.code,
    required this.entry,
    required this.isSelected,
    required this.onSelected,
  });

  final String code;
  final CustomFieldColorEntry? entry;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final Color color =
        ProductManagementColorUtils.colorFromHex(code) ??
            palette.borderColor;
    String label = ColorCatalog.nameForHex(code, context: context).trim();
    if (label.isEmpty || label.startsWith('#')) {
      label = 'لون مخصص';
    }

    return FilterChip(
      label: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? palette.territoryColor : palette.textDefaultColor,
        ),
      ),
      avatar: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: palette.textDefaultColor.withOpacity(0.18),
            width: 1,
          ),
        ),
      ),
      selected: isSelected,
      selectedColor: palette.territoryColor.withOpacity(0.12),
      backgroundColor: palette.secondaryColor,
      side: BorderSide(
        color: isSelected
            ? palette.territoryColor
            : palette.borderColor.withOpacity(0.5),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
