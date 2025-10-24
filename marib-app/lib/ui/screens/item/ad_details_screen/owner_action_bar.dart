// lib/ui/new_code/section/Computers/ads_files/owner_action_bar.dart
// UI فقط: شريط أزرار المالك بأسلوب سكرول أفقي (بدون منطق/توجيهات/Dialogs).
// ظهور كل زر يعتمد على تمرير Callback غير null.
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/delete_item_cubit.dart';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/chat/chat_screen.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/hive_utils.dart';

import 'dart:ui';

import 'fullscreen_gallery.dart';

import 'package:flutter/material.dart';
import 'package:marib/data/model/item/item_model.dart';

// lib/ui/new_code/section/Computers/ads_files/owner_action_bar.dart
import 'package:flutter/material.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/item_category_ids.dart';

class OwnerActionBar extends StatelessWidget {
  const OwnerActionBar({
    super.key,
    required this.model,
    // مرّر أي Callback لتفعيل زرّه (اتركه null ليختفي)
    this.onEdit,
    this.onPromote,
    this.onPause,
    this.onResume,
    this.onMarkSold,
    this.onUnmarkSold,
    this.onRenew,
    this.onOpenStats,
    this.onCopyLink,
    this.onDelete,

    /// سهم المشاركة: أعِد "slug أو id كسلسلة"
    this.buildShareSlug,

    /// لو الإعلان مميز بالفعل نخفي زر "تمييز"
    this.isFeatured,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.spacing = 8,
    this.useCard = true,
    this.routes = const OwnerActionRoutes(),
    this.promotePackages = '/subscription-packages',
    this.stats, // التمييز

    this.onPausePressed,
    this.onResumePressed,
  });

  final ItemModel model;

  final VoidCallback? onEdit;
  final VoidCallback? onPromote;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onMarkSold;
  final VoidCallback? onUnmarkSold;
  final VoidCallback? onRenew;
  final VoidCallback? onOpenStats;
  final VoidCallback? onCopyLink;
  final VoidCallback? onDelete;

  final String Function()? buildShareSlug;
  final bool? isFeatured;

  final EdgeInsetsGeometry padding;
  final double spacing;
  final bool useCard;

  final String? promotePackages; // باقات/تمييز
  final String? stats;
  final OwnerActionRoutes routes;

  final Future<bool> Function()? onPausePressed;
  final Future<void> Function()? onResumePressed;

  bool get _hasAny =>
      onEdit != null ||
      onPromote != null ||
      onPause != null ||
      onResume != null ||
      onMarkSold != null ||
      onUnmarkSold != null ||
      onRenew != null ||
      onOpenStats != null ||
      onCopyLink != null ||
      onDelete != null ||
      buildShareSlug != null;

  bool get _canShowPromote => onPromote != null && (isFeatured != true);

/*
  void _defaultPromote(BuildContext context) {
    if (routes.promotePackages != null) {
      Navigator.pushNamed(
        context,
        Routes.subscriptionPackages,
        arguments: {"item": model, "model": model},
      );

    }
  }

 */

