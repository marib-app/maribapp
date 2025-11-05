import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/manage_item_cubit.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_model.dart';
import 'package:marib/ui/screens/user_profile/my_item_tab.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/geo_rules.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/ecommerce_department.dart';

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

    // فحص بالمعرّفات (من القيم التي أعطيتنيها)
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

    // تحقّق القسم (متجر/كمبيوتر/شي إن)
    if (!supportsProductOptionsForItem(current)) {
      HelperUtils.showSnackBarMessage(
        context, 'خيارات المنتج متاحة فقط لأقسام المتجر أو الكمبيوتر أو شي إن',
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

    if (mainImageFile == null && galleryFiles.isEmpty) {
      HelperUtils.showSnackBarMessage(context, 'أضف صورة الغلاف أولًا');
      return;
    }

    // هذا يستدعي ManageItem(add)؛ وبعد النجاح handleManageItemState سيفتح شاشة الإدارة تلقائيًا
    _submitWithoutLocation(context, mainImageFile, galleryFiles);
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

    final Map<String, dynamic> data = <String, dynamic>{
      'title': model.adTitleController.text.trim(),
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
      _submitWithoutLocation(
        context,
        mainImageFile,
        galleryFiles,
      );
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

  void _submitWithoutLocation(
      BuildContext context,
      File? mainImageFile,
      List<File> galleryFiles,
      ) {
    final Map<String, dynamic> stored =
        (_state.getCloudData('with_more_details') as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final Map<String, dynamic> payload = Map<String, dynamic>.from(stored);

    payload.removeWhere((String key, dynamic value) =>
    value == null || (value is String && value.trim().isEmpty));

    for (final String key in const <String>[
      'latitude',
      'longitude',
      'location_latitude',
      'location_longitude',
    ]) {
      payload.remove(key);
    }

    payload['address'] =
        _normalizeString(payload['address']) ?? 'المتجر الإلكتروني';

    final String? fallbackCity = _normalizeString(HiveUtils.getCityName());
    if (fallbackCity != null) {
      payload['city'] = fallbackCity;
    } else {
      payload.remove('city');
    }

    final int? fallbackAreaId = _normalizeInt(HiveUtils.getAreaId());
    if (fallbackAreaId != null) {
      payload['area_id'] = fallbackAreaId;
    } else {
      payload.remove('area_id');
    }

    final String? fallbackState = _normalizeString(HiveUtils.getStateName());
    if (fallbackState != null) {
      payload['state'] = fallbackState;
    } else {
      payload.remove('state');
    }

    payload['country'] =
        _normalizeString(HiveUtils.getCountryName()) ?? 'اليمن';

    model.isSubmittingWithoutLocation = true;

    final ManageItemCubit manage = context.read<ManageItemCubit>();

    if (model.isEdit) {
      manage.manage(ManageItemType.edit, payload, mainImageFile, galleryFiles);
    } else {
      if (mainImageFile == null) {
        model.isSubmittingWithoutLocation = false;
        HelperUtils.showSnackBarMessage(context, 'الصورة مطلوبة');
        return;
      }
      manage.manage(ManageItemType.add, payload, mainImageFile, galleryFiles);
    }
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