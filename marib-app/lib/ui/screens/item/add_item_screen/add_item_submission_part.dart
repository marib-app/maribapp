part of 'add_item_submission.dart';

class AddItemDetailsSubmissionService {
  AddItemDetailsSubmissionService({
    required this.model,
    required CloudState state,
    required this.refresh,
    required this.onSheinCategoryChanged,
  }) : _state = state;

  final AddItemDetailsModel model;
  final CloudState _state;
  final VoidCallback refresh;
  final void Function(Iterable<int> ids, {bool notify}) onSheinCategoryChanged;

  int _screenStack = 0;

  final List<Map<String, String>> arabCountries = const <Map<String, String>>[
    {'name': 'اليمن', 'code': '+967'},
    {'name': 'السعودية', 'code': '+966'},
    {'name': 'مصر', 'code': '+20'},
    {'name': 'الإمارات', 'code': '+971'},
    {'name': 'الأردن', 'code': '+962'},
    {'name': 'سوريا', 'code': '+963'},
    {'name': 'العراق', 'code': '+964'},
    {'name': 'الكويت', 'code': '+965'},
    {'name': 'البحرين', 'code': '+973'},
    {'name': 'قطر', 'code': '+974'},
    {'name': 'عُمان', 'code': '+968'},
    {'name': 'الجزائر', 'code': '+213'},
    {'name': 'تونس', 'code': '+216'},
    {'name': 'ليبيا', 'code': '+218'},
    {'name': 'المغرب', 'code': '+212'},
    {'name': 'موريتانيا', 'code': '+222'},
    {'name': 'فلسطين', 'code': '+970'},
    {'name': 'لبنان', 'code': '+961'},
    {'name': 'السودان', 'code': '+249'},
    {'name': 'جيبوتي', 'code': '+253'},
  ];

// add_item_details_submission_service.dart
  bool supportsProductOptions({
    String? interfaceType,
    List<dynamic>? categoryIds,
    bool isSheinCategory = false,
    required String storeRootId,        // Constant.storeRootCategoryIdAsString
  }) {
    final it = (interfaceType ?? '').toLowerCase().trim();
    // الأقسام المسموح بها بالاسم
    const allowedTypes = {'shein_products', 'computer_section'};
    if (allowedTypes.contains(it)) return true;
    if (isSheinCategory) return true;

    // فحص بالمعرفات (من القيم التي أعطيتنيها)
    final ids = {
      ...?(categoryIds?.map((e) => e.toString())),
    };
    if (ids.contains(storeRootId)) return true; // متجر
    if (ids.contains('4')) return true;         // شي إن root = 4
    if (ids.contains('5')) return true;         // كمبيوتر root = 5
    return false;
  }



