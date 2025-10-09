import 'package:marib/data/model/item/item_model.dart';

class ItemPurchaseAttributeOption {
  const ItemPurchaseAttributeOption({
    required this.id,
    required this.key,
    required this.name,
    this.type,
    required this.requiredForCheckout,
    required this.affectsStock,
    this.allowedValues = const <String>[],
    this.values = const <String>[],
    this.defaultValue,
  });

  factory ItemPurchaseAttributeOption.fromJson(Map<String, dynamic> json) {
    List<String> _stringList(dynamic source) {
      if (source == null) {
        return const <String>[];
      }

      if (source is List) {
        return source
            .map((dynamic entry) => entry?.toString() ?? '')
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);
      }

      if (source is Map) {
        return source.values
            .map((dynamic entry) => entry?.toString() ?? '')
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);
      }

      final String value = source.toString().trim();
      return value.isEmpty ? const <String>[] : <String>[value];
    }

    final int? id = _parseInt(json['id']);
    final String key = (json['key'] ?? (id != null ? 'cf$id' : ''))
        .toString()
        .trim();

    return ItemPurchaseAttributeOption(
      id: id ?? 0,
      key: key,
      name: _normalizeString(json['name']) ?? '',
      type: _normalizeString(json['type']),
      requiredForCheckout: _parseBool(json['required_for_checkout']) ?? false,
      affectsStock: _parseBool(json['affects_stock']) ?? false,
      allowedValues: _stringList(json['allowed_values']),
      values: _stringList(json['values']),
      defaultValue: _normalizeString(json['default_value']),
    );
  }

  final int id;
  final String key;
  final String name;
  final String? type;
  final bool requiredForCheckout;
  final bool affectsStock;
  final List<String> allowedValues;
  final List<String> values;
  final String? defaultValue;
}

class ItemVariantStockOption {
  const ItemVariantStockOption({
    required this.variantKey,
    required this.stock,
    required this.reservedStock,
    required this.availableStock,
  });

  factory ItemVariantStockOption.fromJson(Map<String, dynamic> json) {
    return ItemVariantStockOption(
      variantKey: _normalizeString(json['variant_key']) ?? '',
      stock: _parseInt(json['stock']) ?? 0,
      reservedStock: _parseInt(json['reserved_stock']) ?? 0,
      availableStock: _parseInt(json['available_stock']) ?? 0,
    );
  }

  final String variantKey;
  final int stock;
  final int reservedStock;
  final int availableStock;
}

class ItemPurchaseOptions {
  const ItemPurchaseOptions({
    required this.itemId,
    required this.basePrice,
    required this.finalPrice,
    this.discount,
    this.attributes = const <ItemPurchaseAttributeOption>[],
    this.variantStocks = const <ItemVariantStockOption>[],
  });

  factory ItemPurchaseOptions.fromJson(Map<String, dynamic> json) {
    List<ItemPurchaseAttributeOption> _parseAttributes(dynamic value) {
      Iterable<Map<dynamic, dynamic>> entries;

      if (value is List) {
        entries = value.whereType<Map>();
      } else if (value is Map) {
        entries = value.values.whereType<Map>();
      } else {
        entries = const <Map<dynamic, dynamic>>[];
      }

      return entries
          .map((Map<dynamic, dynamic> entry) =>
          ItemPurchaseAttributeOption.fromJson(entry.map((dynamic key, dynamic val) =>
              MapEntry(key.toString(), val))))
          .toList(growable: false);
    }

    List<ItemVariantStockOption> _parseStocks(dynamic value) {
      Iterable<Map<dynamic, dynamic>> entries;

      if (value is List) {
        entries = value.whereType<Map>();
      } else if (value is Map) {
        entries = value.values.whereType<Map>();
      } else {
        entries = const <Map<dynamic, dynamic>>[];
      }

      return entries
          .map((Map<dynamic, dynamic> entry) =>
          ItemVariantStockOption.fromJson(entry.map((dynamic key, dynamic val) =>
              MapEntry(key.toString(), val))))
          .toList(growable: false);
    }

    final int itemId = _parseInt(json['item_id']) ?? _parseInt(json['id']) ?? 0;
    final double basePrice = _parseDouble(json['base_price']) ??
        _parseDouble(json['price']) ??
        0.0;
    final double finalPrice = _parseDouble(json['final_price']) ?? basePrice;

    final dynamic discountRaw = json['discount'];

    return ItemPurchaseOptions(
      itemId: itemId,
      basePrice: basePrice,
      finalPrice: finalPrice,
      discount: ItemDiscount.fromJson(discountRaw),
      attributes: _parseAttributes(json['attributes']),
      variantStocks: _parseStocks(json['variant_stocks']),
    );
  }

  factory ItemPurchaseOptions.empty({int itemId = 0}) {
    return ItemPurchaseOptions(
      itemId: itemId,
      basePrice: 0,
      finalPrice: 0,
    );
  }

  final int itemId;
  final double basePrice;
  final double finalPrice;
  final ItemDiscount? discount;
  final List<ItemPurchaseAttributeOption> attributes;
  final List<ItemVariantStockOption> variantStocks;

  ItemPurchaseAttributeOption? attributeByKey(String key) {
    final String normalized = key.toLowerCase().trim();
    for (final ItemPurchaseAttributeOption option in attributes) {
      if (option.key.toLowerCase().trim() == normalized) {
        return option;
      }
    }
    return null;
  }
}

int? _parseInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final String normalized = value.replaceAll(',', '').trim();
    return normalized.isEmpty ? null : double.tryParse(normalized);
  }
  return null;
}

bool? _parseBool(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

String? _normalizeString(dynamic value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}