  void _defaultPromote(BuildContext context) {
    FocusScope.of(context).unfocus();
    Navigator.of(context, rootNavigator: true).pushNamed(
      Routes.promoteAdScreen,
      arguments: {
        "model": model,
        "pricePerDay": 3000.0, // عدّلها براحتك
        "currencySymbol": CurrencyUtils.preferredDisplayFor('YER') ?? 'ر.ي', // أو Constant.currencySymbol
        "minDays": 1,
        "maxDays": 30,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAny) return const SizedBox.shrink();

    final row = Row(
      textDirection: TextDirection.rtl,
      children: [
        _ActionBtn(
          icon: Icons.edit_outlined,
          label: 'تعديل',
          onPressed: onEdit ??
              () {
                FocusScope.of(context).unfocus();
                final categoryIds = buildItemCategoryIds(model);

                Navigator.of(context, rootNavigator: true).pushNamed(
                  Routes.addMoreDetailsScreen,
                  arguments: {
                    "isEdit": true,
                    "model": model, // 👈 مهم
                    "item": model, // 👈 احتياطي للتوافق القديم
                    "id": model.id, // اختياري
                    "categoryId": model.categoryId, // اختياري
                    "breadCrumbItems": null,
                    "categoryIds": categoryIds.isEmpty ? null : categoryIds,
                  },
                );
              },
        ),
        const SizedBox(width: 8),
        if (_canShowPromote)
          _ActionBtn(
            icon: Icons.local_fire_department_outlined,
            label: 'تمييز',
            onPressed: onPromote ??
                () {
                  Navigator.pushNamed(
                    context,
                    Routes.promoteAdScreen, // 👈 مسار جديد
                    arguments: {"model": model},
                  );
                },
          ),
        if (_canShowPromote) const SizedBox(width: 8),
        if (onPause != null)
          _ActionBtn(
              icon: Icons.pause_circle_outline,
              label: 'إيقاف',
              onPressed: () {
                onPause!.call();
              }),
        if (onPause != null) SizedBox(width: spacing),
        if (onResume != null)
          _ActionBtn(
            icon: Icons.rate_review_outlined,
            label: 'مراجعة قبل النشر',
            onPressed: () {
              onResume!.call();
            },
          ),
        if (onResume != null) SizedBox(width: spacing),
        if (onMarkSold != null)
          _ActionBtn(
              icon: Icons.check_circle_outline,
              label: 'وسم مباع',
              onPressed: () {
                onMarkSold!.call();
              }),
        if (onMarkSold != null) SizedBox(width: spacing),
        if (onUnmarkSold != null)
          _ActionBtn(
              icon: Icons.undo,
              label: 'إلغاء مباع',
              onPressed: () {
                onUnmarkSold!.call();
              }),
        if (onUnmarkSold != null) SizedBox(width: spacing),
        if (onRenew != null)
          _ActionBtn(
              icon: Icons.update,
              label: 'تجديد',
              onPressed: () {
                onRenew!.call();
              }),
        if (onRenew != null) SizedBox(width: spacing),
        if (buildShareSlug != null)
          _ActionBtn(
            icon: Icons.share_outlined,
            label: 'مشاركة',
            onPressed: () async {
              final slug = buildShareSlug!.call();
              await HelperUtils.share(context, slug, model: model);
            },
          ),
        if (buildShareSlug != null) SizedBox(width: spacing),
        if (onDelete != null)
          _ActionBtn(
              icon: Icons.delete_outline,
              label: 'حذف',
              destructive: true,
              onPressed: () {
                onDelete!.call();
              }),
      ],
    );

    if (!useCard) {
      return Padding(
        padding: padding,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: row,
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: padding,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: row,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    this.onPressed,
    this.destructive = false,

    // تحسينات اختيارية
    this.isBusy = false,
    this.tooltip,
    this.onLongPress,
    this.confirmBeforeAction, // يُستدعى قبل onPressed لو غير null
    this.height = 46,
    this.radius = 14,
    this.iconSize = 20,
    this.horizontalPadding = 16,
    this.enableHaptics = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  // extras
  final bool isBusy;
  final String? tooltip;
  final VoidCallback? onLongPress;
  final Future<bool> Function(BuildContext context)? confirmBeforeAction;
  final double height;
  final double radius;
  final double iconSize;
  final double horizontalPadding;
  final bool enableHaptics;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = isBusy || onPressed == null;

    Future<void> _handleTap() async {
      if (disabled) return;
      if (enableHaptics) {
        // هزّة خفيفة
        Feedback.forTap(context);
      }
      if (confirmBeforeAction != null) {
        final ok = await confirmBeforeAction!(context);
        if (!ok) return;
      }
      onPressed?.call();
    }

    Color _bg(Set<MaterialState> states) {
      if (destructive) {
        if (states.contains(MaterialState.disabled))
          return cs.errorContainer.withOpacity(.6);
        if (states.contains(MaterialState.pressed))
          return cs.error.withOpacity(.95);
        return cs.errorContainer;
      } else {
        if (states.contains(MaterialState.disabled))
          return cs.primaryContainer.withOpacity(.4);
        if (states.contains(MaterialState.pressed))
          return cs.primary.withOpacity(.95);
        return cs.primaryContainer;
      }
    }

    Color _fg(Set<MaterialState> states) {
      if (destructive) return cs.onErrorContainer;
      return cs.onPrimaryContainer;
    }

    final button = ElevatedButton(
      onPressed: disabled ? null : _handleTap,
      onLongPress: disabled ? null : onLongPress,
      style: ButtonStyle(
        elevation: const MaterialStatePropertyAll(0),
        minimumSize: MaterialStatePropertyAll(Size(0, height)),
        padding: MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: horizontalPadding)),
        backgroundColor: MaterialStateProperty.resolveWith(_bg),
        foregroundColor: MaterialStateProperty.resolveWith(_fg),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: isBusy
            ? SizedBox(
                key: const ValueKey('busy'),
                width: iconSize,
                height: iconSize,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                key: const ValueKey('content'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: iconSize),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );

    final wrapped = Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child:
          tooltip != null ? Tooltip(message: tooltip!, child: button) : button,
    );

    return wrapped;
  }
}

class OwnerActionRoutes {
  final String? editItem;
  final String? promotePackages;
  final String? stats;

  const OwnerActionRoutes({
    this.editItem = '/edit-item',
    this.promotePackages = '/subscription-packages',
    this.stats = '/ad-stats',
  });
}
