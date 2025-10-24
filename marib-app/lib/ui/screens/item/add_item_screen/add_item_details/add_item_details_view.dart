import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_keyboard_manager.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_submission_service.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_shein_service.dart';
import 'package:marib/ui/screens/widgets/custom_drop_down.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';

typedef GallerySectionBuilder = Widget Function({
required BuildContext context,
required List<dynamic> mixedItemImageList,
required bool isUploadingExtra,
required dynamic itemImagePicker,
required void Function(ImageSource source) onPick,
required void Function(int index) onRemove,
});

class AddItemDetailsView extends StatelessWidget {
  const AddItemDetailsView({
    super.key,
    required this.model,
    required this.keyboardManager,
    required this.submissionService,
    required this.sheinService,
    required this.galleryBuilder,
    required this.onSubmit,
    required this.onPickCoverImage,
    required this.onPickGalleryImage,
    required this.onRemoveGalleryImage,
    required this.onBreadcrumbTap,
    required this.onRefresh,
  });

  final AddItemDetailsModel model;
  final AddItemDetailsKeyboardManager keyboardManager;
  final AddItemDetailsSubmissionService submissionService;
  final AddItemDetailsSheinService sheinService;
  final GallerySectionBuilder galleryBuilder;

  final VoidCallback onSubmit;
  final VoidCallback onRefresh;
  final Future<void> Function() onPickCoverImage;
  final Future<void> Function(ImageSource source) onPickGalleryImage;
  final void Function(int index) onRemoveGalleryImage;
  final void Function(int index) onBreadcrumbTap;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double bottomInset = mediaQuery.viewInsets.bottom;
    final double footerHeight = 64 + mediaQuery.padding.bottom;

