import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'dart:collection';
import 'package:marib/ui/screens/widgets/lazy_network_image.dart';

import 'dart:io';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/imagePicker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:dio/dio.dart';
import 'package:marib/data/model/ad_draft_model.dart';
import 'package:marib/utils/app_telemetry.dart';
import 'package:marib/utils/ui_utils.dart';
import 'models/custom_field_schema.dart';
import 'services/category_inventory_service.dart';
import 'widgets/dynamic_custom_fields_form.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';

part 'main_category_step.dart';
part 'sub_category_step.dart';
part 'custom_fields_step.dart';
part 'media_step.dart';
part 'text_details_step.dart';
part 'review_step.dart';
part 'ad_creation_wizard_models.dart';






/// Simplified ad creation wizard showcasing a multi-step flow with
/// progress indicator, navigation guards and auto-save hooks.

class AdCreationWizardArguments {
  const AdCreationWizardArguments._({
    this.draftId,
    this.interfaceType,
    required this.initialCategoryIds,
    this.accountTypeCode,

    required this.permittedDelegateSections,
    required this.blockedDelegateSections,
    required this.allowedCategoryIds,
  });

  const AdCreationWizardArguments.empty()
      : this._(
    initialCategoryIds: const <int>[],
    permittedDelegateSections: const <String>{},
    blockedDelegateSections: const <String>{},
    allowedCategoryIds: const <int>{},
  );

  factory AdCreationWizardArguments({
    String? draftId,
    String? interfaceType,
    List<int>? initialCategoryIds,
    String? accountTypeCode,

    Set<String>? permittedDelegateSections,
    Set<String>? blockedDelegateSections,
    Set<int>? allowedCategoryIds,
  }) {
    return AdCreationWizardArguments._(
      draftId: draftId,
      interfaceType: interfaceType,
      initialCategoryIds:
      List<int>.unmodifiable(initialCategoryIds ?? const <int>[]),
      accountTypeCode: accountTypeCode,
      permittedDelegateSections: Set<String>.unmodifiable(
        _normalizeStringIterable(permittedDelegateSections ?? const <String>{}),
      ),
      blockedDelegateSections: Set<String>.unmodifiable(
        _normalizeStringIterable(blockedDelegateSections ?? const <String>{}),
      ),
      allowedCategoryIds: Set<int>.unmodifiable(
        _normalizeIntIterable(allowedCategoryIds ?? const <int>{}),
      ),
    );
  }



