import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:marib/config/feature_flags.dart';
import 'package:marib/data/model/cart/checkout_models.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/data/model/orders/order_submission_result.dart';
import 'package:marib/data/services/cart_shipping_quote_service.dart';
import 'package:marib/data/repositories/cart/addresses_repository.dart';

import 'package:marib/data/repositories/cart/cart_repository.dart';
import 'package:marib/data/services/delivery_pricing_service.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';

import 'package:marib/utils/api.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/data/repositories/wallet_repository.dart';
import 'package:marib/data/model/cart/cart_discount.dart';
import 'package:marib/data/model/orders/user_order.dart';
import 'package:marib/data/repositories/orders/orders_repository.dart';

/// Repository responsible for collecting all checkout metadata required by the
/// delivery & payment flow. It orchestrates calls to:
///
/// * `GET /api/get-payment-settings`
/// * `GET /api/delivery-prices?department=...`
/// * Cart fetching via [CartRepository]
///
/// The goal is to keep the UI in sync with the server so changes to delivery
/// pricing or payment accounts appear immediately.

typedef _ApiPostHandler = Future<Map<String, dynamic>> Function({
  required String url,
  dynamic parameter,
  Options? options,
  bool? useBaseUrl,
  Map<String, dynamic>? extraHeaders,
});

class CheckoutRepository {
  CheckoutRepository({
    CartRepository? cartRepository,
    DeliveryPricingService? deliveryPricingService,
    WalletRepository? walletRepository,
    CartShippingQuoteService? shippingQuoteService,
    _ApiPostHandler? apiPostHandler,
    AddressesRepository? addressesRepository,
  })  : _shippingQuoteService =
            shippingQuoteService ?? CartShippingQuoteService.shared,
        _cartRepository = cartRepository ??
            CartRepository(
              shippingQuoteService:
                  shippingQuoteService ?? CartShippingQuoteService.shared,
            ),
        _deliveryPricingService =
            deliveryPricingService ?? DeliveryPricingService(),
        _walletRepository = walletRepository ?? WalletRepository(),
        _apiPostHandler = apiPostHandler ?? Api.post {
    _addressesRepository = addressesRepository ??
        AddressesRepository(
          shippingQuoteService: _shippingQuoteService,
          checkoutRepository: this,
        );
  }

  final DeliveryPricingService _deliveryPricingService;
  final WalletRepository _walletRepository;
  final CartShippingQuoteService _shippingQuoteService;
  final _ApiPostHandler _apiPostHandler;

  final CartRepository _cartRepository;
  late final AddressesRepository _addressesRepository;

  String? _lastKnownDepartment;
  int? _lastKnownAddressId;
  bool _forceRefreshNextShippingQuote = false;

