import 'dart:async';

import 'dart:io';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/imagePicker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/imagePicker.dart';
import 'package:dio/dio.dart';
import 'package:marib/data/model/ad_draft_model.dart';
import 'package:marib/data/model/ad_draft_model.dart';
import 'package:marib/data/repositories/item/ad_draft_local_store.dart';
import 'package:marib/data/repositories/item/ad_draft_repository.dart';
import 'package:marib/utils/app_telemetry.dart';
import 'package:marib/utils/ui_utils.dart';
import 'models/custom_field_schema.dart';
import 'services/category_inventory_service.dart';
import 'widgets/dynamic_custom_fields_form.dart';
import 'package:marib/ui/theme/theme.dart';






/// Simplified ad creation wizard showcasing a multi-step flow with
/// progress indicator, navigation guards and auto-save hooks.

class AdCreationWizardArguments {
  const AdCreationWizardArguments({
    this.draftId,
    this.interfaceType,
    List<int>? initialCategoryIds,
  }) : initialCategoryIds = initialCategoryIds ?? const <int>[];


  final String? draftId;
  final String? interfaceType;
  final List<int> initialCategoryIds;

  factory AdCreationWizardArguments.fromMap(Map<dynamic, dynamic> raw) {
    final Map<String, dynamic> normalized = <String, dynamic>{};
    raw.forEach((dynamic key, dynamic value) {
      if (key != null) {
        normalized[key.toString()] = value;
      }
    });

    final String? draftId =
        _stringArgument(normalized['draftId']) ?? _stringArgument(normalized['draft_id']);
    final String? interfaceType =
        _stringArgument(normalized['interfaceType']) ?? _stringArgument(normalized['interface_type']);
    final List<int> categoryIds = _parseCategoryIds(normalized);

    return AdCreationWizardArguments(
      draftId: draftId,
      interfaceType: interfaceType,
      initialCategoryIds: categoryIds,
    );
  }

