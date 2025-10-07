// lib/data/model/classified_model.dart

// lib/data/model/classified_model.dart
import 'dart:convert';

// lib/data/model/classified_model.dart
import 'dart:convert';

class ClassifiedModel {
  // ===== الأساسية =====
  int? id;
  int? userId;
  String? title;
  String? slug;
  String? description;
  String? image;
  String? icon;
  List<String>? tags;
  int? views;
  int? categoryId;
  bool? isMain;
  bool? status;
  String? serviceType;
  String? expiryDate;
  String? createdAt;
  String? updatedAt;

  // ===== زر المتابعة / الدفع =====
  bool? isPaid;
  double? price;
  String? currency;
  String? priceNote;
  String? payUrl; // رابط دفع خارجي اختياري

  // ===== توجيه/حقول مخصّصة =====
  bool? hasCustomFields;
  bool? directToUser;
  int? directUserId;

  String? serviceUid;

  // ===== تقييم =====
  double? rating;
  int? totalRatings;

  // ===== سكيمة الحقول (كما ترجع من الخادم) =====
  List<Map<String, dynamic>>? serviceFieldsSchema;

  ClassifiedModel({
    this.id,
    this.userId,
    this.title,
    this.slug,
    this.description,
    this.image,
    this.icon,
    this.tags,
    this.views,
    this.categoryId,
    this.isMain,
    this.status,
    this.serviceType,
    this.expiryDate,
    this.createdAt,
    this.updatedAt,
    this.isPaid,
    this.price,
    this.currency,
    this.priceNote,
    this.payUrl,
    this.hasCustomFields,
    this.directToUser,
    this.directUserId,
    this.serviceUid,
    this.rating,
    this.totalRatings,
    this.serviceFieldsSchema,
  });

  // ================= Helpers =================
  T? _pick<T>(Map<String, dynamic> json, List keys) {
    for (final k in keys) {
      if (json.containsKey(k) && json[k] != null) return json[k] as T?;
    }
    return null;
  }

