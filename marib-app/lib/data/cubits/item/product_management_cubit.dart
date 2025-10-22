import 'dart:collection';
import 'dart:math' as math;
import 'package:marib/data/model/custom_field/custom_field_model.dart';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/data/repositories/item/item_purchase_options_repository.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/variant_key.dart';

const List<String> _defaultSizeCatalog = <String>[
  'XS',
  'S',
  'M',
  'L',
  'XL',
  'XXL',
  '3XL',
  '4XL',
  '5XL',
  '6XL',
  '28',
  '30',
  '32',
  '34',
  '36',
  '38',
  '40',
  '42',
  '44',
  '46',
  '48',
  '50',
  '52',
  '54',
  '56',
  'Free Size',
];

class SubmissionOutcome {
  const SubmissionOutcome({required this.success, required this.message});

  final bool success;
  final String message;
}

ManagedAttributeType _resolveManagedAttributeType(
  ItemPurchaseAttributeOption attribute,
) {
  final String? type = attribute.type?.toLowerCase();
  final String? uiType = attribute.uiType?.toLowerCase();
  if (type == 'color' || uiType == 'color') {
    return ManagedAttributeType.color;
  }

  if (type == 'size' || uiType == 'size') {
    return ManagedAttributeType.size;
  }

  final String normalizedName = attribute.name.toLowerCase();
  if (normalizedName.contains('مقاس') || normalizedName.contains('size')) {
    return ManagedAttributeType.size;
  }

  return ManagedAttributeType.custom;
}

String _defaultAttributeName(ManagedAttributeType type) {
  switch (type) {
    case ManagedAttributeType.color:
      return 'اللون';
    case ManagedAttributeType.size:
      return 'المقاس';
    case ManagedAttributeType.custom:
      return 'سمة المنتج';
  }
}

List<String> _normalizeOptionValues(List<String> values) {
  final LinkedHashSet<String> normalized = LinkedHashSet<String>();
  for (final String value in values) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    normalized.add(trimmed);
  }
  return normalized.toList(growable: false);
}

List<CustomFieldColorEntry> _normalizeColorEntries(
  List<CustomFieldColorEntry> entries,
) {
  final LinkedHashMap<String, CustomFieldColorEntry> normalized =
      LinkedHashMap<String, CustomFieldColorEntry>();
  for (final CustomFieldColorEntry entry in entries) {
    final String code = entry.code.toUpperCase();
    final int? quantity = entry.quantity;
    if (normalized.containsKey(code) && quantity == null) {
      continue;
    }
    normalized[code] = CustomFieldColorEntry(code: code, quantity: quantity);
  }
  return normalized.values.toList(growable: false);
}

double? _normalizeDeliverySize(dynamic value) {
  if (value == null) {
    return null;
  }

  double? parsed;

  if (value is num) {
    parsed = value.toDouble();
  } else if (value is String) {
    final String normalized = value.replaceAll(',', '.').trim();
    if (normalized.isEmpty) {
      return null;
    }
    parsed = double.tryParse(normalized);
  }

  if (parsed == null || parsed <= 0) {
    return null;
  }

  return double.parse(parsed.toStringAsFixed(3));
}

String _formatDeliverySizeInput(double value) {
  String formatted = value.toStringAsFixed(3);
  if (formatted.contains('.')) {
    formatted = formatted.replaceFirst(RegExp(r'0+$'), '');
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
  }
  return formatted;
}

ManagedPurchaseAttribute _createManagedAttribute(
  ItemPurchaseAttributeOption option,
) {
  final ManagedAttributeType type = _resolveManagedAttributeType(option);
  final String name =
      option.name.isEmpty ? _defaultAttributeName(type) : option.name;
  final Map<String, dynamic> metadata =
      Map<String, dynamic>.from(option.metadata ?? const <String, dynamic>{});

  List<CustomFieldColorEntry> colorEntries = const <CustomFieldColorEntry>[];
  List<String> options = const <String>[];

  if (type == ManagedAttributeType.color) {
    colorEntries = _normalizeColorEntries(option.colorEntries);
    if (colorEntries.isEmpty && option.allowedValues.isNotEmpty) {
      colorEntries = _normalizeColorEntries(
        option.allowedValues
            .map((String value) => CustomFieldColorEntry(code: value))
            .toList(growable: false),
      );
    }
  } else {
    final List<String> source =
        option.allowedValues.isNotEmpty ? option.allowedValues : option.values;
    options = _normalizeOptionValues(source);
  }

  return ManagedPurchaseAttribute(
    id: option.id == 0 ? null : option.id,
    key: option.key,
    name: name,
    type: type,
    requiredForCheckout: option.requiredForCheckout,
    affectsStock: option.affectsStock,
    colorEntries: colorEntries,
    options: options,
    metadata: metadata,
    position: option.position,
  );
}

List<ManagedPurchaseAttribute> _withReindexedPositions(
  List<ManagedPurchaseAttribute> attributes,
) {
  final List<ManagedPurchaseAttribute> result = <ManagedPurchaseAttribute>[];
  for (int index = 0; index < attributes.length; index++) {
    result.add(attributes[index].copyWith(position: index));
  }
  return result;
}

List<String> _sortedSelectionsFromOptions(List<String> options) {
  final List<String> sorted = List<String>.from(options)
    ..removeWhere((String value) => value.trim().isEmpty)
    ..sort();
  return sorted;
}

enum ManagedAttributeType { color, size, custom }

class ManagedPurchaseAttribute extends Equatable {
  const ManagedPurchaseAttribute({
    this.id,
    required this.key,
    required this.name,
    required this.type,
    required this.requiredForCheckout,
    required this.affectsStock,
    this.colorEntries = const <CustomFieldColorEntry>[],
    this.options = const <String>[],
    this.metadata = const <String, dynamic>{},
    this.position,
  });

  final int? id;
  final String key;
  final String name;
  final ManagedAttributeType type;
  final bool requiredForCheckout;
  final bool affectsStock;
  final List<CustomFieldColorEntry> colorEntries;
  final List<String> options;
  final Map<String, dynamic> metadata;
  final int? position;

