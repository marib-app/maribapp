// lib/ui/screens/item/owner_view.dart
import 'package:flutter/material.dart';

import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';

// أجزاء من شاشة التفاصيل العامة التي سنعيد استخدامها
import 'package:marib/ui/screens/item/ad_details_screen/AdImagesHeader.dart';
import 'package:marib/ui/screens/item/ad_details_screen/AdInfoSection.dart';
import 'package:marib/ui/screens/item/ad_details_screen/Description.dart';
import 'package:marib/ui/screens/item/ad_details_screen/Custom_Fields_Widget.dart';
import 'package:marib/ui/screens/item/ad_details_screen/map_preview_box.dart';
import 'package:marib/ui/screens/item/ad_details_screen/bottom_buttons.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart'
    show CustomFieldBuilder;

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

// ==============================
// شريحة إضافات المالك (مثلاً: تمييز الإعلان)
// ==============================
class OwnerExtrasSection extends StatelessWidget {
  final Widget? featuredSection;
  final EdgeInsetsGeometry padding;
  const OwnerExtrasSection({
    super.key,
    this.featuredSection,
    this.padding = const EdgeInsets.symmetric(vertical: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    if (featuredSection == null) return const SizedBox.shrink();
    return Padding(padding: padding, child: featuredSection!);
  }
}

// ==============================
// شريحة إحصاء صغيرة
// ==============================
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatChip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }
}

// ==============================
// الصف العلوي: إحصائيات + قائمة خيارات المالك
// ==============================

class OwnerStatsActions extends StatelessWidget {
  final ItemModel model;
  final int? views; // إجمالي المشاهدات
  final int? likes; // إجمالي الإعجابات
  final bool isActive; // حالة الإعلان

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onShare;

