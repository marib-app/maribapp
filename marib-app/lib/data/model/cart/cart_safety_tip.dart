import 'package:collection/collection.dart';

class CartSafetyTipsPayload {
  const CartSafetyTipsPayload({
    required this.tips,
    this.presentation,
    this.raw,
  });

  final List<CartSafetyTip> tips;
  final String? presentation;
  final Map<String, dynamic>? raw;

  bool get hasTips => tips.isNotEmpty;

  String get _normalizedPresentation =>
      (presentation ?? 'banner').toLowerCase().trim();

  bool get showAsModal => _normalizedPresentation == 'modal';

  bool get showAsBanner => _normalizedPresentation == 'banner';

  CartSafetyTip? get primaryTip =>
      tips.firstWhereOrNull((CartSafetyTip tip) => tip.hasDescription);

  CartSafetyTipsPayload copyWith({
    List<CartSafetyTip>? tips,
    String? presentation,
    Map<String, dynamic>? raw,
  }) {
    return CartSafetyTipsPayload(
      tips: tips ?? this.tips,
      presentation: presentation ?? this.presentation,
      raw: raw ?? this.raw,
    );
  }

  factory CartSafetyTipsPayload.fromJson(Map<String, dynamic> json) {
    final List<CartSafetyTip> parsedTips = (json['tips'] as List?)
        ?.map((dynamic e) => CartSafetyTip.tryParse(e))
        .whereType<CartSafetyTip>()
        .toList() ??
        const <CartSafetyTip>[];

    final String? presentation = _coerceString(
      json['presentation'] ?? json['display'] ?? json['style'],
    );

    final Map<String, dynamic>? raw = json;

    return CartSafetyTipsPayload(
      tips: parsedTips,
      presentation: presentation,
      raw: raw,
    );
  }

  static String? _coerceString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Enum) return value.name;
    return value.toString();
  }
}

class CartSafetyTip {
  const CartSafetyTip({
    this.id,
    this.title,
    this.description,
    this.actions = const <CartSafetyTipAction>[],
    this.raw,
  });

  final int? id;
  final String? title;
  final String? description;
  final List<CartSafetyTipAction> actions;
  final Map<String, dynamic>? raw;

  bool get hasDescription => (description?.trim().isNotEmpty ?? false);

  static CartSafetyTip? tryParse(dynamic value) {
    if (value == null) return null;
    if (value is CartSafetyTip) return value;
    if (value is Map<String, dynamic>) return CartSafetyTip.fromJson(value);
    if (value is Map) {
      return CartSafetyTip.fromJson(
        value.map((dynamic key, dynamic value) =>
            MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  factory CartSafetyTip.fromJson(Map<String, dynamic> json) {
    final String? description = _coerceString(
      json['description'] ?? json['text'] ?? json['message'],
    );

    final List<CartSafetyTipAction> actions = (json['actions'] as List?)
        ?.map((dynamic e) => CartSafetyTipAction.tryParse(e))
        .whereType<CartSafetyTipAction>()
        .toList() ??
        const <CartSafetyTipAction>[];

    return CartSafetyTip(
      id: _coerceInt(json['id'] ?? json['tip_id'] ?? json['item_id']),
      title: _coerceString(json['title'] ?? json['name']),
      description: description,
      actions: actions,
      raw: json,
    );
  }

  static int? _coerceInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String? _coerceString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
}

class CartSafetyTipAction {
  CartSafetyTipAction({
    required this.type,
    this.label,
    this.target,
    this.productLink,
    this.payload,
    this.raw,
  });

  final String type;
  final String? label;
  final String? target;
  final String? productLink;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? raw;

  String get normalizedType => type.toLowerCase().trim();

  bool get isNavigate => normalizedType == 'navigate';

  bool get isOpenUrl => normalizedType == 'open_url';

  String? get normalizedTarget => target?.toLowerCase().trim();

  bool get navigatesToCart =>
      isNavigate && (normalizedTarget == 'cart' ||
          (payload?['target']?.toString().toLowerCase().trim() == 'cart'));

  String? get resolvedProductLink {
    final dynamic candidate = productLink ??
        payload?['product_link'] ??
        payload?['url'] ??
        payload?['link'] ??
        payload?['href'];
    if (candidate == null) return null;
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
    return candidate.toString();
  }

  String get resolvedLabel {
    final String? provided = label?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    switch (normalizedType) {
      case 'navigate':
        return 'عرض';
      case 'open_url':
        return 'فتح';
      default:
        return 'متابعة';
    }
  }

  static CartSafetyTipAction? tryParse(dynamic value) {
    if (value == null) return null;
    if (value is CartSafetyTipAction) return value;
    if (value is Map<String, dynamic>) {
      try {
        return CartSafetyTipAction.fromJson(value);
      } catch (_) {
        return null;
      }
    }
    if (value is Map) {
      try {
        return CartSafetyTipAction.fromJson(
          value.map((dynamic key, dynamic value) =>
              MapEntry(key.toString(), value)),
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  factory CartSafetyTipAction.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : null;

    final String? type = _coerceString(json['type'] ?? json['action']);
    if (type == null || type.trim().isEmpty) {
      throw ArgumentError('Action type is required');
    }

    return CartSafetyTipAction(
      type: type,
      label: _coerceString(json['label'] ?? json['title'] ?? json['text']),
      target: _coerceString(json['target'] ?? payload?['target'] ?? json['value']),
      productLink: _coerceString(
        json['product_link'] ?? json['url'] ?? json['link'] ?? payload?['product_link'],
      ),
      payload: payload,
      raw: json,
    );
  }

  static String? _coerceString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
}