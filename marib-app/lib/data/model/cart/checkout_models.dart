import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/data/model/cart/cart_discount.dart';

import 'package:meta/meta.dart';

/// Aggregated payload returned from [CheckoutRepository].
@immutable
class CheckoutResult {
  const CheckoutResult({
    required this.cartItems,
    required this.banks,
    this.discounts = const <CartDiscount>[],
    this.deliveryInfo,
    this.userAddress,
    this.paymentSettings,
    this.shippingQuote,
    this.walletSummary,
    this.isWalletAvailable,
  });

  final List<Cart> cartItems;
  final List<CheckoutBank> banks;
  final List<CartDiscount> discounts;
  final CheckoutDeliveryInfo? deliveryInfo;
  final CheckoutAddress? userAddress;
  final Map<String, dynamic>? paymentSettings;
  final CheckoutShippingQuote? shippingQuote;
  final WalletSummary? walletSummary;
  final bool? isWalletAvailable;
}

@immutable
class CheckoutBank {
  const CheckoutBank({
    this.id,
    required this.name,
    this.paymentMethod = 'manual_bank',

    this.accountName,
    this.accountNumber,
    this.iban,
    this.branch,
    this.logoUrl,
    this.notes,
    this.storeGatewayId,
    this.storeGatewayAccountId,
    this.isActive,
    this.raw,
  });

  final int? id;
  final String name;
  final String? accountName;
  final String? accountNumber;
  final String paymentMethod;

  final String? iban;
  final String? branch;
  final String? logoUrl;
  final String? notes;
  final int? storeGatewayId;
  final int? storeGatewayAccountId;
  final bool? isActive;
  final Map<String, dynamic>? raw;
}

@immutable
class CheckoutDeliveryInfo {
  const CheckoutDeliveryInfo({
    this.distanceKm,
    this.fee,
    this.feeDisplay,
    this.currency,
    this.currencyCode,
    this.tiers = const <CheckoutDeliveryTier>[],
    this.userCoordinates,
    this.vendorCoordinates,
    this.department,
    this.raw,
  });
  final String? currencyCode;

  final double? distanceKm;
  final num? fee;
  final String? feeDisplay;
  final String? currency;
  final List<CheckoutDeliveryTier> tiers;
  final CheckoutCoordinates? userCoordinates;
  final CheckoutCoordinates? vendorCoordinates;
  final String? department;
  final Map<String, dynamic>? raw;
}


@immutable
class CheckoutShippingQuote {
  const CheckoutShippingQuote({
    this.delivery,
    this.deliveryQuote,
    this.address,
    this.totals,
    this.wallet,
    this.meta,
    this.departmentNotice,
    this.fromCache,
    this.cacheKey,
    this.cacheExpiresAt,
    this.cacheTtlSeconds,
    this.data,
    this.raw,
  });

  final Map<String, dynamic>? delivery;
  final Map<String, dynamic>? deliveryQuote;
  final Map<String, dynamic>? address;
  final Map<String, dynamic>? totals;
  final Map<String, dynamic>? wallet;
  final Map<String, dynamic>? meta;
  final String? departmentNotice;
  final bool? fromCache;
  final String? cacheKey;
  final DateTime? cacheExpiresAt;
  final num? cacheTtlSeconds;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? raw;
}


@immutable
class CheckoutDeliveryTier {
  const CheckoutDeliveryTier({
    required this.key,
    required this.label,
    this.description,
    this.price,
    this.priceDisplay,
    this.raw,
  });

  final String key;
  final String label;
  final String? description;
  final num? price;
  final String? priceDisplay;
  final Map<String, dynamic>? raw;
}

@immutable
class CheckoutCoordinates {
  const CheckoutCoordinates({
    this.lat,
    this.lng,
  });

  final double? lat;
  final double? lng;

  bool get isValid => lat != null && lng != null;
}

@immutable
class CheckoutAddress {
  const CheckoutAddress({
    this.id,
    this.name,
    this.label,
    this.phone,
    this.description,
    this.coordinates,
    this.raw,
  });
  final int? id;
  final String? name;
  final String? label;
  final String? phone;
  final String? description;
  final CheckoutCoordinates? coordinates;
  final Map<String, dynamic>? raw;
}