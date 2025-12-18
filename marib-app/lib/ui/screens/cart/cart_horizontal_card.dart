import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/promoted_widget.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/variant_key.dart';

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
    this.showShadow = false,
  });

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  int? _availableStock(Cart cart) {
    final Map<String, dynamic>? snapshot = cart.stockSnapshot;
    if (snapshot == null || snapshot.isEmpty) {
      return null;
    }

    final int? explicit = _asInt(
      snapshot['available_stock'] ??
          snapshot['availableStock'] ??
          snapshot['available'] ??
          snapshot['available_quantity'] ??
          snapshot['availableQuantity'],
    );
    if (explicit != null) {
      return explicit;
    }

    final int? stock = _asInt(
      snapshot['stock'] ?? snapshot['total_stock'] ?? snapshot['totalStock'],
    );
    if (stock == null) {
      return null;
    }

    final int reserved = _asInt(
          snapshot['reserved_stock'] ??
              snapshot['reservedStock'] ??
              snapshot['reserved'],
        ) ??
        0;
    final int computed = stock - reserved;
    return computed < 0 ? 0 : computed;
  }

  String _stringifyAttributeValue(dynamic rawValue) {
    if (rawValue == null) {
      return '';
    }

    if (rawValue is String) {
      return rawValue.trim();
    }

    if (rawValue is num || rawValue is bool) {
      return rawValue.toString();
    }

    if (rawValue is Iterable) {
      final List<String> parts = rawValue
          .map((dynamic entry) => _stringifyAttributeValue(entry))
          .where((String entry) => entry.isNotEmpty)
          .toList(growable: false);
      return parts.join(', ');
    }

    if (rawValue is Map) {
      final List<String> parts = rawValue.values
          .map((dynamic entry) => _stringifyAttributeValue(entry))
          .where((String entry) => entry.isNotEmpty)
          .toList(growable: false);
      return parts.join(', ');
    }

    return rawValue.toString().trim();
  }

  String _normalizeAttributeKey(String rawKey) {
    final String lower = rawKey.toLowerCase().trim();
    return lower.replaceAll(RegExp(r'[\s_\-]+'), '');
  }

  bool _looksLikeColorKey(String normalizedKey) {
    if (normalizedKey.isEmpty) return false;
    return normalizedKey.contains('color') ||
        normalizedKey.contains('colour') ||
        normalizedKey.contains('colors') ||
        normalizedKey.contains('colours') ||
        normalizedKey.contains('لون') ||
        normalizedKey.contains('اللون') ||
        normalizedKey.contains('الالوان') ||
        normalizedKey.contains('الوان');
  }

  bool _looksLikeSizeKey(String normalizedKey) {
    if (normalizedKey.isEmpty) return false;
    return normalizedKey.contains('size') ||
        normalizedKey.contains('sizes') ||
        normalizedKey.contains('مقاس') ||
        normalizedKey.contains('مقاسات') ||
        normalizedKey.contains('حجم') ||
        normalizedKey.contains('الحجم') ||
        normalizedKey.contains('قياس') ||
        normalizedKey.contains('القياس');
  }

  bool _looksLikeHexColorToken(String token) {
    final String normalized = token.replaceAll('#', '').trim();
    if (normalized.length != 6) {
      return false;
    }
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized);
  }

  Color? _parseHexColor(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final RegExpMatch? match =
        RegExp(r'^(?:0x)?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    String hex = match.group(1)!;
    if (hex.length == 6) {
      hex = 'ff$hex';
    }

    return Color(int.parse(hex, radix: 16));
  }

  bool _looksLikeColorValue(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final List<String> tokens = trimmed.split(RegExp(r'[,/|\\s]+'));
    if (tokens.any(_looksLikeHexColorToken)) {
      return true;
    }

    final String lower = trimmed.toLowerCase();
    const List<String> englishColors = <String>[
      'black',
      'white',
      'red',
      'blue',
      'green',
      'yellow',
      'pink',
      'gray',
      'grey',
      'brown',
      'beige',
      'purple',
      'orange',
      'navy',
      'silver',
      'gold',
    ];
    if (englishColors.any(lower.contains)) {
      return true;
    }

    final String arabic = trimmed.replaceAll(' ', '');
    const List<String> arabicColors = <String>[
      'أسود',
      'اسود',
      'أبيض',
      'ابيض',
      'أحمر',
      'احمر',
      'أزرق',
      'ازرق',
      'أخضر',
      'اخضر',
      'أصفر',
      'اصفر',
      'وردي',
      'زهري',
      'رمادي',
      'بني',
      'بيج',
      'بنفسجي',
      'برتقالي',
      'ذهبي',
      'فضي',
    ];
    return arabicColors.any(arabic.contains);
  }

  bool _looksLikeSizeValue(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final String lower = trimmed.toLowerCase();
    final String condensed = lower.replaceAll(RegExp(r'[\s_\-]+'), '');

    const Set<String> literalSizes = <String>{
      'xs',
      's',
      'm',
      'l',
      'xl',
      'xxl',
      'xxxl',
      '4xl',
      '5xl',
      '6xl',
      'onesize',
      'freesize',
      'os',
    };
    if (literalSizes.contains(condensed)) {
      return true;
    }

    if (condensed.contains('فري') && condensed.contains('سايز')) {
      return true;
    }

    if (condensed.contains('مقاس') && condensed.contains('واحد')) {
      return true;
    }

    if (RegExp(r'^(eu|us|uk)\d{1,3}$').hasMatch(condensed)) {
      return true;
    }

    if (RegExp(r'^\d{1,3}([./-]\d{1,3})?$').hasMatch(condensed)) {
      return true;
    }

    return false;
  }

  List<String> _resolveColorAndSizeAttributes(Cart cart) {
    String? colorValue;
    String? sizeValue;

    void absorbKV(Object? rawKey, Object? rawValue) {
      final String value = _stringifyAttributeValue(rawValue);
      if (value.isEmpty) return;

      final String key = rawKey?.toString() ?? '';
      final String normalizedKey = _normalizeAttributeKey(key);

      if (colorValue == null &&
          normalizedKey.isNotEmpty &&
          _looksLikeColorKey(normalizedKey)) {
        colorValue = value;
        return;
      }
      if (sizeValue == null &&
          normalizedKey.isNotEmpty &&
          _looksLikeSizeKey(normalizedKey)) {
        sizeValue = value;
        return;
      }

      if (colorValue == null && _looksLikeColorValue(value)) {
        colorValue = value;
        return;
      }
      if (sizeValue == null && _looksLikeSizeValue(value)) {
        sizeValue = value;
      }
    }

    final Map<String, dynamic>? variantAttributes = cart.variantAttributes;
    if (variantAttributes != null && variantAttributes.isNotEmpty) {
      variantAttributes.forEach((key, value) => absorbKV(key, value));
    }

    final String? variantKey = cart.variantKey?.trim();
    if ((colorValue == null || sizeValue == null) &&
        variantKey != null &&
        variantKey.isNotEmpty) {
      final Map<String, String> decoded = VariantKeyCodec.decode(variantKey);
      decoded.forEach((key, value) => absorbKV(key, value));
    }

    final List<Map<String, dynamic>>? selected = cart.selectedCustomFields;
    if ((colorValue == null || sizeValue == null) &&
        selected != null &&
        selected.isNotEmpty) {
      for (final Map<String, dynamic> field in selected) {
        String label = (field['name'] ??
                field['label'] ??
                field['title'] ??
                field['key'] ??
                '')
            .toString()
            .trim();

        if (label.isEmpty) {
          final int? fieldId = _asInt(field['field_id'] ?? field['id']);
          final List<CustomFieldModel>? definitions = cart.customFields;
          if (fieldId != null && definitions != null && definitions.isNotEmpty) {
            for (final CustomFieldModel def in definitions) {
              if (def.id == fieldId) {
                final String? name = def.name?.trim();
                if (name != null && name.isNotEmpty) {
                  label = name;
                }
                break;
              }
            }
          }
        }

        absorbKV(
          label,
          field['value'] ?? field['values'],
        );

        if (colorValue != null && sizeValue != null) {
          break;
        }
      }
    }

    if (colorValue == null || sizeValue == null) {
      for (final String entry in _resolveAttributes(cart)) {
        final int colonIndex = entry.indexOf(':');
        if (colonIndex <= 0) {
          continue;
        }
        final String key = entry.substring(0, colonIndex).trim();
        final String value = entry.substring(colonIndex + 1).trim();
        if (key.isEmpty || value.isEmpty) {
          continue;
        }
        absorbKV(key, value);
        if (colorValue != null && sizeValue != null) {
          break;
        }
      }
    }

    if ((colorValue == null || sizeValue == null) &&
        cart.customFields != null &&
        cart.customFields!.isNotEmpty) {
      for (final CustomFieldModel field in cart.customFields!) {
        final List<String> selectedValues = field.value;
        if (selectedValues.isEmpty) {
          continue;
        }

        final String label = field.name?.trim() ?? '';
        final String normalizedKey = _normalizeAttributeKey(label);
        final String value = _stringifyAttributeValue(selectedValues);
        if (value.isEmpty) {
          continue;
        }

        final String type = field.type?.toLowerCase().trim() ?? '';
        if (colorValue == null &&
            ((normalizedKey.isNotEmpty && _looksLikeColorKey(normalizedKey)) ||
                type == 'color' ||
                _looksLikeColorValue(value))) {
          colorValue = value;
        }

        if (sizeValue == null &&
            ((normalizedKey.isNotEmpty && _looksLikeSizeKey(normalizedKey)) ||
                _looksLikeSizeValue(value))) {
          sizeValue = value;
        }

        if (colorValue != null && sizeValue != null) {
          break;
        }
      }
    }

    final List<String> chips = <String>[];
    if (colorValue != null) {
      chips.add('لون: $colorValue');
    }
    if (sizeValue != null) {
      chips.add('مقاس: $sizeValue');
    }
    return chips;
  }

  String _resolveCurrencyLabel({String? currency, String? currencyCode}) {
    final String? preferred =
        CurrencyUtils.preferredDisplayFor(currencyCode ?? currency);
    if (preferred != null && preferred.trim().isNotEmpty) {
      return preferred.trim();
    }

    final String? trimmed = currency?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      final String normalized =
          CurrencyUtils.preferredDisplayFor(trimmed) ?? trimmed;
      final String normalizedTrimmed = normalized.trim();
      if (normalizedTrimmed.isNotEmpty) {
        return normalizedTrimmed;
      }
    }

    return CurrencyUtils.preferredDisplayFor('YER') ?? Constant.currencySymbol;
  }

  List<String> _resolveAttributes(Cart cart) {
    final LinkedHashSet<String> attributes = LinkedHashSet<String>();

    void addKV(String key, Object? value) {
      final String k = key.trim();
      if (k.isEmpty) return;
      final String v = _stringifyAttributeValue(value);
      if (v.isEmpty) {
        attributes.add(k);
        return;
      }
      attributes.add('$k: $v');
    }

    final Map<String, dynamic>? variantAttributes = cart.variantAttributes;
    if (variantAttributes != null && variantAttributes.isNotEmpty) {
      variantAttributes.forEach((key, value) {
        addKV(key.toString(), value);
      });
    } else {
      final String? variantKey = cart.variantKey?.trim();
      if (variantKey != null && variantKey.isNotEmpty) {
        final Map<String, String> decoded = VariantKeyCodec.decode(variantKey);
        decoded.forEach(addKV);
      }
    }

    final List<Map<String, dynamic>>? selected = cart.selectedCustomFields;
    if (selected != null && selected.isNotEmpty) {
      for (final Map<String, dynamic> field in selected) {
        String label = (field['name'] ??
                field['label'] ??
                field['title'] ??
                field['key'] ??
                '')
            .toString()
            .trim();

        if (label.isEmpty) {
          final int? fieldId = _asInt(field['field_id'] ?? field['id']);
          final List<CustomFieldModel>? definitions = cart.customFields;
          if (fieldId != null && definitions != null && definitions.isNotEmpty) {
            for (final CustomFieldModel def in definitions) {
              if (def.id == fieldId) {
                final String? name = def.name?.trim();
                if (name != null && name.isNotEmpty) {
                  label = name;
                }
                break;
              }
            }
          }
        }

        final String value = _stringifyAttributeValue(
          field['value'] ?? field['values'],
        );

        if (label.isNotEmpty && value.isNotEmpty) {
          attributes.add('$label: $value');
        } else if (value.isNotEmpty) {
          attributes.add(value);
        } else if (label.isNotEmpty) {
          attributes.add(label);
        }
      }
    }

    return attributes.toList(growable: false);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        title: "تأكيد الحذف",
        cancelTextColor: context.color.textColorDark,
        content: Text("confirmDeleteProductFromCart".translate(context)),
      ),
    ) as bool?;
    return confirmed == true;
  }

  Future<void> _performDelete(BuildContext context) async {
    if (onDeleteTap != null) {
      onDeleteTap!();
      return;
    }
    if (item.id == null) return;
    await context.read<CartCubit>().removeItem(
          cartItemId: item.cartItemId,
          itemId: item.id!,
        );
  }

  Future<void> _requestDelete(BuildContext context) async {
    if (!await _confirmDelete(context)) {
      return;
    }
    await _performDelete(context);
  }

  void _openAdDetails(BuildContext context) {
    if (item.id == null) return;
    Navigator.pushNamed(
      context,
      Routes.adDetailsScreen,
      arguments: <String, dynamic>{'model': item},
    );
  }

  _ColorChipData? _colorChipFromText(String text) {
    final int colonIndex = text.indexOf(':');
    String label = text.trim();
    String value = '';
    if (colonIndex >= 0) {
      label = text.substring(0, colonIndex).trim();
      value = text.substring(colonIndex + 1).trim();
    }

    final Color? parsedColor = _parseHexColor(value);
    if (parsedColor == null) {
      return null;
    }

    final bool isHexOnly =
        RegExp(r'^(?:#|0x)?[0-9a-fA-F]{6,8}$').hasMatch(value.trim());
    final String? displayValue = isHexOnly ? null : value.trim();

    return _ColorChipData(
      label: label.isEmpty ? 'لون' : label,
      valueLabel: displayValue,
      color: parsedColor,
    );
  }

  Widget _chip(BuildContext context, String text) {
    final _ColorChipData? colorChip = _colorChipFromText(text);

    final Widget child = colorChip != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                colorChip.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.color.textDefaultColor,
                  fontSize: context.font.small,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (colorChip.valueLabel != null &&
                  colorChip.valueLabel!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  colorChip.valueLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontSize: context.font.small,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorChip.color,
                  border: Border.all(
                    color: context.color.borderColor.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          )
        : Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontSize: context.font.small,
              fontWeight: FontWeight.w600,
            ),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.color.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.color.borderColor.withOpacity(0.5)),
      ),
      child: child,
    );
  }

  Widget _stockLabel(BuildContext context, int? availableStock) {
    if (availableStock == null) {
      return const SizedBox.shrink();
    }

    final bool isEmpty = availableStock <= 0;
    final Color color = isEmpty
        ? Colors.redAccent
        : (availableStock <= 3 ? Colors.orange : Colors.green);

    final String label =
        isEmpty ? 'غير متوفر' : 'المتبقي: ${availableStock.toString()}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inventory_2_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: context.font.small,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _quantityControls(BuildContext context, int? availableStock) {
    final CartCubit cartCubit = context.read<CartCubit>();
    final bool canIncrease =
        availableStock == null ? true : item.quantity < availableStock;

    Future<void> handleIncrease() async {
      if (item.id == null) return;

      if (availableStock != null) {
        if (availableStock <= 0) {
          HelperUtils.showSnackBarMessage(context, 'هذا المنتج غير متوفر حالياً.');
          return;
        }
        if (!canIncrease) {
          HelperUtils.showSnackBarMessage(
            context,
            'لا يمكن زيادة الكمية، المتبقي $availableStock فقط.',
          );
          return;
        }
      }

      await cartCubit.increaseQuantity(
        cartItemId: item.cartItemId,
        itemId: item.id!,
      );
    }

    Future<void> handleDecrease() async {
      if (item.id == null) return;
      final int quantity = cartCubit.getQuantityForCartItem(
        cartItemId: item.cartItemId,
        itemId: item.id!,
      );

      if (quantity <= 1) {
        await _requestDelete(context);
        return;
      }

      await cartCubit.decreaseQuantity(
        cartItemId: item.cartItemId,
        itemId: item.id!,
      );
    }

    Widget buildButton({
      required IconData icon,
      required VoidCallback onTap,
      required bool enabled,
      required Color activeColor,
    }) {
      final Color iconColor =
          enabled ? activeColor : context.color.textDefaultColor.withOpacity(0.3);
      return InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activeColor.withOpacity(enabled ? 0.14 : 0.06),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: iconColor),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.color.primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildButton(
            icon: Icons.remove,
            onTap: () => unawaited(handleDecrease()),
            enabled: true,
            activeColor: Colors.orange,
          ),
          const SizedBox(width: 14),
          Text(
            item.quantity.toString(),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: context.font.normal * 1.2,
              color: context.color.textDefaultColor,
            ),
          ),
          const SizedBox(width: 14),
          buildButton(
            icon: Icons.add,
            onTap: () => unawaited(handleIncrease()),
            enabled: canIncrease,
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final String rawPriceLabel = HelperUtils.formatPrice(item.unitPriceValue);
    final String priceLabel = rawPriceLabel.isEmpty ? 'غير متوفر' : rawPriceLabel;
    final String currencyLabel = _resolveCurrencyLabel(
      currency: item.currency,
      currencyCode: item.currencyCode,
    );

    final int? availableStock = _availableStock(item);
    final List<String> attributes = _resolveColorAndSizeAttributes(item);

    final Color shadowColor = isDark
        ? Colors.black.withOpacity(0.22)
        : Colors.black.withOpacity(0.08);

    final Widget card = Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.borderColor.withOpacity(0.6)),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCheckbox)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, end: 10),
              child: InkResponse(
                onTap: onToggleSelect,
                radius: 20,
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.green : Colors.grey,
                  size: 22,
                ),
              ),
            ),
          InkWell(
            onTap: () => _openAdDetails(context),
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 92 + (additionalImageWidth ?? 0),
              height: 92,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: UiUtils.getImage(
                        item.image ?? "",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (item.isFeature ?? false)
                    const PositionedDirectional(
                      start: 6,
                      top: 6,
                      child: PromotedCard(type: PromoteCardType.icon),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        (item.name ?? '').firstUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.font.normal,
                          fontWeight: FontWeight.w700,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'حذف',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minHeight: 36, minWidth: 36),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      onPressed: () => unawaited(_requestDelete(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceLabel,
                      style: TextStyle(
                        fontSize: context.font.large,
                        fontWeight: FontWeight.w800,
                        color: context.color.territoryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currencyLabel,
                      style: TextStyle(
                        fontSize: context.font.normal * 0.75,
                        fontWeight: FontWeight.w700,
                        color: context.color.textDefaultColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                if (attributes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: attributes.map((text) => _chip(context, text)).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _stockLabel(context, availableStock)),
                    _quantityControls(context, availableStock),
                  ],
                ),
                if (addBottom != null && addBottom!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...addBottom!,
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: card,
    );
  }
}

class _ColorChipData {
  final String label;
  final String? valueLabel;
  final Color color;

  _ColorChipData({
    required this.label,
    required this.color,
    this.valueLabel,
  });
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
