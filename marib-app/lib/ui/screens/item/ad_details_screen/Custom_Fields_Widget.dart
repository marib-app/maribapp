/// 🧱 عنصر يعرض بيانات الحقل (أيقونة + اسم + قيمة + فاصل)

import 'dart:async';
import 'package:timeago/timeago.dart' as timeago;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'AdImagesHeader.dart';
import 'AdInfoSection.dart';
import 'Description.dart';
import 'ad_details_screen.dart';
import 'dart:math';
import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/utils/color_palette_utils.dart';
import 'package:marib/data/constants/color_catalog.dart';

class CustomFieldsWidget extends StatefulWidget {
  final List<dynamic>? fields;
  final double spacingBetweenNameAndValue;
  final dynamic field;
  final double width;

  const CustomFieldsWidget({
    super.key,
    required this.field,
    required this.width,
    this.spacingBetweenNameAndValue = 4.0,
    required this.fields,
  });

  @override
  State<CustomFieldsWidget> createState() => _CustomFieldsWidgetState();
}

class _CustomFieldsWidgetState extends State<CustomFieldsWidget> {
  bool showAll = false;
  bool loadingExtra = false;
  bool hasExpandedOnce = false;
  final ScrollController _scrollController = ScrollController();
  final _fieldsKey = GlobalKey();
  bool showInitialLoading = false;
  bool isWideField(List<dynamic>? value) {
    if (value == null || value.isEmpty) return false;
    final url = value[0].toString().toLowerCase();
    return url.endsWith(".pdf") ||
        url.endsWith(".png") ||
        url.endsWith(".jpg") ||
        url.endsWith(".jpeg") ||
        url.endsWith(".svg");
  }

  @override
  Widget build(BuildContext context) {
    final customFields =
        widget.fields?.where((f) => f.value?.isNotEmpty == true).toList();

    if (customFields == null || customFields.isEmpty)
      return const SizedBox.shrink();

    const defaultCount = 10;
    final hasMore = customFields.length > defaultCount;
    final extraCount = customFields.length - defaultCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 📝 عنوان "تفاصيل الإعلان"
          Text("تفاصيل الاعلان".translate(context))
              .bold()
              .size(context.font.large),

          const SizedBox(height: 8),

          /// 🧱 قائمة الحقول داخل Scroll + مفتاح للموقع
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: _scrollController,
                child: Wrap(
                  key: _fieldsKey,
                  spacing: 26,
                  runSpacing: 6,
                  children: _buildFieldsList(constraints, customFields),
                ),
              );
            },
          ),

          /// 🔘 زر عرض المزيد
          _buildMoreButton(hasMore, extraCount),
        ],
      ),
    );
  }

  /// 🧱 عنصر يعرض بيانات الحقل (أيقونة + اسم + قيمة + فاصل)
  Widget _buildFieldItem(dynamic field, double width) {
    final customField = field is CustomFieldModel ? field : null;
    final fieldValue = customField?.value ?? field.value;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: field.name ?? "",
                child: Text(
                  field.name ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font.small,
                    color: context.color.textDefaultColor.withOpacity(0.6),
                  ),
                ),
              ),
              SizedBox(height: widget.spacingBetweenNameAndValue),
              valueContent(
                fieldValue,
                context,
                field: customField,
                hideIcon: true,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Divider(
              height: 2,
              thickness: 0.6,
              color: Color(
                  0xFFE0E0E0), // ✅ يكون تلقائي بتناسق شبيه مع الألوان العامة
            ),
          ),
        ],
      ),
    );
  }

  /// 🔘 بناء زر "عرض المزيد" إذا كان هناك حقول إضافية
  Widget _buildMoreButton(bool hasMore, int extraCount) {
    if (!hasMore || hasExpandedOnce) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () async {
          setState(() {
            loadingExtra = true;
            showAll = true;
            hasExpandedOnce = true;
          });

          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;

          setState(() => loadingExtra = false);

          await Future.delayed(const Duration(milliseconds: 200));
          final offset = _scrollController.position.maxScrollExtent;
          _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        },
        child: loadingExtra
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text("عرض المزيد ($extraCount)"),
      ),
    );
  }

  /// 🧱 بناء قائمة الحقول
  List<Widget> _buildFieldsList(
      BoxConstraints constraints, List<dynamic> customFields) {
    const int defaultCount = 10;

    // 🧱 التقسيم بين الحقول الأساسية والإضافية
    final base = customFields.take(defaultCount).toList();
    final extra = customFields.skip(defaultCount).toList();

    // 📦 القائمة النهائية حسب حالة العرض
    final totalList = [
      ...base,
      if (showAll && !loadingExtra) ...extra,
      if (loadingExtra)
        ...List.filled(extra.length, null), // ➕ عناصر وهمية للشيمر
    ];

    // 🌓 تحديد الثيم الحالي لاختيار ألوان الشيمر
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final baseColor = colorScheme.shimmerBaseColor;
    final highlightColor = colorScheme.shimmerHighlightColor;
    final contentColor = colorScheme.shimmerContentColor;

    return List.generate(
      showInitialLoading ? defaultCount : totalList.length,
      (index) {
        final isShimmer = (showInitialLoading && index < defaultCount) ||
            (loadingExtra && index >= defaultCount);

        final field = isShimmer ? null : totalList[index];
        final wide = field != null && isWideField(field.value);
        final width =
            wide ? constraints.maxWidth : (constraints.maxWidth - 26) / 2;

        // ✨ عنصر shimmer مطابق للمحتوى الحقيقي (اسم + قيمة فقط)
        if (isShimmer) {
          return SizedBox(
            width: width,
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: width * 0.6,
                    decoration: BoxDecoration(
                      color: contentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: width * 0.5,
                    decoration: BoxDecoration(
                      color: contentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Divider(
                    height: 2,
                    thickness: 0.6,
                    color:
                        isDark ? Colors.grey.shade800 : const Color(0xFFE0E0E0),
                  ),
                ],
              ),
            ),
          );
        }

        // ✅ عرض العنصر الحقيقي
        return _buildFieldItem(field, width);
      },
    );
  }

