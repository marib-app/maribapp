import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marib/data/model/ad_draft_model.dart';

import 'services/category_inventory_service.dart';
import 'models/custom_field_schema.dart';

/// Ordered steps used inside the wizard.
enum AdCreationStep {
  mainCategory,
  subCategory,
  customFields,
  media,
  textDetails,
  review,
}

extension AdCreationStepX on AdCreationStep {
  String get label {
    switch (this) {
      case AdCreationStep.mainCategory:
        return 'الفئة الرئيسية';
      case AdCreationStep.subCategory:
        return 'الفئة الفرعية';
      case AdCreationStep.customFields:
        return 'الحقول المخصصة';
      case AdCreationStep.media:
        return 'الوسائط والمخزون';
      case AdCreationStep.textDetails:
        return 'تفاصيل النص';
      case AdCreationStep.review:
        return 'مراجعة';
    }
  }
}

/// Basic category item used by the wizard.
class WizardCategory {
  const WizardCategory({
    required this.id,
    required this.name,
    this.children = const <WizardCategory>[],
  });

  final int id;
  final String name;
  final List<WizardCategory> children;

  WizardCategory copyWith({
    int? id,
    String? name,
    List<WizardCategory>? children,
  }) {
    return WizardCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      children: children ?? this.children,
    );
  }

  WizardCategory? findById(int value) {
    if (id == value) {
      return this;
    }
    for (final WizardCategory child in children) {
      final WizardCategory? match = child.findById(value);
      if (match != null) {
        return match;
      }
    }
    return null;
  }
}

class _CategoryPath {
  const _CategoryPath({required this.main, this.sub});

  final WizardCategory main;
  final WizardCategory? sub;
}

/// Representation of a pending media file before upload.
class PendingMedia {
  PendingMedia({
    required this.displayName,
    this.source,
    bool? isVideo,
  })  : id = _generateId(),
        isVideo = isVideo ?? false;

  final String id;
  final String displayName;
  final String? source;
  final bool isVideo;

  bool get isImage => !isVideo;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': displayName,
      if (source != null) 'source': source,
      'is_video': isVideo,
    };
  }

  static String _generateId() => 'media-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';
}

/// Inventory variation associated with an advertisement.
class InventoryVariation {
  InventoryVariation({String? id})
      : id = id ?? 'variation-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}',
        nameController = TextEditingController(),
        priceController = TextEditingController(),
        quantityController = TextEditingController();

  final String id;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController quantityController;

  String get name => nameController.text;
  String get priceText => priceController.text;
  String get quantityText => quantityController.text;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'price': priceText,
      'quantity': quantityText,
    };
  }

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
  }
}

/// Controls the shared state of the wizard including autosave logic.
class AdCreationWizardController extends ChangeNotifier {
  AdCreationWizardController({
    this.draftId,
    this.interfaceType,
    this.accountTypeCode,
    Iterable<String>? permittedSections,
    Iterable<String>? blockedSections,
    Iterable<int>? allowedCategoryIds,
    Iterable<int>? initialCategoryIds,
    CategoryInventoryService? categoryService,
    AdPublishingService? publishingService,
    this.persistDrafts = false,
  })  : permittedDelegateSections = Set<String>.from(permittedSections ?? const <String>{}),
        blockedDelegateSections = Set<String>.from(blockedSections ?? const <String>{}),
        _allowedCategoryIds = allowedCategoryIds == null ? null : Set<int>.from(allowedCategoryIds),
        _initialCategoryIds = initialCategoryIds == null ? const <int>[] : List<int>.from(initialCategoryIds),
        _categoryService = categoryService ?? CategoryInventoryService(),
        _publishingService = publishingService,
        titleController = TextEditingController(),
        descriptionController = TextEditingController(),
        priceController = TextEditingController(),
        contactController = TextEditingController(),
        sheinProductLinkController = TextEditingController(),
        sheinReviewLinkController = TextEditingController(),
        mediaLabelController = TextEditingController(),
        videoLinkController = TextEditingController();

