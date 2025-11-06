import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/item/product_management_cubit.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/utils/extensions/extensions.dart';

import '../product_management_color_utils.dart';
import '../product_management_input_decorations.dart';
import '../widgets/common_widgets.dart';
import 'package:marib/ui/theme/theme.dart';




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
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: color.borderColor.withOpacity(0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'المخزون الكلي',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: false),
                    decoration: ProductManagementInputDecorations.themed(
                      context,
                      hint: 'مثال: 10',
                    ),
                    onChanged: (String value) =>
                        cubit.updateGeneralStock(int.tryParse(value)),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => _showBulkStockDialog(context),
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: const Text('تعيين مخزون موحد'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => cubit.resetVariantStocks(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة التعيين'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...variants.map((ProductVariant variant) {
          final String key = variant.id;
          final TextEditingController controller = _ensureStockController(
            key,
            variant.stock.toString(),
          );
          final String description = _describeVariant(
            variant.attributes,
            options,
            state.managedAttributes,
          );
          return Card(
            color: color.secondaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: color.borderColor.withOpacity(0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    description.isEmpty ? 'تركيبة بدون وصف' : description,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: false),
                    decoration: ProductManagementInputDecorations.themed(
                      context,
                      label: 'المخزون المتاح',
                    ),
                    onChanged: (String value) => cubit.updateVariantStock(
                      variant,
                      int.tryParse(value),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showBulkStockDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'تعيين مخزون موحد',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: ProductManagementInputDecorations.themed(
              context,
              hint: 'مثال: 10',
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.color.textDefaultColor,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.color.territoryColor,
                foregroundColor: context.color.secondaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                final int value = int.tryParse(controller.text) ?? 0;
                context.read<ProductManagementCubit>().applyBulkStock(value);
                Navigator.pop(context);
              },
              child: const Text('تطبيق'),
            ),
          ],
        );
      },
    );
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

  String _describeVariant(
    Map<String, String> attributes,
    ItemPurchaseOptions options,
    List<ManagedPurchaseAttribute> managedAttributes,
  ) {
    ManagedPurchaseAttribute? resolveManaged(String key) {
      for (final ManagedPurchaseAttribute attribute in managedAttributes) {
        if (attribute.key == key) {
          return attribute;
        }
      }
      return null;
    }

    final List<String> parts = <String>[];
    attributes.forEach((String key, String value) {
      final ManagedPurchaseAttribute? managed = resolveManaged(key);

      final ItemPurchaseAttributeOption? attribute =
          options.attributeByKey(key);
      final String managedName = managed?.name ?? '';
      final String attributeName = attribute?.name ?? '';
      final bool hasManagedName = managedName.trim().isNotEmpty;
      final String name = hasManagedName
          ? managedName
          : (attributeName.trim().isNotEmpty ? attributeName : key);
      String displayValue = value;
      final bool isColorAttribute =
          (managed?.type == ManagedAttributeType.color) ||
              (attribute?.type?.toLowerCase() == 'color') ||
              (attribute != null &&
                  ProductManagementColorUtils.isColorAttribute(attribute));

      if (isColorAttribute) {
        final String? normalized =
            ProductManagementColorUtils.normalizeColorValue(value);
        if (normalized != null) {
          final List<CustomFieldColorEntry> entries = (managed != null &&
                  managed.colorEntries.isNotEmpty)
              ? managed.colorEntries
              : (attribute?.colorEntries ?? const <CustomFieldColorEntry>[]);

          CustomFieldColorEntry? matched;
          for (final CustomFieldColorEntry entry in entries) {
            if (entry.code == normalized) {
              matched = entry;
              break;
            }
          }

          final int? quantity = matched?.quantity;
          displayValue = '#$normalized';
          if (quantity != null && quantity > 0) {
            displayValue = '$displayValue × $quantity';
          }
        }
      }
      parts.add('$name: $displayValue');
    });
    return parts.join(' • ');
  }
}