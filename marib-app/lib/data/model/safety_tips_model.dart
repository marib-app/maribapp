class SafetyTipsModel {
  int? id;
  int? tipId;
  int? languageId;
  String? translatedName;

  //String? description;
  String? description;

  String? createdAt;
  String? updatedAt;
  SafetyTipsDepartment? department;
  String? productLink;
  List<SafetyTipAction> actions;

  SafetyTipsModel({
    this.id,
    this.tipId,
    this.languageId,
    this.translatedName,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.department,
    this.productLink,
    List<SafetyTipAction>? actions,
  }) : actions = List<SafetyTipAction>.unmodifiable(actions ?? const <SafetyTipAction>[]);

  SafetyTipsModel.fromJson(
      Map<String, dynamic> json, {
        SafetyTipsDepartment? department,
        String? productLink,
        List<SafetyTipAction>? sharedActions,
      }) : actions = const <SafetyTipAction>[] {
    id = _coerceInt(json['id']);
    tipId = _coerceInt(json['tip_id']);
    languageId = _coerceInt(json['language_id']);
    translatedName = _coerceString(json['translated_name'] ?? json['name']);
    description = _coerceString(
      json['description'] ?? json['text'] ?? json['message'],
    );
    createdAt = _coerceString(json['created_at']);
    updatedAt = _coerceString(json['updated_at']);
    this.productLink = productLink ?? _coerceString(json['product_link']);
    this.department = department ??
        SafetyTipsDepartment.fromNullableJson(json['department']);
    final List<SafetyTipAction> parsedActions =
    SafetyTipAction.parseList(json['actions']);
    actions = List<SafetyTipAction>.unmodifiable(
      parsedActions.isNotEmpty
          ? parsedActions
          : (sharedActions ?? const <SafetyTipAction>[]),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['tip_id'] = tipId;
    data['language_id'] = languageId;
    data['translated_name'] = translatedName;
    data['description'] = description;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    if (department != null) {
      data['department'] = department!.toJson();
    }
    data['product_link'] = productLink;
    data['actions'] = actions.map((e) => e.toJson()).toList();
    return data;
  }
}



class SafetyTipsDepartment {
  final int? id;
  final String? name;
  final String? translatedName;
  final String? description;
  final String? slug;
  final String? key;
  final String? label;
  final Map<String, dynamic>? raw;
  const SafetyTipsDepartment({
    this.id,
    this.name,
    this.translatedName,
    this.description,
    this.slug,
    this.key,
    this.label,
    this.raw,
  });

  factory SafetyTipsDepartment.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> normalized = json.map(
          (String key, dynamic value) => MapEntry(key.toLowerCase(), value),
    );

    final String? resolvedName =
        _coerceString(normalized['name']) ?? _coerceString(normalized['label']);
    final String? resolvedTranslatedName =
        _coerceString(normalized['translated_name']) ??
            _coerceString(normalized['label']);
    final String? resolvedSlug =
        _coerceString(normalized['slug']) ?? _coerceString(normalized['key']);

    return SafetyTipsDepartment(
      id: _coerceInt(normalized['id']),
      name: resolvedName,
      translatedName: resolvedTranslatedName ?? resolvedName,
      description: _coerceString(normalized['description']),
      slug: resolvedSlug ?? resolvedName,
      key: _coerceString(normalized['key']) ?? resolvedSlug,
      label: _coerceString(normalized['label']) ?? resolvedTranslatedName,
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['translated_name'] = translatedName;
    data['description'] = description;
    data['slug'] = slug;
    data['key'] = key;
    data['label'] = label;
    if (raw != null) {
      data['raw'] = raw;
    }
    data.removeWhere(
          (String key, dynamic value) =>
      value == null || (value is String && value.isEmpty),
    );
    return data;
  }

  static SafetyTipsDepartment? fromNullableJson(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is SafetyTipsDepartment) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      return SafetyTipsDepartment.fromJson(value);
    }
    if (value is Map) {
      return SafetyTipsDepartment.fromJson(
        value.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        ),
      );
    }
    return null;
  }
}

class SafetyTipAction {
  final String type;
  final String? label;
  final String? target;
  final String? url;
  final String? productLink;

  const SafetyTipAction({
    required this.type,
    this.label,
    this.target,
    this.url,
    this.productLink,
  });

  factory SafetyTipAction.fromJson(Map<String, dynamic> json) {
    return SafetyTipAction(
      type: _coerceString(json['type'] ?? json['action']) ?? '',
      label: _coerceString(json['label'] ?? json['title'] ?? json['text']),
      target: _coerceString(json['target']),
      url: _coerceString(
        json['url'] ?? json['href'] ?? json['link'],
      ),
      productLink: _coerceString(json['product_link']),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{
      'type': type,
      'label': label,
      'target': target,
      'url': url,
      'product_link': productLink,
    };
    data.removeWhere((key, value) => value == null || (value is String && value.isEmpty));
    return data;
  }

  static SafetyTipAction? fromDynamic(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is SafetyTipAction) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      return SafetyTipAction.fromJson(value);
    }
    if (value is Map) {
      return SafetyTipAction.fromJson(
        value.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        ),
      );
    }
    return null;
  }

  static List<SafetyTipAction> parseList(dynamic value) {
    if (value is List) {
      return List<SafetyTipAction>.unmodifiable(
        value.map(SafetyTipAction.fromDynamic).whereType<SafetyTipAction>(),
      );
    }
    final SafetyTipAction? parsed = fromDynamic(value);
    if (parsed != null) {
      return List<SafetyTipAction>.unmodifiable(<SafetyTipAction>[parsed]);
    }
    return const <SafetyTipAction>[];
  }
}

int? _coerceInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String? _coerceString(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return value.toString();
}