  final String? draftId;
  final String? interfaceType;
  final String? accountTypeCode;
  final Set<String> permittedDelegateSections;
  final Set<String> blockedDelegateSections;
  final Set<int>? _allowedCategoryIds;
  final List<int> _initialCategoryIds;
  final CategoryInventoryService _categoryService;
  final AdPublishingService? _publishingService;
  final bool persistDrafts;

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController contactController;
  final TextEditingController sheinProductLinkController;
  final TextEditingController sheinReviewLinkController;
  final TextEditingController mediaLabelController;
  final TextEditingController videoLinkController;

  final Map<String, TextEditingController> _customFieldTextControllers = <String, TextEditingController>{};
  final Map<String, Set<String>> _customFieldMultiValues = <String, Set<String>>{};

  AdCreationStep _currentStep = AdCreationStep.mainCategory;
  List<WizardCategory> _mainCategories = const <WizardCategory>[];
  WizardCategory? _selectedMainCategory;
  WizardCategory? _selectedSubCategory;
  List<CustomFieldSchema> _customFields = const <CustomFieldSchema>[];
  bool _isLoadingCustomFields = false;
  final Map<String, dynamic> _customFieldValues = <String, dynamic>{};
  final List<PendingMedia> _mediaFiles = <PendingMedia>[];
  final List<String> _videoLinks = <String>[];
  final List<InventoryVariation> _inventoryVariations = <InventoryVariation>[];
  Map<String, dynamic>? _locationSummary;

  bool _hasPendingChanges = false;
  bool _isSaving = false;
  bool _hasOfflineDraft = false;
  String? _draftId;
  String? _autoSaveError;
  DateTime? _lastAutoSave;
  bool _disposed = false;

  /// Initializes mocked categories and applies initial selections.
  Future<void> initialize() async {
    _draftId = draftId;
    _mainCategories = _buildMockedCategories();
    if (_initialCategoryIds.isNotEmpty) {
      _applyInitialCategorySelection(_initialCategoryIds);
    }
    notifyListeners();
    await refreshCustomFieldSchema();
  }

  AdCreationStep get currentStep => _currentStep;
  int get currentStepIndex => _currentStep.index;

  List<WizardCategory> get mainCategories => _mainCategories;
  WizardCategory? get selectedMainCategory => _selectedMainCategory;
  WizardCategory? get selectedSubCategory => _selectedSubCategory;
  List<WizardCategory> get visibleSubCategories => _selectedMainCategory?.children ?? const <WizardCategory>[];
  List<CustomFieldSchema> get customFields => _customFields;
  bool get isLoadingCustomFields => _isLoadingCustomFields;
  Map<String, dynamic> get customFieldValues => Map<String, dynamic>.from(_customFieldValues);
  List<PendingMedia> get mediaFiles => List<PendingMedia>.from(_mediaFiles);
  List<String> get videoLinks => List<String>.from(_videoLinks);
  List<InventoryVariation> get inventoryVariations => List<InventoryVariation>.from(_inventoryVariations);
  Map<String, dynamic>? get locationSummary => _locationSummary == null
      ? null
      : Map<String, dynamic>.from(_locationSummary!);

  bool get hasPendingChanges => _hasPendingChanges;
  bool get isSaving => _isSaving;
  bool get hasOfflineDraft => _hasOfflineDraft;
  String? get activeDraftId => _draftId;
  String? get autoSaveError => _autoSaveError;
  DateTime? get lastAutoSave => _lastAutoSave;

  String get currencyLabel => 'ريال';

  bool get isSheinInterface =>
      (interfaceType ?? '').toLowerCase().contains('shein');

  String get cacheKey => 'ad-wizard-${interfaceType ?? 'default'}-${accountTypeCode ?? 'guest'}';

  void setCurrentStep(AdCreationStep step) {
    if (_currentStep == step) {
      return;
    }
    _currentStep = step;
    notifyListeners();
  }

