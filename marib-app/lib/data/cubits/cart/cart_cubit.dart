import 'dart:async';
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/data/repositories/cart/cart_repository.dart';
import 'package:marib/data/model/cart/cart_discount.dart';
import 'package:marib/data/model/cart/cart_safety_tip.dart';
import 'package:marib/data/repositories/cart/cart_tips_repository.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/app_telemetry.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:meta/meta.dart';







@immutable
class CartState {
  const CartState({
    this.items = const <Cart>[],
    this.discounts = const <CartDiscount>[],
    this.couponError,
    this.couponInProgress = false,
    this.throttleResetAt,
    this.lastUpdated,
    this.safetyTips,
    this.departmentPolicy,
    this.support,
    this.deliveryQuote,
    this.blocking,
    this.deliveryPaymentOptions,
    this.deliveryPaymentTiming,
    this.pendingAddition,
    this.checkoutLoading = false,
    this.departmentNotice,
    this.currency,
    this.currencyCode,
  });

  final List<Cart> items;
  final List<CartDiscount> discounts;
  final bool couponInProgress;
  final String? couponError;
  final DateTime? throttleResetAt;
  final DateTime? lastUpdated;
  final CartSafetyTipsPayload? safetyTips;
  final Map<String, dynamic>? departmentPolicy;
  final Map<String, dynamic>? support;
  final Map<String, dynamic>? deliveryQuote;
  final Map<String, dynamic>? blocking;
  final List<dynamic>? deliveryPaymentOptions;
  final String? deliveryPaymentTiming;
  final PendingCartAddition? pendingAddition;
  final bool checkoutLoading;
  final String? departmentNotice;
  final String? currency;
  final String? currencyCode;


  CartState copyWith({
    List<Cart>? items,
    List<CartDiscount>? discounts,
    bool? couponInProgress,
    String? couponError,
    bool clearCouponError = false,
    DateTime? throttleResetAt,
    bool clearThrottle = false,
    DateTime? lastUpdated,
    CartSafetyTipsPayload? safetyTips,
    bool clearSafetyTips = false,
    Object? pendingAddition = _sentinel,
    Object? departmentPolicy = _sentinel,
    Object? support = _sentinel,
    Object? deliveryQuote = _sentinel,
    Object? blocking = _sentinel,
    Object? deliveryPaymentOptions = _sentinel,
    Object? deliveryPaymentTiming = _sentinel,
    bool? checkoutLoading,
    Object? departmentNotice = _sentinel,
    Object? currency = _sentinel,
    Object? currencyCode = _sentinel,


  }) {
    return CartState(
      items: items ?? this.items,
      discounts: discounts ?? this.discounts,
      couponInProgress: couponInProgress ?? this.couponInProgress,
      couponError:
      clearCouponError ? null : (couponError ?? this.couponError),
      throttleResetAt:
      clearThrottle ? null : (throttleResetAt ?? this.throttleResetAt),
      lastUpdated: lastUpdated ?? this.lastUpdated,
      safetyTips:
      clearSafetyTips ? null : (safetyTips ?? this.safetyTips),
      pendingAddition: identical(pendingAddition, _sentinel)
          ? this.pendingAddition
          : pendingAddition as PendingCartAddition?,
      departmentPolicy: identical(departmentPolicy, _sentinel)
          ? this.departmentPolicy
          : departmentPolicy as Map<String, dynamic>?,
      support: identical(support, _sentinel)
          ? this.support
          : support as Map<String, dynamic>?,
      deliveryQuote: identical(deliveryQuote, _sentinel)
          ? this.deliveryQuote
          : deliveryQuote as Map<String, dynamic>?,
      blocking: identical(blocking, _sentinel)
          ? this.blocking
          : blocking as Map<String, dynamic>?,
      deliveryPaymentOptions:
      identical(deliveryPaymentOptions, _sentinel)
          ? this.deliveryPaymentOptions
          : deliveryPaymentOptions as List<dynamic>?,
      deliveryPaymentTiming:
      identical(deliveryPaymentTiming, _sentinel)
          ? this.deliveryPaymentTiming
          : deliveryPaymentTiming as String?,
      checkoutLoading: checkoutLoading ?? this.checkoutLoading,
      departmentNotice: identical(departmentNotice, _sentinel)
          ? this.departmentNotice
          : departmentNotice as String?,
      currency: identical(currency, _sentinel)
          ? this.currency
          : currency as String?,
      currencyCode: identical(currencyCode, _sentinel)
          ? this.currencyCode
          : currencyCode as String?,
    );
  }
  static const Object _sentinel = Object();

}



