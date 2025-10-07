// ✅ ملف الواجهة: add_item_details_ui.dart
import 'package:marib/utils/helper_utils.dart'; // ✅ لحل خطأ HelperUtils
import 'package:url_launcher/url_launcher.dart';
// لنماذج الحقول المخصصة
import 'package:marib/data/model/custom_field/custom_field_model.dart';

// ويدجت الحقول المخصصة
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart';

// بقية ما كنت مستورده في part (انقلها هنا)
import 'package:marib/utils/helper_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/screens/widgets/custom_drop_down.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/ui/screens/item/add_item_screen/shein_grabber_page.dart';
import 'dart:math' as math;


part of 'add_item_details.dart';

extension AddItemDetailsUI on _AddItemDetailsState {


  Widget _keyboardAwareField({
    required Widget child,
    double alignment = 0.2,
  }) {
    return Builder(
      builder: (fieldContext) => Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            _lastFocusedFieldContext = fieldContext;
            _lastFocusedFieldAlignment = alignment;
            Future.microtask(() {
              if (!_formScrollController.hasClients) {
                return;
              }
              Scrollable.ensureVisible(
                fieldContext,
                alignment: alignment,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            });
          } else if (_lastFocusedFieldContext == fieldContext) {
            _lastFocusedFieldContext = null;
          }
        },
        child: child,
      ),
    );
  }


  Widget buildDynamicFieldsSection(BuildContext context) {
    if (isLoadingCustomFields) {
      return Padding(
        padding: EdgeInsets.only(top: 12.rh(context)),
        child: const LinearProgressIndicator(),
      );
    }

    if (customFields == null || customFields!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: 12.rh(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "الحقول الإضافية",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10.rh(context)),
          ...customFields!.map((f) => _buildSingleDynamicField(context, f)),
          SizedBox(height: 15.rh(context)),
        ],
      ),
    );
  }

  Widget _buildSingleDynamicField(BuildContext context, CustomFieldModel f) {
    final type = (f.type ?? '').toLowerCase();
    final isNumber   = type == 'number';
    final isTextArea = type == 'textarea' || type == 'long_text';

    final initialValue = _stringifyValue(
      AbstractField.fieldsData[f.id.toString()] ?? f.value,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 10.rh(context)),
      child: _keyboardAwareField(
        child: CustomTextFieldDynamic(
          initController: true,
          value: initialValue,
          id: f.id,
          hintText: (f.name ?? 'حقل مخصص').firstUpperCase(),
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          action: TextInputAction.next,
          formaters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
          required: (f.required == 1),
          validator: (f.required == 1) ? CustomTextFieldValidator.nullCheck : null,
          minLen: f.minLength,
          maxLen: f.maxLength,
          minLine: isTextArea ? 4 : 1,
          maxLine: isTextArea ? 6 : 1,
          capitalization: TextCapitalization.sentences,
        ),
      ),
    );
  }

  String _stringifyValue(dynamic v) {
    if (v == null) return '';
    if (v is List) return v.join(', ');
    return v.toString();
  }


  Widget buildUI(BuildContext context) {
    final currencyTypes = {
      "YER": "ر.ي - يمني".translate(context),
      "SAR": "ر.س - سعودي".translate(context),
      "USD": "د.أ - دولار".translate(context),

    };

    _updateSheinCategoryFlag(_currentCategoryIds(), notify: false);

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final footerHeight = 48.rh(context) + 20 + mediaQuery.padding.bottom;
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: SafeArea(
        child: Scaffold(
          appBar: UiUtils.buildAppBar(
            context,
            showBackButton: true,
            title: "AdDetails".translate(context),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: UiUtils.buildButton(
              context,
              onPressed: () => handleFormSubmission(context),
              height: 48.rh(context),
              fontSize: context.font.large,
              buttonTitle: "next".translate(context),
            ),
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _formScrollController,
              padding: EdgeInsets.fromLTRB(
                18.0,
                18.0,
                18.0,
                24.0 + math.max(bottomInset, footerHeight),
              ),

                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeaderMessage(context),
                    SizedBox(height: 16.rh(context)),
                    if (widget.breadCrumbItems != null)
                      buildBreadCrumbs(context),
                    SizedBox(height: 18.rh(context)),
                    itemImagesListener(
                      context: context,
                      mixedItemImageList: mixedItemImageList,
                      isUploadingExtra: isUploadingExtra,
                      itemImagePicker: itemImagePicker,
                      onPick: (source) async {
                        setState(() => isUploadingExtra = true);
                        await itemImagePicker.pick(
                          pickMultiple: source == ImageSource.gallery,
                          context: context,
                          imageLimit: 10,
                          maxLength: mixedItemImageList.length,
                          source: source,
                        );
                        Future.microtask(() => setState(() => isUploadingExtra = false));
                      },
                      onRemove: (index) {
                        setState(() {
                          final dynamic removed = mixedItemImageList[index];

                          if (removed is Map) {
                            final dynamic rawId = removed['id'];
                            final int? imageId = rawId is int
                                ? rawId
                                : (rawId is String ? int.tryParse(rawId) : null);

                            if (imageId != null &&
                                !deleteItemImageList.contains(imageId)) {
                              deleteItemImageList.add(imageId);
                            }

                            if (removed['isMain'] == true ||
                                removed['url'] == titleImageURL) {
                              titleImageURL = "";
                            }
                          } else if (removed is File &&
                              _pickTitleImage.pickedFile == removed) {
                            _pickTitleImage.pickedFile = null;
                          }

                          mixedItemImageList.removeAt(index);
                        });

                        },
                    ),
                    if (_isSheinCategory) ...[
                      buildProductLinkField(context),
                      buildReviewLinkField(context),
                    ],

                    buildTitleField(context),
                    buildDescriptionField(context),
                    buildPriceAndCurrency(context, currencyTypes),
                    buildPhoneNumberField(context),
                    buildDynamicFieldsSection(context),
                  ],
                ),
              ),
            ),
          ),
        ),

    );
  }




  Widget buildReviewLinkField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 15.rh(context)),
        Text(
          "إضافة رابط المراجعة",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 10.rh(context)),
        _keyboardAwareField(
          child: CustomTextFormField(
            controller: reviewLinkController,
            keyboard: TextInputType.url,
            action: TextInputAction.next,
            capitalization: TextCapitalization.none,
            hintText: "رابط لتوجيه المستخدم للتحقق من المنتج",
            hintTextStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),

        ),
        SizedBox(height: 15.rh(context)),
      ],
    );
  }






  Widget buildProductLinkField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brandColor = colorScheme.territoryColor;

    Color foregroundFor(Color background) =>
        colorScheme.textAutoAdapt(background);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.rh(context)),
        Text(
          "رابط المنتج",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 10.rh(context)),

        // السطر الأول: حقل الإدخال + زر المعاينة
        Row(
          children: [
            Expanded(
              child: _keyboardAwareField(
                child: CustomTextFormField(
                  controller: adProductLinkController,
                  keyboard: TextInputType.url,
                  action: TextInputAction.next,
                  capitalization: TextCapitalization.none,
                  hintText: "الصق رابط شي إن هنا ...",
                  hintTextStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.right,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),

              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: foregroundFor(brandColor),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),

              ),
              onPressed: _isFetchingShein
                  ? null
                  : () async {
                final url = adProductLinkController.text.trim();
                if (url.isEmpty) {
                  HelperUtils.showSnackBarMessage(
                      context, "الرجاء إدخال رابط المنتج أولاً");
                  return;
                }
                final uri = Uri.tryParse(url);
                if (uri == null ||
                    !(uri.host.contains("shein.com") ||
                        uri.host.contains("sheinapp.com"))) {
                  HelperUtils.showSnackBarMessage(
                      context, "الرجاء إدخال رابط صالح من موقع شي إن");
                  return;
                }
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                } else {
                  HelperUtils.showSnackBarMessage(
                      context, "تعذّر فتح الرابط");
                }
              },
              child: _isFetchingShein
                  ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(
                      foregroundFor(brandColor)),
                ),
              )
                  : const Icon(Icons.open_in_new),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // السطر الثاني: زر الجلب عبر WebView + زر المسح
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text("جلب المنتج"),
                style: FilledButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: foregroundFor(brandColor),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () async {
                  final url = adProductLinkController.text.trim();
                  if (url.isEmpty) {
                    HelperUtils.showSnackBarMessage(
                        context, "أدخل رابط المنتج أولاً");

                    return;
                  }

                  // افتح صفحة الجلب عبر WebView
                  final res = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SheinGrabberPage(startUrl: url)),

                  );

                  if (res == null) return;

                  final title = (res['title'] as String?)?.trim();
                  final price = (res['price'] as String?)?.replaceAll(',', '');
                  final currency = (res['currency'] as String?)?.toUpperCase();
                  final imgs = (res['images'] as List?)?.cast<String>() ?? [];

                  if (title?.isNotEmpty == true) adTitleController.text = title!;
                  if (price?.isNotEmpty == true) adPriceController.text = price!;
                  if (currency != null && currency.isNotEmpty) {
                    if (mounted) {
                      setState(() => _selectedCurrency = currency);
                    } else {
                      _selectedCurrency = currency;
                    }

                  }

                  final materializedImages = await _materializeRemoteImages(imgs);
                  if (materializedImages.isNotEmpty) {
                    final firstImage = materializedImages.first;
                    if (firstImage['isMain'] != true) {
                      firstImage['isMain'] = true;
                    }
                  }

                  if (!mounted) return;

                  setState(() {
                    mixedItemImageList
                      ..clear()
                      ..addAll(materializedImages);
                  });


                  HelperUtils.showSnackBarMessage(
                      context, "تم الجلب من WebView ✅");

                  },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: FilledButton.icon(
                onPressed: () => adProductLinkController.clear(),
                icon: const Icon(Icons.clear),
                label: const Text("مسح"),
                style: FilledButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: foregroundFor(brandColor),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }



  Widget buildBreadCrumbs(BuildContext context) {
    final items = widget.breadCrumbItems!;
    final colors = context.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final total = items.length + 1;
    final activeIndex = items.isEmpty ? 0 : items.length;
    final keys = List.generate(total, (_) => GlobalKey());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (activeIndex >= 0 && activeIndex < keys.length) {
        final ctx = keys[activeIndex].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.5,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });

    Color _chipBorder(bool isActive) => isActive
        ? colors.territoryColor.withOpacity(0.55)
        : (isDark
        ? Colors.white.withOpacity(0.10)
        : colors.borderColor.darken(4));

    Color _chipBackground(bool isActive) => isActive
        ? colors.territoryColor.withOpacity(0.12)
        : (isDark
        ? Colors.white.withOpacity(0.04)
        : colors.secondaryColor);

    Color _chipForeground(bool isActive) {
      final base = colors.textDefaultColor;
      return base.withOpacity(isActive ? 0.95 : 0.85);
    }

    Widget buildChip({
      required String label,
      required IconData icon,
      required bool isActive,
      required VoidCallback onTap,
      required int keyIndex,
    }) {
      return Container(
        key: keys[keyIndex],
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _chipBackground(isActive),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _chipBorder(isActive), width: 1),
              boxShadow: isActive
                  ? [
                BoxShadow(
                  color: colors.territoryColor.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: _chipForeground(isActive)
                        .withOpacity(isActive ? 0.95 : 0.8)),
                const SizedBox(width: 6),
                Text(label)
                    .size(context.font.small)
                    .color(_chipForeground(isActive)),
              ],
            ),
          ),
        ),
      );
    }

    void handleHomeTap() {
      if (items.isEmpty) {
        Navigator.pop(context);
        return;
      }
      _onBreadCrumbItemTap(0);
    }

    return SizedBox(
      height: 40,


      child: ListView.separated(

        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),

        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: 8),


        itemBuilder: (context, index) {
          if (index == 0) {
            return buildChip(
              label: "Home",
              icon: Icons.home_outlined,
              isActive: activeIndex == 0,
              onTap: handleHomeTap,
              keyIndex: index,
            );
          }

          final crumb = items[index - 1];
          final isLast = index == items.length;
          return buildChip(
            label: crumb.name?.firstUpperCase() ?? '',
            icon: isLast ? Icons.label_important : Icons.chevron_right,
            isActive: isLast,
            onTap: () => _onBreadCrumbItemTap(index - 1),
            keyIndex: index,
          );
        },
      ),
    );
  }



  Widget buildTitleField(BuildContext context) {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.rh(context)),
        Text(
          "adTitle".translate(context),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 10.rh(context)),
        _keyboardAwareField(
          child: CustomTextFormField(
            controller: adTitleController,
            validator: CustomTextFieldValidator.maxFifty,
            action: TextInputAction.next,
            capitalization: TextCapitalization.sentences,
            hintText: "adTitleHere".translate(context),
            hintTextStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        SizedBox(height: 15.rh(context)),
      ],
    );
  }


  Widget buildDescriptionField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "descriptionLbl".translate(context),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 10.rh(context)),
        _keyboardAwareField(
          alignment: 0.05,
          child: CustomTextFormField(
            controller: adDescriptionController,
            action: TextInputAction.newline,
            capitalization: TextCapitalization.sentences,
            validator: CustomTextFieldValidator.nullCheck,
            hintText: "writeSomething".translate(context),
            maxLine: 15,
            minLine: 6,
            hintTextStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        SizedBox(height: 15.rh(context)),
      ],
    );
  }





  Widget buildPriceAndCurrency(BuildContext context, Map<String, String> currencyTypes) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 360;

        return isSmallScreen
            ? Column( // ✅ للهواتف الصغيرة
          children: [
            _buildPriceField(context),
            const SizedBox(height: 60),
            _buildCurrencyDropdown(context, currencyTypes),
          ],
        )
            : Row( // ✅ الوضع الطبيعي
          children: [
            Expanded(child: _buildPriceField(context)),
            const SizedBox(width: 8),
            Expanded(child: _buildCurrencyDropdown(context, currencyTypes)),
          ],
        );
      },
    );
  }

  Widget _buildPriceField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "price".translate(context),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 10.rh(context)),
        _keyboardAwareField(
          child: CustomTextFormField(
            controller: adPriceController,
            action: TextInputAction.next,
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            isReadOnly: false,
            keyboard: TextInputType.number,
            validator: CustomTextFieldValidator.nullCheck,
            hintText: "00.00",
            hintTextStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                getCurrencySymbol(_selectedCurrency),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildCurrencyDropdown(BuildContext context, Map<String, String> currencyTypes) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "العملة".translate(context),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 10.rh(context)),
        CustomDropdownFormField<String>(
          hintText: "choosecurrency".translate(context),
          items: currencyTypes.values.toList(),
          value: currencyTypes[_selectedCurrency],
          isRequired: true,
          textStyle: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
          ),
          onChanged: (value) {
            setState(() {
              _selectedCurrency = currencyTypes.keys.firstWhere(
                    (key) => currencyTypes[key] == value,
              );
            });
          },
        ),
      ],
    );
  }

  String getCurrencySymbol(String? currencyKey) {
    switch (currencyKey) {
      case 'usd':
        return "\$";
      case 'sar':
        return "﷼";
      case 'yer':
        return "﷼";
      default:
        return "";
    }
  }