  bool goToNextStep() {
    if (_currentStep.index >= AdCreationStep.values.length - 1) {
      return false;
    }
    _currentStep = AdCreationStep.values[_currentStep.index + 1];
    notifyListeners();
    return true;
  }

  bool goToPreviousStep() {
    if (_currentStep.index == 0) {
      return false;
    }
    _currentStep = AdCreationStep.values[_currentStep.index - 1];
    notifyListeners();
    return true;
  }

  void selectMainCategory(WizardCategory category) {
    if (_selectedMainCategory?.id == category.id) {
      return;
    }
    _selectedMainCategory = category;
    _selectedSubCategory = null;
    _customFieldValues.clear();
    _customFieldMultiValues.clear();
    _disposeCustomFieldControllers();
    markDraftChanged();
    notifyListeners();
    unawaited(refreshCustomFieldSchema());
  }

  void selectSubCategory(WizardCategory? category) {
    if (category != null && _selectedSubCategory?.id == category.id) {
      return;
    }
    _selectedSubCategory = category;
    _customFieldValues.clear();
    _customFieldMultiValues.clear();
    _disposeCustomFieldControllers();
    markDraftChanged();
    notifyListeners();
    unawaited(refreshCustomFieldSchema());
  }

  TextEditingController customFieldTextController(String fieldId) {
    final TextEditingController controller =
        _customFieldTextControllers[fieldId] ?? TextEditingController();
    _customFieldTextControllers[fieldId] = controller;
    return controller;
  }

  void setCustomFieldTextValue(String fieldId, String value) {
    _customFieldValues[fieldId] = value;
    markDraftChanged();
  }

  void setCustomFieldSingleChoice(String fieldId, String? value) {
    if (value == null) {
      _customFieldValues.remove(fieldId);
    } else {
      _customFieldValues[fieldId] = value;
    }
    markDraftChanged();
    notifyListeners();
  }

  void toggleCustomFieldMultiChoice(String fieldId, String value) {
    final Set<String> selections =
        _customFieldMultiValues[fieldId] ?? <String>{};
    if (selections.contains(value)) {
      selections.remove(value);
    } else {
      selections.add(value);
    }
    _customFieldMultiValues[fieldId] = selections;
    _customFieldValues[fieldId] = selections.toList(growable: false);
    markDraftChanged();
    notifyListeners();
  }

  void addMediaEntry({required String label, bool isVideo = false}) {
    if (label.trim().isEmpty) {
      return;
    }
    final PendingMedia media =
    PendingMedia(displayName: label.trim(), isVideo: isVideo);
    _mediaFiles.add(media);
    markDraftChanged();
    notifyListeners();
  }

  void removeMedia(String id) {
    _mediaFiles.removeWhere((PendingMedia media) => media.id == id);
    markDraftChanged();
    notifyListeners();
  }

  void addVideoLink(String link) {
    final String trimmed = link.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (_videoLinks.contains(trimmed)) {
      return;
    }
    _videoLinks.add(trimmed);
    markDraftChanged();
    notifyListeners();
  }

  void removeVideoLink(String link) {
    _videoLinks.remove(link);
    markDraftChanged();
    notifyListeners();
  }

  InventoryVariation addInventoryVariation() {
    final InventoryVariation variation = InventoryVariation();
    _inventoryVariations.add(variation);
    markDraftChanged();
    notifyListeners();
    return variation;
  }

  void removeInventoryVariation(String id) {
    final InventoryVariation? variation = _inventoryVariations
        .firstWhereOrNull((InventoryVariation element) => element.id == id);
    _inventoryVariations.removeWhere((InventoryVariation element) => element.id == id);
    variation?.dispose();
    markDraftChanged();
    notifyListeners();
  }

  void updateLocation(Map<String, dynamic>? payload) {
    _locationSummary = payload == null ? null : Map<String, dynamic>.from(payload);
    markDraftChanged();
    notifyListeners();
  }

