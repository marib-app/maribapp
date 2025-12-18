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
  String? selectedCurrency;
  String selectedCountryCode = '+967';
  String coverImageUrl = '';

  bool isUploadingGallery = false;
  bool isSheinCategory = false;
  bool isFetchingShein = false;
  bool isCoverUpdateScheduled = false;
  bool isSubmittingWithoutLocation = false;

  bool _priceListenerAttached = false;
  bool _isFormattingPrice = false;

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

  void ensurePriceFormatterAttached() {
    if (_priceListenerAttached) return;
    _priceListenerAttached = true;
    adPriceController.addListener(_formatPriceField);
    _formatPriceField();
  }

  void _formatPriceField() {
    if (_isFormattingPrice) return;
    final String raw = adPriceController.text;
    final TextSelection selection = adPriceController.selection;
    final String formatted = _formatGrouped(raw);
    if (formatted == raw) return;

    // Adjust caret to best-effort position near the end
    int newOffset = selection.baseOffset + (formatted.length - raw.length);
    if (newOffset < 0) newOffset = 0;
    if (newOffset > formatted.length) newOffset = formatted.length;

    _isFormattingPrice = true;
    adPriceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _isFormattingPrice = false;
  }

  String _formatGrouped(String raw) {
    // Keep digits and a single decimal point. Commas are added as thousand separators.
    final String cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return '';

    final int dotIndex = cleaned.indexOf('.');
    String intPart = dotIndex == -1 ? cleaned : cleaned.substring(0, dotIndex);
    String fracPart = dotIndex == -1
        ? ''
        : cleaned.substring(dotIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');

    // Group from the right every 3 digits with commas.
    final RegExp groupRe = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final String groupedInt = intPart.replaceAllMapped(groupRe, (Match m) => ',');

    if (fracPart.isEmpty) return groupedInt;
    return '$groupedInt.$fracPart';
  }
}
