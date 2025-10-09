import 'package:collection/collection.dart';
import 'package:marib/utils/hive_utils.dart';

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


  String? get departmentKey {
    final dynamic department = raw?['department'];
    if (department is String) {
      final String trimmed = department.trim();
      return trimmed.isEmpty ? null : trimmed.toLowerCase();
    }
    if (department is Map<String, dynamic>) {
      final dynamic value = department['key'] ??
          department['code'] ??
          department['department'] ??
          department['id'];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim().toLowerCase();
      }
    }
    return null;
  }

  bool get isSheinDepartment => departmentKey == 'shein';

  String get _normalizedPresentation =>
      (presentation ?? 'banner').toLowerCase().trim();

  bool get showAsModal => _normalizedPresentation == 'modal';

  bool get showAsBanner => _normalizedPresentation == 'banner';

  CartSafetyTip? get primaryTip =>
      tips.firstWhereOrNull((CartSafetyTip tip) => tip.hasDescription);



  List<CartSafetyTipAction> get rawActions {
    final dynamic actions = raw?['actions'];
    if (actions is List) {
      return actions
          .map((dynamic action) => CartSafetyTipAction.tryParse(action))
          .whereType<CartSafetyTipAction>()
          .toList();
    }
    if (actions is Map) {
      return actions.values
          .map((dynamic action) => CartSafetyTipAction.tryParse(action))
          .whereType<CartSafetyTipAction>()
          .toList();
    }
    return const <CartSafetyTipAction>[];
  }


  String? get fallbackReviewLink {
    final dynamic link = raw?['review_link'] ?? raw?['reviewLink'];
    if (link == null) return null;
    if (link is String) {
      final String trimmed = link.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return link.toString();
  }

  String? get fallbackProductLink {
    final dynamic link = raw?['product_link'] ?? raw?['productLink'];
    if (link == null) return null;
    if (link is String) {
      final String trimmed = link.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return link.toString();
  }


  String? get fallbackVerificationLink =>
      fallbackReviewLink ?? fallbackProductLink;


  List<CartSafetyTipAction> get fallbackActions {
    if (primaryTip?.actions.isNotEmpty ?? false) {
      return primaryTip!.actions;
    }

    final List<CartSafetyTipAction> parsedRaw = rawActions;
    if (parsedRaw.isNotEmpty) {
      return parsedRaw;
    }

    if (!isSheinDepartment) {
      return const <CartSafetyTipAction>[];
    }

    final String? verificationLink = fallbackVerificationLink;
    if (verificationLink == null) {
      return const <CartSafetyTipAction>[];
    }


    final Map<String, dynamic> fallbackPayload = <String, dynamic>{
      if (fallbackReviewLink != null) 'review_link': fallbackReviewLink,
      if (fallbackProductLink != null) 'product_link': fallbackProductLink,
    };


    return <CartSafetyTipAction>[
      CartSafetyTipAction(
        type: 'open_url',
        label: 'تحقق من المنتج',
        productLink: verificationLink,
        payload: fallbackPayload.isEmpty ? null : fallbackPayload,
        raw: <String, dynamic>{
          'type': 'open_url',
          'label': 'Verify Product',
          if (fallbackReviewLink != null) 'review_link': fallbackReviewLink,
          'product_link': fallbackProductLink ?? verificationLink,
          'url': verificationLink,
        },
      ),
    ];
  }

  String? get fallbackTitle {
    final List<String> keys = <String>['title', 'name', 'heading', 'label'];
    for (final String key in keys) {
      final dynamic value = raw?[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? get fallbackDescription {
    final List<String> keys = <String>[
      'disclaimer',
      'default_description',
      'description',
      'message',
      'text',
      'note',
      'return_policy_text',
    ];

    for (final String key in keys) {
      final dynamic value = raw?[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  bool get hasDisplayableContent => hasTips ||
      rawActions.isNotEmpty ||
      fallbackVerificationLink != null;

  bool get requiresConfirmation {
    if (showAsModal && hasDisplayableContent) {
      return true;
    }
    if (isSheinDepartment) {
      return true;
    }
    return false;
  }






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
    final String? description = _resolveTipDescription(json);


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



  static String? _resolveTipDescription(Map<String, dynamic> json) {
    String? normalize(String? value) {
      if (value == null) return null;
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final String? localized = normalize(_localizedTranslation(json['translations']));
    if (localized != null) {
      return localized;
    }

    final List<dynamic> candidates = <dynamic>[
      json['description'],
      json['text'],
      json['message'],
      json['default_description'],
      json['defaultDescription'],
    ];

    for (final dynamic candidate in candidates) {
      final String? resolved = normalize(_coerceString(candidate));
      if (resolved != null) {
        return resolved;
      }
    }

    return null;
  }

  static String? _localizedTranslation(dynamic translationsRaw) {
    if (translationsRaw == null) {
      return null;
    }

    Map<String, dynamic>? translations;
    if (translationsRaw is Map<String, dynamic>) {
      translations = translationsRaw;
    } else if (translationsRaw is Map) {
      translations = translationsRaw.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }

    if (translations == null || translations.isEmpty) {
      return null;
    }

    String? resolveString(dynamic value) {
      final String? stringValue = _coerceString(value);
      if (stringValue == null) {
        return null;
      }
      final String trimmed = stringValue.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    String? languageCode;
    final dynamic language = HiveUtils.getLanguage();
    if (language is Map) {
      final dynamic code = language['code'] ??
          language['language_code'] ??
          language['language'];
      if (code is String && code.trim().isNotEmpty) {
        languageCode = code.trim();
      }
    } else if (language is String && language.trim().isNotEmpty) {
      languageCode = language.trim();
    }

    Iterable<String> candidateKeys(String code) sync* {
      if (code.isEmpty) {
        return;
      }
      yield code;
      final String lower = code.toLowerCase();
      if (lower != code) {
        yield lower;
      }
      final List<String> segments = code.split(RegExp('[-_]'));
      if (segments.isNotEmpty) {
        final String primary = segments.first;
        if (primary.isNotEmpty) {
          yield primary;
          final String primaryLower = primary.toLowerCase();
          if (primaryLower != primary) {
            yield primaryLower;
          }
        }
      }
    }

    if (languageCode != null) {
      for (final String key in candidateKeys(languageCode)) {
        final dynamic value = translations[key] ?? translations[key.toLowerCase()];
        final String? resolved = resolveString(value);
        if (resolved != null) {
          return resolved;
        }
      }
    }

    for (final dynamic value in translations.values) {
      final String? resolved = resolveString(value);
      if (resolved != null) {
        return resolved;
      }
    }

    return null;
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
        payload?['review_link'] ??
        payload?['product_link'] ??
        payload?['verification_link'] ??
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