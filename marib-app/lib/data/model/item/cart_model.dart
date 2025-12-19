import 'dart:convert';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/delivery_department.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/variant_key.dart';



class Cart extends ItemModel {


  Cart({
    required int id,
    required String name,
    required String image,
    required double price,
    double? finalPrice,
    required int categoryId,
    required User? user,
    required this.section,

    this.quantity = 0,
    this.selectedCustomFields,
    this.weight,
    this.vendorLat,
    this.vendorLng,
    this.cartItemId,
    this.unitPrice,
    this.subtotalOverride,
    this.variantId,
    this.variantKey,
    this.variantAttributes,
    this.stockSnapshot,
    this.unitPriceLocked,
    String? currency,
    String? currencyCode,



  }) : super(


    id: id,
    name: name,
    image: image,
    price: price,
    finalPrice: finalPrice ?? price,
    user: user,
    categoryId: categoryId,
    currency: currency,
    currencyCode: currencyCode,
  );



  /// القسم/الإدارة التي ينتمي لها المنتج داخل السلة (تُستخدم للحماية من دمج الأقسام).
  final String section;

  int quantity;
  List<Map<String, dynamic>>? selectedCustomFields;

  /// وزن القطعة بالكيلو (اختياري)
  final double? weight;

  /// إحداثيات مزوّد/البائع (اختياري)
  final double? vendorLat;
  final double? vendorLng;



  /// المعرف الفعلي لسطر السلة داخل جدول cart_items.
  final int? cartItemId;

  /// السعر للوحدة كما هو مخزّن في pivot.
  final double? unitPrice;

  /// الإجمالي الفرعي المحسوب في الخادم (قبل الضريبة/الرسوم).
  final double? subtotalOverride;


  /// المعرف الداخلي للتنويعة كما يعيده الخادم (إن وجد).
  final String? variantId;

  /// المفتاح المحسوب للتنويعة (attr=value|...).
  final String? variantKey;

  /// السمات المحددة للتنويعة.
  final Map<String, dynamic>? variantAttributes;

  /// لقطة مخزون/سعر مخزنة محليًا.
  final Map<String, dynamic>? stockSnapshot;

  /// يحدد ما إذا كان سعر الوحدة مقفلًا بواسطة الخادم.
  final double? unitPriceLocked;


  /// السعر المعتمد للوحدة عند العرض (يراعي pivot أو سعر السلعة).
  double get unitPriceValue => unitPrice ?? price ?? 0.0;

  /// المجموع الفرعي النهائي للعنصر.
  double get subtotalAmount => subtotalOverride ?? unitPriceValue * quantity;



  /// مفتاح مستقر لتمييز سطور السلة (يُستخدم لتحديد العناصر بشكل فريد).
  String get selectionKey {
    final String baseId = cartItemId?.toString() ??
        id?.toString() ??
        hashCode.toString();
    final String? variantIdToken = variantId?.trim();
    final String? variantKeyToken = variantKey?.trim();
    final String variantToken = (variantIdToken != null && variantIdToken.isNotEmpty)
        ? variantIdToken
        : (variantKeyToken ?? '');
    final String attributesKey = _normalizedAttributesKey(variantAttributes);
    final String customFieldsKey =
    _normalizedCustomFieldsKey(selectedCustomFields);

    return '$baseId::$variantToken::$attributesKey::$customFieldsKey';
  }

  static String _normalizedAttributesKey(Map<String, dynamic>? attributes) {
    if (attributes == null || attributes.isEmpty) {
      return '';
    }
    final List<String> keys =
    attributes.keys.map((dynamic key) => key.toString()).toList()
      ..sort();
    final List<String> parts = <String>[];
    for (final String key in keys) {
      final dynamic value = attributes[key];
      parts.add('$key:$value');
    }
    return parts.join(';');
  }

