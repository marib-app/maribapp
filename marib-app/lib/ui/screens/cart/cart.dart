import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/services.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';

import 'cart_ui.dart';
import 'package:marib/data/model/cart/cart_discount.dart';
import 'package:marib/data/model/cart/cart_safety_tip.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:marib/utils/store_status_view_model.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(builder: (_) => const CartScreen());
  }
}

class _CartScreenState extends State<CartScreen> {
  bool _loading = true;
  String? _loadErrorMessage;

  bool _selectAll = false;
  final Set<String> _selectedItems = <String>{};
  final TextEditingController _couponController = TextEditingController();

  // موضع زر واتساب العائم
  final double _whatsappBottom = 155;
  final double _whatsappRight = 340;
  Set<String> _appliedCouponSnapshot = <String>{};
  CartState? _lastCartState;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  // TODO: اربط بمصدر بيانات حقيقي بدلاً من أي بيانات مؤقتة.
  Future<void> _initLoad() async {
    setState(() {
      _loading = true;
      _loadErrorMessage = null;
    });

    try {
      // مثال: await context.read<CartCubit>().loadCartFromApi();
      // ملاحظة: يعتمد على توفر واجهات الخلفية/البيانات المبدئية حالياً.
      final CartCubit cubit = context.read<CartCubit>();
      _syncCouponSnapshot(cubit.state.discounts);
      _lastCartState = cubit.state;
      await cubit.fetchCart();
      _syncCouponSnapshot(cubit.state.discounts);
      _lastCartState = cubit.state;
    } catch (_) {
      // TODO: عالج الأخطاء بحسب نظام التنبيهات لديك
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleSelectAll(List<Cart> cartItems) {
    setState(() {
      _selectAll = !_selectAll;
      _selectedItems.clear();
      if (_selectAll) {
        _selectedItems.addAll(cartItems.map((e) => e.selectionKey));
      }
    });
  }

  void _toggleSelectItem(Cart item, int totalCount) {
    final String key = item.selectionKey;
    setState(() {
      if (_selectedItems.contains(key)) {
        _selectedItems.remove(key);
      } else {
        _selectedItems.add(key);
      }
      _selectAll = (_selectedItems.length == totalCount && totalCount > 0);
    });
  }

  void _syncCouponSnapshot(List<CartDiscount> discounts) {
    _appliedCouponSnapshot = _extractAppliedCoupons(discounts);
  }

  Set<String> _extractAppliedCoupons(List<CartDiscount> discounts) {
    final Set<String> applied = <String>{};
    for (final CartDiscount discount in discounts) {
      final String? code = discount.code;
      if (code == null || !discount.isApplied) {
        continue;
      }
      final String trimmed = code.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      applied.add(trimmed.toLowerCase());
    }
    return applied;
  }

  CartDiscount? _findDiscountByNormalizedCode(
    List<CartDiscount> discounts,
    String normalizedCode,
  ) {
    for (final CartDiscount discount in discounts) {
      final String? code = discount.code;
      if (code == null) continue;
      final String trimmed = code.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.toLowerCase() == normalizedCode) {
        return discount;
      }
    }
    return null;
  }

  CurrencyParseResult _resolveCartCurrencyInfo(CartState state) {
    String? display = state.currency?.trim();
    String? code = CurrencyUtils.normalizeCurrencyCode(state.currencyCode);

    void considerDisplay(String? candidate) {
      if (display != null) {
        return;
      }
      final String? trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        display = trimmed;
      }
    }

    void considerCode(String? candidate) {
      if (code != null) {
        return;
      }
      final String? normalized = CurrencyUtils.normalizeCurrencyCode(candidate);
      if (normalized != null && normalized.isNotEmpty) {
        code = normalized;
      }
    }

    considerCode(display);
    considerCode(state.currencyCode);

    final List<Map<String, dynamic>?> currencySources = <Map<String, dynamic>?>[
      state.deliveryQuote,
      state.departmentPolicy,
      state.blocking,
      state.support,
    ];

    for (final Map<String, dynamic>? source in currencySources) {
      if (source == null || source.isEmpty) {
        continue;
      }
      final CurrencyParseResult info = CurrencyUtils.parseCurrency(source);
      considerDisplay(info.display);
      considerCode(info.code);
    }

    for (final Cart item in state.items) {
      considerDisplay(item.currency);
      considerCode(item.currencyCode);
      considerCode(item.currency);
    }

    if (code == null) {
      considerCode(display);
    }

    return CurrencyParseResult(code: code, display: display);
  }

