import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/item_filter_model.dart';

class SideFilterPanel extends StatefulWidget {
  final ItemFilterModel? initialFilter;
  final String? initialSortBy;
  final List<String>? categoryIds;
  final void Function(ItemFilterModel filter, String? sortBy) onApply;

  const SideFilterPanel({
    super.key,
    required this.initialFilter,
    required this.initialSortBy,
    required this.categoryIds,
    required this.onApply,
  });

  @override
  State<SideFilterPanel> createState() => _SideFilterPanelState();
}

class _SideFilterPanelState extends State<SideFilterPanel> {
  late TextEditingController minPriceController;
  late TextEditingController maxPriceController;
  late TextEditingController currencyController;
  String? selectedCurrency;
  String? sortBy;
  Map<String, dynamic> customFields = {};
  bool onlyDiscount = false;

  static const _txtFilters = '\u0627\u0644\u062A\u0635\u0641\u064A\u0627\u062A';
  static const _txtSort = '\u0627\u0644\u062A\u0631\u062A\u064A\u0628';
  static const _txtPrice = '\u0627\u0644\u0633\u0639\u0631';
  static const _txtPriceMin =
      '\u0627\u0644\u0633\u0639\u0631 \u0627\u0644\u0623\u062F\u0646\u0649';
  static const _txtPriceMax =
      '\u0627\u0644\u0633\u0639\u0631 \u0627\u0644\u0623\u0639\u0644\u0649';
  static const _txtCurrency = '\u0627\u0644\u0639\u0645\u0644\u0629';
  static const _txtDiscounts =
      '\u0627\u0644\u062E\u0635\u0648\u0645\u0627\u062A';
  static const _txtShowDiscountOnly =
      '\u0639\u0631\u0636 \u0627\u0644\u0645\u0646\u062A\u062C\u0627\u062A \u0627\u0644\u062A\u064A \u0639\u0644\u064A\u0647\u0627 \u062E\u0635\u0645 \u0641\u0642\u0637';
  static const _txtAttributes = '\u0627\u0644\u0633\u0645\u0627\u062A';
  static const _txtSizes = '\u0627\u0644\u0645\u0642\u0627\u0633\u0627\u062A';
  static const _txtColors = '\u0627\u0644\u0623\u0644\u0648\u0627\u0646';
  static const _txtOtherAttrs =
      '\u0633\u0645\u0627\u062A \u0623\u062E\u0631\u0649';
  static const _txtNoAttrs =
      '\u0644\u0627 \u062A\u0648\u062C\u062F \u0633\u0645\u0627\u062A \u0644\u0647\u0630\u0627 \u0627\u0644\u0642\u0633\u0645';
  static const _txtNoOptions =
      '\u0644\u0627 \u062A\u0648\u062C\u062F \u062E\u064A\u0627\u0631\u0627\u062A';
  static const _txtNoColors =
      '\u0644\u0627 \u062A\u0648\u062C\u062F \u0623\u0644\u0648\u0627\u0646';
  static const _txtReset =
      '\u0625\u0639\u0627\u062F\u0629 \u062A\u0639\u064A\u064A\u0646';
  static const _txtApply = '\u062A\u0637\u0628\u064A\u0642';
  static const _defaultColorOptions = [
    'FF7F50', // ظ…طھط¹ط¯ط¯ ط§ظ„ط£ظ„ظˆط§ظ† (طھط¯ط±ط¬)
    'FF0000', // Red
    '00A3FF', // Blue
    '2ECC71', // Green
    'FF8C00', // Orange
    'FFC107', // Amber
    '6C63FF', // Indigo
    '000000', // Black
    'FFFFFF', // White
    '9E9E9E', // Gray
    'FF69B4', // Pink
    '5D4037', // Brown
    '00BCD4', // Cyan
    '673AB7', // Dark Purple
    'D4AF37', // Gold
    'C0C0C0', // Silver
  ];
  static const _defaultSizeOptions = [
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'XXXL',
    'XXS',
    'XXXXL'
  ];

