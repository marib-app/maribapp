import 'package:flutter/material.dart';

import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_model.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/imagePicker.dart';

class AddItemDetailsInitializationService {
  AddItemDetailsInitializationService({
    required this.model,
    required CloudState state,
    required this.refresh,
    required this.onSheinCategoryChanged,
  }) : _state = state;

  final AddItemDetailsModel model;
  final CloudState _state;
  final VoidCallback refresh;
  final void Function(Iterable<int> ids, {bool notify}) onSheinCategoryChanged;

  void initialize() {
    AbstractField.fieldsData.clear();
    AbstractField.files.clear();
    model.resetLegacyCustomFields();

    model.coverImagePicker.listener(_handleCoverImageUpdate);
    model.galleryPicker.listener(_handleGalleryUpdate);

    if (model.isEdit) {
      _initFromEditRequest();
    } else {
      _initForCreate();
    }
  }

  void dispose() {
    model.coverImagePicker.removeListener(_handleCoverImageUpdate);
    model.galleryPicker.removeListener(_handleGalleryUpdate);
  }

  void _handleCoverImageUpdate(dynamic _) {
    model.coverImageUrl = '';
    if (model.isCoverUpdateScheduled) {
      return;
    }
    model.isCoverUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      model.isCoverUpdateScheduled = false;
      refresh();
    });
  }

  void _handleGalleryUpdate(dynamic images) {
    try {
      model.galleryItems.addAll(List<dynamic>.from(images as Iterable));
    } catch (_) {
      // ignore malformed payloads
    }
    refresh();
  }

  void _initFromEditRequest() {
    model.item = _state.getCloudData('edit_request') as ItemModel?;
    _state.clearCloudData('item_details');
    _state.clearCloudData('with_more_details');

    final ItemModel? current = model.item;
    if (current == null) {
      return;
    }

    model.adTitleController.text = current.name ?? '';
    model.adDescriptionController.text = current.description ?? '';

    final String? initialPrice = _initialPriceText(current);
    if (initialPrice != null) {
      model.adPriceController.text = initialPrice;
    }

    model.adPhoneNumberController.text = current.contact ?? '';
    model.adAdditionalDetailsController.text = current.videoLink ?? '';
    model.reviewLinkController.text = current.reviewLink ?? '';
    model.adProductLinkController.text = current.productLink ?? '';

    model.coverImageUrl = HelperUtils.absoluteImage(current.image);
    model.selectedCurrency = current.currency ?? 'YER';

    final Iterable<int> ids = _initialCategoryIdsFromItem(current);
    model.selectedCategoryIds
      ..clear()
      ..addAll(ids);
    onSheinCategoryChanged(ids, notify: false);

    model.galleryItems
      ..clear()
      ..addAll(_buildInitialGalleryItems(current));
  }

  void _initForCreate() {
    if (model.breadcrumbItems.isEmpty) {
      return;
    }

    final List<int> ids =
    model.breadcrumbItems.map((CategoryModel e) => e.id!).toList();
    model.selectedCategoryIds
      ..clear()
      ..addAll(ids);
    onSheinCategoryChanged(ids, notify: false);

    final String? defaultPhone = HiveUtils.getUserDetails().mobile;
    if (defaultPhone?.isNotEmpty ?? false) {
      model.adPhoneNumberController.text = defaultPhone!;
    }
  }

  String? _initialPriceText(ItemModel item) {
    final num? rawPrice = item.price ?? item.finalPrice;
    if (rawPrice == null) {
      return null;
    }

    if (rawPrice is int) {
      return rawPrice.toString();
    }

    final double parsed = rawPrice.toDouble();
    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }

    return parsed.toInt().toString();
  }

  Iterable<Map<String, dynamic>> _buildInitialGalleryItems(ItemModel item) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    final String imageUrl = HelperUtils.absoluteImage(item.image);
    if (imageUrl.isNotEmpty) {
      result.add(<String, dynamic>{
        'id': null,
        'url': imageUrl,
        'isMain': true,
      });
    }

    final gallery = item.galleryImages ?? const [];
    for (final image in gallery) {
      final String url = HelperUtils.absoluteImage(image.image);
      if (url.isEmpty) {
        continue;
      }
      result.add(<String, dynamic>{
        'id': image.id,
        'url': url,
      });
    }
    return result;
  }

  Iterable<int> _initialCategoryIdsFromItem(ItemModel item) {
    final String? allIds = item.allCategoryIds;
    if (allIds != null && allIds.isNotEmpty) {
      return allIds
          .split(',')
          .map((String e) => int.tryParse(e.trim()))
          .whereType<int>();
    }

    final int? fallback = item.categoryId ?? item.category?.id;
    if (fallback != null) {
      return <int>[fallback];
    }
    return const Iterable<int>.empty();
  }
}