  ManagedPurchaseAttribute copyWith({
    int? id,
    String? key,
    String? name,
    ManagedAttributeType? type,
    bool? requiredForCheckout,
    bool? affectsStock,
    List<CustomFieldColorEntry>? colorEntries,
    List<String>? options,
    Map<String, dynamic>? metadata,
    bool mergeMetadata = false,
    int? position,
  }) {
    final Map<String, dynamic> nextMetadata = mergeMetadata
        ? <String, dynamic>{...this.metadata, ...?metadata}
        : (metadata ?? this.metadata);

    return ManagedPurchaseAttribute(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      type: type ?? this.type,
      requiredForCheckout: requiredForCheckout ?? this.requiredForCheckout,
      affectsStock: affectsStock ?? this.affectsStock,
      colorEntries: colorEntries ?? this.colorEntries,
      options: options ?? this.options,
      metadata: nextMetadata,
      position: position ?? this.position,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        key,
        name,
        type,
        requiredForCheckout,
        affectsStock,
        colorEntries
            .map((CustomFieldColorEntry entry) =>
                '${entry.code}:${entry.quantity ?? ''}')
            .join('|'),
        options.join('|'),
        metadata.entries
            .map((MapEntry<String, dynamic> entry) =>
                '${entry.key}:${entry.value}')
            .join('|'),
        position,
      ];
}

class VariantStockFormState extends Equatable {
  const VariantStockFormState({
    required this.variantKey,
    required this.attributes,
    required this.stock,
    required this.hidden,
    this.lastVisibleStock,
  });

  final String variantKey;
  final Map<String, String> attributes;
  final int stock;
  final bool hidden;
  final int? lastVisibleStock;

  VariantStockFormState copyWith({
    int? stock,
    bool? hidden,
    int? lastVisibleStock,
    bool resetLastVisibleStock = false,
  }) {
    return VariantStockFormState(
      variantKey: variantKey,
      attributes: attributes,
      stock: stock ?? this.stock,
      hidden: hidden ?? this.hidden,
      lastVisibleStock: resetLastVisibleStock
          ? null
          : (lastVisibleStock ?? this.lastVisibleStock),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        variantKey,
        attributes.entries
            .map((MapEntry<String, String> entry) =>
                '${entry.key}:${entry.value}')
            .join('|'),
        stock,
        hidden,
        lastVisibleStock,
      ];
}

class ProductManagementState extends Equatable {
  const ProductManagementState({
    required this.item,
    required this.loading,
    required this.error,
    required this.options,
    required this.managedAttributes,
    required this.attributeSelections,
    required this.colorSelections,
    required this.textInputs,
    required this.attributesSaving,
    required this.stockSaving,
    required this.discountSaving,
    required this.variantForms,
    required this.deliverySize,
    required this.deliverySizeInput,
    required this.deliverySizeError,
    required this.hasStockVariants,
    required this.generalStock,
    required this.discountEnabled,
    required this.discountType,
    required this.discountValue,
    required this.discountStart,
    required this.discountEnd,
    required this.basePrice,
    required this.previewFinalPrice,
    required this.lastKnownFinalPrice,
  });

  factory ProductManagementState.initial(ItemModel item) {
    return ProductManagementState(
      item: item,
      loading: true,
      error: null,
      options: null,
      managedAttributes: const <ManagedPurchaseAttribute>[],
      attributeSelections: const <String, List<String>>{},
      textInputs: const <String, String>{},
      attributesSaving: false,
      colorSelections: const <String, List<CustomFieldColorEntry>>{},
      stockSaving: false,
      discountSaving: false,
      variantForms: const <String, VariantStockFormState>{},
      hasStockVariants: false,
      deliverySize: null,
      deliverySizeInput: '',
      deliverySizeError: null,
      generalStock: 0,
      discountEnabled: false,
      discountType: 'percent',
      discountValue: null,
      discountStart: null,
      discountEnd: null,
      basePrice: (item.price ?? 0).toDouble(),
      previewFinalPrice: (item.price ?? 0).toDouble(),
      lastKnownFinalPrice: (item.price ?? 0).toDouble(),
    );
  }

  final ItemModel item;
  final bool loading;
  final String? error;
  final ItemPurchaseOptions? options;
  final List<ManagedPurchaseAttribute> managedAttributes;
  final Map<String, List<String>> attributeSelections;
  final Map<String, String> textInputs;
  final bool attributesSaving;
  final bool stockSaving;
  final Map<String, List<CustomFieldColorEntry>> colorSelections;
  final bool discountSaving;
  final Map<String, VariantStockFormState> variantForms;
  final bool hasStockVariants;
  final int? generalStock;
  final bool discountEnabled;
  final String discountType;
  final double? discountValue;
  final DateTime? discountStart;
  final DateTime? discountEnd;
  final double basePrice;
  final double previewFinalPrice;
  final double lastKnownFinalPrice;
  final double? deliverySize;
  final String deliverySizeInput;
  final String? deliverySizeError;

  bool get hasLoaded => options != null;

