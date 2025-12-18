// 🛒 الواجهة فقط
import 'package:flutter/material.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/ui/screens/cart/cart_horizontal_card.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marib/data/model/cart/cart_discount.dart';
import 'package:marib/data/model/cart/cart_safety_tip.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/money_formatter.dart';
import 'package:marib/utils/store_status_view_model.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/ui/widgets/store_status_card.dart';

class CartUI extends StatelessWidget {
  // مدخلات الحالة
  final bool isLoading;
  final List<Cart> cartItems;
  final double subtotal;
  final List<CartDiscount> discounts;
  final String? currency;
  final String? currencyCode;
  final String? loadErrorMessage;
  final Map<String, dynamic>? store;

  final String? supportWhatsappLabel;
  final String? supportWhatsappNumber;
  final String? supportWhatsappUrl;
  final String? supportWhatsappMessage;
  final TextEditingController couponController;
  final bool couponInProgress;
  final String? couponError;
  final VoidCallback onApplyCoupon;
  final ValueChanged<CartDiscount> onRemoveCoupon;
  final VoidCallback onDismissCouponMessage;
  final CartSafetyTipsPayload? safetyTips;
  final ValueChanged<CartSafetyTipAction>? onTapSafetyTipAction;
  final VoidCallback? onDismissSafetyTip;

  final bool selectAll;
  final Set<String> selectedItemIds;

  // نفس تموضع زر الواتساب
  final double whatsappBottom;
  final double whatsappRight;

  // ردود الأفعال
  final VoidCallback onTapDeleteAll;
  final VoidCallback onToggleSelectAll;
  final void Function(Cart item) onToggleSelectItem;
  final VoidCallback onContinueToPayment;
  final bool showCouponSection;
  final List<dynamic>? deliveryPaymentOptions;
  final String? deliveryPaymentTiming;
  final ValueChanged<String>? onSelectDeliveryPaymentTiming;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;