//                             الحقول في صفحة الاعلان

  /// ✅ تعرض محتوى الحقول (نص، صورة، PDF...) بتصميم متجاوب ومرن

  Widget valueContent(
    List<dynamic>? value,
    BuildContext context, {
    // ⚙️ إعدادات قابلة للتخصيص
    CustomFieldModel? field,
    Color? buttonColor,
    Color? iconColor,
    Color? textColor,
    double? fontSize,
    double? iconSize,
    double? borderRadius,
    EdgeInsetsGeometry? padding,
    void Function()? onTapFallback,
    bool iconAtEnd = false,
    bool hideIcon = false,
  }) {
    if (value == null || value.isEmpty) {
      return Text("")
          .color(context.color.textDefaultColor)
          .size(fontSize ?? context.font.small);
    }

    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 350;

    final double responsiveFont = fontSize ?? (isSmall ? 11 : 13);
    final double responsiveIcon = iconSize ?? (isSmall ? 14 : 18);
    final double responsiveRadius = borderRadius ?? 6;
    final EdgeInsetsGeometry responsivePadding =
        padding ?? EdgeInsets.symmetric(horizontal: 10, vertical: 6);

    final List<String> sanitizedValues = value
        .map((e) => (e ?? '').toString().trim())
        .where((element) => element.isNotEmpty)
        .toList();

    final bool isColorField = field?.type?.toLowerCase() == 'color';

    if (isColorField) {
      final hexRegExp = RegExp(r'^[0-9A-F]{6}$');
      final hexValues = sanitizedValues
          .map(ColorCatalog.sanitizeHex)
          .where((hex) => hexRegExp.hasMatch(hex))
          .toSet()
          .toList();

      if (hexValues.isEmpty) {
        return Text("")
            .color(textColor ?? context.color.textDefaultColor)
            .size(responsiveFont);
      }

      final labels = hexValues.map((normalized) => ColorCatalog.nameForHex(normalized, context: context).isNotEmpty ? ColorCatalog.nameForHex(normalized, context: context) : "#${normalized}").toList();
 
      return Text(
        labels.join("� "),
        style: TextStyle(
          color: textColor ?? context.color.textDefaultColor,
          fontWeight: FontWeight.w600,
          fontSize: responsiveFont,
        ),
      );
    }

    String url = value[0].toString().toLowerCase();
    bool isImage = url.endsWith(".png") ||
        url.endsWith(".jpg") ||
        url.endsWith(".jpeg") ||
        url.endsWith(".svg");
    bool isPdf = url.endsWith(".pdf");

    /// 🔘 زر ملف/صورة متجاوب

    Widget fileButton({
      required String label,
      required IconData? icon,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(responsiveRadius),
        child: Container(
          padding: responsivePadding,
          decoration: BoxDecoration(
            color: buttonColor ?? context.color.territoryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(responsiveRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!iconAtEnd && !hideIcon) ...[
                Icon(icon,
                    size: responsiveIcon,
                    color: iconColor ?? context.color.territoryColor),
                //       const SizedBox(width: 5),
              ],
              Text(label)
                  .size(responsiveFont)
                  .color(textColor ?? context.color.textColorDark)
                  .bold(),
              if (iconAtEnd && !hideIcon) ...[
                const SizedBox(width: 5),
                Icon(icon,
                    size: responsiveIcon,
                    color: iconColor ?? context.color.territoryColor),
              ]
            ],
          ),
        ),
      );
    }

    // ✅ ملف PDF
    if (url.startsWith("http") || url.startsWith("https")) {
      if (isPdf) {
        return fileButton(
          label: "📄 افتح الملف",
          icon: null,
          onTap: () {
            Navigator.pushNamed(context, Routes.pdfViewerScreen,
                arguments: {"url": value[0]});
          },
        );
      }
      // ✅ صورة
      else if (isImage) {
        return fileButton(
          label: "📷 عرض الصورة",
          icon: null,
          onTap: () {
            UiUtils.showFullScreenImage(context,
                provider: NetworkImage(value[0]));
          },
        );
      }
    }

    // ✅ نص عادي
    return Text(
      sanitizedValues.isEmpty
          ? value.length == 1
              ? value[0].toString()
              : value.join(' , ')
          : sanitizedValues.length == 1
              ? sanitizedValues.first
              : sanitizedValues.join(' , '),
    ).color(textColor ?? context.color.textDefaultColor).size(responsiveFont);
  }
}