  @override
  void initState() {
    super.initState();
    minPriceController =
        TextEditingController(text: widget.initialFilter?.minPrice ?? '');
    maxPriceController =
        TextEditingController(text: widget.initialFilter?.maxPrice ?? '');
    selectedCurrency = widget.initialFilter?.currency?.trim();
    currencyController = TextEditingController(text: selectedCurrency ?? '');
    sortBy = widget.initialSortBy;
    customFields =
        Map<String, dynamic>.from(widget.initialFilter?.customFields ?? {});
    onlyDiscount = customFields['has_discount'] == true;

    final ids = widget.categoryIds?.where((e) => e.isNotEmpty).toList() ?? [];
    if (ids.isNotEmpty) {
      context
          .read<FetchCustomFieldsCubit>()
          .fetchCustomFields(categoryIds: ids.join(','));
    }
  }

  @override
  void dispose() {
    minPriceController.dispose();
    maxPriceController.dispose();
    currencyController.dispose();
    super.dispose();
  }

  void _apply() {
    final ItemFilterModel updated =
        (widget.initialFilter ?? ItemFilterModel(categoryId: null)).copyWith(
      minPrice: minPriceController.text.trim(),
      maxPrice: maxPriceController.text.trim(),
      currency: (selectedCurrency ?? currencyController.text).trim().isEmpty
          ? null
          : (selectedCurrency ?? currencyController.text).trim(),
      postedSince: sortBy,
      customFields: customFields.isNotEmpty ? customFields : null,
    );
    widget.onApply(updated, sortBy);
    Navigator.of(context).maybePop(true);
  }