  const CartUI({
    super.key,
    required this.isLoading,
    required this.cartItems,
    required this.subtotal,
    required this.discounts,
    required this.currency,
    this.currencyCode,
    this.loadErrorMessage,
    this.store,
    required this.couponController,
    required this.couponInProgress,
    required this.couponError,
    required this.onApplyCoupon,
    required this.onRemoveCoupon,
    required this.onDismissCouponMessage,
    required this.selectAll,
    required this.selectedItemIds,
    required this.whatsappBottom,
    required this.whatsappRight,
    required this.onTapDeleteAll,
    required this.onToggleSelectAll,
    required this.onToggleSelectItem,
    required this.onContinueToPayment,
    this.safetyTips,
    this.onTapSafetyTipAction,
    this.onDismissSafetyTip,
    this.showCouponSection = true,
    this.deliveryPaymentOptions,
    this.deliveryPaymentTiming,
    this.onSelectDeliveryPaymentTiming,
    this.supportWhatsappLabel,
    this.supportWhatsappNumber,
    this.supportWhatsappUrl,
    this.supportWhatsappMessage,
    this.onRetry,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? fallbackCurrencyLabel;
    String? fallbackCurrencyCode;
    for (final Cart cart in cartItems) {
      final String? labelCandidate = cart.currency?.trim();
      if (labelCandidate != null && labelCandidate.isNotEmpty) {
        fallbackCurrencyLabel ??= labelCandidate;
      }
      final String? codeCandidate = cart.currencyCode ?? cart.currency;
      final String? normalizedCode =
          CurrencyUtils.normalizeCurrencyCode(codeCandidate);
      if (normalizedCode != null && normalizedCode.isNotEmpty) {
        fallbackCurrencyCode ??= normalizedCode;
      }
      if (fallbackCurrencyLabel != null && fallbackCurrencyCode != null) {
        break;
      }
    }

    final MoneyFormatter moneyFormatter = MoneyFormatter.fromCartCurrency(
      currency: currency ?? fallbackCurrencyLabel,
      currencyCode: currencyCode ?? fallbackCurrencyCode,
      fallbackLabel: fallbackCurrencyLabel ?? fallbackCurrencyCode,
    );
    final StoreStatusViewModel storeStatus =
        StoreStatusViewModel.fromMap(store);
    final String? inferredStoreName = _resolveCartStoreName(cartItems);
    final String? inferredDepartmentLabel =
        _resolveCartDepartmentLabel(cartItems);

    final String localizedFallbackRaw =
        UiUtils.getTranslatedLabel(context, 'notAvailable');
    final String fallbackStoreName = localizedFallbackRaw == 'notAvailable'
        ? 'غير متوفر'
        : localizedFallbackRaw;

    String? _trimOrNull(String? value) {
      final String? trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    final String resolvedStoreName = _trimOrNull(storeStatus.name) ??
        _trimOrNull(inferredStoreName) ??
        _trimOrNull(inferredDepartmentLabel) ??
        fallbackStoreName;

    final String? whatsappLabelRaw = supportWhatsappLabel?.trim();
    final String? whatsappNumberRaw = supportWhatsappNumber?.trim();
    final String? whatsappUrlRaw = supportWhatsappUrl?.trim();
    final String? whatsappMessageRaw = supportWhatsappMessage?.trim();

    String? sanitizeWhatsappNumber(String? raw) {
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final String digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
      return digitsOnly.isEmpty ? null : digitsOnly;
    }

    Uri? normalizeWhatsappUrl(String? raw) {
      if (raw == null) {
        return null;
      }
      String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      if (trimmed.startsWith('wa.me/')) {
        trimmed = 'https://$trimmed';
      } else if (trimmed.startsWith('whatsapp.')) {
        trimmed = 'https://$trimmed';
      } else if (!(trimmed.startsWith('http://') ||
          trimmed.startsWith('https://') ||
          trimmed.startsWith('whatsapp://'))) {
        trimmed = 'https://$trimmed';
      }

      Uri? uri = Uri.tryParse(trimmed);
      if (uri == null) {
        return null;
      }

      if (!uri.hasScheme && !trimmed.startsWith('whatsapp://')) {
        uri = Uri.tryParse('https://$trimmed');
      }

      return uri;
    }

    void showWhatsappSnack(String message) {
      HelperUtils.showSnackBarMessage(context, message);
    }

    final String? sanitizedWhatsappNumber =
        sanitizeWhatsappNumber(whatsappNumberRaw);
    final String whatsappTooltip = (whatsappLabelRaw != null &&
            whatsappLabelRaw.isNotEmpty)
        ? whatsappLabelRaw
        : 'تواصل عبر واتساب';

    Uri? buildWhatsappUri() {
      final String? sanitizedNumber = sanitizedWhatsappNumber;
      if (sanitizedNumber != null) {
        final StringBuffer buffer =
            StringBuffer('https://wa.me/$sanitizedNumber');
        if (whatsappMessageRaw != null && whatsappMessageRaw.isNotEmpty) {
          buffer.write('?text=${Uri.encodeComponent(whatsappMessageRaw)}');
        }
        return Uri.tryParse(buffer.toString());
      }

      return normalizeWhatsappUrl(whatsappUrlRaw);
    }

    Future<void> openWhatsappSupport() async {
      final Uri? uri = buildWhatsappUri();
      if (uri == null) {
        showWhatsappSnack('بيانات التواصل عبر الواتساب غير متوفرة حالياً.');
        return;
      }

      try {
        final bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          showWhatsappSnack('تعذر فتح تطبيق الواتساب.');
        }
      } catch (_) {
        showWhatsappSnack('تعذر فتح تطبيق الواتساب.');
      }
    }

    Widget buildCouponFeedback(String message) {
      final Color accent = Colors.redAccent;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: onDismissCouponMessage,
              icon: Icon(Icons.close, color: accent),
            ),
          ],
        ),
      );
    }

    Widget? buildSafetyTipsBanner() {
      final CartSafetyTipsPayload? payload = safetyTips;
      if (payload == null || !payload.showAsBanner) {
        return null;
      }

      final CartSafetyTip? tip = payload.primaryTip;
      if (tip == null || !tip.hasDescription) {
        return null;
      }

      final List<CartSafetyTipAction> actionable = tip.actions.where(
        (CartSafetyTipAction action) {
          if (action.isNavigate) {
            return action.navigatesToCart;
          }
          if (action.isOpenUrl) {
            final String? url = action.resolvedProductLink ?? action.target;
            return url != null && url.trim().isNotEmpty;
          }
          return false;
        },
      ).toList();

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.color.territoryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.color.territoryColor.withOpacity(0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: context.color.territoryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title ?? 'نصيحة السلامة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tip.description ?? '',
                        style: TextStyle(
                          color:
                              context.color.textDefaultColor.withOpacity(0.85),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismissSafetyTip != null)
                  IconButton(
                    onPressed: onDismissSafetyTip,
                    icon: Icon(
                      Icons.close,
                      color: context.color.textDefaultColor.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
            if (actionable.isNotEmpty && onTapSafetyTipAction != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actionable.map((CartSafetyTipAction action) {
                  return OutlinedButton(
                    onPressed: () => onTapSafetyTipAction?.call(action),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.color.territoryColor,
                      side: BorderSide(
                        color: context.color.territoryColor,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      action.resolvedLabel,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      );
    }

    final Widget? safetyBanner = buildSafetyTipsBanner();

    String _formatTotalAmount(double value) {
      return moneyFormatter.format(value);
    }

    Widget buildDiscountTile(CartDiscount discount) {
      final bool applied = discount.isApplied;
      final bool rejected = discount.isRejected;
      final Color accent = applied
          ? Colors.green
          : (rejected ? Colors.redAccent : Colors.orangeAccent);

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              applied
                  ? Icons.check_circle
                  : (rejected ? Icons.cancel_outlined : Icons.info_outline),
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    discount.displayTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    discount.displayMessage,
                    style: TextStyle(
                      color: context.color.textDefaultColor,
                      fontSize: 13,
                    ),
                  ),
                  if (discount.amountDisplay != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'قيمة الخصم: ${discount.amountDisplay}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (applied && (discount.code?.trim().isNotEmpty ?? false))
              IconButton(
                onPressed:
                    couponInProgress ? null : () => onRemoveCoupon(discount),
                icon: Icon(Icons.close, color: accent),
              ),
          ],
        ),
      );
    }

    Widget buildCouponSection() {
      final bool isDarkInput = Theme.of(context).brightness == Brightness.dark;
      final OutlineInputBorder border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'قسيمة الخصم',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: context.color.textDefaultColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: couponController,
                  enabled: !couponInProgress && !isLoading,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'أدخل رمز القسيمة',
                    filled: true,
                    fillColor:
                        isDarkInput ? Colors.grey.shade900 : Colors.white,
                    border: border,
                    enabledBorder: border,
                    focusedBorder: border.copyWith(
                      borderSide: BorderSide(
                        color: context.color.territoryColor,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => onApplyCoupon(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed:
                    (!couponInProgress && !isLoading) ? onApplyCoupon : null,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: couponInProgress
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('تطبيق'),
              ),
            ],
          ),
          if (couponError != null && couponError!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            buildCouponFeedback(couponError!.trim()),
          ],
          if (discounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...discounts.map(buildDiscountTile),
          ],
        ],
      );
    }

    String? _stringValue(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final String trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return value.toString();
    }

    Map<String, dynamic>? _castToStringKeyedMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      }
      return null;
    }

    bool? _asBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) {
        return value;
      }
      if (value is num) {
        if (value == 0) return false;
        if (value == 1) return true;
        return value != 0;
      }
      if (value is String) {
        final String normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) return null;
        if (<String>{'true', '1', 'yes', 'y', 'on'}.contains(normalized)) {
          return true;
        }
        if (<String>{'false', '0', 'no', 'n', 'off'}.contains(normalized)) {
          return false;
        }
      }
      return null;
    }

    List<_DeliveryTimingOption> _normalizeDeliveryTimingOptions(
        List<dynamic>? rawOptions) {
      if (rawOptions == null || rawOptions.isEmpty) {
        return const <_DeliveryTimingOption>[];
      }

      final List<_DeliveryTimingOption> options = <_DeliveryTimingOption>[];

      for (final dynamic entry in rawOptions) {
        if (entry == null) {
          continue;
        }

        if (entry is String) {
          final String? value = _stringValue(entry);
          if (value != null) {
            options.add(
              _DeliveryTimingOption(
                value: value,
                label: value,
              ),
            );
          }
          continue;
        }

        final Map<String, dynamic>? map = _castToStringKeyedMap(entry);
        if (map == null) {
          continue;
        }

        String? value = _stringValue(map['value']) ??
            _stringValue(map['id']) ??
            _stringValue(map['key']) ??
            _stringValue(map['code']) ??
            _stringValue(map['timing']);

        String? label = _stringValue(map['label']) ??
            _stringValue(map['title']) ??
            _stringValue(map['name']) ??
            _stringValue(map['text']) ??
            _stringValue(map['display']) ??
            _stringValue(map['value']);

        final List<String> descriptionParts = <String>[];

        void addDescription(dynamic candidate) {
          final String? resolved = _stringValue(candidate);
          if (resolved != null && !descriptionParts.contains(resolved)) {
            descriptionParts.add(resolved);
          }
        }

        addDescription(map['description']);
        addDescription(map['subtitle']);
        addDescription(map['hint']);
        addDescription(map['note']);
        addDescription(map['details']);

        final String? description =
            descriptionParts.isEmpty ? null : descriptionParts.join('\n');

        final bool isDisabled = (_asBool(map['disabled']) ?? false) ||
            (_asBool(map['enabled']) == false);

        final bool isSelected = _asBool(map['selected']) ??
            _asBool(map['is_selected']) ??
            _asBool(map['default']) ??
            false;

        value ??= label;
        if (value == null) {
          continue;
        }

        options.add(
          _DeliveryTimingOption(
            value: value,
            label: label ?? value,
            description: description,
            isDisabled: isDisabled,
            isInitiallySelected: isSelected,
          ),
        );
      }

      return options;
    }

    Widget? buildDeliveryPaymentTimingSection() {
      final List<_DeliveryTimingOption> options =
          _normalizeDeliveryTimingOptions(deliveryPaymentOptions);
      if (options.isEmpty) {
        return null;
      }

      String? resolvedSelectedValue = _stringValue(deliveryPaymentTiming);
      if (resolvedSelectedValue != null && resolvedSelectedValue.isEmpty) {
        resolvedSelectedValue = null;
      }

      final bool containsSelected = resolvedSelectedValue != null &&
          options.any(
            (_DeliveryTimingOption option) =>
                option.value == resolvedSelectedValue,
          );
      if (!containsSelected) {
        final _DeliveryTimingOption preselected = options.firstWhere(
          (_DeliveryTimingOption option) => option.isInitiallySelected,
          orElse: () => options.first,
        );
        resolvedSelectedValue = preselected.value;
      }

      _DeliveryTimingOption? resolvedSelectedOption;
      for (final _DeliveryTimingOption option in options) {
        if (option.value == resolvedSelectedValue) {
          resolvedSelectedOption = option;
          break;
        }
      }

      bool hasDescription(_DeliveryTimingOption option) {
        final String? text = option.description?.trim();
        return text != null && text.isNotEmpty;
      }

      final bool useSegmented = options.length <= 3 &&
          options.every((option) => !hasDescription(option));

      final Color accent = context.color.territoryColor;

      Widget buildSegmentedSelector() {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ToggleButtons(
              borderRadius: BorderRadius.circular(12),
              constraints: const BoxConstraints(minHeight: 40, minWidth: 72),
              borderColor: accent.withOpacity(0.4),
              selectedBorderColor: accent,
              fillColor: accent.withOpacity(0.12),
              color: context.color.textDefaultColor.withOpacity(0.75),
              selectedColor: accent,
              splashColor: accent.withOpacity(0.15),
              isSelected: options
                  .map((option) => option.value == resolvedSelectedValue)
                  .toList(growable: false),
              onPressed: (int index) {
                final _DeliveryTimingOption option = options[index];
                final bool isEnabled = !isLoading &&
                    !option.isDisabled &&
                    onSelectDeliveryPaymentTiming != null;
                if (!isEnabled) {
                  return;
                }
                final String value = option.value;
                if (value != resolvedSelectedValue) {
                  onSelectDeliveryPaymentTiming?.call(value);
                }
              },
              children: options.map((option) {
                final bool isSelected = option.value == resolvedSelectedValue;
                final bool isEnabled = !isLoading &&
                    !option.isDisabled &&
                    onSelectDeliveryPaymentTiming != null;
                final Color textColor = isSelected
                    ? accent
                    : isEnabled
                        ? context.color.textDefaultColor
                        : context.color.textDefaultColor.withOpacity(0.4);
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (resolvedSelectedOption != null &&
                resolvedSelectedOption.description != null &&
                resolvedSelectedOption.description!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  resolvedSelectedOption.description!,
                  style: TextStyle(
                    color: context.color.textDefaultColor.withOpacity(0.75),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        );
      }

      Widget buildRadioSelector() {
        return Column(
          children: options.map((_DeliveryTimingOption option) {
            final bool isSelected = resolvedSelectedValue == option.value;
            final bool isEnabled = !isLoading &&
                !option.isDisabled &&
                onSelectDeliveryPaymentTiming != null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color:
                    isSelected ? accent.withOpacity(0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: RadioListTile<String>(
                value: option.value,
                groupValue: resolvedSelectedValue,
                onChanged: isEnabled
                    ? (String? value) {
                        if (value == null) {
                          return;
                        }
                        if (value != resolvedSelectedValue) {
                          onSelectDeliveryPaymentTiming?.call(value);
                        }
                      }
                    : null,
                activeColor: accent,
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsetsDirectional.only(start: 4),
                title: Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.color.textDefaultColor,
                  ),
                ),
                subtitle: option.description == null
                    ? null
                    : Text(
                        option.description!,
                        style: TextStyle(
                          color:
                              context.color.textDefaultColor.withOpacity(0.75),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            );
          }).toList(),
        );
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: accent),
                const SizedBox(width: 8),
                Text(
                  'وقت دفع المبلغ المتبقي',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (useSegmented)
              buildSegmentedSelector()
            else
              buildRadioSelector(),
          ],
        ),
      );
    }

    final Widget? deliveryTimingSection = buildDeliveryPaymentTimingSection();

    ScrollPhysics buildScrollPhysics() {
      if (onRefresh != null) {
        return const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        );
      }
      return const ClampingScrollPhysics();
    }

    Widget wrapWithRefreshIndicator(Widget child) {
      if (onRefresh == null) {
        return child;
      }
      return RefreshIndicator(
        onRefresh: onRefresh!,
        color: context.color.territoryColor,
        backgroundColor: context.color.secondaryColor,
        displacement: 32,
        child: child,
      );
    }

    String resolveLoadErrorMessage() {
      final String? trimmed = loadErrorMessage?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
      return 'حدث خطأ أثناء تحميل السلة. حاول مرة أخرى.';
    }

    Widget buildErrorPlaceholder() {
      final Color accent = Colors.redAccent;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: accent, size: 44),
                const SizedBox(height: 12),
                Text(
                  resolveLoadErrorMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                if (onRetry != null)
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final bool showLoadErrorState = !isLoading &&
        (loadErrorMessage?.trim().isNotEmpty ?? false) &&
        cartItems.isEmpty;
    final ScrollPhysics scrollPhysics = buildScrollPhysics();
    final bool hasCartItems = cartItems.isNotEmpty;
    final bool showWhatsappButton = hasCartItems && sanitizedWhatsappNumber != null;
    final bool hideCartControls = !isLoading && cartItems.isEmpty;
    final bool showEmptyGuidance = hideCartControls && !showLoadErrorState;
    final bool showErrorGuidance = hideCartControls && showLoadErrorState;

    Widget buildEmptyPlaceholder() {
      final Color accent = context.color.territoryColor;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  color: accent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'سلة المشتريات فارغة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ابدأ التسوق الآن لإضافة منتجاتك المفضلة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.color.textDefaultColor.withOpacity(0.75),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: accent,
                  ),
                  child: const Text('تسوق الآن'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildCartList() {
      if (!isLoading && cartItems.isEmpty) {
        return wrapWithRefreshIndicator(
          ListView(
            physics: scrollPhysics,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              const SizedBox(height: 24),
              buildEmptyPlaceholder(),
              const SizedBox(height: 48),
            ],
          ),
        );
      }

      return wrapWithRefreshIndicator(
        ListView.separated(
          physics: scrollPhysics,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: isLoading ? 5 : cartItems.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              Widget buildSelectRow() {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: onToggleSelectAll,
                      child: Icon(
                        selectAll
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selectAll ? Colors.green : Colors.grey,
                        size: 22,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 20),
                        const SizedBox(width: 4),
                        isLoading
                            ? _buildShimmerLine(context, width: 140, height: 12)
                            : Text(
                                resolvedStoreName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.color.textDefaultColor,
                                ),
                              ),
                      ],
                    ),
                  ],
                );
              }

              final List<Widget> headerChildren = [];
              if (storeStatus.hasData) {
                headerChildren.add(
                  StoreStatusCard(
                    store: storeStatus,
                    moneyFormatter: moneyFormatter,
                    showManualBanks: true,
                  ),
                );
                headerChildren.add(const SizedBox(height: 8));
              }
              headerChildren.add(buildSelectRow());

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8.rh(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: headerChildren,
                ),
              );
            }

            if (isLoading) {
              return _buildShimmerItem(context);
            }

            final Cart item = cartItems[index - 1];
            return CartHorizontalCard(
              item: item,
              showCheckbox: true,
              isSelected: selectedItemIds.contains(item.selectionKey),
              onToggleSelect: () => onToggleSelectItem(item),
              showShadow: true,
            );
          },
        ),
      );
    }

    Widget buildErrorContent() {
      return wrapWithRefreshIndicator(
        ListView(
          physics: scrollPhysics,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            const SizedBox(height: 32),
            buildErrorPlaceholder(),
            const SizedBox(height: 48),
          ],
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const _CartScrollBehavior(),
      child: Scaffold(
        backgroundColor: context.color.primaryColor,
        body: Stack(
          children: [
          Column(
            children: [
              AppBar(
                backgroundColor: context.color.primaryColor,
                elevation: 0,
                automaticallyImplyLeading: false,
                titleSpacing: 16,
                title: Row(
                  children: [
                    BackButton(color: context.color.textColorDark),
                    const SizedBox(width: 8),
                    Text("سلة المشتريات",
                        style: TextStyle(color: context.color.textColorDark)),
                    const Spacer(),
                    if (hasCartItems)
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 26),
                        onPressed: isLoading ? null : onTapDeleteAll,
                      ),
                  ],
                ),
              ),
              if (safetyBanner != null) safetyBanner,
              Expanded(
                child:
                    showLoadErrorState ? buildErrorContent() : buildCartList(),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                    top: 10, left: 16, right: 16, bottom: 24),
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withOpacity(0.4),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Column(
                  children: [
                    if (!hideCartControls &&
                        !isLoading &&
                        showCouponSection) ...[
                      buildCouponSection(),
                      const SizedBox(height: 16),
                    ],
                    if (!hideCartControls &&
                        !isLoading &&
                        deliveryTimingSection != null) ...[
                      deliveryTimingSection,
                      const SizedBox(height: 16),
                    ],
                    if (!hideCartControls)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.color.borderColor,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.22)
                                  : Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "المبلغ الإجمالي",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            isLoading
                                ? _buildShimmerLine(context, width: 80)
                                : Text(
                                    _formatTotalAmount(subtotal),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: context.color.textDefaultColor,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    if (!hideCartControls) const SizedBox(height: 16),
                    UiUtils.buildButton(
                      context,
                      onPressed: onContinueToPayment,
                      buttonTitle: "المتابعة الى الدفع",
                      radius: 12,
                      width: double.infinity,
                      height: 40,
                      disabled: hideCartControls || isLoading,
                      onTapDisabledButton: hideCartControls
                          ? () => HelperUtils.showSnackBarMessage(
                                context,
                                showEmptyGuidance
                                    ? 'أضف منتجات إلى السلة للمتابعة إلى الدفع.'
                                    : 'انتظر حتى يتم تحميل السلة قبل المتابعة.',
                              )
                          : null,
                    ),
                    if (showEmptyGuidance) ...[
                      const SizedBox(height: 12),
                      Text(
                        'سلتك فارغة حالياً. أضف منتجات للمتابعة إلى الدفع.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              context.color.textDefaultColor.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (showErrorGuidance) ...[
                      const SizedBox(height: 12),
                      Text(
                        'تعذر المتابعة قبل تحميل السلة بنجاح. حاول تحديث الصفحة أو إعادة المحاولة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              context.color.textDefaultColor.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (showWhatsappButton)
            Positioned(
              right: whatsappRight,
              bottom: whatsappBottom,
              child: Tooltip(
                message: whatsappTooltip,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: const Color(0xFF25D366),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: openWhatsappSupport,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        height: 50,
                        width: 60,
                        child: Center(
                          child: FaIcon(
                            FontAwesomeIcons.whatsapp,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== شيمرات العرض =====
  Widget _buildShimmerItem(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.shimmerBaseColor,
      highlightColor: colorScheme.shimmerHighlightColor,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.rh(context)),
        height: 100.rh(context),
        decoration: BoxDecoration(
          color: colorScheme.shimmerContentColor,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildShimmerLine(BuildContext context,
      {double height = 14, double width = 120}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.shimmerBaseColor,
      highlightColor: colorScheme.shimmerHighlightColor,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: colorScheme.shimmerContentColor,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String? _resolveCartStoreName(List<Cart> items) {
    if (items.isEmpty) {
      return null;
    }
    for (final Cart cart in items) {
      final String? candidate = cart.user?.name?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  String? _resolveCartDepartmentLabel(List<Cart> items) {
    if (items.isEmpty) {
      return null;
    }

    final String sectionRaw = items.first.section.trim();
    if (sectionRaw.isEmpty) {
      return null;
    }

    final String? normalized = normalizeDeliveryDepartment(sectionRaw);
    switch (normalized) {
      case 'shein':
        return 'شي إن';
      case 'computer':
        return 'الكمبيوتر';
      case 'store':
        return 'المتجر';
      default:
        return null;
    }
  }
}

class _CartScrollBehavior extends ScrollBehavior {
  const _CartScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _DeliveryTimingOption {
  const _DeliveryTimingOption({
    required this.value,
    required this.label,
    this.description,
    this.isDisabled = false,
    this.isInitiallySelected = false,
  });

  final String value;
  final String label;
  final String? description;
  final bool isDisabled;
  final bool isInitiallySelected;
}
