import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/image_section.dart';
import 'package:marib/ui/screens/item/add_item_screen/select_category.dart';
import 'package:marib/ui/screens/item/add_item_screen/shein_grabber_page.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/custom_drop_down.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart'
    show AbstractField;

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/imagePicker.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'dart:async';


import 'package:marib/data/cubits/item/manage_item_cubit.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/ui/screens/user_profile/my_item_tab.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/geo_rules.dart';

import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/ecommerce_department.dart';



class AddItemDetails extends StatefulWidget {
  final List<CategoryModel>? breadCrumbItems;
  final bool? isEdit;

  const AddItemDetails({
    super.key,
    this.breadCrumbItems,
    required this.isEdit,
  });

  static Route route(RouteSettings settings) {
    final Map<String, dynamic>? arguments =
    settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) {
        return BlocProvider(
          create: (_) => ManageItemCubit(),
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ScrollController _formScrollController = ScrollController();
  final PageController _imageSectionPageController = PageController();


  final PickImage _coverImagePicker = PickImage();
  final PickImage _galleryPicker = PickImage();

  final TextEditingController adTitleController = TextEditingController();
  final TextEditingController adDescriptionController = TextEditingController();
  final TextEditingController adPriceController = TextEditingController();
  final TextEditingController adPhoneNumberController = TextEditingController();
  final TextEditingController adAdditionalDetailsController =
  TextEditingController();
  final TextEditingController reviewLinkController = TextEditingController();
  final TextEditingController adProductLinkController = TextEditingController();

  late final List<CategoryModel> _breadcrumbItems;
  late final bool _enableTitleAutofocus;


  String _selectedCurrency = 'YER';
  String _selectedCountryCode = '+967';
  String coverImageUrl = '';

  bool isUploadingGallery = false;
  bool _isFetchingShein = false;
  bool _isKeyboardVisible = false;
  bool _isSheinCategory = false;
  bool _isCoverUpdateScheduled = false;
  double _lastViewInsetsBottom = 0;

  final List<dynamic> galleryItems = <dynamic>[];
  final List<int> deletedImageIds = <int>[];
  final List<int> selectedCategoryIds = <int>[];

  ItemModel? item;
  final List<CustomFieldModel> _legacyCustomFields = <CustomFieldModel>[];

  bool _isSubmittingWithoutLocation = false;

  double? latitude;
  double? longitude;
  String? locationAddress;

  BuildContext? _lastFocusedContext;
  double _lastFocusedAlignment = 0.2;

  @override
  PageController get imageSectionPageController => _imageSectionPageController;

  @override
  void initState() {
    _breadcrumbItems = List<CategoryModel>.from(
      widget.breadCrumbItems ?? const <CategoryModel>[],
    );
    _enableTitleAutofocus = widget.isEdit != true;
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AbstractField.fieldsData.clear();
    AbstractField.files.clear();
    _resetLegacyCustomFieldState();

    _coverImagePicker.listener((data) {
      coverImageUrl = '';
      if (_isCoverUpdateScheduled) {
        return;
      }

      _isCoverUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _isCoverUpdateScheduled = false;
          return;
        }
        setState(() {
          _isCoverUpdateScheduled = false;
        });
      });
    });

    _galleryPicker.listener((images) {
      try {
        galleryItems.addAll(List<dynamic>.from(images));
      } catch (_) {}
      setState(() {});
    });

    if (widget.isEdit == true) {
      _initFromEditRequest();
    } else {
      _initForCreate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _formScrollController.dispose();
    _imageSectionPageController.dispose();

    _coverImagePicker.dispose();
    _galleryPicker.dispose();

    adTitleController.dispose();
    adDescriptionController.dispose();
    adPriceController.dispose();
    adPhoneNumberController.dispose();
    adAdditionalDetailsController.dispose();
    reviewLinkController.dispose();
    adProductLinkController.dispose();

    super.dispose();
  }

