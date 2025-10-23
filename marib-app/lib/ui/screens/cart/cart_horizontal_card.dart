import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/promoted_widget.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/money_formatter.dart';
import 'package:marib/utils/ui_utils.dart';






class CartHorizontalCard extends StatelessWidget {
  final Cart item;
  final List<Widget>? addBottom;
  final double? additionalHeight;
  final StatusButton? statusButton;
  final bool? useRow;
  final VoidCallback? onDeleteTap;
  final double? additionalImageWidth;
  final bool? showLikeButton;
  final bool showCheckbox;
  final bool isSelected;
  final VoidCallback? onToggleSelect;
  final ShapeBorder? buttonShape;
  final bool showShadow;


  const CartHorizontalCard({
    super.key,
    required this.item,
    this.useRow,
    this.addBottom,
    this.additionalHeight,
    this.statusButton,
    this.onDeleteTap,
    this.showLikeButton,
    this.additionalImageWidth,
    this.showCheckbox = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.buttonShape,
    this.showShadow = false, // ✅ أضف هذا
  });

  Widget _quantityControls(BuildContext context, Cart item) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelColor =
    context.color.territoryColor.withOpacity(isDark ? 0.28 : 0.12);

    return Dismissible(
      key: ValueKey(item.selectionKey),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final bool? confirmed = await UiUtils.showBlurredDialoge(
          context,
          dialoge: BlurredDialogBox(
            title: "تأكيد الحذف ",
            cancelTextColor: context.color.textColorDark,
            svgImagePath: "assets/lottie/delete_user.json",
            content:
            Text("confirmDeleteProductFromCart".translate(context)),
          ),
        ) as bool?;
        return confirmed == true;
      },
      onDismissed: (_) {
        if (item.id == null) {
          return;
        }
        unawaited(
          context.read<CartCubit>().removeItem(
            cartItemId: item.cartItemId,
            itemId: item.id!,
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red.withOpacity(0.1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'حذف',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.color.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    await context.read<CartCubit>().increaseQuantity(
                      cartItemId: item.cartItemId,
                      itemId: item.id!,
                    );

                    },
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.1),
                    ),
                    child: Icon(Icons.add, color: Colors.green, size: 18),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  item.quantity.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: context.color.textDefaultColor,
                  ),
                ),
                SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final cartCubit = context.read<CartCubit>();
                    final int quantity = cartCubit.getQuantityForCartItem(
                      cartItemId: item.cartItemId,
                      itemId: item.id!,
                    );

                    if (quantity == 1) {
                      UiUtils.showBlurredDialoge(context,
                          dialoge: BlurredDialogBox(
                              // title: "confirmLogoutTitle".translate(context),
                              title: "تأكيد الحذف ",
                              onAccept: () async {
                                await cartCubit.removeItem(

                                  cartItemId: item.cartItemId,
                                  itemId: item.id!,
                                );
                              },
                              cancelTextColor: context.color.textColorDark,
                              svgImagePath: "assets/lottie/delete_user.json",
                              content: Text("confirmDeleteProductFromCart"
                                  .translate(context))));
                    } else {
                      await context.read<CartCubit>().decreaseQuantity(
                        cartItemId: item.cartItemId,
                        itemId: item.id!,
                      );
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.withOpacity(0.1),
                    ),
                    child: Icon(Icons.remove, color: Colors.orange, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = context.color.secondaryColor;
    final Color shadowColor = isDark
        ? Colors.black.withOpacity(showShadow ? 0.35 : 0.25)
        : Colors.black.withOpacity(showShadow ? 0.12 : 0.08);

    final MoneyFormatter moneyFormatter = MoneyFormatter.fromCartCurrency(
      currency: item.currency,
      currencyCode:
      item.currencyCode ?? CurrencyUtils.normalizeCurrencyCode(item.currency),
      fallbackLabel: item.currency ?? item.currencyCode,
    );
    final String priceLabel = moneyFormatter.format(item.unitPriceValue);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Container(
        height: addBottom == null ? 124 : (124 + (additionalHeight ?? 0)),
        decoration: BoxDecoration(
            border: Border.all(color: context.color.borderColor.darken(50)),
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(15)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          SizedBox(height: 1),
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: UiUtils.getImage(
                                  item.image ?? "",
                                  height: addBottom == null
                                      ? 119
                                      : (119 +
                                          (additionalHeight ??
                                              0)) /*statusButton != null ? 90 : 120*/,
                                  width: 100 + (additionalImageWidth ?? 0),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // Text(item.promoted.toString()),
                              if (item.isFeature ?? false)
                                const PositionedDirectional(
                                    start: 5,
                                    top: 5,
                                    child: PromotedCard(
                                        type: PromoteCardType.icon)),
                            ],
                          ),
                          if (statusButton != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 3.0, horizontal: 3.0),
                              child: Container(
                                decoration: BoxDecoration(
                                    color: statusButton!.color,
                                    borderRadius: BorderRadius.circular(4)),
                                width: 80,
                                height: 120 - 90 - 8,
                                child: Center(
                                    child: Text(statusButton!.lable)
                                        .size(context.font.small)
                                        .bold()
                                        .color(statusButton?.textColor ??
                                            Colors.black)),
                              ),
                            )
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            top: 0,
                            start: 12,
                            bottom: 5,
                            end: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text(
                                item.name!.firstUpperCase(),
                              )
                                  .setMaxLines(lines: 2)
                                  .size(context.font.normal)
                                  .color(context.color.textDefaultColor)
                                  .setMaxChars(maxChars: 30),

                              Row(
                                children: [
                                  Expanded(
                                    child: Text(priceLabel)

                                        .size(context.font.large)
                                        .color(context.color.territoryColor)
                                        .bold(weight: FontWeight.w700),
                                  ),
                                  // if (showLikeButton ?? true) favButton(context)
                                ],
                              ),
                              //SizedBox(height: 5),
                              if (item.user != "")
                                Text(item.user?.name?.trim() ?? "")
                                    .setMaxLines(lines: 1)
                                    .color(context.color.textDefaultColor
                                    .withOpacity(0.5))
                                    .size(context.font.smaller),

                              // Row()
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // if (useRow == false || useRow == null) ...addBottom ?? [],

                // if (useRow == true) ...{Row(children: addBottom ?? [])}
              ],
            ),
            _quantityControls(context, item)
          ],
        ),
      ),
    );
  }
}

class StatusButton {
  final String lable;
  final Color color;
  final Color? textColor;

  StatusButton({
    required this.lable,
    required this.color,
    this.textColor,
  });
}
