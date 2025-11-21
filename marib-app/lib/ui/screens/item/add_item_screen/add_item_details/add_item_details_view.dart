import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/ui/screens/item/purchase_options/product_management_screen.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_keyboard_manager.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_submission.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_shein_service.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/item/product_management_cubit.dart';
import 'package:marib/data/repositories/item/item_purchase_options_repository.dart';
import 'package:marib/utils/helper_utils.dart';

import 'package:marib/data/model/custom_field/custom_field_model.dart'
    show CustomFieldColorEntry;
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';






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
    final mediaQuery = MediaQuery.of(context);
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
                _buildMediaHeader(context),
                const SizedBox(height: 12),
                _buildMediaGrid(context),
                const SizedBox(height: 16),
      //          _buildBreadcrumbs(context),
                const SizedBox(height: 20),
                _buildTextFieldSection(context),
                const SizedBox(height: 20),
                _buildPricingSection(context),
                const SizedBox(height: 20),
                _buildContactSection(context),
                const SizedBox(height: 20),
                _buildSheinSection(context),
                const SizedBox(height: 20),
               _buildProductOptionsButton(context),
                _buildLocationPreview(context),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _makeMainFromItem(dynamic item) {
    final list = model.galleryItems;
    final i = list.indexOf(item);
    if (i > 0) {
      list.removeAt(i);
      list.insert(0, item);
    }
    // لو رابط: خزّنه، لو ملف: افرغه (لأن الحقل غير قابل لـ null)
    model.coverImageUrl = (item is String) ? item : '';
    onRefresh();
  }

  void _afterAddImage(dynamic fileOrUrl) {
    model.galleryItems.add(fileOrUrl);
    if (model.galleryItems.length == 1) {
      // اجعلها غلافًا: انقلها للمركز 0 وحدّث coverImageUrl فقط إن كانت رابط
      final dynamic first = model.galleryItems.first;
      model.coverImageUrl = (first is String) ? first : '';
      onRefresh();
    }
  }


  // --- Media (Images & Video) ---
  Widget _buildMediaHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Debugging overlay to show cover/gallery state when running in debug.
        // Visible only in debug mode to help QA.
        if (kDebugMode)
          Builder(builder: (ctx) {
            final String coverFilePresent = (model.coverImageFile != null) ? 'yes' : 'no';
            final int galleryFiles = model.galleryItems.where((e) => e is File).length;
            final int galleryMaps = model.galleryItems.where((e) => e is Map).length;

            String summarizePayload(dynamic p) {
              try {
                if (p == null) return 'null';
                if (p is Map && p['file'] != null) {
                  final dynamic f = p['file'];
                  if (f is Iterable) {
                    final List<String> names = [];
                    for (final dynamic it in f) {
                      if (it is File) names.add(it.path.split(RegExp(r'[\\/]')).last);
                      else names.add(it.toString());
                    }
                    return names.join(',');
                  }
                  if (f is File) return f.path.split(RegExp(r'[\\/]')).last;
                }
                return p.toString();
              } catch (_) {
                return p.toString();
              }
            }

            final String coverLast = summarizePayload(model.coverImagePicker.lastPayload);
            final String galleryLast = summarizePayload(model.galleryPicker.lastPayload);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('[DBG] cover:' , style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text('file=$coverFilePresent'),
                    const SizedBox(width: 12),
                    Text('files=$galleryFiles'),
                    const SizedBox(width: 8),
                    Text('maps=$galleryMaps'),
                    const Spacer(),
                    // Debug action: dump image state
                    TextButton(
                      onPressed: () {
                        try {
                          submissionService.debugDumpImageState(ctx);
                        } catch (_) {}
                      },
                      child: const Text('DBG: dump'),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('cover.last: $coverLast', style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('gallery.last: $galleryLast', style: const TextStyle(fontSize: 11)),
                ],
              ),
            );
          }),
        Row(
          children: [
            Text('إضافة صور وفيديو', style: theme.textTheme.titleMedium),
            const Spacer(),
            if (model.isUploadingGallery)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'يمكنك رفع مرفقات بحد أقصى 15 ملف (فيديو واحد) — اختر الصورة الرئيسية بالضغط عليها مطول',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }



  Widget _buildMediaGrid(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: model.galleryItems.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return InkWell(
            onTap: () => onPickGalleryImage(ImageSource.gallery),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: colors.secondaryColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.borderColor.withOpacity(0.4)),
              ),
              child: const Center(child: Icon(Icons.add, size: 36)),
            ),
          );
        }

        final dynamic item = model.galleryItems[index - 1];
        ImageProvider? image;
        if (item is File) {
          image = FileImage(item);
        } else if (item is String && item.isNotEmpty) {
          image = NetworkImage(item);
        }

        final bool isMain = (item is File && model.coverImageFile?.path == item.path) ||
            (item is String && model.coverImageUrl == item);

        return GestureDetector(
          onLongPress: () {
            // Mark this image as the cover. If the image is a local File,
            // store it in the PickImage.pickedFile so `model.coverImageFile`
            // becomes non-null. If it's a remote URL (String or Map url),
            // set `coverImageUrl` instead.
            try {
              if (item is File) {
                model.coverImagePicker.pickedFile = item;
                model.coverImagePicker.lastPayload = {"error": "", "file": [item]};
                model.coverImageUrl = '';
                if (kDebugMode) {
                  // ignore: avoid_print
                  print('[debug] long-press -> set cover pickedFile=${item.path}');
                }
              } else if (item is Map) {
                final dynamic fileVal = item['file'];
                final dynamic urlVal = item['url'];
                if (fileVal is File) {
                  model.coverImagePicker.pickedFile = fileVal;
                  model.coverImagePicker.lastPayload = {"error": "", "file": [fileVal]};
                  model.coverImageUrl = '';
                  if (kDebugMode) {
                    // ignore: avoid_print
                    print('[debug] long-press -> set cover pickedFile=${fileVal.path} from Map');
                  }
                } else if (urlVal is String && urlVal.isNotEmpty) {
                  model.coverImagePicker.pickedFile = null;
                  model.coverImagePicker.lastPayload = {"error": "", "file": []};
                  model.coverImageUrl = urlVal;
                  if (kDebugMode) {
                    // ignore: avoid_print
                    print('[debug] long-press -> set cover url=$urlVal');
                  }
                }
              } else if (item is String) {
                model.coverImagePicker.pickedFile = null;
                model.coverImagePicker.lastPayload = {"error": "", "file": []};
                model.coverImageUrl = item;
                if (kDebugMode) {
                  // ignore: avoid_print
                  print('[debug] long-press -> set cover url=$item (String)');
                }
              }
            } catch (_) {
              // ignore
            }
            onRefresh();
          },
          child: Stack(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderColor.withOpacity(0.4)),
                  image: image == null
                      ? null
                      : DecorationImage(image: image, fit: BoxFit.cover),
                  color: colors.secondaryColor,
                ),
                child: image == null
                    ? const Center(child: Icon(Icons.image_outlined))
                    : null,
              ),
              PositionedDirectional(
                top: 6,
                end: 6,
                child: InkWell(
                  onTap: () => onRemoveGalleryImage(index - 1),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
              if (isMain)
                PositionedDirectional(
                  bottom: 6,
                  start: 6,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        SizedBox(width: 4),
                        Text('رئيسية',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }


// اسم الاعلان
  Widget _buildTextFieldSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('اسم الإعلان', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        keyboardManager.wrapWithKeyboardAwareFocus(
          child: CustomTextFormField(
            controller: model.adTitleController,
            hintText: 'الاسم',
            validator: CustomTextFieldValidator.nullCheck,
            action: TextInputAction.next,
            capitalization: TextCapitalization.sentences,
            maxLength: 120,
          ),
        ),
        const SizedBox(height: 16),
        Text('وصف الإعلان', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        keyboardManager.wrapWithKeyboardAwareFocus(
          child: CustomTextFormField(
            controller: model.adDescriptionController,
            hintText: 'وصف الاعلان',
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
    final colors = Theme.of(context).colorScheme;
    const Map<String, String> currencies = <String, String>{
      'YER': 'ر.ي',
      'SAR': 'ر.س',
      'USD': 'د.أ',
    };
    final List<MapEntry<String, String>> entries = currencies.entries.toList();

    // تنسيق الأرقام أثناء الكتابة: يفصل كل 3 خانات بـ "," ويحافظ على الجزء العشري كما كُتب (.,)
    String _formatGrouped(String raw) {
      // أبقِ الأرقام + الفواصل العشرية الشائعة فقط
      final String cleaned = raw.replaceAll(RegExp(r'[^0-9\.,]'), '');
      if (cleaned.isEmpty) return '';

      // حدد الفاصل العشري المستخدم (إن وُجد)
      final bool hasComma = cleaned.contains(',');
      final bool hasDot = cleaned.contains('.');
      String decSep = '';
      if (hasComma && !hasDot) decSep = ',';
      if (!hasComma && hasDot) decSep = '.';
      if (hasComma && hasDot) {
        // إن وُجدا معًا: اعتبر آخر ظهور هو الفاصل العشري
        final int lastComma = cleaned.lastIndexOf(',');
        final int lastDot = cleaned.lastIndexOf('.');
        decSep = lastComma > lastDot ? ',' : '.';
      }

      String intPart = cleaned;
      String fracPart = '';
      if (decSep.isNotEmpty) {
        final int idx = cleaned.lastIndexOf(decSep);
        intPart = cleaned.substring(0, idx);
        fracPart = cleaned.substring(idx + 1).replaceAll(RegExp(r'[^0-9]'), '');
      }

      // أزل أي فواصل قديمة من الجزء الصحيح
      intPart = intPart.replaceAll(RegExp(r'[^0-9]'), '');
      // أضف فواصل كل 3 خانات
      final String reversed = intPart.split('').reversed.join();
      final String groupedReversed =
      RegExp(r'.{1,3}').allMatches(reversed).map((m) => m.group(0)!).join(',');
      final String grouped = groupedReversed.split('').reversed.join();

      if (decSep.isEmpty || fracPart.isEmpty) return grouped;
      return '$grouped$decSep$fracPart';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('السعر والعملة', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),

        // حقل السعر مع شارة العملة داخل الحقل (Suffix)
        keyboardManager.wrapWithKeyboardAwareFocus(
          child: CustomTextFormField(
            controller: model.adPriceController,
            hintText: 'اكتب السعر هنا',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            action: TextInputAction.next,
            validator: CustomTextFieldValidator.nullCheck,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
            ],
            onChanged: (String v) {
              final String formatted = _formatGrouped(v);
              if (formatted != v) {
                final int baseOffset = formatted.length;
                model.adPriceController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: baseOffset),
                );
              }
            },
            // نفترض أن CustomTextFormField يمرر هذه إلى InputDecoration:
            suffixIcon: Container(
              margin: const EdgeInsetsDirectional.only(end: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                currencies[model.selectedCurrency] ?? '—',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // خيارات العملة: تعبئة العرض بالكامل بالتساوي
        Row(
          children: <Widget>[
            for (int i = 0; i < entries.length; i++) ...[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    model.selectedCurrency = entries[i].key;
                    onRefresh();
                  },
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: model.selectedCurrency == entries[i].key
                          ? colors.territoryColor.withOpacity(0.12)
                          : colors.secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: model.selectedCurrency == entries[i].key
                            ? colors.territoryColor
                            : colors.borderColor.withOpacity(0.6),
                      ),
                    ),
                    child: Text(
                      entries[i].value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: model.selectedCurrency == entries[i].key
                            ? colors.territoryColor
                            : colors.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              if (i != entries.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    final theme = Theme.of(context);
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
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
                  if (value == null) return;
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
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildSheinSection(BuildContext context) {
    if (!model.isSheinCategory) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final Color brandColor = colors.territoryColor;

    // تنظيف/تطبيع رابط شي إن
    String _cleanSheinUrl(String input) {
      String t = input.trim();
      if (t.isEmpty) return '';
      final Uri? u0 = Uri.tryParse(t);
      if (u0 != null && u0.queryParameters.containsKey('url')) {
        final Uri? inner = Uri.tryParse(u0.queryParameters['url']!);
        if (inner != null) t = inner.toString();
      }
      final Uri? u = Uri.tryParse(t);
      if (u == null) return input.trim();
      String host = u.host;
      if (host.endsWith('shein.com')) host = 'www.shein.com';
      return Uri(scheme: 'https', host: host, path: u.path).toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // رأس القسم + زر الجلب
        Row(
          children: <Widget>[
            Icon(Icons.shopping_bag_outlined, color: brandColor),
            const SizedBox(width: 8),
            Text('روابط شي إن', style: theme.textTheme.titleMedium),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: model.isFetchingShein ? null : () => sheinService.fetchSheinData(context),
              icon: model.isFetchingShein
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_download_outlined, size: 18),
              label: const Text('جلب المنتج'),
              style: ElevatedButton.styleFrom(
                foregroundColor: colors.onPrimary,
                backgroundColor: brandColor,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // رابط المنتج
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
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {
                final cleaned = _cleanSheinUrl(model.adProductLinkController.text);
                model.adProductLinkController.value = TextEditingValue(
                  text: cleaned,
                  selection: TextSelection.collapsed(offset: cleaned.length),
                );
                onRefresh();
              },
              icon: const Icon(Icons.cleaning_services_rounded, size: 18),
              label: const Text('تنظيف'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                side: BorderSide(color: colors.borderColor.withOpacity(0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                foregroundColor: colors.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                model.adProductLinkController.clear();
                onRefresh();
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('حذف'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                foregroundColor: colors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // رابط المراجعات (اختياري)
        keyboardManager.wrapWithKeyboardAwareFocus(
          alignment: 0.4,
          child: CustomTextFormField(
            controller: model.reviewLinkController,
            hintText: 'رابط المراجعة (  اختياري  )',
            keyboard: TextInputType.url,
            validator: CustomTextFieldValidator.url,
            isRequired: false,
            minLine: 1,
            maxLine: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildProductOptionsButton(BuildContext context) {
    final theme  = Theme.of(context);
    final colors = theme.colorScheme;
    final brand  = colors.territoryColor;

    final ItemModel current = model.item ?? ItemModel();

    // السماح فقط لأقسام (المتجر/الكمبيوتر/شي إن) عبر الخدمة المركزية
    final bool eligible = submissionService.supportsProductOptionsForItem(current);
    if (!eligible) return const SizedBox.shrink();

    // تأكد من وجود أي صورة (غلاف كرابط أو أي عنصر في المعرض)
    final String coverUrl = (model.coverImageUrl ?? '').trim();
    final bool hasGallery = model.galleryItems.any(
          (e) => (e is String && e.trim().isNotEmpty) || (e is File),
    );
    final bool hasAnyImage = coverUrl.isNotEmpty || hasGallery;

    return Material(
      color: colors.secondaryColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderColor.withOpacity(0.4)),
      ),
        child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: brand.withOpacity(0.10),
        highlightColor: brand.withOpacity(0.06),
        onTap: () {
          // Delegate the open/create-draft flow to the submission service.
          // The service will validate images, attempt to create a quick draft
          // if needed, and open the ProductManagementScreen when ready.
          submissionService.openProductManagementOrCreateDraft(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(Icons.tune_rounded, color: brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إدارة خيارات الشراء والمخزون للمنتج الحالي',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 18, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildLocationPreview(BuildContext context) {
    if (model.latitude == null ||
        model.longitude == null ||
        model.locationAddress == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.location_pin, color: colors.territoryColor),
              const SizedBox(width: 8),
              Text('الموقع المحدد', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(model.locationAddress ?? '', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