@immutable
class PendingCartAddition {
  const PendingCartAddition({
    required this.itemId,
    required this.quantity,
    this.department,
    this.selectedCustomFields,
    this.weight,
    this.vendorLat,
    this.vendorLng,
    this.variantId,
    this.variantKey,
    this.variantAttributes,
    this.stockSnapshot,
    this.unitPrice,
    this.unitPriceLocked,
    this.currency,
  });

  factory PendingCartAddition.fromCart({
    required Cart cart,
    required String? department,
  }) {
    return PendingCartAddition(
      itemId: cart.id!,
      quantity: cart.quantity,
      department: department,
      selectedCustomFields: _cloneListOfMaps(cart.selectedCustomFields),
      weight: cart.weight,
      vendorLat: cart.vendorLat,
      vendorLng: cart.vendorLng,
      variantId: cart.variantId,
      variantKey: cart.variantKey,
      variantAttributes:
      cart.variantAttributes != null ? Map<String, dynamic>.from(cart.variantAttributes!) : null,
      stockSnapshot:
      cart.stockSnapshot != null ? Map<String, dynamic>.from(cart.stockSnapshot!) : null,
      unitPrice: cart.unitPrice,
      unitPriceLocked: cart.unitPriceLocked,
      currency: cart.currency,
    );
  }

  final int itemId;
  final int quantity;
  final String? department;
  final List<Map<String, dynamic>>? selectedCustomFields;
  final double? weight;
  final double? vendorLat;
  final double? vendorLng;
  final String? variantId;
  final String? variantKey;
  final Map<String, dynamic>? variantAttributes;
  final Map<String, dynamic>? stockSnapshot;
  final double? unitPrice;
  final double? unitPriceLocked;
  final String? currency;