  static String? _stringArgument(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static List<int> _parseCategoryIds(Map<String, dynamic> map) {
    final List<int> categoryIds = <int>[];

    void add(dynamic value) {
      final int? parsed = _intArgument(value);
      if (parsed == null) {
        return;
      }
      if (!categoryIds.contains(parsed)) {
        categoryIds.add(parsed);
      }
    }

    final dynamic rawCategoryIds = map['categoryIds'] ?? map['category_ids'];
    if (rawCategoryIds is Iterable) {
      for (final dynamic entry in rawCategoryIds) {
        add(entry);
      }
    } else if (rawCategoryIds is String) {
      for (final String token in rawCategoryIds.split(RegExp(r'[\s,]+'))) {
        add(token);
      }
    } else {
      add(rawCategoryIds);
    }

    add(map['catID']);
    add(map['catId']);
    add(map['categoryId']);
    add(map['category_id']);
    add(map['mainCategoryId']);
    add(map['subCategoryId']);
    add(map['sub_category_id']);

    return categoryIds;
  }

  static int? _intArgument(dynamic value) {
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
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

}

class AdCreationWizardScreen extends StatefulWidget {
  const AdCreationWizardScreen({
    super.key,
    this.initialDraftId,
    this.interfaceType,
    List<int>? initialCategoryIds,
  }) : initialCategoryIds = initialCategoryIds ?? const <int>[];

  final String? initialDraftId;
  final String? interfaceType;
  final List<int> initialCategoryIds;


  static Route<void> route(RouteSettings settings) {
    final AdCreationWizardArguments args = _resolveArguments(settings.arguments);

    return MaterialPageRoute(
      builder: (_) => AdCreationWizardScreen(
        initialDraftId: args.draftId,
        interfaceType: args.interfaceType,
        initialCategoryIds: args.initialCategoryIds,
      ),
      settings: settings,
    );
  }

  static AdCreationWizardArguments _resolveArguments(Object? raw) {
    if (raw is AdCreationWizardArguments) {
      return raw;
    }
    if (raw is Map) {
      return AdCreationWizardArguments.fromMap(
          Map<dynamic, dynamic>.from(raw as Map));
    }
    return const AdCreationWizardArguments();
  }


  @override
  State<AdCreationWizardScreen> createState() => _AdCreationWizardScreenState();
}

enum _WizardStepId {
  mainCategory,
  subCategory,
  customFields,
  media,
  textDetails,
  locationInventory,
  review,
}

class _AdCreationWizardScreenState extends State<AdCreationWizardScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final _priceController = TextEditingController();
  final _videoLinkFieldController = TextEditingController();
  final _sheinProductLinkController = TextEditingController();
  final _sheinReviewLinkController = TextEditingController();

  String? _selectedCurrency = 'YER';

  final PickImage _imagePicker = PickImage();
  final ImagePicker _videoPicker = ImagePicker();

  final List<_PendingMedia> _mediaFiles = <_PendingMedia>[];
  final List<String> _videoLinks = <String>[];
  final TextEditingController _locationAddressController =
      TextEditingController();
  final TextEditingController _locationLatitudeController =
      TextEditingController();
  final TextEditingController _locationLongitudeController =
      TextEditingController();
  final GlobalKey<FormState> _locationFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _inventoryFormKey = GlobalKey<FormState>();
  List<_InventoryVariation> _inventoryVariations = <_InventoryVariation>[];
  bool _isPickingImages = false;
  bool _isPickingVideo = false;

  final GlobalKey<FormState> _textDetailsFormKey = GlobalKey<FormState>();

  static const Map<String, String> _currencyOptions = <String, String>{
    'YER': 'ريال يمني',
    'SAR': 'ريال سعودي',
    'USD': 'دولار أمريكي',
  };
  static const Map<String, _WizardSectionConfig> _sectionConfigurations =
      <String, _WizardSectionConfig>{
    'public_ads': _WizardSectionConfig(requiresLocation: true),
    'public_ads:102': _WizardSectionConfig(requiresLocation: true),
    'services': _WizardSectionConfig(requiresInventory: true),
    'shein_products': _WizardSectionConfig(requiresInventory: true),
  };

  String get _stepFiveLabel {
    final _WizardSectionConfig config = _currentSectionConfig;
    if (config.requiresLocation && config.requiresInventory) {
      return 'الموقع والمخزون';
    }
    if (config.requiresLocation) {
      return 'تحديد الموقع';
    }
    if (config.requiresInventory) {
      return 'إدارة المخزون';
    }
    return 'خيارات إضافية';
  }

  _WizardSectionConfig get _currentSectionConfig {
    final _MainCategoryOption? mainCategory = _selectedMainCategory;
    if (mainCategory == null) {
      return const _WizardSectionConfig();
    }
    final _SubCategoryOption? subCategory = _selectedSubCategory;
    if (subCategory != null) {
      final String overrideKey =
          '${mainCategory.interfaceType}:${subCategory.id}';
      final _WizardSectionConfig? override =
          _sectionConfigurations[overrideKey];
      if (override != null) {
        return override;
      }
    }
    return _sectionConfigurations[mainCategory.interfaceType] ??
        const _WizardSectionConfig();
  }

  bool get _requiresLocation => _currentSectionConfig.requiresLocation;

  bool get _requiresInventory => _currentSectionConfig.requiresInventory;

  List<_WizardStep> get _steps {
    final _WizardSectionConfig config = _currentSectionConfig;
    final bool requiresLocation = config.requiresLocation;
    final bool requiresInventory = config.requiresInventory;
    final bool hasRequiredCustomFields =
        _customFieldSchemas.any((CustomFieldSchema field) => field.isRequired);

    return <_WizardStep>[
      const _WizardStep(
        id: _WizardStepId.mainCategory,
        label: 'الفئة الرئيسية',
      ),
      const _WizardStep(
        id: _WizardStepId.subCategory,
        label: 'الفئة الفرعية',
      ),
      _WizardStep(
        id: _WizardStepId.customFields,
        label: 'الحقول المخصّصة',
        isOptional: !hasRequiredCustomFields,
      ),
      const _WizardStep(
        id: _WizardStepId.media,
        label: 'المرحلة 4A: الوسائط',
      ),
      const _WizardStep(
        id: _WizardStepId.textDetails,
        label: 'المرحلة 4B: التفاصيل النصية',
      ),
      _WizardStep(
        id: _WizardStepId.locationInventory,
        label: _stepFiveLabel,
        isOptional: !(requiresLocation || requiresInventory),
        isVisible: requiresLocation || requiresInventory,
      ),
      const _WizardStep(
        id: _WizardStepId.review,
        label: 'المراجعة النهائية',
      ),
    ];
  }

  List<_WizardStep> get _visibleSteps => _steps
      .where((_WizardStep step) => step.isVisible)
      .toList(growable: false);

  final CategoryInventoryService _inventoryService = CategoryInventoryService();
  final AdPublishingService _adPublishingService = AdPublishingService();
  List<_MainCategoryOption> _mainCategories = <_MainCategoryOption>[];
  final List<int> _preferredCategoryPath = <int>[];
  String? _preferredInterfaceTypeOriginal;
  String? _preferredInterfaceTypeNormalized;
  int? _pendingInitialSubCategoryId;
  bool _appliedInitialCategorySelection = false;
  bool _hasRequestedCategoryFetch = false;
  FetchCategoryCubit? _categoryCubit;
  StreamSubscription<FetchCategoryState>? _categorySubscription;
  final GlobalKey<DynamicCustomFieldsFormState> _customFieldsFormKey =
      GlobalKey<DynamicCustomFieldsFormState>();
  final Map<String, List<CustomFieldSchema>> _customFieldSchemaCache =
      <String, List<CustomFieldSchema>>{};
  _MainCategoryOption? _selectedMainCategory;
  _SubCategoryOption? _selectedSubCategory;
  List<CustomFieldSchema> _customFieldSchemas = const <CustomFieldSchema>[];
  Map<String, dynamic> _customFieldValues = <String, dynamic>{};
  bool _isLoadingCustomFields = false;
  String? _customFieldError;
  bool _isPublishing = false;

  Timer? _autoSaveTimer;
  int _currentStep = 0;
  bool _hasUnsavedChanges = false;
  bool _isSavingDraft = false;
  String? _draftId;
  bool _isLoadingDraft = false;
  bool _isSyncingPending = false;
  bool _isHydratingState = false;
  final Map<String, String> _serverFieldErrors = <String, String>{};

  @override
  void initState() {
    super.initState();

    _registerPreferredInterfaceType(widget.interfaceType);
    _registerPreferredCategoryIds(widget.initialCategoryIds);

    _registerFieldController(_titleController, const <String>['title']);
    _registerFieldController(
        _descriptionController, const <String>['description']);
    _registerFieldController(_contactController, const <String>['contact']);
    _registerFieldController(_priceController, const <String>['price']);
    _registerFieldController(
        _sheinProductLinkController, const <String>['product_link']);
    _registerFieldController(
        _sheinReviewLinkController, const <String>['review_link']);
    _registerFieldController(
        _locationAddressController, const <String>['location.address']);
    _registerFieldController(
        _locationLatitudeController, const <String>['location.latitude']);
    _registerFieldController(
        _locationLongitudeController, const <String>['location.longitude']);
    _imagePicker.listener((dynamic files) {
      if (!mounted) {
        return;
      }
      if (files is List<File>) {
        _addImageFiles(files);
      } else if (files is File) {
        _addImageFiles(<File>[files]);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDraft();
    });
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final FetchCategoryCubit cubit = context.read<FetchCategoryCubit>();
    if (!identical(_categoryCubit, cubit)) {
      _categorySubscription?.cancel();
      _categoryCubit = cubit;
      _categorySubscription = cubit.stream.listen(_handleCategoryState);
    }

    final FetchCategoryState currentState = cubit.state;
    _handleCategoryState(currentState);

    final bool matchesPreferences =
    _categoryStateMatchesPreferences(currentState);
    if (!_hasRequestedCategoryFetch) {
      _triggerCategoryFetch();
    } else if (!matchesPreferences &&
        currentState is! FetchCategoryInProgress) {
      _triggerCategoryFetch(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _categorySubscription?.cancel();

    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _priceController.dispose();
    _videoLinkFieldController.dispose();
    _sheinProductLinkController.dispose();
    _sheinReviewLinkController.dispose();
    _locationAddressController.dispose();
    _locationLatitudeController.dispose();
    _locationLongitudeController.dispose();
    _imagePicker.dispose();
    super.dispose();
  }

  void _markDirty() {
    _autoSaveTimer?.cancel();
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    } else {
      _hasUnsavedChanges = true;
    }
    _autoSaveTimer = Timer(const Duration(seconds: 3), _autoSaveDraft);
  }

  void _registerFieldController(
      TextEditingController controller, List<String> keys) {
    controller.addListener(() {
      for (final String key in keys) {
        _clearServerFieldError(key);
      }
      _markDirty();
    });
  }


  void _registerPreferredInterfaceType(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }
    _preferredInterfaceTypeOriginal = trimmed;
    _preferredInterfaceTypeNormalized = trimmed.toLowerCase();
  }

  void _registerPreferredCategoryIds(Iterable<int> ids) {
    for (final int id in ids) {
      if (id <= 0) {
        continue;
      }
      if (!_preferredCategoryPath.contains(id)) {
        _preferredCategoryPath.add(id);
      }
    }
  }

  void _triggerCategoryFetch({bool forceRefresh = false}) {
    final FetchCategoryCubit? cubit =
        _categoryCubit ?? context.read<FetchCategoryCubit>();
    if (cubit == null) {
      return;
    }
    _categoryCubit = cubit;
    final List<int> categoryPath = List<int>.from(_preferredCategoryPath);
    final int? categoryId = categoryPath.isEmpty ? null : categoryPath.first;
    cubit.fetchCategories(
      interfaceType: _preferredInterfaceTypeOriginal,
      categoryId: categoryId,
      categoryIds: categoryPath.isEmpty ? null : categoryPath,
      forceRefresh: forceRefresh,
    );
    _hasRequestedCategoryFetch = true;
  }

  bool _categoryStateMatchesPreferences(FetchCategoryState state) {
    if (state is! FetchCategorySuccess) {
      return false;
    }
    final String? normalizedStateInterface =
    state.interfaceType?.trim().toLowerCase();
    if (_preferredInterfaceTypeNormalized != null &&
        normalizedStateInterface != _preferredInterfaceTypeNormalized) {
      return false;
    }
    if (_preferredCategoryPath.isNotEmpty) {
      if (state.categoryId != _preferredCategoryPath.first) {
        return false;
      }
      if (_preferredCategoryPath.length > 1 &&
          !_areCategoryPathsEqual(state.categoryIds, _preferredCategoryPath)) {
        return false;
      }
    }
    return true;
  }

  bool _areCategoryPathsEqual(List<int>? a, List<int> b) {
    if (b.isEmpty) {
      return true;
    }
    if (a == null || a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  void _handleCategoryState(FetchCategoryState state) {
    if (!mounted) {
      return;
    }
    if (state is FetchCategorySuccess) {
      final List<_MainCategoryOption> options =
      _buildMainCategoryOptions(state.categories);
      final _MainCategoryOption? retainedMain = _findMainCategoryById(
        options,
        _selectedMainCategory?.id,
      );
      final _SubCategoryOption? retainedSub = _selectedSubCategory == null
          ? null
          : _findSubCategoryById(
        retainedMain?.subCategories ?? const <_SubCategoryOption>[],
        _selectedSubCategory?.id,
      );

      setState(() {
        _mainCategories = options;
        _selectedMainCategory = retainedMain;
        _selectedSubCategory = retainedSub;
      });

      if (!_appliedInitialCategorySelection) {
        _applyInitialCategorySelection(options);
      } else if (_pendingInitialSubCategoryId != null) {
        _applyPendingSubCategorySelection();
      }
    }
  }

  List<_MainCategoryOption> _buildMainCategoryOptions(
      List<CategoryModel> categories) {
    final List<_MainCategoryOption> options = <_MainCategoryOption>[];
    for (final CategoryModel model in categories) {
      final int? id = model.id;
      final String? name = model.name;
      if (id == null || name == null || name.trim().isEmpty) {
        continue;
      }
      options.add(_MainCategoryOption.fromCategoryModel(model));
    }
    return options;
  }

  _MainCategoryOption? _findMainCategoryById(
      List<_MainCategoryOption> options, int? id) {
    if (id == null) {
      return null;
    }
    for (final _MainCategoryOption option in options) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }

  _SubCategoryOption? _findSubCategoryById(
      List<_SubCategoryOption> options, int? id) {
    if (id == null) {
      return null;
    }
    for (final _SubCategoryOption option in options) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }

  _MainCategoryOption? _findInitialMainCategory(
      List<_MainCategoryOption> options) {
    final int? preferredId =
    _preferredCategoryPath.isNotEmpty ? _preferredCategoryPath.first : null;
    if (preferredId != null) {
      final _MainCategoryOption? byId =
      _findMainCategoryById(options, preferredId);
      if (byId != null) {
        return byId;
      }
    }
    if (_preferredInterfaceTypeNormalized != null) {
      for (final _MainCategoryOption option in options) {
        if (option.normalizedInterfaceType ==
            _preferredInterfaceTypeNormalized) {
          return option;
        }
      }
    }
    return null;
  }

  void _applyInitialCategorySelection(List<_MainCategoryOption> options) {
    final _MainCategoryOption? target = _findInitialMainCategory(options);
    if (target == null) {
      return;
    }
    _appliedInitialCategorySelection = true;
    _pendingInitialSubCategoryId =
    _preferredCategoryPath.length > 1 ? _preferredCategoryPath[1] : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _onMainCategorySelected(target);
      _applyPendingSubCategorySelection();
    });
  }

  void _applyPendingSubCategorySelection() {
    final int? pendingId = _pendingInitialSubCategoryId;
    final _MainCategoryOption? main = _selectedMainCategory;
    if (pendingId == null || main == null) {
      return;
    }
    final _SubCategoryOption? target =
    _findSubCategoryById(main.subCategories, pendingId);
    if (target == null) {
      _pendingInitialSubCategoryId = null;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _pendingInitialSubCategoryId = null;
      _onSubCategorySelected(target);
    });
  }

  void _retryFetchCategories() {
    _triggerCategoryFetch(forceRefresh: true);
  }


  void _clearServerFieldError(String key) {
    if (_serverFieldErrors.isEmpty) {
      return;
    }
    final List<String> targets = _serverFieldErrors.keys
        .where((String existing) =>
            existing == key || existing.startsWith('$key.'))
        .toList(growable: false);
    if (targets.isEmpty) {
      return;
    }
    for (final String target in targets) {
      _serverFieldErrors.remove(target);
    }
  }

  void _resetServerValidationState() {
    if (_serverFieldErrors.isEmpty) {
      _customFieldsFormKey.currentState?.clearValidationErrors();
      return;
    }
    setState(() {
      _serverFieldErrors.clear();
    });
    _customFieldsFormKey.currentState?.clearValidationErrors();
  }

  String _normalizeServerFieldKey(String key) {
    if (key.startsWith('payload.')) {
      return key.substring('payload.'.length);
    }
    return key;
  }

  void _applyServerValidationErrors(Map<String, List<String>> errors) {
    final Map<String, String> normalized = <String, String>{};
    final Map<String, String> customFieldErrors = <String, String>{};

    errors.forEach((String rawKey, List<String> messages) {
      if (messages.isEmpty) {
        return;
      }
      final String normalizedKey = _normalizeServerFieldKey(rawKey);
      final String message = messages.first;
      if (normalizedKey.startsWith('custom_fields.')) {
        final String fieldId = normalizedKey.substring('custom_fields.'.length);
        customFieldErrors[fieldId] = message;
      } else {
        normalized[normalizedKey] = message;
      }
    });

    setState(() {
      _serverFieldErrors
        ..clear()
        ..addAll(normalized);
    });

    if (customFieldErrors.isNotEmpty) {
      _customFieldsFormKey.currentState
          ?.applyValidationErrors(customFieldErrors);
    }

    _textDetailsFormKey.currentState?.validate();
    if (_requiresLocation ||
        _serverFieldErrors.keys
            .any((String key) => key.startsWith('location.'))) {
      _locationFormKey.currentState?.validate();
    }
    final bool shouldValidateInventory = _requiresInventory ||
        _inventoryVariations.isNotEmpty ||
        _serverFieldErrors.keys
            .any((String key) => key.startsWith('inventory.'));
    if (shouldValidateInventory) {
      _inventoryFormKey.currentState?.validate();
    }
  }

  String? _firstNormalizedServerErrorKey(Map<String, List<String>> errors) {
    for (final String rawKey in errors.keys) {
      final String normalized = _normalizeServerFieldKey(rawKey);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  _WizardStepId? _stepForErrorKey(String key) {
    if (key.startsWith('custom_fields.')) {
      return _WizardStepId.customFields;
    }
    if (key.startsWith('media')) {
      return _WizardStepId.media;
    }
    if (key.startsWith('location.') || key.startsWith('inventory.')) {
      return _WizardStepId.locationInventory;
    }
    if (key.startsWith('sub_category')) {
      return _WizardStepId.subCategory;
    }
    if (key.startsWith('main_category') || key.startsWith('interface_type')) {
      return _WizardStepId.mainCategory;
    }
    const Set<String> textDetailKeys = <String>{
      'title',
      'description',
      'price',
      'contact',
      'currency',
      'product_link',
      'review_link',
      'video_links',
    };
    if (textDetailKeys.contains(key)) {
      return _WizardStepId.textDetails;
    }
    return null;
  }

  String get _draftCacheKey => _cacheKeyFor(_draftId ?? widget.initialDraftId);

  String _cacheKeyFor(String? draftId) => 'ad_wizard_${draftId ?? 'new'}';

  Future<void> _initializeDraft() async {
    String activeCacheKey = _cacheKeyFor(widget.initialDraftId);
    setState(() => _isLoadingDraft = true);
    try {
      Map<String, dynamic>? pending =
          await _adPublishingService.readPending(activeCacheKey);
      AdDraftModel? snapshot =
          await _adPublishingService.readCachedDraft(activeCacheKey);
      AdDraftModel? remote;

      final String? initialDraftId = widget.initialDraftId;
      if (initialDraftId != null && initialDraftId.isNotEmpty) {
        try {
          remote = await _adPublishingService.fetchDraft(initialDraftId);
          final String remoteCacheKey =
              _cacheKeyFor(remote.id ?? initialDraftId);
          await _adPublishingService.rememberDraft(remoteCacheKey, remote);
          if (remoteCacheKey != activeCacheKey) {
            await _adPublishingService.migrateCache(
              from: activeCacheKey,
              to: remoteCacheKey,
            );
            activeCacheKey = remoteCacheKey;
            pending ??= await _adPublishingService.readPending(activeCacheKey);
            snapshot =
                await _adPublishingService.readCachedDraft(activeCacheKey) ??
                    remote;
          }
          _draftId = remote.id ?? initialDraftId;
        } on DioException catch (error) {
          if (pending == null && snapshot == null && mounted) {
            _showMessage(
              'تعذّر تحميل المسودة: ${error.message ?? error.toString()}',
            );
          }
        }
      }

      if (pending != null) {
        _draftId =
            _extractDraftIdFromPending(pending) ?? _draftId ?? initialDraftId;
        _applyDraftPayload(
          payload: _mapOf(pending['payload']),
          temporaryMedia: _mapOf(pending['temporary_media']),
          currentStepName: _stringOrNull(pending['current_step']),
        );
      } else if (snapshot != null) {
        _draftId = snapshot.id ?? _draftId ?? initialDraftId;
        _applyDraftPayload(
          payload: snapshot.payload,
          temporaryMedia: snapshot.temporaryMedia,
          currentStepName: snapshot.currentStep,
        );
      } else if (remote != null) {
        _draftId = remote.id ?? _draftId ?? initialDraftId;
        _applyDraftPayload(
          payload: remote.payload,
          temporaryMedia: remote.temporaryMedia,
          currentStepName: remote.currentStep,
        );
      }

      await _syncPendingDraftIfNeeded(cacheKey: activeCacheKey);
    } catch (error) {
      if (mounted) {
        _showMessage('تعذّر تحميل المسودة: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDraft = false);
      }
    }
  }

  Future<void> _syncPendingDraftIfNeeded({String? cacheKey}) async {
    if (_isSyncingPending) {
      return;
    }
    final String resolvedKey = cacheKey ?? _draftCacheKey;
    _isSyncingPending = true;
    try {
      final AdDraftModel? synced = await _adPublishingService.syncPending(
        cacheKey: resolvedKey,
        fallbackDraftId: _draftId ?? widget.initialDraftId,
      );
      if (synced != null) {
        final String newCacheKey =
            _cacheKeyFor(synced.id ?? _draftId ?? widget.initialDraftId);
        if (newCacheKey != resolvedKey) {
          await _adPublishingService.migrateCache(
            from: resolvedKey,
            to: newCacheKey,
          );
        }
        if (mounted) {
          setState(() {
            _draftId = synced.id ?? _draftId;
            _hasUnsavedChanges = false;
          });
        }
      }
    } on DioException catch (error) {
      if (mounted) {
        _showMessage(
            'تعذّر مزامنة المسودة: ${error.message ?? error.toString()}');
      }
    } finally {
      _isSyncingPending = false;
    }
  }

  void _applyDraftPayload({
    required Map<String, dynamic> payload,
    Map<String, dynamic>? temporaryMedia,
    String? currentStepName,
  }) {
    _isHydratingState = true;
    _autoSaveTimer?.cancel();

    final _MainCategoryOption? mainCategory = _resolveMainCategory(payload);
    final _SubCategoryOption? subCategory =
        _resolveSubCategory(mainCategory, payload);
    final Map<String, dynamic> customFields = _mapOf(payload['custom_fields']);
    final Map<String, dynamic> location = _mapOf(payload['location']);
    final Map<String, dynamic> media = _mapOf(payload['media']);
    final Map<String, dynamic> inventory = _mapOf(payload['inventory']);
    final Map<String, dynamic> mediaCache = temporaryMedia != null
        ? Map<String, dynamic>.from(temporaryMedia)
        : <String, dynamic>{};

    final List<_PendingMedia> mediaFiles =
        _composePendingMedia(media, mediaCache);
    final List<String> videoLinks = _collectVideoLinks(media, mediaCache);
    final List<_InventoryVariation> variations = _buildVariations(inventory);
    final String? currency = _stringOrNull(payload['currency']);

    try {
      _titleController.text = _stringOrNull(payload['title']) ?? '';
      _descriptionController.text = _stringOrNull(payload['description']) ?? '';
      _contactController.text = _stringOrNull(payload['contact']) ?? '';
      _priceController.text = _stringOrNull(payload['price']) ?? '';
      _sheinProductLinkController.text =
          _stringOrNull(payload['product_link']) ?? '';
      _sheinReviewLinkController.text =
          _stringOrNull(payload['review_link']) ?? '';
      _locationAddressController.text =
          _stringOrNull(location['address']) ?? '';
      _locationLatitudeController.text =
          _stringOrNull(location['latitude']) ?? '';
      _locationLongitudeController.text =
          _stringOrNull(location['longitude']) ?? '';
    } finally {
      _isHydratingState = false;
    }

    setState(() {
      _selectedMainCategory = mainCategory;
      _selectedSubCategory = subCategory;
      _selectedCurrency = currency ?? _selectedCurrency;
      _customFieldValues = customFields;
      _mediaFiles
        ..clear()
        ..addAll(mediaFiles);
      _videoLinks
        ..clear()
        ..addAll(videoLinks);
      _inventoryVariations = variations;
      _hasUnsavedChanges = false;
      _recomputeCurrentStepBounds();
    });

    if (mainCategory != null && subCategory != null) {
      _fetchCustomFieldSchema();
    }

    final _WizardStepId? stepId = _wizardStepFromName(currentStepName);
    if (stepId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final List<_WizardStep> steps = _visibleSteps;
        final int index = steps.indexWhere((step) => step.id == stepId);
        if (index >= 0) {
          setState(() {
            _currentStep = index;
          });
        }
      });
    }
  }

  _MainCategoryOption? _resolveMainCategory(Map<String, dynamic> payload) {
    final int? categoryId = _intFrom(payload['main_category_id']);
    final String? interfaceType = _stringOrNull(payload['interface_type']);
    if (categoryId != null) {
      _registerPreferredCategoryIds(<int>[categoryId]);
    }
    if (interfaceType != null) {
      _registerPreferredInterfaceType(interfaceType);
    }
    if (categoryId != null) {
      for (final _MainCategoryOption option in _mainCategories) {
        if (option.id == categoryId) {
          return option;
        }
      }
    }
    if (interfaceType != null) {
      for (final _MainCategoryOption option in _mainCategories) {
        if (option.interfaceType == interfaceType) {
          return option;
        }
      }
    }
    return null;
  }

  _SubCategoryOption? _resolveSubCategory(
    _MainCategoryOption? mainCategory,
    Map<String, dynamic> payload,
  ) {
    if (mainCategory == null) {
      return null;
    }
    final int? subCategoryId = _intFrom(payload['sub_category_id']);
    if (subCategoryId == null) {
      return null;
    }
    _registerPreferredCategoryIds(<int>[subCategoryId]);
    for (final _SubCategoryOption sub in mainCategory.subCategories) {
      if (sub.id == subCategoryId) {
        return sub;
      }
    }
    return null;
  }

  Map<String, dynamic> _buildStepPayload(
    _WizardStepId step,
    Map<String, dynamic> payload,
  ) {
    switch (step) {
      case _WizardStepId.mainCategory:
        return <String, dynamic>{
          if (payload.containsKey('interface_type'))
            'interface_type': payload['interface_type'],
          if (payload.containsKey('main_category_id'))
            'main_category_id': payload['main_category_id'],
        };
      case _WizardStepId.subCategory:
        return <String, dynamic>{
          if (payload.containsKey('sub_category_id'))
            'sub_category_id': payload['sub_category_id'],
        };
      case _WizardStepId.customFields:
        return <String, dynamic>{
          if (payload.containsKey('custom_fields'))
            'custom_fields': payload['custom_fields'],
        };
      case _WizardStepId.media:
        return <String, dynamic>{
          if (payload.containsKey('media')) 'media': payload['media'],
        };
      case _WizardStepId.textDetails:
        return <String, dynamic>{
          if (payload.containsKey('title')) 'title': payload['title'],
          if (payload.containsKey('description'))
            'description': payload['description'],
          if (payload.containsKey('contact')) 'contact': payload['contact'],
          if (payload.containsKey('price')) 'price': payload['price'],
          if (payload.containsKey('currency')) 'currency': payload['currency'],
          if (payload.containsKey('product_link'))
            'product_link': payload['product_link'],
          if (payload.containsKey('review_link'))
            'review_link': payload['review_link'],
        };
      case _WizardStepId.locationInventory:
        return <String, dynamic>{
          if (payload.containsKey('location')) 'location': payload['location'],
          if (payload.containsKey('inventory'))
            'inventory': payload['inventory'],
        };
      case _WizardStepId.review:
        final Map<_WizardStepId, bool> completion =
            _calculateStepCompletion(_visibleSteps);
        return <String, dynamic>{
          'completed_steps': <String, bool>{
            for (final MapEntry<_WizardStepId, bool> entry
                in completion.entries)
              entry.key.name: entry.value,
          },
          'ready': !_hasUnsavedChanges,
        };
    }
  }

  Map<String, dynamic> _buildTemporaryMediaSnapshot() {
    final Map<String, dynamic> snapshot = <String, dynamic>{};
    final List<Map<String, dynamic>> pending =
        _mediaFiles.map((media) => media.toPayload()).toList(growable: false);
    if (pending.isNotEmpty) {
      snapshot['pending'] = pending;
    }
    if (_videoLinks.isNotEmpty) {
      snapshot['video_links'] = List<String>.from(_videoLinks);
    }
    return snapshot;
  }

  List<_PendingMedia> _composePendingMedia(
    Map<String, dynamic> media,
    Map<String, dynamic> temporaryMedia,
  ) {
    final List<_PendingMedia> result = <_PendingMedia>[];
    final Set<String> seen = <String>{};

    void addDescriptor(Map<String, dynamic> descriptor) {
      final String? type = _stringOrNull(descriptor['type']);
      final String? path = _stringOrNull(descriptor['path']);
      if (type == null || path == null) {
        return;
      }
      final String key = '$type::$path';
      if (!seen.add(key)) {
        return;
      }
      final File file = File(path);
      if (type == 'image') {
        result.add(_PendingMedia.image(file));
      } else if (type == 'video') {
        result.add(_PendingMedia.video(file));
      }
    }

    final List<dynamic>? images = media['images'] as List<dynamic>?;
    if (images != null) {
      for (final dynamic raw in images) {
        addDescriptor(_mapOf(raw));
      }
    }
    final List<dynamic>? videos = media['videos'] as List<dynamic>?;
    if (videos != null) {
      for (final dynamic raw in videos) {
        addDescriptor(_mapOf(raw));
      }
    }

    final List<dynamic>? pending = temporaryMedia['pending'] as List<dynamic>?;
    if (pending != null) {
      for (final dynamic raw in pending) {
        addDescriptor(_mapOf(raw));
      }
    }

    return result;
  }

  List<String> _collectVideoLinks(
    Map<String, dynamic> media,
    Map<String, dynamic> temporaryMedia,
  ) {
    final Set<String> links = <String>{};
    final List<dynamic>? existing = media['video_links'] as List<dynamic>?;
    if (existing != null) {
      for (final dynamic raw in existing) {
        final String? link = _stringOrNull(raw);
        if (link != null) {
          links.add(link);
        }
      }
    }
    final List<dynamic>? pending =
        temporaryMedia['video_links'] as List<dynamic>?;
    if (pending != null) {
      for (final dynamic raw in pending) {
        final String? link = _stringOrNull(raw);
        if (link != null) {
          links.add(link);
        }
      }
    }
    return links.toList(growable: false);
  }

  List<_InventoryVariation> _buildVariations(
    Map<String, dynamic> inventory,
  ) {
    final List<dynamic>? rawVariations =
        inventory['variations'] as List<dynamic>?;
    if (rawVariations == null) {
      return <_InventoryVariation>[];
    }
    return rawVariations.map((dynamic raw) {
      final Map<String, dynamic> data = _mapOf(raw);
      return _InventoryVariation(
        id: _stringOrNull(data['id']) ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _stringOrNull(data['name']) ?? '',
        sku: _stringOrNull(data['sku']) ?? '',
        priceText: _stringOrNull(data['price']) ?? '',
        quantityText: _stringOrNull(data['quantity']) ?? '',
      );
    }).toList(growable: false);
  }

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return <String, dynamic>{};
  }

  int? _intFrom(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    final String candidate = value.toString();
    return candidate.isEmpty ? null : candidate;
  }

  String? _extractDraftIdFromPending(Map<String, dynamic> pending) {
    return _stringOrNull(pending['draft_id']);
  }

  _WizardStepId? _wizardStepFromName(String? name) {
    if (name == null) {
      return null;
    }
    for (final _WizardStepId step in _WizardStepId.values) {
      if (step.name == name) {
        return step;
      }
    }
    return null;
  }

  bool get _isSheinInterface =>
      _selectedMainCategory?.interfaceType == 'shein_products';

  String get _currencyLabel =>
      _currencyOptions[_selectedCurrency] ?? (_selectedCurrency ?? 'غير محدد');

  List<Widget> get _customFieldSummary {
    final ThemeData theme = Theme.of(context);
    final List<Widget> summary = <Widget>[];
    for (final CustomFieldSchema field in _customFieldSchemas) {
      final dynamic value = _customFieldValues[field.id];
      final String formatted = field.formatValue(value);
      summary
        ..add(Text(
          field.label,
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ))
        ..add(const SizedBox(height: 4))
        ..add(Text(formatted.isEmpty ? 'غير محدد' : formatted))
        ..add(const SizedBox(height: 12));
    }
    return summary;
  }

  List<Widget> get _customFieldWidgets {
    final ThemeData theme = Theme.of(context);
    final List<Widget> widgets = <Widget>[];
    for (final CustomFieldSchema field in _customFieldSchemas) {
      final dynamic value = _customFieldValues[field.id];
      final String formatted = field.formatValue(value);
      final String displayValue = formatted.isEmpty ? 'غير محدد' : formatted;
      widgets
        ..add(Text(
          field.label,
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ))
        ..add(const SizedBox(height: 4))
        ..add(Text(displayValue))
        ..add(const SizedBox(height: 12));
    }
    return widgets;
  }

  void _addImageFiles(List<File> files) {
    if (files.isEmpty) {
      return;
    }

    bool didAdd = false;
    setState(() {
      for (final File file in files) {
        if (_mediaFiles.any((media) => media.file.path == file.path)) {
          continue;
        }
        _mediaFiles.add(_PendingMedia.image(file));
        didAdd = true;
      }
    });

    if (didAdd) {
      _clearServerFieldError('media');
      _markDirty();
    }
  }

  Future<void> _pickImages() async {
    if (_isPickingImages) {
      return;
    }
    setState(() => _isPickingImages = true);
    try {
      await _imagePicker.pick(
        context: context,
        pickMultiple: true,
        imageLimit: 25,
        maxLength: _mediaFiles.where((media) => media.isImage).length,
      );
    } catch (error) {
      if (mounted) {
        _showMessage('تعذّر اختيار الصور: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImages = false);
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_isPickingVideo) {
      return;
    }
    setState(() => _isPickingVideo = true);
    try {
      final XFile? picked = await _videoPicker.pickVideo(
        source: ImageSource.gallery,
      );
      if (picked == null) {
        return;
      }

      final File file = File(picked.path);
      bool didAdd = false;
      setState(() {
        if (_mediaFiles.any((media) => media.file.path == file.path)) {
          return;
        }
        _mediaFiles.add(_PendingMedia.video(file));
        didAdd = true;
      });

      if (didAdd) {
        _clearServerFieldError('media');
        _markDirty();
      }
    } catch (error) {
      if (mounted) {
        _showMessage('تعذّر اختيار الفيديو: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingVideo = false);
      }
    }
  }

  void _removeMediaFile(_PendingMedia media) {
    setState(() {
      _mediaFiles.remove(media);
    });
    _clearServerFieldError('media');
    _markDirty();
  }

  void _addVideoLink() {
    final String raw = _videoLinkFieldController.text.trim();
    if (raw.isEmpty) {
      _showMessage('أدخل رابط الفيديو أولًا.');
      return;
    }
    if (!_isValidVideoLink(raw)) {
      _showMessage('يرجى إدخال رابط فيديو صالح (يوتيوب أو ملف فيديو مباشر).');
      return;
    }
    if (_videoLinks.contains(raw)) {
      _showMessage('تمت إضافة هذا الرابط مسبقًا.');
      return;
    }

    setState(() {
      _videoLinks.add(raw);
      _videoLinkFieldController.clear();
    });
    _clearServerFieldError('media');
    FocusScope.of(context).unfocus();
    _markDirty();
  }

  void _removeVideoLink(String link) {
    setState(() {
      _videoLinks.remove(link);
    });
    _clearServerFieldError('media');
    _markDirty();
  }

  bool _isValidVideoLink(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return false;
    }
    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    if (HelperUtils.isYoutubeVideo(trimmed)) {
      return true;
    }
    final String host = uri.host.toLowerCase();
    if (host.contains('vimeo.com') || host.contains('dailymotion.com')) {
      return true;
    }
    const List<String> allowedExtensions = <String>[
      '.mp4',
      '.mov',
      '.m4v',
      '.webm'
    ];
    return allowedExtensions.any(
      (String ext) => uri.path.toLowerCase().endsWith(ext),
    );
  }

  bool _validateMediaStep() {
    if (_mediaFiles.isEmpty && _videoLinks.isEmpty) {
      _showMessage('يرجى إضافة صورة أو فيديو واحد على الأقل قبل المتابعة.');
      return false;
    }
    for (final String link in _videoLinks) {
      if (!_isValidVideoLink(link)) {
        _showMessage('أحد روابط الفيديو غير صالح. يرجى التحقق منه.');
        return false;
      }
    }
    return true;
  }

  bool _validateTextDetailsStep() {
    final FormState? form = _textDetailsFormKey.currentState;
    if (form == null) {
      return true;
    }
    if (!form.validate()) {
      _showMessage('يرجى التحقق من الحقول النصية قبل المتابعة.');
      return false;
    }
    return true;
  }

  bool _validateStepFive() {
    bool isValid = true;
    if (_requiresLocation) {
      isValid = _validateLocationSection(showMessages: true) && isValid;
    } else {
      _locationFormKey.currentState?.validate();
    }
    final bool shouldValidateInventory =
        _requiresInventory || _inventoryVariations.isNotEmpty;
    if (shouldValidateInventory) {
      isValid = _validateInventorySection(showMessages: true) && isValid;
    } else {
      _inventoryFormKey.currentState?.validate();
    }
    return isValid;
  }

  bool _validateLocationSection({required bool showMessages}) {
    final FormState? form = _locationFormKey.currentState;
    if (form == null) {
      if (_requiresLocation && showMessages) {
        _showMessage('يرجى إكمال بيانات الموقع قبل المتابعة.');
      }
      return !_requiresLocation;
    }
    final bool valid = form.validate();
    if (!valid && showMessages) {
      _showMessage('يرجى إكمال بيانات الموقع قبل المتابعة.');
    }
    return valid;
  }

  bool _validateInventorySection({required bool showMessages}) {
    final FormState? form = _inventoryFormKey.currentState;
    final bool fieldsValid = form?.validate() ?? true;
    final bool hasVariations = _inventoryVariations.isNotEmpty;
    final bool meetsMinimum = !_requiresInventory || hasVariations;
    final bool valid = fieldsValid && meetsMinimum;
    if (!valid && showMessages) {
      final String message = !hasVariations && _requiresInventory
          ? 'يرجى إضافة تنويعة واحدة على الأقل للمخزون.'
          : 'يرجى تصحيح بيانات التنويعات قبل المتابعة.';
      _showMessage(message);
    }
    return valid;
  }

  String? _validateTitle(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.length < 10 || trimmed.length > 90) {
      return 'العنوان يجب أن يكون بين 10 و90 حرفًا.';
    }
    return _serverFieldErrors['title'];
  }

  String? _validateDescription(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.length < 30) {
      return 'الوصف يجب أن يحتوي على 30 حرفًا على الأقل.';
    }
    if (trimmed.length > 1200) {
      return 'الوصف طويل جدًا. يرجى تقليصه إلى 1200 حرف كحد أقصى.';
    }
    return _serverFieldErrors['description'];
  }

  String? _validatePrice(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'يرجى إدخال السعر.';
    }
    final num? parsed = num.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      return 'يرجى إدخال سعر صالح أكبر من صفر.';
    }
    return _serverFieldErrors['price'];
  }

  String? _validateContact(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'يرجى إدخال رقم للتواصل.';
    }
    final String normalized =
        trimmed.startsWith('+') ? trimmed.substring(1) : trimmed;
    if (normalized.length < 6 || normalized.length > 15) {
      return 'رقم التواصل يجب أن يكون بين 6 و15 رقمًا.';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) {
      return 'رقم التواصل يجب أن يحتوي على أرقام فقط بعد المقدمة.';
    }
    return _serverFieldErrors['contact'];
  }

  String? _validateSheinProductLink(String? value) =>
      _validateSheinUrlInternal(value, 'product_link');

  String? _validateSheinReviewLink(String? value) =>
      _validateSheinUrlInternal(value, 'review_link');

  String? _validateSheinUrlInternal(String? value, String key) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _serverFieldErrors[key];
    }
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.scheme == 'file') {
      return 'يرجى إدخال رابط صالح.';
    }
    return _serverFieldErrors[key];
  }

  Future<void> _autoSaveDraft() async {
    if (!_hasUnsavedChanges || _isSavingDraft) {
      return;
    }

    final List<_WizardStep> steps = _visibleSteps;
    final int currentIndex = _clampCurrentStepIndex(steps);
    final _WizardStepId currentStepId =
        steps.isEmpty ? _WizardStepId.mainCategory : steps[currentIndex].id;
    final String previousCacheKey =
        _cacheKeyFor(_draftId ?? widget.initialDraftId);

    final Map<String, dynamic> payload = _buildAdPayload(isDraft: true);
    final Map<String, dynamic> stepPayload =
        _buildStepPayload(currentStepId, payload);
    final Map<String, dynamic> temporaryMedia = _buildTemporaryMediaSnapshot();

    setState(() => _isSavingDraft = true);
    try {
      await _syncPendingDraftIfNeeded(cacheKey: previousCacheKey);
      final AdDraftModel draft = await _adPublishingService.saveDraft(
        draftId: _draftId,
        payload: payload,
        stepPayload: stepPayload,
        temporaryMedia: temporaryMedia,
        currentStep: currentStepId.name,
        cacheKey: previousCacheKey,
      );

      final String newCacheKey =
          _cacheKeyFor(draft.id ?? _draftId ?? widget.initialDraftId);
      if (newCacheKey != previousCacheKey) {
        await _adPublishingService.migrateCache(
          from: previousCacheKey,
          to: newCacheKey,
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _draftId = draft.id ?? _draftId;

        _hasUnsavedChanges = false;
      });
    } on DraftSaveOfflineException {
      if (mounted) {
        _showMessage(
            'تم حفظ التغييرات محليًا. سيتم المزامنة عند توفر الاتصال.');
      }
    } on DioException catch (error) {
      if (mounted) {
        _showMessage('تعذّر حفظ المسودة: ${error.message ?? error.toString()}');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('تعذّر حفظ المسودة: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDraft = false);
      }
    }
  }

  void _goNext() {
    final List<_WizardStep> steps = _visibleSteps;
    if (steps.isEmpty) {
      return;
    }
    final int currentIndex = _clampCurrentStepIndex(steps);
    if (currentIndex >= steps.length - 1) {
      return;
    }
    final _WizardStep currentStep = steps[currentIndex];
    if (!_canProceedFromStep(currentStep.id)) {
      return;
    }
    setState(() => _currentStep = currentIndex + 1);
  }

  void _goPrevious() {
    final List<_WizardStep> steps = _visibleSteps;
    if (steps.isEmpty) {
      return;
    }
    final int currentIndex = _clampCurrentStepIndex(steps);
    if (currentIndex == 0) {
      return;
    }
    setState(() => _currentStep = currentIndex - 1);
  }

  void _jumpToStep(_WizardStepId stepId) {
    final List<_WizardStep> steps = _visibleSteps;
    if (steps.isEmpty) {
      return;
    }
    final int index = steps.indexWhere((step) => step.id == stepId);
    if (index < 0) {
      return;
    }
    setState(() => _currentStep = index);
  }

  bool _canProceedFromStep(_WizardStepId stepId) {
    switch (stepId) {
      case _WizardStepId.mainCategory:
        if (_selectedMainCategory == null) {
          _showMessage('يرجى اختيار الفئة الرئيسية قبل المتابعة.');
          return false;
        }
        return true;
      case _WizardStepId.subCategory:
        final _MainCategoryOption? mainCategory = _selectedMainCategory;
        final bool hasSubCategories =
            mainCategory != null && mainCategory.subCategories.isNotEmpty;
        if (hasSubCategories && _selectedSubCategory == null) {
          _showMessage('يرجى اختيار الفئة الفرعية قبل المتابعة.');
          return false;
        }
        return true;
      case _WizardStepId.customFields:
        final bool valid =
            _customFieldsFormKey.currentState?.validate() ?? true;
        if (!valid) {
          _showMessage('يرجى إكمال الحقول المخصّصة المطلوبة قبل المتابعة.');
          return false;
        }
        return true;
      case _WizardStepId.media:
        return _validateMediaStep();
      case _WizardStepId.textDetails:
        return _validateTextDetailsStep();
      case _WizardStepId.locationInventory:
        return _validateStepFive();
      case _WizardStepId.review:
        return true;
    }
  }

  int _clampCurrentStepIndex(List<_WizardStep> steps) {
    if (steps.isEmpty) {
      return 0;
    }
    final int maxIndex = steps.length - 1;
    if (_currentStep < 0) {
      return 0;
    }
    if (_currentStep > maxIndex) {
      return maxIndex;
    }
    return _currentStep;
  }

  int _effectiveCurrentStepIndex(List<_WizardStep> steps) {
    final int clamped = _clampCurrentStepIndex(steps);
    if (clamped != _currentStep && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentStep = clamped);
        }
      });
    }
    return clamped;
  }

  void _recomputeCurrentStepBounds() {
    final List<_WizardStep> steps = _visibleSteps;
    if (steps.isEmpty) {
      _currentStep = 0;
      return;
    }
    final int maxIndex = steps.length - 1;
    if (_currentStep > maxIndex) {
      _currentStep = maxIndex;
    }
    if (_currentStep < 0) {
      _currentStep = 0;
    }
  }

  Map<_WizardStepId, bool> _calculateStepCompletion(List<_WizardStep> steps) {
    final Map<_WizardStepId, bool> completion = <_WizardStepId, bool>{};
    for (final _WizardStep step in steps) {
      if (step.id == _WizardStepId.review) {
        continue;
      }
      completion[step.id] = _isNonReviewStepComplete(step.id);
    }
    if (steps.any((step) => step.id == _WizardStepId.review)) {
      final bool prerequisitesComplete = steps
          .where((step) => step.id != _WizardStepId.review)
          .every((step) => completion[step.id] ?? false);
      completion[_WizardStepId.review] =
          prerequisitesComplete && !_hasUnsavedChanges;
    }
    return completion;
  }

  Color _segmentColor(
    ColorScheme colors,
    bool isCompleted,
    bool isCurrent,
    bool isBeforeCurrent,
  ) {
    if (isCompleted || isBeforeCurrent) {
      return colors.territoryColor;
    }
    if (isCurrent) {
      return colors.territoryColor.withOpacity(0.6);
    }
    return colors.borderColor.withOpacity(0.28);
  }

  bool _isNonReviewStepComplete(_WizardStepId id) {
    switch (id) {
      case _WizardStepId.mainCategory:
        return _selectedMainCategory != null;
      case _WizardStepId.subCategory:
        final _MainCategoryOption? mainCategory = _selectedMainCategory;
        if (mainCategory == null) {
          return false;
        }
        if (mainCategory.subCategories.isEmpty) {
          return true;
        }
        return _selectedSubCategory != null;
      case _WizardStepId.customFields:
        if (_customFieldSchemas.isEmpty) {
          return true;
        }
        for (final CustomFieldSchema field in _customFieldSchemas) {
          if (field.isRequired &&
              !_hasCustomFieldValue(field, _customFieldValues[field.id])) {
            return false;
          }
        }
        return true;
      case _WizardStepId.media:
        if (_mediaFiles.isEmpty && _videoLinks.isEmpty) {
          return false;
        }
        for (final String link in _videoLinks) {
          if (!_isValidVideoLink(link)) {
            return false;
          }
        }
        return true;
      case _WizardStepId.textDetails:
        final bool titleValid = _validateTitle(_titleController.text) == null;
        final bool descriptionValid =
            _validateDescription(_descriptionController.text) == null;
        final bool priceValid = _validatePrice(_priceController.text) == null;
        final bool contactValid =
            _validateContact(_contactController.text) == null;
        final bool currencySelected = _selectedCurrency != null;
        final bool sheinProductValid = !_isSheinInterface ||
            _validateSheinProductLink(_sheinProductLinkController.text) == null;
        final bool sheinReviewValid =
            _validateSheinReviewLink(_sheinReviewLinkController.text) == null;
        return titleValid &&
            descriptionValid &&
            priceValid &&
            contactValid &&
            currencySelected &&
            sheinProductValid &&
            sheinReviewValid;
      case _WizardStepId.locationInventory:
        final bool requiresLocation = _requiresLocation;
        final bool requiresInventory = _requiresInventory;
        final bool locationComplete =
            !requiresLocation || _isLocationDataComplete();
        final bool inventoryComplete =
            !requiresInventory || _isInventoryDataComplete();
        return locationComplete && inventoryComplete;
      case _WizardStepId.review:
        return !_hasUnsavedChanges;
    }
  }

  bool _hasCustomFieldValue(CustomFieldSchema field, dynamic value) {
    if (value == null) {
      return false;
    }
    if (field.type == CustomFieldType.multiChoice) {
      if (value is Iterable) {
        return value
            .map((dynamic element) => element.toString().trim())
            .where((String element) => element.isNotEmpty)
            .isNotEmpty;
      }
      return false;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    return true;
  }

  bool _isLocationDataComplete() {
    final String address = _locationAddressController.text.trim();
    final bool hasAddress = address.isNotEmpty;
    final bool latitudeValid =
        _validateLatitudeField(_locationLatitudeController.text) == null;
    final bool longitudeValid =
        _validateLongitudeField(_locationLongitudeController.text) == null;
    return hasAddress && latitudeValid && longitudeValid;
  }

  bool _isInventoryDataComplete() {
    if (_inventoryVariations.isEmpty) {
      return false;
    }
    for (final _InventoryVariation variation in _inventoryVariations) {
      if (!variation.isComplete) {
        return false;
      }
    }
    return true;
  }

  String? _inventoryFieldError(int index, String field) {
    return _serverFieldErrors['inventory.variations.$index.$field'];
  }

  String? _blockErrorFor(String prefix) {
    for (final MapEntry<String, String> entry in _serverFieldErrors.entries) {
      if (entry.key == prefix || entry.key.startsWith('$prefix.')) {
        return entry.value;
      }
    }
    return null;
  }

  String? _anyBlockErrorFor(Iterable<String> prefixes) {
    for (final String prefix in prefixes) {
      final String? error = _blockErrorFor(prefix);
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_WizardStep> steps = _visibleSteps;
    final int currentStepIndex = _effectiveCurrentStepIndex(steps);
    final Map<_WizardStepId, bool> completionByStep =
        _calculateStepCompletion(steps);
    final double stepProgress =
        steps.isEmpty ? 0 : (currentStepIndex + 1) / steps.length;
    final int progressPercent = (stepProgress * 100).clamp(0, 100).round();
    final bool isCurrentStepOptional =
        steps.isNotEmpty ? steps[currentStepIndex].isOptional : false;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = context.color;
    final String dynamicTitle = steps.isEmpty
        ? 'معالج إنشاء إعلان'
        : '${steps[currentStepIndex].label} • $progressPercent%';

    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: dynamicTitle,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _isLoadingDraft ? null : stepProgress,
                    minHeight: 6,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colors.territoryColor),
                    backgroundColor: colors.borderColor
                        .withOpacity(_isLoadingDraft ? 0.2 : 0.12),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      for (int i = 0; i < steps.length; i++)
                        Expanded(
                          child: Container(
                            margin: EdgeInsetsDirectional.only(
                              end: i == steps.length - 1 ? 0 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: _segmentColor(
                                colors,
                                completionByStep[steps[i].id] ?? false,
                                i == currentStepIndex,
                                i < currentStepIndex,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (steps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.borderColor.withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          'المرحلة ${currentStepIndex + 1}/${steps.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.textDefaultColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentStepOptional
                              ? colors.deactivateColor.withOpacity(0.16)
                              : colors.territoryColor.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isCurrentStepOptional ? 'اختياري' : 'مطلوب',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isCurrentStepOptional
                                ? colors.textDefaultColor
                                : colors.territoryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _buildStepBody(steps, currentStepIndex)),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16.0,
          12.0,
          16.0,
          12.0 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSavingDraft ? null : _autoSaveDraft,
                    child: _isSavingDraft
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('حفظ كمسودة'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('إلغاء'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: currentStepIndex == 0 ? null : _goPrevious,
                    child: const Text('رجوع'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPublishing
                        ? null
                        : (currentStepIndex == steps.length - 1
                            ? _publishAd
                            : _goNext),
                    child: currentStepIndex == steps.length - 1
                        ? (_isPublishing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('نشر'))
                        : const Text('التالي'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value,
      {bool multiline = false}) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium,
            maxLines: multiline ? 4 : null,
            overflow: multiline ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildReviewCard({
    required String title,
    required List<Widget> content,
    _WizardStepId? step,
    Widget? status,
    String? errorMessage,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                if (status != null) ...[
                  status,
                  const SizedBox(width: 8),
                ],
                if (step != null)
                  TextButton.icon(
                    onPressed: _isPublishing ? null : () => _jumpToStep(step),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('تحرير'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (content.isEmpty)
              Text('لا توجد بيانات متاحة.', style: theme.textTheme.bodySmall)
            else
              ...content,
            if (errorMessage != null && errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    String displayValue(String value, [String placeholder = 'غير محدد']) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? placeholder : trimmed;
    }

    final List<_PendingMedia> images =
        _mediaFiles.where((media) => media.isImage).toList(growable: false);
    final List<_PendingMedia> videos =
        _mediaFiles.where((media) => media.isVideo).toList(growable: false);
    final bool isShein = _isSheinInterface;
    final String currencyLabel = _currencyLabel;
    final Map<String, dynamic>? locationSummary = _buildLocationPayload();
    final List<_InventoryVariation> inventorySummary =
        List<_InventoryVariation>.from(_inventoryVariations);

    final bool locationComplete =
        !_requiresLocation || _isLocationDataComplete();
    final bool inventoryComplete =
        !_requiresInventory || _isInventoryDataComplete();

    final List<Widget> categoryContent = <Widget>[
      _buildReviewItem(
          'الفئة الرئيسية', _selectedMainCategory?.name ?? 'غير محدد'),
      _buildReviewItem(
          'الفئة الفرعية', _selectedSubCategory?.name ?? 'غير محدد'),
      _buildReviewItem(
          'واجهة العرض', _selectedMainCategory?.interfaceType ?? 'غير محدد'),
    ];

    final List<Widget> textDetailContent = <Widget>[
      _buildReviewItem('العنوان', displayValue(_titleController.text)),
      _buildReviewItem('الوصف', displayValue(_descriptionController.text),
          multiline: true),
      _buildReviewItem(
        'السعر',
        displayValue(
          _priceController.text.isEmpty
              ? ''
              : '${_priceController.text.trim()} $currencyLabel',
        ),
      ),
      _buildReviewItem('رقم التواصل', displayValue(_contactController.text)),
    ];
    if (isShein) {
      textDetailContent.add(
        _buildReviewItem(
          'رابط المنتج',
          displayValue(_sheinProductLinkController.text, 'غير متوفر'),
          multiline: true,
        ),
      );
      textDetailContent.add(
        _buildReviewItem(
          'رابط المراجعة',
          displayValue(_sheinReviewLinkController.text, 'غير متوفر'),
          multiline: true,
        ),
      );
    }

    final List<Widget> customFieldContent;
    if (_customFieldSchemas.isEmpty) {
      customFieldContent = <Widget>[
        Text('لا توجد حقول مخصّصة لهذه الفئة.',
            style: theme.textTheme.bodySmall),
      ];
    } else if (_customFieldValues.isEmpty) {
      customFieldContent = <Widget>[
        Text('لم يتم إدخال بيانات الحقول المخصّصة.',
            style: theme.textTheme.bodySmall),
      ];
    } else {
      customFieldContent = _customFieldSchemas.map((CustomFieldSchema field) {
        final dynamic value = _customFieldValues[field.id];
        final String formatted = field.formatValue(value);
        return _buildReviewItem(
          field.label,
          displayValue(formatted, 'غير محدد'),
          multiline: true,
        );
      }).toList(growable: false);
    }

    final List<Widget> mediaContent = <Widget>[];
    if (images.isEmpty && videos.isEmpty && _videoLinks.isEmpty) {
      mediaContent
          .add(Text('لم تتم إضافة وسائط.', style: theme.textTheme.bodySmall));
    } else {
      if (images.isNotEmpty) {
        mediaContent.add(_buildReviewItem('عدد الصور', '${images.length}'));
      }
      if (videos.isNotEmpty) {
        mediaContent
            .add(_buildReviewItem('عدد الفيديوهات', '${videos.length}'));
      }
      if (_videoLinks.isNotEmpty) {
        mediaContent.add(
            _buildReviewItem('روابط الفيديو', '${_videoLinks.length} رابط'));
        mediaContent.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _videoLinks
                  .map((String link) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(link, style: theme.textTheme.bodySmall),
                      ))
                  .toList(growable: false),
            ),
          ),
        );
      }
    }

    final List<Widget> locationContent;
    if (locationSummary == null || locationSummary.isEmpty) {
      locationContent = <Widget>[
        Text(
          _requiresLocation
              ? 'لم يتم تحديد الموقع بعد. هذه الخطوة مطلوبة.'
              : 'لم يتم تحديد موقع (اختياري).',
          style: theme.textTheme.bodySmall,
        ),
      ];
    } else {
      locationContent = <Widget>[
        _buildReviewItem(
          'العنوان',
          displayValue(locationSummary['address']?.toString() ?? ''),
          multiline: true,
        ),
        _buildReviewItem(
          'خط العرض',
          displayValue(locationSummary['latitude']?.toString() ?? ''),
        ),
        _buildReviewItem(
          'خط الطول',
          displayValue(locationSummary['longitude']?.toString() ?? ''),
        ),
      ];
    }

    final List<Widget> inventoryContent;
    if (inventorySummary.isEmpty) {
      inventoryContent = <Widget>[
        Text(
          _requiresInventory
              ? 'لم يتم إضافة أي تنويعات بعد. هذه الخطوة مطلوبة قبل النشر.'
              : 'لم يتم إضافة تنويعات (اختياري).',
          style: theme.textTheme.bodySmall,
        ),
      ];
    } else {
      inventoryContent = <Widget>[
        for (int i = 0; i < inventorySummary.length; i++)
          Padding(
            padding: EdgeInsets.only(
                bottom: i == inventorySummary.length - 1 ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayValue(
                    inventorySummary[i].name,
                    'تنويعة ${i + 1}',
                  ),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'السعر: ${displayValue(inventorySummary[i].priceText.isEmpty ? '' : '${inventorySummary[i].priceText.trim()} $currencyLabel', 'غير محدد')}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'الكمية: ${displayValue(inventorySummary[i].quantityText, 'غير محددة')}',
                  style: theme.textTheme.bodySmall,
                ),
                if (inventorySummary[i].sku.trim().isNotEmpty)
                  Text('SKU: ${inventorySummary[i].sku.trim()}',
                      style: theme.textTheme.bodySmall),
              ],
            ),
          ),
      ];
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildReviewCard(
          title: 'الفئات',
          step: _WizardStepId.mainCategory,
          content: categoryContent,
          errorMessage: _anyBlockErrorFor(const <String>[
            'main_category_id',
            'sub_category_id',
            'interface_type'
          ]),
        ),
        _buildReviewCard(
          title: 'التفاصيل النصية',
          step: _WizardStepId.textDetails,
          content: textDetailContent,
          errorMessage: _anyBlockErrorFor(
            const <String>[
              'title',
              'description',
              'price',
              'contact',
              'currency',
              'product_link',
              'review_link'
            ],
          ),
        ),
        if (_customFieldSchemas.isNotEmpty)
          _buildReviewCard(
            title: 'الحقول المخصّصة',
            step: _WizardStepId.customFields,
            content: customFieldContent,
            errorMessage: _blockErrorFor('custom_fields'),
          ),
        _buildReviewCard(
          title: 'الوسائط',
          step: _WizardStepId.media,
          content: mediaContent,
          errorMessage: _blockErrorFor('media'),
        ),
        if (_requiresLocation || locationSummary != null)
          _buildReviewCard(
            title: 'الموقع',
            step: _WizardStepId.locationInventory,
            status: _buildStatusChip(
              locationComplete ? 'مكتمل' : 'ناقص',
              locationComplete ? colors.tertiary : colors.error,
            ),
            content: locationContent,
            errorMessage: _blockErrorFor('location'),
          ),
        if (_requiresInventory || inventorySummary.isNotEmpty)
          _buildReviewCard(
            title: 'تنويعات المخزون',
            step: _WizardStepId.locationInventory,
            status: _buildStatusChip(
              inventoryComplete ? 'مكتمل' : 'ناقص',
              inventoryComplete ? colors.tertiary : colors.error,
            ),
            content: inventoryContent,
            errorMessage: _blockErrorFor('inventory'),
          ),
      ],
    );
  }

  Widget _buildStepBody(List<_WizardStep> steps, int currentIndex) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final _WizardStep currentStep = steps[currentIndex];
    switch (currentStep.id) {
      case _WizardStepId.mainCategory:
        return _buildMainCategoryStep();
      case _WizardStepId.subCategory:
        return _buildSubCategoryStep();
      case _WizardStepId.customFields:
        return _buildCustomFieldsStep();
      case _WizardStepId.media:
        return _buildMediaStep();

      case _WizardStepId.textDetails:
        return _buildTextDetailsStep();
      case _WizardStepId.locationInventory:
        return _buildStepFiveBody();
      case _WizardStepId.review:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepFiveBody() {
    if (_requiresLocation && _requiresInventory) {
      return _buildCombinedLocationInventoryStep();
    }
    if (_requiresLocation) {
      return _buildLocationStep();
    }
    if (_requiresInventory) {
      return _buildInventoryStep();
    }
    return _buildOptionalExtrasStep();
  }

  Widget _buildCombinedLocationInventoryStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: _locationFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildLocationFields(),
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _inventoryFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildInventoryFields(),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: _locationFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildLocationFields(),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: _inventoryFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildInventoryFields(),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionalExtrasStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          'لا تتطلب هذه المرحلة إدخال بيانات إضافية. يمكنك مراجعة التفاصيل أو العودة لأي خطوة سابقة.',
        ),
      ],
    );
  }

  List<Widget> _buildLocationFields() {
    final ThemeData theme = Theme.of(context);
    return <Widget>[
      Text('تحديد موقع الإعلان', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      Text(
        'أدخل العنوان والإحداثيات التقريبية للموقع لضمان ظهور الإعلان في المكان الصحيح.',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _locationAddressController,
        decoration: const InputDecoration(
          labelText: 'العنوان التفصيلي',
          helperText: 'مثال: صنعاء، شارع الخمسين، جوار المستشفى.',
        ),
        textInputAction: TextInputAction.next,
        validator: (String? value) {
          final String trimmed = value?.trim() ?? '';
          if (trimmed.isEmpty) {
            return 'يرجى إدخال العنوان.';
          }
          return _serverFieldErrors['location.address'];
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _locationLatitudeController,
        decoration: const InputDecoration(labelText: 'خط العرض'),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        validator: _validateLatitudeField,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _locationLongitudeController,
        decoration: const InputDecoration(labelText: 'خط الطول'),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        validator: _validateLongitudeField,
      ),
    ];
  }

  List<Widget> _buildInventoryFields() {
    final ThemeData theme = Theme.of(context);
    final bool requiresInventory = _requiresInventory;
    final bool hasVariations = _inventoryVariations.isNotEmpty;
    return <Widget>[
      Text('إدارة تنويعات المخزون', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      Text(
        'أضف التنويعات المختلفة للمنتج مع السعر والكمية لضمان توفر المعلومات للمشترين.',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      if (!hasVariations)
        _buildInfoCard(
          requiresInventory
              ? 'لا يمكن المتابعة دون إضافة تنويعة واحدة على الأقل.'
              : 'لم يتم إضافة تنويعات بعد. يمكنك المتابعة أو إضافة تنويعات اختيارية.',
        ),
      if (hasVariations)
        ..._inventoryVariations.asMap().entries.map(
            (MapEntry<int, _InventoryVariation> entry) =>
                _buildVariationCard(entry.value, requiresInventory, entry.key)),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _addInventoryVariation,
          icon: const Icon(Icons.add),
          label: const Text('إضافة تنويعة'),
        ),
      ),
    ];
  }

  Widget _buildVariationCard(
    _InventoryVariation variation,
    bool requiresInventory,
    int index,
  ) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'تنويعة جديدة',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeInventoryVariation(variation),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'حذف التنويعة',
                ),
              ],
            ),
            TextFormField(
              key: ValueKey<String>('variation_name_${variation.id}'),
              initialValue: variation.name,
              decoration: InputDecoration(
                labelText: 'اسم التنويعة',
                errorText: _inventoryFieldError(index, 'name'),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (String value) {
                setState(() => variation.name = value);
                _clearServerFieldError('inventory.variations.$index.name');
                _markDirty();
              },
              validator: (String? value) {
                final String trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty && requiresInventory) {
                  return 'يرجى إدخال اسم للتنويعة.';
                }
                return _inventoryFieldError(index, 'name');
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey<String>('variation_sku_${variation.id}'),
              initialValue: variation.sku,
              decoration: InputDecoration(
                labelText: 'المعرف (SKU)',
                helperText: 'اختياري لتتبع المخزون الداخلي.',
                errorText: _inventoryFieldError(index, 'sku'),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (String value) {
                setState(() => variation.sku = value);
                _markDirty();
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey<String>('variation_price_${variation.id}'),
              initialValue: variation.priceText,
              decoration: InputDecoration(
                labelText: 'السعر',
                errorText: _inventoryFieldError(index, 'price'),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (String value) {
                setState(() => variation.priceText = value);
                _clearServerFieldError('inventory.variations.$index.price');
                _markDirty();
              },
              validator: (String? value) {
                final String trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return requiresInventory ? 'يرجى إدخال السعر.' : null;
                }
                final double? parsed = double.tryParse(trimmed);
                if (parsed == null || parsed <= 0) {
                  return 'يرجى إدخال سعر صالح أكبر من صفر.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey<String>('variation_quantity_${variation.id}'),
              initialValue: variation.quantityText,
              decoration: InputDecoration(
                labelText: 'الكمية المتاحة',
                errorText: _inventoryFieldError(index, 'quantity'),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
              onChanged: (String value) {
                setState(() => variation.quantityText = value);
                _clearServerFieldError('inventory.variations.$index.quantity');
                _markDirty();
              },
              validator: (String? value) {
                final String trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return requiresInventory ? 'يرجى إدخال الكمية.' : null;
                }
                final int? parsed = int.tryParse(trimmed);
                if (parsed == null || parsed < 0) {
                  return 'يرجى إدخال كمية صحيحة (0 أو أكثر).';
                }
                return _inventoryFieldError(index, 'quantity');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addInventoryVariation() {
    setState(() {
      _inventoryVariations = <_InventoryVariation>[
        ..._inventoryVariations,
        _InventoryVariation(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
        ),
      ];
    });
    _clearServerFieldError('inventory');
    _inventoryFormKey.currentState?.validate();
    _markDirty();
  }

  void _removeInventoryVariation(_InventoryVariation variation) {
    setState(() {
      _inventoryVariations = _inventoryVariations
          .where((_) => _.id != variation.id)
          .toList(growable: false);
    });
    _clearServerFieldError('inventory');
    _inventoryFormKey.currentState?.validate();
    _markDirty();
  }

  String? _validateLatitudeField(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _requiresLocation ? 'يرجى إدخال خط العرض.' : null;
    }
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < -90 || parsed > 90) {
      return 'القيمة يجب أن تكون بين -90 و 90.';
    }
    return _serverFieldErrors['location.latitude'];
  }

  String? _validateLongitudeField(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _requiresLocation ? 'يرجى إدخال خط الطول.' : null;
    }
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < -180 || parsed > 180) {
      return 'القيمة يجب أن تكون بين -180 و 180.';
    }
    return _serverFieldErrors['location.longitude'];
  }

  Widget _buildMainCategoryStep() {
    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
        builder: (BuildContext context, FetchCategoryState state) {
          final bool isLoading = state is FetchCategoryInProgress;

          if (state is FetchCategoryFailure && _mainCategories.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildErrorCard(
                  message: 'تعذّر تحميل الفئات. حاول مرة أخرى.',
                  onRetry: _retryFetchCategories,
                ),
              ],
            );
          }

          if (_mainCategories.isEmpty) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPlaceholderMessage(
                    'لا توجد فئات متاحة لهذا الحساب حاليًا.'),
                if (state is FetchCategoryFailure)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildErrorCard(
                      message: 'تعذّر تحميل الفئات. حاول مجددًا.',
                      onRetry: _retryFetchCategories,
                    ),
                  ),
              ],
            );
          }

          final ThemeData theme = Theme.of(context);
          final _MainCategoryOption? selected = _selectedMainCategory;

          return ListView(
              padding: const EdgeInsets.all(16),
              children: [
              const Text(
              'اختر الفئة الرئيسية الأنسب لنوع حسابك. يمكنك تعديل الاختيار لاحقًا.'),
          if (_preferredInterfaceTypeOriginal != null)
          Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
          'واجهة العرض الحالية: ${_preferredInterfaceTypeOriginal}',
          style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          ),
          ),
          ),
          if (isLoading)
          const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
          value: selected?.id,
          decoration: const InputDecoration(
          labelText: 'الفئة الرئيسية',
          border: OutlineInputBorder(),
          ),
          items: _mainCategories
              .map((category) => DropdownMenuItem<int>(
          value: category.id,
          child: Text(category.name),
          ))
              .toList(growable: false),
          onChanged: (int? value) {
          final _MainCategoryOption? option =
          _findMainCategoryById(_mainCategories, value);
          if (option != null) {
          _onMainCategorySelected(option);
          }
              },
            ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _mainCategories
                      .map(_buildMainCategoryChip)
                      .toList(growable: false),
                ),
                if (state is FetchCategoryFailure && _mainCategories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildErrorCard(
                      message: 'حدث خطأ أثناء تحديث الفئات. حاول مرة أخرى.',
                      onRetry: _retryFetchCategories,
                    ),
                  ),
              ],
          );
        },
    );
  }

  Widget _buildMainCategoryChip(_MainCategoryOption category) {
    final bool isSelected = _selectedMainCategory?.id == category.id;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String interfaceLabel =
    category.interfaceType.isEmpty ? 'غير محددة' : category.interfaceType;
    final int subCount = category.subCategories.length;

    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => _onMainCategorySelected(category),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      label: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'واجهة: $interfaceLabel',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              'الفئات الفرعية: $subCount',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryStep() {
    final _MainCategoryOption? mainCategory = _selectedMainCategory;
    if (mainCategory == null) {
      return _buildPlaceholderMessage(
          'يرجى اختيار الفئة الرئيسية أولًا لمتابعة اختيار الفئة الفرعية.');
    }

    final List<_SubCategoryOption> subCategories = mainCategory.subCategories;
    if (subCategories.isEmpty) {
      return _buildPlaceholderMessage('لا توجد فئات فرعية متاحة لهذه الفئة.');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('اختر الفئة الفرعية المناسبة لإعلانك ضمن ${mainCategory.name}.'),
        const SizedBox(height: 12),
        for (final _SubCategoryOption subCategory in subCategories)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<_SubCategoryOption>(
              value: subCategory,
              groupValue: _selectedSubCategory,
              title: Text(subCategory.name),
              onChanged: (value) {
                if (value == null) return;
                _onSubCategorySelected(value);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCustomFieldsStep() {
    final _MainCategoryOption? mainCategory = _selectedMainCategory;
    final _SubCategoryOption? subCategory = _selectedSubCategory;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('املأ الحقول المخصّصة المرتبطة بالفئة الفرعية المختارة.'),
        const SizedBox(height: 12),
        if (mainCategory == null)
          _buildInfoCard(
              'يرجى اختيار الفئة الرئيسية قبل الانتقال إلى الحقول المخصّصة.')
        else if (subCategory == null)
          _buildInfoCard('يرجى اختيار الفئة الفرعية لمتابعة الحقول المخصّصة.')
        else if (_isLoadingCustomFields)
          const Center(
              child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          ))
        else if (_customFieldError != null)
          _buildErrorCard(
            message: 'تعذّر تحميل الحقول المخصّصة. حاول مجددًا.',
            onRetry: _fetchCustomFieldSchema,
          )
        else
          DynamicCustomFieldsForm(
            key: _customFieldsFormKey,
            fields: _customFieldSchemas,
            values: Map<String, dynamic>.unmodifiable(_customFieldValues),
            onChanged: (Map<String, dynamic> values) {
              setState(() {
                _customFieldValues = values;
              });
              _markDirty();
            },
          ),
      ],
    );
  }

  void _onMainCategorySelected(_MainCategoryOption category) {
    if (_selectedMainCategory?.id == category.id) {
      return;
    }
    _registerPreferredInterfaceType(category.interfaceType);
    _preferredCategoryPath
      ..clear()
      ..add(category.id);
    setState(() {
      _selectedMainCategory = category;
      _selectedSubCategory = null;
      _customFieldSchemas = const <CustomFieldSchema>[];
      _customFieldValues = <String, dynamic>{};
      _customFieldError = null;
      _isLoadingCustomFields = false;
      _inventoryVariations = <_InventoryVariation>[];
      if (category.interfaceType != 'shein_products') {
        if (_sheinProductLinkController.text.isNotEmpty) {
          _sheinProductLinkController.clear();
        }
        if (_sheinReviewLinkController.text.isNotEmpty) {
          _sheinReviewLinkController.clear();
        }
      }
      _recomputeCurrentStepBounds();
    });
    _locationFormKey.currentState?.reset();
    _inventoryFormKey.currentState?.reset();
    if (_locationAddressController.text.isNotEmpty) {
      _locationAddressController.clear();
    }
    if (_locationLatitudeController.text.isNotEmpty) {
      _locationLatitudeController.clear();
    }
    if (_locationLongitudeController.text.isNotEmpty) {
      _locationLongitudeController.clear();
    }
    _customFieldsFormKey.currentState?.clearValidationErrors();
    _markDirty();
    if (_pendingInitialSubCategoryId != null) {
      _applyPendingSubCategorySelection();
    }
  }

  void _onSubCategorySelected(_SubCategoryOption subCategory) {
    if (_selectedSubCategory?.id == subCategory.id) {
      return;
    }
    if (_selectedMainCategory != null) {
      _preferredCategoryPath
        ..clear()
        ..add(_selectedMainCategory!.id)
        ..add(subCategory.id);
    } else {
      _preferredCategoryPath
        ..clear()
        ..add(subCategory.id);
    }

    setState(() {
      _selectedSubCategory = subCategory;
      _customFieldValues = <String, dynamic>{};
      _customFieldError = null;
      _inventoryVariations = <_InventoryVariation>[];
      _recomputeCurrentStepBounds();
    });

    _locationFormKey.currentState?.reset();
    _inventoryFormKey.currentState?.reset();
    if (_locationAddressController.text.isNotEmpty) {
      _locationAddressController.clear();
    }
    if (_locationLatitudeController.text.isNotEmpty) {
      _locationLatitudeController.clear();
    }
    if (_locationLongitudeController.text.isNotEmpty) {
      _locationLongitudeController.clear();
    }

    _customFieldsFormKey.currentState?.clearValidationErrors();
    _markDirty();
    _fetchCustomFieldSchema();
  }

  Future<void> _fetchCustomFieldSchema() async {
    final _MainCategoryOption? mainCategory = _selectedMainCategory;
    final _SubCategoryOption? subCategory = _selectedSubCategory;
    if (mainCategory == null || subCategory == null) {
      return;
    }

    final String cacheKey = '${mainCategory.interfaceType}:${subCategory.id}';
    final List<CustomFieldSchema>? cached = _customFieldSchemaCache[cacheKey];
    if (cached != null) {
      _applyCustomFieldSchema(cached);
      return;
    }

    setState(() {
      _isLoadingCustomFields = true;
      _customFieldError = null;
      _customFieldSchemas = const <CustomFieldSchema>[];
    });

    try {
      final List<CustomFieldSchema> fields =
          await _inventoryService.fetchCustomFieldSchema(
        interfaceType: mainCategory.interfaceType,
        categoryId: subCategory.id,
      );
      if (!mounted) {
        return;
      }
      _customFieldSchemaCache[cacheKey] = fields;
      _applyCustomFieldSchema(fields);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _customFieldError = error.toString();
        _customFieldSchemas = const <CustomFieldSchema>[];
        _isLoadingCustomFields = false;
      });
    }
  }

  void _applyCustomFieldSchema(List<CustomFieldSchema> fields) {
    final Map<String, dynamic> previousValues =
        Map<String, dynamic>.from(_customFieldValues);
    setState(() {
      _customFieldSchemas = fields;
      _customFieldError = null;
      _isLoadingCustomFields = false;
      final Set<String> allowed =
          fields.map((CustomFieldSchema f) => f.id).toSet();
      _customFieldValues = <String, dynamic>{
        for (final MapEntry<String, dynamic> entry in previousValues.entries)
          if (allowed.contains(entry.key)) entry.key: entry.value,
      };
    });
    if (_customFieldValues.length != previousValues.length) {
      _markDirty();
    }
    _customFieldsFormKey.currentState?.clearValidationErrors();
  }

  Widget _buildPlaceholderMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildInfoCard(String message) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  Widget _buildErrorCard(
      {required String message, required VoidCallback onRetry}) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _buildLocationPayload() {
    final String address = _locationAddressController.text.trim();
    final double? latitude =
        double.tryParse(_locationLatitudeController.text.trim());
    final double? longitude =
        double.tryParse(_locationLongitudeController.text.trim());
    if (address.isEmpty || latitude == null || longitude == null) {
      return null;
    }
    return <String, dynamic>{
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  List<Map<String, dynamic>> _buildInventoryVariationsPayload() {
    return _inventoryVariations
        .where((variation) => variation.isComplete)
        .map((variation) => variation.toPayload())
        .toList(growable: false);
  }

  Map<String, dynamic> _buildAdPayload({required bool isDraft}) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'interface_type': _selectedMainCategory?.interfaceType,
      'main_category_id': _selectedMainCategory?.id,
      'sub_category_id': _selectedSubCategory?.id,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'contact': _contactController.text.trim(),
      'price': _priceController.text.trim(),
      'currency': _selectedCurrency,
      'status': isDraft ? 'draft' : 'pending',
      'has_custom_fields': _customFieldSchemas.isNotEmpty,
    };

    final List<_PendingMedia> images =
        _mediaFiles.where((media) => media.isImage).toList(growable: false);
    final List<_PendingMedia> videos =
        _mediaFiles.where((media) => media.isVideo).toList(growable: false);

    if (images.isNotEmpty || videos.isNotEmpty || _videoLinks.isNotEmpty) {
      payload['media'] = <String, dynamic>{
        if (images.isNotEmpty)
          'images':
              images.map((media) => media.toPayload()).toList(growable: false),
        if (videos.isNotEmpty)
          'videos':
              videos.map((media) => media.toPayload()).toList(growable: false),
        if (_videoLinks.isNotEmpty)
          'video_links': List<String>.from(_videoLinks),
      };
    }

    if (_customFieldValues.isNotEmpty) {
      payload['custom_fields'] = Map<String, dynamic>.from(_customFieldValues);
    }

    final Map<String, dynamic>? locationPayload = _buildLocationPayload();
    if (locationPayload != null) {
      payload['location'] = locationPayload;
    }

    final List<Map<String, dynamic>> inventoryPayload =
        _buildInventoryVariationsPayload();
    if (inventoryPayload.isNotEmpty) {
      payload['inventory'] = <String, dynamic>{
        'variations': inventoryPayload,
      };
    }

    if (_isSheinInterface) {
      final String productLink = _sheinProductLinkController.text.trim();
      final String reviewLink = _sheinReviewLinkController.text.trim();
      if (productLink.isNotEmpty) {
        payload['product_link'] = productLink;
      }
      if (reviewLink.isNotEmpty) {
        payload['review_link'] = reviewLink;
      }
    }

    payload.removeWhere((String key, dynamic value) {
      if (value == null) {
        return true;
      }
      if (value is String) {
        return value.trim().isEmpty;
      }
      if (value is Map && value.isEmpty) {
        return true;
      }
      return false;
    });

    return payload;
  }

  Widget _buildMediaStep() {
    final ThemeData theme = Theme.of(context);
    final List<_PendingMedia> images =
        _mediaFiles.where((media) => media.isImage).toList(growable: false);
    final List<_PendingMedia> videos =
        _mediaFiles.where((media) => media.isVideo).toList(growable: false);
    final bool canAddLink = _videoLinkFieldController.text.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('أضف وسائط إعلانك', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'يمكنك رفع الصور والفيديوهات بشكل مؤقت أو إضافة روابط فيديو قبل الإرسال.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _isPickingImages ? null : _pickImages,
              icon: _isPickingImages
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: const Text('إضافة صور'),
            ),
            FilledButton.icon(
              onPressed: _isPickingVideo ? null : _pickVideo,
              icon: _isPickingVideo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.videocam_outlined),
              label: const Text('إضافة فيديو'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (images.isEmpty && videos.isEmpty)
          _buildInfoCard('لم يتم إضافة ملفات وسائط بعد.'),
        if (images.isNotEmpty) ...[
          Text('الصور (${images.length})', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final _PendingMedia media in images)
                _MediaPreviewCard(
                  key: ValueKey<String>('image_${media.file.path}'),
                  media: media,
                  onRemove: () => _removeMediaFile(media),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (videos.isNotEmpty) ...[
          Text('الفيديوهات (${videos.length})',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final _PendingMedia media in videos)
                _MediaPreviewCard(
                  key: ValueKey<String>('video_${media.file.path}'),
                  media: media,
                  onRemove: () => _removeMediaFile(media),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        const Divider(height: 32),
        Text('روابط الفيديو', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _videoLinkFieldController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'أدخل رابط فيديو (يوتيوب أو ملف مباشر)',
                ),
                onChanged: (_) {
                  _clearServerFieldError('media');
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: canAddLink ? _addVideoLink : null,
              icon: const Icon(Icons.add_link),
              label: const Text('إضافة'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_videoLinks.isEmpty)
          Text('لا توجد روابط فيديو مضافة.', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final String link in _videoLinks)
                InputChip(
                  label: SizedBox(
                    width: 220,
                    child: Text(
                      link,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onDeleted: () => _removeVideoLink(link),
                ),
            ],
          ),
      ],
    );
  }

  bool _runPrePublishChecklist() {
    if (_selectedMainCategory == null) {
      _showMessage('يرجى اختيار الفئة الرئيسية قبل النشر.');
      _jumpToStep(_WizardStepId.mainCategory);
      return false;
    }
    final _MainCategoryOption? mainCategory = _selectedMainCategory;
    if (mainCategory != null &&
        mainCategory.subCategories.isNotEmpty &&
        _selectedSubCategory == null) {
      _showMessage('يرجى اختيار الفئة الفرعية قبل النشر.');
      _jumpToStep(_WizardStepId.subCategory);
      return false;
    }
    if (_customFieldSchemas.isNotEmpty) {
      final bool valid = _customFieldsFormKey.currentState?.validate() ?? true;
      if (!valid) {
        _showMessage('يرجى إكمال الحقول المخصّصة المطلوبة قبل النشر.');
        _jumpToStep(_WizardStepId.customFields);
        return false;
      }
    }
    if (!_validateMediaStep()) {
      _jumpToStep(_WizardStepId.media);
      return false;
    }
    if (!_validateTextDetailsStep()) {
      _jumpToStep(_WizardStepId.textDetails);
      return false;
    }

    if ((_requiresLocation ||
            _requiresInventory ||
            _inventoryVariations.isNotEmpty) &&
        !_validateStepFive()) {
      _jumpToStep(_WizardStepId.locationInventory);
      return false;
    }
    if (_requiresInventory && !_isInventoryDataComplete()) {
      _showMessage('يرجى إكمال بيانات تنويعات المخزون قبل النشر.');
      _jumpToStep(_WizardStepId.locationInventory);
      return false;
    }
    if (_requiresLocation && !_isLocationDataComplete()) {
      _showMessage('يرجى تحديد موقع الإعلان بشكل كامل قبل النشر.');
      _jumpToStep(_WizardStepId.locationInventory);
      return false;
    }
    return true;
  }

  Map<String, dynamic> _buildPublishTelemetryContext(AdPublishResult result) {
    final int imageCount = _mediaFiles.where((media) => media.isImage).length;
    final int videoCount = _mediaFiles.where((media) => media.isVideo).length;
    final Map<String, dynamic>? locationPayload = _buildLocationPayload();
    return <String, dynamic>{
      'draft_id': result.draftId ?? _draftId ?? 'new',
      'status': result.status ?? 'unknown',
      'images': imageCount,
      'videos': videoCount,
      'video_links': _videoLinks.length,
      'variations': _inventoryVariations.length,
      'has_location': locationPayload != null,
    };
  }

  Future<void> _publishAd() async {
    _resetServerValidationState();
    if (!_runPrePublishChecklist()) {
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final Map<String, dynamic> payload = _buildAdPayload(isDraft: false);
      final AdPublishResult result = await _adPublishingService.publish(
        payload: payload,
        draftId: _draftId,
        cacheKey: _draftCacheKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _hasUnsavedChanges = false;
        if (result.draftId != null) {
          _draftId = result.draftId.toString();
        }
      });
      AppTelemetry.record(
          'ad.publish.success', _buildPublishTelemetryContext(result));
      _showMessage(result.message);
    } on PublishValidationException catch (error) {
      if (!mounted) {
        return;
      }
      _applyServerValidationErrors(error.fieldErrors);
      final String? firstKey =
          _firstNormalizedServerErrorKey(error.fieldErrors);
      if (firstKey != null) {
        final _WizardStepId? step = _stepForErrorKey(firstKey);
        if (step != null) {
          _jumpToStep(step);
        }
      }
      AppTelemetry.record('ad.publish.validation_failed', <String, dynamic>{
        'message': error.message,
        if (firstKey != null) 'field': firstKey,
      });
      _showMessage(error.message);
    } catch (error) {
      if (mounted) {
        AppTelemetry.record('ad.publish.error', <String, dynamic>{
          'message': error.toString(),
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  Widget _buildTextDetailsStep() {
    final ThemeData theme = Theme.of(context);
    final bool isShein = _isSheinInterface;

    final List<Widget> customFieldWidgets = _customFieldWidgets;

    final TextStyle? sectionStyle = theme.textTheme.titleMedium;

    return Form(
      key: _textDetailsFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('المراجعة النهائية', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildInfoCard(
              'تحقق من التفاصيل قبل الإرسال. يمكنك العودة لتعديل أي خطوة.'),
          const SizedBox(height: 16),
          Text('معلومات الإعلان', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
              'العنوان: ${_titleController.text.isEmpty ? 'غير محدد' : _titleController.text}'),
          const SizedBox(height: 6),
          Text(
              'الوصف: ${_descriptionController.text.isEmpty ? 'غير محدد' : _descriptionController.text}'),
          const SizedBox(height: 6),
          Text(
              'السعر: ${_priceController.text.isEmpty ? 'غير محدد' : _priceController.text} $_currencyLabel'),
          const SizedBox(height: 6),
          Text(
              'رقم التواصل: ${_contactController.text.isEmpty ? 'غير محدد' : _contactController.text}'),
          const SizedBox(height: 16),
          Text('الفئات المختارة', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('الفئة الرئيسية: ${_selectedMainCategory?.name ?? 'غير محدد'}'),
          Text('الفئة الفرعية: ${_selectedSubCategory?.name ?? 'غير محدد'}'),
          Text(
              'واجهة العرض: ${_selectedMainCategory?.interfaceType ?? 'غير محدد'}'),
          const SizedBox(height: 16),
          Text('الحقول المخصّصة', style: sectionStyle),
          const SizedBox(height: 8),
          if (customFieldWidgets.isEmpty)
            Text('لا توجد قيم محفوظة للحقول المخصّصة.',
                style: theme.textTheme.bodySmall)
          else
            ...customFieldWidgets,
          const Divider(height: 32),
          Text('معلومات الإعلان', style: sectionStyle),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'عنوان الإعلان',
              helperText: '10 - 90 حرفًا',
            ),
            maxLength: 90,
            validator: _validateTitle,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'الوصف التفصيلي',
              helperText: 'يُنصح بوصف واضح لا يقل عن 30 حرفًا.',
            ),
            validator: _validateDescription,
          ),
          const SizedBox(height: 16),
          Text('التسعير والعملات', style: sectionStyle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'السعر',
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  validator: _validatePrice,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  decoration: InputDecoration(
                    labelText: 'العملة',
                    errorText: _serverFieldErrors['currency'],
                  ),
                  items: _currencyOptions.entries
                      .map(
                        (MapEntry<String, String> entry) =>
                            DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    setState(() => _selectedCurrency = value);
                    _clearServerFieldError('currency');

                    _markDirty();
                  },
                  validator: (String? value) {
                    if (value == null) {
                      return 'يرجى اختيار العملة.';
                    }
                    return _serverFieldErrors['currency'];
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('بيانات التواصل', style: sectionStyle),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'رقم التواصل',
              helperText: 'يمكن أن يبدأ بعلامة + ثم أرقام فقط.',
            ),
            maxLength: 16,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            ],
            validator: _validateContact,
          ),
          if (isShein) ...[
            const SizedBox(height: 16),
            Text('روابط شي إن', style: sectionStyle),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sheinProductLinkController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'رابط المنتج في شي إن',
              ),
              validator: _validateSheinProductLink,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sheinReviewLinkController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'رابط مراجعة موثوقة (اختياري)',
              ),
              validator: _validateSheinReviewLink,
            ),
          ],
        ],
      ),
    );
  }
}