  static String _normalizedCustomFieldsKey(List<Map<String, dynamic>>? fields) {
    if (fields == null || fields.isEmpty) {
      return '';
    }
    final List<String> parts = <String>[];
    for (final Map<String, dynamic> field in fields) {
      final List<String> fieldKeys =
      field.keys.map((dynamic key) => key.toString()).toList()
        ..sort();
      final List<String> entries = <String>[];
      for (final String key in fieldKeys) {
        final dynamic value = field[key];
        entries.add('$key:$value');
      }
      parts.add(entries.join('|'));
    }
    return parts.join(';');
  }




  /// إنشاء عنصر سلة مباشرة من [ItemModel] مع الحرص على التقاط القسم المناسب.
  factory Cart.fromItemModel(
      ItemModel item, {
        int quantity = 1,
        List<Map<String, dynamic>>? selectedCustomFields,
        double? weight,
        double? vendorLat,
        double? vendorLng,
        String? variantId,
        String? variantKey,
        Map<String, dynamic>? variantAttributes,
        Map<String, dynamic>? stockSnapshot,
        double? unitPrice,
        double? unitPriceLocked,
        String? currency,
      }) {
    if (item.id == null) {
      throw ArgumentError('ItemModel.id cannot be null when creating a cart item');
    }

    final resolvedSection = _resolveSectionSlug(
      item,
      explicitSection: item.departmentSlug ?? item.itemType,
    );


    String? _trimmed(String? value) {
      final String? trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    final double resolvedUnitPrice = unitPrice ?? item.finalPrice ?? item.price ?? 0;
    final double basePrice = item.price ?? resolvedUnitPrice;
    final double resolvedFinalPrice = item.finalPrice ?? resolvedUnitPrice;
    final String? explicitCurrency = _trimmed(currency);
    final String? resolvedCurrencyDisplay =
        explicitCurrency ?? _trimmed(item.currency);
    final String? resolvedCurrencyCode = CurrencyUtils.normalizeCurrencyCode(explicitCurrency) ??
        item.currencyCode ??
        CurrencyUtils.normalizeCurrencyCode(resolvedCurrencyDisplay);

    return Cart(
      id: item.id!,
      name: item.name ?? '',
      image: item.image ?? '',
      price: basePrice,
      finalPrice: resolvedFinalPrice,
      categoryId: item.categoryId ?? 0,
      user: item.user,
      quantity: quantity,
      selectedCustomFields: selectedCustomFields,
      weight: weight,
      vendorLat: vendorLat ?? item.latitude,
      vendorLng: vendorLng ?? item.longitude,
      section: resolvedSection,
      cartItemId: null,
      unitPrice: resolvedUnitPrice,
      subtotalOverride: resolvedUnitPrice * quantity,
      variantId: variantId,
      variantKey: variantKey,
      variantAttributes:
      variantAttributes != null ? Map<String, dynamic>.from(variantAttributes) : null,
      stockSnapshot:
      stockSnapshot != null ? Map<String, dynamic>.from(stockSnapshot) : null,
      unitPriceLocked: unitPriceLocked ?? resolvedUnitPrice,
      currency: resolvedCurrencyDisplay,
      currencyCode: resolvedCurrencyCode,
    );
  }


  /// إعادة بناء عنصر السلة من الـJSON الذي يعيده الخادم أو التخزين المحلي.
  factory Cart.fromJson(Map<String, dynamic> json) {
    final dynamic pivot = json['pivot'];
    final Map<String, dynamic>? pivotMap =
    pivot is Map<String, dynamic> ? Map<String, dynamic>.from(pivot) : null;

    final dynamic item = json['item'];
    final Map<String, dynamic>? itemMap =
    item is Map<String, dynamic> ? Map<String, dynamic>.from(item) : null;

    final Map<String, dynamic> baseSource =
    itemMap != null ? Map<String, dynamic>.from(itemMap) : <String, dynamic>{};

    void fillIfAbsent(String key, dynamic value) {
      if (value == null) return;
      if (key == 'pivot') return;
      if (key == 'id' && baseSource.containsKey('id') && baseSource['id'] != null) {
        return;
      }
      baseSource.putIfAbsent(key, () => value);


    }

    // تأكد من وجود المعرف الصحيح للعنصر.
    final dynamic itemIdCandidate = json['item_id'] ?? pivotMap?['item_id'];
    if (!baseSource.containsKey('id') || baseSource['id'] == null) {
      if (itemIdCandidate != null) {
        baseSource['id'] = itemIdCandidate;
      } else if (json['id'] != null) {
        baseSource['id'] = json['id'];
      }
    }

    json.forEach(fillIfAbsent);
    pivotMap?.forEach(fillIfAbsent);

    // عالج غياب السعر في العنصر الأساسي.
    baseSource.putIfAbsent('price', () =>
    pivotMap?['unit_price'] ?? json['unit_price'] ?? baseSource['unit_price']);

    final ItemModel base = ItemModel.fromJson(baseSource);



    User? resolvedUser = base.user;

    void mergeUser(dynamic raw) {
      final User? candidate = _parseUser(raw);
      if (candidate == null) return;
      if (resolvedUser == null) {
        resolvedUser = candidate;
        return;
      }

      bool _isBlank(String? value) => value == null || value.trim().isEmpty;

      if (_isBlank(resolvedUser!.name) && !_isBlank(candidate.name)) {
        resolvedUser!.name = candidate.name;
      }

      if (_isBlank(resolvedUser!.mobile) && !_isBlank(candidate.mobile)) {
        resolvedUser!.mobile = candidate.mobile;
      }

      if (_isBlank(resolvedUser!.email) && !_isBlank(candidate.email)) {
        resolvedUser!.email = candidate.email;
      }

      if (resolvedUser!.address == null && candidate.address != null) {
        resolvedUser!.address = candidate.address;
      }

      if (resolvedUser!.id == null && candidate.id != null) {
        resolvedUser!.id = candidate.id;
      }
    }

    mergeUser(json['seller']);
    mergeUser(json['vendor']);
    mergeUser(pivotMap?['seller']);
    mergeUser(pivotMap?['vendor']);
    mergeUser(itemMap?['seller']);
    mergeUser(itemMap?['vendor']);



    final int? itemId = _parseInt(json['item_id']) ??
        _parseInt(pivotMap?['item_id']) ??
        _parseInt(baseSource['item_id']) ??
        _parseInt(base.id);
    if (itemId == null) {



      throw ArgumentError('Cart JSON is missing the required `item_id`/`id` field.');
    }

    final int quantity = _parseInt(json['quantity']) ??
        _parseInt(json['qty']) ??
        _parseInt(pivotMap?['quantity']) ??
        0;

    final selectedFieldsRaw = json['selected_custom_fields'] ??
        pivotMap?['selected_custom_fields'];

    final double? weight =
        _parseDouble(json['weight']) ?? _parseDouble(pivotMap?['weight']);

    final double? vendorLat = _parseDouble(json['vendor_lat'] ?? json['vendor_latitude']) ??
        _parseDouble(pivotMap?['vendor_lat'] ?? pivotMap?['vendor_latitude']);




    final double? vendorLng = _parseDouble(json['vendor_lng'] ?? json['vendor_longitude']) ??
        _parseDouble(pivotMap?['vendor_lng'] ?? pivotMap?['vendor_longitude']);




    final sectionRaw = json['section'] ??
        json['department'] ??
        pivotMap?['section'] ??
        pivotMap?['department'];



    final resolvedSection = _resolveSectionSlug(
      base,
      explicitSection: sectionRaw is String ? sectionRaw : null,
    );

    final double? rawUnitPrice =
        _parseDouble(json['unit_price']) ?? _parseDouble(pivotMap?['unit_price']);
    final double? lockedUnitPrice =
    _parseDouble(json['unit_price_locked'] ?? pivotMap?['unit_price_locked']);
    final double? finalUnitPrice =
        _parseDouble(json['final_unit_price']) ?? lockedUnitPrice;
    final double resolvedUnitPrice = finalUnitPrice ?? rawUnitPrice ??
        base.finalPrice ?? base.price ?? 0.0;
    final double basePrice = base.price ?? resolvedUnitPrice;
    final double resolvedFinalPrice = base.finalPrice ?? resolvedUnitPrice;
    final double? subtotal =
        _parseDouble(json['subtotal']) ?? _parseDouble(pivotMap?['subtotal']);

    final String? variantId =
    _stringOrNull(json['variant_id'] ?? pivotMap?['variant_id']);
    String? variantKey =
    _stringOrNull(json['variant_key'] ?? pivotMap?['variant_key']);

    if (variantKey != null && variantKey.trim().isNotEmpty) {
      final String normalized = VariantKeyCodec.canonicalize(variantKey);
      variantKey = normalized.isEmpty ? null : normalized;
    } else {
      variantKey = null;
    }


    final Map<String, dynamic>? variantAttributes = _parseJsonMap(
      json['variant_attributes'] ??
          pivotMap?['variant_attributes'] ??
          json['attributes'] ??
          pivotMap?['attributes'],
    );
    final Map<String, dynamic>? stockSnapshot =
    _parseJsonMap(json['stock_snapshot'] ?? pivotMap?['stock_snapshot']);


    CurrencyParseResult currencyInfo = const CurrencyParseResult();

    void absorbCurrency(Map<String, dynamic>? source) {
      if (source == null || source.isEmpty) {
        return;
      }
      currencyInfo = currencyInfo.mergePreferNew(CurrencyUtils.parseCurrency(source));
    }

    absorbCurrency(baseSource);
    absorbCurrency(pivotMap);
    absorbCurrency(json);

    final String? currencyDisplay =
    (currencyInfo.display ?? base.currency)?.trim();
    final String? currencyCode = currencyInfo.code ??
        base.currencyCode ??
        CurrencyUtils.normalizeCurrencyCode(currencyDisplay);

    return Cart(
      id: itemId,
      name: base.name ?? '',
      image: base.image ?? '',
      price: basePrice,
      finalPrice: resolvedFinalPrice,
      categoryId: base.categoryId ?? _parseInt(json['category_id']) ?? 0,
      user: resolvedUser,


      quantity: quantity,
      selectedCustomFields: _parseSelectedCustomFields(selectedFieldsRaw),
      weight: weight,
      vendorLat: vendorLat ?? base.latitude,
      vendorLng: vendorLng ?? base.longitude,
      section: resolvedSection,
      cartItemId:
      _parseInt(json['cart_item_id']) ?? _parseInt(pivotMap?['id']) ?? _parseInt(json['id']),
      unitPrice: finalUnitPrice ?? lockedUnitPrice ?? rawUnitPrice ?? resolvedUnitPrice,
      subtotalOverride: subtotal ?? resolvedUnitPrice * quantity,
      variantId: variantId,
      variantKey: variantKey,
      variantAttributes: variantAttributes,
      stockSnapshot: stockSnapshot,
      unitPriceLocked: lockedUnitPrice ?? finalUnitPrice,
      currency: currencyDisplay?.isEmpty == true ? null : currencyDisplay,
      currencyCode: currencyCode,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = super.toJson();
    data['quantity'] = quantity;
    if (selectedCustomFields != null) {
      data['selected_custom_fields'] = selectedCustomFields!
          .map((field) => Map<String, dynamic>.from(field))
          .toList();
    }
    if (weight != null) {
      data['weight'] = weight;
    }
    if (vendorLat != null) {
      data['vendor_lat'] = vendorLat;
    }
    if (vendorLng != null) {
      data['vendor_lng'] = vendorLng;
    }
    data['section'] = section;
    data['item_id'] = id;
    if (cartItemId != null) {
      data['cart_item_id'] = cartItemId;
    }

    if (variantId != null) {
      data['variant_id'] = variantId;
    }
    if (variantKey != null && variantKey!.trim().isNotEmpty) {
      data['variant_key'] = variantKey;
    }
    if (variantAttributes != null && variantAttributes!.isNotEmpty) {
      data['variant_attributes'] = Map<String, dynamic>.from(variantAttributes!);
    }
    if (stockSnapshot != null && stockSnapshot!.isNotEmpty) {
      data['stock_snapshot'] = Map<String, dynamic>.from(stockSnapshot!);
    }

    data['unit_price'] = unitPriceValue;
    if (unitPriceLocked != null) {
      data['unit_price_locked'] = unitPriceLocked;
    }
    data['subtotal'] = subtotalAmount;

    return data;
  }






  static String _resolveSectionSlug(ItemModel item, {String? explicitSection}) {
    final List<String?> rawCandidates = <String?>[
      explicitSection,
      item.departmentSlug,
      item.itemType,
      item.type,
      item.category?.description,
      item.category?.name,
    ];

    for (final String? candidate in rawCandidates) {
      final String? normalized = normalizeDeliveryDepartment(candidate);
      if (normalized != null) {
        return normalized;
      }
    }



    final Set<int> categoryIds = _collectCategoryIds(
      item,
      additionalSources: rawCandidates,
    );

    final String? departmentFromIds =
    resolveDeliveryDepartmentFromCategoryIds(categoryIds);
    if (departmentFromIds != null) {
      return departmentFromIds;
    }

    for (final String? candidate in rawCandidates) {
      final String? sanitized = _normalizeSection(candidate);
      if (sanitized != null) {
        final String? normalized = normalizeDeliveryDepartment(sanitized);
        return normalized ?? sanitized;
      }
    }

    if (categoryIds.isNotEmpty) {
      final int fallbackId = categoryIds.first;
      final String? normalized =
      resolveDeliveryDepartmentFromCategoryIds(<int>[fallbackId]);
      if (normalized != null) {
        return normalized;
      }
      return 'category-$fallbackId';

    }

    return 'general';
  }

  static Set<int> _collectCategoryIds(ItemModel item,
      {Iterable<String?> additionalSources = const <String?>[]}) {
    final Set<int> ids = <int>{};

    void add(dynamic value) {
      final int? parsed = _parseInt(value);
      if (parsed != null) {
        ids.add(parsed);
      }
    }

    add(item.categoryId);
    add(item.category?.id);

    final String? allCategoryIds = item.allCategoryIds;
    if (allCategoryIds != null && allCategoryIds.trim().isNotEmpty) {
      for (final int id in _extractIntegers(allCategoryIds)) {
        ids.add(id);
      }
    }

    for (final String? source in additionalSources) {
      if (source == null) continue;
      for (final int id in _extractIntegers(source)) {
        ids.add(id);
      }
    }

    return ids;
  }

  static Iterable<int> _extractIntegers(String raw) sync* {
    for (final Match match in RegExp(r'\d+').allMatches(raw)) {
      final int? value = int.tryParse(match.group(0)!);
      if (value != null) {
        yield value;
      }
    }
  }


  static String? _normalizeSection(String? raw) {
    if (raw == null) return null;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final String lower = trimmed.toLowerCase();
    final String collapsedWhitespace = lower.replaceAll(RegExp(r'\s+'), '-');
    final String sanitized =
    collapsedWhitespace.replaceAll(RegExp(r'[^a-z0-9_\-]'), '');


    return sanitized.isEmpty ? lower : sanitized;
  }


  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', ''));
    }
    return null;
  }