  static List<Map<String, dynamic>>? _cloneListOfMaps(
      List<Map<String, dynamic>>? source,
      ) {
    if (source == null) {
      return null;
    }
    return source
        .map((Map<String, dynamic> entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
}

class CartCubit extends Cubit<CartState> {
  CartCubit({CartRepository? repository, CartTipsRepository? tipsRepository})
      : _repository = repository ?? CartRepository(),
        _tipsRepository = tipsRepository ?? const CartTipsRepository(),

      super(const CartState()) {
    final String? storedSection = HiveUtils.getCartSection();
    _activeSection =
        normalizeDeliveryDepartment(storedSection) ?? storedSection;


  }

  String? _activeSection;
  String? get activeSection => _activeSection;


  final CartRepository _repository;
  final CartTipsRepository _tipsRepository;
  PendingCartAddition? _pendingAdditionCache;
  bool _checkoutRefreshInProgress = false;
  bool _checkoutRefreshPending = false;


  Future<void> fetchCart() async {
    final PendingCartAddition? existingPendingAddition =
        state.pendingAddition ?? _pendingAdditionCache;
    final bool preservePendingAddition = existingPendingAddition != null;

    if (!preservePendingAddition) {
      _pendingAdditionCache = null;
    }

    final CartSummary summary = await _repository.fetchCart();
    _syncSection(summary.items);

    emit(
      state.copyWith(
        items: summary.items,
        discounts: summary.discounts,
        clearCouponError: true,
        clearThrottle: true,
        lastUpdated: DateTime.now(),
        clearSafetyTips: !preservePendingAddition,
        pendingAddition:
        preservePendingAddition ? existingPendingAddition : null,
        departmentPolicy:
        summary.departmentPolicy ?? state.departmentPolicy,
        support: summary.support ?? state.support,
        deliveryQuote: summary.deliveryQuote ?? state.deliveryQuote,
        blocking: summary.blocking ?? state.blocking,
        deliveryPaymentOptions: summary.deliveryPaymentOptions ??
            state.deliveryPaymentOptions,
        deliveryPaymentTiming: summary.deliveryPaymentTiming ??
            state.deliveryPaymentTiming,
        checkoutLoading: true,
        currency: summary.currency ?? state.currency,
        currencyCode: summary.currencyCode ?? state.currencyCode,
      ),
    );

    if (preservePendingAddition) {
      _pendingAdditionCache = existingPendingAddition;
    }



    unawaited(refreshCheckoutDetails(force: true));
  }

  Future<void> refreshCheckoutDetails({bool force = false}) async {
    if (state.items.isEmpty) {
      _checkoutRefreshPending = false;
      emit(
        state.copyWith(
          checkoutLoading: false,
          departmentPolicy: null,
          support: null,
          deliveryQuote: null,
          blocking: null,
          deliveryPaymentOptions: null,
          deliveryPaymentTiming: null,
          departmentNotice: null,
        ),
      );
      return;
    }

    if (_checkoutRefreshInProgress) {
      if (force) {
        _checkoutRefreshPending = true;
      }
      return;
    }

    _checkoutRefreshInProgress = true;
    emit(state.copyWith(checkoutLoading: true));

    try {
      final CartCheckoutDetails details = await _repository.fetchCheckoutInfo();
      emit(
        state.copyWith(
          checkoutLoading: false,
          departmentPolicy:
          details.departmentPolicy ?? state.departmentPolicy,
          support: details.support ?? state.support,
          deliveryQuote: details.deliveryQuote ?? state.deliveryQuote,
          blocking: details.blocking ?? state.blocking,
          deliveryPaymentOptions: details.deliveryPaymentOptions ??
              state.deliveryPaymentOptions,
          deliveryPaymentTiming: details.deliveryPaymentTiming ??
              state.deliveryPaymentTiming,
          departmentNotice:
          details.departmentNotice ?? state.departmentNotice,
        ),
      );
    } catch (_) {
      emit(state.copyWith(checkoutLoading: false));
    } finally {
      _checkoutRefreshInProgress = false;
      if (_checkoutRefreshPending) {
        _checkoutRefreshPending = false;
        unawaited(refreshCheckoutDetails());
      }
    }

  }


  Future<void> updateDeliveryPaymentTiming(String timing) async {
    final String normalized = timing.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (state.deliveryPaymentTiming == normalized) {
      return;
    }

    final String? previousTiming = state.deliveryPaymentTiming;

    emit(
      state.copyWith(
        deliveryPaymentTiming: normalized,
      ),
    );

    try {
      final CartSummary summary = await _repository.setDeliveryPaymentTiming(
        timing: normalized,
      );
      _syncSection(summary.items);
      emit(
        state.copyWith(
          items: summary.items,
          discounts: summary.discounts,
          lastUpdated: DateTime.now(),
          departmentPolicy:
          summary.departmentPolicy ?? state.departmentPolicy,
          support: summary.support ?? state.support,
          deliveryQuote: summary.deliveryQuote ?? state.deliveryQuote,
          blocking: summary.blocking ?? state.blocking,
          deliveryPaymentOptions: summary.deliveryPaymentOptions ??
              state.deliveryPaymentOptions,
          deliveryPaymentTiming:
          summary.deliveryPaymentTiming ?? normalized,
          checkoutLoading: true,
          currency: summary.currency ?? state.currency,
          currencyCode: summary.currencyCode ?? state.currencyCode,
        ),
      );

      final bool requiresRefresh =
          summary.deliveryPaymentOptions == null ||
              summary.deliveryPaymentOptions!.isEmpty ||
              summary.deliveryPaymentTiming == null ||
              summary.deliveryPaymentTiming!.trim().isEmpty;
      if (requiresRefresh) {
        await refreshDeliveryPaymentTiming();
      }
      unawaited(refreshCheckoutDetails());

    } catch (_) {
      emit(
        state.copyWith(
          deliveryPaymentTiming: previousTiming,
        ),
      );
    }
  }

  Future<void> addItem(Cart cart) async {
    if (cart.id == null) {
      return;
    }
    _clearPendingAddition(clearSafetyTips: false);

    final String? normalizedCartSection =
        normalizeDeliveryDepartment(cart.section) ?? cart.section;
    final String? normalizedActiveSection =
        normalizeDeliveryDepartment(_activeSection) ?? _activeSection;

    String? departmentRaw;

    if (state.items.isNotEmpty && normalizedActiveSection != null) {
      departmentRaw = normalizedActiveSection;
    } else if (normalizedActiveSection != null &&
        normalizedCartSection != null &&
        normalizedActiveSection.toLowerCase().trim() ==
            normalizedCartSection.toLowerCase().trim()) {
      departmentRaw = normalizedActiveSection;
    } else {
      departmentRaw = normalizedCartSection ?? normalizedActiveSection;
    }
    final String? normalizedDepartment =
        normalizeDeliveryDepartment(departmentRaw) ?? departmentRaw;

    final String? department = normalizedDepartment;
    final String? canonicalDepartment =
        normalizeDeliveryDepartment(normalizedDepartment) ?? normalizedDepartment;
    final bool isSheinDepartment = canonicalDepartment != null &&
        canonicalDepartment.toLowerCase().trim() == 'shein';


    _setActiveSection(department);

    final PendingCartAddition request = PendingCartAddition.fromCart(
      cart: cart,
      department: department,
    );
    _pendingAdditionCache = request;
    CartSafetyTipsPayload? safetyTips;
    if (department != null && isSheinDepartment) {

      try {
        safetyTips = await _tipsRepository.fetchTips(
          department: department,
          itemId: cart.id!,
        );
      } catch (_) {
        // Ignore tip fetch errors; cart addition will proceed without tips.
      }
    }

    final bool requiresConfirmation =
        safetyTips != null && safetyTips.requiresConfirmation;

    if (requiresConfirmation) {

      emit(
        state.copyWith(
          safetyTips: safetyTips,
          clearSafetyTips: false,
          pendingAddition: request,

        ),
      );
      return;
    }

    await _commitCartAddition(
      request: request,

      safetyTipsOverride:
      (safetyTips != null && safetyTips.hasTips) ? safetyTips : null,
    );
  }

  Future<void> _commitCartAddition({
    required PendingCartAddition request,

    CartSafetyTipsPayload? safetyTipsOverride,
    bool skipTipFetch = false,
  }) async {

    final String? normalizedDepartment =
        normalizeDeliveryDepartment(request.department) ?? request.department;
    final bool requestIsShein = normalizedDepartment != null &&
        normalizedDepartment.toLowerCase().trim() == 'shein';

    try {
      final CartSummary summary = await _repository.addItem(
        itemId: request.itemId,
        quantity: request.quantity,
        selectedCustomFields: request.selectedCustomFields,
        weight: request.weight,
        vendorLat: request.vendorLat,
        vendorLng: request.vendorLng,
        department: request.department,
        variantId: request.variantId,
        variantKey: request.variantKey,
        attributes: request.variantAttributes,
        stockSnapshot: request.stockSnapshot,
        unitPrice: request.unitPrice,
        unitPriceLocked: request.unitPriceLocked,
        currency: request.currency,
      );









      CartSafetyTipsPayload? resolvedTips =
      (safetyTipsOverride != null &&
          safetyTipsOverride.hasDisplayableContent)
          ? safetyTipsOverride
          : null;

      if (!skipTipFetch && resolvedTips == null && requestIsShein) {
        final String? summaryDepartment =
            _extractCanonicalDepartment(summary.raw) ?? normalizedDepartment;
        final String? fetchDepartment =
            normalizeDeliveryDepartment(summaryDepartment) ?? summaryDepartment;
        final int? addedItemId =
            _extractAddedItemId(summary.raw) ?? request.itemId;

        if (fetchDepartment != null && addedItemId != null) {
          try {
            final CartSafetyTipsPayload? fetched =
            await _tipsRepository.fetchTips(
              department: fetchDepartment,
              itemId: addedItemId,
            );
            if (fetched != null && fetched.hasDisplayableContent) {
              resolvedTips = fetched;
            }
          } catch (_) {
            // Ignore tip fetch errors; cart addition succeeded.


          }

        }
      }
      _syncSection(summary.items);
      emit(
        state.copyWith(
          items: summary.items,
          discounts: summary.discounts,
          lastUpdated: DateTime.now(),
          safetyTips: skipTipFetch ? null : resolvedTips,
          clearSafetyTips: skipTipFetch || resolvedTips == null,
          pendingAddition: null,
          departmentPolicy:
          summary.departmentPolicy ?? state.departmentPolicy,
          support: summary.support ?? state.support,
          deliveryQuote: summary.deliveryQuote ?? state.deliveryQuote,
          blocking: summary.blocking ?? state.blocking,
          deliveryPaymentOptions: summary.deliveryPaymentOptions ??
              state.deliveryPaymentOptions,
          deliveryPaymentTiming: summary.deliveryPaymentTiming ??
              state.deliveryPaymentTiming,
          checkoutLoading: true,
          currency: summary.currency ?? state.currency,
          currencyCode: summary.currencyCode ?? state.currencyCode,
        ),
      );
      _pendingAdditionCache = null;

      _recordTelemetry('cart_add.success', <String, dynamic>{
        'department': normalizedDepartment,
        'skip_tip_fetch': skipTipFetch,
        'has_tips': resolvedTips?.hasDisplayableContent ?? false,
      });

      final bool shouldRefreshPaymentTiming =
          summary.deliveryPaymentOptions == null ||
              summary.deliveryPaymentOptions!.isEmpty ||
              summary.deliveryPaymentTiming == null ||
              summary.deliveryPaymentTiming!.trim().isEmpty;

      if (shouldRefreshPaymentTiming) {
        await refreshDeliveryPaymentTiming();
      }
      unawaited(refreshCheckoutDetails());

    } catch (error, _) {
      _recordTelemetry('cart_add.failed', <String, dynamic>{
        'department': normalizedDepartment,
        'skip_tip_fetch': skipTipFetch,
        'error': error.toString(),
      });
      rethrow;
    }
  }


  Future<void> refreshDeliveryPaymentTiming() async {
    try {
      final CartSummary summary = await _repository.fetchDeliveryPaymentTiming();
      if (summary.items.isNotEmpty) {
        _syncSection(summary.items);
      }

      final List<Cart> resolvedItems =
      summary.items.isNotEmpty ? summary.items : state.items;
      final List<CartDiscount> resolvedDiscounts =
      summary.discounts.isNotEmpty ? summary.discounts : state.discounts;

      emit(
        state.copyWith(
          items: resolvedItems,
          discounts: resolvedDiscounts,
          lastUpdated: DateTime.now(),
          departmentPolicy: summary.departmentPolicy ?? state.departmentPolicy,
          support: summary.support ?? state.support,
          deliveryQuote: summary.deliveryQuote ?? state.deliveryQuote,
          blocking: summary.blocking ?? state.blocking,
          deliveryPaymentOptions:
          summary.deliveryPaymentOptions ?? state.deliveryPaymentOptions,
          deliveryPaymentTiming:
          summary.deliveryPaymentTiming ?? state.deliveryPaymentTiming,
          currency: summary.currency ?? state.currency,
          currencyCode: summary.currencyCode ?? state.currencyCode,
          checkoutLoading: true,
        ),
      );
      unawaited(refreshCheckoutDetails());
    } catch (_) {
      // Ignore delivery payment timing fetch failures.
    }
  }


  Future<void> confirmPendingCartAddition() async {
    final PendingCartAddition? pending =
        state.pendingAddition ?? _pendingAdditionCache;
    if (pending == null) {
      if (state.safetyTips != null) {
        _clearPendingAddition(clearSafetyTips: true);
      }
      await fetchCart();
      return;
    }

    try {
      await _commitCartAddition(
        request: pending,
        safetyTipsOverride: state.safetyTips,
        skipTipFetch: true,
      );
    } finally {
      final PendingCartAddition? existingPendingAddition =
          state.pendingAddition ?? _pendingAdditionCache;
      final bool preservePendingAddition = existingPendingAddition != null;

      if (!preservePendingAddition) {
        _pendingAdditionCache = null;
      }

      _clearPendingAddition(clearSafetyTips: true);
    }
  }

  Future<void> cancelPendingCartAddition() async {
    _clearPendingAddition(clearSafetyTips: true);
    await fetchCart();

  }

  void _clearPendingAddition({bool clearSafetyTips = false}) {
    final bool shouldEmit = state.pendingAddition != null ||
        (clearSafetyTips && state.safetyTips != null);
    _pendingAdditionCache = null;
    if (!shouldEmit) {
      return;
    }
    emit(
      state.copyWith(
        pendingAddition: null,
        clearSafetyTips: clearSafetyTips,
      ),
    );
  }



  Future<void> updateItemQuantity(int id, int quantity) async {
    final Cart? item = _findItem(itemId: id);
    if (item == null) return;

    await _updateItemQuantity(item, quantity);
  }

  Future<void> _updateItemQuantity(Cart item, int quantity) async {
    final CartSummary summary = await _repository.updateQuantity(
      itemId: item.id!,
      quantity: quantity,
      cartItemId: item.cartItemId,
      variantId: item.variantId,
      variantKey: item.variantKey,
      attributes: item.variantAttributes,
      stockSnapshot: item.stockSnapshot,
      unitPrice: item.unitPrice,
      unitPriceLocked: item.unitPriceLocked,
      currency: item.currency,
    );

    _syncSection(summary.items);

    emit(
      state.copyWith(
        items: summary.items,
        discounts: summary.discounts,
        lastUpdated: DateTime.now(),
        clearSafetyTips: true,
        departmentPolicy:
        summary.departmentPolicy ?? state.departmentPolicy,
        support: summary.support ?? state.support,
        deliveryQuote: summary.deliveryQuote ?? state.deliveryQuote,
        blocking: summary.blocking ?? state.blocking,
        deliveryPaymentOptions: summary.deliveryPaymentOptions ??
            state.deliveryPaymentOptions,
        deliveryPaymentTiming:
        summary.deliveryPaymentTiming ?? state.deliveryPaymentTiming,
        checkoutLoading: true,
        currency: summary.currency ?? state.currency,
        currencyCode: summary.currencyCode ?? state.currencyCode,
      ),
    );
    unawaited(refreshCheckoutDetails());

  }

  Future<void> increaseQuantity({int? cartItemId, required int itemId}) async {
    final Cart? item = _findItem(
      cartItemId: cartItemId,
      itemId: itemId,
    );

    if (item == null) return;


    await _updateItemQuantity(item, item.quantity + 1);
  }

  Future<void> decreaseQuantity({int? cartItemId, required int itemId}) async {
    final Cart? item = _findItem(
      cartItemId: cartItemId,
      itemId: itemId,
    );
    if (item == null || item.quantity <= 1) return;

    await _updateItemQuantity(item, item.quantity - 1);
  }



  Future<void> removeItem({int? cartItemId, required int itemId}) async {
    final Cart? item = _findItem(
      cartItemId: cartItemId,
      itemId: itemId,
    );
    if (item == null) return;

    final CartSummary summary = await _repository.removeItem(
      itemId: item.id!,
      cartItemId: item.cartItemId,
      variantKey: item.variantKey,
    );

    _syncSection(summary.items);

    emit(
      state.copyWith(
        items: summary.items,
        discounts: summary.discounts,
        lastUpdated: DateTime.now(),
        departmentPolicy:
        summary.departmentPolicy ?? state.departmentPolicy,
        support: summary.support ?? state.support,
        deliveryQuote: summary.deliveryQuote ?? state.deliveryQuote,
        blocking: summary.blocking ?? state.blocking,
        deliveryPaymentOptions: summary.deliveryPaymentOptions ??
            state.deliveryPaymentOptions,
        deliveryPaymentTiming:
        summary.deliveryPaymentTiming ?? state.deliveryPaymentTiming,
        checkoutLoading: true,
        currency: summary.currency ?? state.currency,
        currencyCode: summary.currencyCode ?? state.currencyCode,
      ),
    );
    unawaited(refreshCheckoutDetails());
  }

  Future<void> clearCart() async {
    final CartSummary summary = await _repository.clearCart();
    _syncSection(summary.items);

    emit(
      state.copyWith(
        items: summary.items,
        discounts: summary.discounts,
        lastUpdated: DateTime.now(),
        departmentPolicy:
        summary.departmentPolicy ?? state.departmentPolicy,
        support: summary.support ?? state.support,
        deliveryQuote: summary.deliveryQuote ?? state.deliveryQuote,
        blocking: summary.blocking ?? state.blocking,
        deliveryPaymentOptions: summary.deliveryPaymentOptions ??
            state.deliveryPaymentOptions,
        deliveryPaymentTiming:
        summary.deliveryPaymentTiming ?? state.deliveryPaymentTiming,
        checkoutLoading: true,
        currency: summary.currency ?? state.currency,
        currencyCode: summary.currencyCode ?? state.currencyCode,
      ),
    );
    unawaited(refreshCheckoutDetails());
  }

  Future<void> applyCoupon(String rawCode) async {
    final String trimmed = rawCode.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          couponError: 'يرجى إدخال رمز القسيمة.',
          couponInProgress: false,
          throttleResetAt: state.throttleResetAt,
        ),
      );
      return;
    }

    if (state.couponInProgress) return;

    emit(
      state.copyWith(
        couponInProgress: true,
        clearCouponError: true,
      ),
    );

    try {
      final CartSummary summary = await _repository.applyCoupon(
        code: trimmed,
      );
      _syncSection(summary.items);
      emit(
        state.copyWith(
          items: summary.items,
          discounts: summary.discounts,
          couponInProgress: false,
          clearCouponError: true,
          clearThrottle: true,
          lastUpdated: DateTime.now(),
          departmentPolicy:
          summary.departmentPolicy ?? state.departmentPolicy,
          support: summary.support ?? state.support,
          deliveryQuote: summary.deliveryQuote ?? state.deliveryQuote,
          blocking: summary.blocking ?? state.blocking,
          deliveryPaymentOptions: summary.deliveryPaymentOptions ??
              state.deliveryPaymentOptions,
          deliveryPaymentTiming:
          summary.deliveryPaymentTiming ?? state.deliveryPaymentTiming,
          checkoutLoading: true,
          currency: summary.currency ?? state.currency,
          currencyCode: summary.currencyCode ?? state.currencyCode,
        ),
      );
      unawaited(refreshCheckoutDetails());
    } on ApiHttpException catch (error) {
      if (error.statusCode == 429) {
        emit(
          state.copyWith(
            couponInProgress: false,
            couponError:
            'تم تجاوز الحد المسموح لمحاولات القسائم. يرجى الانتظار دقيقة قبل المحاولة مجددًا.',
            throttleResetAt: DateTime.now().add(const Duration(minutes: 1)),
          ),
        );
      } else {
        emit(
          state.copyWith(
            couponInProgress: false,
            couponError: error.toString(),
          ),
        );
      }
    } catch (error) {
      emit(
        state.copyWith(
          couponInProgress: false,
          couponError: error.toString(),
        ),
      );
    }
  }




