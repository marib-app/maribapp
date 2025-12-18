import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/constants/color_catalog.dart';
import 'package:marib/data/cubits/item/product_management_cubit.dart';
import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/ui/screens/item/purchase_options/product_management/product_management_color_utils.dart';
import 'package:marib/ui/screens/item/purchase_options/product_management/widgets/common_widgets.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';


class StockTab extends StatelessWidget {
  const StockTab({
    super.key,
    required this.state,
    required this.stockControllers,
  });

  final ProductManagementState state;
  final Map<String, TextEditingController> stockControllers;

  @override
  Widget build(BuildContext context) {
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    final ItemPurchaseOptions? options = state.options;
    final theme = Theme.of(context);
    final color = context.color;
    if (options == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!state.hasStockVariants) {
      final TextEditingController controller = _ensureStockController(
        '__general__',
        (state.generalStock ?? 0).toString(),
      );

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Card(
            color: color.secondaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: color.borderColor.withValues(alpha: 0.38)),
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
                          color: color.territoryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 20,
                          color: color.territoryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'المخزون الكلي',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'حدّد الكمية المتاحة للمنتج.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.textDefaultColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _QuantityStepper(
                      controller: controller,
                      hint: '0',
                      onChanged: cubit.updateGeneralStock,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final List<ProductVariant> variants = state.variants;
    if (variants.isEmpty) {
      return const ProductManagementEmptyState(
        message:
            'لم يتم إنشاء تركيبات لخيارات المنتج بعد. أضف خيارات السمات أولاً.',
      );
    }

    final Map<String, ManagedPurchaseAttribute> managedByKey =
        <String, ManagedPurchaseAttribute>{
      for (final ManagedPurchaseAttribute attribute in state.managedAttributes)
        attribute.key: attribute,
    };

    ManagedPurchaseAttribute? colorAttribute;
    for (final ManagedPurchaseAttribute attribute in state.managedAttributes) {
      if (attribute.type == ManagedAttributeType.color) {
        colorAttribute = attribute;
        break;
      }
    }
    final String? colorKey = colorAttribute?.key;
    final bool canGroupByColor = colorKey != null &&
        variants.any((ProductVariant variant) =>
            variant.attributes.containsKey(colorKey));

    final List<Widget> rows = <Widget>[];

    if (canGroupByColor) {
      final Map<String, List<ProductVariant>> grouped =
          <String, List<ProductVariant>>{};
      for (final ProductVariant variant in variants) {
        final String raw = variant.attributes[colorKey] ?? '';
        final String normalized =
            ProductManagementColorUtils.normalizeColorValue(raw) ??
                raw.trim().toUpperCase();
        final String groupKey =
            normalized.isEmpty ? '__unknown__' : normalized;
        grouped.putIfAbsent(groupKey, () => <ProductVariant>[]).add(variant);
      }

      final List<_ColorGroup> groups = <_ColorGroup>[];
      grouped.forEach((String key, List<ProductVariant> list) {
        final String? normalizedKey =
            ProductManagementColorUtils.normalizeColorValue(key);
        final String resolvedName = normalizedKey == null
            ? 'لون مخصص'
            : ColorCatalog.nameForHex(normalizedKey, context: context).trim();
        final String displayName =
            resolvedName.isEmpty || resolvedName.startsWith('#')
                ? 'لون مخصص'
                : resolvedName;
        final Color swatch = normalizedKey == null
            ? color.borderColor
            : (ProductManagementColorUtils.colorFromHex(normalizedKey) ??
                color.borderColor);
        groups.add(
          _ColorGroup(
            meta: _ColorMeta(
              code: normalizedKey ?? key,
              name: displayName,
              color: swatch,
            ),
            variants: list,
          ),
        );
      });
      groups.sort((a, b) => a.meta.name.compareTo(b.meta.name));

      ManagedPurchaseAttribute? sizeAttribute;
      for (final ManagedPurchaseAttribute attribute in state.managedAttributes) {
        if (attribute.type == ManagedAttributeType.size) {
          sizeAttribute = attribute;
          break;
        }
      }
      final String? sizeKey = sizeAttribute?.key;

      for (final _ColorGroup group in groups) {
        final List<ProductVariant> groupVariants =
            group.variants.toList(growable: false);
        if (sizeKey != null) {
          groupVariants.sort(
            (a, b) => (a.attributes[sizeKey] ?? '')
                .compareTo(b.attributes[sizeKey] ?? ''),
          );
        }

        rows.add(
          Card(
            color: color.secondaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: color.borderColor.withValues(alpha: 0.38),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _ColorHeader(meta: group.meta, count: groupVariants.length),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: color.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: color.borderColor.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < groupVariants.length; i++) ...<Widget>[
                          _VariantStockRow(
                            variant: groupVariants[i],
                            options: options,
                            managedByKey: managedByKey,
                            controller: _ensureStockController(
                              groupVariants[i].id,
                              groupVariants[i].stock.toString(),
                            ),
                            onStockChanged: (int value) =>
                                cubit.updateVariantStock(groupVariants[i], value),
                            skipAttributeKey: colorKey,
                          ),
                          if (i != groupVariants.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: color.borderColor.withValues(alpha: 0.25),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        rows.add(const SizedBox(height: 12));
      }
      if (rows.isNotEmpty) {
        rows.removeLast();
      }
    } else {
      for (final ProductVariant variant in variants) {
        rows.add(
          Card(
            color: color.secondaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: color.borderColor.withValues(alpha: 0.38),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _VariantStockRow(
                variant: variant,
                options: options,
                managedByKey: managedByKey,
                controller: _ensureStockController(
                  variant.id,
                  variant.stock.toString(),
                ),
                onStockChanged: (int value) =>
                    cubit.updateVariantStock(variant, value),
              ),
            ),
          ),
        );
        rows.add(const SizedBox(height: 12));
      }
      if (rows.isNotEmpty) {
        rows.removeLast();
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Card(
          color: color.secondaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color.borderColor.withValues(alpha: 0.38)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.territoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: color.territoryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'المخزون',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'عدد التركيبات: ${variants.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color.textDefaultColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showBulkStockDialog(context),
                        icon: const Icon(Icons.auto_fix_high_outlined),
                        label: const Text('تعيين مخزون موحد'),
                        style: FilledButton.styleFrom(
                          backgroundColor: color.territoryColor,
                          foregroundColor: color.buttonColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => cubit.resetVariantStocks(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة التعيين'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color.territoryColor,
                          side: BorderSide(
                            color: color.borderColor.withValues(alpha: 0.6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...rows,
      ],
    );
  }

  void _showBulkStockDialog(BuildContext context) async {
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    final TextEditingController controller = TextEditingController(text: '0');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final ColorScheme palette = sheetContext.color;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.52,
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
                              'تعيين مخزون موحد',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'سيتم تطبيق الكمية على جميع التركيبات المتاحة.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              palette.textDefaultColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: AlignmentDirectional.center,
                        child: _QuantityStepper(
                          controller: controller,
                          hint: '0',
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final int value =
                                    int.tryParse(controller.text.trim()) ?? 0;
                                cubit.applyBulkStock(value);
                                Navigator.of(sheetContext).pop();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: palette.territoryColor,
                                foregroundColor: palette.buttonColor,
                              ),
                              child: const Text('تطبيق'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    controller.dispose();
  }

  TextEditingController _ensureStockController(String key, String value) {
    final TextEditingController controller = stockControllers.putIfAbsent(
        key, () => TextEditingController(text: value));
    if (controller.text != value) {
      controller.text = value;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
    return controller;
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.hint,
  });

  final TextEditingController controller;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final String? hint;

  int _parseValue() {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  void _setValue(int value) {
    final int normalized = value < 0 ? 0 : value;
    controller.text = normalized.toString();
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    Widget buildButton(IconData icon, VoidCallback onTap) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? palette.territoryColor
                  : palette.textDefaultColor.withValues(alpha: 0.45),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          buildButton(Icons.remove, () {
            final int current = _parseValue();
            final int next = current > 0 ? current - 1 : 0;
            _setValue(next);
            onChanged(next);
          }),
          SizedBox(
            width: 72,
            child: TextField(
              enabled: enabled,
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (String value) {
                final int parsed = int.tryParse(value.trim()) ?? 0;
                onChanged(parsed);
              },
            ),
          ),
          buildButton(Icons.add, () {
            final int current = _parseValue();
            final int next = current + 1;
            _setValue(next);
            onChanged(next);
          }),
        ],
      ),
    );
  }
}

class _ColorValuePill extends StatelessWidget {
  const _ColorValuePill({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.secondaryColor,
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
              color: color,
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
}

class _AttributePill extends StatelessWidget {
  const _AttributePill.size({required this.label})
      : _variant = _AttributePillVariant.size;

  const _AttributePill.generic({required this.label})
      : _variant = _AttributePillVariant.generic;

  final String label;
  final _AttributePillVariant _variant;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    final Color background;
    final Color border;
    final Color textColor;
    final FontWeight weight;

    switch (_variant) {
      case _AttributePillVariant.size:
        background = palette.territoryColor.withValues(alpha: 0.12);
        border = palette.territoryColor.withValues(alpha: 0.35);
        textColor = palette.territoryColor;
        weight = FontWeight.w800;
        break;
      case _AttributePillVariant.generic:
        background = palette.secondaryColor;
        border = palette.borderColor.withValues(alpha: 0.45);
        textColor = palette.textDefaultColor;
        weight = FontWeight.w700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: weight,
          color: textColor,
        ),
      ),
    );
  }
}

enum _AttributePillVariant { size, generic }

class _VariantStockRow extends StatelessWidget {
  const _VariantStockRow({
    required this.variant,
    required this.options,
    required this.managedByKey,
    required this.controller,
    required this.onStockChanged,
    this.skipAttributeKey,
  });

  final ProductVariant variant;
  final ItemPurchaseOptions options;
  final Map<String, ManagedPurchaseAttribute> managedByKey;
  final TextEditingController controller;
  final ValueChanged<int> onStockChanged;
  final String? skipAttributeKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    final List<Widget> pills = <Widget>[];
    variant.attributes.forEach((String key, String value) {
      if (key == skipAttributeKey) {
        return;
      }
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return;
      }

      final ManagedPurchaseAttribute? managed = managedByKey[key];
      final ItemPurchaseAttributeOption? option = options.attributeByKey(key);
      final bool isColorAttribute =
          (managed?.type == ManagedAttributeType.color) ||
              (option?.type?.toLowerCase() == 'color') ||
              (option != null &&
                  ProductManagementColorUtils.isColorAttribute(option));

      if (isColorAttribute) {
        final String? normalized =
            ProductManagementColorUtils.normalizeColorValue(trimmed);
        final Color dotColor = normalized == null
            ? palette.borderColor
            : (ProductManagementColorUtils.colorFromHex(normalized) ??
                palette.borderColor);
        final String label = normalized == null
            ? ''
            : ColorCatalog.nameForHex(normalized, context: context).trim();
        final String displayLabel =
            label.isEmpty || label.startsWith('#') ? 'لون مخصص' : label;
        pills.add(_ColorValuePill(color: dotColor, label: displayLabel));
        return;
      }

      if (managed?.type == ManagedAttributeType.size) {
        pills.add(_AttributePill.size(label: trimmed));
        return;
      }

      final String managedName = (managed?.name ?? '').trim();
      final String optionName = (option?.name ?? '').trim();
      final String name = managedName.isNotEmpty ? managedName : optionName;
      final String label = name.isEmpty ? trimmed : '$name: $trimmed';
      pills.add(_AttributePill.generic(label: label));
    });

    if (pills.isEmpty) {
      pills.add(const _AttributePill.generic(label: 'تركيبة'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pills,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                'الكمية',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textDefaultColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              _QuantityStepper(
                controller: controller,
                hint: '0',
                enabled: !variant.hidden,
                onChanged: onStockChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorMeta {
  const _ColorMeta({
    required this.code,
    required this.name,
    required this.color,
  });

  final String code;
  final String name;
  final Color color;
}

class _ColorGroup {
  const _ColorGroup({
    required this.meta,
    required this.variants,
  });

  final _ColorMeta meta;
  final List<ProductVariant> variants;
}

class _ColorHeader extends StatelessWidget {
  const _ColorHeader({
    required this.meta,
    required this.count,
  });

  final _ColorMeta meta;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: meta.color,
            border: Border.all(
              color: palette.borderColor.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                meta.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count تركيبة',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textDefaultColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
