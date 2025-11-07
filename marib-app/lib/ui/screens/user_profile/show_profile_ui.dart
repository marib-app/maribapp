// lib/ui/screens/profile/show_profile_ui.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// التبويب الداخلي لقائمة الإعلانات
import 'my_item_tab.dart';

// حالات المستخدم والإحصائيات
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/cubits/profile/profile_stats_cubit.dart';

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

  /// مزوّد صورة البروفايل (File/Network/SVG) من الـ State الخارجي
  final Widget Function() buildProfileImage;

  const ProfileScreenUI({
    super.key,
    required this.tabController,
    required this.adTabs,
    required this.onEditProfilePressed,
    required this.onShareProfilePressed,
    required this.onAvatarEditPressed,
    required this.buildProfileImage,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return NestedScrollView(
      physics: AppScrollBehavior.defaultPhysics,
      floatHeaderSlivers: true,

      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              _HeaderSection(buildProfileImage: buildProfileImage),
              const SizedBox(height: 11),
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
          return MyItemTab(getItemsWithStatus: status);
        }).toList(),
      ),
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
      padding: const EdgeInsetsDirectional.only(top: 18, start: 16, end: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // إطار صورة بروفايل دائري
          Container(
            height: 100.rh(context),
            width: 100.rw(context),
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
                width: 92.rw(context),
                height: 92.rh(context),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
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

    final iconSize = clamp(width * 0.045, 16, 20);
    final fontSize = clamp(width * 0.035, 12, 16);
    final hPad = clamp(width * 0.04, 12, 20);
    final vPad = clamp(width * 0.02, 10, 14);
    final minH = clamp(width * 0.12, 44, 52);

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
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
          const SizedBox(width: 12),

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
        textTheme.copyWith(fontWeight: FontWeight.w700, height: 1.1);
    final unselectedStyle =
        textTheme.copyWith(fontWeight: FontWeight.w500, height: 1.1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        physics: AppScrollBehavior.defaultPhysics,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: brand, width: 3),
            insets: const EdgeInsets.symmetric(horizontal: 24)),
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
                constraints: const BoxConstraints(minWidth: 92),
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
                      const SizedBox(width: 6),
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

  static const double _statsSectionExtent = 128;
  static const double _tabsSectionExtent = 72;

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
    final double translateY = -12 * t;

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
          const SizedBox(height: 4),
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
          const SizedBox(height: 8),
          tabBarBuilder(context),
          const SizedBox(height: 8),
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