enum _PendingMediaType { image, video }

class _PendingMedia {
  _PendingMedia._(this.file, this.type, this.sizeInBytes);

  factory _PendingMedia.image(File file) =>
      _PendingMedia._(file, _PendingMediaType.image, _resolveSize(file));

  factory _PendingMedia.video(File file) =>
      _PendingMedia._(file, _PendingMediaType.video, _resolveSize(file));

  final File file;
  final _PendingMediaType type;
  final int sizeInBytes;

  static int _resolveSize(File file) {
    try {
      return file.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  bool get isImage => type == _PendingMediaType.image;

  bool get isVideo => type == _PendingMediaType.video;

  String get displayName {
    final List<String> segments = file.uri.pathSegments;
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return file.path;
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'type': type.name,
        'path': file.path,
        'size': sizeInBytes,
        'name': displayName,
      };
}

class _InventoryVariation {
  _InventoryVariation({
    required this.id,
    this.name = '',
    this.sku = '',
    this.priceText = '',
    this.quantityText = '',
  });

  final String id;
  String name;
  String sku;
  String priceText;
  String quantityText;

  Map<String, dynamic> toPayload() {
    final String trimmedName = name.trim();
    final String trimmedSku = sku.trim();
    final double? price = double.tryParse(priceText.trim());
    final int? quantity = int.tryParse(quantityText.trim());
    final Map<String, dynamic> payload = <String, dynamic>{
      'id': id,
      if (trimmedName.isNotEmpty) 'name': trimmedName,
      if (trimmedSku.isNotEmpty) 'sku': trimmedSku,
      if (price != null) 'price': price,
      if (quantity != null) 'quantity': quantity,
    };
    return payload;
  }

  bool get isComplete {
    final double? price = double.tryParse(priceText.trim());
    final int? quantity = int.tryParse(quantityText.trim());
    return name.trim().isNotEmpty &&
        price != null &&
        price > 0 &&
        quantity != null &&
        quantity >= 0;
  }
}

class _WizardSectionConfig {
  const _WizardSectionConfig({
    this.requiresLocation = false,
    this.requiresInventory = false,
  });

  final bool requiresLocation;
  final bool requiresInventory;
}

class _MediaPreviewCard extends StatelessWidget {
  const _MediaPreviewCard(
      {super.key, required this.media, required this.onRemove});

  final _PendingMedia media;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    Widget buildPreview() {
      if (media.isImage) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            media.file,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
              return Container(
                color: colors.surfaceVariant,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              );
            },
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.play_circle_fill, size: 42, color: colors.tertiary),
      );
    }

    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(child: buildPreview()),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: colors.error.withOpacity(0.9),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            media.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            HelperUtils.getFileSizeString(
                bytes: media.sizeInBytes, decimals: 1),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (media.isVideo)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.movie_filter_outlined,
                      size: 16, color: colors.tertiary),
                  const SizedBox(width: 4),
                  Text('ملف فيديو', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WizardStep {
  const _WizardStep({
    required this.id,
    required this.label,
    this.isOptional = false,
    this.isVisible = true,
  });

  final _WizardStepId id;
  final String label;
  final bool isOptional;
  final bool isVisible;
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.index,
    required this.isCurrent,
    required this.isCompleted,
    required this.isOptional,
  });

  final String label;
  final int index;
  final bool isCurrent;
  final bool isCompleted;
  final bool isOptional;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.color;
    final ThemeData theme = Theme.of(context);
    final Color background = isCompleted
        ? colors.territoryColor.withOpacity(0.1)
        : isCurrent
            ? colors.territoryColor.withOpacity(0.12)
            : colors.secondaryColor;
    final Color borderColor = isCompleted
        ? colors.territoryColor
        : isCurrent
            ? colors.territoryColor.withOpacity(0.6)
            : colors.borderColor.withOpacity(0.4);
    final Color labelColor =
        isCompleted ? colors.territoryColor : colors.textDefaultColor;

    final Color badgeBackground = isOptional
        ? colors.deactivateColor.withOpacity(isCompleted ? 0.24 : 0.14)
        : colors.territoryColor.withOpacity(isCompleted ? 0.24 : 0.14);
    final Color badgeTextColor =
        isOptional ? colors.textDefaultColor : colors.territoryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color:
                  isCompleted ? colors.territoryColor : colors.secondaryColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted
                    ? colors.territoryColor
                    : colors.borderColor.withOpacity(isCurrent ? 0.6 : 0.4),
              ),
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isCurrent
                          ? colors.territoryColor
                          : colors.textDefaultColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: labelColor,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOptional ? 'اختياري' : 'مطلوب',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: badgeTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MainCategoryOption {
  const _MainCategoryOption({
    required this.id,
    required this.name,
    required this.interfaceType,
    this.subCategories = const <_SubCategoryOption>[],
  });

  final int id;
  final String name;
  final String interfaceType;
  final List<_SubCategoryOption> subCategories;

  factory _MainCategoryOption.fromCategoryModel(CategoryModel model) {
    String resolveName(String? value) {
      final String trimmed = (value ?? '').trim();
      return trimmed.isEmpty ? 'فئة بدون اسم' : trimmed;
    }

    final List<_SubCategoryOption> subCategories =
    (model.children ?? const <CategoryModel>[])
        .where((CategoryModel child) => child.id != null)
        .map((CategoryModel child) => _SubCategoryOption(
      id: child.id!,
      name: resolveName(child.name),
    ))
        .toList(growable: false);

    return _MainCategoryOption(
      id: model.id!,
      name: resolveName(model.name),
      interfaceType: (model.interfaceType ?? '').trim(),
      subCategories: subCategories,
    );
  }

  String get normalizedInterfaceType {
    final String trimmed = interfaceType.trim();
    return trimmed.isEmpty ? '' : trimmed.toLowerCase();
  }

}

class _SubCategoryOption {
  const _SubCategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}
