import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:dotted_border/dotted_border.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/screens/widgets/custom_drop_down.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/ui/screens/item/add_item_screen/select_category.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/imagePicker.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'image_section.dart';
// لنماذج الحقول المخصصة
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart'; // فيه CustomTextFieldDynamic
import 'package:marib/data/model/custom_field/custom_field_model.dart';

// ويدجت الحقول المخصصة
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'dart:typed_data';


import 'package:marib/utils/ui_utils.dart';

import 'package:marib/data/model/category_model.dart';
import 'package:path_provider/path_provider.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html; // مكرر مرتين
import 'package:html/dom.dart' as dom;
import 'package:image/image.dart' as img;

import 'shein_grabber_page.dart';

part 'add_item_details_ui.dart';




class AddItemDetails extends StatefulWidget {
  final List<CategoryModel>? breadCrumbItems;
  final bool? isEdit;

  const AddItemDetails({
    super.key,
    this.breadCrumbItems,
    required this.isEdit,
  });

  static Route route(RouteSettings settings) {
    Map<String, dynamic>? arguments =
    settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) {
        return BlocProvider(
          create: (context) => FetchCustomFieldsCubit(),
          child: AddItemDetails(
            breadCrumbItems: arguments?['breadCrumbItems'],
            isEdit: arguments?['isEdit'],
          ),
        );
      },
    );
  }

  @override
  CloudState<AddItemDetails> createState() => _AddItemDetailsState();
}

