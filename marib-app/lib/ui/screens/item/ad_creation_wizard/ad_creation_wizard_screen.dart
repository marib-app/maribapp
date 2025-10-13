import 'dart:async';


import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/imagePicker.dart';


import 'models/custom_field_schema.dart';
import 'services/category_inventory_service.dart';
import 'widgets/dynamic_custom_fields_form.dart';


/// Simplified ad creation wizard showcasing a multi-step flow with
/// progress indicator, navigation guards and auto-save hooks.
class AdCreationWizardScreen extends StatefulWidget {
  const AdCreationWizardScreen({super.key});

  static Route<void> route(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const AdCreationWizardScreen(),
      settings: settings,
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

  String? _selectedCurrency = 'YER';

  final PickImage _imagePicker = PickImage();
  final ImagePicker _videoPicker = ImagePicker();

  final List<_PendingMedia> _mediaFiles = <_PendingMedia>[];
  final List<String> _videoLinks = <String>[];
  final TextEditingController _locationAddressController = TextEditingController();
  final TextEditingController _locationLatitudeController = TextEditingController();
  final TextEditingController _locationLongitudeController = TextEditingController();
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
      final String overrideKey = '${mainCategory.interfaceType}:${subCategory.id}';
      final _WizardSectionConfig? override = _sectionConfigurations[overrideKey];
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
      _steps.where((_WizardStep step) => step.isVisible).toList(growable: false);


  final CategoryInventoryService _inventoryService = CategoryInventoryService();
  final AdPublishingService _adPublishingService = AdPublishingService();
  final List<_MainCategoryOption> _mainCategories = <_MainCategoryOption>[
    _MainCategoryOption(
      id: 1,
      name: 'إعلانات عامة',
      interfaceType: 'public_ads',
      subCategories: const <_SubCategoryOption>[
        const _SubCategoryOption(id: 101, name: 'سيارات للبيع'),
        const _SubCategoryOption(id: 102, name: 'عقارات للإيجار'),
      ],
    ),
    _MainCategoryOption(
      id: 2,
      name: 'الخدمات',
      interfaceType: 'services',
      subCategories: const <_SubCategoryOption>[
        const _SubCategoryOption(id: 201, name: 'خدمات الصيانة'),
        const _SubCategoryOption(id: 202, name: 'استشارات الأعمال'),
      ],
    ),
  ];
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

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markDirty);
    _descriptionController.addListener(_markDirty);
    _contactController.addListener(_markDirty);
    _priceController.addListener(_markDirty);
    _sheinProductLinkController.addListener(_markDirty);
    _sheinReviewLinkController.addListener(_markDirty);
    _locationAddressController.addListener(_markDirty);
    _locationLatitudeController.addListener(_markDirty);
    _locationLongitudeController.addListener(_markDirty);
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
  }

  @override
  void dispose() {
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
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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
    FocusScope.of(context).unfocus();
    _markDirty();
  }

  void _removeVideoLink(String link) {
    setState(() {
      _videoLinks.remove(link);
    });
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
    const List<String> allowedExtensions = <String>['.mp4', '.mov', '.m4v', '.webm'];
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
    return null;
  }

  String? _validateDescription(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.length < 30) {
      return 'الوصف يجب أن يحتوي على 30 حرفًا على الأقل.';
    }
    if (trimmed.length > 1200) {
      return 'الوصف طويل جدًا. يرجى تقليصه إلى 1200 حرف كحد أقصى.';
    }
    return null;
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
    return null;
  }

  String? _validateContact(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'يرجى إدخال رقم للتواصل.';
    }
    final String normalized = trimmed.startsWith('+') ? trimmed.substring(1) : trimmed;
    if (normalized.length < 6 || normalized.length > 15) {
      return 'رقم التواصل يجب أن يكون بين 6 و15 رقمًا.';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) {
      return 'رقم التواصل يجب أن يحتوي على أرقام فقط بعد المقدمة.';
    }
    return null;
  }

  String? _validateSheinUrl(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.scheme == 'file') {
      return 'يرجى إدخال رابط صالح.';
    }
    return null;
  }



  Future<void> _autoSaveDraft() async {
    if (!_hasUnsavedChanges || _isSavingDraft) {
      return;
    }
    setState(() => _isSavingDraft = true);
    try {
      final Map<String, dynamic> payload = _buildAdPayload(isDraft: true);
      await _adPublishingService.saveDraft(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasUnsavedChanges = false;
      });
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
        final bool valid = _customFieldsFormKey.currentState?.validate() ?? true;
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
        final bool contactValid = _validateContact(_contactController.text) == null;
        final bool currencySelected = _selectedCurrency != null;
        final bool sheinProductValid = !_isSheinInterface ||
            _validateSheinUrl(_sheinProductLinkController.text) == null;
        final bool sheinReviewValid =
            _validateSheinUrl(_sheinReviewLinkController.text) == null;
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
    final int completedSteps =
        completionByStep.values.where((bool value) => value).length;
    final double progress =
    steps.isEmpty ? 0 : completedSteps / steps.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('معالج إنشاء إعلان'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < steps.length; i++)
                      _StepChip(
                        label: steps[i].label,
                        index: i,
                        isCurrent: i == currentStepIndex,
                        isCompleted:
                        completionByStep[steps[i].id] ?? false,
                        isOptional: steps[i].isOptional,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildStepBody(steps, currentStepIndex)),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16.0, 12.0, 16.0, 12.0 + MediaQuery.of(context).viewPadding.bottom,
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
          return null;
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
            .map((variation) => _buildVariationCard(variation, requiresInventory)),
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
              decoration: const InputDecoration(labelText: 'اسم التنويعة'),
              textInputAction: TextInputAction.next,
              onChanged: (String value) {
                setState(() => variation.name = value);
                _markDirty();
              },
              validator: (String? value) {
                final String trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty && requiresInventory) {
                  return 'يرجى إدخال اسم للتنويعة.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey<String>('variation_sku_${variation.id}'),
              initialValue: variation.sku,
              decoration: const InputDecoration(
                labelText: 'المعرف (SKU)',
                helperText: 'اختياري لتتبع المخزون الداخلي.',
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
              decoration: const InputDecoration(labelText: 'السعر'),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (String value) {
                setState(() => variation.priceText = value);
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
              decoration: const InputDecoration(labelText: 'الكمية المتاحة'),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
              onChanged: (String value) {
                setState(() => variation.quantityText = value);
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
                return null;
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
    _inventoryFormKey.currentState?.validate();
    _markDirty();
  }

  void _removeInventoryVariation(_InventoryVariation variation) {
    setState(() {
      _inventoryVariations = _inventoryVariations
          .where((_) => _.id != variation.id)
          .toList(growable: false);
    });
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
    return null;
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
    return null;
  }





  Widget _buildMainCategoryStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('اختر الفئة الرئيسية للإعلان. يمكن تعديل هذا الاختيار لاحقًا.'),
        const SizedBox(height: 12),
        for (final _MainCategoryOption category in _mainCategories)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: RadioListTile<_MainCategoryOption>(
              value: category,
              groupValue: _selectedMainCategory,
              title: Text(category.name),
              subtitle: Text('واجهة العرض: ${category.interfaceType}'),
              onChanged: (value) {
                if (value == null) return;
                _onMainCategorySelected(value);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSubCategoryStep() {
    final _MainCategoryOption? mainCategory = _selectedMainCategory;
    if (mainCategory == null) {
      return _buildPlaceholderMessage('يرجى اختيار الفئة الرئيسية أولًا لمتابعة اختيار الفئة الفرعية.');
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
          _buildInfoCard('يرجى اختيار الفئة الرئيسية قبل الانتقال إلى الحقول المخصّصة.')
        else if (subCategory == null)
          _buildInfoCard('يرجى اختيار الفئة الفرعية لمتابعة الحقول المخصّصة.')
        else if (_isLoadingCustomFields)
            const Center(child: Padding(
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
  }

  void _onSubCategorySelected(_SubCategoryOption subCategory) {
    if (_selectedSubCategory?.id == subCategory.id) {
      return;
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
      final List<CustomFieldSchema> fields = await _inventoryService.fetchCustomFieldSchema(
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
    final Map<String, dynamic> previousValues = Map<String, dynamic>.from(_customFieldValues);
    setState(() {
      _customFieldSchemas = fields;
      _customFieldError = null;
      _isLoadingCustomFields = false;
      final Set<String> allowed = fields.map((CustomFieldSchema f) => f.id).toSet();
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

  Widget _buildErrorCard({required String message, required VoidCallback onRetry}) {
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
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
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
          'images': images.map((media) => media.toPayload()).toList(growable: false),
        if (videos.isNotEmpty)
          'videos': videos.map((media) => media.toPayload()).toList(growable: false),
        if (_videoLinks.isNotEmpty) 'video_links': List<String>.from(_videoLinks),
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
          Text('الفيديوهات (${videos.length})', style: theme.textTheme.titleSmall),
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
                onChanged: (_) => setState(() {}),
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





  Future<void> _publishAd() async {
    if (_selectedMainCategory == null) {
      _showMessage('يرجى اختيار الفئة الرئيسية قبل النشر.');
      return;
    }
    if (_selectedSubCategory == null) {
      _showMessage('يرجى اختيار الفئة الفرعية قبل النشر.');
      return;
    }
    if (_customFieldSchemas.isNotEmpty) {
      final bool valid = _customFieldsFormKey.currentState?.validate() ?? true;
      if (!valid) {
        _showMessage('يرجى إكمال الحقول المخصّصة المطلوبة قبل النشر.');
        return;
      }
    }
    if (!_validateMediaStep()) {
      return;
    }
    if (!_validateTextDetailsStep()) {
      return;
    }

    if ((_requiresLocation || _requiresInventory ||
        _inventoryVariations.isNotEmpty) &&
        !_validateStepFive()) {
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final Map<String, dynamic> payload = _buildAdPayload(isDraft: false);
      await _adPublishingService.publish(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasUnsavedChanges = false;
      });
      _showMessage('تم إرسال الإعلان للنشر بنجاح.');
    } catch (error) {
      if (mounted) {
        _showMessage('تعذّر نشر الإعلان: $error');
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
          _buildInfoCard('تحقق من التفاصيل قبل الإرسال. يمكنك العودة لتعديل أي خطوة.'),
          const SizedBox(height: 16),
          Text('معلومات الإعلان', style: theme.textTheme.titleMedium),

          const SizedBox(height: 8),
          Text('العنوان: ${_titleController.text.isEmpty ? 'غير محدد' : _titleController.text}'),
          const SizedBox(height: 6),
          Text('الوصف: ${_descriptionController.text.isEmpty ? 'غير محدد' : _descriptionController.text}'),
          const SizedBox(height: 6),
          Text('السعر: ${_priceController.text.isEmpty ? 'غير محدد' : _priceController.text} $_currencyLabel'),
          const SizedBox(height: 6),
          Text('رقم التواصل: ${_contactController.text.isEmpty ? 'غير محدد' : _contactController.text}'),
          const SizedBox(height: 16),
          Text('الفئات المختارة', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),

          Text('الفئة الرئيسية: ${_selectedMainCategory?.name ?? 'غير محدد'}'),
          Text('الفئة الفرعية: ${_selectedSubCategory?.name ?? 'غير محدد'}'),
          Text('واجهة العرض: ${_selectedMainCategory?.interfaceType ?? 'غير محدد'}'),
          const SizedBox(height: 16),
          Text('الحقول المخصّصة', style: sectionStyle),
          const SizedBox(height: 8),
          if (customFieldWidgets.isEmpty)
            Text('لا توجد قيم محفوظة للحقول المخصّصة.', style: theme.textTheme.bodySmall)
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  decoration: const InputDecoration(
                    labelText: 'العملة',
                  ),
                  items: _currencyOptions.entries
                      .map(
                        (MapEntry<String, String> entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    setState(() => _selectedCurrency = value);
                    _markDirty();
                  },
                  validator: (String? value) => value == null ? 'يرجى اختيار العملة.' : null,
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
              validator: _validateSheinUrl,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sheinReviewLinkController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'رابط مراجعة موثوقة (اختياري)',
              ),
              validator: _validateSheinUrl,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final ThemeData theme = Theme.of(context);
    final List<_PendingMedia> images =
    _mediaFiles.where((media) => media.isImage).toList(growable: false);
    final List<_PendingMedia> videos =
    _mediaFiles.where((media) => media.isVideo).toList(growable: false);
    final bool isShein = _isSheinInterface;
    final List<Widget> customFieldSummary = _customFieldSummary;
    final String currencyLabel = _currencyLabel;

    final Map<String, dynamic>? locationSummary = _buildLocationPayload();
    final List<_InventoryVariation> inventorySummary = _inventoryVariations
        .where((variation) => variation.isComplete)
        .toList(growable: false);


    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('معلومات الإعلان', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('العنوان: ${_titleController.text.isEmpty ? 'غير محدد' : _titleController.text}'),
        const SizedBox(height: 6),
        Text('الوصف: ${_descriptionController.text.isEmpty ? 'غير محدد' : _descriptionController.text}'),
        const SizedBox(height: 6),
        Text('السعر: ${_priceController.text.isEmpty ? 'غير محدد' : _priceController.text} $currencyLabel'),
        const SizedBox(height: 6),
        Text('رقم التواصل: ${_contactController.text.isEmpty ? 'غير محدد' : _contactController.text}'),
        const Divider(height: 32),
        Text('الفئة الرئيسية: ${_selectedMainCategory?.name ?? 'غير محدد'}'),
        const SizedBox(height: 8),
        Text('الفئة الفرعية: ${_selectedSubCategory?.name ?? 'غير محدد'}'),
        const SizedBox(height: 8),
        Text('واجهة العرض: ${_selectedMainCategory?.interfaceType ?? 'غير محدد'}'),
        const Divider(height: 32),
        Text('الحقول المخصّصة', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (customFieldSummary.isEmpty)
          Text('لا توجد قيم محفوظة للحقول المخصّصة.', style: theme.textTheme.bodySmall)
        else
          ...customFieldSummary,


        if (locationSummary != null) ...[
          const Divider(height: 32),
          Text('الموقع', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('العنوان: ${locationSummary['address']}'),
          Text('خط العرض: ${locationSummary['latitude']}'),
          Text('خط الطول: ${locationSummary['longitude']}'),
        ],

        if (inventorySummary.isNotEmpty) ...[
          const Divider(height: 32),
          Text('تنويعات المخزون', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...inventorySummary.map((variation) {
            final String price = variation.priceText.trim();
            final String quantity = variation.quantityText.trim();
            final String sku = variation.sku.trim();
            final String name =
            variation.name.trim().isEmpty ? 'تنويعة بدون اسم' : variation.name.trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('السعر: ${price.isEmpty ? 'غير محدد' : price}'),
                  Text('الكمية: ${quantity.isEmpty ? 'غير محددة' : quantity}'),
                  if (sku.isNotEmpty) Text('SKU: $sku'),
                ],
              ),
            );
          }),
        ],

        const Divider(height: 32),
        Text('الوسائط', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (images.isEmpty && videos.isEmpty && _videoLinks.isEmpty)
          Text('لم تتم إضافة وسائط.', style: theme.textTheme.bodySmall)
        else ...[
          if (images.isNotEmpty)
            Text('عدد الصور: ${images.length}', style: theme.textTheme.bodyMedium),
          if (videos.isNotEmpty)
            Text('عدد الفيديوهات: ${videos.length}', style: theme.textTheme.bodyMedium),
          if (_videoLinks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('روابط الفيديو:', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            ..._videoLinks.map((String link) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(link, style: theme.textTheme.bodySmall),
            )),
          ],
        ],
        if (isShein) ...[
          const Divider(height: 32),
          Text('تفاصيل قسم شي إن', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('رابط المنتج: ${_sheinProductLinkController.text.isEmpty ? 'غير متوفر' : _sheinProductLinkController.text}'),
          const SizedBox(height: 6),
          Text('رابط المراجعة: ${_sheinReviewLinkController.text.isEmpty ? 'غير متوفر' : _sheinReviewLinkController.text}'),
        ],
      ],
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
  const _MediaPreviewCard({super.key, required this.media, required this.onRemove});

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
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
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
            HelperUtils.getFileSizeString(bytes: media.sizeInBytes, decimals: 1),
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
                  Icon(Icons.movie_filter_outlined, size: 16, color: colors.tertiary),
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
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
}

class _SubCategoryOption {
  const _SubCategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}