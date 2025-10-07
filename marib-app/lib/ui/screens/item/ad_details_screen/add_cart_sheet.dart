import 'dart:async';
import 'dart:convert';
import 'package:marib/config/feature_flags.dart';
import 'package:marib/ui/screens/cart/delivery_pricing_guard.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'cart_field_helpers.dart';



String canonicalizeVariantAttributes(Map<String, dynamic>? attributes) {
  if (attributes == null || attributes.isEmpty) {
    return '{}';
  }

  dynamic normalize(dynamic value) {
    if (value is Map) {
      final sortedEntries = value.entries
          .map((entry) => MapEntry(entry.key.toString(), normalize(entry.value)))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      return {for (final entry in sortedEntries) entry.key: entry.value};
    }

    if (value is List) {
      return value.map(normalize).toList();
    }

    return value;
  }

  final normalized = normalize(Map<String, dynamic>.from(attributes));
  return jsonEncode(normalized);
}

String cartVariantSignature(Cart cart) {
  final String variantId = cart.variantId?.trim() ?? '';
  final String normalizedAttributes = canonicalizeVariantAttributes(cart.variantAttributes);

  return '$variantId|$normalizedAttributes';
}

bool isDuplicateCartLine(Iterable<Cart> existingItems, Cart incoming) {
  if (incoming.id == null) {
    return false;
  }

  final String incomingSignature = cartVariantSignature(incoming);

  return existingItems.any(
        (item) => item.id == incoming.id && cartVariantSignature(item) == incomingSignature,
  );
}

class AddCartSheet extends StatelessWidget {
  final List<CustomFieldBuilder> moreDetailDynamicFields;
  final Cart cartItem;
  final VoidCallback onItemAdded;

  const AddCartSheet({
    super.key,
    required this.moreDetailDynamicFields,
    required this.cartItem,
    required this.onItemAdded,
  });

  @override
  Widget build(BuildContext context) {
    final cartCubit = context.read<CartCubit>();
    final pricingEnabled = FeatureFlags.deliveryPricingEnabled;

    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                height: 5, width: 50,
                decoration: BoxDecoration(color: context.color.borderColor, borderRadius: BorderRadius.circular(3)),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                pricingEnabled ? "اختر خياراتك".translate(context) : "الإضافة للسلة (بدون توصيل)".translate(context),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.font.larger, color: context.color.textDefaultColor),
              ),
            ),
            const Divider(height: 1),

            if (!pricingEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.block, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "التوصيل والتسعير متوقفان مؤقتًا. يمكنك الإضافة للسلة وإكمال الطلب لاحقًا.",
                        style: TextStyle(fontSize: context.font.small, color: context.color.textDefaultColor.withOpacity(0.8)),
                      ),
                    ),
                  ],
                ),
              ),

            Flexible(
              child: moreDetailDynamicFields.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("لا توجد خيارات إضافية متاحة", style: TextStyle(color: context.color.textDefaultColor)),
                ),
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: moreDetailDynamicFields.map((field) {
                    field.stateUpdater((fn) {});
                    return Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: field.build(context));
                  }).toList(),
                ),
              ),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))],

                ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.color.territoryColor,
                  foregroundColor: context.color.secondaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final String? validationError =
                  validateRequiredCustomFieldSelections(
                    moreDetailDynamicFields,
                  );

    if (validationError != null) {
    HelperUtils.showSnackBarMessage(context, validationError);
    return;
                    }


                  final List<Map<String, dynamic>> selectedCustomFields =
                  buildSelectedCustomFieldsPayload();

                  cartItem.selectedCustomFields =
                  selectedCustomFields.isEmpty ? null : selectedCustomFields;

                  final existingItems = cartCubit.state.items;


                  String? _normalizeCurrency(String? raw) {
                    final String? trimmed = raw?.trim();
                    if (trimmed == null || trimmed.isEmpty) {
                      return null;
                    }
                    return trimmed.toUpperCase();
                  }

                  String? _activeCartCurrency(Iterable<Cart> items) {
                    for (final Cart entry in items) {
                      final String? candidate =
                      _normalizeCurrency(entry.currency);
                      if (candidate != null) {
                        return candidate;
                      }
                    }
                    return null;
                  }

                  final String incomingSection = cartItem.section.trim();
                  final String? existingSection =
                  existingItems.isNotEmpty
                      ? existingItems.first.section.trim()
                      : null;

                  bool _sectionsMatch(String? a, String? b) =>
                      a != null &&
                          b != null &&
                          a.toLowerCase() == b.toLowerCase();

                  if (existingSection != null &&
                      !_sectionsMatch(existingSection, incomingSection)) {
                    await UiUtils.showBlurredDialoge(
                      context,
                      dialoge: const BlurredDialogBox(
                        title: "تنبيه السلة",
                        content: Text(
                            "لا يمكنك خلط الأقسام داخل السلة. فضلاً أفرغ السلة قبل إضافة منتجات من قسم مختلف."),
                        showCancleButton: false,
                        acceptButtonName: "حسنًا",
                      ),
                    );
                    return;
                  }



                  final String? existingCurrency =
                  _activeCartCurrency(existingItems);
                  final String? incomingCurrency =
                  _normalizeCurrency(cartItem.currency);

                  if (existingCurrency != null &&
                      incomingCurrency != null &&
                      existingCurrency != incomingCurrency) {
                    HelperUtils.showSnackBarMessage(
                      context,
                      'لا يمكن إضافة هذا المنتج لأن السلة مضبوطة على عملة $existingCurrency بينما المنتج بعملة $incomingCurrency.',
                    );
                    return;
                  }

    if (isDuplicateCartLine(existingItems, cartItem)) {
    HelperUtils.showSnackBarMessage(
    context,
    "productAlreadyInCart".translate(context),
    );
    return;
    }

                  try {
                    // إن كانت التسعير/التوصيل متوقفة، لا تنفّذ أي استدعاء تسعير هنا.
                    // فقط أضف للسلة محليًا.
                    final result = cartCubit.addItem(cartItem);
                    if (result is Future) await result;

                    onItemAdded();

                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.pop();
                    }
                    navigator.pushNamed(Routes.cart);
                  } catch (e) {
                    final message = DeliveryPricingGuard.readableErrorMessage(
                      context,
                      e,
                    );
                    HelperUtils.showSnackBarMessage(
                      context,
                      message,
                    );
                  }
                },
                child: Text("Cart".translate(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// نفس ويدجت التنويه لديك. لم يُعدّل.


