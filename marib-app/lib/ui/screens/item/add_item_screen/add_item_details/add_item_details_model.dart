import 'dart:io';

import 'package:flutter/material.dart';

import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/imagePicker.dart';
import 'package:marib/ui/screens/item/purchase_options/pending_item_draft.dart';

class AddItemDetailsModel {
  AddItemDetailsModel({
    required List<CategoryModel>? breadcrumbItems,
    required bool? isEdit,
  })  : breadcrumbItems =
  List<CategoryModel>.from(breadcrumbItems ?? const <CategoryModel>[]),
        isEdit = isEdit == true,
        enableTitleAutofocus = isEdit != true;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final ScrollController formScrollController = ScrollController();
  final PageController imageSectionPageController = PageController();

  final PickImage coverImagePicker = PickImage();
  final PickImage galleryPicker = PickImage();

  final TextEditingController adTitleController = TextEditingController();
  final TextEditingController adDescriptionController = TextEditingController();
  final TextEditingController adPriceController = TextEditingController();
  final TextEditingController adPhoneNumberController = TextEditingController();
  final TextEditingController adAdditionalDetailsController =
  TextEditingController();
  final TextEditingController reviewLinkController = TextEditingController();
  final TextEditingController adProductLinkController = TextEditingController();

  final List<CategoryModel> breadcrumbItems;
  final bool isEdit;
  final bool enableTitleAutofocus;

  final List<dynamic> galleryItems = <dynamic>[];
  final List<int> deletedImageIds = <int>[];
  final List<int> selectedCategoryIds = <int>[];
  final List<CustomFieldModel> legacyCustomFields = <CustomFieldModel>[];

  ItemModel? item;
  PendingItemDraft? pendingDraft;
  String selectedCurrency = 'YER';
  String selectedCountryCode = '+967';
  String coverImageUrl = '';

  bool isUploadingGallery = false;
  bool isSheinCategory = false;
  bool isFetchingShein = false;
  bool isCoverUpdateScheduled = false;
  bool isSubmittingWithoutLocation = false;

  double? latitude;
  double? longitude;
  String? locationAddress;

  File? get coverImageFile => coverImagePicker.pickedFile;

  void resetLegacyCustomFields() {
    if (legacyCustomFields.isNotEmpty) {
      legacyCustomFields.clear();
    }
  }

  void dispose() {
    formScrollController.dispose();
    imageSectionPageController.dispose();

    coverImagePicker.dispose();
    galleryPicker.dispose();

    adTitleController.dispose();
    adDescriptionController.dispose();
    adPriceController.dispose();
    adPhoneNumberController.dispose();
    adAdditionalDetailsController.dispose();
    reviewLinkController.dispose();
    adProductLinkController.dispose();
  }
}