  Future<void> openProductManagementOrCreateDraft(BuildContext context) async {
    final ItemModel current = model.item ?? ItemModel();

    // تحقق القسم (متجر/كمبيوتر/شي إن)
    if (!supportsProductOptionsForItem(current)) {
      HelperUtils.showSnackBarMessage(
        context,
        'خيارات المنتج متاحة فقط لأقسام المتجر أو الكمبيوتر أو شي إن',
      );
      return;
    }

    // Debug: report current local image state before validation
    final int id = current.id ?? 0;
    try {
      // Extract gallery files robustly (support File or Map{'file': File})
      final List<File> galleryFilesExtracted = <File>[];
      File? flaggedMainFromMap;
      for (final dynamic entry in model.galleryItems) {
        if (entry is File) {
          galleryFilesExtracted.add(entry);
        } else if (entry is Map) {
          final dynamic rawFile = entry['file'];
          if (rawFile is File) {
            galleryFilesExtracted.add(rawFile);
            if (entry['isMain'] == true) flaggedMainFromMap = rawFile;
          }
        }
      }

      final dynamic main = model.coverImageFile ?? flaggedMainFromMap;
      if (kDebugMode) {
        print('[debug] openProductManagementOrCreateDraft: item.id=$id main=${main != null} galleryFiles=${galleryFilesExtracted.length} flaggedMainFromMap=${flaggedMainFromMap != null}');
      }
    } catch (e) {
      if (kDebugMode) print('[debug] openProductManagementOrCreateDraft error: $e');
    }
    // لو عنده id جاهز: افتح مباشرة
    
    if (id > 0) {
      Navigator.pushNamed(
        context,
        Routes.productManagementScreen,
        arguments: current, // يدعمه _resolveItem(arguments)
      );
      return;
    }

    // ما في id ⇒ أنشئ مسودة سريعة بدون موقع (تحتاج صورة على الأقل)
    // Build mainImageFile and galleryFiles considering Map entries
    final List<File> galleryFiles = <File>[];
    File? flaggedMainFile;
    for (final dynamic entry in model.galleryItems) {
      if (entry is File) {
        galleryFiles.add(entry);
      } else if (entry is Map) {
        final dynamic rawFile = entry['file'];
        if (rawFile is File) {
          galleryFiles.add(rawFile);
          if (entry['isMain'] == true) flaggedMainFile = rawFile;
        }
      }
    }

    File? mainImageFile = model.coverImageFile ?? flaggedMainFile ?? (galleryFiles.isNotEmpty ? galleryFiles.first : null);
    if (mainImageFile != null) {
      final String mainPath = mainImageFile.path;
      galleryFiles.removeWhere((File file) => file.path == mainPath);
    }

    if (mainImageFile == null && galleryFiles.isEmpty) {
      HelperUtils.showSnackBarMessage(context, 'Cannot continue without images');
      return;
    }

    final Map<String, dynamic> stored =
        (_state.getCloudData('with_more_details') as Map<String, dynamic>?) ??
            <String, dynamic>{};

    String _normalizedTitle(dynamic value) {
      if (value == null) return '';
      if (value is String) {
        return value.trim();
      }
      return value.toString().trim();
    }

    final String currentTitle = model.adTitleController.text.trim();

    final bool hasStoredTitle =
        _normalizedTitle(stored['title']).isNotEmpty;
    if (!hasStoredTitle) {
      stored['title'] = currentTitle;
    }

    final bool hasStoredName = _normalizedTitle(stored['name']).isNotEmpty;
    if (!hasStoredName) {
      stored['name'] = hasStoredTitle
          ? _normalizedTitle(stored['title'])
          : currentTitle;
    }
    if (!stored.containsKey('description')) {
      stored['description'] = model.adDescriptionController.text.trim();
    }
    if (!stored.containsKey('price')) {
      stored['price'] = model.adPriceController.text.trim();
    }
    if (!stored.containsKey('currency') && model.selectedCurrency != null) {
      stored['currency'] = model.selectedCurrency;
    }
    if (!stored.containsKey('contact')) {
      stored['contact'] = model.adPhoneNumberController.text.trim();
    }
    if (!stored.containsKey('contact_country_code')) {
      stored['contact_country_code'] = model.selectedCountryCode;
    }
    if (!stored.containsKey('video_link')) {
      stored['video_link'] = model.adAdditionalDetailsController.text.trim();
    }
    if (!stored.containsKey('review_link')) {
      stored['review_link'] = model.reviewLinkController.text.trim();
    }
    if (!stored.containsKey('product_link')) {
      stored['product_link'] = model.adProductLinkController.text.trim();
    }

    if (!stored.containsKey('all_category_ids') ||
        (stored['all_category_ids']?.toString().trim().isEmpty ?? true)) {
      final Iterable<int> categories = currentCategoryIds();
      if (categories.isNotEmpty) {
        stored['all_category_ids'] =
            categories.map((int id) => id.toString()).join(',');
        stored['category_id'] = categories.last;
      }
    }

    final PendingItemDraft? draft = _preparePendingDraftWithoutLocation(
      context: context,
      baseData: stored,
      mainImageFile: mainImageFile,
      galleryFiles: galleryFiles,
    );

    if (draft == null) {
      return;
    }

    model.pendingDraft = draft;
    model.item = draft.item;
    model.isSubmittingWithoutLocation = true;

    Navigator.of(context, rootNavigator: true)
        .pushNamed(
          Routes.productManagementScreen,
          arguments: <String, dynamic>{
            'item': draft.item,
            'pendingDraft': draft,
          },
        )
        .whenComplete(() => model.isSubmittingWithoutLocation = false);
  }