// حقل رقم الهاتف

  Widget buildPhoneNumberField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.rh(context)),
        Text(
          "phoneNumber".translate(context),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 10.rh(context)),
        Row(
          children: [
            // ✅ قائمة بحث فيها الدول العربية
            SizedBox(
              width: 130,
              child: DropdownSearch<Map<String, String>>(
                selectedItem: arabCountries.firstWhere(
                      (c) => c["code"] == _selectedCountryCode,
                ),
                items: arabCountries,
                itemAsString: (item) => "${item["name"]} (${item["code"]})",
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: "ابحث عن الدولة...",
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCountryCode = value["code"]!);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),

            // ✅ حقل الرقم
            Expanded(
              child: _keyboardAwareField(
                child: CustomTextFormField(
                  controller: adPhoneNumberController,
                  action: TextInputAction.next,
                  keyboard: TextInputType.phone,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  validator: CustomTextFieldValidator.phoneNumber,
                  hintText: "77XXXXXXX",
                  hintTextStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 15.rh(context)),
      ],
    );
  }





  Widget buildHeaderMessage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_objects_outlined, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              "youAreAlmostThere".translate(context),
              style: TextStyle(
                fontSize: context.font.extraLarge,
                fontWeight: FontWeight.w700,
                color: context.color.textColorDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

