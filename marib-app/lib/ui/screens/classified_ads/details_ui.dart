// lib/ui/screens/classified_ads/details_ui.dart
// واجهة العرض فقط — بدون منطق. مطابق للشكل السابق 1:1.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/utils/app_icon.dart';

import 'package:marib/ui/screens/classified_ads/app_html.dart';

class ClassifiedDetailsUI extends StatelessWidget {
  // ===== الحالة والبيانات المعروضة =====
  final bool loading;

  final String appBarTitle;

  final bool hasImage;
  final String? imageUrl;

  final String html;
  final String? dateLine;

  final String ratingText;

  final bool directiveHidden;
  final String buttonTitle;

  final bool fabVisible;
  final bool isReporting;
  final Widget? ownerPanel;

  // ===== ردود الأفعال (callbacks) =====
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onReportTap;
  final VoidCallback? onRateTap;

  /// ✅ مطلوب وغير قابل لأن يكون null لإرضاء onPressed
  final VoidCallback onContinueTap;

  /// يٌستدعى عند تغيّر رؤية زر المشاركة بحسب اتجاه التمرير
  final void Function(bool visible)? onFabVisibilityChange;

  const ClassifiedDetailsUI({
    super.key,
    // حالة
    required this.loading,
    required this.appBarTitle,
    required this.hasImage,
    required this.imageUrl,
    required this.html,
    required this.dateLine,
    required this.ratingText,
    required this.directiveHidden,
    required this.buttonTitle,
    required this.fabVisible,
    required this.isReporting,
    // أفعال
    this.onBack,
    this.onShare,
    this.onReportTap,
    this.onRateTap,
    required this.onContinueTap,
    this.onFabVisibilityChange,
    this.ownerPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.primaryColor,

      // AppBar — زر رجوع بالشكل السابق (UiUtils + AppIcons) وسلوك سلس
      appBar: AppBar(
        backgroundColor: context.color.primaryColor,
        elevation: 0,
        leading: Material(
          clipBehavior: Clip.antiAlias,
          color: Colors.transparent,
          type: MaterialType.circle,
          child: InkWell(
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 15),
              child: Directionality(
                textDirection: Directionality.of(context),
                child: RotatedBox(
                  quarterTurns:
                      Directionality.of(context) == TextDirection.rtl ? 2 : -4,
                  child: UiUtils.getSvg(
                    AppIcons.arrowLeft,
                    fit: BoxFit.none,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          appBarTitle,
          style: TextStyle(color: context.color.textDefaultColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),

      // BottomNavigationBar — شيمر أثناء التحميل، أو زر "متابعة" حسب directive
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
                      onPressed: onContinueTap, // غير قابلة لـ null الآن
                    ),
                  ),
                )),

      // Body
      body: loading
          ? _LoadingBody()
          : _LoadedBody(
              hasImage: hasImage,
              imageUrl: imageUrl,
              html: html,
              dateLine: dateLine,
              ratingText: ratingText,
              isReporting: isReporting,
              onReportTap: onReportTap,
              onRateTap: onRateTap,
              onShare: onShare,
              fabVisible: fabVisible,
              onFabVisibilityChange: onFabVisibilityChange,
              ownerPanel: ownerPanel,
            ),
    );
  }
}

// ===============================
// شيمر أثناء التحميل (مطابق للشكل)
// ===============================
class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100), // مساحة للـ FAB
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // صورة البانر (شيمر) — نفس مقاس السلايدر 395/150
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 395 / 150,
                child: const CustomShimmer(
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // شيمر لأزرار (إبلاغ + تقييم)
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    height: 42,
                    child: CustomShimmer(
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    height: 42,
                    child: CustomShimmer(
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // شيمر لسطر التاريخ
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const SizedBox(
              width: 220,
              height: 12,
              child: CustomShimmer(width: 220, height: 12),
            ),
          ),
          const SizedBox(height: 12),

          // شيمر لفقرات النص
          for (int i = 0; i < 6; i++) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: const SizedBox(
                width: double.infinity,
                height: 12,
                child: CustomShimmer(width: double.infinity, height: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ===============================
// الجسم بعد التحميل
// ===============================
class _LoadedBody extends StatelessWidget {
  final bool hasImage;
  final String? imageUrl;

  final String html;
  final String? dateLine;

  final String ratingText;

  final bool isReporting;

  final VoidCallback? onReportTap;
  final VoidCallback? onRateTap;

  final VoidCallback? onShare;

  final bool fabVisible;
  final void Function(bool visible)? onFabVisibilityChange;
  final Widget? ownerPanel;

  const _LoadedBody({
    required this.hasImage,
    required this.imageUrl,
    required this.html,
    required this.dateLine,
    required this.ratingText,
    required this.isReporting,
    required this.onReportTap,
    required this.onRateTap,
    required this.onShare,
    required this.fabVisible,
    required this.onFabVisibilityChange,
    required this.ownerPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // إخفاء/إظهار زر المشاركة العائم عند التمرير
        NotificationListener<UserScrollNotification>(
          onNotification: (n) {
            if (n.direction == ScrollDirection.reverse && fabVisible) {
              onFabVisibilityChange?.call(false);
            } else if (n.direction == ScrollDirection.forward && !fabVisible) {
              onFabVisibilityChange?.call(true);
            }
            return false;
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(12, 12, 12, 100), // مساحة للـ FAB
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage && (imageUrl ?? '').isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 390 / 150,
                        child: UiUtils.getImage(
                          imageUrl!,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // أزرار تحت الصورة: إبلاغ + تقييم
                Row(
                  children: [
                    Expanded(
                      child: _ReportButton(
                        isReporting: isReporting,
                        onTap: onReportTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PillButton(
                        icon: Icons.star_rounded,
                        label: ratingText,
                        emphasize: true,
                        onTap: onRateTap,
                      ),
                    ),
                  ],
                ),

                if (ownerPanel != null) ...[
                  const SizedBox(height: 12),
                  ownerPanel!,
                ],

                const SizedBox(height: 10),

                // التاريخ فقط
                if (dateLine != null)
                  Text(dateLine!)
                      .size(context.font.smaller)
                      .color(context.color.textColorDark.withOpacity(0.55)),

                const SizedBox(height: 12),

                // الوصف HTML
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

        // زر مشاركة عائم (يسار) يختفي بالتمرير
        Positioned(
          left: 20,
          bottom: 24,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            offset: fabVisible ? Offset.zero : const Offset(0, 1.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: fabVisible ? 1 : 0,
              child: FloatingActionButton(
                heroTag: 'share_fab',
                onPressed: onShare,
                backgroundColor: context.color.secondaryColor.withOpacity(0.9),
                foregroundColor: context.color.textDefaultColor,
                child: const Icon(Icons.share),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===============================
// زر الإبلاغ (Stack مع مؤشر تحميل صغير)
// ===============================
class _ReportButton extends StatelessWidget {
  final bool isReporting;
  final VoidCallback? onTap;

  const _ReportButton({
    required this.isReporting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final btn = _PillButton(
      icon: Icons.flag_rounded,
      label: 'إبلاغ',
      enabled: !isReporting,
      onTap: isReporting ? null : onTap,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        btn,
        if (isReporting)
          const IgnorePointer(
            ignoring: true,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

// ===============================
// زر Pills مساعد (يحافظ على ستايلك)
// ===============================
class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool emphasize;

  const _PillButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(12);
    final bg =
        context.color.secondaryColor.withOpacity(emphasize ? 0.20 : 0.14);
    final borderColor = emphasize
        ? context.color.textColorDark.withOpacity(0.20)
        : Colors.transparent;

    final child = Container(
      height: 42,
      decoration: BoxDecoration(
        color: enabled ? bg : bg.withOpacity(0.6),
        borderRadius: br,
        border: Border.all(color: borderColor, width: emphasize ? 1 : 0),
        boxShadow: [
          if (emphasize)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: enabled
                ? context.color.textColorDark.withOpacity(0.85)
                : context.color.textColorDark.withOpacity(0.35),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: context.font.normal,
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
                color: enabled
                    ? context.color.textColorDark
                    : context.color.textColorDark.withOpacity(0.45),
              ),
            ),
          ),
        ],
      ),
    );

    if (!enabled || onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: br,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