  /// Debug helper: print the current image-related state and what would be
  /// chosen as the main image and gallery files. This does not perform any
  /// navigation or side-effects.
  void debugDumpImageState(BuildContext context) {
    try {
      final ItemModel current = model.item ?? ItemModel();
      final List<String> galleryTypes = <String>[];
      final List<File> galleryFiles = <File>[];
      File? flaggedMainFromMap;

      for (final dynamic entry in model.galleryItems) {
        if (entry is File) {
          galleryFiles.add(entry);
          galleryTypes.add('File(${entry.path.split(RegExp(r"[\\\\/]")).last})');
        } else if (entry is Map) {
          final dynamic rawFile = entry['file'];
          if (rawFile is File) {
            galleryFiles.add(rawFile);
            galleryTypes.add('Map(file:${rawFile.path.split(RegExp(r"[\\\\/]")).last})');
            if (entry['isMain'] == true) flaggedMainFromMap = rawFile;
          } else {
            galleryTypes.add('Map(url:${entry['url'] ?? ''})');
          }
        } else if (entry is String) {
          galleryTypes.add('String(url:$entry)');
        } else {
          galleryTypes.add(entry.runtimeType.toString());
        }
      }

      final File? coverFile = model.coverImageFile;
      final String coverUrl = model.coverImageUrl;
      final File? computedMain = coverFile ?? flaggedMainFromMap ?? (galleryFiles.isNotEmpty ? galleryFiles.first : null);

      if (kDebugMode) {
        // ignore: avoid_print
        print('[debug] debugDumpImageState: coverFile=${coverFile?.path} coverUrl=$coverUrl galleryItems=[${galleryTypes.join(', ')}] galleryFilesCount=${galleryFiles.length} flaggedMainFromMap=${flaggedMainFromMap?.path} computedMain=${computedMain?.path}');
      }

      HelperUtils.showSnackBarMessage(context, 'DBG: see console for image-state');
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[debug] debugDumpImageState error: $e');
      }
      HelperUtils.showSnackBarMessage(context, 'DBG failed');
    }
  }





  void handleSubmit(BuildContext context) {
    if (!(model.formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String rawPrice = model.adPriceController.text.trim();
    if (rawPrice.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'الرجاء إدخال سعر الإعلان',
      );
      return;
    }

    if ((model.selectedCurrency ?? '').trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'الرجاء اختيار العملة',
      );
      return;
    }

    model.resetLegacyCustomFields();

    final List<File> galleryFiles = <File>[];
    File? mainImageFile = model.coverImageFile;
    File? flaggedMainFile;

    for (final dynamic entry in model.galleryItems) {
      File? file;
      if (entry is File) {
        file = entry;
      } else if (entry is Map) {
        final dynamic rawFile = entry['file'];
        if (rawFile is File) {
          file = rawFile;
        }
        if (entry['isMain'] == true && rawFile is File) {
          flaggedMainFile = rawFile;
        }
      }

      if (file != null) {
        galleryFiles.add(file);
      }
    }

    if (mainImageFile == null) {
      mainImageFile =
          flaggedMainFile ?? (galleryFiles.isNotEmpty ? galleryFiles.first : null);
    }

    if (mainImageFile != null) {
      final String mainPath = mainImageFile.path;
      galleryFiles.removeWhere((File file) => file.path == mainPath);
    }

    if (mainImageFile == null && model.coverImageUrl.isEmpty) {
      UiUtils.showBlurredDialoge(
        context,
        dialoge: const BlurredDialogBox(
          title: 'الصورة مطلوبة',
          content: Text('يرجى اختيار صورة واحدة على الأقل لإعلانك.'),
        ),
      );
      return;
    }

    final List<int> categoryIds = currentCategoryIds().toList(growable: false);
    onSheinCategoryChanged(categoryIds, notify: false);
    final bool disableLocation = GeoRules.isDisabled(categoryIds: categoryIds);

    final String normalizedTitle = model.adTitleController.text.trim();

    final Map<String, dynamic> data = <String, dynamic>{
      'name': normalizedTitle,
      'title': normalizedTitle,
      'description': model.adDescriptionController.text.trim(),
      'price': model.adPriceController.text.trim(),
      'currency': model.selectedCurrency,
      'contact': model.adPhoneNumberController.text.trim(),
      'contact_country_code': model.selectedCountryCode,
      'video_link': model.adAdditionalDetailsController.text.trim(),
      if (!model.isEdit)
        'category_id': categoryIds.isNotEmpty
            ? categoryIds.last
            : (model.selectedCategoryIds.isNotEmpty
            ? model.selectedCategoryIds.last
            : null),
      if (model.isEdit) 'id': model.item?.id,
      if (model.isEdit && model.deletedImageIds.isNotEmpty)
        'delete_item_image_id': model.deletedImageIds.join(','),
      'all_category_ids': model.isEdit
          ? ((model.item?.allCategoryIds?.isNotEmpty ?? false)
          ? model.item!.allCategoryIds!
          : model.item?.categoryId?.toString() ??
          model.item?.category?.id?.toString() ??
          model.selectedCategoryIds.join(','))
          : model.selectedCategoryIds.join(','),
    }..removeWhere(
          (String key, dynamic value) =>
      value == null || (value is String && value.isEmpty),
    );

    final Map<String, dynamic>? rawMoreDetails =
    _state.getCloudData('more_details_data') as Map<String, dynamic>?;
    final Map<String, dynamic> sanitizedMoreDetails =
    _sanitizeMoreDetailsPayload(rawMoreDetails);

    if (sanitizedMoreDetails.isNotEmpty) {
      _state.addCloudData('more_details_data', sanitizedMoreDetails);
      data.addAll(sanitizedMoreDetails);
    } else if (rawMoreDetails != null && rawMoreDetails.isNotEmpty) {
      _state.clearCloudData('more_details_data');
    }

    if (model.isSheinCategory) {
      final String reviewLink = model.reviewLinkController.text.trim();
      if (reviewLink.isNotEmpty) {
        data['review_link'] = reviewLink;
      }
      final String productLink = model.adProductLinkController.text.trim();
      if (productLink.isNotEmpty) {
        data['product_link'] = productLink;
      }
    } else {
      data.remove('review_link');
      data.remove('product_link');
    }

    _state.addCloudData('item_details', data);
    _state.addCloudData('with_more_details', data);

    if (disableLocation) {
      final PendingItemDraft? draft = _preparePendingDraftWithoutLocation(
        context: context,
        baseData: data,
        mainImageFile: mainImageFile,
        galleryFiles: galleryFiles,
      );

      if (draft == null) {
        return;
      }

      model.pendingDraft = draft;
      model.item = draft.item;
      model.isSubmittingWithoutLocation = true;

      Navigator.of(context, rootNavigator: true)
          .pushNamed(
            Routes.productManagementScreen,
            arguments: <String, dynamic>{
              'item': draft.item,
              'pendingDraft': draft,
            },
          )
          .whenComplete(() => model.isSubmittingWithoutLocation = false);
      return;
    }

    _screenStack++;

    Navigator.pushNamed(
      context,
      Routes.confirmLocationScreen,
      arguments: <String, dynamic>{
        'isEdit': model.isEdit,
        'mainImage': mainImageFile,
        'otherImage': galleryFiles,
      },
    ).then((dynamic value) {
      _screenStack--;

      if (value is Map) {
        model.latitude = value['lat'] as double?;
        model.longitude = value['lng'] as double?;
        model.locationAddress = value['address'] as String?;
        refresh();
      }
    });
  }

  void handleManageItemState(BuildContext context, ManageItemState state) {
    if (!model.isSubmittingWithoutLocation) {
      return;
    }

    if (state is ManageItemInProgress) {
      Widgets.showLoader(context);
      return;
    }

    if (state is ManageItemSuccess) {
      Widgets.hideLoder(context);
      model.isSubmittingWithoutLocation = false;
      model.item = state.model;
      final dynamic editKey = _state.getCloudData('edit_from');
      if (editKey is String && editKey.isNotEmpty) {
        myAdsCubitReference[editKey]?.edit(state.model);
      }
      Future.microtask(() {
        if (!context.mounted) {
          return;
        }
        final bool openProductManagement =
            state.type == ManageItemType.add &&
                supportsProductOptionsForItem(state.model);

        if (openProductManagement) {
          Navigator.pushNamed(
            context,
            Routes.productManagementScreen,
            arguments: <String, dynamic>{'model': state.model},
          );
        } else {
          Navigator.pushNamed(
            context,
            Routes.successItemScreen,
            arguments: <String, dynamic>{
              'model': state.model,
              'isEdit': model.isEdit,
            },
          );
        }
      });
      return;
    }

    if (state is ManageItemFail) {
      Widgets.hideLoder(context);
      model.isSubmittingWithoutLocation = false;
      final dynamic filteredError = ErrorFilter.check(state.error).error;
      final String message = filteredError is String
          ? filteredError
          : filteredError.toString();
      HelperUtils.showSnackBarMessage(context, message);
    }
  }

  Iterable<int> currentCategoryIds() {
    if (model.selectedCategoryIds.isNotEmpty) {
      return model.selectedCategoryIds;
    }

    if (model.isEdit) {
      final String? ids = model.item?.allCategoryIds;
      if (ids?.isNotEmpty ?? false) {
        return ids!
            .split(',')
            .map((String e) => int.tryParse(e.trim()))
            .whereType<int>();
      }
      final int? fallback = model.item?.categoryId ?? model.item?.category?.id;
      if (fallback != null) {
        return <int>[fallback];
      }
    }
    return const Iterable<int>.empty();
  }

  bool supportsProductOptionsForItem(ItemModel model) {
    if (GeoRules.isMapEnabledForItem(model)) {
      return false;
    }

    final Iterable<int> categoryIds = currentCategoryIds();
    if (_hasMapSectionCategory(categoryIds)) {
      return false;
    }

    if (isEcommerceItem(model)) {
      return true;
    }

    final List<int> ecommerceCategoryIds =
    _ecommerceEligibleCategoryIds(categoryIds);
    if (ecommerceCategoryIds.isNotEmpty &&
        supportsEcommerceByCategories(ecommerceCategoryIds)) {
      return true;
    }
    return false;
  }

  bool _shouldOpenProductManagement(PendingItemDraft draft) {
    if (supportsProductOptionsForItem(draft.item)) {
      return true;
    }

    final Iterable<int> categories = draft.categoryPath;
    if (categories.isEmpty || _hasMapSectionCategory(categories)) {
      return false;
    }

    if (supportsEcommerceByCategories(
        _ecommerceEligibleCategoryIds(categories))) {
      return true;
    }

    return supportsProductOptions(
      interfaceType: draft.item.departmentSlug,
      categoryIds: categories.toList(),
      isSheinCategory: model.isSheinCategory,
      storeRootId: Constant.storeRootCategoryIdAsString,
    );
  }

  Map<String, dynamic> _sanitizeMoreDetailsPayload(
      Map<String, dynamic>? rawData) {
    if (rawData == null || rawData.isEmpty) {
      return <String, dynamic>{};
    }

    final Map<String, dynamic> sanitized = <String, dynamic>{};
    rawData.forEach((String key, dynamic value) {
      if (value == null) {
        return;
      }

      if (key == 'custom_fields') {
        final String? normalized = _sanitizeCustomFieldsValue(value);
        if (normalized != null && normalized.isNotEmpty) {
          sanitized[key] = normalized;
        }
        return;
      }

      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isEmpty || trimmed == '{}' || trimmed == '[]') {
          return;
        }
        sanitized[key] = trimmed;
        return;
      }

      if (value is Iterable) {
        if (value.isEmpty) {
          return;
        }
        sanitized[key] = value;
        return;
      }

      if (value is Map) {
        if (value.isEmpty) {
          return;
        }
        sanitized[key] = value;
        return;
      }

      sanitized[key] = value;
    });

    return sanitized;
  }

  String? _sanitizeCustomFieldsValue(dynamic raw) {
    if (raw == null) {
      return null;
    }

    Map<String, dynamic>? decoded;

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed == '{}' || trimmed == '[]') {
        return null;
      }
      try {
        final dynamic jsonValue = json.decode(trimmed);
        if (jsonValue is Map) {
          decoded = Map<String, dynamic>.from(jsonValue);
        } else {
          // Not a map; keep the trimmed string as-is.
          return trimmed;
        }
      } catch (_) {
        // Invalid JSON, fall back to original string.
        return trimmed;
      }
    } else if (raw is Map) {
      decoded = Map<String, dynamic>.from(raw);
    } else {
      return raw.toString();
    }

    if (decoded == null || decoded.isEmpty) {
      return null;
    }

    final Map<String, dynamic> filtered = <String, dynamic>{};
    decoded.forEach((dynamic key, dynamic value) {
      final String normalizedKey = key?.toString().trim() ?? '';
      if (normalizedKey.isEmpty) {
        return;
      }
      final dynamic cleanedValue = _pruneCustomFieldValue(value);
      if (cleanedValue == null) {
        return;
      }
      filtered[normalizedKey] = cleanedValue;
    });

    if (filtered.isEmpty) {
      return null;
    }

    final Set<String>? allowedIds = _activeCustomFieldIds();
    if (allowedIds != null && allowedIds.isNotEmpty) {
      final List<String> originalKeys = List<String>.from(filtered.keys);
      filtered.removeWhere(
        (String key, dynamic _) => !allowedIds.contains(key),
      );
      debugPrint(
        '[AddItemSubmission] custom_fields filtered from '
        '${originalKeys.join(',')} to ${filtered.keys.join(',')} '
        'allowed=$allowedIds',
      );
      if (filtered.isEmpty) {
        return null;
      }
    } else {
      debugPrint(
        '[AddItemSubmission] custom_fields retained keys ${filtered.keys.join(',')} '
        '(no active filter)',
      );
    }

    return json.encode(filtered);
  }

  dynamic _pruneCustomFieldValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is Iterable) {
      final List<dynamic> cleaned = value
          .map(_pruneCustomFieldValue)
          .where((dynamic entry) => entry != null)
          .toList();
      if (cleaned.isEmpty) {
        return null;
      }
      return cleaned;
    }

    if (value is Map) {
      final Map<String, dynamic> cleaned = <String, dynamic>{};
      value.forEach((dynamic key, dynamic nestedValue) {
        final String normalizedKey = key?.toString().trim() ?? '';
        if (normalizedKey.isEmpty) {
          return;
        }
        final dynamic nestedCleaned = _pruneCustomFieldValue(nestedValue);
        if (nestedCleaned == null) {
          return;
        }
        cleaned[normalizedKey] = nestedCleaned;
      });
      if (cleaned.isEmpty) {
        return null;
      }
      return cleaned;
    }

    return value;
  }

  Set<String>? _activeCustomFieldIds() {
    final dynamic raw = _state.getCloudData('active_custom_field_ids');
    if (raw == null) {
      return null;
    }

    Iterable<dynamic> source;
    if (raw is Iterable) {
      source = raw;
    } else if (raw is String) {
      source = raw.split(',');
    } else {
      source = <dynamic>[raw];
    }

    final Set<String> normalized = <String>{};
    for (final dynamic entry in source) {
      final String value = entry?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        normalized.add(value);
      }
    }

    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  PendingItemDraft? _preparePendingDraftWithoutLocation({
    required BuildContext context,
    required Map<String, dynamic> baseData,
    required File? mainImageFile,
    required List<File> galleryFiles,
  }) {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(baseData);

    payload.removeWhere((String key, dynamic value) =>
        value == null || (value is String && value.trim().isEmpty));

    final double? effectiveLat = _coerceCoordinate(
      payload['latitude'] ??
          payload['location_latitude'] ??
          model.latitude,
    );
    final double? effectiveLng = _coerceCoordinate(
      payload['longitude'] ??
          payload['location_longitude'] ??
          model.longitude,
    );

    if (effectiveLat != null) {
      payload['latitude'] = effectiveLat;
      payload['location_latitude'] = effectiveLat;
    } else {
      payload.remove('latitude');
      payload.remove('location_latitude');
    }
    model.latitude = effectiveLat;

    if (effectiveLng != null) {
      payload['longitude'] = effectiveLng;
      payload['location_longitude'] = effectiveLng;
    } else {
      payload.remove('longitude');
      payload.remove('location_longitude');
    }
    model.longitude = effectiveLng;

    final String? normalizedAddress = _normalizeString(
      payload['address'] ?? model.locationAddress,
    );
    if (normalizedAddress != null) {
      payload['address'] = normalizedAddress;
      model.locationAddress = normalizedAddress;
    } else {
      payload.remove('address');
    }

    final String? normalizedCity = _normalizeString(payload['city']);
    if (normalizedCity != null) {
      payload['city'] = normalizedCity;
    } else {
      final String? fallbackCity = _normalizeString(HiveUtils.getCityName());
      if (fallbackCity != null) {
        payload['city'] = fallbackCity;
      } else {
        payload.remove('city');
      }
    }

    final int? normalizedAreaId = _normalizeInt(payload['area_id']);
    if (normalizedAreaId != null) {
      payload['area_id'] = normalizedAreaId;
    } else {
      final int? fallbackAreaId = _normalizeInt(HiveUtils.getAreaId());
      if (fallbackAreaId != null) {
        payload['area_id'] = fallbackAreaId;
      } else {
        payload.remove('area_id');
      }
    }

    final String? normalizedState = _normalizeString(payload['state']);
    if (normalizedState != null) {
      payload['state'] = normalizedState;
    } else {
      final String? fallbackState = _normalizeString(HiveUtils.getStateName());
      if (fallbackState != null) {
        payload['state'] = fallbackState;
      } else {
        payload.remove('state');
      }
    }

    final String? normalizedCountry = _normalizeString(payload['country']);
    if (normalizedCountry != null) {
      payload['country'] = normalizedCountry;
    } else {
      final String? fallbackCountry =
          _normalizeString(HiveUtils.getCountryName()) ?? 'Yemen';
      payload['country'] = fallbackCountry;
    }

    if (!model.isEdit && mainImageFile == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'يرجى إضافة صورة رئيسية قبل المتابعة.',
      );
      return null;
    }

    final ItemModel source = model.item ?? ItemModel();
    final String? payloadNameRaw =
        (payload['name'] ?? payload['title'])?.toString();

    final ItemModel draftItem = source.copyWith(
      name: payloadNameRaw,
      description: payload['description']?.toString(),
      price: _parsePrice(payload['price']),
      currency: payload['currency']?.toString(),
      contact: payload['contact']?.toString(),
      videoLink: payload['video_link']?.toString(),
      reviewLink: payload['review_link']?.toString(),
      productLink: payload['product_link']?.toString(),
      allCategoryIds: payload['all_category_ids']?.toString(),
      categoryId: _normalizeInt(payload['category_id']),
      address: payload['address']?.toString(),
      city: payload['city']?.toString(),
      state: payload['state']?.toString(),
      country: payload['country']?.toString(),
      status: source.status ?? 'draft',
    );

    final List<int> categoryPath =
        currentCategoryIds().toList(growable: false);

    final String? editSourceKey =
        _state.getCloudData('edit_from') as String?;

    return PendingItemDraft(
      payload: payload,
      item: draftItem,
      mainImage: mainImageFile,
      galleryImages: galleryFiles,
      isEdit: model.isEdit,
      editSourceKey: editSourceKey,
      categoryPath: categoryPath,
    );
  }

  String? _normalizeString(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final String trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _normalizeInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value > 0 ? value : null;
    }
    if (value is num) {
      final int parsed = value.toInt();
      return parsed > 0 ? parsed : null;
    }
    return int.tryParse(value.toString());
  }

  double? _parsePrice(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    final String normalized =
        value.toString().replaceAll(',', '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  double? _coerceCoordinate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    final String normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  List<int> _ecommerceEligibleCategoryIds(Iterable<int> categoryIds) {
    if (categoryIds.isEmpty) {
      return const <int>[];
    }

    return categoryIds
        .where((int id) => !_isMapSectionCategoryId(id))
        .toList(growable: false);
  }

  bool _hasMapSectionCategory(Iterable<int> categoryIds) {
    for (final int id in categoryIds) {
      if (_isMapSectionCategoryId(id)) {
        return true;
      }
    }
    return false;
  }

  bool _isMapSectionCategoryId(int id) {
    return id == Constant.publicRootCategoryId ||
        id == Constant.realEstateRootCategoryId;
  }
}
