// lib/ui/code_ui/user_profile/my_item_tab_ui.dart


import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:marib/utils/constant.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';
//- import 'package:marib/utils/constant.dart' as C;
import 'package:marib/utils/constant.dart' show sidePadding, defaultPadding, Constant;

import 'package:marib/data/cubits/item/fetch_my_item_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/utils/api.dart';

import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';

import 'profile_item_card.dart';
import 'package:marib/app/app_scroll_behavior.dart';
import 'package:marib/app/app_scroll_behavior.dart';


const double sidePadding = Constant.defaultPadding;
const double defaultPadding = Constant.defaultPadding;


class MyItemTabUI extends StatelessWidget {
  final FetchMyItemsState state;
  final ScrollController controller;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final void Function(ItemModel) onTapItem;
  final String storageKey; // ✅ جديد


  const MyItemTabUI({
    super.key,
    required this.state,
    required this.controller,
    required this.onRefresh,
    required this.onRetry,
    required this.onTapItem,
    required this.storageKey, // ✅ جديد

  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.color.territoryColor,
      child: _buildBody(context,
        contentMaxWidth: 820,
        contentAlignment: Alignment.topCenter,
        contentPadding: const EdgeInsets.symmetric(horizontal: 1),
        itemSpacing: 8,
      )

    );
  }


  Widget _buildBody(
      BuildContext context, {
        double? contentMaxWidth,                         // NEW
        AlignmentGeometry contentAlignment = Alignment.center, // NEW
        EdgeInsetsGeometry? contentPadding,              // NEW
        double itemSpacing = 6,                          // NEW
        ScrollPhysics? physicsOverride,                  // NEW
      }) {
    // مطاط دائمًا على كل المنصات (يمكن تجاوزه)
    final ScrollPhysics physics =
        physicsOverride ?? const AppScrollBehavior().getScrollPhysics(context);
    // غلاف موحّد للتحكم بالعرض/المحاذاة/الحشوات
    Widget wrapContent(Widget child) {
      return Align(
        alignment: contentAlignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: contentMaxWidth ?? double.infinity,
          ),
          child: Padding(
            padding: contentPadding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      );
    }

    if (state is FetchMyItemsInProgress) {
      return wrapContent(_shimmerEffect(context));
    }

    if (state is FetchMyItemsFailed) {
      final err = (state as FetchMyItemsFailed).error;
      if (_isNoInternet(err)) return wrapContent(NoInternet(onRetry: onRetry));
      return wrapContent(const SomethingWentWrong());
    }

    if (state is FetchMyItemsSuccess) {
      final s = state as FetchMyItemsSuccess;

      // لا بيانات
      if (s.items.isEmpty) {
        return ScrollConfiguration(
          behavior: const _AlwaysBouncyScrollBehavior(),
          child: CustomScrollView(
            physics: physics,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: wrapContent(
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                      child: NoDataFound(
                        mainMessage: "noAdsFound".translate(context),
                        subMessage: "noAdsAvailable".translate(context),
                        onTap: onRetry,
                        category: EmptyStateCategory.profile,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }




      // قائمة + لودر أخير
      final int itemCount = s.items.length + (s.isLoadingMore ? 1 : 0);

      return ScrollConfiguration(
        behavior: const _AlwaysBouncyScrollBehavior(),
        child: Scrollbar(
          controller: controller,
          child: wrapContent(


              ListView.builder(
                key: PageStorageKey(storageKey),           // ✅ مفتاح ديناميكي لكل تبويب
                controller: controller,
                primary: false,                             // ✅ مهم مع NestedScrollView
                physics: physics,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(vertical: 4),
                cacheExtent: 600,                           // ✅ سلاسة تمرير أفضل
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  // اللودر الأخير
                  if (index == s.items.length) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: itemSpacing * 2 / 1.5),
                      child: Center(child: UiUtils.progress()),
                    );
                  }

                  final item = s.items[index];

                  // ملاحظة: بما أنك ركّبت الشارة الجديدة داخل ProfileItemCard، ما نضيف أي شارة هنا
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ProfileItemCard(
                      item: item,
                      onTap: () => onTapItem(item),
                      // additionalHeight: 6,
                      // additionalImageWidth: 12,
                    ),
                  );
                },
              )



          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }


  // ===== Helpers =====
  bool _isNoInternet(Object e) {
    // ✅ يدعم اختلاف أسماء الحقول داخل ApiException
    try {
      final d = e as dynamic;
      final v = d.error ?? d.code ?? d.type ?? d.message;
      if (v is String) {
        final s = v.toLowerCase();
        if (s == 'no-internet' || s.contains('no internet')) return true;
      }
    } catch (_) {}
    return e.toString().toLowerCase().contains('no-internet');
  }


  // ===== شيمر =====

  Widget _shimmerEffect(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        vertical: 10 + defaultPadding,
        horizontal: defaultPadding,
      ),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(15)),
                child: CustomShimmer(height: 90, width: 90),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ShimmerLines(),
              ),
            ],
          ),
        );
      },
    );
  }
}




