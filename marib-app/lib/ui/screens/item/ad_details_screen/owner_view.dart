// lib/ui/screens/item/owner_view.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';

// ط£ط¬ط²ط§ط، ظ…ظ† ط´ط§ط´ط© ط§ظ„طھظپط§طµظٹظ„ ط§ظ„ط¹ط§ظ…ط© ط§ظ„طھظٹ ط³ظ†ط¹ظٹط¯ ط§ط³طھط®ط¯ط§ظ…ظ‡ط§
import 'AdImagesHeader.dart';
import 'AdInfoSection.dart';
import 'Description.dart';
import 'Custom_Fields_Widget.dart';
import 'map_preview_box.dart';
import 'bottom_buttons.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart'
    show CustomFieldBuilder;

import 'owner_action_bar.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'AdImagesHeader.dart';
import 'AdInfoSection.dart';
import 'Description.dart';
import 'Custom_Fields_Widget.dart';
import 'Seller_Profile.dart';
import 'map_preview_box.dart';
import 'add_cart_sheet.dart';
import 'bottom_buttons.dart';
import 'owner_view.dart';
import 'AdImagesHeader.dart';
import 'ad_custom_fields.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'AdImagesHeader.dart';

import 'ad_details_screen.dart';
import 'package:marib/utils/geo_rules.dart';
import 'ad_image_source.dart';

// ==============================
// ط´ط±ظٹط­ط© ط¥ط¶ط§ظپط§طھ ط§ظ„ظ…ط§ظ„ظƒ (ظ…ط«ظ„ط§ظ‹: طھظ…ظٹظٹط² ط§ظ„ط¥ط¹ظ„ط§ظ†)
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
// ط´ط±ظٹط­ط© ط¥ط­طµط§ط، طµط؛ظٹط±ط©
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
// ط§ظ„طµظپ ط§ظ„ط¹ظ„ظˆظٹ: ط¥ط­طµط§ط¦ظٹط§طھ + ظ‚ط§ط¦ظ…ط© ط®ظٹط§ط±ط§طھ ط§ظ„ظ…ط§ظ„ظƒ
// ==============================

class OwnerStatsActions extends StatelessWidget {
  final ItemModel model;
  final int? views; // ط¥ط¬ظ…ط§ظ„ظٹ ط§ظ„ظ…ط´ط§ظ‡ط¯ط§طھ
  final int? likes; // ط¥ط¬ظ…ط§ظ„ظٹ ط§ظ„ط¥ط¹ط¬ط§ط¨ط§طھ
  final bool isActive; // ط­ط§ظ„ط© ط§ظ„ط¥ط¹ظ„ط§ظ†

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
            tooltip: 'ط®ظٹط§ط±ط§طھ',
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
                      leading: Icon(Icons.edit), title: Text('طھط¹ط¯ظٹظ„ ط§ظ„ط¥ط¹ظ„ط§ظ†'))),
              const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('ط­ط°ظپ ط§ظ„ط¥ط¹ظ„ط§ظ†'))),
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  leading: Icon(isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline),
                  title: Text(isActive ? 'ط¥ظٹظ‚ط§ظپ ظ…ط¤ظ‚طھ' : 'طھظپط¹ظٹظ„'),
                ),
              ),
              const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                      leading: Icon(Icons.share), title: Text('ظ…ط´ط§ط±ظƒط©'))),
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
                Text('ط®ظٹط§ط±ط§طھ', style: text.bodyMedium),
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
// ط§ظ„ظ€ Bottom bar ط§ظ„ط®ط§طµ ط¨ط§ظ„ظ…ط§ظ„ظƒ
// ==============================

class OwnerViewBar extends StatelessWidget {
  final ItemModel model;
  final List<CustomFieldBuilder> moreDetailDynamicFields;
  final VoidCallback onRenewPressed;
  final bool isBusy;