  Future<CheckoutResult> fetchCheckout({
    String? department,
    int? addressId,
    Future<CheckoutAddress?>? preloadedAddress,
    bool depositEnabled = false,
    String? deliveryPaymentTiming,
    Map<String, dynamic>? shippingPaymentOverride,
  }) async {
    final String? departmentCode = normalizeDeliveryDepartment(department);
    final String? trackedDepartment = departmentCode ?? department;

    _handleShippingDestinationChange(
      department: trackedDepartment,
      addressId: addressId,
    );

    final Future<CartSummary> cartFuture = _cartRepository.fetchCart();
    final paymentFuture = Api.get(url: Api.getPaymentSettingsApi);
    final bool shouldRequestQuote =
        FeatureFlags.deliveryPricingEnabled && addressId != null;

    final Future<CheckoutAddress?> fallbackAddressFuture = addressId != null
        ? (preloadedAddress ?? _fetchAddressFromRepository(addressId))
        : (preloadedAddress ?? Future<CheckoutAddress?>.value(null));

    final Map<String, dynamic>? quoteExtras = _buildShippingQuoteExtras(
      deliveryPaymentTiming: deliveryPaymentTiming,
      paymentOverride: shippingPaymentOverride,
    );

    final Future<CheckoutShippingQuote?> quoteFuture = shouldRequestQuote
        ? _fetchShippingQuote(
            department: department,
            addressId: addressId,
            forceRefresh: _consumeForceRefreshFlag(),
            depositEnabled: depositEnabled,
            extra: quoteExtras,
          )
        : Future.value(null);

    final walletFuture = _fetchWalletSummary();

    final CartSummary cartSummary = await cartFuture;
    final List<Cart> cartItems = cartSummary.items;
    final List<CartDiscount> discounts = cartSummary.discounts;

    final Map<String, dynamic> paymentSettings = await paymentFuture;
    final CheckoutShippingQuote? shippingQuote = await quoteFuture;
    final WalletSummary? walletSummary = await walletFuture;
    final CheckoutAddress? fallbackAddress = await fallbackAddressFuture;

    final Map<String, dynamic>? paymentData =
        _extractMap(paymentSettings, candidates: const [
      'data',
      'payment_settings',
      'settings',
      'result',
    ]);

    final CheckoutDeliveryInfo? deliveryInfo =
        FeatureFlags.deliveryPricingEnabled
            ? _parseDeliveryInfoFromQuote(
                shippingQuote,
                fallbackDepartment: departmentCode ?? department,
              )
            : null;

    final CheckoutAddress? address = _parseCheckoutAddress(
          shippingQuote?.address ??
              shippingQuote?.delivery ??
              shippingQuote?.deliveryQuote ??
              shippingQuote?.data ??
              paymentData ??
              fallbackAddress?.raw,
        ) ??
        fallbackAddress;

    final List<CheckoutBank> banks =
        _parseBanks(paymentData ?? paymentSettings);

    return CheckoutResult(
      cartItems: cartItems,
      discounts: discounts,
      banks: banks,
      deliveryInfo: deliveryInfo,
      userAddress: address,
      paymentSettings: paymentData,
      shippingQuote: shippingQuote,
      walletSummary: walletSummary,
      isWalletAvailable: walletSummary != null,
    );
  }

  Future<WalletSummary?> _fetchWalletSummary() async {
    try {
      return await _walletRepository.fetchSummary();
    } catch (_) {
      return null;
    }
  }

  Future<CheckoutAddress?> fetchAddressForCheckout(int addressId) {
    return _fetchAddressFromRepository(addressId);
  }

  Future<CheckoutDeliveryInfo?> refreshDeliveryInfo({
    String? department,
    int? addressId,
    bool depositEnabled = false,
    String? deliveryPaymentTiming,
    Map<String, dynamic>? shippingPaymentOverride,
  }) async {
    if (!FeatureFlags.deliveryPricingEnabled) {
      return null;
    }

    final String? departmentCode = normalizeDeliveryDepartment(department);
    final Map<String, dynamic>? quoteExtras = _buildShippingQuoteExtras(
      deliveryPaymentTiming: deliveryPaymentTiming,
      paymentOverride: shippingPaymentOverride,
    );

    final CheckoutShippingQuote? quote = await _fetchShippingQuote(
      department: departmentCode,
      addressId: addressId,
      forceRefresh: true,
      depositEnabled: depositEnabled,
      extra: quoteExtras,
    );
    return _parseDeliveryInfoFromQuote(
      quote,
      fallbackDepartment: departmentCode ?? department,
    );
  }

  Future<DeliveryPricingResult> calculateDeliveryPrice({
    double? distanceKm,
    double? distance,
    double? weightKg,
    double? weight,
    DeliveryPackageSize? packageSize,
    String? mode,
    String? department,
    num? orderTotal,
    Map<String, dynamic>? extra,
  }) {
    return _deliveryPricingService.calculate(
      distanceKm: distanceKm,
      distance: distance,
      weightKg: weightKg,
      weight: weight,
      packageSize: packageSize,
      mode: mode,
      department: normalizeDeliveryDepartment(department),
      orderTotal: orderTotal,
      extra: extra,
    );
  }