// فصل صغير لهيكل سطور الشيمر
class _ShimmerLines extends StatelessWidget {
  const _ShimmerLines();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          CustomShimmer(height: 10, width: c.maxWidth - 50),
          const SizedBox(height: 10),
          const CustomShimmer(height: 10),
          const SizedBox(height: 10),
          CustomShimmer(height: 10, width: c.maxWidth / 1.2),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: CustomShimmer(width: c.maxWidth / 4),
          ),
        ],
      ),
    );
  }
}


class _AlwaysBouncyScrollBehavior extends ScrollBehavior {
  const _AlwaysBouncyScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      AppScrollBehavior.defaultPhysics;
  // إلغاء وميض التوهّج الأزرق/البرتقالي
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}




// === Status helpers (مطابقة لتفاصيل الإعلان، مختصرة) ===
String _normalizeStatus(String? raw) {
  final s = (raw ?? '').trim().toLowerCase();
  if (s.isEmpty) return 'review';
  if (['approved','active','published','enabled'].contains(s)) return 'approved';
  if (['inactive','paused','disabled'].contains(s)) return 'inactive';
  if (['rejected','declined'].contains(s)) return 'rejected';
  if (['sold out','sold','completed'].contains(s)) return 'sold out';
  if (['review','pending','under_review','inreview'].contains(s)) return 'review';
  return s;
}

class _StatusStyle {
  final Color bg, fg, border;
  final IconData icon;
  final String label;
  const _StatusStyle({required this.bg,required this.fg,required this.border,required this.icon,required this.label});
}

Map<String, _StatusStyle> _statusStyles(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return {
    'review': _StatusStyle(
      bg: Colors.blue.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
      border: Colors.blue.withOpacity(.35),
      icon: Icons.hourglass_top_rounded,
      label: "قيد المراجعة",
    ),
    'approved': _StatusStyle(
      bg: Colors.green.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.green.shade100 : Colors.green.shade900,
      border: Colors.green.withOpacity(.35),
      icon: Icons.verified_rounded,
      label: "مفعل",
    ),
    'inactive': _StatusStyle(
      bg: Colors.grey.withOpacity(isDark ? .30 : .18),
      fg: isDark ? Colors.grey.shade100 : Colors.grey.shade900,
      border: Colors.grey.withOpacity(.35),
      icon: Icons.pause_circle_filled_rounded,
      label: "موقّت",
    ),
    'rejected': _StatusStyle(
      bg: Colors.red.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.red.shade100 : Colors.red.shade900,
      border: Colors.red.withOpacity(.40),
      icon: Icons.block_rounded,
      label: "مرفوض",
    ),
    'sold out': _StatusStyle(
      bg: Colors.amber.withOpacity(isDark ? .28 : .18),
      fg: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
      border: Colors.amber.withOpacity(.35),
      icon: Icons.sell_rounded,
      label: "تم البيع",
    ),
  };
}

class _StatusChipSmall extends StatelessWidget {
  final String? rawStatus;
  final bool dense;
  const _StatusChipSmall({required this.rawStatus, this.dense = true});

  @override
  Widget build(BuildContext context) {
    final norm = _normalizeStatus(rawStatus);
    final st = _statusStyles(context)[norm] ?? _statusStyles(context)['review']!;
    final padH = dense ? 10.0 : 12.0;
    final padV = dense ? 6.0 : 8.0;
    return IgnorePointer(
      ignoring: true, // ما يمنع الضغط على البطاقة
      child: Semantics(
        label: 'حالة الإعلان: ${st.label}',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: st.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: st.border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(st.icon, size: dense ? 14 : 16, color: st.fg),
              const SizedBox(width: 6),
              Text(st.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: st.fg, fontWeight: FontWeight.w600, fontSize: dense ? 12 : 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
