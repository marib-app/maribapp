import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:marib/data/constants/color_catalog.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/fields/custom_color_field.dart'
    show ColorWheelPickerSheet;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class CustomColorFieldAttributes extends CustomField {
  @override
  String type = 'color';

  static final List<Map<String, String>> basePalette =
      ColorCatalog.basePalette;

  final LinkedHashMap<String, CustomFieldColorEntry> _entries =
  LinkedHashMap<String, CustomFieldColorEntry>();
  final Set<String> _custom = <String>{};

  String get _key {
    final dynamic rawKey = parameters['key'];
    if (rawKey is String && rawKey.trim().isNotEmpty) {
      return rawKey.trim();
    }
    final dynamic id = parameters['id'];
    if (id is String && id.trim().isNotEmpty) {
      return id.trim();
    }
    if (id is num) {
      return 'cf${id.toInt()}';
    }
    return 'colors';
  }

  String get _title => parameters['name']?.toString() ?? 'ألوان السمة';

  String? get _description {
    for (final key in ['description', 'note', 'notes', 'hint']) {
      final dynamic value = parameters[key];
      if (value != null) {
        final String text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  String? get _iconPath {
    for (final key in ['icon', 'image', 'iconPath', 'img']) {
      final dynamic value = parameters[key];
      if (value != null) {
        final String path = value.toString().trim();
        if (path.isNotEmpty) {
          return path;
        }
      }
    }
    return null;
  }

  bool get _isRequired =>
      parameters['required'] == true || parameters['required'] == 1;

  int? get _maxCount {
    final dynamic max = parameters['max'];
    if (max is int && max > 0) {
      return max;
    }
    if (max is String) {
      final int? parsed = int.tryParse(max);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
  }

  @override
  void init() {
    final dynamic initialRaw = parameters['color_entries'] ?? parameters['value'];
    final List<CustomFieldColorEntry> parsedEntries =
    parseCustomFieldColorEntries(initialRaw);

    _entries
      ..clear()
      ..addEntries(parsedEntries.map((CustomFieldColorEntry entry) =>
          MapEntry(entry.code.toUpperCase(), entry)));

    final dynamic customRaw = parameters['custom_colors'];
    if (customRaw is Iterable) {
      for (final dynamic value in customRaw) {
        final String? hex = _sanitizeHex(value);
        if (hex != null) {
          _custom.add(hex);
        }
      }
    }

    _sync();
    super.init();
  }

  @override
  Widget render() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorPalette = context.color;


    final int selectedCount = _entries.length;
    final Iterable<CustomFieldColorEntry> entries = _entries.values;

    Widget iconBadge() {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorPalette.secondaryColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorPalette.borderColor, width: 1),
        ),
        alignment: Alignment.center,
        child: _iconPath != null
            ? (_iconPath!.toLowerCase().endsWith('.svg')
            ? UiUtils.getSvg(_iconPath!, height: 24, width: 24)
            : UiUtils.getImage(_iconPath!, height: 24, width: 24))
            : Icon(Icons.palette_outlined,
            size: 22, color: colorPalette.textDefaultColor),
      );
    }

    Widget buildSummary() {
      if (entries.isEmpty) {
        return Text(
          'لم يتم تحديد ألوان بعد.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.hintColor.withOpacity(.8)),
        );
      }

      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: entries.map((CustomFieldColorEntry entry) {
          final Color color = _colorFromHex(entry.code);
          final int quantity = entry.quantity ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorPalette.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorPalette.borderColor.withOpacity(.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border:
                    Border.all(color: Colors.black.withOpacity(0.18), width: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${entry.code}${quantity > 0 ? ' × $quantity' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorPalette.textDefaultColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      );
    }

    return FormField<List<Map<String, dynamic>>>(
      validator: (_) =>
      (_isRequired && _entries.isEmpty) ? 'يرجى اختيار لون واحد على الأقل' : null,
      builder: (FormFieldState<List<Map<String, dynamic>>> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  iconBadge(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_isRequired)
                    Text(
                      ' *',
                      style: TextStyle(
                        color: context.color.territoryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            if (_description != null) ...[
              const SizedBox(height: 6),
              Text(
                _description!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(.75),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openSheet,
                icon: const Icon(Icons.color_lens_rounded),
                label: Text(
                  selectedCount > 0
                      ? 'الألوان المختارة :  $selectedCount'
                      : 'اختيار الألوان',
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: colorPalette.secondaryColor,
                  padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: colorPalette.borderColor),
                  foregroundColor: colorPalette.textDefaultColor,
                ).copyWith(
                  overlayColor: MaterialStatePropertyAll(
                    theme.colorScheme.onSurface.withOpacity(.06),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            buildSummary(),
            if (state.hasError) ...[
              const SizedBox(height: 6),
              Text(
                state.errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _openSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext _) {
        return _ColorAttributeSheet(
          title: 'إدارة ألوان السمة',
          entries: LinkedHashMap<String, CustomFieldColorEntry>.from(_entries),
          customCodes: Set<String>.from(_custom),
          maxCount: _maxCount,
          onSave: (LinkedHashMap<String, CustomFieldColorEntry> entries,
              Set<String> customCodes) {
            _entries
              ..clear()
              ..addEntries(entries.entries);
            _custom
              ..clear()
              ..addAll(customCodes);
            _sync();
            update(() {});
          },
        );
      },
    );
  }

  void _sync() {
    CustomField.fieldsData[_key] = _entries.values
        .map((CustomFieldColorEntry entry) => entry.toJson())
        .toList(growable: false);
  }

  String? _sanitizeHex(dynamic value) {
    if (value == null) {
      return null;
    }
    final String hex = ColorCatalog.sanitizeHex(value.toString());
    return _isHex6(hex) ? hex : null;
  }

  bool _isHex6(String value) => RegExp(r'^[0-9A-F]{6}$').hasMatch(value);

  Color _colorFromHex(String hex6) =>
      Color(int.parse('0xFF${hex6.toUpperCase()}'));
}

class _ColorAttributeSheet extends StatefulWidget {
  const _ColorAttributeSheet({
    required this.title,
    required this.entries,
    required this.customCodes,
    required this.onSave,
    this.maxCount,
  });

  final String title;
  final LinkedHashMap<String, CustomFieldColorEntry> entries;
  final Set<String> customCodes;
  final int? maxCount;
  final void Function(LinkedHashMap<String, CustomFieldColorEntry>, Set<String>)
  onSave;

  @override
  State<_ColorAttributeSheet> createState() => _ColorAttributeSheetState();
}

class _ColorAttributeSheetState extends State<_ColorAttributeSheet> {
  late LinkedHashMap<String, CustomFieldColorEntry> _entries;
  late Set<String> _customCodes;
  bool _showCommonOnly = true;

  static const Set<String> _commonHex = {
    'FFFFFF',
    '000000',
    '808080',
    'C0C0C0',
    'D4AF37',
    'FF0000',
    '0000FF',
    '00A651',
    'FFFF00',
    'FFA500',
    '8B4513',
    'F5F5DC',
    '000080',
    'FFC0CB',
    '40E0D0',
  };

  @override
  void initState() {
    _entries = LinkedHashMap<String, CustomFieldColorEntry>.from(widget.entries);
    _customCodes = Set<String>.from(widget.customCodes);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    final List<Map<String, String>> paletteSource =
    widget.maxCount != null && _entries.length >= widget.maxCount!
        ? _filteredPalette().where(_isSelected).toList(growable: false)
        : _filteredPalette();

    final List<_ColorDescriptor> selectedDescriptors = _entries.values
        .map((CustomFieldColorEntry entry) => _ColorDescriptor(entry.code,
        color: _colorFromHex(entry.code),
        label: '#${entry.code}',
        quantity: entry.quantity ?? 0,
        isCustom: _customCodes.contains(entry.code)))
        .toList(growable: false);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .92,
          ),
          child: Material(
            color: palette.secondaryColor,
            elevation: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  height: 5,
                  width: 48,
                  decoration: BoxDecoration(
                    color: palette.borderColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                _buildHeader(theme),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أضف الألوان المتوفرة مع تحديد كمية كل لون.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                        const SizedBox(height: 16),
                        _buildPaletteToggle(theme),
                        const SizedBox(height: 12),
                        _ColorPaletteGrid(
                          palette: paletteSource,
                          isSelected: _isSelected,
                          onTap: _toggleColor,
                        ),
                        const SizedBox(height: 16),
                        _buildCustomColorsSection(theme),
                        const SizedBox(height: 16),
                        _buildSelectedList(theme, selectedDescriptors),
                      ],
                    ),
                  ),
                ),
                _buildFooter(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border:
        Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.palette_rounded, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteToggle(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('الأكثر شيوعًا'),
          selected: _showCommonOnly,
          onSelected: (bool value) {
            setState(() => _showCommonOnly = true);
          },
        ),
        const SizedBox(width: 12),
        ChoiceChip(
          label: const Text('كامل اللوحة'),
          selected: !_showCommonOnly,
          onSelected: (bool value) {
            setState(() => _showCommonOnly = false);
          },
        ),
      ],
    );
  }

  Widget _buildCustomColorsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ألوان مخصّصة',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openCustomColorPicker,
              icon: const Icon(Icons.add),
              label: const Text('إضافة لون'),
            ),
          ],
        ),
        if (_customCodes.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _customCodes.map((String code) {
              final Color color = _colorFromHex(code);
              return _RemovableColorDot(
                color: color,
                onDelete: () => _removeCustomColor(code),
              );
            }).toList(growable: false),
          )
        else
          Text(
            'لم تتم إضافة ألوان مخصّصة.',
            style:
            theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
      ],
    );
  }

  Widget _buildSelectedList(
      ThemeData theme,
      List<_ColorDescriptor> selectedDescriptors,
      ) {
    if (selectedDescriptors.isEmpty) {
      return Text(
        'حدد لونًا من الأعلى لإضافته إلى السمة.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الألوان المختارة',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: selectedDescriptors.length,
          separatorBuilder: (_, __) =>
              Divider(color: theme.dividerColor.withOpacity(.3)),
          itemBuilder: (BuildContext context, int index) {
            final _ColorDescriptor descriptor = selectedDescriptors[index];
            final CustomFieldColorEntry entry =
                _entries[descriptor.code] ?? descriptor.toEntry();
            return _SelectedColorTile(
              descriptor: descriptor,
              entry: entry,
              onQuantityChanged: (int quantity) =>
                  _setQuantity(descriptor.code, quantity),
              onRemove: () => _toggleColor(descriptor.code),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                label: const Text('إلغاء'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onSave(
                    LinkedHashMap<String, CustomFieldColorEntry>.from(_entries),
                    Set<String>.from(_customCodes),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _filteredPalette() {
    final Iterable<Map<String, String>> palette =
        CustomColorFieldAttributes.basePalette;

    if (_showCommonOnly) {
      return palette
          .where((Map<String, String> entry) {
        final String? hex = entry['hex'];
        if (hex == null) {
          return false;
        }
        return _commonHex.contains(hex.toUpperCase());
      })
          .toList(growable: false);
    }

    return palette.toList(growable: false);
  }

  bool _isSelected(Map<String, String> entry) {
    final String? hex = entry['hex'];
    if (hex == null) {
      return false;
    }
    return _entries.containsKey(ColorCatalog.sanitizeHex(hex));
  }

  void _toggleColor(String hex) {
    final String code = ColorCatalog.sanitizeHex(hex);
    if (code.isEmpty) {
      return;
    }

    setState(() {
      if (_entries.containsKey(code)) {
        _entries.remove(code);
        _customCodes.remove(code);
      } else {
        if (widget.maxCount != null &&
            _entries.length >= widget.maxCount!) {
          return;
        }
        _entries[code] = CustomFieldColorEntry(code: code, quantity: 0);
      }
    });
  }

  void _setQuantity(String code, int quantity) {
    final CustomFieldColorEntry? current = _entries[code];
    if (current == null) {
      return;
    }

    final int normalized = math.max(0, quantity);
    setState(() {
      _entries[code] = current.copyWith(quantity: normalized);
    });
  }

  Future<void> _openCustomColorPicker() async {
    final String? hex = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ColorWheelPickerSheet(),
    );

    if (hex == null || hex.isEmpty) {
      return;
    }

    final String code = ColorCatalog.sanitizeHex(hex);
    if (code.isEmpty) {
      return;
    }

    setState(() {
      if (!_entries.containsKey(code)) {
        if (widget.maxCount != null &&
            _entries.length >= widget.maxCount!) {
          return;
        }
        _entries[code] = CustomFieldColorEntry(code: code, quantity: 0);
      }
      _customCodes.add(code);
    });
  }

  void _removeCustomColor(String code) {
    setState(() {
      _customCodes.remove(code);
      _entries.remove(code);
    });
  }

  Color _colorFromHex(String hex) =>
      Color(int.parse('0xFF${hex.toUpperCase()}'));
}

class _ColorPaletteGrid extends StatelessWidget {
  const _ColorPaletteGrid({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  final List<Map<String, String>> palette;
  final bool Function(Map<String, String>) isSelected;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (palette.isEmpty) {
      return Text(
        'لا توجد ألوان متاحة في هذه اللوحة.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: palette.map((Map<String, String> entry) {
        final String hex = entry['hex'] ?? '';
        final String name = entry['name'] ?? '#$hex';
        final bool selected = isSelected(entry);
        final Color color = Color(int.parse('0xFF${hex.toUpperCase()}'));

        return GestureDetector(
          onTap: () => onTap(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withOpacity(.12)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.dividerColor.withOpacity(.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.black.withOpacity(.15)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _SelectedColorTile extends StatelessWidget {
  const _SelectedColorTile({
    required this.descriptor,
    required this.entry,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final _ColorDescriptor descriptor;
  final CustomFieldColorEntry entry;
  final void Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final TextEditingController controller = TextEditingController(
      text: (entry.quantity ?? 0).toString(),
    );

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: descriptor.color,
            border: Border.all(color: Colors.black.withOpacity(.18)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                descriptor.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _QuantityButton(
                    icon: Icons.remove,
                    onTap: () {
                      final int current = entry.quantity ?? 0;
                      final int next = math.max(0, current - 1);
                      onQuantityChanged(next);
                    },
                  ),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                      ),
                      onChanged: (String value) {
                        final int? parsed = int.tryParse(value);
                        if (parsed != null) {
                          onQuantityChanged(math.max(0, parsed));
                        }
                      },
                    ),
                  ),
                  _QuantityButton(
                    icon: Icons.add,
                    onTap: () {
                      final int current = entry.quantity ?? 0;
                      final int next = current + 1;
                      onQuantityChanged(next);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'إزالة اللون',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _RemovableColorDot extends StatelessWidget {
  const _RemovableColorDot({required this.color, required this.onDelete});

  final Color color;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withOpacity(.18)),
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onDelete,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.7),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDescriptor {
  _ColorDescriptor(
      this.code, {
        required this.color,
        required this.label,
        required this.quantity,
        required this.isCustom,
      });

  final String code;
  final Color color;
  final String label;
  final int quantity;
  final bool isCustom;

  CustomFieldColorEntry toEntry() =>
      CustomFieldColorEntry(code: code, quantity: quantity);
}