  Future<OrderSubmissionResult> submitOrder({
    required List<Cart> cartItems,
    required Map<String, dynamic>? address,
    int? addressId,
    CheckoutDeliveryInfo? deliveryInfo,
    CheckoutBank? paymentBank,
    String? paymentMethodName,
    String? deliveryPriceDisplay,
    String? department,
    num? subtotal,
    required String deliveryPaymentTiming,
    String? deliveryPaymentNote,
    bool depositEnabled = false,
  }) async {
    final List<Map<String, dynamic>> items = cartItems.map((Cart item) {
      return <String, dynamic>{
        'item_id': item.id,
        'quantity': item.quantity,
        if (item.selectedCustomFields != null &&
            item.selectedCustomFields!.isNotEmpty)
          'selected_custom_fields': item.selectedCustomFields,
        if (item.weight != null) 'weight': item.weight,
        if (item.vendorLat != null) 'vendor_lat': item.vendorLat,
        if (item.vendorLng != null) 'vendor_lng': item.vendorLng,
        if (item.section.isNotEmpty) 'section': item.section,
        if (item.variantId != null) 'variant_id': item.variantId,
        if (item.variantAttributes != null &&
            item.variantAttributes!.isNotEmpty)
          'variant_attributes': item.variantAttributes,
        if (item.stockSnapshot != null && item.stockSnapshot!.isNotEmpty)
          'stock_snapshot': item.stockSnapshot,
        if (item.unitPrice != null) 'unit_price': item.unitPrice,
        if (item.unitPriceLocked != null)
          'unit_price_locked': item.unitPriceLocked,
        if (item.currency != null && item.currency!.trim().isNotEmpty)
          'currency': item.currency!.trim(),
      };
    }).toList();

    final String? departmentCode = normalizeDeliveryDepartment(department);

    final String? trimmedPaymentMethod = paymentMethodName?.trim();
    final String? apiPaymentMethod =
        trimmedPaymentMethod != null && trimmedPaymentMethod.isNotEmpty
            ? ManualPaymentService.paymentMethodForApi(trimmedPaymentMethod)
            : null;

    final Map<String, dynamic> payload = <String, dynamic>{
      'items': jsonEncode(items),
      if (departmentCode != null) 'department': departmentCode,
      if (addressId != null) 'address_id': addressId,
      'delivery_payment_timing': deliveryPaymentTiming,
      if (deliveryPaymentNote != null && deliveryPaymentNote.trim().isNotEmpty)
        'delivery_user_note': deliveryPaymentNote.trim(),
      'deposit_enabled': depositEnabled ? 1 : 0,
      if (apiPaymentMethod != null) 'payment_method': apiPaymentMethod,
      if (subtotal != null) 'subtotal': subtotal,
    };

    if (address != null && address.isNotEmpty) {
      payload['shipping_address'] = jsonEncode(address);
    }

    final String? deliveryDepartmentCode =
        normalizeDeliveryDepartment(deliveryInfo?.department);

    final Map<String, dynamic> delivery = <String, dynamic>{
      if (deliveryDepartmentCode != null) 'department': deliveryDepartmentCode,
      if (deliveryInfo?.distanceKm != null)
        'distance_km': deliveryInfo!.distanceKm,
      if (deliveryInfo?.fee != null) 'fee': deliveryInfo!.fee,
      if (deliveryInfo?.feeDisplay != null &&
          deliveryInfo!.feeDisplay!.trim().isNotEmpty)
        'fee_display': deliveryInfo.feeDisplay!.trim(),
      if (deliveryPriceDisplay != null &&
          deliveryPriceDisplay.trim().isNotEmpty)
        'selected_fee_display': deliveryPriceDisplay.trim(),
      if (deliveryInfo?.currency != null &&
          deliveryInfo!.currency!.trim().isNotEmpty)
        'currency': deliveryInfo.currency!.trim(),
      if (deliveryInfo?.userCoordinates?.lat != null)
        'user_lat': deliveryInfo!.userCoordinates!.lat,
      if (deliveryInfo?.userCoordinates?.lng != null)
        'user_lng': deliveryInfo!.userCoordinates!.lng,
      if (deliveryInfo?.vendorCoordinates?.lat != null)
        'vendor_lat': deliveryInfo!.vendorCoordinates!.lat,
      if (deliveryInfo?.vendorCoordinates?.lng != null)
        'vendor_lng': deliveryInfo!.vendorCoordinates!.lng,
    };

    if (delivery.isNotEmpty) {
      payload['delivery'] = jsonEncode(delivery);
    }

    final Map<String, dynamic> payment = <String, dynamic>{
      if (apiPaymentMethod != null) 'method': apiPaymentMethod,
      if (paymentBank?.id != null) 'bank_id': paymentBank!.id,
      if (paymentBank?.name.isNotEmpty == true) 'bank_name': paymentBank!.name,
      if (paymentBank?.accountNumber?.isNotEmpty == true)
        'account_number': paymentBank!.accountNumber,
    };

    if (payment.isNotEmpty) {
      payload['payment'] = jsonEncode(payment);
    }

    final Map<String, dynamic> response = await _apiPostHandler(
      url: Api.createOrderApi,
      parameter: payload,
      useBaseUrl: true,
      extraHeaders: <String, dynamic>{
        'Idempotency-Key': Api.generateIdempotencyKey(),
      },
    );

    final Map<String, dynamic> normalized = Map<String, dynamic>.from(response);
    OrderDetails? details;
    try {
      details = OrdersRepository.parseOrderDetailsResponse(
        Map<String, dynamic>.from(normalized),
      );
    } catch (_) {
      details = null;
    }

    final Map<String, dynamic>? orderPayload = details?.order.raw ??
        _extractMap(normalized, candidates: const <String>[
          'order',
          'data',
          'result',
        ]);

    final Map<String, dynamic> orderSource = orderPayload ?? normalized;

    String? orderId = details?.order.id;
    if (orderId == null || orderId.trim().isEmpty) {
      orderId = _asString(_firstValue(orderSource, const <List<String>>[
        <String>['id'],
        <String>['order_id'],
        <String>['data', 'id'],
      ]));
    }

    String? orderCode = details?.order.code;
    if (orderCode == null || orderCode.trim().isEmpty) {
      orderCode = _asString(_firstValue(orderSource, const <List<String>>[
        <String>['code'],
        <String>['reference'],
        <String>['order_code'],
      ]));
    }

    return OrderSubmissionResult(
      orderId: orderId,
      orderCode: orderCode,
      order: orderPayload,
      details: details,
      raw: normalized,
    );
  }