class _AddItemDetailsState extends CloudState<AddItemDetails>
    with ImageSectionMixin, WidgetsBindingObserver {
  String _selectedCurrency = 'YER';
  final PickImage _pickTitleImage = PickImage();
  final PickImage itemImagePicker = PickImage();
  String titleImageURL = "";
  List<dynamic> mixedItemImageList = [];
  List<int> deleteItemImageList = [];
  final GlobalKey<FormState> _formKey = GlobalKey();
  bool isUploading = false;
  bool isUploaded = false;
  bool isUploadingExtra = false;
  bool isUploadedExtra = false;
  bool _isTitleImageUpdateScheduled = false;

  String _selectedCountryCode = "+967";
  final TextEditingController productLinkController = TextEditingController();
  final TextEditingController reviewLinkController = TextEditingController();

  final TextEditingController adProductLinkController = TextEditingController();
  late final PageController _imageSectionPageController = PageController();
  final ScrollController _formScrollController = ScrollController();
  BuildContext? _lastFocusedFieldContext;
  double _lastFocusedFieldAlignment = 0.2;

  double _lastViewInsetsBottom = 0.0;
  bool _keyboardWasVisible = false;

  Timer? _linkDebounce;
  List<CustomFieldModel>? customFields;           // تأتي من Cubit/API
  bool isLoadingCustomFields = false;             // حالة تحميل
  final Map<int, dynamic> selectedCustomFieldValues = {}; // قيم المُدخلات


  final List<Map<String, String>> arabCountries = [
    {"name": "اليمن", "code": "+967"},
    {"name": "السعودية", "code": "+966"},
    {"name": "مصر", "code": "+20"},
    {"name": "الإمارات", "code": "+971"},
    {"name": "الأردن", "code": "+962"},
    {"name": "سوريا", "code": "+963"},
    {"name": "العراق", "code": "+964"},
    {"name": "الكويت", "code": "+965"},
    {"name": "البحرين", "code": "+973"},
    {"name": "قطر", "code": "+974"},
    {"name": "عُمان", "code": "+968"},
    {"name": "الجزائر", "code": "+213"},
    {"name": "تونس", "code": "+216"},
    {"name": "ليبيا", "code": "+218"},
    {"name": "المغرب", "code": "+212"},
    {"name": "موريتانيا", "code": "+222"},
    {"name": "فلسطين", "code": "+970"},
    {"name": "لبنان", "code": "+961"},
    {"name": "السودان", "code": "+249"},
    {"name": "جيبوتي", "code": "+253"},
  ];

  // ✅ الموقع الذي يختاره المستخدم
  double? latitude;
  double? longitude;

// ✅ العنوان النصي الناتج من الإحداثيات
  String? locationAddress;




  // دالة جلب بيانات المنتج من رابط شي إن


  bool _isFetchingShein = false;

  Future<List<Map<String, dynamic>>> _materializeRemoteImages(
      List<String> imageUrls) async {
    if (imageUrls.isEmpty) {
      return const [];
    }

    final tempDir = await getTemporaryDirectory();
    final List<Map<String, dynamic>> materializedImages = [];

    for (final url in imageUrls) {
      if (url.isEmpty) {
        continue;
      }

      try {
        final uri = Uri.tryParse(url);
        if (uri == null) {
          continue;
        }

        final response = await http.get(uri);
        if (response.statusCode != 200) {
          continue;
        }

        final allowedExtensions = {'jpg', 'jpeg', 'png'};
        final contentType = response.headers['content-type'] ?? '';
        String? headerExtension;
        if (contentType.contains('/')) {
          final typeParts = contentType.split('/');
          if (typeParts.length == 2) {
            headerExtension =
                typeParts.last.split(';').first.trim().toLowerCase();
          }
        }

        String? extensionFromUrl;

        if (uri.pathSegments.isNotEmpty) {
          final lastSegment = uri.pathSegments.last;
          final dotIndex = lastSegment.lastIndexOf('.');
          if (dotIndex != -1 && dotIndex < lastSegment.length - 1) {
            final candidate =
            lastSegment.substring(dotIndex + 1).trim().toLowerCase();

            if (candidate.length <= 5) {
              extensionFromUrl = candidate;
            }
          }
        }

        String resolvedExtension =
        (extensionFromUrl ?? headerExtension ?? 'jpg').toLowerCase();

        final normalizedHeaderExtension = headerExtension?.toLowerCase();
        bool requiresTranscode =
            !allowedExtensions.contains(resolvedExtension) ||
                (normalizedHeaderExtension != null &&
                    !allowedExtensions.contains(normalizedHeaderExtension));

        List<int> bytes = response.bodyBytes;

        if (requiresTranscode) {
          try {
            final decoded = img.decodeImage(Uint8List.fromList(bytes));
            if (decoded == null) {
              debugPrint(
                  'Failed to decode unsupported remote image from $url (content-type: $contentType)');
              continue;
            }
            bytes = img.encodeJpg(decoded);
            resolvedExtension = 'jpg';
          } catch (error) {
            debugPrint('Failed to transcode remote image from $url: $error');
            continue;
          }
        }

        final String fileName =
            'remote_${DateTime.now().microsecondsSinceEpoch}_${materializedImages.length}.$resolvedExtension';
        final File file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        materializedImages.add({'file': file, 'url': url});
      } catch (error) {
        debugPrint('Failed to cache remote image from $url: $error');
      }
    }

    return materializedImages;
  }



  @override
  PageController get imageSectionPageController => _imageSectionPageController;




  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final viewInsetsBottom = dispatcher.views.isNotEmpty
        ? dispatcher.views.first.viewInsets.bottom
        : dispatcher.implicitView?.viewInsets.bottom ?? 0.0;

    final bool isKeyboardVisible = viewInsetsBottom > 0;
    if (!isKeyboardVisible) {
      if (_keyboardWasVisible || _lastViewInsetsBottom != 0.0) {
        _keyboardWasVisible = false;
        _lastViewInsetsBottom = 0.0;
      }


      return;
    }


    const double kMinBottomDiff = 16.0;
    final bool heightChangedSignificantly =
        (viewInsetsBottom - _lastViewInsetsBottom).abs() > kMinBottomDiff;
    final bool shouldTriggerScroll =
        !_keyboardWasVisible || heightChangedSignificantly;

    if (!shouldTriggerScroll) {
      return;
    }

    _keyboardWasVisible = true;
    _lastViewInsetsBottom = viewInsetsBottom;

    final focusedContext = _lastFocusedFieldContext;
    if (focusedContext == null || !_formScrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        focusedContext,
        alignment: _lastFocusedFieldAlignment,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }



// ====== جلب بيانات المنتج من رابط شي إن (محسّنة) ======

  Future<void> _onSheinFetchRequested(BuildContext context) async {
    final url = adProductLinkController.text.trim();

    // تحقق أولي
    if (url.isEmpty) {
      HelperUtils.showSnackBarMessage(context, "أدخل رابط المنتج أولاً");
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.host.contains("shein.com") || uri.host.contains("sheinapp.com"))) {
      HelperUtils.showSnackBarMessage(context, "الرجاء إدخال رابط صالح من موقع شي إن");
      return;
    }

    if (_isFetchingShein) return; // منع الضغط المتكرر
    if (mounted) setState(() => _isFetchingShein = true);

    try {
      // افتح صفحة WebView لجلب البيانات من DOM
      final res = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => SheinGrabberPage(startUrl: url)),
      );

      if (res == null) {
        HelperUtils.showSnackBarMessage(context, "تم الإلغاء، لم يتم جلب بيانات");
        return;
      }

      // قراءة النتائج
      final String? title   = (res['title'] as String?)?.trim();
      final String? priceRaw = (res['price'] as String?)?.trim();
      final String? currency = (res['currency'] as String?)?.trim();
      final List<String> images = (res['images'] as List?)?.cast<String>() ?? const [];

      // تنظيف السعر (أرقام فقط)
      final String? price = priceRaw == null
          ? null
          : RegExp(r'[\d\.,]+').firstMatch(priceRaw)?.group(0)?.replaceAll(',', '');

      // تطبيق على الواجهة
      if (title != null && title.isNotEmpty) {
        adTitleController.text = title;
      }
      if (price != null && price.isNotEmpty) {
        adPriceController.text = price;
      }
      if (currency != null && currency.isNotEmpty) {
        _selectedCurrency = currency.toUpperCase(); // مثال: SAR / YER
      }

      if (images.isNotEmpty) {

        final materializedImages = await _materializeRemoteImages(images);
        if (materializedImages.isNotEmpty) {
          final firstImage = materializedImages.first;
          if (firstImage['isMain'] != true) {
            firstImage['isMain'] = true;
          }
        }


        mixedItemImageList
          ..clear()
          ..addAll(materializedImages);
      }

      if (mounted) setState(() {});
      HelperUtils.showSnackBarMessage(context, "تم الجلب من WebView ✅");
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, "تعذّر الجلب: $e");
    } finally {
      if (mounted) setState(() => _isFetchingShein = false);
    }
  }




  void handleFormSubmission(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      List<File> galleryImages = mixedItemImageList
          .whereType<File>()
          .toList();
      final List<File> resolvedGalleryFiles = [];
      File? flaggedMainFromList;

      for (final dynamic entry in mixedItemImageList) {
        File? file;
        if (entry is File) {
          file = entry;
        } else if (entry is Map) {
          final dynamic mapFile = entry['file'];
          if (mapFile is File) {
            file = mapFile;
            if (entry['isMain'] == true && flaggedMainFromList == null) {
              flaggedMainFromList = mapFile;
            }
          }
        }

        if (file != null) {
          resolvedGalleryFiles.add(file);
        }
      }
      File? mainImageFile = _pickTitleImage.pickedFile ?? flaggedMainFromList;

      if (mainImageFile == null && resolvedGalleryFiles.isNotEmpty) {
        mainImageFile = resolvedGalleryFiles.first;
      }

      if (mainImageFile == null && titleImageURL.isEmpty) {


        UiUtils.showBlurredDialoge(
          context,
          dialoge: BlurredDialogBox(
            title: "الصورة مطلوبة",
            content: Text("يرجى اختيار صورة واحدة على الأقل لإعلانك."),
          ),
        );
        return;
      }


      _updateSheinCategoryFlag(_currentCategoryIds(), notify: false);
      final bool isSheinCategory = _isSheinCategory;
      if (!isSheinCategory) {
        if (reviewLinkController.text.isNotEmpty) {
          reviewLinkController.clear();
        }
        if (adProductLinkController.text.isNotEmpty) {
          adProductLinkController.clear();
        }
      }


      Map<String, dynamic> itemDetailsData = {
        "name": adTitleController.text,
        "description": adDescriptionController.text,
        if (widget.isEdit != true) "category_id": selectedCategoryList.last,
        if (widget.isEdit == true) "id": item?.id,
        "price": adPriceController.text,
        "currency": _selectedCurrency,
        "contact": adPhoneNumberController.text,
        "video_link": adAdditionalDetailsController.text,
        if (widget.isEdit == true)
          "delete_item_image_id": deleteItemImageList.join(','),
        "all_category_ids": widget.isEdit == true
            ? (item!.allCategoryIds ??
            item!.categoryId?.toString() ??
            selectedCategoryList.join(','))
            : selectedCategoryList.join(',')
      };

      Map<String, dynamic>? moreDetailsData = getCloudData("more_details_data");
      if (moreDetailsData != null) {
        itemDetailsData.addAll(moreDetailsData);
      }

      if (isSheinCategory) {
        final reviewLink = reviewLinkController.text.trim();
        if (reviewLink.isNotEmpty) {
          itemDetailsData["review_link"] = reviewLink;
        }

        final productLink = adProductLinkController.text.trim();
        if (productLink.isNotEmpty) {
          itemDetailsData["product_link"] = productLink;
        }
      } else {
        itemDetailsData.remove("review_link");
        itemDetailsData.remove("product_link");
      }




      addCloudData("item_details", itemDetailsData);
      addCloudData("with_more_details", itemDetailsData);

      screenStack++;
      Navigator.pushNamed(context, Routes.confirmLocationScreen, arguments: {
        "isEdit": widget.isEdit,
        "mainImage": mainImageFile,
        "otherImage": galleryImages
      }).then((value) {
        screenStack--;
        if (value != null && value is Map) {
          setState(() {
            latitude = value['lat'];
            longitude = value['lng'];
            locationAddress = value['address'];
          });
        }
      });
    }
  }


  //Text Controllers
  final TextEditingController adTitleController = TextEditingController();
  final TextEditingController adDescriptionController = TextEditingController();
  final TextEditingController adPriceController = TextEditingController();
  final TextEditingController adPhoneNumberController = TextEditingController();
  final TextEditingController adAdditionalDetailsController =
  TextEditingController();

  void _onBreadCrumbItemTap(int index) {
    int popTimes = (widget.breadCrumbItems!.length - 1) - index;
    int current = index;
    int length = widget.breadCrumbItems!.length;

    for (int i = length - 1; i >= current + 1; i--) {
      widget.breadCrumbItems!.removeAt(i);
    }

    for (int i = 0; i < popTimes; i++) {
      Navigator.pop(context);
    }
    setState(() {});
  }

  List<int> selectedCategoryList = <int>[];
  ItemModel? item;
  bool _isSheinCategory = false;


  Iterable<int> _currentCategoryIds() {

    if (selectedCategoryList.isNotEmpty) {
      return selectedCategoryList;
    }

    if (widget.isEdit == true) {
      final String? ids = item?.allCategoryIds;
      if (ids != null && ids.isNotEmpty) {
        return ids
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>();
      }
      final int? fallback = item?.categoryId ?? item?.category?.id;
      if (fallback != null) {
        return [fallback];
      }
      return const Iterable<int>.empty();
    }
    return selectedCategoryList;
  }

  void _updateSheinCategoryFlag(Iterable<int> ids, {bool notify = true}) {
    final bool next = ids.any((id) => id == Constant.sheinRootCategoryId);
    if (_isSheinCategory != next && !next) {
      reviewLinkController.clear();
      adProductLinkController.clear();
    }

    if (notify) {
      if (_isSheinCategory != next) {
        if (mounted) {
          setState(() {
            _isSheinCategory = next;
          });
        } else {
          _isSheinCategory = next;
        }
      }
    } else {
      _isSheinCategory = next;
    }
  }


  @override
  void initState() {
    AbstractField.fieldsData.clear();
    AbstractField.files.clear();


    if (widget.isEdit == true) {
      item = getCloudData('edit_request') as ItemModel;

      clearCloudData("item_details");
      clearCloudData("with_more_details");

      // تحميل الحقول في الخلفية بدون انتظار
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // التحقق من وجود allCategoryIds قبل استخدامها
        String categoryIds;
        if (item!.allCategoryIds != null && item!.allCategoryIds!.isNotEmpty) {
          categoryIds = item!.allCategoryIds!;
        } else {
          // استخدام categoryId كبديل
          categoryIds = item!.categoryId?.toString() ??
              item!.category?.id?.toString() ??
              "1";
        }
        context.read<FetchCustomFieldsCubit>().fetchCustomFields(
          categoryIds: categoryIds,
        );
      });

      adTitleController.text = item?.name ?? "";
      adDescriptionController.text = item?.description ?? "";
      adPriceController.text = item?.price.toString() ?? "";
      adPhoneNumberController.text = item?.contact ?? "";
      adAdditionalDetailsController.text = item?.videoLink ?? "";

      titleImageURL = HelperUtils.absoluteImage(item?.image);
      _selectedCurrency = item?.currency ?? 'YER';
      final initialCategoryIds = _currentCategoryIds().toList();
      selectedCategoryList = initialCategoryIds;
      _updateSheinCategoryFlag(initialCategoryIds, notify: false);

      if (_isSheinCategory) {
        reviewLinkController.text = item?.reviewLink ?? "";
        adProductLinkController.text = item?.productLink ?? "";

      } else {
        reviewLinkController.clear();
        adProductLinkController.clear();

      }



      mixedItemImageList
        ..clear();

      final String mainImageUrl = titleImageURL;
      if (mainImageUrl.isNotEmpty) {
        mixedItemImageList.add({
          'id': null,
          'url': mainImageUrl,
          'isMain': true,
        });
      }

      final galleryImages = item?.galleryImages ?? [];
      mixedItemImageList.addAll(
        galleryImages
            .where((e) => (e.image ?? '').isNotEmpty)
            .map(
              (e) => {
            'id': e.id,
            'url': HelperUtils.absoluteImage(e.image),
          },
        ),
      );

      setState(() {});
    } else {
      List<int> ids = widget.breadCrumbItems!.map((item) => item.id!).toList();

      // تحميل الحقول في الخلفية بدون انتظار
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context
            .read<FetchCustomFieldsCubit>()
            .fetchCustomFields(categoryIds: ids.join(','));
      });

      selectedCategoryList = ids;

      _updateSheinCategoryFlag(ids, notify: false);


      adPhoneNumberController.text = HiveUtils
          .getUserDetails()
          .mobile ?? "";
      adTitleController.addListener(() {
        // Check if the default language is English
        // String languageCode = HiveUtils.getLanguage()['code'].toString();
        // if (languageCode.toLowerCase() == "en") {
        //   updateSlug();
        // }
      });
    }

    _pickTitleImage.listener((p0) {
      titleImageURL = "";

      if (_isTitleImageUpdateScheduled) {
        return;
      }

      _isTitleImageUpdateScheduled = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _isTitleImageUpdateScheduled = false;
          return;
        }

        setState(() {
          _isTitleImageUpdateScheduled = false;
        });
      });
    });

    itemImagePicker.listener((images) {
      try {
        mixedItemImageList.addAll(List<dynamic>.from(images));
      } catch (e) {}

      setState(() {});
    });

    super.initState();
  }

  String generateSlug(String title) {
    // تم إلغاء استخدام السلاج نهائياً
    return "";
  }

  @override
  Widget build(BuildContext context) => buildUI(context);




  @override
  void dispose() {
    _imageSectionPageController.dispose();
    _formScrollController.dispose();

    _linkDebounce?.cancel();
    productLinkController.dispose();
    reviewLinkController.dispose();
    adProductLinkController.dispose();
    adTitleController.dispose();
    adDescriptionController.dispose();
    adPriceController.dispose();
    adPhoneNumberController.dispose();
    adAdditionalDetailsController.dispose();
    super.dispose();
  }




}








