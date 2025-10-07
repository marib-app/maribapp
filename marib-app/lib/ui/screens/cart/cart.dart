// 🛒 المنطق فقط
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/theme/theme.dart';
// لو كنت تستخدم AnnotatedRegion بنمط النظام
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart'; // لتعريف BlurredDialogBox

import 'package:marib/ui/screens/cart/cart_ui.dart';
import 'package:marib/data/model/cart/cart_discount.dart';
import 'package:marib/data/model/cart/cart_safety_tip.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:marib/utils/helper_utils.dart';

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

  bool _selectAll = false;
  final Set<int> _selectedItems = <int>{};
  final TextEditingController _couponController = TextEditingController();

  // نفس القيم الأصلية
  final double _whatsappBottom = 155;
  final double _whatsappRight = 340;

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

  // TODO: اربط بمصدر بياناتك الحقيقي بدلاً من أي بيانات مؤقتة.
  Future<void> _initLoad() async {
    setState(() => _loading = true);
    try {
      // مثال: await context.read<CartCubit>().loadCartFromApi();
      // ملاحظة: عند وصول البيانات، لا تنسَ ضبط الاختيارات/الافتراضي حسب حاجتك.
      final CartCubit cubit = context.read<CartCubit>();
      await cubit.fetchCart();
      final CartState cartState = cubit.state;
      final bool needsPaymentTimingRefresh =
          cartState.deliveryPaymentOptions == null ||
              cartState.deliveryPaymentOptions!.isEmpty ||
              cartState.deliveryPaymentTiming == null ||
              cartState.deliveryPaymentTiming!.trim().isEmpty;
      if (needsPaymentTimingRefresh) {
        await cubit.refreshDeliveryPaymentTiming();
      }
    } catch (_) {
      // TODO: تعامل مع الخطأ حسب نظام التنبيهات لديك
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleSelectAll(List<Cart> cartItems) {
    setState(() {
      _selectAll = !_selectAll;
      _selectedItems.clear();
      if (_selectAll) {
        _selectedItems
            .addAll(cartItems.where((e) => e.id != null).map((e) => e.id!));
      }
    });
  }

  void _toggleSelectItem(int? id, int totalCount) {
    if (id == null) return;
    setState(() {
      if (_selectedItems.contains(id)) {
        _selectedItems.remove(id);
      } else {
        _selectedItems.add(id);
      }
      _selectAll = (_selectedItems.length == totalCount && totalCount > 0);
    });
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
    if (code == null || code.trim().isEmpty) {
      return;
    }
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

  void _continueToPayment(List<Cart> cartItems) {
    if (cartItems.isEmpty) {
      UiUtils.showBlurredDialoge(
        context,
        dialoge: BlurredDialogBox(
          title: "تنبيه",
          content: const Text("السلة فارغة، يرجى إضافة منتجات أولاً."),
          showCancleButton: false,
        ),
      );
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
          if (!state.couponInProgress && state.couponError == null) {
            final String trimmed = _couponController.text.trim();
            if (trimmed.isNotEmpty) {
              final String lower = trimmed.toLowerCase();
              final bool applied = state.discounts.any((CartDiscount discount) {
                final String? code = discount.code?.trim();
                if (code == null || code.isEmpty) return false;
                return discount.isApplied && code.toLowerCase() == lower;
              });
              if (applied) {
                _couponController.clear();
              }
            }
          }
        },
        child: CartUI(
          isLoading: _loading,
          cartItems: cartItems,
          subtotal: subtotal,
          selectAll: _selectAll,
          selectedItemIds: _selectedItems,
          whatsappBottom: _whatsappBottom,
          whatsappRight: _whatsappRight,
          onTapDeleteAll: () {
            if (cartItems.isEmpty) {
              HelperUtils.showSnackBarMessage(
                context,
                "السلة فارغة، لا يوجد عناصر للحذف.",
              );
            } else {
              UiUtils.showBlurredDialoge(
                context,
                dialoge: BlurredDialogBox(
                  title: "تأكيد الحذف",
                  onAccept: _clearAll,
                  cancelTextColor: context.color.textColorDark,
                  svgImagePath: "assets/lottie/delete_user.json",
                  content: const Text("هل أنت متأكد من حذف جميع المنتجات؟"),
                ),
              );
            }
          },
          onToggleSelectAll: () => _toggleSelectAll(cartItems),
          onToggleSelectItem: (int? id) =>
              _toggleSelectItem(id, cartItems.length),
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
          deliveryPaymentOptions: cartState.deliveryPaymentOptions,
          deliveryPaymentTiming: cartState.deliveryPaymentTiming,
          onSelectDeliveryPaymentTiming: _updateDeliveryPaymentTiming,
        ),
      ),
    );
  }
}
