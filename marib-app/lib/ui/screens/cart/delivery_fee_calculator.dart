import 'package:marib/data/model/cart/checkout_models.dart'; // CheckoutDeliveryTier
import 'package:marib/data/model/item/cart_model.dart'; // Cart

enum SizeTier { small, medium, large }

SizeTier pickTierByWeightKg(double kg) {
  if (kg <= 5) return SizeTier.small;
  if (kg <= 20) return SizeTier.medium;
  return SizeTier.large;
}

double totalWeightKg<T>(
    Iterable<T> items, double Function(T) itemKg, int Function(T) qty) {
  double sum = 0;
  for (final it in items) {
    final w = itemKg(it);
    final q = qty(it);
    if (w > 0 && q > 0) sum += w * q;
  }
  return (sum * 10).ceil() / 10.0;
}

double? ratePerKmForTier(SizeTier tier, List<CheckoutDeliveryTier> tiers) {
  String key(SizeTier t) {
    switch (t) {
      case SizeTier.small:
        return 'small';
      case SizeTier.medium:
        return 'medium';
      case SizeTier.large:
        return 'large';
    }
  }

  final wanted = {
    key(tier),
    if (tier == SizeTier.small) ...{'صغير', 's'},
    if (tier == SizeTier.medium) ...{'متوسط', 'm', 'medium'},
    if (tier == SizeTier.large) ...{'كبير', 'l', 'large'},
  }.map((e) => e.toLowerCase());

  CheckoutDeliveryTier? match;
  for (final t in tiers) {
    final k = (t.key).toLowerCase();
    final l = (t.label).toLowerCase();
    if (wanted.contains(k) || wanted.contains(l)) {
      match = t;
      break;
    }
  }

  if (match == null && tiers.isNotEmpty) {
    final idx = tiers.length >= 3
        ? (tier == SizeTier.small
            ? 0
            : tier == SizeTier.medium
                ? 1
                : 2)
        : (tier == SizeTier.small
            ? 0
            : tiers.length == 1
                ? 0
                : 1);
    match = tiers[idx];
  }

  return match?.price?.toDouble();
}

double? computeDeliveryFee({
  required List<Cart> cartItems,
  required List<CheckoutDeliveryTier> tiers,
  required double? distanceKm,
  required double Function(Cart) itemWeightKg,
}) {
  if (distanceKm == null || distanceKm <= 0) return null;

  final kg = totalWeightKg<Cart>(
    cartItems,
    itemWeightKg,
    (c) => c.quantity,
  );

  final tier = pickTierByWeightKg(kg);
  final ratePerKm = ratePerKmForTier(tier, tiers);
  if (ratePerKm == null) return null;

  final fee = ratePerKm * distanceKm;
  return double.parse(fee.toStringAsFixed(2));
}
