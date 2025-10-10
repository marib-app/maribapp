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

class SubmissionOutcome {
  const SubmissionOutcome({required this.success, required this.message});

  final bool success;
  final String message;
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
      lastVisibleStock:
      resetLastVisibleStock ? null : (lastVisibleStock ?? this.lastVisibleStock),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    variantKey,
    attributes.entries
        .map((MapEntry<String, String> entry) => '${entry.key}:${entry.value}')
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
    required this.attributeSelections,
    required this.colorSelections,
    required this.textInputs,
    required this.attributesSaving,
    required this.stockSaving,
    required this.discountSaving,
    required this.variantForms,
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
      attributeSelections: const <String, List<String>>{},
      textInputs: const <String, String>{},
      attributesSaving: false,
      colorSelections: const <String, List<CustomFieldColorEntry>>{},
      stockSaving: false,
      discountSaving: false,
      variantForms: const <String, VariantStockFormState>{},
      hasStockVariants: false,
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

  bool get hasLoaded => options != null;
  bool get isCombinationReady {
    if (!hasStockVariants) {
      return true;
    }

    if (options == null) {
      return false;
    }

    for (final ItemPurchaseAttributeOption attribute in options!.attributes) {
      if (!attribute.affectsStock) {
        continue;
      }
      final List<String> selected = attributeSelections[attribute.key] ?? const <String>[];
      if (selected.isEmpty) {
        return false;
      }
    }
    return true;
  }