  /// ظ‡ظ„ ط§ظ„ط¥ط¹ظ„ط§ظ† ظ…ط¶ط§ظپ ط¨ظˆط§ط³ط·طھظٹطں ظٹط£طھظٹ ظ…ظ† ط§ظ„ط´ط§ط´ط© ط§ظ„ط£ط¨
  final bool isAddedByMe;

  /// ظƒظˆظ„ط¨ط§ظƒ ظ„طھط­ط¯ظٹط« moreDetailDynamicFields ظپظٹ ط§ظ„ط´ط§ط´ط© ط§ظ„ط£ط¨ (Stateful)
  final void Function(List<CustomFieldBuilder>) onUpdateFields;

  final Future<bool> Function()? onPausePressed;
  final Future<void> Function()? onResumePressed;

  const OwnerViewBar({
    super.key,
    required this.model,
    required this.moreDetailDynamicFields,
    required this.onRenewPressed,
    this.isBusy = false,
    required this.isAddedByMe, // âœ… ط£ط¶ظپظ†ط§ظ‡ ظƒظ€ required
    required this.onUpdateFields, // âœ… ظ…ظˆط¬ظˆط¯ ظˆظ…ط·ظ„ظˆط¨

    this.onPausePressed,
    this.onResumePressed,
  });