  void clearSafetyTips() {
    _clearPendingAddition(clearSafetyTips: true);
  }


  void _recordTelemetry(String event, [Map<String, dynamic>? context]) {
    AppTelemetry.record(event, context ?? const <String, dynamic>{});
  }



  Future<void> removeCoupon(String rawCode) async {
    final String trimmed = rawCode.trim();
    if (trimmed.isEmpty) return;
    if (state.couponInProgress) return;

    emit(
      state.copyWith(
        couponInProgress: true,
        clearCouponError: true,
      ),
    );

    try {
      final CartSummary summary = await _repository.removeCoupon(
        code: trimmed,
      );
      _syncSection(summary.items);
      emit(
        state.copyWith(
          items: summary.items,
          discounts: summary.discounts,
          couponInProgress: false,
          clearCouponError: true,
          clearThrottle: true,
          lastUpdated: DateTime.now(),
          departmentPolicy:
          summary.departmentPolicy ?? state.departmentPolicy,
          support: summary.support ?? state.support,
          deliveryQuote: summary.deliveryQuote ?? state.deliveryQuote,
          blocking: summary.blocking ?? state.blocking,
          deliveryPaymentOptions: summary.deliveryPaymentOptions ??
              state.deliveryPaymentOptions,
          deliveryPaymentTiming:
          summary.deliveryPaymentTiming ?? state.deliveryPaymentTiming,
          checkoutLoading: true,
          currency: summary.currency ?? state.currency,
          currencyCode: summary.currencyCode ?? state.currencyCode,
        ),
      );
      unawaited(refreshCheckoutDetails());
    } on ApiHttpException catch (error) {
      if (error.statusCode == 429) {
        emit(
          state.copyWith(
            couponInProgress: false,
            couponError:
            'تم تجاوز الحد المسموح لمحاولات القسائم. يرجى الانتظار دقيقة قبل المحاولة مجددًا.',
            throttleResetAt: DateTime.now().add(const Duration(minutes: 1)),
          ),
        );
      } else {
        emit(
          state.copyWith(
            couponInProgress: false,
            couponError: error.toString(),
          ),
        );
      }
    } catch (error) {
      emit(
        state.copyWith(
          couponInProgress: false,
          couponError: error.toString(),
        ),
      );
    }
  }

