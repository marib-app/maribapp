/// ًں§± ط¹ظ†طµط± ظٹط¹ط±ط¶ ط¨ظٹط§ظ†ط§طھ ط§ظ„ط­ظ‚ظ„ (ط£ظٹظ‚ظˆظ†ط© + ط§ط³ظ… + ظ‚ظٹظ…ط© + ظپط§طµظ„)

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
          /// ًں“‌ ط¹ظ†ظˆط§ظ† "طھظپط§طµظٹظ„ ط§ظ„ط¥ط¹ظ„ط§ظ†"
          Text("طھظپط§طµظٹظ„ ط§ظ„ط§ط¹ظ„ط§ظ†".translate(context))
              .bold()
              .size(context.font.large),

          const SizedBox(height: 8),

          /// ًں§± ظ‚ط§ط¦ظ…ط© ط§ظ„ط­ظ‚ظˆظ„ ط¯ط§ط®ظ„ Scroll + ظ…ظپطھط§ط­ ظ„ظ„ظ…ظˆظ‚ط¹
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

          /// ًں”ک ط²ط± ط¹ط±ط¶ ط§ظ„ظ…ط²ظٹط¯
          _buildMoreButton(hasMore, extraCount),
        ],
      ),
    );
  }

  /// ًں§± ط¹ظ†طµط± ظٹط¹ط±ط¶ ط¨ظٹط§ظ†ط§طھ ط§ظ„ط­ظ‚ظ„ (ط£ظٹظ‚ظˆظ†ط© + ط§ط³ظ… + ظ‚ظٹظ…ط© + ظپط§طµظ„)
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
                  0xFFE0E0E0), // âœ… ظٹظƒظˆظ† طھظ„ظ‚ط§ط¦ظٹ ط¨طھظ†ط§ط³ظ‚ ط´ط¨ظٹظ‡ ظ…ط¹ ط§ظ„ط£ظ„ظˆط§ظ† ط§ظ„ط¹ط§ظ…ط©
            ),
          ),
        ],
      ),
    );
  }

  /// ًں”ک ط¨ظ†ط§ط، ط²ط± "ط¹ط±ط¶ ط§ظ„ظ…ط²ظٹط¯" ط¥ط°ط§ ظƒط§ظ† ظ‡ظ†ط§ظƒ ط­ظ‚ظˆظ„ ط¥ط¶ط§ظپظٹط©
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
            : Text("ط¹ط±ط¶ ط§ظ„ظ…ط²ظٹط¯ ($extraCount)"),
      ),
    );
  }

  /// ًں§± ط¨ظ†ط§ط، ظ‚ط§ط¦ظ…ط© ط§ظ„ط­ظ‚ظˆظ„
  List<Widget> _buildFieldsList(
      BoxConstraints constraints, List<dynamic> customFields) {
    const int defaultCount = 10;

    // ًں§± ط§ظ„طھظ‚ط³ظٹظ… ط¨ظٹظ† ط§ظ„ط­ظ‚ظˆظ„ ط§ظ„ط£ط³ط§ط³ظٹط© ظˆط§ظ„ط¥ط¶ط§ظپظٹط©
    final base = customFields.take(defaultCount).toList();
    final extra = customFields.skip(defaultCount).toList();

    // ًں“¦ ط§ظ„ظ‚ط§ط¦ظ…ط© ط§ظ„ظ†ظ‡ط§ط¦ظٹط© ط­ط³ط¨ ط­ط§ظ„ط© ط§ظ„ط¹ط±ط¶
    final totalList = [
      ...base,
      if (showAll && !loadingExtra) ...extra,
      if (loadingExtra)
        ...List.filled(extra.length, null), // â‍• ط¹ظ†ط§طµط± ظˆظ‡ظ…ظٹط© ظ„ظ„ط´ظٹظ…ط±
    ];

    // ًںŒ“ طھط­ط¯ظٹط¯ ط§ظ„ط«ظٹظ… ط§ظ„ط­ط§ظ„ظٹ ظ„ط§ط®طھظٹط§ط± ط£ظ„ظˆط§ظ† ط§ظ„ط´ظٹظ…ط±
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

        // âœ¨ ط¹ظ†طµط± shimmer ظ…ط·ط§ط¨ظ‚ ظ„ظ„ظ…ط­طھظˆظ‰ ط§ظ„ط­ظ‚ظٹظ‚ظٹ (ط§ط³ظ… + ظ‚ظٹظ…ط© ظپظ‚ط·)
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

        // âœ… ط¹ط±ط¶ ط§ظ„ط¹ظ†طµط± ط§ظ„ط­ظ‚ظٹظ‚ظٹ
        return _buildFieldItem(field, width);
      },
    );
  }

//                             ط§ظ„ط­ظ‚ظˆظ„ ظپظٹ طµظپط­ط© ط§ظ„ط§ط¹ظ„ط§ظ†

  /// âœ… طھط¹ط±ط¶ ظ…ط­طھظˆظ‰ ط§ظ„ط­ظ‚ظˆظ„ (ظ†طµطŒ طµظˆط±ط©طŒ PDF...) ط¨طھطµظ…ظٹظ… ظ…طھط¬ط§ظˆط¨ ظˆظ…ط±ظ†

  Widget valueContent(
    List<dynamic>? value,
    BuildContext context, {
    // âڑ™ï¸ڈ ط¥ط¹ط¯ط§ط¯ط§طھ ظ‚ط§ط¨ظ„ط© ظ„ظ„طھط®طµظٹطµ
    CustomFieldModel? field,
    Color? buttonColor,
    Color? textColor,
    double? fontSize,
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
    final double chipRadius = borderRadius ?? 6;
    final EdgeInsetsGeometry contentPadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6);

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

      final labels = hexValues
          .map((normalized) => ColorCatalog.nameForHex(normalized, context: context).isNotEmpty
              ? ColorCatalog.nameForHex(normalized, context: context)
              : "#$normalized")
          .toList();
 
      return Text(
        labels.join("، "),
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

    if (url.startsWith("http") || url.startsWith("https")) {
      if (isPdf) {
        return InkWell(
          onTap: () {
            Navigator.pushNamed(context, Routes.pdfViewerScreen,
                arguments: {"url": value[0]});
          },
          child: Container(
            padding: contentPadding,
            decoration: BoxDecoration(
              color: buttonColor ?? context.color.territoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(chipRadius),
            ),
            child: Text(
              "افتح الملف",
              style: TextStyle(
                color: textColor ?? context.color.textColorDark,
                fontWeight: FontWeight.w600,
                fontSize: responsiveFont,
              ),
            ),
          ),
        );
      } else if (isImage) {
        return InkWell(
          onTap: () {
            UiUtils.showFullScreenImage(context,
                provider: NetworkImage(value[0]));
          },
          child: Container(
            padding: contentPadding,
            decoration: BoxDecoration(
              color: buttonColor ?? context.color.territoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(chipRadius),
            ),
            child: Text(
              "عرض الصورة",
              style: TextStyle(
                color: textColor ?? context.color.textColorDark,
                fontWeight: FontWeight.w600,
                fontSize: responsiveFont,
              ),
            ),
          ),
        );
      }
    }

    return Text(
      sanitizedValues.isEmpty
          ? value.length == 1
              ? value[0].toString()
              : value.join(' , ')
          : sanitizedValues.length == 1
              ? sanitizedValues.first
              : sanitizedValues.join('، '),
        );
        }
}