  void _initFromEditRequest() {
    item = getCloudData('edit_request') as ItemModel?;
    clearCloudData('item_details');
    clearCloudData('with_more_details');

    if (item == null) {
      return;
    }

    adTitleController.text = item?.name ?? '';
    adDescriptionController.text = item?.description ?? '';
    final String? initialPrice = _initialPriceText(item);
    if (initialPrice != null) {
      adPriceController.text = initialPrice;
    }
    adPhoneNumberController.text = item?.contact ?? '';
    adAdditionalDetailsController.text = item?.videoLink ?? '';
    reviewLinkController.text = item?.reviewLink ?? '';
    adProductLinkController.text = item?.productLink ?? '';

    coverImageUrl = HelperUtils.absoluteImage(item?.image);
    _selectedCurrency = item?.currency ?? 'YER';

    final Iterable<int> ids = _initialCategoryIdsFromItem(item);
    selectedCategoryIds
      ..clear()
      ..addAll(ids);
    _updateSheinCategoryFlag(ids, notify: false);

    galleryItems
      ..clear()
      ..addAll(_buildInitialGalleryItems(item));
  }


  String? _initialPriceText(ItemModel? item) {
    if (item == null) {
      return null;
    }

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


  void _initForCreate() {
    if (_breadcrumbItems.isEmpty) {

      return;
    }

    final ids = _breadcrumbItems.map((e) => e.id!).toList(growable: false);

    selectedCategoryIds
      ..clear()
      ..addAll(ids);


    _updateSheinCategoryFlag(ids, notify: false);
    adPhoneNumberController.text =
        HiveUtils.getUserDetails().mobile ?? adPhoneNumberController.text;
  }



  void _resetLegacyCustomFieldState() {
    if (_legacyCustomFields.isNotEmpty) {
      _legacyCustomFields.clear();
    }
  }

  Map<String, dynamic> _sanitizeMoreDetailsPayload(
      Map<String, dynamic>? rawData) {
    if (rawData == null || rawData.isEmpty) {
      return <String, dynamic>{};
    }

    final Map<String, dynamic> sanitized = <String, dynamic>{};
    rawData.forEach((key, value) {
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


  Iterable<Map<String, dynamic>> _buildInitialGalleryItems(ItemModel? item) {
    if (item == null) {
      return const Iterable.empty();
    }

    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    final String imageUrl = HelperUtils.absoluteImage(item.image);
    if (imageUrl.isNotEmpty) {
      result.add({
        'id': null,
        'url': imageUrl,
        'isMain': true,
      });
    }


    final gallery = item.galleryImages ?? const [];
    for (final image in gallery) {
      final url = HelperUtils.absoluteImage(image.image);
      if (url.isEmpty) continue;
      result.add({
        'id': image.id,
        'url': url,
      });
    }
    return result;
  }

  Iterable<int> _initialCategoryIdsFromItem(ItemModel? item) {
    if (item == null) {
      return const Iterable<int>.empty();
    }

    if ((item.allCategoryIds ?? '').isNotEmpty) {
      return item.allCategoryIds!
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>();
    }

    final fallback = item.categoryId ?? item.category?.id;
    if (fallback != null) {
      return [fallback];
    }
    return const Iterable<int>.empty();
  }




  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final viewInsetsBottom = dispatcher.views.isNotEmpty
        ? dispatcher.views.first.viewInsets.bottom
        : dispatcher.implicitView?.viewInsets.bottom ?? 0.0;

    final bool isVisible = viewInsetsBottom > 0;
    if (!isVisible) {
      _isKeyboardVisible = false;
      _lastViewInsetsBottom = 0;
      return;
    }


    const double threshold = 16.0;
    final bool changedSignificantly =
        (viewInsetsBottom - _lastViewInsetsBottom).abs() > threshold;
    final bool shouldScroll = !_isKeyboardVisible || changedSignificantly;

    _isKeyboardVisible = true;
    _lastViewInsetsBottom = viewInsetsBottom;

    if (!shouldScroll) {
      return;
    }

    if (_lastFocusedContext == null || !_formScrollController.hasClients) {

      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        _lastFocusedContext!,
        alignment: _lastFocusedAlignment,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }



  void _updateSheinCategoryFlag(Iterable<int> ids, {bool notify = true}) {
    final bool next = ids.any((id) => id == Constant.sheinRootCategoryId);
    if (_isSheinCategory != next && !next) {
      reviewLinkController.clear();
      adProductLinkController.clear();
      return;
    }
    if (!notify) {
      _isSheinCategory = next;
      return;
    }

    if (_isSheinCategory != next) {
      if (mounted) {
        setState(() => _isSheinCategory = next);
      } else {
        _isSheinCategory = next;
      }
    }
  }
  Widget _buildKeyboardAwareField({
    required Widget child,
    double alignment = 0.2,
  }) {
    return Builder(
      builder: (context) {
        return Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              _lastFocusedContext = context;
              _lastFocusedAlignment = alignment;
              if (_formScrollController.hasClients) {
                Scrollable.ensureVisible(
                  context,
                  alignment: alignment,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                );
              }
            } else if (_lastFocusedContext == context) {
              _lastFocusedContext = null;
            }
          },
          child: child,
        );
      },
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_rounded, color: color.territoryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تفاصيل إعلانك',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'املأ الحقول التالية بعناية للحصول على إعلان جذاب وسهل القراءة.'
                '\nيمكنك إضافة صورة رئيسية، ومعرض صور، ومعلومات التواصل، وروابط إضافية.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }


  Widget _buildBreadcrumbs(BuildContext context) {
    if (_breadcrumbItems.isEmpty) {

      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color inactiveBorder =
    isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08);
    final Color activeBorder = colors.territoryColor.withOpacity(0.55);
    final Color activeBackground = colors.territoryColor.withOpacity(0.12);
    final TextStyle labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ) ??
        const TextStyle(fontWeight: FontWeight.w600);
    final Color baseLabelColor = labelStyle.color ?? colors.onSurface;

    final int total = _breadcrumbItems.length + 1;
    final int activeIndex = _breadcrumbItems.length;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,

        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool isHome = index == 0;
          final bool isActive = index == activeIndex;
          final String label = isHome
              ? 'Home'.translate(context)
              : (_breadcrumbItems[index - 1].name ?? '');
          final IconData icon = isHome
              ? Icons.home_outlined
              : (isActive ? Icons.label_important : Icons.chevron_right);

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isActive
                ? null
                : () {
              if (isHome) {
                _onBreadCrumbTap(0);
              } else {
                _onBreadCrumbTap(index - 1);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? activeBackground : colors.secondaryColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? activeBorder : inactiveBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isActive ? colors.territoryColor : baseLabelColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: labelStyle.copyWith(
                      color:
                      isActive ? colors.territoryColor : baseLabelColor,
                    ),
                  ),
                ],
              ),
            ),

          );
        },
      ),
    );
  }

  void _onBreadCrumbTap(int index) {
    if (_breadcrumbItems.isEmpty) {

      return;
    }

    final int safeIndex = index.clamp(0, _breadcrumbItems.length - 1);
    final int popTimes = (_breadcrumbItems.length - 1) - safeIndex;
    final int totalPops = popTimes <= 0 ? 1 : popTimes;
    for (int i = 0; i < totalPops; i++) {
      if (!Navigator.of(context).canPop()) {
        break;
      }
      Navigator.of(context).pop();
    }


  }

  Widget _buildCoverImageCard(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final File? pickedFile = _coverImagePicker.pickedFile;
    final ImageProvider? previewProvider;
    if (pickedFile != null) {
      previewProvider = FileImage(pickedFile);
    } else if (coverImageUrl.isNotEmpty) {
      previewProvider = NetworkImage(coverImageUrl);
    } else {
      previewProvider = null;
    }




    return DottedBorder(
      dashPattern: const [5, 3],
      color: color.borderColor,
      borderType: BorderType.RRect,
      radius: const Radius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await _coverImagePicker.pick(
            context: context,
            pickMultiple: false,
            source: ImageSource.gallery,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: color.secondaryColor,
                  image: previewProvider != null
                      ? DecorationImage(
                    image: previewProvider,
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: previewProvider == null
                    ? Icon(
                  Icons.add_a_photo_rounded,
                  color: color.territoryColor,
                )
                    : Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: CircleAvatar(
                      backgroundColor: color.secondaryColor,
                      radius: 12,
                      child: const Icon(
                        Icons.edit,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الصورة الرئيسية',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      previewProvider != null
                          ? 'اضغط لتغيير الصورة الرئيسية.'
                          : 'اختر صورة جذابة لتكون الصورة الرئيسية لإعلانك.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGallerySection(BuildContext context) {
    return itemImagesListener(
        context: context,
        mixedItemImageList: galleryItems,
        isUploadingExtra: isUploadingGallery,
        itemImagePicker: _galleryPicker,
        onPick: (source) async {
          setState(() => isUploadingGallery = true);
          await _galleryPicker.pick(
            context: context,
            pickMultiple: true,
            source: source,
            imageLimit: 25,
            maxLength: galleryItems.length,
          );
          Future.microtask(() {
            if (mounted) {
              setState(() => isUploadingGallery = false);
            }
          });
        },
        onRemove: (index) {
          setState(() {
            final dynamic removed = galleryItems[index];
            if (removed is Map) {
              final dynamic rawId = removed['id'];
              final int? imageId = rawId is int
                  ? rawId
                  : (rawId is String ? int.tryParse(rawId) : null);
              if (imageId != null && !deletedImageIds.contains(imageId)) {
                deletedImageIds.add(imageId);
            }
              if (removed['isMain'] == true || removed['url'] == coverImageUrl) {
                coverImageUrl = '';
              }
            } else if (removed is File && _coverImagePicker.pickedFile == removed) {
              _coverImagePicker.pickedFile = null;
          }
            galleryItems.removeAt(index);
          });
        },
    );
  }

  Widget _buildTextFieldSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('معلومات الإعلان', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildKeyboardAwareField(
          child: CustomTextFormField(
            controller: adTitleController,
            hintText: 'عنوان الإعلان',
            validator: CustomTextFieldValidator.nullCheck,
            action: TextInputAction.next,
            capitalization: TextCapitalization.sentences,
            maxLength: 120,
            autofocus: _enableTitleAutofocus,
          ),
        ),
        const SizedBox(height: 12),
        _buildKeyboardAwareField(
          child: CustomTextFormField(
            controller: adDescriptionController,
            hintText: 'وصف تفصيلي',
            minLine: 4,
            maxLine: 6,
            validator: CustomTextFieldValidator.nullCheck,
            capitalization: TextCapitalization.sentences,
          ),
        ),
      ],
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    final theme = Theme.of(context);
    final color = Theme.of(context).colorScheme;
    const currencies = <String, String>{
      'YER': 'ريال يمني',
      'SAR': 'ريال سعودي',
      'USD': 'دولار أمريكي',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('التسعير', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildKeyboardAwareField(
                child: CustomTextFormField(
                  controller: adPriceController,
                  hintText: 'السعر',
                  keyboard: TextInputType.number,
                  action: TextInputAction.next,
                  validator: CustomTextFieldValidator.nullCheck,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: CustomDropdownFormField<String>(
                items: currencies.keys.toList(growable: false),
                value: currencies.keys.contains(_selectedCurrency)
                    ? _selectedCurrency
                    : 'YER',
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedCurrency = value);
                },
                hintText: 'العملة',
                dense: true,
                fillColor: color.secondaryColor,
                borderColor: color.borderColor,
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildContactSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text('معلومات التواصل', style: theme.textTheme.titleMedium),
    const SizedBox(height: 12),
    Row(
      children: [
        Flexible(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: _selectedCountryCode,
            decoration: InputDecoration(
              labelText: 'المقدمة',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            isExpanded: true,
            items: arabCountries
                .map(
                  (country) => DropdownMenuItem<String>(
                value: country['code'],
                child: Text(
                  '${country['code']} (${country['name']})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              FocusScope.of(context).unfocus();
              setState(() => _selectedCountryCode = value);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: _buildKeyboardAwareField(
            child: CustomTextFormField(
              controller: adPhoneNumberController,
              hintText: 'رقم الهاتف',
              keyboard: TextInputType.phone,
              validator: CustomTextFieldValidator.phoneNumber,
              isMobileRequired: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              action: TextInputAction.next,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    _buildKeyboardAwareField(
    child: CustomTextFormField(
    controller: adAdditionalDetailsController,
    hintText: 'رابط فيديو أو تفاصيل إضافية (اختياري)',
    keyboard: TextInputType.url,
    action: TextInputAction.next,
    validator: CustomTextFieldValidator.url,
    isRequired: false,
    minLine: 1,
    maxLine: 2,
          ),
    ),
        ],
    );
  }



  Widget _buildSheinSection(BuildContext context) {
    if (!_isSheinCategory) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final brandColor = color.territoryColor;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag_rounded, color: brandColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'روابط شي إن',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _isFetchingShein
                    ? null
                    : () => _onSheinFetchRequested(context),
                style: FilledButton.styleFrom(
                  backgroundColor: brandColor,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: _isFetchingShein
                    ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(color.onPrimary),
                  ),
                )
                    : const Icon(Icons.downloading_rounded),
                label: Text(
                  'جلب التفاصيل',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildKeyboardAwareField(
            child: CustomTextFormField(
              controller: adProductLinkController,
              hintText: 'رابط المنتج في شي إن',
              keyboard: TextInputType.url,
              action: TextInputAction.next,
              validator: CustomTextFieldValidator.url,
              isRequired: false,
            ),
          ),
          const SizedBox(height: 12),
          _buildKeyboardAwareField(
            child: CustomTextFormField(
              controller: reviewLinkController,
              hintText: 'رابط مراجعة موثوقة (اختياري)',
              keyboard: TextInputType.url,
              action: TextInputAction.next,
              validator: CustomTextFieldValidator.url,
              isRequired: false,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPurchaseOptionsShortcut(BuildContext context) {
    final ItemModel? currentItem = item;
    if (currentItem == null || currentItem.id == null) {
      return const SizedBox.shrink();
    }
    if (!_supportsProductOptionsForItem(currentItem)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.secondaryColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.borderColor.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.territoryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: color.territoryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'إدارة خيارات المنتج',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'يمكنك ضبط المخزون أو إنشاء خصومات مخصصة لهذا الإعلان من خلال صفحة إدارة خيارات المنتج.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color.textDefaultColor.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 16),
            UiUtils.buildButton(
              context,
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  Routes.productManagementScreen,
                  arguments: {'model': currentItem},
                );
              },
              buttonTitle: 'فتح إدارة خيارات المنتج',
              height: 48.rh(context),
              fontSize: context.font.large,
            ),
          ],
        ),
      ),
    );
  }


  String? _normalizeString(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final trimmed = value.toString().trim();
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


  Widget _buildLocationPreview(BuildContext context) {
    if (latitude == null || longitude == null || locationAddress == null) {
      return const SizedBox.shrink();
    }




    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_pin, color: color.territoryColor),
              const SizedBox(width: 8),
              Text(
                'الموقع المحدد',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            locationAddress ?? '',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _handleSubmit(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    _resetLegacyCustomFieldState();


    final List<File> galleryFiles = <File>[];
    File? mainImageFile = _coverImagePicker.pickedFile;
    File? flaggedMainFile;

    for (final entry in galleryItems) {
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
      mainImageFile = flaggedMainFile ?? (galleryFiles.isNotEmpty ? galleryFiles.first : null);
    }

    if (mainImageFile == null && coverImageUrl.isEmpty) {
      UiUtils.showBlurredDialoge(
        context,
        dialoge: const BlurredDialogBox(
          title: 'الصورة مطلوبة',
          content: Text('يرجى اختيار صورة واحدة على الأقل لإعلانك.'),
        ),
      );
      return;
    }

    final List<int> categoryIds = _currentCategoryIds().toList(growable: false);
    _updateSheinCategoryFlag(categoryIds, notify: false);
    final bool isShein = _isSheinCategory;
    final bool disableLocation = GeoRules.isDisabled(categoryIds: categoryIds);

    final Map<String, dynamic> data = <String, dynamic>{
      'name': adTitleController.text.trim(),
      'description': adDescriptionController.text.trim(),
      'price': adPriceController.text.trim(),
      'currency': _selectedCurrency,
      'contact': adPhoneNumberController.text.trim(),
      'contact_country_code': _selectedCountryCode,
      'video_link': adAdditionalDetailsController.text.trim(),
      if (widget.isEdit != true) 'category_id': categoryIds.isNotEmpty
          ? categoryIds.last
          : selectedCategoryIds.isNotEmpty
          ? selectedCategoryIds.last
          : null,
      if (widget.isEdit == true) 'id': item?.id,
      if (widget.isEdit == true && deletedImageIds.isNotEmpty)
        'delete_item_image_id': deletedImageIds.join(','),
      'all_category_ids': widget.isEdit == true
          ? (item?.allCategoryIds?.isNotEmpty == true
          ? item!.allCategoryIds!
          : item?.categoryId?.toString() ??
          item?.category?.id?.toString() ??
          selectedCategoryIds.join(','))
          : selectedCategoryIds.join(','),
    }..removeWhere((key, value) => value == null || (value is String && value.isEmpty));

    final Map<String, dynamic>? rawMoreDetails =
    getCloudData('more_details_data') as Map<String, dynamic>?;
    final Map<String, dynamic> sanitizedMoreDetails =
    _sanitizeMoreDetailsPayload(rawMoreDetails);

    if (sanitizedMoreDetails.isNotEmpty) {
      addCloudData('more_details_data', sanitizedMoreDetails);
      data.addAll(sanitizedMoreDetails);
    } else if (rawMoreDetails != null && rawMoreDetails.isNotEmpty) {
      clearCloudData('more_details_data');

    }
    if (isShein) {
      final reviewLink = reviewLinkController.text.trim();
      if (reviewLink.isNotEmpty) {
        data['review_link'] = reviewLink;
      }
      final productLink = adProductLinkController.text.trim();
      if (productLink.isNotEmpty) {
        data['product_link'] = productLink;
      }
    } else {
      data.remove('review_link');
      data.remove('product_link');
    }

    addCloudData('item_details', data);
    addCloudData('with_more_details', data);


    if (disableLocation) {
      _submitWithoutLocation(
        context,
        mainImageFile,
        galleryFiles,
      );
      return;
    }

    screenStack++;
    Navigator.pushNamed(
      context,
      Routes.confirmLocationScreen,
      arguments: {
        'isEdit': widget.isEdit,
        'mainImage': mainImageFile,
        'otherImage': galleryFiles,
      },
    ).then((value) {
      screenStack--;
      if (value is Map) {
        setState(() {
          latitude = value['lat'] as double?;
          longitude = value['lng'] as double?;
          locationAddress = value['address'] as String?;
        });
      }
    });
  }



  void _submitWithoutLocation(
      BuildContext context,
      File? mainImageFile,
      List<File> galleryFiles,
      ) {
    final Map<String, dynamic> stored =
        (getCloudData('with_more_details') as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final Map<String, dynamic> payload = Map<String, dynamic>.from(stored);

    payload.removeWhere((key, value) =>
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

    _isSubmittingWithoutLocation = true;

    final ManageItemCubit manage = context.read<ManageItemCubit>();

    if (widget.isEdit == true) {
      manage.manage(ManageItemType.edit, payload, mainImageFile, galleryFiles);
    } else {
      if (mainImageFile == null) {
        _isSubmittingWithoutLocation = false;
        HelperUtils.showSnackBarMessage(context, 'الصورة مطلوبة');
        return;
      }
      manage.manage(ManageItemType.add, payload, mainImageFile, galleryFiles);
    }
  }

  void _handleManageItemState(
      BuildContext context, ManageItemState state) {
    if (!_isSubmittingWithoutLocation) {
      return;
    }

    if (state is ManageItemInProgress) {
      Widgets.showLoader(context);
      return;
    }

    if (state is ManageItemSuccess) {
      Widgets.hideLoder(context);
      _isSubmittingWithoutLocation = false;
      if (mounted) {
        setState(() {
          item = state.model;
        });
      } else {
        item = state.model;
      }
      final dynamic editKey = getCloudData('edit_from');
      if (editKey is String && editKey.isNotEmpty) {
        myAdsCubitReference[editKey]?.edit(state.model);
      }
      Future.microtask(() {
        if (!mounted) {
          return;
        }
        final bool openProductManagement =
            state.type == ManageItemType.add &&
                _supportsProductOptionsForItem(state.model);

        if (openProductManagement) {

          Navigator.pushNamed(
            context,
            Routes.productManagementScreen,
            arguments: {'model': state.model},
          );
        } else {
          Navigator.pushNamed(
            context,
            Routes.successItemScreen,
            arguments: {'model': state.model, 'isEdit': widget.isEdit},
          );
        }
      });
      return;
    }

    if (state is ManageItemFail) {
      Widgets.hideLoder(context);
      _isSubmittingWithoutLocation = false;
      final dynamic filteredError = ErrorFilter.check(state.error).error;
      final String message = filteredError is String
          ? filteredError
          : filteredError.toString();
      HelperUtils.showSnackBarMessage(context, message);
    }
  }

  Iterable<int> _currentCategoryIds() {

    if (selectedCategoryIds.isNotEmpty) {
      return selectedCategoryIds;
    }

    if (widget.isEdit == true) {
      final ids = item?.allCategoryIds;
      if (ids?.isNotEmpty ?? false) {
        return ids!
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>();
      }
      final fallback = item?.categoryId ?? item?.category?.id;

      if (fallback != null) {
        return [fallback];
      }

    }
    return const Iterable<int>.empty();

  }

  bool _supportsProductOptionsForItem(ItemModel model) {

    if (GeoRules.isMapEnabledForItem(model)) {
      return false;
    }

    final Iterable<int> categoryIds = _currentCategoryIds();
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

  Future<void> _onSheinFetchRequested(BuildContext context) async {
    final url = adProductLinkController.text.trim();
    if (url.isEmpty) {
      HelperUtils.showSnackBarMessage(context, 'أدخل رابط المنتج أولاً');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.host.contains('shein.com') || uri.host.contains('sheinapp.com'))) {
      HelperUtils.showSnackBarMessage(context, 'يرجى إدخال رابط صالح من شي إن');
      return;
    }
    if (_isFetchingShein) {
      return;
    }
    setState(() => _isFetchingShein = true);


    try {
      final Map<String, dynamic>? data = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SheinGrabberPage(startUrl: url),
        ),
      );

      if (data == null) {
        HelperUtils.showSnackBarMessage(context, 'تم الإلغاء، لم يتم جلب بيانات');
        return;
      }


      final String? title = (data['title'] as String?)?.trim();
      final String? priceRaw = (data['price'] as String?)?.trim();
      final String? currency = (data['currency'] as String?)?.trim();
      final List<String> images =
          (data['images'] as List<dynamic>?)?.cast<String>() ?? const <String>[];

      if (title != null && title.isNotEmpty) {
        adTitleController.text = title;
      }

      if (priceRaw != null && priceRaw.isNotEmpty) {
        final String? normalized =
        RegExp(r'[\d\.,]+').firstMatch(priceRaw)?.group(0)?.replaceAll(',', '');
        if (normalized != null) {
          adPriceController.text = normalized;
        }


      }
      if (currency != null && currency.isNotEmpty) {
        setState(() => _selectedCurrency = currency.toUpperCase());
      }


      if (images.isNotEmpty) {
        final materialized = await _materializeRemoteImages(images);
        if (materialized.isNotEmpty) {
          final first = materialized.first;
          first['isMain'] = true;
          galleryItems
            ..clear()
            ..addAll(materialized);
        }
      }

      if (mounted) {
        setState(() {});
      }
      HelperUtils.showSnackBarMessage(context, 'تم جلب البيانات بنجاح');
    } catch (error) {
      HelperUtils.showSnackBarMessage(
        context,
        'تعذر الجلب: ${error.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingShein = false);
      }
    }
  }
  Future<List<Map<String, dynamic>>> _materializeRemoteImages(
      List<String> urls) async {
    if (urls.isEmpty) {
      return const [];
    }

    final tempDir = await getTemporaryDirectory();
    final List<Map<String, dynamic>> resolved = [];

    for (final url in urls) {
      if (url.isEmpty) continue;
      try {
        final uri = Uri.tryParse(url);
        if (uri == null) continue;
        final response = await http.get(uri);
        if (response.statusCode != 200) continue;

        final allowed = {'jpg', 'jpeg', 'png'};
        final contentType = response.headers['content-type'] ?? '';
        String? headerExtension;
        if (contentType.contains('/')) {
          final parts = contentType.split('/');
          if (parts.length == 2) {
            headerExtension = parts.last.split(';').first.trim().toLowerCase();
          }
        }

        String? extensionFromUrl;
        if (uri.pathSegments.isNotEmpty) {
          final segment = uri.pathSegments.last;
          final dotIndex = segment.lastIndexOf('.');
          if (dotIndex != -1 && dotIndex < segment.length - 1) {
            final candidate = segment.substring(dotIndex + 1).toLowerCase();
            if (candidate.length <= 5) {
              extensionFromUrl = candidate;
            }
          }
        }

        String resolvedExtension =
        (extensionFromUrl ?? headerExtension ?? 'jpg').toLowerCase();

        bool requiresTranscode = !allowed.contains(resolvedExtension) ||
            (headerExtension != null && !allowed.contains(headerExtension));

        List<int> bytes = response.bodyBytes;
        if (requiresTranscode) {
          final decoded = img.decodeImage(Uint8List.fromList(bytes));
          if (decoded == null) {
            continue;
          }
          bytes = img.encodeJpg(decoded);
          resolvedExtension = 'jpg';
        }

        final fileName =
            'remote_${DateTime.now().microsecondsSinceEpoch}_${resolved.length}.$resolvedExtension';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        resolved.add({'file': file, 'url': url});
      } catch (_) {
        continue;
      }
    }

    return resolved;
  }




  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final footerHeight = 64 + mediaQuery.padding.bottom;

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: SafeArea(
        child: Scaffold(
          appBar: UiUtils.buildAppBar(
            context,
            title: 'تفاصيل الإعلان',
            showBackButton: true,
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: UiUtils.buildButton(
              context,
              onPressed: () => _handleSubmit(context),
              height: 48.rh(context),
              fontSize: context.font.large,
              buttonTitle: 'متابعة',
            ),
          ),
          body: MultiBlocListener(
            listeners: [

              BlocListener<ManageItemCubit, ManageItemState>(
                listener: _handleManageItemState,
              ),
            ],
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: _formScrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  24 + (bottomInset > 0 ? bottomInset : footerHeight),
                ),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntroCard(context),
                    const SizedBox(height: 16),
                    _buildBreadcrumbs(context),
                    if (widget.breadCrumbItems?.isNotEmpty ?? false)
                      const SizedBox(height: 16),
                    _buildCoverImageCard(context),
                    const SizedBox(height: 20),
                    _buildGallerySection(context),
                    const SizedBox(height: 20),
                    _buildTextFieldSection(context),
                    const SizedBox(height: 20),
                    _buildPricingSection(context),
                    const SizedBox(height: 20),
                    _buildContactSection(context),
                    _buildSheinSection(context),
                    if (widget.isEdit == true && (item?.id ?? 0) > 0)
                      _buildPurchaseOptionsShortcut(context),
                    _buildLocationPreview(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  final List<Map<String, String>> arabCountries = const [
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


}








