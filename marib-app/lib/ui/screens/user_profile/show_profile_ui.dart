// lib/ui/screens/profile/show_profile_ui.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';

// التبويب الداخلي لقائمة الإعلانات
import 'my_item_tab.dart';

// حالات المستخدم والإحصائيات
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/cubits/profile/profile_stats_cubit.dart';
import 'package:marib/data/cubits/item/fetch_my_item_cubit.dart';

// ثيم + أدوات مساعدة
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/app/app_scroll_behavior.dart';

/// واجهة شاشة الملف الشخصي (عرض فقط) — تستقبل كل شيء عبر Params.
/// لا يوجد منطق بيانات هنا؛ أي منطق يجب أن يبقى خارج هذا الملف.


class ProfileScreenUI extends StatelessWidget {
  final TabController tabController;
  final List<Map<String, String>> adTabs;

  final VoidCallback onEditProfilePressed;
  final VoidCallback onShareProfilePressed;
  final VoidCallback onAvatarEditPressed;
  final bool isUserAuthenticated;
  final ValueNotifier<bool> fullPageLoadingNotifier;
  final VoidCallback onRequestFullRefresh;

  /// مزوّد صورة البروفايل (File/Network/SVG) من الـ State الخارجي
  final Widget Function() buildProfileImage;