  final String? draftId;
  final String? interfaceType;
  final List<int> initialCategoryIds;
  final String? accountTypeCode;
  final Set<String> permittedDelegateSections;
  final Set<String> blockedDelegateSections;
  final Set<int> allowedCategoryIds;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (draftId != null) 'draftId': draftId,
      if (interfaceType != null) 'interfaceType': interfaceType,
      if (initialCategoryIds.isNotEmpty) 'initialCategoryIds': initialCategoryIds,
      if (accountTypeCode != null) 'accountTypeCode': accountTypeCode,
      if (permittedDelegateSections.isNotEmpty)
        'permittedDelegateSections': permittedDelegateSections.toList(growable: false),
      if (blockedDelegateSections.isNotEmpty)
        'blockedDelegateSections': blockedDelegateSections.toList(growable: false),
      if (allowedCategoryIds.isNotEmpty)
        'allowedCategoryIds': allowedCategoryIds.toList(growable: false),
    };
  }


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

    final String? accountTypeCode =
        _stringArgument(normalized['accountTypeCode']) ?? _stringArgument(normalized['account_type_code']);
    final Set<String> permittedSections = _parseStringSet(
      normalized['permittedDelegateSections'] ?? normalized['permitted_sections'],
    );
    final Set<String> blockedSections = _parseStringSet(
      normalized['blockedDelegateSections'] ?? normalized['blocked_sections'],
    );
    final Set<int> allowedCategories = _parseIntSet(
      normalized['allowedCategoryIds'] ?? normalized['allowed_category_ids'],
    );

    return AdCreationWizardArguments(
      draftId: draftId,
      interfaceType: interfaceType,
      initialCategoryIds: categoryIds,
      accountTypeCode: accountTypeCode,
      permittedDelegateSections: permittedSections,
      blockedDelegateSections: blockedSections,
      allowedCategoryIds: allowedCategories,
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


  static Set<String> _parseStringSet(dynamic raw) {
    final Set<String> values = <String>{};

    void consume(dynamic value) {
      if (value == null) {
        return;
      }
      if (value is Iterable) {
        for (final dynamic entry in value) {
          consume(entry);
        }
        return;
      }
      if (value is Map) {
        for (final dynamic entry in value.values) {
          consume(entry);
        }
        return;
      }
      final String text = value.toString().trim();
      if (text.isEmpty) {
        return;
      }
      for (final String token in text.split(RegExp(r'[\s,]+'))) {
        final String normalized = token.trim().toLowerCase();
        if (normalized.isEmpty) {
          continue;
        }
        values.add(normalized);
      }
    }

    consume(raw);
    return values;
  }

  static Set<int> _parseIntSet(dynamic raw) {
    final Set<int> values = <int>{};

    void consume(dynamic value) {
      if (value == null) {
        return;
      }
      if (value is Iterable) {
        for (final dynamic entry in value) {
          consume(entry);
        }
        return;
      }
      if (value is Map) {
        for (final dynamic entry in value.values) {
          consume(entry);
        }
        return;
      }
      if (value is num) {
        final int candidate = value.toInt();
        if (candidate > 0) {
          values.add(candidate);
        }
        return;
      }
      final String text = value.toString().trim();
      if (text.isEmpty) {
        return;
      }
      for (final String token in text.split(RegExp(r'[\s,]+'))) {
        final String trimmed = token.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final int? parsed = int.tryParse(trimmed);
        if (parsed != null && parsed > 0) {
          values.add(parsed);
        }
      }
    }

    consume(raw);
    return values;
  }

  static Iterable<String> _normalizeStringIterable(Iterable<String> raw) {
    return raw
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty);
  }

  static Iterable<int> _normalizeIntIterable(Iterable<int> raw) {
    return raw.where((int value) => value > 0);
  }

}

class AdCreationWizardScreen extends StatefulWidget {
  factory AdCreationWizardScreen({
    Key? key,
    String? draftId,
    String? interfaceType,
    List<int>? initialCategoryIds,
    String? accountTypeCode,
    Iterable<String>? permittedDelegateSections,
    Iterable<String>? blockedDelegateSections,
    Iterable<int>? allowedCategoryIds,
    Map<String, dynamic>? routeArgumentMap,
    AdCreationWizardArguments? arguments,

    RouteSettings? routeSettings,
  }) {
    final AdCreationWizardArguments mergedArguments = _mergeArguments(
      explicitDraftId: draftId,
      explicitInterfaceType: interfaceType,
      explicitCategoryIds: initialCategoryIds,
      explicitAccountTypeCode: accountTypeCode,
      explicitPermittedSections: permittedDelegateSections,
      explicitBlockedSections: blockedDelegateSections,
      explicitAllowedCategoryIds: allowedCategoryIds,
      raw: arguments ?? routeArgumentMap ?? routeSettings?.arguments,
    );

    final Map<String, dynamic> resolvedRouteArgumentMap =
    Map<String, dynamic>.unmodifiable(
      _buildRouteArgumentMap(
        explicit: routeArgumentMap,
        rawRouteArguments: routeSettings?.arguments,
        resolvedArguments: mergedArguments,
        providedArguments: arguments,
      ),

    );

    return AdCreationWizardScreen._(
      key: key,
      routeSettings: routeSettings,
      resolvedArguments: mergedArguments,
      routeArgumentMap: resolvedRouteArgumentMap,
    );
  }

  AdCreationWizardScreen._({
    super.key,

    RouteSettings? routeSettings,
    required this.resolvedArguments,
    required Map<String, dynamic> routeArgumentMap,

  })  : routeSettings = routeSettings,

        draftId = resolvedArguments.draftId,
        interfaceType = resolvedArguments.interfaceType,
        initialCategoryIds = List<int>.unmodifiable(
          resolvedArguments.initialCategoryIds,
        ),
        accountTypeCode = resolvedArguments.accountTypeCode,
        permittedDelegateSections = resolvedArguments.permittedDelegateSections,
        blockedDelegateSections = resolvedArguments.blockedDelegateSections,
        allowedCategoryIds = resolvedArguments.allowedCategoryIds,
        routeArgumentsMap = Map<String, dynamic>.unmodifiable(routeArgumentMap);