  void clearCouponFeedback() {
    if (state.couponError != null || state.throttleResetAt != null) {
      emit(
        state.copyWith(
          clearCouponError: true,
          clearThrottle: true,
        ),
      );
    }
  }

  void replaceWithSummary(CartSummary summary) {
    _syncSection(summary.items);
    emit(
      state.copyWith(
        items: summary.items,
        discounts: summary.discounts,
        lastUpdated: DateTime.now(),
        departmentPolicy:
        summary.departmentPolicy ?? state.departmentPolicy,
        support: summary.support ?? state.support,
        deliveryQuote: summary.deliveryQuote ?? state.deliveryQuote,
        blocking: summary.blocking ?? state.blocking,
        deliveryPaymentOptions: summary.deliveryPaymentOptions ??
            state.deliveryPaymentOptions,
        deliveryPaymentTiming:
        summary.deliveryPaymentTiming ?? state.deliveryPaymentTiming,
        checkoutLoading: true,
        currency: summary.currency ?? state.currency,
        currencyCode: summary.currencyCode ?? state.currencyCode,
      ),
    );
    unawaited(refreshCheckoutDetails());
  }

  int get totalItems =>
      state.items.fold(0, (int total, Cart item) => total + item.quantity);



  int getQuantityForCartItem({int? cartItemId, required int itemId}) {
    final Cart? item = _findItem(
      cartItemId: cartItemId,
      itemId: itemId,
    );

    return item?.quantity ?? 0;
  }