  String? _resolveCartCurrencyLabel(CartState state) {
    final CurrencyParseResult info = _resolveCartCurrencyInfo(state);
    return CurrencyUtils.displayToken(
      label: info.display,
      fallback: info.code,
      code: info.code,
    );
  }

  String? _resolveCartCurrencyCode(CartState state) {
    final CurrencyParseResult info = _resolveCartCurrencyInfo(state);
    return info.code;
  }

  CurrencyParseResult _currencyInfoFromMap(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) {
      return const CurrencyParseResult();
    }
    return CurrencyUtils.parseCurrency(source);
  }

  String? _asString(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }

  Future<void> _clearAll() async {
    await context.read<CartCubit>().clearCart();
    setState(() {
      _selectedItems.clear();
      _selectAll = false;
    });
  }

  Future<void> _applyCoupon() async {
    await context.read<CartCubit>().applyCoupon(_couponController.text);
  }

  Future<void> _updateDeliveryPaymentTiming(String timing) async {
    await context.read<CartCubit>().updateDeliveryPaymentTiming(timing);
  }

  Future<void> _removeCoupon(CartDiscount discount) async {
    String? code = discount.code;
    code ??= discount.raw?['coupon_code']?.toString();
    code ??= discount.raw?['coupon']?.toString();
    code ??= discount.raw?['code']?.toString();

    await context.read<CartCubit>().removeCoupon(code);
  }

  void _dismissCouponMessage() {
    context.read<CartCubit>().clearCouponFeedback();
  }

  Future<void> _handleSafetyTipAction(CartSafetyTipAction action) async {
    if (!mounted) return;
    final CartCubit cubit = context.read<CartCubit>();

    try {
      if (action.isNavigate && action.navigatesToCart) {
        if (ModalRoute.of(context)?.settings.name != Routes.cart) {
          await Navigator.of(context).pushNamed(Routes.cart);
        }
      } else if (action.isOpenUrl) {
        final String? url = action.resolvedProductLink ?? action.target;
        if (url != null && url.trim().isNotEmpty) {
          final Uri? uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } finally {
      if (mounted) {
        cubit.clearSafetyTips();
      }
    }
  }

  void _dismissSafetyTipsBanner() {
    if (!mounted) return;
    context.read<CartCubit>().clearSafetyTips();
  }

  Future<void> _showStoreClosedSheet(StoreStatusViewModel status) async {
    const String fallbackStore = '\u0627\u0644\u0645\u062a\u062c\u0631';
    final String storeName = (status.name?.trim().isNotEmpty ?? false)
        ? status.name!.trim()
        : fallbackStore;
    final String? nextOpen = status.formatNextOpenLabel(locale: 'ar');
    final DateTime now = DateTime.now();
    final DateTime? nextOpenAt = status.nextOpenAt;
    final Duration? untilOpen =
        nextOpenAt != null ? nextOpenAt.difference(now) : null;
    final int hoursHint = (untilOpen != null && untilOpen.inMinutes > 0)
        ? ((untilOpen.inMinutes + 59) ~/ 60)
        : 6;
    final String sixHoursHint =
        DateFormat('EEEE d MMM, h:mm a', 'ar').format(now.add(
      Duration(hours: hoursHint),
    ));
    final String nextOpenDisplay = (nextOpen != null && nextOpen.trim().isNotEmpty)
        ? nextOpen.trim()
        : sixHoursHint;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext sheetContext) {
        final Color accent = Colors.orange;
        final TextStyle? titleStyle = Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w800);
        final TextStyle? bodyStyle = Theme.of(context).textTheme.bodyMedium;

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.lock_clock, color: accent, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '\u0627\u0644\u0645\u062a\u062c\u0631  \u0645\u063a\u0644\u0642 \u0627\u0644\u0622\u0646',
                      style: titleStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIconLine(
                      icon: Icons.error_outline,
                      color: accent,
                      text:
                          '\u0644\u0627 \u064a\u0645\u0643\u0646 \u0625\u062a\u0645\u0627\u0645 \u0627\u0644\u062f\u0641\u0639 \u0623\u0648 \u0627\u0644\u062a\u0648\u0635\u064a\u0644 \u0623\u062b\u0646\u0627\u0621 \u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u0645\u062a\u062c\u0631.',
                      style: bodyStyle,
                    ),
                    if (nextOpen != null && nextOpen.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildIconLine(
                        icon: Icons.schedule_outlined,
                        color: Colors.teal,
                        text: '\u0627\u0644\u0641\u062a\u062d \u0627\u0644\u0642\u0627\u062f\u0645: $nextOpenDisplay',
                        style: bodyStyle,
                      ),
                    ],
                    if (hoursHint < 24) ...[
                      const SizedBox(height: 10),
                      _buildIconLine(
                        icon: Icons.lightbulb_outline,
                        color: Colors.blueGrey,
                        text:
                            '\u062c\u0631\u0651\u0628 \u0627\u0644\u0631\u062c\u0648\u0639 \u0628\u0639\u062f \u0646\u062d\u0648 $hoursHint \u0633\u0627\u0639\u0629.',
                        style: bodyStyle,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '\u0644\u0627 \u064a\u0645\u0643\u0646\u0646\u0627 \u0627\u0633\u062a\u0644\u0627\u0645 \u0627\u0644\u0637\u0644\u0628 \u0648\u0645\u0639\u0627\u0644\u062c\u062a\u0647 \u0623\u062b\u0646\u0627\u0621 \u0627\u0644\u0625\u063a\u0644\u0627\u0642. \u0633\u0646\u0643\u0648\u0646 \u062c\u0627\u0647\u0632\u064a\u0646 \u0644\u062e\u062f\u0645\u062a\u0643 \u0628\u0645\u062c\u0631\u062f \u0641\u062a\u062d \u0627\u0644\u0645\u062a\u062c\u0631.',
                style: bodyStyle?.copyWith(color: Colors.blueGrey.shade700),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '\u062d\u0633\u0646\u0627\u064b \u0641\u0647\u0645\u062a',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconLine({
    required IconData icon,
    required Color color,
    required String text,
    TextStyle? style,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: style,
          ),
        ),
      ],
    );
  }

  void _continueToPayment(List<Cart> cartItems) {
    if (cartItems.isEmpty) {
      UiUtils.showBlurredDialoge(
        context,
        dialoge: BlurredDialogBox(
          title: "تنبيه",
          content: const Text(
              "السلة فارغة حالياً. يرجى إضافة منتجات أولاً."),
          showCancleButton: false,
        ),
      );
      return;
    }
    final StoreStatusViewModel storeStatus =
        StoreStatusViewModel.fromMap(context.read<CartCubit>().state.store);
    final bool storeClosed = storeStatus.hasData &&
        !storeStatus.isOpenNow &&
        !storeStatus.browseOnly;
    if (storeClosed) {
      _showStoreClosedSheet(storeStatus);
      return;
    }
    Navigator.pushNamed(context, Routes.deliveryandpayment);
  }

  @override
  Widget build(BuildContext context) {
    final CartState cartState = context.watch<CartCubit>().state;
    final List<Cart> cartItems = cartState.items;
    final double subtotal = context.read<CartCubit>().subtotal;

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

    String? _stringValue(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is String) {
        final String trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return value.toString();
    }

    String? _firstStringValue(Map<String, dynamic>? map, List<String> keys) {
      if (map == null || map.isEmpty) {
        return null;
      }
      for (final String key in keys) {
        if (!map.containsKey(key)) {
          continue;
        }
        final String? result = _stringValue(map[key]);
        if (result != null) {
          return result;
        }
      }
      return null;
    }

    Map<String, dynamic>? _firstMap(dynamic value) {
      final Map<String, dynamic>? direct = _castToStringKeyedMap(value);
      if (direct != null) {
        return direct;
      }
      if (value is Iterable) {
        for (final dynamic entry in value) {
          final Map<String, dynamic>? inner = _castToStringKeyedMap(entry);
          if (inner != null) {
            return inner;
          }
        }
      }
      return null;
    }

    final Map<String, dynamic>? supportMap =
        _castToStringKeyedMap(cartState.support);
    String? supportWhatsappNumber;
    String? supportWhatsappUrl;
    String? supportWhatsappMessage;
    String? supportWhatsappLabel;
    dynamic supportWhatsappData;

    const List<String> numberKeys = <String>[
      'whatsapp_number',
      'whatsappNumber',
      'whatsapp',
      'number',
      'phone',
      'phone_number',
      'contact',
      'value',
      'recipient',
    ];
    const List<String> urlKeys = <String>[
      'whatsapp_url',
      'whatsappUrl',
      'wa_url',
      'waUrl',
      'wa_link',
      'waLink',
      'url',
      'link',
      'href',
      'ready_url',
      'readyUrl',
      'action_url',
      'actionUrl',
      'deep_link',
      'deepLink',
    ];
    const List<String> messageKeys = <String>[
      'message',
      'default_message',
      'defaultMessage',
      'prefill',
      'text',
      'body',
    ];
    const List<String> labelKeys = <String>[
      'label',
      'title',
      'button_label',
      'buttonLabel',
      'button_text',
      'buttonText',
      'cta',
      'cta_text',
      'ctaText',
      'name',
      'text',
    ];

    if (supportMap != null) {
      supportWhatsappData = supportMap['whatsapp'] ?? supportMap['whatsApp'];

      Map<String, dynamic>? whatsappMap = _firstMap(supportWhatsappData);

      final Map<String, dynamic>? channelsMap =
          _firstMap(supportMap['channels']) ??
              _firstMap(supportMap['contact_channels']);
      if (channelsMap != null && whatsappMap == null) {
        whatsappMap = _firstMap(channelsMap['whatsapp']);
        supportWhatsappData ??= channelsMap['whatsapp'];
      }

      supportWhatsappNumber = _firstStringValue(whatsappMap, numberKeys) ??
          _firstStringValue(supportMap, numberKeys);
      supportWhatsappUrl = _firstStringValue(whatsappMap, urlKeys) ??
          _firstStringValue(supportMap, urlKeys);
      supportWhatsappMessage = _firstStringValue(whatsappMap, messageKeys) ??
          _firstStringValue(supportMap, messageKeys);
      supportWhatsappLabel = _firstStringValue(whatsappMap, labelKeys) ??
          _firstStringValue(supportMap, labelKeys);
      supportWhatsappData ??= whatsappMap;

      if (supportWhatsappUrl == null) {
        final dynamic whatsappRaw = supportMap['whatsapp'];
        final String? textCandidate = _stringValue(whatsappRaw);
        if (textCandidate != null &&
            (textCandidate.contains('http') ||
                textCandidate.startsWith('wa.me/') ||
                textCandidate.startsWith('whatsapp')) &&
            supportWhatsappUrl == null) {
          supportWhatsappUrl = textCandidate;
        }
      }

      if (supportWhatsappNumber == null) {
        final dynamic whatsappRaw = supportMap['whatsapp'];
        if (whatsappRaw is String) {
          final String trimmed = whatsappRaw.trim();
          if (trimmed.isNotEmpty) {
            supportWhatsappNumber = trimmed;
          }
        }
      }
    }

    final Map<String, dynamic>? departmentPolicyMap =
        _castToStringKeyedMap(cartState.departmentPolicy);
    if (departmentPolicyMap != null) {
      final dynamic policyWhatsappData = departmentPolicyMap['whatsapp'] ??
          departmentPolicyMap['whatsApp'] ??
          departmentPolicyMap['support'] ??
          departmentPolicyMap['support_info'] ??
          departmentPolicyMap['supportInfo'];

      Map<String, dynamic>? whatsappMap = _firstMap(policyWhatsappData);
      final Map<String, dynamic>? channelsMap =
          _firstMap(departmentPolicyMap['channels']) ??
              _firstMap(departmentPolicyMap['contact_channels']);
      if (channelsMap != null && whatsappMap == null) {
        whatsappMap = _firstMap(channelsMap['whatsapp']);
      }

      supportWhatsappNumber ??= _firstStringValue(whatsappMap, numberKeys) ??
          _firstStringValue(departmentPolicyMap, numberKeys);
      supportWhatsappUrl ??= _firstStringValue(whatsappMap, urlKeys) ??
          _firstStringValue(departmentPolicyMap, urlKeys);
      supportWhatsappMessage ??= _firstStringValue(whatsappMap, messageKeys) ??
          _firstStringValue(departmentPolicyMap, messageKeys);
      supportWhatsappLabel ??= _firstStringValue(whatsappMap, labelKeys) ??
          _firstStringValue(departmentPolicyMap, labelKeys);
    }

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: BlocListener<CartCubit, CartState>(
        listenWhen: (CartState previous, CartState current) {
          return previous.couponInProgress != current.couponInProgress ||
              previous.discounts != current.discounts ||
              previous.couponError != current.couponError;
        },
        listener: (BuildContext context, CartState state) {
          final CartState? previousState = _lastCartState;
          final Set<String> previousCoupons = _appliedCouponSnapshot;
          final Set<String> nextCoupons =
              _extractAppliedCoupons(state.discounts);

          if (_loading) {
            _appliedCouponSnapshot = nextCoupons;
            _lastCartState = state;
            return;
          }
          if (!state.couponInProgress && state.couponError == null) {
            final String trimmed = _couponController.text.trim();
            if (trimmed.isNotEmpty) {
              final String lower = trimmed.toLowerCase();
              if (nextCoupons.contains(lower)) {
                _couponController.clear();
              }
            }
          }

          final String? trimmedError = state.couponError?.trim();
          final String? previousError = previousState?.couponError?.trim();
          if (trimmedError != null &&
              trimmedError.isNotEmpty &&
              trimmedError != previousError) {
            HelperUtils.showSnackBarMessage(context, trimmedError);
          } else if (!state.couponInProgress) {
            final Set<String> newlyApplied =
                nextCoupons.difference(previousCoupons);
            if (newlyApplied.isNotEmpty) {
              for (final String normalized in newlyApplied) {
                final CartDiscount? discount =
                    _findDiscountByNormalizedCode(state.discounts, normalized);
                final String resolvedCode =
                    (discount?.code ?? normalized).trim().toUpperCase();
                final String title = ((discount?.displayTitle ?? '').trim());
                final String message = title.isNotEmpty &&
                        title.toLowerCase() != resolvedCode.toLowerCase()
                    ? 'تم تطبيق كوبون الخصم $resolvedCode بنجاح: $title'
                    : 'تم تطبيق كوبون الخصم $resolvedCode بنجاح.';
                HelperUtils.showSnackBarMessage(context, message);
              }
            }
          }

          _appliedCouponSnapshot = nextCoupons;
          _lastCartState = state;
        },
        child: CartUI(
          isLoading: _loading,
          cartItems: cartItems,
          subtotal: subtotal,
          currency: _resolveCartCurrencyLabel(cartState),
          currencyCode: _resolveCartCurrencyCode(cartState),
          loadErrorMessage: _loadErrorMessage,
          store: cartState.store,
          selectAll: _selectAll,
          selectedItemIds: _selectedItems,
          whatsappBottom: _whatsappBottom,
          whatsappRight: _whatsappRight,
          onTapDeleteAll: () {
            if (cartItems.isEmpty) {
              HelperUtils.showSnackBarMessage(
                context,
                'السلة فارغة، لا توجد عناصر للحذف.',
              );
            } else {
              UiUtils.showBlurredDialoge(
                context,
                dialoge: BlurredDialogBox(
                  title: 'تأكيد الحذف',
                  onAccept: _clearAll,
                  cancelTextColor: context.color.textColorDark,
                  content: const Text(
                      'هل أنت متأكد من حذف جميع المنتجات؟'),
                ),
              );
            }
          },
          onToggleSelectAll: () => _toggleSelectAll(cartItems),
          onToggleSelectItem: (Cart item) =>
              _toggleSelectItem(item, cartItems.length),
          onContinueToPayment: () => _continueToPayment(cartItems),
          discounts: cartState.discounts,
          supportWhatsappLabel: supportWhatsappLabel,
          supportWhatsappNumber: supportWhatsappNumber,
          supportWhatsappUrl: supportWhatsappUrl,
          supportWhatsappMessage: supportWhatsappMessage,
          couponController: _couponController,
          couponInProgress: cartState.couponInProgress,
          couponError: cartState.couponError,
          onApplyCoupon: _applyCoupon,
          onRemoveCoupon: _removeCoupon,
          onDismissCouponMessage: _dismissCouponMessage,
          safetyTips: cartState.safetyTips,
          onTapSafetyTipAction: _handleSafetyTipAction,
          onDismissSafetyTip: _dismissSafetyTipsBanner,
          showCouponSection: false,
          // Checkout-related settings (delivery/payment timing, policies, etc.)
          // are loaded and shown inside the checkout screen only.
          deliveryPaymentOptions: null,
          deliveryPaymentTiming: null,
          onSelectDeliveryPaymentTiming: null,
          onRetry: () => _initLoad(),
          onRefresh: _initLoad,
        ),
      ),
    );
  }
}