  const OwnerStatsActions({
    super.key,
    required this.model,
    required this.isActive,
    this.views,
    this.likes,
    this.onEdit,
    this.onDelete,
    this.onToggleStatus,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
      child: Row(
        children: [
          _StatChip(
              icon: Icons.remove_red_eye_rounded,
              text: (views ?? 0).toString()),
          const SizedBox(width: 8),
          _StatChip(
              icon: Icons.favorite_rounded, text: (likes ?? 0).toString()),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'خيارات',
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  if (onEdit != null) onEdit!();
                  break;
                case 'delete':
                  if (onDelete != null) onDelete!();
                  break;
                case 'toggle':
                  if (onToggleStatus != null) onToggleStatus!();
                  break;
                case 'share':
                  if (onShare != null) onShare!();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                      leading: Icon(Icons.edit), title: Text('تعديل الإعلان'))),
              const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('حذف الإعلان'))),
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  leading: Icon(isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline),
                  title: Text(isActive ? 'إيقاف مؤقت' : 'تفعيل'),
                ),
              ),
              const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                      leading: Icon(Icons.share), title: Text('مشاركة'))),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(.2)),
              ),
              child: Row(children: [
                Text('خيارات', style: text.bodyMedium),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more, size: 18),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// الـ Bottom bar الخاص بالمالك
// ==============================

class OwnerViewBar extends StatelessWidget {
  final ItemModel model;
  final List<CustomFieldBuilder> moreDetailDynamicFields;
  final VoidCallback onRenewPressed;
  final bool isBusy;

  /// هل الإعلان مضاف بواسطتي؟ يأتي من الشاشة الأب
  final bool isAddedByMe;

  /// كولباك لتحديث moreDetailDynamicFields في الشاشة الأب (Stateful)
  final void Function(List<CustomFieldBuilder>) onUpdateFields;

  final Future<bool> Function()? onPausePressed;
  final Future<bool> Function()? onResumePressed;

  const OwnerViewBar({
    super.key,
    required this.model,
    required this.moreDetailDynamicFields,
    required this.onRenewPressed,
    this.isBusy = false,
    required this.isAddedByMe, // ✅ أضفناه كـ required
    required this.onUpdateFields, // ✅ موجود ومطلوب

    this.onPausePressed,
    this.onResumePressed,
  });

  @override
  Widget build(BuildContext context) {
    // ⚠️ لا نستخدم Padding خارجي هنا حتى ما يسبب فراغ على الأطراف

    final bar = bottomButtonWidget(
      context: context,
      model: model,
      isAddedByMe: isAddedByMe,
      moreDetailDynamicFields: moreDetailDynamicFields,
      onRenewPressed: onRenewPressed,
      onUpdateFields: onUpdateFields,
      // 👇 مهم لتمرير منطق الإيقاف/الاستئناف للأسفل
      onPausePressed: onPausePressed,
      onResumePressed: onResumePressed,
    );

    return SafeArea(
      // خليه يغطي العرض كامل، بدون حواف جانبية
      left: false,
      right: false,
      bottom: true,
      top: false,
      child: isBusy
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SizedBox(
                height: 46,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          : bar,
    );
  }
}

// ==============================
// الجسم الكامل لواجهة المالك
// ==============================
class OwnerAdDetailsBody extends StatelessWidget {
  final void Function(String key, dynamic value) addCloudDataFn; // 👈 جديد

  final ItemModel model;
  final List<String?> images;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  final List<dynamic> moreDetailDynamicFields; // (CustomFieldBuilder...)
  final VoidCallback onRenewPressed;
  final VoidCallback onOpenMap;

  /// ويدجت اختيارية (مثل createFeaturesAds())
  final Widget? featuredSection;

  const OwnerAdDetailsBody({
    super.key,
    required this.model,
    required this.images,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.moreDetailDynamicFields,
    required this.onRenewPressed,
    required this.onOpenMap,
    required this.addCloudDataFn, // 👈 جديد

    this.featuredSection,
  });

  @override
  Widget build(BuildContext context) {
    final adInfo =
        AdInfoSection(context: context, model: model, isAddedByMe: true);
    final views = model.views ?? 0;
    final likes = model.totalLikes ?? 0;

    // شريط الإحصائيات بعرض كامل
    Widget _statsBar(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final text = Theme.of(context).textTheme;

      Widget chip(IconData icon, String label) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withOpacity(.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label, style: text.bodyMedium),
            ],
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: LayoutBuilder(builder: (ctx, c) {
          final isNarrow = c.maxWidth < 360;
          return isNarrow
              ? Column(
                  children: [
                    SizedBox(
                        width: double.infinity,
                        child: chip(
                            Icons.remove_red_eye_rounded, views.toString())),
                    const SizedBox(height: 8),
                    SizedBox(
                        width: double.infinity,
                        child: chip(Icons.favorite_rounded, likes.toString())),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                        child: chip(
                            Icons.remove_red_eye_rounded, views.toString())),
                    const SizedBox(width: 10),
                    Expanded(
                        child: chip(Icons.favorite_rounded, likes.toString())),
                  ],
                );
        }),
      );
    }

    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // السلايدر مع تكبير عند السحب للأسفل (بدون blur)
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: MediaQuery.of(context).size.height * 0.40,
          backgroundColor: context.color.secondaryDetailsColor,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            stretchModes: const [
              StretchMode.zoomBackground,
              StretchMode.fadeTitle, // اختياري
            ],
            background: AdImageHeader(
              currentImageIndex: currentIndex,
              images: images.whereType<String>().toList(),
              pageController: pageController,
              currentIndex: currentIndex,
              onPageChanged: onPageChanged,
              isFavorite: isFavorite,
              onToggleFavorite: onToggleFavorite,
              model: model,
              isAddedByMe: true,
              safeModelId: (model.id ?? 0).toString(),
            ),
          ),
        ),

        // باقي المحتوى
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // العنوان
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(model.name ?? "Unknown Item")
                      .size(context.font.large)
                      .setMaxLines(lines: 2)
                      .color(context.color.textDefaultColor),
                ),

                // الإحصائيات بعرض كامل (بدون قائمة خيارات)
                _statsBar(context),

                // السعر + الحالة
                adInfo.priceAndStatus(),

                // سبب الرفض (إن وجد)
                if (model.rejectedReason?.isNotEmpty == true)
                  RejectedReasonCard(reason: model.rejectedReason!),

                if (model.address != null) adInfo.titleAndDate(isDate: true),

                // قسم إضافات المالك (إن وجد)
                OwnerExtrasSection(featuredSection: featuredSection),

                // الحقول المخصصة
                if (model.customFields?.isNotEmpty == true)
                  CustomFieldsWidget(
                    field: model,
                    fields: model.customFields!,
                    width: MediaQuery.of(context).size.width / 2 - 20,
                  ),

                Divider(
                    thickness: 1,
                    color: context.color.textDefaultColor.withOpacity(0.1)),
                AdDescriptionSection(description: model.description),
                Divider(
                    thickness: 1,
                    color: context.color.textDefaultColor.withOpacity(0.1)),

                // الخريطة
                if (model.latitude != null && model.longitude != null)
                  MapPreviewBox(
                    latitude: model.latitude!,
                    longitude: model.longitude!,
                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                    addressWidget: adInfo.titleAndDate(isDate: false),
                    onTap: onOpenMap,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==============================
// ويدجت سبب الرفض (تصميم أجمل)
// ==============================

class RejectedReasonCard extends StatelessWidget {
  final String reason;
  const RejectedReasonCard({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.errorContainer.withOpacity(.20),
            cs.errorContainer.withOpacity(.08),
          ],
        ),
        border: Border.all(color: cs.error.withOpacity(.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: cs.error.withOpacity(.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.report_gmailerrorred_rounded, color: cs.error),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تم رفض الإعلان',
                    style: t.titleSmall?.copyWith(
                        color: cs.error, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(reason,
                    style: t.bodyMedium
                        ?.copyWith(color: cs.onSurface.withOpacity(.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
