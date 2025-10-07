class SocialLink {
  final String label;
  final String url;
  final String? iconClass;

  const SocialLink({
    required this.label,
    required this.url,
    this.iconClass,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'url': url,
      if (iconClass != null && iconClass!.isNotEmpty) 'iconClass': iconClass,

    };
  }

  factory SocialLink.fromMap(Map<dynamic, dynamic> map) {
    final dynamic rawUrl =
        map['url'] ?? map['link'] ?? map['value'] ?? map['href'];
    if (rawUrl == null) {
      throw ArgumentError('SocialLink map is missing a url/link field');
    }

    final dynamic rawLabel = map['label'] ??
        map['name'] ??
        map['title'] ??
        map['platform'] ??
        map['key'] ??
        map['type'];

    final String url = rawUrl.toString().trim();
    final String label = rawLabel == null || rawLabel.toString().trim().isEmpty
        ? url
        : rawLabel.toString().trim();

    final String? iconClass = _parseIconClass(map);

    return SocialLink(label: label, url: url, iconClass: iconClass);

  }

  factory SocialLink.fromKeyValue(String key, dynamic value) {
    final String label = key.trim().isEmpty ? value.toString().trim() : key;
    return SocialLink(label: label, url: value.toString().trim());
  }

  static SocialLink? fromDynamic(dynamic raw) {
    if (raw == null) {
      return null;
    }

    if (raw is SocialLink) {
      return raw;
    }

    if (raw is Map) {
      try {
        final link = SocialLink.fromMap(raw);
        return link.url.isEmpty ? null : link;
      } catch (_) {
        return null;
      }
    }

    if (raw is List && raw.length >= 2) {
      final label = raw.first?.toString() ?? '';
      final url = raw[1]?.toString() ?? '';
      if (url.trim().isEmpty) {
        return null;
      }
      final resolvedLabel = label.trim().isEmpty ? url.trim() : label.trim();
      return SocialLink(label: resolvedLabel, url: url.trim());
    }

    final text = raw.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    return SocialLink(label: text, url: text);
  }
  static String? _parseIconClass(Map<dynamic, dynamic> map) {
    final dynamic rawIcon = map['iconClass'] ??
        map['icon_class'] ??
        map['icon'] ??
        map['css_class'] ??
        map['cssClass'] ??
        map['class'];

    if (rawIcon == null) {
      return null;
    }

    if (rawIcon is Map) {
      for (final dynamic value in rawIcon.values) {
        final String? parsed = _normalizeIconValue(value);
        if (parsed != null) {
          return parsed;
        }
      }
      return null;
    }

    if (rawIcon is Iterable) {
      final Iterable<String> tokens = rawIcon
          .map((dynamic value) => _normalizeIconValue(value))
          .whereType<String>();
      final String combined = tokens.join(' ').trim();
      return combined.isEmpty ? null : combined;
    }

    return _normalizeIconValue(rawIcon);
  }

  static String? _normalizeIconValue(dynamic raw) {
    if (raw == null) {
      return null;
    }
    final String text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }
}