  int getQuantityForProduct(int id) => getQuantityForCartItem(itemId: id);



  double get subtotal =>
      state.items.fold(0, (double sum, Cart item) => sum + item.subtotalAmount);

  Cart? _findItem({int? cartItemId, required int itemId}) {
    if (cartItemId != null) {
      for (final Cart item in state.items) {
        if (item.cartItemId == cartItemId) {
          return item;
        }
      }
      return null;
    }


    for (final Cart item in state.items) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }


  void _syncSection(List<Cart> items) {
    final String? newSection = items.isNotEmpty ? items.first.section : null;
    _setActiveSection(newSection);
  }

  void _setActiveSection(String? section) {
    final String? normalized =
        normalizeDeliveryDepartment(section) ?? section?.trim();

    if (_activeSection == normalized) {

      return;
    }

    _activeSection = normalized;
    unawaited(HiveUtils.setCartSection(normalized));
  }




  String? _extractCanonicalDepartment(Map<String, dynamic>? raw) {
    for (final Map<String, dynamic> candidate in _mapCandidates(raw)) {
      final String? direct = _readDepartmentSlug(candidate);

      if (direct != null && direct.isNotEmpty) {
        return direct;
      }

      final Map<String, dynamic>? itemMap = _castToStringKeyedMap(
        candidate['item'] ?? candidate['added_item'],
      );
      final String? nested = _readDepartmentSlug(itemMap);

      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }
    return null;
  }

