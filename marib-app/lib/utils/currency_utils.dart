import 'dart:collection';

class CurrencyParseResult {
  const CurrencyParseResult({
    this.code,
    this.display,
  });

  final String? code;
  final String? display;

  CurrencyParseResult mergePreferNew(CurrencyParseResult other) {
    return CurrencyParseResult(
      code: other.code ?? code,
      display: other.display ?? display,
    );
  }

  bool get hasData => code != null || display != null;
}

class CurrencyUtils {
  static const List<String> _codeKeys = <String>[
    'currency_code',
    'currencyCode',
    'currency_iso',
    'currencyIso',
    'currency_id',
    'currencyId',
    'currency_iso_code',
    'currencyIsoCode',
    'currency_code_iso',
    'currencyCodeIso',
    'currency_key',
    'currencyKey',
    'currencyAlpha3',
    'currency_alpha3',
    'currencyAlpha',
    'currency_alpha',
  ];

  static const List<String> _labelKeys = <String>[
    'currency_label',
    'currencyLabel',
    'currency_text',
    'currencyText',
    'currency_display',
    'currencyDisplay',
    'currency_name',
    'currencyName',
  ];

  static const List<String> _symbolKeys = <String>[
    'currency_symbol',
    'currencySymbol',
    'currency_sign',
    'currencySign',
    'currency_symbol_native',
    'currencySymbolNative',
  ];

  static const List<String> _genericCurrencyKeys = <String>[
    'currency',
    'curr',
    'price_currency',
    'priceCurrency',
    'order_currency',
    'payment_currency',
    'paymentCurrency',
    'currency_value',
    'currencyValue',
    'currency_text_value',
    'currencyTextValue',
  ];

  static final Map<String, String> _currencySynonyms = <String, String>{
    'yer': 'YER',
    'ريال يمني': 'YER',
    'ريال يمنى': 'YER',
    'ر.ي': 'YER',
    'ر. ي.': 'YER',
    'sar': 'SAR',
    'ريال سعودي': 'SAR',
    'ر.س': 'SAR',
    'ر. س.': 'SAR',
    'sar ر.س': 'SAR',
    'omr': 'OMR',
    'ريال عماني': 'OMR',
    'ر.ع': 'OMR',
    'aed': 'AED',
    'درهم اماراتي': 'AED',
    'د.إ': 'AED',
    'kwd': 'KWD',
    'دينار كويتي': 'KWD',
    'د.ك': 'KWD',
    'bhd': 'BHD',
    'دينار بحريني': 'BHD',
    'د.ب': 'BHD',
    'egp': 'EGP',
    'جنيه مصري': 'EGP',
    'ج.م': 'EGP',
    'usd': 'USD',
    'دولار': 'USD',
    'دولار امريكي': 'USD',
    '$': 'USD',
    'eur': 'EUR',
    '€': 'EUR',
    'جنيه استرليني': 'GBP',
    'gbp': 'GBP',
    '£': 'GBP',
    'try': 'TRY',
    '₺': 'TRY',
    'ليرة تركية': 'TRY',
  };

  static CurrencyParseResult parseCurrency(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) {
      return const CurrencyParseResult();
    }

    String? resolvedCode;
    String? resolvedDisplay;

    for (final Map<String, dynamic> map in _flattenMaps(source)) {
      final String? codeCandidate = _firstStringMatch(map, _codeKeys);
      final String? labelCandidate = _firstStringMatch(map, _labelKeys);
      final String? symbolCandidate = _firstStringMatch(map, _symbolKeys);
      final String? genericCandidate = _firstStringMatch(map, _genericCurrencyKeys);

      resolvedCode ??= normalizeCurrencyCode(codeCandidate);
      resolvedCode ??= normalizeCurrencyCode(labelCandidate);
      resolvedCode ??= normalizeCurrencyCode(symbolCandidate);
      resolvedCode ??= normalizeCurrencyCode(genericCandidate);

      resolvedDisplay ??= labelCandidate;
      resolvedDisplay ??= symbolCandidate;
      resolvedDisplay ??= genericCandidate;
      resolvedDisplay ??= codeCandidate;

      if (resolvedCode != null && resolvedDisplay != null) {
        break;
      }
    }

    if (resolvedDisplay == null && resolvedCode != null) {
      resolvedDisplay = resolvedCode;
    }

    return CurrencyParseResult(code: resolvedCode, display: resolvedDisplay);
  }

  static Iterable<Map<String, dynamic>> _flattenMaps(Map<String, dynamic> root) sync* {
    final Queue<dynamic> queue = Queue<dynamic>();
    final Set<int> visited = <int>{};
    queue.add(root);

    while (queue.isNotEmpty) {
      final dynamic current = queue.removeFirst();
      if (current is Map) {
        final int id = identityHashCode(current);
        if (!visited.add(id)) {
          continue;
        }

        final Map<String, dynamic> normalized = <String, dynamic>{};
        current.forEach((dynamic key, dynamic value) {
          if (key is String) {
            normalized[key] = value;
          }
        });

        if (normalized.isNotEmpty) {
          yield normalized;
        }

        for (final dynamic value in normalized.values) {
          if (value is Map || value is Iterable) {
            queue.add(value);
          }
        }
      } else if (current is Iterable) {
        for (final dynamic element in current) {
          if (element is Map || element is Iterable) {
            queue.add(element);
          }
        }
      }
    }
  }

  static String? _firstStringMatch(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      if (!map.containsKey(key)) {
        continue;
      }
      final String? value = _stringify(map[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static String? _stringify(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }

  static String? normalizeCurrencyCode(String? raw) {
    final String? trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final String lower = trimmed.toLowerCase();
    final String? directMatch = _currencySynonyms[lower];
    if (directMatch != null) {
      return directMatch;
    }

    final Iterable<String> tokens = <String>{
      trimmed,
      ...trimmed.split(RegExp(r'[\s\-_/\\()]+')),
    };

    for (final String token in tokens) {
      if (token.isEmpty) {
        continue;
      }
      final String tokenLower = token.toLowerCase();
      final String? synonym = _currencySynonyms[tokenLower];
      if (synonym != null) {
        return synonym;
      }
    }

    final RegExpMatch? asciiMatch = RegExp(r'[A-Za-z]{3}').firstMatch(trimmed.toUpperCase());
    if (asciiMatch != null) {
      return asciiMatch.group(0)!.toUpperCase();
    }

    return null;
  }

  static bool areEquivalent(String? a, String? b) {
    final String? normalizedA = normalizeCurrencyCode(a);
    final String? normalizedB = normalizeCurrencyCode(b);
    if (normalizedA != null || normalizedB != null) {
      return normalizedA == normalizedB;
    }
    final String? trimmedA = _stringify(a);
    final String? trimmedB = _stringify(b);
    if (trimmedA == null || trimmedB == null) {
      return false;
    }
    return trimmedA == trimmedB;
  }

  static String? displayToken({String? label, String? symbol, String? fallback, String? code}) {
    return label ?? symbol ?? fallback ?? code;
  }
}