  bool get isCombinationReady {
    if (!hasStockVariants) {
      return true;
    }

    if (managedAttributes.isEmpty) {
      return false;
    }

    for (final ManagedPurchaseAttribute attribute in managedAttributes) {
      if (!attribute.affectsStock) {
        continue;
      }
      if (attribute.type == ManagedAttributeType.color) {
        final List<CustomFieldColorEntry> entries =
            colorSelections[attribute.key] ?? attribute.colorEntries;
        if (entries.isEmpty) {
          return false;
        }
      } else {
        final List<String> selected =
            attributeSelections[attribute.key] ?? attribute.options;
        if (selected.isEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  ProductManagementState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    ItemPurchaseOptions? options,
    List<ManagedPurchaseAttribute>? managedAttributes,
    Map<String, List<String>>? attributeSelections,
    Map<String, String>? textInputs,
    bool? attributesSaving,
    bool? stockSaving,
    Map<String, List<CustomFieldColorEntry>>? colorSelections,
    bool? discountSaving,
    Map<String, VariantStockFormState>? variantForms,
    bool? hasStockVariants,
    int? generalStock,
    bool setGeneralStockNull = false,
    bool? discountEnabled,
    String? discountType,
    double? discountValue,
    bool clearDiscountValue = false,
    DateTime? discountStart,
    bool clearDiscountStart = false,
    DateTime? discountEnd,
    bool clearDiscountEnd = false,
    double? basePrice,
    double? previewFinalPrice,
    double? lastKnownFinalPrice,
    double? deliverySize,
    String? deliverySizeInput,
    String? deliverySizeError,
    bool clearDeliverySizeError = false,
    bool clearDeliverySize = false,
  }) {
    return ProductManagementState(
      item: item,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      options: options ?? this.options,
      managedAttributes: managedAttributes ?? this.managedAttributes,
      attributeSelections: attributeSelections ?? this.attributeSelections,
      textInputs: textInputs ?? this.textInputs,
      attributesSaving: attributesSaving ?? this.attributesSaving,
      stockSaving: stockSaving ?? this.stockSaving,
      colorSelections: colorSelections ?? this.colorSelections,
      discountSaving: discountSaving ?? this.discountSaving,
      variantForms: variantForms ?? this.variantForms,
      deliverySize:
          clearDeliverySize ? null : (deliverySize ?? this.deliverySize),
      deliverySizeInput: deliverySizeInput ?? this.deliverySizeInput,
      deliverySizeError: clearDeliverySize
          ? null
          : (clearDeliverySizeError
              ? null
              : (deliverySizeError ?? this.deliverySizeError)),
      hasStockVariants: hasStockVariants ?? this.hasStockVariants,
      generalStock:
          setGeneralStockNull ? null : (generalStock ?? this.generalStock),
      discountEnabled: discountEnabled ?? this.discountEnabled,
      discountType: discountType ?? this.discountType,
      discountValue:
          clearDiscountValue ? null : (discountValue ?? this.discountValue),
      discountStart:
          clearDiscountStart ? null : (discountStart ?? this.discountStart),
      discountEnd: clearDiscountEnd ? null : (discountEnd ?? this.discountEnd),
      basePrice: basePrice ?? this.basePrice,
      previewFinalPrice: previewFinalPrice ?? this.previewFinalPrice,
      lastKnownFinalPrice: lastKnownFinalPrice ?? this.lastKnownFinalPrice,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        item,
        loading,
        error,
        options,
        managedAttributes,
        attributeSelections.entries
            .map((MapEntry<String, List<String>> entry) =>
                '${entry.key}:${entry.value.join(',')}')
            .toList(),
        colorSelections.entries
            .map((MapEntry<String, List<CustomFieldColorEntry>> entry) {
          final Iterable<String> encoded =
              entry.value.map((CustomFieldColorEntry e) {
            final String quantity = e.quantity?.toString() ?? '';
            return '${e.code}:$quantity';
          });
          return '${entry.key}:${encoded.join('|')}';
        }).toList(),
        textInputs,
        attributesSaving,
        stockSaving,
        discountSaving,
        variantForms,
        deliverySize,
        deliverySizeInput,
        deliverySizeError,
        hasStockVariants,
        generalStock,
        discountEnabled,
        discountType,
        discountValue,
        discountStart,
        discountEnd,
        basePrice,
        previewFinalPrice,
        lastKnownFinalPrice,
      ];

  ManagedPurchaseAttribute? attributeByKey(String key) {
    for (final ManagedPurchaseAttribute attribute in managedAttributes) {
      if (attribute.key == key) {
        return attribute;
      }
    }
    return null;
  }
}

class ProductManagementCubit extends Cubit<ProductManagementState> {
  ProductManagementCubit(this._repository, this.item)
      : super(ProductManagementState.initial(item));

  final ItemPurchaseOptionsRepository _repository;
  final ItemModel item;
  int _attributeSeed = 0;

  Future<void> initialize() async {
    final int? itemId = item.id;
    if (itemId == null) {
      emit(state.copyWith(
        loading: false,
        error: 'لا يمكن تحميل بيانات المنتج دون معرّف صالح.',
      ));
      return;
    }

    emit(state.copyWith(loading: true, error: null));

    try {
      final ItemPurchaseOptions options = await _repository.fetch(itemId);
      _applyOptions(options, finalPrice: options.finalPrice);
    } catch (error) {
      final String message =
          ErrorFilter.check(error).error?.toString() ?? error.toString();
      emit(state.copyWith(loading: false, error: message));
    }
  }

  void toggleAttributeValue(String key, String value) {
    final ManagedPurchaseAttribute? attribute = state.attributeByKey(key);
    if (attribute == null) {
      return;
    }
    if (attribute.type == ManagedAttributeType.color) {
      final List<CustomFieldColorEntry> currentEntries =
          List<CustomFieldColorEntry>.from(
              state.colorSelections[key] ?? const <CustomFieldColorEntry>[]);
      final String normalized = value.toUpperCase();
      final int index = currentEntries.indexWhere(
          (CustomFieldColorEntry entry) =>
              entry.code.toUpperCase() == normalized);

      if (index >= 0) {
        currentEntries.removeAt(index);
      } else {
        currentEntries.add(CustomFieldColorEntry(code: normalized));
      }

      setColorAttributeEntries(key, currentEntries);
      return;
    }

    final List<String> current = List<String>.from(
      state.attributeSelections[key] ?? attribute.options,
    );

    if (current.contains(value)) {
      current.remove(value);
    } else {
      current.add(value);
    }

    current
      ..removeWhere((String element) => element.trim().isEmpty)
      ..sort();
    _updateAttributeOptions(key, current);
  }

  void _updateAttributeOptions(String key, List<String> options,
      {bool triggerRecompute = true}) {
    final ManagedPurchaseAttribute? attribute = state.attributeByKey(key);
    if (attribute == null) {
      return;
    }

    final List<String> sanitized = _normalizeOptionValues(options);
    final List<ManagedPurchaseAttribute> nextManaged = state.managedAttributes
        .map((ManagedPurchaseAttribute item) =>
            item.key == key ? item.copyWith(options: sanitized) : item)
        .toList(growable: false);

    final Map<String, List<String>> nextSelections =
        Map<String, List<String>>.from(state.attributeSelections);
    if (sanitized.isEmpty) {
      nextSelections.remove(key);
    } else {
      nextSelections[key] = _sortedSelectionsFromOptions(sanitized);
    }

    emit(state.copyWith(
      managedAttributes: _withReindexedPositions(nextManaged),
      attributeSelections: nextSelections,
      error: null,
    ));

    if (triggerRecompute) {
      _recomputeVariantState();
    }
  }

  String _generateTemporaryAttributeKey(String prefix) {
    String candidate;
    do {
      _attributeSeed++;
      candidate =
          '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_attributeSeed';
    } while (state.attributeByKey(candidate) != null);
    return candidate;
  }

  void addColorAttribute() {
    final String key = _generateTemporaryAttributeKey('color');
    final ManagedPurchaseAttribute attribute = ManagedPurchaseAttribute(
      id: null,
      key: key,
      name: _defaultAttributeName(ManagedAttributeType.color),
      type: ManagedAttributeType.color,
      requiredForCheckout: true,
      affectsStock: true,
      colorEntries: const <CustomFieldColorEntry>[],
      options: const <String>[],
      metadata: const <String, dynamic>{},
      position: state.managedAttributes.length,
    );

    final List<ManagedPurchaseAttribute> next = _withReindexedPositions(
      <ManagedPurchaseAttribute>[...state.managedAttributes, attribute],
    );

    emit(state.copyWith(managedAttributes: next, error: null));

    _recomputeVariantState();
  }

  void addSizeAttribute() {
    final String key = _generateTemporaryAttributeKey('size');
    final ManagedPurchaseAttribute attribute = ManagedPurchaseAttribute(
      id: null,
      key: key,
      name: _defaultAttributeName(ManagedAttributeType.size),
      type: ManagedAttributeType.size,
      requiredForCheckout: true,
      affectsStock: true,
      colorEntries: const <CustomFieldColorEntry>[],
      options: const <String>[],
      metadata: const <String, dynamic>{},
      position: state.managedAttributes.length,
    );

    final List<ManagedPurchaseAttribute> next = _withReindexedPositions(
      <ManagedPurchaseAttribute>[...state.managedAttributes, attribute],
    );

    emit(state.copyWith(managedAttributes: next, error: null));
    _recomputeVariantState();
  }

  void addCustomAttribute({String? name}) {
    final String key = _generateTemporaryAttributeKey('custom');
    final String resolvedName = (name ?? '').trim().isEmpty
        ? _defaultAttributeName(ManagedAttributeType.custom)
        : name!.trim();
    final ManagedPurchaseAttribute attribute = ManagedPurchaseAttribute(
      id: null,
      key: key,
      name: resolvedName,
      type: ManagedAttributeType.custom,
      requiredForCheckout: false,
      affectsStock: false,
      colorEntries: const <CustomFieldColorEntry>[],
      options: const <String>[],
      metadata: const <String, dynamic>{},
      position: state.managedAttributes.length,
    );

    final List<ManagedPurchaseAttribute> next = _withReindexedPositions(
      <ManagedPurchaseAttribute>[...state.managedAttributes, attribute],
    );

    emit(state.copyWith(managedAttributes: next, error: null));
    _recomputeVariantState();
  }

  void removeAttribute(String key) {
    final List<ManagedPurchaseAttribute> next = state.managedAttributes
        .where((ManagedPurchaseAttribute attribute) => attribute.key != key)
        .toList(growable: false);

    final Map<String, List<String>> nextSelections =
        Map<String, List<String>>.from(state.attributeSelections)..remove(key);
    final Map<String, List<CustomFieldColorEntry>> nextColors =
        Map<String, List<CustomFieldColorEntry>>.from(state.colorSelections)
          ..remove(key);
    final Map<String, String> nextTexts =
        Map<String, String>.from(state.textInputs)..remove(key);

    emit(state.copyWith(
      managedAttributes: _withReindexedPositions(next),
      attributeSelections: nextSelections,
      colorSelections: nextColors,
      textInputs: nextTexts,
      error: null,
    ));

    _recomputeVariantState();
  }

  void setAttributeName(String key, String name) {
    final ManagedPurchaseAttribute? attribute = state.attributeByKey(key);
    if (attribute == null) {
      return;
    }

    final String normalized = name.trim().isEmpty
        ? _defaultAttributeName(attribute.type)
        : name.trim();

    final List<ManagedPurchaseAttribute> next = state.managedAttributes
        .map((ManagedPurchaseAttribute item) =>
            item.key == key ? item.copyWith(name: normalized) : item)
        .toList(growable: false);

    emit(state.copyWith(
      managedAttributes: _withReindexedPositions(next),
      error: null,
    ));
  }

  void setAttributeRequired(String key, bool required) {
    final ManagedPurchaseAttribute? attribute = state.attributeByKey(key);
    if (attribute == null) {
      return;
    }

    final List<ManagedPurchaseAttribute> next = state.managedAttributes
        .map((ManagedPurchaseAttribute item) => item.key == key
            ? item.copyWith(requiredForCheckout: required)
            : item)
        .toList(growable: false);

    emit(state.copyWith(
      managedAttributes: _withReindexedPositions(next),
      error: null,
    ));
  }

  void setAttributeAffectsStock(String key, bool affectsStock) {
    final ManagedPurchaseAttribute? attribute = state.attributeByKey(key);
    if (attribute == null) {
      return;
    }

    final List<ManagedPurchaseAttribute> next = state.managedAttributes
        .map((ManagedPurchaseAttribute item) =>
            item.key == key ? item.copyWith(affectsStock: affectsStock) : item)
        .toList(growable: false);

    emit(state.copyWith(
      managedAttributes: _withReindexedPositions(next),
      error: null,
    ));

    _recomputeVariantState();
  }

  void addAttributeOption(String key, {String? value}) {
    final ManagedPurchaseAttribute? attribute = state.attributeByKey(key);
    if (attribute == null || attribute.type == ManagedAttributeType.color) {
      return;
    }

    final String resolved =
        (value ?? 'خيار ${attribute.options.length + 1}').trim();
    final List<String> options = <String>[...attribute.options, resolved];
    _updateAttributeOptions(key, options);
  }

  void updateAttributeOption(String key, int index, String value) {
    final ManagedPurchaseAttribute? attribute = state.attributeByKey(key);
    if (attribute == null || attribute.type == ManagedAttributeType.color) {
      return;
    }
    if (index < 0 || index >= attribute.options.length) {
      return;
    }

    final List<String> options = List<String>.from(attribute.options);
    options[index] = value.trim();
    _updateAttributeOptions(key, options);
  }

  void removeAttributeOption(String key, int index) {
    final ManagedPurchaseAttribute? attribute = state.attributeByKey(key);
    if (attribute == null || attribute.type == ManagedAttributeType.color) {
      return;
    }
    if (index < 0 || index >= attribute.options.length) {
      return;
    }

    final List<String> options = List<String>.from(attribute.options)
      ..removeAt(index);
    _updateAttributeOptions(key, options);
  }

  void setTextAttribute(String key, String value) {
    final Map<String, String> next = Map<String, String>.from(state.textInputs);
    next[key] = value;

    emit(state.copyWith(textInputs: next, error: null));
  }

  void setColorAttributeEntries(
      String key, List<CustomFieldColorEntry> entries) {
    final Map<String, List<CustomFieldColorEntry>> nextColorSelections =
        Map<String, List<CustomFieldColorEntry>>.from(state.colorSelections);
    final Map<String, List<String>> nextSelections =
        Map<String, List<String>>.from(state.attributeSelections);

    final LinkedHashMap<String, CustomFieldColorEntry> normalized =
        LinkedHashMap<String, CustomFieldColorEntry>();
    for (final CustomFieldColorEntry entry in entries) {
      final String code = entry.code.toUpperCase().trim();
      if (code.isEmpty || !RegExp(r'^[0-9A-F]{6}$').hasMatch(code)) {
        continue;
      }
      final int? quantity = entry.quantity;
      normalized[code] = quantity != null && quantity >= 0
          ? CustomFieldColorEntry(code: code, quantity: quantity)
          : CustomFieldColorEntry(code: code, quantity: null);
    }

    if (normalized.isEmpty) {
      nextColorSelections.remove(key);
      nextSelections.remove(key);
    } else {
      nextColorSelections[key] = normalized.values.toList(growable: false);
      final List<String> codes = normalized.keys
          .map((String code) => code)
          .toList(growable: false)
        ..sort();
      nextSelections[key] = codes;
    }

    final ManagedPurchaseAttribute? attribute = state.attributeByKey(key);
    final List<ManagedPurchaseAttribute> nextManaged = attribute == null
        ? state.managedAttributes
        : state.managedAttributes
            .map((ManagedPurchaseAttribute item) => item.key == key
                ? item.copyWith(
                    colorEntries: normalized.values.toList(growable: false))
                : item)
            .toList(growable: false);

    emit(state.copyWith(
      managedAttributes: _withReindexedPositions(nextManaged),
      colorSelections: nextColorSelections,
      attributeSelections: nextSelections,
      error: null,
    ));

    _recomputeVariantState();
  }

  void setDeliverySize(String? value) {
    if (value == null) {
      emit(state.copyWith(
        deliverySize: null,
        deliverySizeInput: '',
        clearDeliverySize: true,
        deliverySizeError: null,
        clearDeliverySizeError: true,
        error: null,
      ));
      return;
    }

    final String sanitized = value.replaceAll(',', '.');
    final String trimmed = sanitized.trim();

    if (trimmed.isEmpty) {
      emit(state.copyWith(
        deliverySize: null,
        deliverySizeInput: '',
        clearDeliverySize: true,
        deliverySizeError: 'يرجى إدخال وزن المنتج بالكيلوجرام.',
        clearDeliverySizeError: false,
        error: null,
      ));
      return;
    }

    final double? parsed = double.tryParse(trimmed);
    if (parsed == null) {
      emit(state.copyWith(
        deliverySizeInput: trimmed,
        deliverySizeError:
            'يمكن إدخال الأرقام والفاصل العشري فقط (على سبيل المثال 2.5).',
        clearDeliverySizeError: false,
        error: null,
      ));
      return;
    }

    final int decimalIndex = trimmed.indexOf('.');
    if (decimalIndex != -1 && trimmed.length - decimalIndex - 1 > 3) {
      emit(state.copyWith(
        deliverySizeInput: trimmed,
        deliverySizeError: 'يمكن استخدام حتى ثلاثة منازل عشرية فقط.',
        clearDeliverySizeError: false,
        error: null,
      ));
      return;
    }

    if (trimmed.endsWith('.')) {
      emit(state.copyWith(
        deliverySizeInput: trimmed,
        deliverySizeError: 'يرجى إكمال الجزء العشري بعد الفاصل.',
        clearDeliverySizeError: false,
        error: null,
      ));
      return;
    }

    if (parsed <= 0) {
      emit(state.copyWith(
        deliverySizeInput: trimmed,
        deliverySizeError: 'الوزن يجب أن يكون أكبر من صفر.',
        clearDeliverySizeError: false,
        error: null,
      ));
      return;
    }

    final double normalizedValue = double.parse(parsed.toStringAsFixed(3));
    final String formattedInput = _formatDeliverySizeInput(normalizedValue);

    if (state.deliverySize == normalizedValue &&
        state.deliverySizeInput == formattedInput &&
        state.deliverySizeError == null) {
      return;
    }

    emit(state.copyWith(
      deliverySize: normalizedValue,
      deliverySizeInput: formattedInput,
      clearDeliverySize: false,
      deliverySizeError: null,
      clearDeliverySizeError: true,
      error: null,
    ));
  }

  Future<SubmissionOutcome> saveAttributes() async {
    if (item.id == null) {
      return const SubmissionOutcome(
        success: false,
        message: 'لا يمكن حفظ السمات قبل تحميل البيانات.',
      );
    }

    if (state.deliverySizeError != null) {
      return SubmissionOutcome(
        success: false,
        message: state.deliverySizeError!,
      );
    }

    if (state.deliverySize == null) {
      emit(state.copyWith(
        deliverySizeError: 'يرجى إدخال وزن المنتج بالكيلوجرام.',
        clearDeliverySizeError: false,
      ));
      return const SubmissionOutcome(
        success: false,
        message: 'يرجى إدخال وزن المنتج بالكيلوجرام قبل الحفظ.',
      );
    }

    emit(state.copyWith(attributesSaving: true, error: null));

    try {
      final List<Map<String, dynamic>> attributesPayload =
          <Map<String, dynamic>>[];

      for (int index = 0; index < state.managedAttributes.length; index++) {
        final ManagedPurchaseAttribute attribute =
            state.managedAttributes[index];
        final String trimmedName = attribute.name.trim().isEmpty
            ? _defaultAttributeName(attribute.type)
            : attribute.name.trim();

        switch (attribute.type) {
          case ManagedAttributeType.color:
            final List<CustomFieldColorEntry> entries =
                state.colorSelections[attribute.key] ?? attribute.colorEntries;
            if ((attribute.requiredForCheckout || attribute.affectsStock) &&
                entries.isEmpty) {
              emit(state.copyWith(attributesSaving: false));
              return SubmissionOutcome(
                success: false,
                message:
                    'يرجى إضافة لون واحد على الأقل للسمة $trimmedName قبل الحفظ.',
              );
            }

            attributesPayload.add(<String, dynamic>{
              if (attribute.id != null) 'id': attribute.id,
              'key': attribute.key,
              'name': trimmedName,
              'type': 'color',
              'required_for_checkout': attribute.requiredForCheckout,
              'affects_stock': attribute.affectsStock,
              'position': index,
              'values': entries
                  .map((CustomFieldColorEntry entry) => entry.toJson())
                  .toList(growable: false),
              if (attribute.metadata.isNotEmpty) 'metadata': attribute.metadata,
            });
            break;
          case ManagedAttributeType.size:
          case ManagedAttributeType.custom:
            final List<String> options = attribute.options;
            if ((attribute.requiredForCheckout || attribute.affectsStock) &&
                options.isEmpty) {
              emit(state.copyWith(attributesSaving: false));
              return SubmissionOutcome(
                success: false,
                message:
                    'يرجى إضافة خيار واحد على الأقل للسمة $trimmedName قبل الحفظ.',
              );
            }

            attributesPayload.add(<String, dynamic>{
              if (attribute.id != null) 'id': attribute.id,
              'key': attribute.key,
              'name': trimmedName,
              'type': attribute.type.name,
              'required_for_checkout': attribute.requiredForCheckout,
              'affects_stock': attribute.affectsStock,
              'position': index,
              'values': options,
              if (attribute.metadata.isNotEmpty) 'metadata': attribute.metadata,
            });
            break;
        }
      }

      final PurchaseOptionsUpdateResult result =
          await _repository.saveAttributes(
        itemId: item.id!,
        attributes: attributesPayload,
        deliverySize: state.deliverySize,
      );

      _applyOptions(result.options, finalPrice: result.finalPrice);

      emit(state.copyWith(attributesSaving: false));

      return SubmissionOutcome(success: true, message: result.message);
    } catch (error) {
      final String message =
          ErrorFilter.check(error).error?.toString() ?? error.toString();
      emit(state.copyWith(attributesSaving: false));
      return SubmissionOutcome(success: false, message: message);
    }
  }

  void setVariantStock(String variantKey, int stock) {
    final Map<String, VariantStockFormState> next =
        Map<String, VariantStockFormState>.from(state.variantForms);
    final VariantStockFormState? current = next[variantKey];

    if (current == null) {
      return;
    }

    final int normalized = stock < 0 ? 0 : stock;
    next[variantKey] = current.copyWith(stock: normalized);

    emit(state.copyWith(variantForms: next));
  }

  void toggleVariantVisibility(String variantKey) {
    final Map<String, VariantStockFormState> next =
        Map<String, VariantStockFormState>.from(state.variantForms);
    final VariantStockFormState? current = next[variantKey];
    if (current == null) {
      return;
    }

    if (current.hidden) {
      final int restored = current.lastVisibleStock ?? current.stock;
      next[variantKey] = current.copyWith(
        hidden: false,
        stock: restored,
        resetLastVisibleStock: true,
      );
    } else {
      next[variantKey] = current.copyWith(
        hidden: true,
        stock: 0,
        lastVisibleStock: current.stock,
      );
    }

    emit(state.copyWith(variantForms: next));
  }

  void applyBulkStock(int stock) {
    final int normalized = stock < 0 ? 0 : stock;
    final Map<String, VariantStockFormState> next =
        <String, VariantStockFormState>{};

    state.variantForms.forEach((String key, VariantStockFormState value) {
      if (value.hidden) {
        next[key] = value;
      } else {
        next[key] =
            value.copyWith(stock: normalized, resetLastVisibleStock: true);
      }
    });

    emit(state.copyWith(variantForms: next));
  }

  void setGeneralStock(int stock) {
    final int normalized = stock < 0 ? 0 : stock;
    emit(state.copyWith(generalStock: normalized));
  }

  Future<SubmissionOutcome> saveStock() async {
    if (item.id == null) {
      return const SubmissionOutcome(
          success: false, message: 'معرّف المنتج غير معروف.');
    }

    if (state.hasStockVariants && state.variantForms.isEmpty) {
      return const SubmissionOutcome(
        success: false,
        message:
            'يرجى تحديد قيم السمات المؤثرة على المخزون ثم توليد التوليفات قبل الحفظ.',
      );
    }

    emit(state.copyWith(stockSaving: true, error: null));

    try {
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

      if (state.hasStockVariants) {
        final SplayTreeMap<String, VariantStockFormState> ordered =
            SplayTreeMap<String, VariantStockFormState>.from(
                state.variantForms);
        ordered.forEach((String key, VariantStockFormState value) {
          rows.add(<String, dynamic>{
            'variant_key': key,
            'stock': value.hidden ? 0 : value.stock,
          });
        });
      } else {
        rows.add(<String, dynamic>{
          'variant_key': '',
          'stock': (state.generalStock ?? 0),
        });
      }

      final PurchaseOptionsUpdateResult result = await _repository.saveStock(
        itemId: item.id!,
        rows: rows,
      );

      _applyOptions(result.options, finalPrice: result.finalPrice);

      emit(state.copyWith(stockSaving: false));

      return SubmissionOutcome(success: true, message: result.message);
    } catch (error) {
      final String message =
          ErrorFilter.check(error).error?.toString() ?? error.toString();
      emit(state.copyWith(stockSaving: false));
      return SubmissionOutcome(success: false, message: message);
    }
  }

  void setDiscountEnabled(bool enabled) {
    emit(state.copyWith(discountEnabled: enabled));
    _recomputePreviewFinalPrice();
  }

  void setDiscountType(String type) {
    emit(state.copyWith(discountType: type));
    _recomputePreviewFinalPrice();
  }

  void setDiscountValue(double? value) {
    emit(state.copyWith(discountValue: value));
    _recomputePreviewFinalPrice();
  }

  void setDiscountStart(DateTime? value) {
    emit(state.copyWith(discountStart: value));
  }

  void setDiscountEnd(DateTime? value) {
    emit(state.copyWith(discountEnd: value));
  }

  Future<SubmissionOutcome> saveDiscount() async {
    if (item.id == null) {
      return const SubmissionOutcome(
          success: false, message: 'معرّف المنتج غير معروف.');
    }

    emit(state.copyWith(discountSaving: true, error: null));

    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'enabled': state.discountEnabled,
      };

      if (state.discountEnabled) {
        if (state.discountValue == null) {
          emit(state.copyWith(discountSaving: false));
          return const SubmissionOutcome(
            success: false,
            message: 'أدخل قيمة الخصم قبل الحفظ.',
          );
        }

        if (state.discountStart == null || state.discountEnd == null) {
          emit(state.copyWith(discountSaving: false));
          return const SubmissionOutcome(
            success: false,
            message: 'حدد فترة الخصم قبل الحفظ.',
          );
        }

        final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

        payload['discount_type'] = state.discountType;
        payload['discount_value'] = state.discountType == 'percent'
            ? math.min(state.discountValue!, 90)
            : math.max(state.discountValue!, 0);
        payload['discount_start'] = formatter.format(state.discountStart!);
        payload['discount_end'] = formatter.format(state.discountEnd!);
      }

      final PurchaseOptionsUpdateResult result = await _repository.saveDiscount(
        itemId: item.id!,
        payload: payload,
      );

      _applyOptions(result.options, finalPrice: result.finalPrice);

      emit(state.copyWith(discountSaving: false));

      return SubmissionOutcome(success: true, message: result.message);
    } catch (error) {
      final String message =
          ErrorFilter.check(error).error?.toString() ?? error.toString();
      emit(state.copyWith(discountSaving: false));
      return SubmissionOutcome(success: false, message: message);
    }
  }

  void _applyOptions(ItemPurchaseOptions options, {double? finalPrice}) {
    final Map<String, ItemPurchaseAttributeOption> rawAttributes =
        <String, ItemPurchaseAttributeOption>{
      for (final ItemPurchaseAttributeOption attribute in options.attributes)
        attribute.key: attribute,
    };

    final List<ManagedPurchaseAttribute> managedAttributes =
        options.attributes.map(_createManagedAttribute).toList(growable: false);

    final Map<String, List<String>> selections = <String, List<String>>{};
    final Map<String, String> textInputs = <String, String>{};
    final Map<String, List<CustomFieldColorEntry>> colorSelections =
        <String, List<CustomFieldColorEntry>>{};

    for (final ManagedPurchaseAttribute attribute in managedAttributes) {
      if (attribute.type == ManagedAttributeType.color) {
        final List<CustomFieldColorEntry> entries = attribute
                .colorEntries.isNotEmpty
            ? attribute.colorEntries
            : _normalizeColorEntries(
                (rawAttributes[attribute.key]?.allowedValues ??
                        const <String>[])
                    .map((String value) => CustomFieldColorEntry(code: value))
                    .toList(growable: false),
              );

        if (entries.isNotEmpty) {
          final List<CustomFieldColorEntry> normalized =
              _normalizeColorEntries(entries);

          final List<String> codes = normalized
              .map((CustomFieldColorEntry entry) => entry.code)
              .toList(growable: false)
            ..sort();
          selections[attribute.key] = codes;
          colorSelections[attribute.key] = normalized;
        }
      } else {
        final List<String> optionsList = attribute.options.isNotEmpty
            ? attribute.options
            : _normalizeOptionValues(
                rawAttributes[attribute.key]?.allowedValues ??
                    const <String>[]);

        if (optionsList.isNotEmpty) {
          final List<String> normalized = List<String>.from(optionsList)
            ..removeWhere((String value) => value.trim().isEmpty)
            ..sort();
          selections[attribute.key] = normalized;
        } else {
          final String fallback =
              rawAttributes[attribute.key]?.defaultValue ?? '';
          textInputs[attribute.key] = fallback;
        }
      }
    }

    final bool hasVariants = managedAttributes
        .any((ManagedPurchaseAttribute attribute) => attribute.affectsStock);

    final ItemVariantStockOption generalStockOption =
        options.variantStocks.firstWhere(
      (ItemVariantStockOption element) => element.variantKey.trim().isEmpty,
      orElse: () => const ItemVariantStockOption(
        variantKey: '',
        stock: 0,
        reservedStock: 0,
        availableStock: 0,
      ),
    );

    final double basePrice = options.basePrice;
    final double targetFinalPrice = finalPrice ?? options.finalPrice;

    double? discountValue;
    DateTime? discountStart;
    DateTime? discountEnd;
    bool discountEnabled = false;
    String discountType = 'percent';

    final ItemDiscount? discount = options.discount;
    if (discount != null) {
      discountEnabled = discount.isActive || options.finalPrice < basePrice;
      if (discount.type != null) {
        if (discount.type == 'fixed') {
          discountType = 'fixed';
        } else {
          discountType = 'percent';
        }
      }
      discountValue = discount.value;
      discountStart = discount.start;
      discountEnd = discount.end;
    }
    final double? deliverySize = _normalizeDeliverySize(options.deliverySize);

    emit(state.copyWith(
      loading: false,
      error: null,
      options: options,
      managedAttributes: managedAttributes,
      attributeSelections: selections,
      colorSelections: colorSelections,
      textInputs: textInputs,
      deliverySize: deliverySize,
      deliverySizeInput:
          deliverySize != null ? _formatDeliverySizeInput(deliverySize) : '',
      deliverySizeError: null,
      clearDeliverySize: deliverySize == null,
      clearDeliverySizeError: true,
      hasStockVariants: hasVariants,
      generalStock: hasVariants ? null : generalStockOption.stock,
      basePrice: basePrice,
      lastKnownFinalPrice: targetFinalPrice,
      discountEnabled: discountEnabled,
      discountType: discountType,
      discountValue: discountValue,
      discountStart: discountStart,
      discountEnd: discountEnd,
      previewFinalPrice: targetFinalPrice,
    ));

    _recomputeVariantState(options: options);
    _recomputePreviewFinalPrice();
  }

  void _recomputeVariantState({ItemPurchaseOptions? options}) {
    final ItemPurchaseOptions? targetOptions = options ?? state.options;
    if (targetOptions == null) {
      return;
    }

    final List<ManagedPurchaseAttribute> affecting = state.managedAttributes
        .where((ManagedPurchaseAttribute element) => element.affectsStock)
        .toList(growable: false);

    if (affecting.isEmpty) {
      final ItemVariantStockOption generalStockOption =
          targetOptions.variantStocks.firstWhere(
        (ItemVariantStockOption element) => element.variantKey.trim().isEmpty,
        orElse: () => const ItemVariantStockOption(
          variantKey: '',
          stock: 0,
          reservedStock: 0,
          availableStock: 0,
        ),
      );

      emit(state.copyWith(
        variantForms: const <String, VariantStockFormState>{},
        hasStockVariants: false,
        generalStock: generalStockOption.stock,
      ));
      return;
    }

    final Map<String, ItemVariantStockOption> stockMap =
        <String, ItemVariantStockOption>{};
    for (final ItemVariantStockOption entry in targetOptions.variantStocks) {
      stockMap[entry.variantKey] = entry;
    }

    bool ready = true;
    for (final ManagedPurchaseAttribute attribute in affecting) {
      final List<String> selected =
          state.attributeSelections[attribute.key] ?? const <String>[];
      if (selected.isEmpty) {
        ready = false;
        break;
      }
    }

    if (!ready) {
      emit(state.copyWith(
        variantForms: const <String, VariantStockFormState>{},
        hasStockVariants: true,
        setGeneralStockNull: true,
      ));
      return;
    }

    final List<Map<String, String>> combinations =
        _generateCombinations(affecting);
    final Map<String, VariantStockFormState> nextForms =
        <String, VariantStockFormState>{};

    for (final Map<String, String> combo in combinations) {
      final String variantKey = _buildVariantKey(combo);
      final VariantStockFormState? existing = state.variantForms[variantKey];
      final ItemVariantStockOption? stockOption = stockMap[variantKey];

      final int resolvedStock = existing?.stock ?? stockOption?.stock ?? 0;
      final bool hidden = existing?.hidden ?? false;
      final int? lastVisibleStock = existing?.lastVisibleStock;

      nextForms[variantKey] = VariantStockFormState(
        variantKey: variantKey,
        attributes: Map<String, String>.unmodifiable(combo),
        stock: hidden ? (existing?.stock ?? 0) : resolvedStock,
        hidden: hidden,
        lastVisibleStock: lastVisibleStock,
      );
    }

    emit(state.copyWith(
      variantForms: nextForms,
      hasStockVariants: true,
      setGeneralStockNull: true,
    ));
  }

  List<Map<String, String>> _generateCombinations(
    List<ManagedPurchaseAttribute> attributes,
  ) {
    final List<Map<String, String>> result = <Map<String, String>>[];

    void helper(int index, Map<String, String> current) {
      if (index >= attributes.length) {
        result.add(Map<String, String>.from(current));
        return;
      }

      final ManagedPurchaseAttribute attribute = attributes[index];
      final List<String> selected =
          state.attributeSelections[attribute.key] ?? const <String>[];

      for (final String value in selected) {
        current[attribute.key] = value;
        helper(index + 1, current);
      }

      current.remove(attribute.key);
    }

    helper(0, <String, String>{});
    return result;
  }

  String _buildVariantKey(Map<String, String> attributes) {
    if (attributes.isEmpty) {
      return '';
    }

    final Map<String, String> normalized = <String, String>{};
    attributes.forEach((String key, String value) {
      final String trimmedKey = key.trim();
      final String trimmedValue = value.trim();
      if (trimmedKey.isNotEmpty) {
        normalized[trimmedKey] = trimmedValue;
      }
    });

    if (normalized.isEmpty) {
      return '';
    }

    return VariantKeyCodec.encode(Map<String, Object?>.from(normalized));
  }

  void _recomputePreviewFinalPrice() {
    final double base = state.basePrice;
    double finalPrice = base;

    if (state.discountEnabled && state.discountValue != null) {
      if (state.discountType == 'percent') {
        final double percentage = math.min(state.discountValue!, 90);
        final double discountAmount = base * (percentage / 100);
        finalPrice = math.max(0, base - discountAmount);
      } else {
        final double amount = math.max(0, state.discountValue!);
        finalPrice = math.max(0, base - amount);
      }
    } else {
      finalPrice = state.lastKnownFinalPrice;
    }

    emit(state.copyWith(
        previewFinalPrice: double.parse(finalPrice.toStringAsFixed(2))));
  }
}