  int? _extractAddedItemId(Map<String, dynamic>? raw) {
    for (final Map<String, dynamic> candidate in _mapCandidates(raw)) {
      final int? id = _readInt(
        candidate,
        const <String>['item_id', 'id', 'cart_item_id'],
      );
      if (id != null && id > 0) {
        return id;
      }

      final Map<String, dynamic>? itemMap = _castToStringKeyedMap(
        candidate['item'] ?? candidate['added_item'] ?? candidate['cart_item'],
      );
      final int? nestedId = _readInt(
        itemMap,
        const <String>['item_id', 'id'],
      );
      if (nestedId != null && nestedId > 0) {
        return nestedId;
      }
    }
    return null;
  }

  Iterable<Map<String, dynamic>> _mapCandidates(Map<String, dynamic>? raw) sync* {
    final List<dynamic> queue = <dynamic>[];
    if (raw != null) {
      queue.add(raw);
    }

    final List<Map<String, dynamic>> visited = <Map<String, dynamic>>[];

    void enqueue(dynamic value) {
      if (value == null) return;
      if (value is Iterable) {
        for (final dynamic entry in value) {
          queue.add(entry);
        }
      } else {
        queue.add(value);
      }
    }

    while (queue.isNotEmpty) {
      final dynamic current = queue.removeAt(0);
      final Map<String, dynamic>? map = _castToStringKeyedMap(current);
      if (map == null) {
        continue;
      }
      if (visited.any((Map<String, dynamic> entry) => identical(entry, map))) {
        continue;
      }
      visited.add(map);
      yield map;

      enqueue(map['data']);
      enqueue(map['payload']);
      enqueue(map['result']);
      enqueue(map['cart']);
      enqueue(map['meta']);
      enqueue(map['item']);
      enqueue(map['added_item']);
      enqueue(map['cart_item']);
    }
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




  String? _readDepartmentSlug(Map<String, dynamic>? map) {
    final String? value = _extractDepartmentValue(map);
    if (value == null) {
      return null;
    }
    return _sanitizeDepartmentSlug(value);
  }

  String? _extractDepartmentValue(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }
    for (final String key in const <String>[
      'canonical_department',
      'department',
      'section',
    ]) {
      if (!map.containsKey(key)) {
        continue;
      }
      final String? resolved =
      _resolveDepartmentValue(map[key], <Map<String, dynamic>>{map});
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }
    return null;
  }