  bool? _asBool(dynamic v, {bool? defaultValue}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s.isEmpty) return defaultValue;
      return s == '1' || s == 'true' || s == 'yes';
    }
    return defaultValue;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  List<String>? _asStringList(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      return v.map((e) => _asString(e) ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return null;
  }

  // ----- سكيمة -----
  dynamic _jsonOrSelf(dynamic v) {
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty || s == '[]' || s == '{}') return null;
      try {
        return jsonDecode(s);
      } catch (_) {
        return null;
      }
    }
    return v;
  }

  List<Map<String, dynamic>> _listToMapList(List src) {
    final out = <Map<String, dynamic>>[];
    for (final e in src) {
      if (e is Map) out.add(Map<String, dynamic>.from(e as Map));
    }
    return out;
  }

  bool _looksLikeFieldMap(Map m) {
    final keys = m.keys.map((e) => e.toString().toLowerCase()).toSet();
    return keys.contains('type') ||
        keys.contains('title') ||
        keys.contains('label') ||
        keys.contains('name') ||
        keys.contains('field_type') ||
        keys.contains('input_type');
  }

  List<Map<String, dynamic>>? _extractSchema(dynamic raw) {
    if (raw == null) return null;

    final decoded = _jsonOrSelf(raw) ?? raw;

    if (decoded is List) {
      final list = _listToMapList(decoded);
      return list.isEmpty ? null : _normalizeSchema(list);
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded as Map);

      const keys = <String>[
        'service_fields_schema',
        'serviceFieldsSchema',
        'service_fields',
        'custom_fields_schema',
        'customFieldsSchema',
        'custom_fields',
        'fields_schema',
        'fields',
        'schema',
        'data',
        'item',
        'payload',
        'record',
        'result',
      ];

      for (final k in keys) {
        if (map.containsKey(k) && map[k] != null) {
          final cand = _extractSchema(map[k]);
          if (cand != null && cand.isNotEmpty) return cand;
        }
      }

      if (_looksLikeFieldMap(map)) return _normalizeSchema([map]);

      for (final v in map.values) {
        final cand = _extractSchema(v);
        if (cand != null && cand.isNotEmpty) return cand;
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _normalizeSchema(List<Map<String, dynamic>> list) {
    final out = <Map<String, dynamic>>[];
    for (final m0 in list) {
      final m = Map<String, dynamic>.from(m0);

      // type ↓
      final rawType = _asString(m['type'] ?? m['field_type'] ?? m['input_type']) ?? 'textbox';
      m['type'] = rawType.toLowerCase(); // نحافظ على الأنواع الـ 7 المعتمدة

      // label/title/name ↓
      m['label'] = _asString(m['label'] ?? m['title'] ?? m['name']) ?? '';

      // required ↓
      m['required'] = _asBool(m['required'] ?? m['is_required'] ?? m['mandatory'] ?? m['req'], defaultValue: false) ?? false;

      // options/values ↓ (نسمح بالنص المفصول بـ | أو List)
      if (m['options'] == null && m['values'] != null) {
        m['options'] = m['values'];
      }
      if (m['options'] is String) {
        final s = (m['options'] as String).trim();
        m['options'] = s.isEmpty ? '' : s;
      } else if (m['options'] is List) {
        final arr = (m['options'] as List)
            .map((e) => _asString(e) ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
        m['options'] = arr.isEmpty ? '' : arr.join('|'); // نعيدها كنص مفصول |
      }

      // min/max (اختياريان)
      if (m['min'] != null && m['min'] is String) m['min'] = int.tryParse(m['min']);
      if (m['max'] != null && m['max'] is String) m['max'] = int.tryParse(m['max']);

      // order/sequence ↓
      final order = m['order'] ?? m['sequence'] ?? m['sort_order'] ?? 0;
      m['order'] = (order is num) ? order.toInt() : int.tryParse('$order') ?? 0;

      // notes/is_customer_option/color_values (إن وُجدت)
      if (m.containsKey('is_customer_option')) {
        m['is_customer_option'] = _asBool(m['is_customer_option'], defaultValue: false) ?? false;
      }
      if (m['color_values'] != null && m['color_values'] is List) {
        m['color_values'] = (m['color_values'] as List)
            .map((e) => _asString(e)?.replaceAll('#', '').toUpperCase())
            .whereType<String>()
            .where((s) => s.length == 6)
            .toList();
      }

      out.add(m);
    }
    // ترتيب حسب order
    out.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    return out;
  }

  // ================= fromJson =================
  ClassifiedModel.fromJson(Map<String, dynamic> json) {
    // الأساسية
    id          = _asInt(json['id']);
    userId      = _asInt(_pick(json, ['user_id','userId']));
    categoryId  = _asInt(_pick(json, ['category_id','categoryId']));
    title       = _asString(_pick(json, ['title','name']));
    slug        = _asString(json['slug']);
    description = _asString(_pick(json, ['description','desc','details']));

    image       = _asString(_pick(json, ['image','image_url','thumbnail','thumb']));
    icon        = _asString(_pick(json, ['icon','icon_url']));

    tags        = _asStringList(json['tags']);

    status      = _asBool(json['status']);
    isMain      = _asBool(_pick(json, ['is_main','isMain']));
    serviceType = _asString(_pick(json, ['service_type','serviceType']));

    views       = _asInt(json['views']);
    expiryDate  = _asString(_pick(json, ['expiry_date','expiryDate']));

    createdAt   = _asString(_pick(json, ['created_at','createdAt']));
    updatedAt   = _asString(_pick(json, ['updated_at','updatedAt']));

    // تقييم
    rating        = _asDouble(_pick(json, ['rating','avg_rating']));
    totalRatings  = _asInt(_pick(json, ['total_ratings','totalRatings']));

    // الدفع
    isPaid    = _asBool(_pick(json, ['is_paid','paid']), defaultValue: false);
    price     = _asDouble(_pick(json, ['price','amount']));
    currency  = _asString(_pick(json, ['currency','currency_code']));
    priceNote = _asString(_pick(json, ['price_note','payment_note','note']));
    payUrl    = _asString(_pick(json, ['pay_url','payment_url','url','link']));

    // منطق المتابعة
    hasCustomFields = _asBool(_pick(json, ['has_custom_fields','hasCustomFields']), defaultValue: false);
    directToUser    = _asBool(_pick(json, ['direct_to_user','directToUser']), defaultValue: false);
    directUserId    = _asInt(_pick(json, ['direct_user_id','directUserId']));

    serviceUid      = _asString(_pick(json, ['service_uid','uid']));

    // السكيمة (مرن جدًا + تطبيع)
    serviceFieldsSchema = _extractSchema(
      _pick(json, [
        'service_fields_schema',
        'serviceFieldsSchema',
        'service_fields',
        'custom_fields_schema',
        'customFieldsSchema',
        'custom_fields',
        'fields_schema',
        'fields',
        'schema',
        'data',
        'item',
        'payload',
        'record',
        'result',
      ]) ?? json,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    // الأساسية
    data['id'] = id;
    data['user_id'] = userId;
    data['title'] = title;
    data['slug'] = slug;
    data['description'] = description;
    data['image'] = image;
    data['icon'] = icon;
    data['tags'] = tags;
    data['views'] = views;
    data['category_id'] = categoryId;
    data['is_main'] = isMain;
    data['status'] = status;
    data['service_type'] = serviceType;
    data['expiry_date'] = expiryDate;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;

    // تقييم
    data['rating'] = rating;
    data['total_ratings'] = totalRatings;

    // الدفع
    data['is_paid'] = isPaid;
    data['price'] = price;
    data['currency'] = currency;
    data['price_note'] = priceNote;
    data['pay_url'] = payUrl;

    // المتابعة
    data['has_custom_fields'] = hasCustomFields;
    data['direct_to_user'] = directToUser;
    data['direct_user_id'] = directUserId;

    data['service_uid'] = serviceUid;

    // السكيمة
    data['service_fields_schema'] = serviceFieldsSchema;

    return data;
  }
}




/// نسخة خفيفة للقائمة (List/Grid) — تشمل الحقول اللازمة للعرض السريع.
class ClassifiedSummary {
  final int id;
  final String? title;
  final String? image;
  final bool isMain;
  final bool status;
  final double? rating;
  final int? totalRatings;
  final int? categoryId;

  const ClassifiedSummary({
    required this.id,
    this.title,
    this.image,
    this.isMain = false,
    this.status = true,
    this.rating,
    this.totalRatings,
    this.categoryId,
  });

  factory ClassifiedSummary.fromJson(Map<String, dynamic> json) {
    int? _asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    double? _asDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    String? _asString(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    bool _asBool(dynamic v, {bool defaultValue = false}) {
      if (v == null) return defaultValue;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase().trim();
        if (s == 'true' || s == '1' || s == 'yes') return true;
        if (s == 'false' || s == '0' || s == 'no') return false;
      }
      return defaultValue;
    }

    String? _pickImage(Map<String, dynamic> j) {
      final direct = j['image'] ??
          j['image_url'] ??
          j['title_image'] ??
          j['icon'] ??
          j['logo'] ??
          j['photo'] ??
          j['thumbnail'] ??
          j['thumb'];
      if (direct is String && direct.trim().isNotEmpty) return direct;

      final imgs = j['images'];
      if (imgs is List && imgs.isNotEmpty) {
        final first = imgs.first;
        if (first is String && first.trim().isNotEmpty) return first;
        if (first is Map && first['url'] is String && (first['url'] as String).trim().isNotEmpty) {
          return first['url'] as String;
        }
      }
      return null;
    }

    final int id = _asInt(json['id']) ??
        _asInt(json['item_id']) ??
        _asInt(json['items_id']) ??
        _asInt(json['service_id']) ??
        _asInt(json['id_item']) ??
        0;

    return ClassifiedSummary(
      id: id,
      title: _asString(json['title']) ??
          _asString(json['name']) ??
          _asString(json['service_title']) ??
          _asString(json['service_name']),

      image: _pickImage(json),
      isMain: _asBool(json['is_main']) || _asBool(json['isMain']),
      status: _asBool(json['status'], defaultValue: true),
      rating: _asDouble(json['rating']) ?? _asDouble(json['avg_rating']),
      totalRatings: _asInt(json['total_ratings']) ?? _asInt(json['ratings_count']),
      categoryId: _asInt(json['category_id']) ?? _asInt(json['cat_id']) ?? _asInt(json['categoryId']),
    );
  }
}

/// محوّلات بين النسختين
extension ClassifiedMappers on ClassifiedModel {
  /// تحويل النسخة الكاملة إلى خفيفة (للقائمة)
  ClassifiedSummary toSummary() => ClassifiedSummary(
    id: id ?? 0,
    title: title,
    image: image ?? icon,
    isMain: isMain ?? false,
    status: status ?? true,
    rating: rating,
    totalRatings: totalRatings,
    categoryId: categoryId,
  );

  /// دمج البيانات الخفيفة في نسخة كاملة موجودة (بدون فقدان تفاصيل)
  ClassifiedModel mergeSummary(ClassifiedSummary s) {
    return ClassifiedModel(
      id: id ?? s.id,
      title: title ?? s.title,
      slug: slug,
      description: description,
      image: image ?? s.image,
      icon: icon ?? s.image, // كـ fallback
      tags: tags,
      views: views,
      categoryId: categoryId ?? s.categoryId,
      isMain: isMain ?? s.isMain,
      status: status ?? s.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      rating: rating ?? s.rating,
      totalRatings: totalRatings ?? s.totalRatings,
    );
  }
}

extension ClassifiedSummaryX on ClassifiedSummary {
  /// تحويل النسخة الخفيفة إلى نسخة كاملة مبدئية (تُستخدم كـ placeholder)
  ClassifiedModel toFullSkeleton() => ClassifiedModel(
    id: id,
    title: title,
    image: image,
    icon: image,
    isMain: isMain,
    status: status,
    rating: rating,
    totalRatings: totalRatings,
    categoryId: categoryId,
  );
}