  const ProfileScreenUI({
    super.key,
    required this.tabController,
    required this.adTabs,
    required this.onEditProfilePressed,
    required this.onShareProfilePressed,
    required this.onAvatarEditPressed,
    required this.isUserAuthenticated,
    required this.fullPageLoadingNotifier,
    required this.onRequestFullRefresh,
    required this.buildProfileImage,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    String normalizeStatus(String? value) {
      if (value == null || value.isEmpty) return 'all';
      return value;
    }
    void updateLoading(String statusKey, bool isLoading) {
      final String activeStatus =
      normalizeStatus(adTabs[tabController.index]["status"]);

      if (activeStatus == statusKey) {
        if (fullPageLoadingNotifier.value != isLoading) {
          fullPageLoadingNotifier.value = isLoading;
        }
        return;
      }

      if (!isLoading && fullPageLoadingNotifier.value) {
        final cubit = myAdsCubitReference[activeStatus];
        final bool activeLoading =
            cubit != null && cubit.state is FetchMyItemsInProgress;
        if (!activeLoading) {
          fullPageLoadingNotifier.value = false;
        }
      }
    }

    Widget buildContent() {
      return NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 0),
          _HeaderSection(buildProfileImage: buildProfileImage),
          const SizedBox(height: 8),
          _ProfileButtons(
            onEditProfilePressed: onEditProfilePressed,
            onShareProfilePressed: onShareProfilePressed,
          ),
          const SizedBox(height: 12),
        ],
      ),
          ),
          SliverPersistentHeader(
          pinned: true,
          floating: true,
          delegate: _StatsTabsHeaderDelegate(
          backgroundColor: backgroundColor,
          statsBuilder: (ctx) => _StatsRow(),
          tabBarBuilder: (ctx) => _ProfileTabBar(
          controller: tabController,
          adTabs: adTabs,
          ),
            ),
          ),
        ],
          body: TabBarView(
            controller: tabController,
            physics: AppScrollBehavior.defaultPhysics,
            children: adTabs.map((tab) {
              final status = tab["status"];
              final statusKey = normalizeStatus(status);
              return MyItemTab(
                getItemsWithStatus: status,
                onLoadingChanged: updateLoading,
                onFullRefreshRequested: () {
                  updateLoading(statusKey, true);
                  onRequestFullRefresh();
                },
              );
            }).toList(),
        ),
      );
    }

    return BlocBuilder<ProfileStatsCubit, ProfileStatsState>(
      builder: (context, statsState) {
        final bool statsLoading = isUserAuthenticated &&
            (statsState is ProfileStatsLoading ||
                statsState is ProfileStatsInitial);

        return ValueListenableBuilder<bool>(
          valueListenable: fullPageLoadingNotifier,
          builder: (context, adsLoading, _) {
            final bool showShimmer = statsLoading || adsLoading;

            return Stack(
              children: [
                buildContent(),
                if (showShimmer)
                  Positioned.fill(
                    child: _ProfileScreenShimmer(
                      backgroundColor: backgroundColor,
                      adTabs: adTabs,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// رأس الشاشة: صورة + اسم المستخدم.
/// تم استخدام BlocBuilder للتحديث الفوري عند تغيّر بيانات المستخدم.
class _HeaderSection extends StatelessWidget {
  final Widget Function() buildProfileImage;

  const _HeaderSection({required this.buildProfileImage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12, start: 16, end: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // إطار صورة بروفايل دائري
          Container(
            height: 84.rh(context),
            width: 84.rw(context),
            alignment: AlignmentDirectional.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: context.color.territoryColor,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: SizedBox(
                width: 76.rw(context),
                height: 76.rh(context),
                child: buildProfileImage(),
              ),
            ),
          ),
          const SizedBox(width: 18),

          // الاسم — يُعاد بناؤه تلقائيًا عند تغير حالة UserDetailsCubit
          Expanded(
            child: BlocBuilder<UserDetailsCubit, UserDetailsState>(
              buildWhen: (prev, curr) => prev.user != curr.user,
              builder: (context, state) {
                final name = state.user?.name ?? '';
                return Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                      ),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// صف الإحصائيات: (المفضلة / الإعلانات / الرسائل / التقييم)
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileStatsCubit, ProfileStatsState>(
      builder: (context, state) {
        int fav = 0, ads = 0, chats = 0;
        double rating = 0.0;

        final isReady = state is ProfileStatsSuccess;
        if (isReady) {
          final s = state as ProfileStatsSuccess;
          fav = s.totalFavorites;
          ads = s.totalAds;
          chats = s.totalChats;
          // TODO: اربط التقييم الحقيقي عند توفره من الـ API
          // rating = s.rating;
        }

        String showInt(int v) => isReady ? '$v' : '—';
        String showRating(double v) => isReady ? v.toStringAsFixed(1) : '—';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatBox(value: showInt(fav), label: "المفضلة".translate(context)),
              StatBox(
                  value: showInt(ads), label: "الإعلانات".translate(context)),
              StatBox(
                  value: showInt(chats), label: "الرسائل".translate(context)),
              StatBox(
                  value: showRating(rating),
                  label: "التقييم".translate(context)),
            ],
          ),
        );
      },
    );
  }
}

/// صندوق رقم + عنوان بسيط مع إمكانية الضغط (اختياري)
class StatBox extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const StatBox(
      {super.key, required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
    return onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: content,
            ),
          );
  }
}

/// أزرار الإجراءات (تعديل / مشاركة) مع حالات تعطيل/تحميل اختيارية.
class _ProfileButtons extends StatelessWidget {
  final VoidCallback onEditProfilePressed;
  final VoidCallback onShareProfilePressed;

  final bool isEditLoading;
  final bool isShareLoading;
  final bool editEnabled;
  final bool shareEnabled;

  const _ProfileButtons({
    required this.onEditProfilePressed,
    required this.onShareProfilePressed,
    this.isEditLoading = false,
    this.isShareLoading = false,
    this.editEnabled = true,
    this.shareEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // مقاسات متجاوبة بسيطة
    double clamp(num v, num min, num max) =>
        math.max(min.toDouble(), math.min(max.toDouble(), v.toDouble()));

    final iconSize = clamp(width * 0.04, 15, 18);
    final fontSize = clamp(width * 0.032, 11, 15);
    final hPad = clamp(width * 0.035, 10, 18);
    final vPad = clamp(width * 0.018, 8, 12);
    final minH = clamp(width * 0.105, 40, 48);

    final cs = Theme.of(context).colorScheme;

    final baseStyle = ElevatedButton.styleFrom(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outline.withOpacity(.6)),
      ),
      minimumSize: Size(0, minH), // ارتفاع موحّد ومتجاوب
    ).copyWith(
      // استخدام MaterialStateProperty لملاءمة إصدارات Flutter الأقدم
      overlayColor: MaterialStatePropertyAll(cs.primary.withOpacity(.06)),
    );

    Widget labelText(String text) => FittedBox(
          fit: BoxFit.scaleDown, // يضمن بقاء النص في سطر واحد
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(fontSize: fontSize, color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
        );

    Widget buildBtn({
      required IconData icon,
      required String text,
      required VoidCallback onPressed,
      required bool enabled,
      required bool loading,
    }) {
      final child = loading
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: iconSize, color: cs.onSurface),
                const SizedBox(width: 8),
                Flexible(child: labelText(text)),
              ],
            );

      return ElevatedButton(
        onPressed: (enabled && !loading) ? onPressed : null,
        style: baseStyle,
        child: child,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.max, // يغطي العرض كامل
        children: [
          // زر التعديل أعرض
          Expanded(
            flex: 7,
            child: Semantics(
              button: true,
              label: 'تعديل الملف الشخصي',
              child: buildBtn(
                icon: Icons.edit,
                text: "تعديل الملف الشخصي".translate(context),
                onPressed: onEditProfilePressed,
                enabled: editEnabled,
                loading: isEditLoading,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // زر المشاركة أضيق
          Expanded(
            flex: 5,
            child: Semantics(
              button: true,
              label: 'مشاركة الملف',
              child: buildBtn(
                icon: Icons.share,
                text: "مشاركة الملف".translate(context),
                onPressed: onShareProfilePressed,
                enabled: shareEnabled,
                loading: isShareLoading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// تبويبات الحالات + شارة عدّاد اختيارية لكل تبويب.
class _ProfileTabBar extends StatelessWidget {
  final TabController controller;
  final List<Map<String, String>> adTabs;

  // عدادات اختيارية (بنفس ترتيب التبويبات)
  final List<int>? counts;

  // حدث تغيير التبويب (اختياري)
  final void Function(int index)? onTap;

  static const EdgeInsets _labelPadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 4);
  static const double _extraVerticalInset = 6;
  static double get preferredHeight =>
      kTextTabBarHeight + _labelPadding.vertical + _extraVerticalInset;

  const _ProfileTabBar({
    required this.controller,
    required this.adTabs,
    this.counts,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme.labelLarge ??
        theme.textTheme.bodyLarge ??
        const TextStyle(fontSize: 14);
    final isDark = theme.brightness == Brightness.dark;
    final Color borderColor = isDark ? Colors.white12 : Colors.black12;
    final Color background = theme.colorScheme.surface;
    final Color onBackground = theme.colorScheme.onSurface;
    final Color brand = context.color.territoryColor;

    final selectedStyle =
    textTheme.copyWith(fontWeight: FontWeight.w600, height: 1.05);
    final unselectedStyle =
    textTheme.copyWith(fontWeight: FontWeight.w500, height: 1.05);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        physics: AppScrollBehavior.defaultPhysics,

        labelPadding: _labelPadding,
        indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: brand, width: 2.5),
            insets: const EdgeInsets.symmetric(horizontal: 20)),
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        labelColor: onBackground,
        unselectedLabelColor: onBackground.withOpacity(0.55),
        labelStyle: selectedStyle,
        unselectedLabelStyle: unselectedStyle,
        onTap: onTap,
        tabs: List.generate(adTabs.length, (i) {
          final title = adTabs[i]['title']!.translate(context);
          final count =
              (counts != null && i < counts!.length) ? counts![i] : null;

          return Tab(
            child: Semantics(
              label: count == null ? title : '$title ($count)',
              selected: controller.index == i,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 5),
                      _Badge(count: count),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StatsTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StatsTabsHeaderDelegate({
    required this.backgroundColor,
    required this.statsBuilder,
    required this.tabBarBuilder,
  });

  final Color backgroundColor;
  final WidgetBuilder statsBuilder;
  final WidgetBuilder tabBarBuilder;

  static const double _statsSectionExtent = 95;
  static const double _topSpacing = 4;
  static const double _betweenSpacing = 6;
  static const double _bottomSpacing = 12;

  double get _tabsSectionExtent =>
      _ProfileTabBar.preferredHeight +
      _topSpacing +
      _betweenSpacing +
      _bottomSpacing;

  @override
  double get minExtent => _tabsSectionExtent;

  @override
  double get maxExtent => _tabsSectionExtent + _statsSectionExtent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double deltaExtent = maxExtent - minExtent;
    final double t =
        deltaExtent <= 0 ? 1.0 : (shrinkOffset / deltaExtent).clamp(0.0, 1.0);
    final double statsOpacity = 1 - t;
    final double heightFactor = math.max(0.0001, statsOpacity);
    final double translateY = -8 * t;

    final showShadow = overlapsContent || shrinkOffset > 0;
    final shadowStrength = showShadow ? 0.08 * (0.5 + t / 2) : 0.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(shadowStrength),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(height: _topSpacing),
          ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: heightFactor,
              child: Opacity(
                opacity: statsOpacity,
                child: Transform.translate(
                  offset: Offset(0, translateY),
                  child: statsBuilder(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: _betweenSpacing),
          tabBarBuilder(context),
          const SizedBox(height: _bottomSpacing),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StatsTabsHeaderDelegate oldDelegate) {
    return true;
  }
}

/// شارة عدّاد صغيرة
class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 12, color: cs.primary),
      ),
    );
  }
}



class _ProfileScreenShimmer extends StatelessWidget {
  final Color backgroundColor;
  final List<Map<String, String>> adTabs;

  const _ProfileScreenShimmer({
    required this.backgroundColor,
    required this.adTabs,
  });

  @override
  Widget build(BuildContext context) {
    final int tabCount = adTabs.isEmpty ? 4 : adTabs.length;
    final EdgeInsets contentPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: backgroundColor,
        child: CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderShimmer(),
                    const SizedBox(height: 16),
                    _BioLinesShimmer(),
                    const SizedBox(height: 16),
                    _ActionButtonsShimmer(),
                    const SizedBox(height: 20),
                    _StatsStripShimmer(),
                    const SizedBox(height: 20),
                    _TabFiltersShimmer(count: tabCount),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _ProfileItemSkeletonCard(),
                ),
                childCount: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return Row(
      children: [
        CustomShimmer(
          height: 72,
          width: 72,
          borderRadius: 36,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomShimmer(height: 18, width: width * 0.55, borderRadius: 10),
              const SizedBox(height: 10),
              CustomShimmer(height: 14, width: width * 0.35, borderRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _BioLinesShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (index) {
        final double factor = index == 2 ? 0.5 : 0.85;
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 8),
          child: CustomShimmer(
            height: 12,
            width: width * factor,
            borderRadius: 8,
          ),
        );
      }),
    );
  }
}

class _ActionButtonsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomShimmer(height: 48, borderRadius: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomShimmer(height: 48, borderRadius: 14),
        ),
      ],
    );
  }
}

class _StatsStripShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double itemWidth = (width - 16 * 2 - 12) / 2;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(4, (_) {
        return CustomShimmer(
          height: 44,
          width: itemWidth,
          borderRadius: 16,
        );
      }),
    );
  }
}

class _TabFiltersShimmer extends StatelessWidget {
  final int count;
  const _TabFiltersShimmer({required this.count});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(count, (_) {
        return CustomShimmer(
          height: 34,
          width: 110,
          borderRadius: 18,
        );
      }),
    );
  }
}

class _ProfileItemSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomShimmer(
      height: 140,
      width: double.infinity,
      borderRadius: 18,
      margin: EdgeInsets.zero,
    );
  }
}
