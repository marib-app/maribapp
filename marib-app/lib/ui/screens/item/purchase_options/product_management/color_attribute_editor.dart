import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/data/constants/color_catalog.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'product_management_color_utils.dart';
import 'product_management_input_decorations.dart';
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
              CustomFieldColorEntry(code: entry.code, quantity: entry.quantity),
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
  late Map<String, TextEditingController> _controllers;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _entries = LinkedHashMap<String, CustomFieldColorEntry>();
    _controllers = <String, TextEditingController>{};
    for (final CustomFieldColorEntry entry in widget.entries) {
      final String code = entry.code.toUpperCase();
      _entries[code] =
          CustomFieldColorEntry(code: code, quantity: entry.quantity);
      _controllers[code] =
          TextEditingController(text: entry.quantity?.toString() ?? '');
    }
    _hexController = TextEditingController();
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final List<String> suggested = widget.suggestedCodes
        .map((String code) => code.toUpperCase())
        .toSet()
        .toList(growable: false)
      ..sort();

    final Set<String> recommendedSet = suggested.toSet();

    final List<Map<String, String>> paletteEntries = ColorCatalog.basePalette;

    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
                        'الألوان المحددة',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_entries.isEmpty)
                        Text(
                          'لم يتم اختيار أي لون بعد. اختر لونًا من اللوحات أو أضف لونًا مخصصًا.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.textDefaultColor.withOpacity(0.7),
                          ),
                        )
                      else
                        Column(
                          children: _entries.values
                              .map((CustomFieldColorEntry entry) =>
                                  _buildSelectedColorTile(context, entry))
                              .toList(growable: false),
                        ),
                      const SizedBox(height: 24),
                      if (suggested.isNotEmpty) ...<Widget>[
                        Text(
                          'الألوان المقترحة',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: suggested
                              .map((String code) => ColorChoiceChip(
                                    code: code,
                                    label: '#$code',
                                    selected: _entries.containsKey(code),
                                    onTap: () => _toggleColor(code),
                                  ))
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 24),
                      ],
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
                        children:
                            paletteEntries.map((Map<String, String> entry) {
                          final String? rawHex = entry['hex'];
                          final String? normalized =
                              ProductManagementColorUtils.normalizeColorValue(
                                  rawHex);
                          if (normalized == null) {
                            return const SizedBox.shrink();
                          }
                          final bool selected =
                              _entries.containsKey(normalized);
                          final bool isRecommended =
                              recommendedSet.contains(normalized);
                          final String label = entry['name'] ?? '#$normalized';
                          return ColorChoiceChip(
                            code: normalized,
                            label: label,
                            selected: selected,
                            onTap: () => _toggleColor(normalized),
                            muted: isRecommended,
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'إضافة لون مخصص',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _hexController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: ProductManagementInputDecorations
                                  .themed(
                                context,
                                hint: '#AABBCC',
                                label: 'كود اللون',
                              ),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9a-fA-F#]'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _addCustomColor,
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.territoryColor,
                              foregroundColor: palette.secondaryColor,
                            ),
                            child: const Text('إضافة'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'حدد كمية اختيارية لكل لون (مثل عدد القطع المتوفرة).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textDefaultColor.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: _entries.entries
                            .map((MapEntry<String, CustomFieldColorEntry> entry) {
                          final String code = entry.key;
                          final CustomFieldColorEntry value = entry.value;
                          final TextEditingController controller =
                              _controllers.putIfAbsent(
                            code,
                            () => TextEditingController(
                              text: value.quantity?.toString() ?? '',
                            ),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: false,
                                    ),
                                    decoration:
                                        ProductManagementInputDecorations.themed(
                                      context,
                                      label: '#$code',
                                    ),
                                    onChanged: (String raw) =>
                                        _updateQuantity(code, raw),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  tooltip: 'حذف اللون',
                                  onPressed: () => _removeColor(code),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        }).toList(growable: false),
                      ),
                      SizedBox(height: bottomInset + 12),
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
                          foregroundColor: palette.secondaryColor,
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

  Widget _buildSelectedColorTile(
    BuildContext context,
    CustomFieldColorEntry entry,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final Color color =
        ProductManagementColorUtils.colorFromHex(entry.code) ??
            palette.borderColor;
    final TextEditingController controller = _controllers.putIfAbsent(
      entry.code,
      () => TextEditingController(text: entry.quantity?.toString() ?? ''),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: palette.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor.withOpacity(0.4)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.black.withOpacity(0.18), width: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '#${entry.code}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  decoration: ProductManagementInputDecorations.themed(
                    context,
                    label: 'الكمية المتوفرة',
                  ),
                  onChanged: (String raw) => _updateQuantity(entry.code, raw),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إزالة اللون',
            onPressed: () => _removeColor(entry.code),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
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
        _controllers.remove(normalized)?.dispose();
      } else {
        _entries[normalized] =
            CustomFieldColorEntry(code: normalized, quantity: 0);
        _controllers[normalized] = TextEditingController(text: '0');
      }
    });
  }

  void _addCustomColor() {
    final String? normalized =
        ProductManagementColorUtils.normalizeColorValue(_hexController.text);
    if (normalized == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'يرجى إدخال كود لون صالح مكوَّن من 6 خانات.',
      );
      return;
    }

    setState(() {
      if (!_entries.containsKey(normalized)) {
        _entries[normalized] =
            CustomFieldColorEntry(code: normalized, quantity: 0);
        _controllers[normalized] = TextEditingController(text: '0');
      }
      _hexController.clear();
    });
  }

  void _removeColor(String code) {
    setState(() {
      _entries.remove(code);
      _controllers.remove(code)?.dispose();
    });
  }

  void _updateQuantity(String code, String raw) {
    final int? parsed = int.tryParse(raw);
    setState(() {
      final CustomFieldColorEntry? current = _entries[code];
      if (current == null) {
        return;
      }
      final int? normalized = parsed == null ? null : parsed;
      _entries[code] = CustomFieldColorEntry(
        code: code,
        quantity: normalized,
      );
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
    final String displayLabel = label ?? '#$code';

    return ChoiceChip(
      label: Text(displayLabel),
      avatar: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.black.withOpacity(0.18), width: 1),
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
    final int? quantity = entry.quantity;

    final String quantityLabel =
        quantity != null && quantity > 0 ? ' × $quantity' : '';

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
              border: Border.all(color: Colors.black.withOpacity(0.18), width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '#${entry.code}$quantityLabel',
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
    final int? quantity = entry?.quantity;
    final String label =
        '#$code${quantity != null && quantity > 0 ? ' × $quantity' : ''}';

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
          border: Border.all(color: Colors.black.withOpacity(0.18), width: 1),
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