  String? _resolveDepartmentValue(dynamic value,
      [Set<Map<String, dynamic>>? visited]) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is Iterable) {
      for (final dynamic entry in value) {
        final String? resolved = _resolveDepartmentValue(entry, visited);
        if (resolved != null && resolved.isNotEmpty) {
          return resolved;
        }
      }
      return null;
    }

    final Map<String, dynamic>? map = _castToStringKeyedMap(value);
    if (map != null) {
      visited ??= <Map<String, dynamic>>{};
      if (visited.contains(map)) {
        return null;
      }
      visited.add(map);
      for (final String key in const <String>[
        'canonical_department',
        'department',
        'section',
        'key',
        'slug',
        'code',
      ]) {
        if (!map.containsKey(key)) {
          continue;
        }
        final dynamic nested = map[key];
        if (identical(nested, map)) {
          continue;
        }
        final String? resolved = _resolveDepartmentValue(nested, visited);
        if (resolved != null && resolved.isNotEmpty) {
          return resolved;
        }
      }
      return null;
    }

    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _sanitizeDepartmentSlug(String? value) {
    if (value == null) {
      return null;
    }
    final String? normalized = normalizeDeliveryDepartment(value);
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }





  String? _readString(Map<String, dynamic>? map, Iterable<String> keys) {
    if (map == null) return null;
    for (final String key in keys) {
      if (!map.containsKey(key)) continue;
      final dynamic value = map[key];
      if (value == null) {
        continue;
      }
      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      } else if (value is Enum) {
        return value.name;
      } else {
        final String text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  int? _readInt(Map<String, dynamic>? map, Iterable<String> keys) {
    if (map == null) return null;
    for (final String key in keys) {
      if (!map.containsKey(key)) continue;
      final dynamic value = map[key];
      final int? parsed = _coerceInt(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  int? _coerceInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }





}
