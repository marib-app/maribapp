import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/constants/color_catalog.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/data/cubits/item/product_management_cubit.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/ui/theme/theme.dart';

import 'package:marib/ui/screens/item/purchase_options/product_management/color_attribute_editor.dart';
import 'package:marib/ui/screens/item/purchase_options/product_management/product_management_color_utils.dart';
import 'package:marib/ui/screens/item/purchase_options/product_management/product_management_input_decorations.dart';
import 'package:marib/ui/screens/item/purchase_options/product_management/widgets/common_widgets.dart';

class AttributesTab extends StatefulWidget {
  const AttributesTab({super.key, required this.state});

  final ProductManagementState state;

  @override
  State<AttributesTab> createState() => _AttributesTabState();
}

class _AttributesTabState extends State<AttributesTab> {
  final Map<String, TextEditingController> _nameControllers =
      <String, TextEditingController>{};
  final Map<String, List<TextEditingController>> _optionControllers =
      <String, List<TextEditingController>>{};

  static const List<String> _defaultSizeCatalog = <String>[
    'XS',
    'S',
    'M',
    'L',
    'XL',
    '2XL',
    '3XL',
    '4XL',
    '5XL',
    '6XL',
    '28',
    '30',
    '32',
    '34',
    '36',
    '38',
    '40',
    '42',
    '44',
    '46',
    '48',
    '50',
  ];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant AttributesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.managedAttributes != widget.state.managedAttributes ||
        oldWidget.state.attributeSelections !=
            widget.state.attributeSelections) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final List<TextEditingController> controllers
        in _optionControllers.values) {
      for (final TextEditingController controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _syncControllers() {
    final Set<String> keys = widget.state.managedAttributes
        .map((ManagedPurchaseAttribute attribute) => attribute.key)
        .toSet();

    final List<String> removedNameKeys = _nameControllers.keys
        .where((String key) => !keys.contains(key))
        .toList();
    for (final String key in removedNameKeys) {
      _nameControllers.remove(key)?.dispose();
    }

    final List<String> removedOptionKeys = _optionControllers.keys
        .where((String key) => !keys.contains(key))
        .toList();
    for (final String key in removedOptionKeys) {
      final List<TextEditingController>? controllers =
          _optionControllers.remove(key);
      if (controllers != null) {
        for (final TextEditingController controller in controllers) {
          controller.dispose();
        }
      }
    }

    for (final ManagedPurchaseAttribute attribute
        in widget.state.managedAttributes) {
      _ensureNameController(attribute.key, attribute.name);
      final List<TextEditingController> controllers = _optionControllers
          .putIfAbsent(attribute.key, () => <TextEditingController>[]);
      final int optionsLength = attribute.options.length;

      if (controllers.length > optionsLength) {
        final Iterable<TextEditingController> toDispose =
            controllers.sublist(optionsLength);
        for (final TextEditingController controller in toDispose) {
          controller.dispose();
        }
        controllers.removeRange(optionsLength, controllers.length);
      }
      while (controllers.length < optionsLength) {
        controllers.add(TextEditingController());
      }

      for (int index = 0; index < optionsLength; index++) {
        final TextEditingController controller = controllers[index];
        final String optionValue = attribute.options[index];
        if (controller.text != optionValue) {
          controller.text = optionValue;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }
      }
    }
  }

  TextEditingController _ensureNameController(String key, String value) {
    final TextEditingController controller =
        _nameControllers.putIfAbsent(key, () => TextEditingController());
    if (controller.text != value) {
      controller.text = value;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
    return controller;
  }

  String _displayColorName(BuildContext context, String code) {
    final String label = ColorCatalog.nameForHex(code, context: context).trim();
    if (label.isEmpty) {
      return 'لون';
    }
    if (label.startsWith('#')) {
      return 'لون مخصص';
    }
    return label;
  }

  Widget _buildMorePill(BuildContext context, int count) {
    final ColorScheme palette = context.color;
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.primaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderColor.withValues(alpha: 0.45)),
      ),
      child: Text(
        '+$count',
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: palette.textDefaultColor,
        ),
      ),
    );
  }

  Widget _buildColorPill(BuildContext context, CustomFieldColorEntry entry) {
    final ColorScheme palette = context.color;
    final ThemeData theme = Theme.of(context);
    final Color dotColor =
        ProductManagementColorUtils.colorFromHex(entry.code) ??
            palette.borderColor;
    final String label = _displayColorName(context, entry.code);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.primaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              border: Border.all(
                color: palette.textDefaultColor.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: palette.textDefaultColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizePill(BuildContext context, String size) {
    final ColorScheme palette = context.color;
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.territoryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: palette.territoryColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        size,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: palette.territoryColor,
        ),
      ),
    );
  }

  Future<void> _confirmRemoveAttribute(
    BuildContext context,
    ProductManagementCubit cubit,
    ManagedPurchaseAttribute attribute,
  ) async {
    final String attributeName = switch (attribute.type) {
      ManagedAttributeType.color => 'الألوان المتوفرة',
      ManagedAttributeType.size => 'المقاسات المتاحة',
      ManagedAttributeType.custom => attribute.name.trim(),
    };

    final String message = attributeName.isEmpty
        ? 'هل أنت متأكد من حذف هذه السمة؟'
        : 'هل أنت متأكد من حذف سمة "$attributeName"؟';

    final bool? confirmed = await UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        title: 'تأكيد الحذف',
        cancelButtonName: 'إلغاء',
        acceptButtonName: 'حذف',
        cancelTextColor: context.color.textColorDark,
        content: Text(message),
      ),
    ) as bool?;

    if (confirmed == true) {
      cubit.removeAttribute(attribute.key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProductManagementState state = widget.state;
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();

    if (state.loadingAttributes) {
      return const Center(child: CircularProgressIndicator());
    }

    final ColorScheme palette = context.color;
    const EdgeInsets listPadding = EdgeInsets.fromLTRB(16, 16, 16, 96);

    final Widget body =
        (state.availableAttributes.isEmpty && state.managedAttributes.isEmpty)
            ? ListView(
                padding: listPadding,
                children: const <Widget>[
                  ProductManagementEmptyState(
                    message:
                        'يمكنك إضافة الألوان المتوفرة أو المقاسات المتاحة أو أي خيارات شراء أخرى من زر الإضافة العائم بالأسفل.',
                  ),
                ],
              )
            : ListView(
                padding: listPadding,
                children: <Widget>[
                  _buildManagedAttributes(context, cubit, state),
                  const SizedBox(height: 16),
                  _buildAvailableAttributes(context, cubit, state),
                ],
              );

    return Stack(
      children: <Widget>[
        body,
        Positioned(
          left: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: FloatingActionButton(
              heroTag: 'product-management-add-attribute',
              mini: true,
              tooltip: 'إضافة سمة جديدة',
              backgroundColor: palette.territoryColor,
              foregroundColor: palette.buttonColor,
              onPressed: () => _showAddAttributeMenu(context),
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManagedAttributes(
    BuildContext context,
    ProductManagementCubit cubit,
    ProductManagementState state,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    if (state.managedAttributes.isEmpty) {
      return Card(
        color: palette.secondaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.borderColor.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'لا توجد سمات مُدارة حاليًا',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'أضف سمات جديدة من القائمة أدناه لتخصيص خيارات الشراء.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textDefaultColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'السمات المُدارة',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...state.managedAttributes
            .map((ManagedPurchaseAttribute attribute) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildManagedAttributeCard(
                    context,
                    cubit,
                    state,
                    attribute,
                  ),
                ))
            .toList(growable: false),
      ],
    );
  }

  Widget _buildManagedAttributeCard(
    BuildContext context,
    ProductManagementCubit cubit,
    ProductManagementState state,
    ManagedPurchaseAttribute attribute,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    if (attribute.type == ManagedAttributeType.color) {
      final Map<String, CustomFieldColorEntry> unique =
          <String, CustomFieldColorEntry>{};
      for (final CustomFieldColorEntry entry in attribute.colorEntries) {
        final String code = entry.code.toUpperCase().trim();
        if (code.isEmpty) continue;
        unique.putIfAbsent(code, () => entry);
      }
      final List<CustomFieldColorEntry> selected =
          unique.values.toList(growable: false);
      const int chipLimit = 10;
      final List<CustomFieldColorEntry> visible =
          selected.take(chipLimit).toList(growable: false);
      final int remaining = selected.length - visible.length;
      return Card(
        color: palette.secondaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.borderColor.withValues(alpha: 0.38)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.territoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      size: 20,
                      color: palette.territoryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'الألوان المتوفرة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (selected.isNotEmpty)
                          Text(
                            '${selected.length} لون',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textDefaultColor
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف السمة',
                    onPressed: () async {
                      await _confirmRemoveAttribute(context, cubit, attribute);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (selected.isEmpty)
                Text(
                  'لم يتم تحديد ألوان بعد',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textDefaultColor.withValues(alpha: 0.7),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ...visible.map((e) => _buildColorPill(context, e)),
                    if (remaining > 0) _buildMorePill(context, remaining),
                  ],
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ColorAttributeEditor.show(
                      context: context,
                      attributeKey: attribute.key,
                      attributeName: 'الألوان المتوفرة',
                      currentEntries: attribute.colorEntries,
                      suggestedCodes: attribute.suggestedColorCodes,
                      onSave: (List<CustomFieldColorEntry> entries) {
                        cubit.setColorAttributeEntries(attribute.key, entries);
                      },
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                      selected.isEmpty ? 'تحديد الألوان' : 'تعديل الألوان'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.territoryColor,
                    side: BorderSide(
                      color: palette.territoryColor.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (attribute.type == ManagedAttributeType.size) {
      final List<String> selected = attribute.options
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
      const int chipLimit = 12;
      final List<String> visible =
          selected.take(chipLimit).toList(growable: false);
      final int remaining = selected.length - visible.length;
      return Card(
        color: palette.secondaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.borderColor.withValues(alpha: 0.38)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.territoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.straighten,
                      size: 20,
                      color: palette.territoryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'المقاسات المتاحة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (selected.isNotEmpty)
                          Text(
                            '${selected.length} مقاس',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textDefaultColor
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف السمة',
                    onPressed: () async {
                      await _confirmRemoveAttribute(context, cubit, attribute);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (selected.isEmpty)
                Text(
                  'لم يتم تحديد مقاسات بعد',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textDefaultColor.withValues(alpha: 0.7),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ...visible.map((size) => _buildSizePill(context, size)),
                    if (remaining > 0) _buildMorePill(context, remaining),
                  ],
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openSizeSelector(
                      context, cubit, attribute.key, attribute.options),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                      selected.isEmpty ? 'تحديد المقاسات' : 'تعديل المقاسات'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.territoryColor,
                    side: BorderSide(
                      color: palette.territoryColor.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final TextEditingController nameController =
        _ensureNameController(attribute.key, attribute.name);
    final Widget content = _buildCustomOptions(context, attribute, cubit);

    return Card(
      color: palette.secondaryColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.borderColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: ProductManagementInputDecorations.themed(
                      context,
                      label: 'اسم السمة',
                      hint: 'مثال: خامة المنتج',
                    ),
                    onChanged: (String value) =>
                        cubit.renameAttribute(attribute.key, value),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف السمة',
                  onPressed: () async {
                    await _confirmRemoveAttribute(context, cubit, attribute);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Future<void> _openSizeSelector(
    BuildContext context,
    ProductManagementCubit cubit,
    String attributeKey,
    List<String> current,
  ) async {
    final List<String>? selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final ColorScheme palette = sheetContext.color;
        final Set<String> selectedSet = Set<String>.from(
            current.map((e) => e.trim()).where((e) => e.isNotEmpty));

        return StatefulBuilder(
          builder:
              (BuildContext _, void Function(void Function()) setSheetState) {
            void toggle(String size) {
              setSheetState(() {
                if (selectedSet.contains(size)) {
                  selectedSet.remove(size);
                } else {
                  selectedSet.add(size);
                }
              });
            }

            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.secondaryColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
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
                          color: palette.borderColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'المقاسات المتاحة',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _defaultSizeCatalog.map((String size) {
                              final bool selected = selectedSet.contains(size);
                              return FilterChip(
                                label: Text(size),
                                selected: selected,
                                onSelected: (_) => toggle(size),
                                labelStyle:
                                    theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? palette.territoryColor
                                      : palette.textDefaultColor,
                                ),
                                selectedColor: palette.territoryColor
                                    .withValues(alpha: 0.12),
                                backgroundColor: palette.secondaryColor,
                                side: BorderSide(
                                  color: selected
                                      ? palette.territoryColor
                                      : palette.borderColor
                                          .withValues(alpha: 0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                child: const Text('إلغاء'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  final List<String> result = selectedSet
                                      .toList(growable: false)
                                    ..sort();
                                  Navigator.of(sheetContext).pop(result);
                                },
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
          },
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    cubit.setAttributeOptions(attributeKey, selected);
  }

  Widget _buildCustomOptions(
    BuildContext context,
    ManagedPurchaseAttribute attribute,
    ProductManagementCubit cubit,
  ) {
    final ThemeData theme = Theme.of(context);
    final List<String> options = attribute.options;
    final List<TextEditingController> controllers = _optionControllers
        .putIfAbsent(attribute.key, () => <TextEditingController>[]);

    final List<Widget> children = <Widget>[];

    if (options.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'لم يتم إضافة خيارات بعد. أضف خيارات متعددة ليختار منها المشتري.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    for (int index = 0; index < options.length; index++) {
      if (index >= controllers.length) {
        controllers.add(TextEditingController(text: options[index]));
      }
      final TextEditingController controller = controllers[index];
      final String optionValue = options[index];
      if (controller.text != optionValue) {
        controller.text = optionValue;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
      children.add(
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                decoration: ProductManagementInputDecorations.themed(
                  context,
                  label: 'الخيار ${index + 1}',
                ),
                onChanged: (String value) =>
                    cubit.updateAttributeOption(attribute.key, index, value),
              ),
            ),
            IconButton(
              tooltip: 'حذف الخيار',
              onPressed: () =>
                  cubit.removeAttributeOption(attribute.key, index),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      );
      if (index != options.length - 1) {
        children.add(const SizedBox(height: 12));
      }
    }
    children.add(
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => cubit.addAttributeOption(attribute.key),
          icon: const Icon(Icons.add),
          label: const Text('إضافة خيار'),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildAvailableAttributes(
    BuildContext context,
    ProductManagementCubit cubit,
    ProductManagementState state,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    final List<ItemPurchaseAttributeOption> available =
        state.availableAttributes;

    if (available.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: palette.secondaryColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.borderColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'سمات مقترحة من الإعلان',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: available
                  .map(
                    (ItemPurchaseAttributeOption attribute) =>
                        _buildAvailableChip(
                      context,
                      cubit,
                      attribute,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableChip(
    BuildContext context,
    ProductManagementCubit cubit,
    ItemPurchaseAttributeOption attribute,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    final bool isManaged = widget.state.managedAttributes.any(
        (ManagedPurchaseAttribute managed) => managed.key == attribute.key);

    if (ProductManagementColorUtils.isColorAttribute(attribute)) {
      final List<CustomFieldColorEntry> entries = attribute.colorEntries;
      return ColorAttributeChip(
        code: entries.isNotEmpty
            ? entries.first.code
            : attribute.key.toUpperCase(),
        entry: entries.isNotEmpty ? entries.first : null,
        isSelected: isManaged,
        onSelected: () => cubit.addAttributeFromOption(attribute),
      );
    }

    final String label =
        attribute.name.trim().isEmpty ? attribute.key : attribute.name;

    return TextAttributeChip(
      label: label,
      isSelected: isManaged,
      onSelected: () => cubit.addAttributeFromOption(attribute),
      theme: theme,
      color: palette,
    );
  }

  void _showAddAttributeMenu(BuildContext context) {
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final ColorScheme palette = context.color;
        final ThemeData theme = Theme.of(context);
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.secondaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title:
                      Text('إضافة سمة ألوان', style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    cubit.addColorAttribute();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.straighten),
                  title: Text('إضافة سمة مقاسات',
                      style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    cubit.addSizeAttribute();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.view_list_outlined),
                  title:
                      Text('إضافة سمة مخصصة', style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    cubit.addCustomAttribute();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TextAttributeChip extends StatelessWidget {
  const TextAttributeChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    required this.theme,
    required this.color,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final ThemeData theme;
  final ColorScheme color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? color.territoryColor : color.textDefaultColor,
      ),
      selectedColor: color.territoryColor.withValues(alpha: 0.12),
      backgroundColor: color.secondaryColor,
      side: BorderSide(
        color: isSelected
            ? color.territoryColor
            : color.borderColor.withValues(alpha: 0.5),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class SizeAttributeManager extends StatelessWidget {
  const SizeAttributeManager({
    super.key,
    required this.catalog,
    required this.selected,
    required this.onToggle,
  });

  final List<String> catalog;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final Set<String> selectedSet = selected.toSet();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: catalog
          .map((String value) => TextAttributeChip(
                label: value,
                isSelected: selectedSet.contains(value),
                onSelected: () => onToggle(value),
                theme: theme,
                color: palette,
              ))
          .toList(growable: false),
    );
  }
}

class ColorAttributeManager extends StatelessWidget {
  const ColorAttributeManager({
    super.key,
    required this.entries,
    required this.onManage,
  });

  final List<CustomFieldColorEntry> entries;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (entries.isEmpty)
          Text(
            'لم يتم اختيار ألوان بعد.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textDefaultColor.withValues(alpha: 0.6),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: entries
                .map((CustomFieldColorEntry entry) =>
                    ColorSelectionChip(entry: entry))
                .toList(growable: false),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onManage,
          icon: const Icon(Icons.palette_outlined),
          label: Text(entries.isEmpty ? 'اختيار الألوان' : 'تعديل الألوان'),
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.territoryColor,
            side: BorderSide(color: palette.territoryColor),
            textStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