    return SafeArea(
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
            onPressed: onSubmit,
            height: 48.rh(context),
            fontSize: context.font.large,
            buttonTitle: 'متابعة',
          ),
        ),
        body: Form(
          key: model.formKey,
          child: SingleChildScrollView(
            controller: model.formScrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              24 + (bottomInset > 0 ? bottomInset : footerHeight),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildIntroCard(context),
                const SizedBox(height: 16),
                _buildBreadcrumbs(context),
                if (model.breadcrumbItems.isNotEmpty)
                  const SizedBox(height: 16),
                _buildCoverImageCard(context),
                const SizedBox(height: 20),
                galleryBuilder(
                  context: context,
                  mixedItemImageList: model.galleryItems,
                  isUploadingExtra: model.isUploadingGallery,
                  itemImagePicker: model.galleryPicker,
                  onPick: (ImageSource source) => onPickGalleryImage(source),
                  onRemove: onRemoveGalleryImage,
                ),
                const SizedBox(height: 20),
                _buildTextFieldSection(context),
                const SizedBox(height: 20),
                _buildPricingSection(context),
                const SizedBox(height: 20),
                _buildContactSection(context),
                _buildSheinSection(context),
                if (model.isEdit && (model.item?.id ?? 0) > 0)
                  _buildPurchaseOptionsShortcut(context),
                _buildLocationPreview(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme color = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
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
    if (model.breadcrumbItems.isEmpty) {
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

    final int total = model.breadcrumbItems.length + 1;
    final int activeIndex = model.breadcrumbItems.length;

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
              : (model.breadcrumbItems[index - 1].name ?? '');
          final IconData icon = isHome
              ? Icons.home_outlined
              : (isActive ? Icons.label_important : Icons.chevron_right);

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isActive
                ? null
                : () {
              if (isHome) {
                onBreadcrumbTap(0);
              } else {
                onBreadcrumbTap(index - 1);
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
                children: <Widget>[
                  Icon(
                    icon,
                    size: 18,
                    color: isActive ? colors.territoryColor : baseLabelColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: labelStyle.copyWith(
                      color: isActive ? colors.territoryColor : baseLabelColor,
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

  Widget _buildCoverImageCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme color = theme.colorScheme;
    final File? pickedFile = model.coverImageFile;
    final ImageProvider<Object>? previewProvider;
    if (pickedFile != null) {
      previewProvider = FileImage(pickedFile);
    } else if (model.coverImageUrl.isNotEmpty) {
      previewProvider = NetworkImage(model.coverImageUrl);
    } else {
      previewProvider = null;
    }

    return DottedBorder(
      dashPattern: const <double>[5, 3],
      color: color.borderColor,
      borderType: BorderType.RRect,
      radius: const Radius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPickCoverImage,
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
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
                  children: <Widget>[
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

  Widget _buildTextFieldSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('معلومات الإعلان', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        keyboardManager.wrapWithKeyboardAwareFocus(
          child: CustomTextFormField(
            controller: model.adTitleController,
            hintText: 'عنوان الإعلان',
            validator: CustomTextFieldValidator.nullCheck,
            action: TextInputAction.next,
            capitalization: TextCapitalization.sentences,
            maxLength: 120,
            autofocus: model.enableTitleAutofocus,
          ),
        ),
        const SizedBox(height: 12),
        keyboardManager.wrapWithKeyboardAwareFocus(
          child: CustomTextFormField(
            controller: model.adDescriptionController,
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme color = Theme.of(context).colorScheme;
    const Map<String, String> currencies = <String, String>{
      'YER': 'ريال يمني',
      'SAR': 'ريال سعودي',
      'USD': 'دولار أمريكي',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('التسعير', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: keyboardManager.wrapWithKeyboardAwareFocus(
                child: CustomTextFormField(
                  controller: model.adPriceController,
                  hintText: 'السعر',
                  keyboard: TextInputType.number,
                  action: TextInputAction.next,
                  validator: CustomTextFieldValidator.nullCheck,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: CustomDropdownFormField<String>(
                items: currencies.keys.toList(growable: false),
                value: currencies.keys.contains(model.selectedCurrency)
                    ? model.selectedCurrency
                    : 'YER',
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  model.selectedCurrency = value;
                  onRefresh();
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
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('معلومات التواصل', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Flexible(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: model.selectedCountryCode,
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
                items: submissionService.arabCountries
                    .map(
                      (Map<String, String> country) =>
                      DropdownMenuItem<String>(
                        value: country['code'],
                        child: Text(
                          '${country['code']} (${country['name']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                )
                    .toList(),
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  FocusScope.of(context).unfocus();
                  model.selectedCountryCode = value;
                  onRefresh();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: keyboardManager.wrapWithKeyboardAwareFocus(
                child: CustomTextFormField(
                  controller: model.adPhoneNumberController,
                  hintText: 'رقم الهاتف',
                  keyboard: TextInputType.phone,
                  validator: CustomTextFieldValidator.phoneNumber,
                  isMobileRequired: true,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  action: TextInputAction.next,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        keyboardManager.wrapWithKeyboardAwareFocus(
          child: CustomTextFormField(
            controller: model.adAdditionalDetailsController,
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
    if (!model.isSheinCategory) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final ColorScheme color = theme.colorScheme;
    final Color brandColor = color.territoryColor;

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
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.shopping_bag_outlined, color: brandColor),
              const SizedBox(width: 8),
              Text(
                'روابط شي إن',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: model.isFetchingShein
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(Icons.cloud_download_outlined, color: brandColor),
                onPressed: model.isFetchingShein
                    ? null
                    : () => sheinService.fetchSheinData(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          keyboardManager.wrapWithKeyboardAwareFocus(
            child: CustomTextFormField(
              controller: model.adProductLinkController,
              hintText: 'رابط المنتج على شي إن',
              keyboard: TextInputType.url,
              action: TextInputAction.next,
              validator: CustomTextFieldValidator.url,
              isRequired: false,
              minLine: 1,
              maxLine: 2,
            ),
          ),
          const SizedBox(height: 12),
          keyboardManager.wrapWithKeyboardAwareFocus(
            alignment: 0.4,
            child: CustomTextFormField(
              controller: model.reviewLinkController,
              hintText: 'رابط المراجعات (اختياري)',
              keyboard: TextInputType.url,
              validator: CustomTextFieldValidator.url,
              isRequired: false,
              minLine: 1,
              maxLine: 2,
            ),
          ),
          const SizedBox(height: 12),
          UiUtils.buildButton(
            context,
            buttonTitle: 'جلب من شي إن',
            onPressed: () => sheinService.fetchSheinData(context),
            height: 42,
            disabled: model.isFetchingShein,
            isInProgress: model.isFetchingShein,
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseOptionsShortcut(BuildContext context) {
    final ItemModel? current = model.item;
    if (current == null) {
      return const SizedBox.shrink();
    }

    final bool enabled = submissionService.supportsProductOptionsForItem(current);
    if (!enabled) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme color = theme.colorScheme;

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
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.inventory_2_outlined, color: color.territoryColor),
              const SizedBox(width: 8),
              Text(
                'إدارة خيارات الشراء',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    Routes.productManagementScreen,
                    arguments: <String, dynamic>{'model': current},
                  );
                },
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك إضافة خيارات الشراء، الأسعار، وتفاصيل المخزون من هنا.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPreview(BuildContext context) {
    if (model.latitude == null || model.longitude == null || model.locationAddress == null) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme color = theme.colorScheme;

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
        children: <Widget>[
          Row(
            children: <Widget>[
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
            model.locationAddress ?? '',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}