  static User? _parseUser(dynamic raw) {
    if (raw == null) return null;
    if (raw is User) return raw;
    if (raw is Map) {
      final Map<String, dynamic> normalised = _normaliseUserMap(raw);
      if (normalised.isEmpty) return null;
      return User.fromJson(normalised);
    }
    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      return User(name: trimmed);
    }
    return null;
  }


  static Map<String, dynamic> _normaliseUserMap(Map<dynamic, dynamic> raw) {
    final Map<String, dynamic> result = <String, dynamic>{};

    raw.forEach((dynamic key, dynamic value) {
      if (key == null) return;
      result[key is String ? key : key.toString()] = value;
    });

    void assignIfMissing(
        String canonical, List<String> aliases, String? Function(dynamic) pick) {
      if (_hasMeaningfulUserValue(result[canonical])) return;
      for (final String alias in aliases) {
        if (!_hasMeaningfulUserValue(result[alias])) continue;
        final String? value = pick(result[alias]);
        if (value != null) {
          result[canonical] = value;
          break;
        }
      }
    }

    void assignDynamicIfMissing(
        String canonical, List<String> aliases, dynamic Function(dynamic) pick) {
      if (_hasMeaningfulUserValue(result[canonical])) return;
      for (final String alias in aliases) {
        if (!_hasMeaningfulUserValue(result[alias])) continue;
        final dynamic value = pick(result[alias]);
        if (_hasMeaningfulUserValue(value)) {
          result[canonical] = value;
          break;
        }
      }
    }

    assignIfMissing('name', <String>[
      'seller_name',
      'sellerName',
      'vendor_name',
      'vendorName',
      'store_name',
      'shop_name',
      'business_name',
      'company_name',
      'full_name',
      'fullName',
      'display_name',
      'displayName',
      'contact_name',
      'contactName',
      'representative_name',
      'representativeName',

      'username',
      'seller',
      'vendor',
    ], _stringOrNull);

    assignIfMissing('mobile', <String>[
      'seller_mobile',
      'sellerMobile',
      'seller_phone',
      'sellerPhone',
      'vendor_phone',
      'vendor_mobile',
      'phone',
      'phone_number',
      'phoneNumber',
      'mobile_number',
      'mobileNumber',
      'phone_primary',
      'phonePrimary',
      'primary_phone',
      'primaryPhone',
      'mobile_phone',
      'mobilePhone',
      'contact',
      'contact_number',
      'contactNumber',
      'contact_phone',
      'contactPhone',
      'whatsapp',
      'whatsapp_number',
      'whatsappNumber',
      'telephone',
      'tel',
    ], _stringOrNull);

    assignIfMissing('email', <String>[
      'seller_email',
      'sellerEmail',
      'contact_email',
      'contactEmail',
      'vendor_email',
      'vendorEmail',
      'email_address',
      'emailAddress',
    ], _stringOrNull);

    assignDynamicIfMissing('address', <String>[
      'seller_address',
      'sellerAddress',
      'vendor_address',
      'vendorAddress',
      'location',
      'address',
      'address_line',
      'addressLine',
      'address1',
      'address_1',
      'address_line_1',
      'addressLine1',
      'address_line1',
      'address_line_2',
      'addressLine2',
      'address2',
      'street',
      'street_address',
      'streetAddress',
      'full_address',
      'fullAddress',
      'city',
      'area',
      'neighbourhood',

    ], _normaliseAddressValue);

    if (!_hasMeaningfulUserValue(result['id'])) {
      for (final String alias in <String>[
        'seller_id',
        'sellerId',
        'vendor_id',
        'vendorId',
        'user_id',
        'userId',
      ]) {
        final dynamic value = result[alias];
        if (_hasMeaningfulUserValue(value)) {
          result['id'] = value;
          break;
        }
      }
    }

    result.removeWhere((String key, dynamic value) {
      if (value == null) return true;
      if (value is String) {
        return value.trim().isEmpty;
      }
      return false;
    });

    return result;
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return trimmed;
    }
    final String converted = value.toString();
    return converted.trim().isEmpty ? null : converted;
  }

  static dynamic _normaliseAddressValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value;
  }

  static bool _hasMeaningfulUserValue(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    return true;
  }


  static List<Map<String, dynamic>>? _parseSelectedCustomFields(dynamic raw) {
    if (raw == null) return null;

    dynamic decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
    }

    if (decoded is Map) {
      return <Map<String, dynamic>>[Map<String, dynamic>.from(decoded)];
    }

    return null;
  }
  static Map<String, dynamic>? _parseJsonMap(dynamic raw) {
    if (raw == null) return null;

    dynamic decoded = raw;
    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    }

    if (decoded is Map<String, dynamic>) {
      return Map<String, dynamic>.from(decoded);
    }

    if (decoded is Map) {
      final Map<String, dynamic> result = <String, dynamic>{};
      decoded.forEach((dynamic key, dynamic value) {
        if (key == null) return;
        result[key is String ? key : key.toString()] = value;
      });
      return result;
    }

    return null;
  }

}