  ProductManagementState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    ItemPurchaseOptions? options,
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
  }) {
    return ProductManagementState(
      item: item,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      options: options ?? this.options,
      attributeSelections: attributeSelections ?? this.attributeSelections,
      textInputs: textInputs ?? this.textInputs,
      attributesSaving: attributesSaving ?? this.attributesSaving,
      stockSaving: stockSaving ?? this.stockSaving,
      colorSelections: colorSelections ?? this.colorSelections,
      discountSaving: discountSaving ?? this.discountSaving,
      variantForms: variantForms ?? this.variantForms,
      hasStockVariants: hasStockVariants ?? this.hasStockVariants,
      generalStock: setGeneralStockNull ? null : (generalStock ?? this.generalStock),
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
    attributeSelections.entries
        .map((MapEntry<String, List<String>> entry) =>
    '${entry.key}:${entry.value.join(',')}')
        .toList(),
    colorSelections.entries
        .map((MapEntry<String, List<CustomFieldColorEntry>> entry) {
      final Iterable<String> encoded = entry.value.map((CustomFieldColorEntry e) {
        final String quantity = e.quantity?.toString() ?? '';
        return '${e.code}:$quantity';
      });
      return '${entry.key}:${encoded.join('|')}';
    })

        .toList(),
    textInputs,
    attributesSaving,
    stockSaving,
    discountSaving,
    variantForms,
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
}

class ProductManagementCubit extends Cubit<ProductManagementState> {
  ProductManagementCubit(this._repository, this.item)
      : super(ProductManagementState.initial(item));

  final ItemPurchaseOptionsRepository _repository;
  final ItemModel item;

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

    final ItemPurchaseAttributeOption? attribute = state.options?.attributeByKey(key);
    final bool isColor = attribute != null && _looksLikeColorAttribute(attribute);

    if (isColor) {
      final List<CustomFieldColorEntry> currentEntries =
      List<CustomFieldColorEntry>.from(state.colorSelections[key] ?? const <CustomFieldColorEntry>[]);
      final String normalized = value.toUpperCase();
      final int index =
      currentEntries.indexWhere((CustomFieldColorEntry entry) => entry.code.toUpperCase() == normalized);

      if (index >= 0) {
        currentEntries.removeAt(index);
      } else {
        currentEntries.add(CustomFieldColorEntry(code: normalized));
      }

      setColorAttributeEntries(key, currentEntries);
      return;
    }

    final Map<String, List<String>> nextSelections =
    Map<String, List<String>>.from(state.attributeSelections);

    final List<String> current = List<String>.from(nextSelections[key] ?? const <String>[]);

    if (current.contains(value)) {
      current.remove(value);
    } else {
      current.add(value);
    }

    current
      ..removeWhere((String element) => element.trim().isEmpty)
      ..sort();

    if (current.isEmpty) {
      nextSelections.remove(key);
    } else {
      nextSelections[key] = current;
    }

    emit(state.copyWith(
      attributeSelections: nextSelections,
      error: null,
    ));

    _recomputeVariantState();
  }

  void setTextAttribute(String key, String value) {
    final Map<String, String> next = Map<String, String>.from(state.textInputs);
    next[key] = value;

    emit(state.copyWith(textInputs: next, error: null));
  }



  void setColorAttributeEntries(String key, List<CustomFieldColorEntry> entries) {
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
      final List<String> codes =
      normalized.keys.map((String code) => code).toList(growable: false)
        ..sort();
      nextSelections[key] = codes;
    }

    emit(state.copyWith(
      colorSelections: nextColorSelections,
      attributeSelections: nextSelections,
      error: null,
    ));

    _recomputeVariantState();
  }

  bool _looksLikeColorAttribute(ItemPurchaseAttributeOption attribute) {
    final String? type = attribute.type?.toLowerCase();
    final String? uiType = attribute.uiType?.toLowerCase();
    if (type == 'color' || uiType == 'color') {
      return true;
    }

    if (attribute.colorEntries.isNotEmpty) {
      return true;
    }

    final String normalizedKey = attribute.key.toLowerCase();
    final String normalizedName = attribute.name.toLowerCase();

    return normalizedKey.contains('color') ||
        normalizedKey.contains('colour') ||
        normalizedKey.contains('اللون') ||
        normalizedName.contains('color') ||
        normalizedName.contains('colour') ||
        normalizedName.contains('اللون');
  }

  Future<SubmissionOutcome> saveAttributes() async {
    if (state.options == null || item.id == null) {
      return const SubmissionOutcome(
        success: false,
        message: 'لا يمكن حفظ السمات قبل تحميل البيانات.',
      );
    }

    emit(state.copyWith(attributesSaving: true, error: null));

    try {
      final Map<String, dynamic> selectedValues = <String, dynamic>{};

      final Map<String, String> textValues = <String, String>{};

      for (final ItemPurchaseAttributeOption attribute in state.options!.attributes) {
        final List<String> selected = state.attributeSelections[attribute.key] ?? const <String>[];
        if (attribute.allowedValues.isNotEmpty) {
          if (_looksLikeColorAttribute(attribute)) {
            final List<CustomFieldColorEntry> entries =
                state.colorSelections[attribute.key] ?? const <CustomFieldColorEntry>[];
            selectedValues[attribute.key] =
                entries.map((CustomFieldColorEntry entry) => entry.toJson()).toList();
          } else {
            selectedValues[attribute.key] = selected;
          }

        } else {
          textValues[attribute.key] = state.textInputs[attribute.key]?.trim() ?? '';
        }
      }

      final PurchaseOptionsUpdateResult result = await _repository.saveAttributes(
        itemId: item.id!,
        selectedValues: selectedValues,
        textValues: textValues,
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
    final Map<String, VariantStockFormState> next = <String, VariantStockFormState>{};

    state.variantForms.forEach((String key, VariantStockFormState value) {
      if (value.hidden) {
        next[key] = value;
      } else {
        next[key] = value.copyWith(stock: normalized, resetLastVisibleStock: true);
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
      return const SubmissionOutcome(success: false, message: 'معرّف المنتج غير معروف.');
    }

    if (state.hasStockVariants && state.variantForms.isEmpty) {
      return const SubmissionOutcome(
        success: false,
        message: 'يرجى تحديد قيم السمات المؤثرة على المخزون ثم توليد التوليفات قبل الحفظ.',
      );
    }

    emit(state.copyWith(stockSaving: true, error: null));

    try {
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

      if (state.hasStockVariants) {
        final SplayTreeMap<String, VariantStockFormState> ordered =
        SplayTreeMap<String, VariantStockFormState>.from(state.variantForms);
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
      return const SubmissionOutcome(success: false, message: 'معرّف المنتج غير معروف.');
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
    final Map<String, List<String>> selections = <String, List<String>>{};
    final Map<String, String> textInputs = <String, String>{};
    final Map<String, List<CustomFieldColorEntry>> colorSelections =
    <String, List<CustomFieldColorEntry>>{};

    for (final ItemPurchaseAttributeOption attribute in options.attributes) {
      if (attribute.allowedValues.isNotEmpty) {
        if (_looksLikeColorAttribute(attribute)) {
          final Map<String, CustomFieldColorEntry> entriesByCode = {
            for (final CustomFieldColorEntry entry in attribute.colorEntries)
              entry.code: entry,
          };
          final List<String> selectedCodes =
          List<String>.from(attribute.selectedValues);

          final List<CustomFieldColorEntry> selectedEntries =
          <CustomFieldColorEntry>[];
          final Set<String> seen = <String>{};

          void addEntry(String code) {
            final String normalized = code.toUpperCase();
            if (!seen.add(normalized)) {
              return;
            }
            final CustomFieldColorEntry? entry = entriesByCode[normalized];
            if (entry != null) {
              selectedEntries.add(entry);
            } else {
              selectedEntries
                  .add(CustomFieldColorEntry(code: normalized, quantity: null));
            }
          }

          if (selectedCodes.isNotEmpty) {
            for (final String code in selectedCodes) {
              addEntry(code);
            }
          } else if (entriesByCode.isNotEmpty) {
            for (final CustomFieldColorEntry entry in entriesByCode.values) {
              addEntry(entry.code);
            }
          } else if (attribute.allowedValues.isNotEmpty) {
            for (final String value in attribute.allowedValues) {
              addEntry(value);
            }
          }

          final List<String> codes =
          selectedEntries.map((CustomFieldColorEntry entry) => entry.code).toList();
          codes.sort();
          selections[attribute.key] = codes;
          colorSelections[attribute.key] = selectedEntries;
        } else {
          final List<String> selected =
          List<String>.from(attribute.selectedValues);
          selected.sort();
          selections[attribute.key] = selected;
        }
      } else {
        textInputs[attribute.key] = attribute.defaultValue ?? '';
      }
    }

    final bool hasVariants = options.attributes.any((ItemPurchaseAttributeOption attribute) => attribute.affectsStock);

    final ItemVariantStockOption generalStockOption = options.variantStocks.firstWhere(
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

    emit(state.copyWith(
      loading: false,
      error: null,
      options: options,
      attributeSelections: selections,
      colorSelections: colorSelections,
      textInputs: textInputs,
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

    if (!targetOptions.attributes.any((ItemPurchaseAttributeOption attribute) => attribute.affectsStock)) {
      final ItemVariantStockOption generalStockOption = targetOptions.variantStocks.firstWhere(
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

    final Map<String, ItemVariantStockOption> stockMap = <String, ItemVariantStockOption>{};
    for (final ItemVariantStockOption entry in targetOptions.variantStocks) {
      stockMap[entry.variantKey] = entry;
    }

    final List<ItemPurchaseAttributeOption> affecting = targetOptions.attributes
        .where((ItemPurchaseAttributeOption element) => element.affectsStock)
        .toList(growable: false);

    bool ready = true;
    for (final ItemPurchaseAttributeOption attribute in affecting) {
      final List<String> selected = state.attributeSelections[attribute.key] ?? const <String>[];
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

    final List<Map<String, String>> combinations = _generateCombinations(affecting);
    final Map<String, VariantStockFormState> nextForms = <String, VariantStockFormState>{};

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
      List<ItemPurchaseAttributeOption> attributes,
      ) {
    final List<Map<String, String>> result = <Map<String, String>>[];

    void helper(int index, Map<String, String> current) {
      if (index >= attributes.length) {
        result.add(Map<String, String>.from(current));
        return;
      }

      final ItemPurchaseAttributeOption attribute = attributes[index];
      final List<String> selected = state.attributeSelections[attribute.key] ?? const <String>[];

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
    final SplayTreeMap<String, String> ordered =
    SplayTreeMap<String, String>.from(attributes);
    final List<String> parts = <String>[];
    ordered.forEach((String key, String value) {
      parts.add('$key:$value');
    });
    return parts.join('|');
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

    emit(state.copyWith(previewFinalPrice: double.parse(finalPrice.toStringAsFixed(2))));
  }
}