  @override
  Widget build(BuildContext context) {
    // âڑ ï¸ڈ ظ„ط§ ظ†ط³طھط®ط¯ظ… Padding ط®ط§ط±ط¬ظٹ ظ‡ظ†ط§ ط­طھظ‰ ظ…ط§ ظٹط³ط¨ط¨ ظپط±ط§ط؛ ط¹ظ„ظ‰ ط§ظ„ط£ط·ط±ط§ظپ

    final bar = bottomButtonWidget(
      context: context,
      model: model,
      isAddedByMe: isAddedByMe,
      moreDetailDynamicFields: moreDetailDynamicFields,
      onRenewPressed: onRenewPressed,
      onUpdateFields: onUpdateFields,
      // ًں‘‡ ظ…ظ‡ظ… ظ„طھظ…ط±ظٹط± ظ…ظ†ط·ظ‚ ط§ظ„ط¥ظٹظ‚ط§ظپ/ط§ظ„ط§ط³طھط¦ظ†ط§ظپ ظ„ظ„ط£ط³ظپظ„
      onPausePressed: onPausePressed,
      onResumePressed: onResumePressed,
    );

    return SafeArea(
      // ط®ظ„ظٹظ‡ ظٹط؛ط·ظٹ ط§ظ„ط¹ط±ط¶ ظƒط§ظ…ظ„طŒ ط¨ط¯ظˆظ† ط­ظˆط§ظپ ط¬ط§ظ†ط¨ظٹط©
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
// ط§ظ„ط¬ط³ظ… ط§ظ„ظƒط§ظ…ظ„ ظ„ظˆط§ط¬ظ‡ط© ط§ظ„ظ…ط§ظ„ظƒ
// ==============================
class OwnerAdDetailsBody extends StatelessWidget {
  final void Function(String key, dynamic value) addCloudDataFn; // ًں‘ˆ ط¬ط¯ظٹط¯

  final ItemModel model;
  final List<String?> images;
  final List<AdImageSource> imageSources;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  final List<dynamic> moreDetailDynamicFields; // (CustomFieldBuilder...)
  final VoidCallback onRenewPressed;
  final VoidCallback onOpenMap;

  /// ظˆظٹط¯ط¬طھ ط§ط®طھظٹط§ط±ظٹط© (ظ…ط«ظ„ createFeaturesAds())
  final Widget? featuredSection;
  final String? videoUrl;
  final String? videoThumbnail;
  final VoidCallback? onVideoTap;
  final bool hideLocation;
  final bool supportsMapSection;

  const OwnerAdDetailsBody({
    super.key,
    required this.model,
    required this.images,
    required this.imageSources,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.moreDetailDynamicFields,
    required this.onRenewPressed,
    required this.onOpenMap,
    required this.addCloudDataFn, // ًں‘ˆ ط¬ط¯ظٹط¯
    required this.hideLocation,
    required this.supportsMapSection,
    this.featuredSection,
    this.videoUrl,
    this.videoThumbnail,
    this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    final adInfo =
        AdInfoSection(context: context, model: model, isAddedByMe: true);
    final views = model.views ?? 0;
    final likes = model.totalLikes ?? 0;

    // ط´ط±ظٹط· ط§ظ„ط¥ط­طµط§ط¦ظٹط§طھ ط¨ط¹ط±ط¶ ظƒط§ظ…ظ„
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
      slivers: [
        // ط§ظ„ط³ظ„ط§ظٹط¯ط± ظ…ط¹ طھظƒط¨ظٹط± ط¹ظ†ط¯ ط§ظ„ط³ط­ط¨ ظ„ظ„ط£ط³ظپظ„ (ط¨ط¯ظˆظ† blur)
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: MediaQuery.of(context).size.height * 0.40,
          backgroundColor: context.color.secondaryDetailsColor,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            stretchModes: const [
              StretchMode.zoomBackground,
              StretchMode.fadeTitle, // ط§ط®طھظٹط§ط±ظٹ
            ],
            background: AdImageHeader(
              currentImageIndex: currentIndex,
              images: imageSources,
              pageController: pageController,
              currentIndex: currentIndex,
              onPageChanged: onPageChanged,
              isFavorite: isFavorite,
              onToggleFavorite: onToggleFavorite,
              model: model,
              isAddedByMe: true,
              safeModelId: (model.id ?? 0).toString(),
              videoUrl: (model.videoLink ?? '').trim().isNotEmpty
                  ? model.videoLink!.trim()
                  : null,
              videoThumbnail:
                  videoThumbnail != null && videoThumbnail!.isNotEmpty
                      ? videoThumbnail
                      : null,
              onVideoTap: onVideoTap,
            ),
          ),
        ),

        // ط¨ط§ظ‚ظٹ ط§ظ„ظ…ط­طھظˆظ‰
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ط§ظ„ط¹ظ†ظˆط§ظ†
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(model.name ?? "Unknown Item")
                      .size(context.font.large)
                      .setMaxLines(lines: 2)
                      .color(context.color.textDefaultColor),
                ),

                // ط§ظ„ط¥ط­طµط§ط¦ظٹط§طھ ط¨ط¹ط±ط¶ ظƒط§ظ…ظ„ (ط¨ط¯ظˆظ† ظ‚ط§ط¦ظ…ط© ط®ظٹط§ط±ط§طھ)
                _statsBar(context),

                // ط§ظ„ط³ط¹ط± + ط§ظ„ط­ط§ظ„ط©
                adInfo.priceAndStatus(),

                // ط³ط¨ط¨ ط§ظ„ط±ظپط¶ (ط¥ظ† ظˆط¬ط¯)
                if (model.rejectedReason?.isNotEmpty == true)
                  RejectedReasonCard(reason: model.rejectedReason!),

                if (!hideLocation && model.address != null)
                  adInfo.titleAndDate(isDate: true),
                // ظ‚ط³ظ… ط¥ط¶ط§ظپط§طھ ط§ظ„ظ…ط§ظ„ظƒ (ط¥ظ† ظˆط¬ط¯)
                OwnerExtrasSection(featuredSection: featuredSection),

                // ط§ظ„ط­ظ‚ظˆظ„ ط§ظ„ظ…ط®طµطµط©
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

                // ط§ظ„ط®ط±ظٹط·ط©
                if (!hideLocation &&
                    supportsMapSection &&
                    model.latitude != null &&
                    model.longitude != null)
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
// ظˆظٹط¯ط¬طھ ط³ط¨ط¨ ط§ظ„ط±ظپط¶ (طھطµظ…ظٹظ… ط£ط¬ظ…ظ„)
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
                Text('طھظ… ط±ظپط¶ ط§ظ„ط¥ط¹ظ„ط§ظ†',
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