  final String? draftId;
  final String? interfaceType;
  final List<int> initialCategoryIds;
  final String? accountTypeCode;
  final Set<String> permittedDelegateSections;
  final Set<String> blockedDelegateSections;
  final Set<int> allowedCategoryIds;
  final RouteSettings? routeSettings;
  final AdCreationWizardArguments resolvedArguments;
  final Map<String, dynamic> routeArgumentsMap;

  static Route<void> route(RouteSettings settings) {

    final Object? rawArguments = settings.arguments;
    Map<String, dynamic> argumentMap = _normalizeArgumentMap(rawArguments);

    final AdCreationWizardArguments resolvedArguments;
    if (argumentMap.isNotEmpty) {
      resolvedArguments = AdCreationWizardArguments.fromMap(
        Map<dynamic, dynamic>.from(argumentMap),
      );
    } else {
      resolvedArguments = _resolveArguments(rawArguments);
      argumentMap = _normalizeArgumentMap(resolvedArguments);
    }


    return MaterialPageRoute(
      builder: (_) => AdCreationWizardScreen(
        routeSettings: settings,
        arguments: resolvedArguments,
        routeArgumentMap: argumentMap,

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
    return const AdCreationWizardArguments.empty();
  }



  static Map<String, dynamic> _normalizeArgumentMap(Object? raw) {
    if (raw == null) {
      return <String, dynamic>{};
    }
    if (raw is AdCreationWizardArguments) {
      return raw.toMap();
    }
    if (raw is Map) {
      final Map<String, dynamic> normalized = <String, dynamic>{};
      raw.forEach((dynamic key, dynamic value) {
        if (key != null) {
          normalized[key.toString()] = value;
        }
      });
      return normalized;
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _buildRouteArgumentMap({
    Map<String, dynamic>? explicit,
    Object? rawRouteArguments,
    AdCreationWizardArguments? resolvedArguments,
    AdCreationWizardArguments? providedArguments,
  }) {
    final Map<String, dynamic> result = <String, dynamic>{};

    void merge(Map<String, dynamic>? source) {
      if (source == null || source.isEmpty) {
        return;
      }
      result.addAll(source);
    }

    merge(_normalizeArgumentMap(rawRouteArguments));
    if (resolvedArguments != null) {
      merge(resolvedArguments.toMap());
    }
    if (providedArguments != null) {
      merge(providedArguments.toMap());
    }
    merge(explicit);

    return result;
  }



  static AdCreationWizardArguments _mergeArguments({
    String? explicitDraftId,
    String? explicitInterfaceType,
    List<int>? explicitCategoryIds,
    String? explicitAccountTypeCode,
    Iterable<String>? explicitPermittedSections,
    Iterable<String>? explicitBlockedSections,
    Iterable<int>? explicitAllowedCategoryIds,
    Object? raw,
  }) {
    final AdCreationWizardArguments routeArgs = _resolveArguments(raw);
    final String? resolvedDraftId =
        routeArgs.draftId ?? AdCreationWizardArguments._stringArgument(explicitDraftId);
    final String? resolvedInterfaceType =
        routeArgs.interfaceType ?? AdCreationWizardArguments._stringArgument(explicitInterfaceType);

    final LinkedHashSet<int> categorySet = LinkedHashSet<int>();

    void consume(Iterable<int>? source) {
      if (source == null) {
        return;
      }
      for (final int id in source) {
        if (id > 0) {
          categorySet.add(id);
        }
      }
    }

    consume(routeArgs.initialCategoryIds);
    consume(explicitCategoryIds);


    final String? resolvedAccountTypeCode =
        routeArgs.accountTypeCode ?? AdCreationWizardArguments._stringArgument(explicitAccountTypeCode);

    final LinkedHashSet<String> permittedSet = LinkedHashSet<String>()
      ..addAll(routeArgs.permittedDelegateSections);
    if (explicitPermittedSections != null) {
      permittedSet.addAll(
        AdCreationWizardArguments._normalizeStringIterable(explicitPermittedSections),
      );
    }

    final LinkedHashSet<String> blockedSet = LinkedHashSet<String>()
      ..addAll(routeArgs.blockedDelegateSections);
    if (explicitBlockedSections != null) {
      blockedSet.addAll(
        AdCreationWizardArguments._normalizeStringIterable(explicitBlockedSections),
      );
    }

    final LinkedHashSet<int> allowedSet = LinkedHashSet<int>()
      ..addAll(routeArgs.allowedCategoryIds);
    if (explicitAllowedCategoryIds != null) {
      allowedSet.addAll(
        AdCreationWizardArguments._normalizeIntIterable(explicitAllowedCategoryIds),
      );
    }


    return AdCreationWizardArguments(
      draftId: resolvedDraftId,
      interfaceType: resolvedInterfaceType,
      initialCategoryIds: categorySet.toList(growable: false),
      accountTypeCode: resolvedAccountTypeCode,
      permittedDelegateSections: permittedSet,
      blockedDelegateSections: blockedSet,
      allowedCategoryIds: allowedSet,
    );
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
  final TextEditingController _categorySearchController =
  TextEditingController();
  final TextEditingController _subCategorySearchController =
  TextEditingController();
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
  Timer? _categorySearchDebounce;
  Timer? _subCategorySearchDebounce;
  String _categorySearchQuery = '';
  String _subCategorySearchQuery = '';


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


  static const Map<String, String> _interfaceTypeLabels =
  <String, String>{
    'public_ads': 'واجهة الإعلانات العامة',
    'services': 'الخدمات المتخصصة',
    'shein_products': 'منتجات شي إن',
    'computer_section': 'قسم الكمبيوتر',
    'store_products': 'منتجات المتجر',
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

  List<_WizardStep> get _visibleSteps =>
      _steps
          .where((_WizardStep step) => step.isVisible)
          .toList(growable: false);

  final CategoryInventoryService _inventoryService = CategoryInventoryService();
  final AdPublishingService _adPublishingService = AdPublishingService();
  List<_MainCategoryOption> _mainCategories = <_MainCategoryOption>[];
  final List<int> _preferredCategoryPath = <int>[];
  String? _preferredInterfaceTypeOriginal;
  String? _preferredInterfaceTypeNormalized;
  int? _pendingInitialSubCategoryId;
  int? _pendingSubCategoryFetchParentId;
  bool _appliedInitialCategorySelection = false;
  bool _hasRequestedCategoryFetch = false;
  bool _isCategoryFetchScheduled = false;
  bool _pendingForcedCategoryRefresh = false;
  FetchCategoryCubit? _categoryCubit;
  StreamSubscription<FetchCategoryState>? _categorySubscription;
  final GlobalKey<DynamicCustomFieldsFormState> _customFieldsFormKey =
  GlobalKey<DynamicCustomFieldsFormState>();
  final Map<String, List<CustomFieldSchema>> _customFieldSchemaCache =
  <String, List<CustomFieldSchema>>{};
  _MainCategoryOption? _selectedMainCategory;
  _SubCategoryOption? _selectedSubCategory;
  int? _pressedMainCategoryId;
  int? _pressedSubCategoryId;
  List<CustomFieldSchema> _customFieldSchemas = const <CustomFieldSchema>[];
  Map<String, dynamic> _customFieldValues = <String, dynamic>{};
  bool _isLoadingCustomFields = false;
  String? _customFieldError;
  bool _isPublishing = false;


  List<_MainCategoryOption> get _filteredMainCategories {
    final String normalized = _categorySearchQuery.trim().toLowerCase();
    if (normalized.isEmpty) {
      return _mainCategories;
    }
    return _mainCategories
        .where((option) => option.name.toLowerCase().contains(normalized))
        .toList(growable: false);
  }


  List<_SubCategoryOption> _filteredSubCategories(
      _MainCategoryOption? mainCategory) {
    if (mainCategory == null) {
      return const <_SubCategoryOption>[];
    }
    final String normalized = _subCategorySearchQuery.trim().toLowerCase();
    if (normalized.isEmpty) {
      return mainCategory.subCategories;
    }
    return mainCategory.subCategories
        .where((option) => option.name.toLowerCase().contains(normalized))
        .toList(growable: false);
  }


  Timer? _autoSaveTimer;
  int _currentStep = 0;
  bool _hasUnsavedChanges = false;
  bool _isSavingDraft = false;
  String? _draftId;
  bool _isLoadingDraft = false;
  bool _isSyncingPending = false;
  bool _isHydratingState = false;
  final Map<String, String> _serverFieldErrors = <String, String>{};
  Map<String, dynamic> get initialRouteArguments => widget.routeArgumentsMap;

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
      _scheduleCategoryFetch();
    } else if (!matchesPreferences &&
        currentState is! FetchCategoryInProgress) {
      _scheduleCategoryFetch(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _categorySubscription?.cancel();

    _autoSaveTimer?.cancel();
    _categorySearchDebounce?.cancel();
    _subCategorySearchDebounce?.cancel();

    _titleController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    _priceController.dispose();
    _videoLinkFieldController.dispose();
    _sheinProductLinkController.dispose();
    _sheinReviewLinkController.dispose();
    _locationAddressController.dispose();
    _categorySearchController.dispose();
    _subCategorySearchController.dispose();
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

  void _registerFieldController(TextEditingController controller,
      List<String> keys) {
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


  List<int> _collectEnsuredCategoryIds() {
    final LinkedHashSet<int> ensured = LinkedHashSet<int>();
    ensured.addAll(_preferredCategoryPath);
    ensured.addAll(widget.allowedCategoryIds);
    final _MainCategoryOption? main = _selectedMainCategory;
    if (main != null) {
      ensured.add(main.id);
    }
    final _SubCategoryOption? sub = _selectedSubCategory;
    if (sub != null) {
      ensured.add(sub.id);
    }
    return ensured.toList(growable: false);
  }

  void _scheduleCategoryFetch({bool forceRefresh = false}) {
    if (forceRefresh) {
      _pendingForcedCategoryRefresh = true;
    }

    if (_isCategoryFetchScheduled) {
      return;
    }

    if (!forceRefresh && _hasRequestedCategoryFetch) {
      return;
    }

    _isCategoryFetchScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isCategoryFetchScheduled = false;
        _pendingForcedCategoryRefresh = false;

        return;
      }

      final bool shouldForceRefresh = forceRefresh || _pendingForcedCategoryRefresh;
      _pendingForcedCategoryRefresh = false;

      _triggerCategoryFetch(forceRefresh: shouldForceRefresh);
      _isCategoryFetchScheduled = false;
    });
  }

  void _ensureSubCategoryFetch(int parentId) {
    if (parentId <= 0) {
      return;
    }
    if (_pendingSubCategoryFetchParentId == parentId) {
      return;
    }

    _pendingSubCategoryFetchParentId = parentId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_selectedMainCategory?.id != parentId) {
        if (_pendingSubCategoryFetchParentId == parentId) {
          _pendingSubCategoryFetchParentId = null;
        }
        return;
      }
      _scheduleCategoryFetch(forceRefresh: true);
    });
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
    final List<int> ensuredCategoryIds = _collectEnsuredCategoryIds();

    cubit.fetchCategories(
      interfaceType: _preferredInterfaceTypeOriginal,
      categoryId: categoryId,
      categoryIds: categoryPath.isEmpty ? null : categoryPath,
      forceRefresh: forceRefresh,
      onlyAllowed: true,
      ensureCategoryIds: ensuredCategoryIds,
      allowedCategoryIds: widget.allowedCategoryIds,
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
        _pendingSubCategoryFetchParentId = null;
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
      if (id == null || name == null || name
          .trim()
          .isEmpty) {
        continue;
      }
      options.add(_MainCategoryOption.fromCategoryModel(model));
    }
    return options;
  }

  _MainCategoryOption? _findMainCategoryById(List<_MainCategoryOption> options,
      int? id) {
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

  _SubCategoryOption? _findSubCategoryById(List<_SubCategoryOption> options,
      int? id) {
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
      _onMainCategorySelected(target, advanceToNextStep: false);

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
      _onSubCategorySelected(target, advanceToNextStep: false);
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

  String get _draftCacheKey => _cacheKeyFor(_draftId ?? widget.draftId);

  String _cacheKeyFor(String? draftId) => 'ad_wizard_${draftId ?? 'new'}';

  Future<void> _initializeDraft() async {
    String activeCacheKey = _cacheKeyFor(widget.draftId);
    setState(() => _isLoadingDraft = true);
    try {
      Map<String, dynamic>? pending =
      await _adPublishingService.readPending(activeCacheKey);
      AdDraftModel? snapshot =
      await _adPublishingService.readCachedDraft(activeCacheKey);
      AdDraftModel? remote;

      final String? initialDraftId = widget.draftId;
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
        fallbackDraftId: _draftId ?? widget.draftId,
      );
      if (synced != null) {
        final String newCacheKey =
        _cacheKeyFor(synced.id ?? _draftId ?? widget.draftId);
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

    final bool requiresCategoryRefresh = _preferredCategoryPath.isNotEmpty &&
        !_mainCategories.any(
              (_MainCategoryOption option) =>
          option.id == _preferredCategoryPath.first,
        );
    if (requiresCategoryRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerCategoryFetch(forceRefresh: true);
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

  _SubCategoryOption? _resolveSubCategory(_MainCategoryOption? mainCategory,
      Map<String, dynamic> payload,) {
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

  Map<String, dynamic> _buildStepPayload(_WizardStepId step,
      Map<String, dynamic> payload,) {
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

  List<_PendingMedia> _composePendingMedia(Map<String, dynamic> media,
      Map<String, dynamic> temporaryMedia,) {
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

  List<String> _collectVideoLinks(Map<String, dynamic> media,
      Map<String, dynamic> temporaryMedia,) {
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

  List<_InventoryVariation> _buildVariations(Map<String, dynamic> inventory,) {
    final List<dynamic>? rawVariations =
    inventory['variations'] as List<dynamic>?;
    if (rawVariations == null) {
      return <_InventoryVariation>[];
    }
    return rawVariations.map((dynamic raw) {
      final Map<String, dynamic> data = _mapOf(raw);
      return _InventoryVariation(
        id: _stringOrNull(data['id']) ??
            DateTime
                .now()
                .microsecondsSinceEpoch
                .toString(),
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
      summary..add(Text(
        field.label,
        style:
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ))..add(const SizedBox(height: 4))..add(
          Text(formatted.isEmpty ? 'غير محدد' : formatted))..add(
          const SizedBox(height: 12));
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
      widgets..add(Text(
        field.label,
        style:
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ))..add(const SizedBox(height: 4))..add(Text(displayValue))..add(
          const SizedBox(height: 12));
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
        maxLength: _mediaFiles
            .where((media) => media.isImage)
            .length,
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
    _cacheKeyFor(_draftId ?? widget.draftId);

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
      _cacheKeyFor(draft.id ?? _draftId ?? widget.draftId);
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


  bool _shouldHideNavigationForStep(_WizardStepId stepId) {
    switch (stepId) {
      case _WizardStepId.mainCategory:
      case _WizardStepId.subCategory:
        return true;
      case _WizardStepId.customFields:
      case _WizardStepId.media:
      case _WizardStepId.textDetails:
      case _WizardStepId.locationInventory:
      case _WizardStepId.review:
        return false;
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
      return value
          .trim()
          .isNotEmpty;
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
    HelperUtils.showSnackBarMessage(
      context,
      message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_WizardStep> steps = _visibleSteps;
    final int currentStepIndex = _effectiveCurrentStepIndex(steps);

    final double stepProgress =
    steps.isEmpty ? 0 : (currentStepIndex + 1) / steps.length;
    final int progressPercent = (stepProgress * 100).clamp(0, 100).round();
    final int stepPosition = steps.isEmpty ? 0 : currentStepIndex + 1;
    final String progressPercentLabel = '$progressPercent% مكتمل';
    final String stepPositionLabel =
    steps.isEmpty ? '' : 'المرحلة $stepPosition/${steps.length}';
    final bool isCurrentStepOptional =
    steps.isNotEmpty ? steps[currentStepIndex].isOptional : false;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = context.color;
    final String appBarTitle = steps.isEmpty
        ? 'معالج إنشاء إعلان'
        : steps[currentStepIndex].label;
    final List<Widget>? appBarActions =
    (!_hasUnsavedChanges && !_isSavingDraft)
        ? null
        : <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: TextButton(
          onPressed: _isSavingDraft || !_hasUnsavedChanges
              ? null
              : _autoSaveDraft,
          style: TextButton.styleFrom(
            foregroundColor: colors.territoryColor,
            disabledForegroundColor:
            colors.deactivateColor.withOpacity(0.7),
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: _isSavingDraft
              ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                colors.territoryColor,
              ),
            ),
          )
              : const Text('حفظ كمسودة'),
        ),
      ),
    ];
    final double appBarBottomHeight = steps.isEmpty ? 0 : 96;
    final List<Widget>? appBarBottom = steps.isEmpty
        ? null
        : <Widget>[
      Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    stepPositionLabel,
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
                const Spacer(),
                Text(
                  progressPercentLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.textDefaultColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
          ],
        ),

      ),
    ];


    final _WizardStepId? currentStepId =
    steps.isNotEmpty ? steps[currentStepIndex].id : null;
    final bool shouldShowBottomNavigation = currentStepId != null &&
        !_shouldHideNavigationForStep(currentStepId);


    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: appBarTitle,
        actions: appBarActions,
        bottomHeight: appBarBottomHeight,
        bottom: appBarBottom,
      ),
      body: _buildStepBody(steps, currentStepIndex),
      bottomNavigationBar: shouldShowBottomNavigation
          ? Padding(
        padding: EdgeInsets.fromLTRB(
          16.0,
          12.0,
          16.0,
          12.0 + MediaQuery
              .of(context)
              .viewPadding
              .bottom,
              ),
        child: Row(

          children: [
            Expanded(
              child: UiUtils.buildButton(
                context,
                onPressed: _goPrevious,
                buttonTitle: 'رجوع',
                buttonColor: colors.secondaryColor,
                textColor: colors.territoryColor,
                border: BorderSide(color: colors.territoryColor),
                showElevation: false,
                disabled: currentStepIndex == 0,
                disabledColor: colors.secondaryColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: UiUtils.buildButton(
                context,
                onPressed: currentStepIndex == steps.length - 1
                    ? _publishAd
                    : _goNext,
                buttonTitle: currentStepIndex == steps.length - 1
                    ? 'نشر'
                    : 'التالي',
                isInProgress:
                _isPublishing && currentStepIndex == steps.length - 1,
                disabled: _isPublishing,
                progressWidth: 18,
                progressHeight: 18,
              ),
            ),
          ],
              ),
      )
          : null,
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


  Widget _buildStepBody(List<_WizardStep> steps, int currentIndex) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<Widget> children = steps
        .map((step) {
      switch (step.id) {
        case _WizardStepId.mainCategory:
          return KeyedSubtree(
            key: ValueKey<_WizardStepId>(step.id),
            child: _buildMainCategoryStep(),
          );
        case _WizardStepId.subCategory:
          return KeyedSubtree(
            key: ValueKey<_WizardStepId>(step.id),
            child: _buildSubCategoryStep(),
          );
        case _WizardStepId.customFields:
          return KeyedSubtree(
            key: ValueKey<_WizardStepId>(step.id),
            child: _buildCustomFieldsStep(),
          );
        case _WizardStepId.media:
          return KeyedSubtree(
            key: ValueKey<_WizardStepId>(step.id),
            child: _buildMediaStep(),
          );
        case _WizardStepId.textDetails:
          return KeyedSubtree(
            key: ValueKey<_WizardStepId>(step.id),
            child: _buildTextDetailsStep(),
          );
        case _WizardStepId.locationInventory:
          return KeyedSubtree(
            key: ValueKey<_WizardStepId>(step.id),
            child: _buildStepFiveBody(),
          );
        case _WizardStepId.review:
          return KeyedSubtree(
            key: ValueKey<_WizardStepId>(step.id),
            child: _buildReviewStep(),
          );
        default:
          return const SizedBox.shrink();
      }
    })
        .whereType<Widget>()
        .toList(growable: false);
    final int clampedIndex = currentIndex.clamp(0, children.length - 1);
    return IndexedStack(
      index: clampedIndex,
      children: children,
    );
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
        ..._inventoryVariations
            .asMap()
            .entries
            .map(
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

  Widget _buildVariationCard(_InventoryVariation variation,
      bool requiresInventory,
      int index,) {
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
          id: DateTime
              .now()
              .microsecondsSinceEpoch
              .toString(),
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


  void _onMainCategorySelected(_MainCategoryOption category,
      {bool advanceToNextStep = true}) {

    if (_selectedMainCategory?.id == category.id) {
      return;
    }

    _subCategorySearchDebounce?.cancel();
    if (_subCategorySearchController.text.isNotEmpty) {
      _subCategorySearchController.clear();
    }

    _registerPreferredInterfaceType(category.interfaceType);
    _preferredCategoryPath
      ..clear()
      ..add(category.id);
    setState(() {
      _selectedMainCategory = category;
      _selectedSubCategory = null;
      _pressedSubCategoryId = null;
      _customFieldSchemas = const <CustomFieldSchema>[];
      _customFieldValues = <String, dynamic>{};
      _customFieldError = null;
      _isLoadingCustomFields = false;
      _inventoryVariations = <_InventoryVariation>[];
      _subCategorySearchQuery = '';
      _pendingSubCategoryFetchParentId = null;
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

    if (advanceToNextStep) {
      _scheduleAdvanceFromMainCategory();
    }
  }

  void _scheduleAdvanceFromMainCategory() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final List<_WizardStep> steps = _visibleSteps;
      if (steps.isEmpty) {
        return;
      }
      final int mainIndex =
      steps.indexWhere((step) => step.id == _WizardStepId.mainCategory);
      if (mainIndex == -1 || mainIndex >= steps.length - 1) {
        return;
      }
      if (!_canProceedFromStep(_WizardStepId.mainCategory)) {
        return;
      }
      int targetIndex = mainIndex + 1;
      if (targetIndex >= steps.length) {
        return;
      }
      if (steps[targetIndex].id == _WizardStepId.subCategory &&
          ((_selectedMainCategory?.subCategories.isEmpty ?? true))) {
        targetIndex += 1;
      }
      if (targetIndex >= steps.length) {
        return;
      }
      final _WizardStepId targetStepId = steps[targetIndex].id;

      if (_currentStep == mainIndex) {
        setState(() => _currentStep = targetIndex);

      } else {
        _jumpToStep(targetStepId);
      }
    });


  }

  void _scheduleAdvanceFromSubCategory() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final List<_WizardStep> steps = _visibleSteps;
      if (steps.isEmpty) {
        return;
      }
      final int subIndex =
      steps.indexWhere((step) => step.id == _WizardStepId.subCategory);
      if (subIndex == -1 || subIndex >= steps.length - 1) {
        return;
      }
      if (!_canProceedFromStep(_WizardStepId.subCategory)) {
        return;
      }
      final _WizardStepId nextStepId = steps[subIndex + 1].id;
      if (_currentStep == subIndex) {
        setState(() => _currentStep = subIndex + 1);
      } else {
        _jumpToStep(nextStepId);
      }
    });
  }

  void _onSubCategorySelected(_SubCategoryOption subCategory,
      {bool advanceToNextStep = true}) {
    if (_selectedSubCategory?.id == subCategory.id) {
      return;
    }
    if (_selectedMainCategory != null) {
      _preferredCategoryPath
        ..clear()
        ..add(_selectedMainCategory!.id)..add(subCategory.id);
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
      _pressedSubCategoryId = null;
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
    if (advanceToNextStep) {
      _scheduleAdvanceFromSubCategory();
    }
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
    final int imageCount = _mediaFiles
        .where((media) => media.isImage)
        .length;
    final int videoCount = _mediaFiles
        .where((media) => media.isVideo)
        .length;
    final Map<String, dynamic>? locationPayload = _buildLocationPayload();
    return <String, dynamic>{
      'draft_id': result.draftId ?? _draftId ?? 'new',
      'status': result.status ?? 'unknown',
      'images': imageCount,
      'videos': videoCount,
      'video_links': _videoLinks.length,
      'variations': _inventoryVariations.length,
      'has_location': locationPayload != null,
      if (widget.routeArgumentsMap.isNotEmpty)
        'initial_route_arguments': widget.routeArgumentsMap,
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
        return value
            .trim()
            .isEmpty;
      }
      if (value is Map && value.isEmpty) {
        return true;
      }
      return false;
    });

    return payload;
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
}