  void _reset() {
    minPriceController.clear();
    maxPriceController.clear();
    currencyController.clear();
    selectedCurrency = null;
    sortBy = null;
    customFields.clear();
    onlyDiscount = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double panelWidth = MediaQuery.of(context).size.width * 0.86;
    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(4, 0),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  _txtFilters,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(false),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(_txtSort),
                  Wrap(
                    spacing: 8,
                    children: [
                      _chip(
                          '\u0627\u0644\u0623\u062D\u062F\u062B', 'new-to-old'),
                      _chip(
                          '\u0627\u0644\u0623\u0642\u062F\u0645', 'old-to-new'),
                      _chip(
                          '\u0627\u0644\u0623\u0639\u0644\u0649 \u0633\u0639\u0631\u0627',
                          'price-high-to-low'),
                      _chip(
                          '\u0627\u0644\u0623\u0642\u0644 \u0633\u0639\u0631\u0627',
                          'price-low-to-high'),
                      _chip(
                          '\u0627\u0644\u0623\u0643\u062B\u0631 \u0645\u0634\u0627\u0647\u062F\u0629',
                          'most-viewed'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(_txtPrice),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          controller: minPriceController,
                          label: _txtPriceMin,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _textField(
                          controller: maxPriceController,
                          label: _txtPriceMax,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _sectionTitle(_txtCurrency),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _currencyChip('YER',
                          '\u0627\u0644\u0631\u064a\u0627\u0644 \u0627\u0644\u064a\u0645\u0646\u064a'),
                      _currencyChip('SAR',
                          '\u0627\u0644\u0631\u064a\u0627\u0644 \u0627\u0644\u0633\u0639\u0648\u062f\u064a'),
                      _currencyChip(
                          'USD', '\u0627\u0644\u062f\u0648\u0644\u0627\u0631'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(_txtDiscounts),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: onlyDiscount,
                    onChanged: (v) {
                      setState(() {
                        onlyDiscount = v;
                        if (v) {
                          customFields['has_discount'] = true;
                        } else {
                          customFields.remove('has_discount');
                        }
                      });
                    },
                    title: const Text(_txtShowDiscountOnly),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(_txtAttributes),
                  _buildCustomAttributes(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text(_txtReset),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: const Text(_txtApply),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final bool active = sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) {
        setState(() {
          sortBy = value;
        });
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _currencyChip(String code, [String? label]) {
    final active = (selectedCurrency ?? '').toUpperCase() == code.toUpperCase();
    return ChoiceChip(
      label: Text(label ?? code),
      selected: active,
      onSelected: (_) {
        setState(() {
          selectedCurrency = code;
          currencyController.text = code;
        });
      },
    );
  }

  Widget _buildCustomAttributes() {
    return BlocBuilder<FetchCustomFieldsCubit, FetchCustomFieldState>(
      builder: (context, state) {
        if (state is FetchCustomFieldInProgress ||
            state is FetchCustomFieldInitial) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        if (state is FetchCustomFieldFail) {
          return const Text(
              '\u062A\u0639\u0630\u0631 \u062A\u062D\u0645\u064A\u0644 \u0627\u0644\u0633\u0645\u0627\u062A');
        }
        if (state is FetchCustomFieldSuccess) {
          return _buildAttributesBody(state.fields);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAttributesBody(List<CustomFieldModel> fields) {
    final List<CustomFieldModel> colorFields = [];
    final List<CustomFieldModel> sizeFields = [];
    final List<CustomFieldModel> otherFields = [];

    for (final f in fields) {
      if (_isColorField(f)) {
        colorFields.add(f);
      } else if (_isSizeField(f)) {
        sizeFields.add(f);
      } else {
        otherFields.add(f);
      }
    }

    if (sizeFields.isEmpty) {
      final fallbackSizes = otherFields.where((f) {
        final opts = _fieldOptions(f);
        return opts.isNotEmpty && _looksLikeSizeOptions(opts);
      }).toList();
      if (fallbackSizes.isNotEmpty) {
        sizeFields.addAll(fallbackSizes);
        otherFields.removeWhere((f) => fallbackSizes.contains(f));
      }
    }

    if (sizeFields.isEmpty) {
      sizeFields.add(CustomFieldModel(
        id: -1,
        name: _txtSizes,
        type: 'size',
        values: _defaultSizeOptions,
      ));
    }

    if (colorFields.isEmpty) {
      colorFields.add(CustomFieldModel(
        id: -2,
        name: _txtColors,
        type: 'color',
        values: _defaultColorOptions,
      ));
    }

    final List<Widget> children = [];

    if (sizeFields.isNotEmpty) {
      children.addAll(sizeFields.map(_buildSizeField));
      children.add(const SizedBox(height: 10));
    }

    if (colorFields.isNotEmpty) {
      children.addAll(colorFields.map(_buildColorField));
      children.add(const SizedBox(height: 10));
    }

    if (children.isEmpty) {
      return const Text(_txtNoAttrs);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildSizeField(CustomFieldModel f) {
    final key = f.id?.toString() ?? 'size';
    final options =
        _fieldOptions(f).isNotEmpty ? _fieldOptions(f) : _defaultSizeOptions;
    final selected = customFields[key];

    return _panelTile(
      title: f.name ?? '\u0645\u0642\u0627\u0633',
      subtitle: selected?.toString(),
      child: options.isEmpty
          ? const Text(_txtNoOptions)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map(
                    (opt) => ChoiceChip(
                      label: Text(opt),
                      selected: selected == opt,
                      onSelected: (_) {
                        setState(() {
                          if (selected == opt) {
                            customFields.remove(key);
                          } else {
                            customFields[key] = opt;
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildColorField(CustomFieldModel f) {
    final key = f.id?.toString() ?? 'color';
    final options = _colorOptions(f);
    final selected = (customFields[key] ?? '').toString();
    final selectedLabel =
        selected.isEmpty ? null : _colorDisplayName(_normalizedHex(selected));

    return _panelTile(
      title: f.name ?? _txtColors,
      subtitle: selectedLabel,
      child: options.isEmpty
          ? const Text(_txtNoColors)
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map(
                (opt) {
                  final normalized = _normalizedHex(opt);
                  final bool isSelected =
                      selected.toLowerCase() == normalized.toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          customFields.remove(key);
                        } else {
                          customFields[key] = normalized;
                        }
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: normalized == 'FF7F50'
                                ? null
                                : _hexToColor(normalized),
                            gradient: normalized == 'FF7F50'
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF5722),
                                      Color(0xFF9C27B0),
                                      Color(0xFF2196F3),
                                      Color(0xFF4CAF50),
                                      Color(0xFFFFC107),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            border: Border.all(
                              color: Colors.black.withOpacity(0.12),
                              width: 0.6,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 4,
                                      spreadRadius: 0.2,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _colorDisplayName(normalized),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black87),
                        ),
                      ],
                    ),
                  );
                },
              ).toList(),
            ),
    );
  }

  Widget _buildGenericField(CustomFieldModel f) {
    final key = f.id?.toString();
    if (key == null) return const SizedBox.shrink();
    final options = _fieldOptions(f);
    final selected = customFields[key];

    return _panelTile(
      title: f.name ?? '\u062E\u0627\u0646\u0629',
      subtitle: selected?.toString(),
      child: options.isEmpty
          ? const Text(_txtNoOptions)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map(
                    (opt) => ChoiceChip(
                      label: Text(opt),
                      selected: selected == opt,
                      onSelected: (_) {
                        setState(() {
                          if (selected == opt) {
                            customFields.remove(key);
                          } else {
                            customFields[key] = opt;
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _panelTile(
      {required String title, String? subtitle, required Widget child}) {
    final String badge = subtitle ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          title: Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              if (badge.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 13),
                  ),
                ),
            ],
          ),
          children: [child],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  List<String> _fieldOptions(CustomFieldModel f) {
    final raw = f.values.isNotEmpty ? f.values : f.value;
    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<String> _colorOptions(CustomFieldModel f) {
    if (f.colorEntries.isNotEmpty) {
      return f.colorEntries.map((e) => e.code).toList();
    }
    return _fieldOptions(f);
  }

  Widget _colorDot(String hex) {
    final Color c = _hexToColor(hex);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c,
        border: Border.all(color: Colors.transparent, width: 0.5),
      ),
    );
  }

  Color _hexToColor(String code) {
    final value = _normalizedHex(code);
    return Color(int.parse('0xFF$value'));
  }

  String _normalizedHex(String code) {
    final cleaned = code.replaceAll('#', '').trim();
    return cleaned.padLeft(6, '0').toUpperCase();
  }

  String _colorDisplayName(String hex) {
    const Map<String, String> arabicNames = {
      'FF0000': 'أحمر',
      '00A3FF': 'أزرق',
      '2ECC71': 'أخضر',
      'FF8C00': 'برتقالي',
      'FFC107': 'أصفر',
      '6C63FF': 'بنفسجي',
      '000000': 'أسود',
      'FFFFFF': 'أبيض',
      '9E9E9E': 'رمادي',
      'FF69B4': 'وردي',
      '5D4037': 'بني',
      '00BCD4': 'سماوي',
      '673AB7': 'بنفسجي داكن',
      'D4AF37': 'ذهبي',
      'C0C0C0': 'فضي',
      'FF7F50': 'متعدد الألوان',
    };
    final key = hex.toUpperCase();
    return arabicNames[key] ?? '\u0644\u0648\u0646';
  }

  bool _isSizeField(CustomFieldModel f) {
    final type = (f.type ?? '').toLowerCase();
    final name = (f.name ?? '').toLowerCase();
    const sizeKeywords = [
      'size',
      '\u0645\u0642\u0627\u0633',
      '\u0627\u0644\u0645\u0642\u0627\u0633',
      '\u0642\u064A\u0627\u0633',
      '\u0627\u0644\u062D\u062C\u0645',
      '\u062D\u062C\u0645',
      '\u0645\u0642\u0627\u0633\u0627\u062A'
    ];
    final hasKeyword =
        sizeKeywords.any((k) => name.contains(k) || type.contains(k));
    if (hasKeyword) return true;
    final opts = _fieldOptions(f);
    final looksLikeSizes = opts.isNotEmpty && _looksLikeSizeOptions(opts);
    return looksLikeSizes;
  }

  bool _looksLikeSizeOptions(List<String> opts) {
    final knownSizes = _defaultSizeOptions.map((e) => e.toLowerCase()).toSet();
    final normalized = opts.map((o) => o.trim().toLowerCase()).toList();
    if (normalized.isEmpty) return false;
    final shortEnough = normalized.every((o) => o.length <= 4);
    final allKnown = normalized.every(
        (o) => knownSizes.contains(o) || RegExp(r'^[0-9]+$').hasMatch(o));
    return shortEnough || allKnown;
  }

  bool _isColorField(CustomFieldModel f) {
    final type = (f.type ?? '').toLowerCase();
    final name = (f.name ?? '').toLowerCase();
    return type.contains('color') ||
        name.contains('\u0644\u0648\u0646') ||
        f.colorEntries.isNotEmpty;
  }
}