  void markDraftChanged() {
    if (_disposed) {
      return;
    }
    if (!_hasPendingChanges) {
      _hasPendingChanges = true;
      notifyListeners();
    }
  }

  Future<void> refreshCustomFieldSchema() async {
    final int? categoryId =
        _selectedSubCategory?.id ?? _selectedMainCategory?.id;
    if (categoryId == null) {
      _customFields = const <CustomFieldSchema>[];
      notifyListeners();
      return;
    }

    _isLoadingCustomFields = true;
    _customFields = const <CustomFieldSchema>[];
    notifyListeners();
    try {
      final List<CustomFieldSchema> schema = await _categoryService
          .fetchCustomFieldSchema(
        interfaceType: interfaceType ?? 'public_ads',
        categoryId: categoryId,
      );
      _customFields = schema;
      _syncCustomFieldControllers(schema);
    } catch (error) {
      _autoSaveError = error.toString();
    } finally {
      _isLoadingCustomFields = false;
      notifyListeners();
    }
  }

  Future<void> autoSaveCurrentStep() async {
    if (_disposed || _isSaving || !_hasPendingChanges) {
      return;
    }
    _isSaving = true;
    _autoSaveError = null;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (persistDrafts && _publishingService != null) {
        try {
          final AdDraftModel draft = await _publishingService!.saveDraft(
            draftId: _draftId,
            payload: buildPayload(),
            stepPayload: buildStepPayload(_currentStep),
            temporaryMedia: buildTemporaryMediaPayload(),
            currentStep: _currentStep.name,
            cacheKey: cacheKey,
          );
          _draftId = draft.id ?? _draftId;
          _hasOfflineDraft = false;
        } on DraftSaveOfflineException catch (error) {
          _hasOfflineDraft = true;
          _autoSaveError = error.toString();
        } catch (error) {
          _autoSaveError = error.toString();
        }
      }
      _lastAutoSave = DateTime.now();
      if (_autoSaveError == null) {
        _hasPendingChanges = false;
      }
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> buildPayload() {
    return <String, dynamic>{
      'interface_type': interfaceType,
      'account_type_code': accountTypeCode,
      'permitted_sections': permittedDelegateSections.toList(),
      'blocked_sections': blockedDelegateSections.toList(),
      'category_path': <int?>[
        _selectedMainCategory?.id,
        _selectedSubCategory?.id,
      ].whereType<int>().toList(),
      'title': titleController.text,
      'description': descriptionController.text,
      'price': priceController.text,
      'contact_number': contactController.text,
      'shein_product_link': sheinProductLinkController.text,
      'shein_review_link': sheinReviewLinkController.text,
      'custom_fields': Map<String, dynamic>.from(_customFieldValues),
      'media_files': _mediaFiles.map((PendingMedia media) => media.toJson()).toList(),
      'video_links': List<String>.from(_videoLinks),
      'inventory': _inventoryVariations.map((InventoryVariation e) => e.toJson()).toList(),
      if (_locationSummary != null) 'location': Map<String, dynamic>.from(_locationSummary!),
    };
  }

  Map<String, dynamic> buildStepPayload(AdCreationStep step) {
    switch (step) {
      case AdCreationStep.mainCategory:
        return <String, dynamic>{
          'selected_main_category': _selectedMainCategory?.id,
        };
      case AdCreationStep.subCategory:
        return <String, dynamic>{
          'selected_sub_category': _selectedSubCategory?.id,
        };
      case AdCreationStep.customFields:
        return <String, dynamic>{
          'custom_fields': Map<String, dynamic>.from(_customFieldValues),
        };
      case AdCreationStep.media:
        return <String, dynamic>{
          'media_files': _mediaFiles.map((PendingMedia media) => media.toJson()).toList(),
          'video_links': List<String>.from(_videoLinks),
          'inventory': _inventoryVariations.map((InventoryVariation e) => e.toJson()).toList(),
        };
      case AdCreationStep.textDetails:
        return <String, dynamic>{
          'title': titleController.text,
          'description': descriptionController.text,
          'price': priceController.text,
          'contact_number': contactController.text,
          'shein_product_link': sheinProductLinkController.text,
          'shein_review_link': sheinReviewLinkController.text,
        };
      case AdCreationStep.review:
        return buildPayload();
    }
  }

  Map<String, dynamic> buildTemporaryMediaPayload() {
    return <String, dynamic>{
      'media_files': _mediaFiles.map((PendingMedia media) => media.toJson()).toList(),
      'video_links': List<String>.from(_videoLinks),
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _disposeCustomFieldControllers();
    for (final InventoryVariation variation in _inventoryVariations) {
      variation.dispose();
    }
    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    contactController.dispose();
    sheinProductLinkController.dispose();
    sheinReviewLinkController.dispose();
    mediaLabelController.dispose();
    videoLinkController.dispose();
    super.dispose();
  }

  void _applyInitialCategorySelection(List<int> categoryIds) {
    for (final int id in categoryIds) {
      final _CategoryPath? path = _locateCategory(id);
      if (path == null) {
        continue;
      }
      _selectedMainCategory = path.main;
      _selectedSubCategory = path.sub;
    }
  }

  _CategoryPath? _locateCategory(int id) {
    for (final WizardCategory main in _mainCategories) {
      if (main.id == id) {
        return _CategoryPath(main: main);
      }
      final WizardCategory? match = main.findById(id);
      if (match != null) {
        return _CategoryPath(main: main, sub: match);
      }
    }
    return null;
  }

  List<WizardCategory> _buildMockedCategories() {
    const List<WizardCategory> all = <WizardCategory>[
      WizardCategory(
        id: 101,
        name: 'إلكترونيات',
        children: <WizardCategory>[
          WizardCategory(id: 201, name: 'هواتف ذكية'),
          WizardCategory(id: 202, name: 'أجهزة لوحية'),
          WizardCategory(id: 203, name: 'أجهزة كمبيوتر'),
        ],
      ),
      WizardCategory(
        id: 102,
        name: 'عقارات',
        children: <WizardCategory>[
          WizardCategory(id: 204, name: 'شقق'),
          WizardCategory(id: 205, name: 'فلل'),
          WizardCategory(id: 206, name: 'أراضٍ'),
        ],
      ),
      WizardCategory(
        id: 103,
        name: 'خدمات',
        children: <WizardCategory>[
          WizardCategory(id: 207, name: 'صيانة'),
          WizardCategory(id: 208, name: 'تنظيف'),
          WizardCategory(id: 209, name: 'استشارات'),
        ],
      ),
    ];

    if (_allowedCategoryIds == null || _allowedCategoryIds!.isEmpty) {
      return all;
    }

    final Set<int> allowed = _allowedCategoryIds!;
    final List<WizardCategory> filtered = <WizardCategory>[];
    for (final WizardCategory main in all) {
      final List<WizardCategory> children = <WizardCategory>[];
      for (final WizardCategory child in main.children) {
        if (allowed.contains(child.id) || allowed.contains(main.id)) {
          children.add(child);
        }
      }
      if (allowed.contains(main.id) || children.isNotEmpty) {
        filtered.add(main.copyWith(children: children));
      }
    }
    return filtered.isEmpty ? all : filtered;
  }

  void _syncCustomFieldControllers(List<CustomFieldSchema> schema) {
    final Set<String> activeIds = schema.map((CustomFieldSchema e) => e.id).toSet();
    final List<String> toRemove = <String>[];
    _customFieldTextControllers.forEach((String key, TextEditingController value) {
      if (!activeIds.contains(key)) {
        value.dispose();
        toRemove.add(key);
      }
    });
    for (final String key in toRemove) {
      _customFieldTextControllers.remove(key);
    }
  }

  void _disposeCustomFieldControllers() {
    final List<TextEditingController> controllers =
    _customFieldTextControllers.values.toList();
    _customFieldTextControllers.clear();
    for (final TextEditingController controller in controllers) {
      controller.dispose();
    }
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final E element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}