  Future<CheckoutShippingQuote?> _fetchShippingQuote({
    String? department,
    int? addressId,
    bool depositEnabled = false,
    bool forceRefresh = false,
    Map<String, dynamic>? extra,
  }) async {
    if (!FeatureFlags.deliveryPricingEnabled) {
      return null;
    }

    final String? trimmedDepartment = normalizeDeliveryDepartment(department);

    try {
      return await _shippingQuoteService.quoteShipping(
        addressId: addressId,
        department: trimmedDepartment,
        forceRefresh: forceRefresh,
        depositEnabled: depositEnabled,
        extra: extra,
      );
    } on CartShippingQuoteException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<CheckoutAddress?> _fetchAddressFromRepository(int addressId) async {
    try {
      final List<Map<String, dynamic>> addresses =
          await _addressesRepository.fetchAddresses();
      for (final Map<String, dynamic> entry in addresses) {
        final CheckoutAddress? parsed = _parseCheckoutAddress(entry);
        if (parsed?.id == addressId) {
          return parsed;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, dynamic>? _buildShippingQuoteExtras({
    String? deliveryPaymentTiming,
    Map<String, dynamic>? paymentOverride,
  }) {
    final Map<String, dynamic> extras = <String, dynamic>{};

    final String? normalizedTiming = deliveryPaymentTiming?.trim();
    if (normalizedTiming != null && normalizedTiming.isNotEmpty) {
      extras['delivery_payment_timing'] = normalizedTiming;
      extras['payment_timing'] = normalizedTiming;
      extras['timing'] = normalizedTiming;
    }

    if (paymentOverride != null && paymentOverride.isNotEmpty) {
      final Map<String, dynamic> sanitized =
          Map<String, dynamic>.from(paymentOverride)
            ..removeWhere((String key, dynamic value) => value == null);

      if (sanitized.isNotEmpty) {
        extras['payment'] = jsonEncode(sanitized);
        sanitized.forEach((String key, dynamic value) {
          extras['payment[$key]'] = value;
        });
      }
    }

    return extras.isEmpty ? null : extras;
  }

  void _handleShippingDestinationChange({
    String? department,
    int? addressId,
  }) {
    final bool hasChanged =
        department != _lastKnownDepartment || addressId != _lastKnownAddressId;

    if (hasChanged && FeatureFlags.deliveryPricingEnabled) {
      _shippingQuoteService.invalidateCache();
      _forceRefreshNextShippingQuote = true;
    }

    _lastKnownDepartment = department;
    _lastKnownAddressId = addressId;
  }

  bool _consumeForceRefreshFlag() {
    final bool shouldForce = _forceRefreshNextShippingQuote;
    _forceRefreshNextShippingQuote = false;
    return shouldForce;
  }

  CheckoutDeliveryInfo? _parseDeliveryInfoFromQuote(
    CheckoutShippingQuote? quote, {
    String? fallbackDepartment,
  }) {
    if (quote == null) {
      return null;
    }

    final dynamic payload = quote.delivery ?? quote.deliveryQuote ?? quote.data;
    final String? department =
        _resolveQuoteDepartment(quote) ?? fallbackDepartment;

    return _parseDeliveryInfo(payload, department: department);
  }

  String? _resolveQuoteDepartment(CheckoutShippingQuote quote) {
    final String? fromDelivery = _asString(quote.delivery?['department']);
    if (fromDelivery != null && fromDelivery.trim().isNotEmpty) {
      return normalizeDeliveryDepartment(fromDelivery) ?? fromDelivery;
    }

    final String? fromQuote = _asString(quote.deliveryQuote?['department']);
    if (fromQuote != null && fromQuote.trim().isNotEmpty) {
      return normalizeDeliveryDepartment(fromQuote) ?? fromQuote;
    }

    final String? fromData = _asString(quote.data?['department']);
    if (fromData != null && fromData.trim().isNotEmpty) {
      return normalizeDeliveryDepartment(fromData) ?? fromData;
    }

    return null;
  }

  CheckoutDeliveryInfo? _parseDeliveryInfo(dynamic payload,
      {String? department}) {
    final Map<String, dynamic>? map = _extractMap(payload, candidates: const [
      'data',
      'delivery',
      'pricing',
      'result',
      'delivery_prices',
      'deliveryPrice',
    ]);

    if (map == null || map.isEmpty) {
      return null;
    }

    final double? distanceKm = _asDouble(_firstValue(map, const [
      ['distance_km'],
      ['distance'],
      ['meta', 'distance_km'],
      ['meta', 'distance'],
      ['metrics', 'distance'],
    ]));

    final num? feeValue = _asNum(_firstValue(map, const [
      ['delivery_fee'],
      ['fee'],
      ['price'],
      ['amount'],
      ['total_fee'],
      ['delivery_price'],
    ]));

    final String? feeDisplay = _asString(_firstValue(map, const [
          ['delivery_fee_formatted'],
          ['fee_display'],
          ['price_display'],
          ['formatted_price'],
          ['formatted_fee'],
          ['delivery_fee_text'],
        ])) ??
        (feeValue != null ? feeValue.toString() : null);

    final String? currency = _asString(_firstValue(map, const [
      ['currency'],
      ['currency_code'],
      ['meta', 'currency'],
    ]));

    final CheckoutCoordinates? userCoordinates =
        _parseCoordinates(_firstValue(map, const [
      ['user_coordinates'],
      ['userLocation'],
      ['user'],
      ['customer'],
      ['recipient'],
      ['shipping', 'coordinates'],
    ]));

    final CheckoutCoordinates? vendorCoordinates =
        _parseCoordinates(_firstValue(map, const [
      ['vendor_coordinates'],
      ['vendorLocation'],
      ['vendor'],
      ['seller'],
      ['origin'],
    ]));

    final List<CheckoutDeliveryTier> tiers =
        _parseTiers(_firstValue(map, const [
      ['tiers'],
      ['size_tiers'],
      ['sizes'],
      ['price_table'],
      ['rate_table'],
      ['rates'],
    ]));

    return CheckoutDeliveryInfo(
      distanceKm: distanceKm,
      fee: feeValue,
      feeDisplay: feeDisplay,
      currency: currency,
      tiers: tiers,
      userCoordinates: userCoordinates,
      vendorCoordinates: vendorCoordinates,
      department: department ?? _asString(map['department']),
      raw: map,
    );
  }

  CheckoutAddress? _parseCheckoutAddress(dynamic payload) {
    final Map<String, dynamic>? envelope = _mapify(payload);

    final Map<String, dynamic>? map = _extractMap(payload, candidates: const [
      'user',
      'customer',
      'recipient',
      'address',
      'shipping',
    ]);

    if (map == null || map.isEmpty) {
      return null;
    }

    final CheckoutCoordinates? coordinates = _parseCoordinates(map);
    final int? id = _asInt(_firstValue(map, const [
      ['id'],
      ['address_id'],
      ['addressId'],
      ['address', 'id'],
    ]));
    final String? label = _asString(_firstValue(map, const [
      ['address'],
      ['address_line'],
      ['label'],
      ['street'],
      ['full_address'],
    ]));

    const List<List<String>> namePaths = [
      ['name'],
      ['contact_name'],
      ['contactName'],
      ['recipient_name'],
      ['recipientName'],
      ['receiver_name'],
      ['receiverName'],
      ['user', 'name'],
      ['customer', 'name'],
      ['contact', 'name'],
    ];
    String? name;
    for (final Map<String, dynamic>? scope in [map, envelope]) {
      if (scope == null) continue;
      final String? candidate = _asString(_firstValue(scope, namePaths));
      if (candidate != null && candidate.trim().isNotEmpty) {
        name = candidate;
        break;
      }
    }

    final String? description = _asString(_firstValue(map, const [
      ['description'],
      ['notes'],
      ['landmark'],
    ]));

    const List<List<String>> phonePaths = [
      ['phone'],
      ['mobile'],
      ['contact'],
      ['phone_number'],
      ['phoneNumber'],
      ['contact_phone'],
      ['contactPhone'],
      ['recipient_phone'],
      ['recipientPhone'],
      ['receiver_phone'],
      ['receiverPhone'],
      ['telephone'],
      ['contact', 'phone'],
    ];
    String? phone;
    for (final Map<String, dynamic>? scope in [map, envelope]) {
      if (scope == null) continue;
      final String? candidate = _asString(_firstValue(scope, phonePaths));
      if (candidate != null && candidate.trim().isNotEmpty) {
        phone = candidate;
        break;
      }
    }

    if ((label == null || label.trim().isEmpty) &&
        (phone == null || phone.trim().isEmpty) &&
        (coordinates?.isValid != true)) {
      return null;
    }

    return CheckoutAddress(
      id: id,
      name: name,
      label: label,
      phone: phone,
      description: description,
      coordinates: coordinates,
      raw: {
        ...?envelope,
        ...map,
      },
    );
  }

  List<CheckoutBank> _parseBanks(dynamic payload) {
    final Iterable<Map<String, dynamic>> candidates = _extractBankMaps(payload);

    final List<CheckoutBank> banks = candidates
        .map(_bankFromMap)
        .where((bank) => bank.name.isNotEmpty)
        .toList();

    final Map<String, dynamic>? payloadMap = _mapify(payload);
    final CheckoutBank? eastYemenBank = _parseEastYemenBank(payloadMap);
    if (eastYemenBank != null &&
        !banks
            .any((bank) => bank.paymentMethod == eastYemenBank.paymentMethod)) {
      banks.add(eastYemenBank);
    }

    banks.sort((a, b) {
      final int orderA = _asInt(a.raw?['display_order']) ?? 0;
      final int orderB = _asInt(b.raw?['display_order']) ?? 0;
      return orderA.compareTo(orderB);
    });

    return banks;
  }

  Iterable<Map<String, dynamic>> _extractBankMaps(dynamic payload) sync* {
    final visited = <int>{};

    Map<String, dynamic>? normalize(dynamic source) {
      if (source is Map<String, dynamic>) return source;
      if (source is Map) {
        return Map<String, dynamic>.from(source);
      }
      return null;
    }

    Iterable<dynamic> unwrap(dynamic node) sync* {
      if (node == null) return;
      if (node is List) {
        for (final element in node) {
          yield element;
        }
        return;
      }

      final Map<String, dynamic>? map = normalize(node);
      if (map == null) return;
      final int hash = map.hashCode;
      if (!visited.add(hash)) return;

      const keys = [
        'manualPaymentBanks',
        'manual_payment_banks',
        'manual_banks',
        'banks',
        'data',
        'items',
        'payment_banks',
        'paymentBanks',
      ];

      for (final key in keys) {
        if (!map.containsKey(key)) continue;
        yield* unwrap(map[key]);
      }
    }

    for (final node in unwrap(payload)) {
      final Map<String, dynamic>? map = normalize(node);
      if (map != null) {
        yield map;
      }
    }
  }

  CheckoutBank _bankFromMap(Map<String, dynamic> map) {
    final String name = _asString(_firstValue(map, const [
          ['bank_name'],
          ['name'],
          ['title'],
          ['label'],
          ['payment_method_name'],
        ]))?.trim() ??
        '';

    final String paymentMethod = _asString(_firstValue(map, const [
          ['payment_method'],
          ['method'],
          ['gateway'],
        ]))?.trim() ??
        'manual_bank';

    final String? accountName = _asString(_firstValue(map, const [
      ['account_name'],
      ['account_holder'],
      ['holder'],
    ]));

    final String? accountNumber = _asString(_firstValue(map, const [
      ['account_number'],
      ['number'],
      ['iban'],
    ]));

    final String? iban = _asString(_firstValue(map, const [
      ['iban'],
      ['iban_number'],
    ]));

    final String? branch = _asString(_firstValue(map, const [
      ['branch'],
      ['branch_name'],
    ]));

    final String? notes = _asString(_firstValue(map, const [
      ['notes'],
      ['description'],
      ['instructions'],
    ]));

    final String? logoUrl = _asString(_firstValue(map, const [
      ['logo_url'],
      ['logo'],
      ['image'],
    ]));

    final int? id = _asInt(_firstValue(map, const [
      ['id'],
      ['bank_id'],
    ]));

    return CheckoutBank(
      id: id,
      name: name,
      paymentMethod: paymentMethod.isEmpty ? 'manual_bank' : paymentMethod,
      accountName: accountName,
      accountNumber: accountNumber,
      iban: iban,
      branch: branch,
      logoUrl: logoUrl,
      notes: notes,
      raw: map,
    );
  }

  CheckoutBank? _parseEastYemenBank(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }

    final Map<String, dynamic>? extras =
        _extractMap(payload, candidates: const [
      'extras',
      'extra',
      'additional',
      'meta',
      'metadata',
    ]);

    final Map<String, dynamic>? config = _mapify(
      extras?['east_yemen_bank'] ?? extras?['eastYemenBank'],
    );

    if (config == null || config.isEmpty) {
      return null;
    }

    final bool enabled = _asBool(_firstValue(config, const [
          ['enabled'],
          ['status'],
          ['is_enabled'],
          ['isEnabled'],
          ['active'],
        ])) ??
        false;

    if (!enabled) {
      return null;
    }

    final String name = _asString(_firstValue(config, const [
          ['display_name'],
          ['name'],
          ['title'],
          ['label'],
        ]))?.trim() ??
        '';

    final String resolvedName = name.isEmpty ? 'بنك الشرق اليمني' : name;

    final String? notes = _asString(_firstValue(config, const [
      ['note'],
      ['notes'],
      ['description'],
      ['help_text'],
    ]));

    final String? logoUrl = _asString(_firstValue(config, const [
      ['logo_url'],
      ['logo'],
      ['image'],
    ]));

    final String? accountName = _asString(_firstValue(config, const [
      ['account_name'],
      ['beneficiary_name'],
      ['recipient_name'],
    ]));

    final String? accountNumber = _asString(_firstValue(config, const [
      ['account_number'],
      ['number'],
    ]));

    final String? iban = _asString(_firstValue(config, const [
      ['iban'],
      ['iban_number'],
    ]));

    final String? branch = _asString(_firstValue(config, const [
      ['branch'],
      ['branch_name'],
    ]));

    final int? displayOrder = _asInt(_firstValue(config, const [
      ['display_order'],
      ['order'],
      ['sort'],
      ['priority'],
    ]));

    final Map<String, dynamic> raw = Map<String, dynamic>.from(config);
    raw['payment_method'] ??= 'east_yemen_bank';
    if (displayOrder != null) {
      raw['display_order'] ??= displayOrder;
    } else {
      raw['display_order'] ??= 1000;
    }

    return CheckoutBank(
      id: _asInt(config['id']),
      name: resolvedName,
      paymentMethod: 'east_yemen_bank',
      accountName: accountName,
      accountNumber: accountNumber,
      iban: iban,
      branch: branch,
      logoUrl: logoUrl,
      notes: notes,
      raw: raw,
    );
  }

  CheckoutCoordinates? _parseCoordinates(dynamic payload) {
    final Map<String, dynamic>? map = _mapify(payload);
    if (map == null || map.isEmpty) {
      return null;
    }

    const List<List<String>> latPaths = <List<String>>[
      <String>['lat'],
      <String>['latitude'],
      <String>['latitudine'],
      <String>['coordinates', 'lat'],
      <String>['coordinates', 'latitude'],
      <String>['location', 'lat'],
      <String>['location', 'latitude'],
      <String>['geo', 'lat'],
      <String>['geo', 'latitude'],
    ];

    const List<List<String>> lngPaths = <List<String>>[
      <String>['lng'],
      <String>['longitude'],
      <String>['long'],
      <String>['coordinates', 'lng'],
      <String>['coordinates', 'longitude'],
      <String>['location', 'lng'],
      <String>['location', 'longitude'],
      <String>['geo', 'lng'],
      <String>['geo', 'longitude'],
    ];

    final double? lat = _asDouble(_firstValue(map, latPaths));
    final double? lng = _asDouble(_firstValue(map, lngPaths));

    if (lat == null && lng == null) {
      return null;
    }

    return CheckoutCoordinates(lat: lat, lng: lng);
  }

  List<CheckoutDeliveryTier> _parseTiers(dynamic payload) {
    if (payload == null) {
      return const <CheckoutDeliveryTier>[];
    }

    if (payload is List) {
      return payload
          .map((dynamic e) => _mapify(e))
          .whereType<Map<String, dynamic>>()
          .map(_tierFromMap)
          .toList();
    }

    if (payload is Map) {
      final map = _mapify(payload);
      if (map == null) return const <CheckoutDeliveryTier>[];
      return map.entries
          .map((entry) => _tierFromMap({
                'key': entry.key,
                'price': entry.value,
              }))
          .toList();
    }

    return const <CheckoutDeliveryTier>[];
  }

  CheckoutDeliveryTier _tierFromMap(Map<String, dynamic> map) {
    final String key = _asString(_firstValue(map, const [
          ['key'],
          ['id'],
          ['size_key'],
          ['code'],
        ]))?.trim() ??
        '';

    final String label = _asString(_firstValue(map, const [
          ['label'],
          ['name'],
          ['title'],
          ['size'],
          ['description'],
        ]))?.trim() ??
        key;

    final String? description = _asString(_firstValue(map, const [
      ['description'],
      ['range'],
      ['weight_range'],
      ['notes'],
    ]));

    final num? price = _asNum(_firstValue(map, const [
      ['price'],
      ['fee'],
      ['amount'],
      ['value'],
    ]));

    final String? priceDisplay = _asString(_firstValue(map, const [
          ['price_display'],
          ['formatted_price'],
          ['display'],
          ['text'],
        ])) ??
        (price != null ? price.toString() : null);

    return CheckoutDeliveryTier(
      key: key.isEmpty ? label : key,
      label: label,
      description: description,
      price: price,
      priceDisplay: priceDisplay,
      raw: map,
    );
  }

  Map<String, dynamic>? _extractMap(dynamic payload,
      {required List<String> candidates}) {
    final Map<String, dynamic>? normalized = _mapify(payload);
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    for (final key in candidates) {
      if (!normalized.containsKey(key)) continue;
      final Map<String, dynamic>? nested = _mapify(normalized[key]);
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }

    for (final String wrapper in const <String>['data', 'result', 'payload']) {
      if (!normalized.containsKey(wrapper)) continue;
      final Map<String, dynamic>? nested = _extractMap(
        normalized[wrapper],
        candidates: candidates,
      );
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }

    return normalized;
  }

  dynamic _firstValue(Map<String, dynamic> map, List<List<String>> paths) {
    for (final path in paths) {
      dynamic current = map;
      var success = true;
      for (final segment in path) {
        if (current is Map && current.containsKey(segment)) {
          current = current[segment];
        } else {
          success = false;
          break;
        }
      }
      if (success) {
        return current;
      }
    }
    return null;
  }

  Map<String, dynamic>? _mapify(dynamic source) {
    if (source is Map<String, dynamic>) {
      return source;
    }
    if (source is Map) {
      return Map<String, dynamic>.from(source);
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }

  num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value.replaceAll(',', ''));
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    final num? result = _asNum(value);
    return result?.toDouble();
  }

  int? _asInt(dynamic value) {
    final num? result = _asNum(value);
    return result?.toInt();
  }

  bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      if (const {
        'true',
        '1',
        'yes',
        'y',
        'on',
        'enabled',
        'active',
      }.contains(normalized)) {
        return true;
      }
      if (const {
        'false',
        '0',
        'no',
        'n',
        'off',
        'disabled',
        'inactive',
      }.contains(normalized)) {
        return false;
      }
    }
    return null;
  }
}
