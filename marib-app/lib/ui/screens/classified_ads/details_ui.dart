// lib/ui/screens/classified_ads/details_ui.dart
// ????? ????? ??? ? ???? ????. ????? ????? ?????? 1:1.

import 'package:flutter/material.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/utils/app_icon.dart';

import 'app_html.dart';

class ClassifiedDetailsUI extends StatelessWidget {
  // ===== ?????? ????????? ???????? =====
  final bool loading;

  final String appBarTitle;

  final bool hasImage;
  final String? imageUrl;

  final String html;
  final String? dateLine;

  final String ratingText;
  final double? ratingValue;
  final int? ratingCount;
  final int? viewsCount;

  final bool directiveHidden;
  final String buttonTitle;

  final bool chatRedirectEnabled;
  final bool isReporting;
  final Widget? ownerPanel;
  final VoidCallback? onChatTap;

  // ===== ???? ??????? (callbacks) =====
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onReportTap;
  final VoidCallback? onRateTap;

  /// ? ????? ???? ???? ??? ???? null ?????? onPressed
  final VoidCallback onContinueTap;

  const ClassifiedDetailsUI({
    super.key,
    // ????
    required this.loading,
    required this.appBarTitle,
    required this.hasImage,
    required this.imageUrl,
    required this.html,
    required this.dateLine,
    required this.ratingText,
    this.ratingValue,
    this.ratingCount,
    this.viewsCount,
    required this.directiveHidden,
    required this.buttonTitle,
    this.chatRedirectEnabled = false,
    required this.isReporting,
    // ?????
    this.onBack,
    this.onShare,
    this.onReportTap,
    this.onRateTap,
    required this.onContinueTap,
    this.onChatTap,
    this.ownerPanel,
  });

  @override
  Widget build(BuildContext context) {
    final bool extendBehindAppBar =
        !loading && hasImage && (imageUrl ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: context.color.primaryColor,

      extendBodyBehindAppBar: extendBehindAppBar,

      // AppBar مخفي أثناء الشيمر (نكتفي بالهيدر داخل الـ Sliver بعد التحميل)
      appBar: null,

      // BottomNavigationBar ? ???? ????? ??????? ?? ?? "??????" ??? directive
      bottomNavigationBar: loading
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    height: 54,
                    child: CustomShimmer(
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
            )
          : (directiveHidden
              ? const SizedBox.shrink()
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: UiUtils.buildButton(
                      context,
                      buttonTitle: buttonTitle,
                      radius: 12,
                      height: 54,
                      onPressed: onContinueTap, // ??? ????? ?? null ????
                    ),
                  ),
                )),

      // Body
      body: loading
          ? _LoadingBody()
          : _LoadedBody(
              appBarTitle: appBarTitle,
              onBack: onBack,
              hasImage: hasImage,
              imageUrl: imageUrl,
              html: html,
              dateLine: dateLine,
              ratingText: ratingText,
              ratingValue: ratingValue,
              ratingCount: ratingCount,
              viewsCount: viewsCount,
              isReporting: isReporting,
              onReportTap: onReportTap,
              onRateTap: onRateTap,
              onShare: onShare,
              chatRedirectEnabled: chatRedirectEnabled,
              onChatTap: onChatTap,
              ownerPanel: ownerPanel,
            ),
    );
  }
}

