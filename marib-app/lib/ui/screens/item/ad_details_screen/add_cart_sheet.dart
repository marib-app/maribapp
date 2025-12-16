import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/ui/screens/item/ad_details_screen/cart_field_helpers.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

/// بصمة فريدة لتمييز السطر داخل السلة (المعرف + السمات)
String _cartVariantSignature(Cart cart) {
  String normalize(dynamic value) {
    if (value is Map) {
      final sorted = value.entries
          .map((e) => MapEntry(e.key.toString(), normalize(e.value)))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return jsonEncode({for (final e in sorted) e.key: e.value});
    }
    if (value is List) return jsonEncode(value.map(normalize).toList());
    return value.toString();
  }

  final variantId = (cart.variantId ?? '').trim();
  final attrs = cart.variantAttributes ?? <String, dynamic>{};
  return '$variantId|${normalize(attrs)}';
}

bool _isDuplicateCartLine(Iterable<Cart> existingItems, Cart incoming) {
  final signature = _cartVariantSignature(incoming);
  return existingItems.any(
    (item) => item.id == incoming.id && _cartVariantSignature(item) == signature,
  );
}

class AddCartSheet extends StatelessWidget {
  final List<CustomFieldBuilder> moreDetailDynamicFields;
  final Cart cartItem;
  final VoidCallback onItemAdded;
  final String? safetyTip;

  const AddCartSheet({
    super.key,
    required this.moreDetailDynamicFields,
    required this.cartItem,
    required this.onItemAdded,
    this.safetyTip,
  });

  @override
  Widget build(BuildContext context) {
    final cartCubit = context.read<CartCubit>();
    final attributes = _resolveAttributes(cartItem);

    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 4,
                decoration: BoxDecoration(
                  color: context.color.borderColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: context.color.territoryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'تنبيه هام قبل الشراء',
                style: TextStyle(
                  fontSize: context.font.large,
                  fontWeight: FontWeight.w800,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                safetyTip?.trim().isNotEmpty == true
                    ? safetyTip!.trim()
                    : 'يرجى مراجعة الكمية والسمات المختارة قبل الإضافة للسلة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.color.textDefaultColor.withOpacity(0.8),
                  fontSize: context.font.normal,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(context, 'الكمية: ${cartItem.quantity}'),
                  ...attributes.map((e) => _chip(context, e)),
                ],
              ),
              if (moreDetailDynamicFields.isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'حقول إضافية',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...moreDetailDynamicFields.map((field) {
                  field.stateUpdater((fn) {});
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: field.build(context),
                  );
                }),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'إغلاق',
                        style: TextStyle(
                          color: context.color.textDefaultColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final String? validationError =
                            validateRequiredCustomFieldSelections(
                          moreDetailDynamicFields,
                        );
                        if (validationError != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(validationError)),
                          );
                          return;
                        }

                        final selectedCustomFields =
                            buildSelectedCustomFieldsPayload();
                        cartItem.selectedCustomFields =
                            selectedCustomFields.isEmpty
                                ? null
                                : selectedCustomFields;

                        final existingItems = cartCubit.state.items;
                        if (_isDuplicateCartLine(existingItems, cartItem)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'هذا المنتج بنفس المواصفات موجود في السلة.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                          Navigator.of(context).pop();
                          return;
                        }

                        await cartCubit.addItem(cartItem);
                        onItemAdded();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تمت الإضافة إلى السلة',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.color.territoryColor,
                        foregroundColor: context.color.secondaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'إضافة إلى السلة',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _resolveAttributes(Cart cart) {
    final attrs = <String>[];
    final map = cart.variantAttributes;
    if (map != null && map.isNotEmpty) {
      map.forEach((key, value) {
        final k = key.toString().trim();
        if (k.isEmpty) return;
        final v = value?.toString().trim() ?? '';
        attrs.add('$k: $v');
      });
    }
    return attrs;
  }

  Widget _chip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.color.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.color.borderColor.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: context.color.textDefaultColor,
          fontSize: context.font.small,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.color.textDefaultColor,
            )),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.color.textDefaultColor,
          ),
        ),
      ],
    );
  }
}
