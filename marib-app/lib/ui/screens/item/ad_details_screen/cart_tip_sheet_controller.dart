import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/model/cart/cart_safety_tip.dart';
import 'package:marib/ui/screens/item/ad_details_screen/cart_tip_sheet.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_telemetry.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class CartAttributeLabel {
  const CartAttributeLabel({this.label, this.isColor = false});
  final String? label;
  final bool isColor;
}

class CartTipSheetController {
  CartTipSheetController({
    required this.cartCubit,
    required this.payload,
    required this.resolvedDepartmentSlug,
    required this.attributeLabels,
    this.tip,
    this.navigateAction,
    this.externalAction,
  });

  final CartCubit cartCubit;
  final CartSafetyTipsPayload payload;
  final String? resolvedDepartmentSlug;
  final Map<String, CartAttributeLabel> attributeLabels;
  final CartSafetyTip? tip;
  final CartSafetyTipAction? navigateAction;
  final CartSafetyTipAction? externalAction;

  Future<void> show(BuildContext context) async {
    final CartSafetyTip? currentTip = tip ?? payload.primaryTip;
    final String? fallbackTitle = payload.fallbackTitle;
    final String titleText = (currentTip?.title?.trim().isNotEmpty ?? false)
        ? currentTip!.title!.trim()
        : ((fallbackTitle?.trim().isNotEmpty ?? false)
            ? fallbackTitle!.trim()
            : 'تنويه هام قبل الشراء');

    final String descriptionText = currentTip?.description?.trim() ??
        payload.fallbackDescription ??
        'الرجاء مراجعة اختياراتك وتفاصيل الطلب قبل المتابعة.';

    final pending = cartCubit.state.pendingAddition;
    final List<ChipData> chips = <ChipData>[];
    if (pending != null) {
      chips.add(ChipData(label: 'الكمية', value: '${pending.quantity}'));

      final hexColor = RegExp(r'^[0-9A-F]{6}$', caseSensitive: false);
      pending.variantAttributes?.forEach((key, value) {
        final String rawKey = key.toString().trim();
        String v = value?.toString().trim() ?? '';
        if (rawKey.isEmpty || v.isEmpty) return;

        final String normalizedKey = rawKey.toLowerCase();
        final CartAttributeLabel? meta =
            attributeLabels[normalizedKey] ?? attributeLabels[rawKey];
        final String label = (meta?.label?.trim().isNotEmpty ?? false)
            ? meta!.label!.trim()
            : rawKey;

        Color? colorPreview;
        final String normalizedValue = v.replaceAll('#', '').toUpperCase();
        final bool looksLikeColor =
            meta?.isColor == true || hexColor.hasMatch(normalizedValue);
        if (looksLikeColor && hexColor.hasMatch(normalizedValue)) {
          colorPreview = Color(int.parse('FF$normalizedValue', radix: 16));
          v = ''; // نعرض الدائرة فقط بدون كود اللون
        }

        chips.add(ChipData(label: label, value: v, colorPreview: colorPreview));
      });
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final Color textColor = sheetContext.color.textDefaultColor;
        final Color sheetBackground = sheetContext.color.secondaryColor;
        final Color accentColor = sheetContext.color.territoryColor;
        final Color handleColor =
            sheetContext.color.textColorDark.withOpacity(0.1);
        final Color outlineForeground = textColor.withOpacity(0.9);
        final Color outlineBorder = textColor.withOpacity(0.3);

        final TextStyle titleStyle = TextStyle(
          fontSize: sheetContext.font.larger,
          fontWeight: FontWeight.bold,
          color: textColor,
        );
        final TextStyle descriptionStyle = TextStyle(
          fontSize: sheetContext.font.normal,
          height: 1.6,
          color: textColor.withOpacity(0.9),
        );

        Future<void> handleNavigate() async {
          AppTelemetry.record('tips_confirmed', <String, dynamic>{
            'department': resolvedDepartmentSlug ?? payload.departmentKey,
            'has_external': externalAction != null,
          });

          try {
            await cartCubit.confirmPendingCartAddition();
          } catch (_) {
            HelperUtils.showSnackBarMessage(
              sheetContext,
              'تعذر إضافة المنتج إلى السلة',
            );
            return;
          }

          Navigator.of(sheetContext).pop(true);
          HelperUtils.showSnackBarMessage(
            sheetContext,
            'تم إضافة المنتج إلى السلة',
          );
        }

        Future<void> handleExternal() async {
          if (externalAction == null) return;
          Navigator.of(sheetContext).pop(false);
          await _handleCartTipAction(sheetContext, externalAction!);
        }

        void handleClose() {
          Navigator.of(sheetContext).pop(false);
          cartCubit.clearSafetyTips();
        }

        return CartTipSheet(
          titleText: titleText,
          descriptionText: descriptionText,
          showSheinButton:
              (resolvedDepartmentSlug ?? payload.departmentKey) == 'shein' &&
                  externalAction != null,
          onExternal: externalAction != null ? handleExternal : null,
          onNavigate: handleNavigate,
          onClose: handleClose,
          textColor: textColor,
          sheetBackground: sheetBackground,
          accentColor: accentColor,
          handleColor: handleColor,
          outlineForeground: outlineForeground,
          outlineBorder: outlineBorder,
          titleStyle: titleStyle,
          descriptionStyle: descriptionStyle,
          chips: chips,
        );
      },
    );
  }

  Future<void> _handleCartTipAction(
      BuildContext context, CartSafetyTipAction action) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (action.isNavigate && action.navigatesToCart) {
      navigator.popUntil((Route<dynamic> route) => route is! PopupRoute);
      await navigator.pushNamed(Routes.cart);
      return;
    }

    if (action.isOpenUrl) {
      final String? url = action.resolvedProductLink ?? action.target;
      if (url != null && url.trim().isNotEmpty) {
        final Uri? uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
    }

    HelperUtils.showSnackBarMessage(
      context,
      'تعذر تنفيذ الإجراء المطلوب',
    );
  }
}