// ===============================
// ???? ????? ??????? (????? ?????)
// ===============================
class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final double screenH = MediaQuery.of(context).size.height;
    final double heroH = (screenH * 0.40).clamp(180, 320);
    const widths = [0.95, 0.88, 0.92, 0.6, 0.75];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 110), // ????? ??? ??????? ???????
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: heroH,
              child: const CustomShimmer(
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: const SizedBox(
                      height: 62,
                      child: CustomShimmer(
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const SizedBox(
              width: 180,
              height: 12,
              child: CustomShimmer(width: 180, height: 12),
            ),
          ),
          const SizedBox(height: 18),
          ...List.generate(5, (i) {
            final double w = i < widths.length ? widths[i] : widths.last;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * w,
                  height: 12,
                  child: const CustomShimmer(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
class _LoadedBody extends StatelessWidget {
  final String appBarTitle;
  final VoidCallback? onBack;
  final bool hasImage;
  final String? imageUrl;
  final String html;
  final String? dateLine;

  final String ratingText;
  final double? ratingValue;
  final int? ratingCount;
  final int? viewsCount;

  final bool isReporting;

  final VoidCallback? onReportTap;
  final VoidCallback? onRateTap;

  final VoidCallback? onShare;
  final VoidCallback? onChatTap;
  final bool chatRedirectEnabled;
  final Widget? ownerPanel;

  const _LoadedBody({
    required this.appBarTitle,
    required this.onBack,
    required this.hasImage,
    required this.imageUrl,
    required this.html,
    required this.dateLine,
    required this.ratingText,
    this.ratingValue,
    this.ratingCount,
    this.viewsCount,
    required this.isReporting,
    required this.onReportTap,
    required this.onRateTap,
    required this.onShare,
    required this.chatRedirectEnabled,
    required this.onChatTap,
    required this.ownerPanel,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final String ratingLabel = ratingText;
    final String? ratingSubtitle = (ratingValue != null || ratingCount != null)
        ? '${(ratingValue ?? 0).toStringAsFixed(1)}${ratingCount != null ? ' (${ratingCount}${isRtl ? ' تقييم' : ' reviews'})' : ''}'
        : null;
    final String viewsText = viewsCount != null ? viewsCount.toString() : '0';
    final String viewsLabel = isRtl ? 'الزيارات' : 'Views';
    final String reportLabel = isRtl ? 'إبلاغ' : 'Report';
    final String reportValue =
        isRtl ? 'الإبلاغ عن الخدمة' : 'Report service';
    final String ratingFallback =
        isRtl ? 'لا يوجد تقييم' : 'No rating yet';

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            _HeaderSliver(
              title: appBarTitle,
              onBack: onBack,
              hasImage: hasImage && (imageUrl ?? '').isNotEmpty,
              imageUrl: imageUrl,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 120),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // شريط البيانات المختصرة (تقييم - زيارات - إبلاغ)
                    Row(
                      children: [
                        Expanded(
                          child: _MetaBadge(
                            icon: Icons.star_rounded,
                            label: ratingLabel,
                            value: ratingSubtitle ?? ratingFallback,
                            onTap: onRateTap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetaBadge(
                            icon: Icons.remove_red_eye_outlined,
                            label: viewsLabel,
                            value: viewsText,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetaBadge(
                            icon: Icons.flag_rounded,
                            label: reportLabel,
                            value: reportValue,
                            busy: isReporting,
                            onTap: isReporting ? null : onReportTap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (ownerPanel != null) ...[
                      const SizedBox(height: 12),
                      ownerPanel!,
                    ],

                    const SizedBox(height: 12),

                    // السطر التعريفي
                    if (dateLine != null)
                      Text(dateLine!)
                          .size(context.font.smaller)
                          .color(context.color.textColorDark.withOpacity(0.55)),

                    const SizedBox(height: 12),

                    // نص HTML
                    AppHtml(
                      data: html,
                      baseUrl: null,
                      centerContent: true,
                      maxWidth: 720,
                      preserveInlineStyles: true,
                      selectable: true,
                      outerPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 1),
                  ],
                ),
              ),
            ),
          ],
        ),

        // أزرار عائمة (مشاركة) وأخرى ثانوية
        Positioned(
          left: 20,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            verticalDirection: VerticalDirection.up,
            children: [
              FloatingActionButton(
                heroTag: 'share_fab',
                onPressed: onShare,
                backgroundColor: context.color.secondaryColor.withOpacity(0.9),
                foregroundColor: context.color.textDefaultColor,
                child: const Icon(Icons.share),
              ),
              if (chatRedirectEnabled && onChatTap != null) ...[
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'chat_fab',
                  onPressed: onChatTap,
                  backgroundColor:
                      context.color.secondaryColor.withOpacity(0.9),
                  foregroundColor: context.color.textDefaultColor,
                  child: const Icon(Icons.chat_rounded),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderSliver extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final bool hasImage;
  final String? imageUrl;

  const _HeaderSliver({
    required this.title,
    required this.onBack,
    required this.hasImage,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = context.color.textDefaultColor;
    final expandedHeight = hasImage
        ? MediaQuery.of(context).size.height * 0.40
        : kToolbarHeight + MediaQuery.of(context).padding.top;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      backgroundColor: context.color.primaryColor,
      elevation: 0,
      expandedHeight: expandedHeight,
      automaticallyImplyLeading: false,
      leadingWidth: 68,
      leading: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            type: MaterialType.circle,
            child: InkWell(
              onTap: onBack,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Directionality(
                  textDirection: Directionality.of(context),
                  child: RotatedBox(
                    quarterTurns:
                        Directionality.of(context) == TextDirection.rtl
                            ? 2
                            : -4,
                    child: UiUtils.getSvg(
                      AppIcons.arrowLeft,
                      fit: BoxFit.none,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: hasImage ? CollapseMode.parallax : CollapseMode.pin,
        titlePadding:
            const EdgeInsetsDirectional.only(start: 72, end: 16, bottom: 16),
        title: Text(
          title,
          style: TextStyle(color: textColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: hasImage
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final double dpr = MediaQuery.of(context).devicePixelRatio;
                  final double targetWidthPx =
                      (constraints.maxWidth * dpr).clamp(360, 900);
                  final double targetHeightPx =
                      (constraints.maxHeight * dpr).clamp(360, 1200);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      UiUtils.getImage(
                        imageUrl!,
                        fit: BoxFit.cover,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        cacheWidth: targetWidthPx.round(),
                        cacheHeight: targetHeightPx.round(),
                        allowHiResCache: true,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.35),
                              Colors.black.withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : null,
      ),
    );
  }
}

// ===============================
// Meta badges (compact info tiles)
// ===============================
class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool busy;
  final VoidCallback? onTap;
  final bool emphasize;

  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.value,
    this.busy = false,
    this.onTap,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(14);
    final bg = emphasize
        ? context.color.secondaryColor.withOpacity(0.16)
        : context.color.secondaryColor.withOpacity(0.10);
    final borderColor = emphasize
        ? context.color.territoryColor.withOpacity(0.35)
        : context.color.borderColor.withOpacity(0.35);
    final textColor = context.color.textColorDark;

    final tile = Container(
      height: 64,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: br,
        border: Border.all(color: borderColor),
        boxShadow: emphasize
            ? [
                BoxShadow(
                  color: context.color.territoryColor.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                )
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: context.color.territoryColor.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: context.color.territoryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font.normal,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.font.smaller,
                    color: textColor.withOpacity(0.72),
                  ),
                ),
              ],
            ),
          ),
          if (busy) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return tile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: br,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}


