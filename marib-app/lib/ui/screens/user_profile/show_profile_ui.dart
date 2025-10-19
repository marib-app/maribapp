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

/// واجهة شاشة الملف الشخصي (عرض فقط) — تستقبل كل شيء عبر Params.
/// لا يوجد منطق بيانات هنا؛ أي منطق يجب أن يبقى خارج هذا الملف.
class ProfileScreenUI {
  final TabController tabController;
  final List<Map<String, String>> adTabs;

  final VoidCallback onEditProfilePressed;
  final VoidCallback onShareProfilePressed;
  final VoidCallback onAvatarEditPressed;

  /// مزوّد صورة البروفايل (File/Network/SVG) من الـ State الخارجي
  final Widget Function() buildProfileImage;

  const ProfileScreenUI({
    required this.tabController,
    required this.adTabs,
    required this.onEditProfilePressed,
    required this.onShareProfilePressed,
    required this.onAvatarEditPressed,
    required this.buildProfileImage,
  });

  /// يبني قائمة Slivers تُستخدم داخل CustomScrollView/NestedScrollView.
  List<Widget> buildSlivers(BuildContext context) {
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 6)),
      SliverToBoxAdapter(
        child: _HeaderSection(
          buildProfileImage: buildProfileImage,
          onAvatarEditPressed: onAvatarEditPressed,
        ),

      ),
      const SliverToBoxAdapter(child: SizedBox(height: 11)),
      const SliverToBoxAdapter(child: _StatsRow()),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileButtons(
              onEditProfilePressed: onEditProfilePressed,
              onShareProfilePressed: onShareProfilePressed,
            ),
            const SizedBox(height: 14),
            _ProfileTabBar(
              controller: tabController,
              adTabs: adTabs,
            ),
          ],
        ),
    ),
    SliverFillRemaining(
    fillOverscroll: true,
    child: ColoredBox(
    color: context.color.primaryColor,
          child: TabBarView(
            controller: tabController,
            physics: const BouncingScrollPhysics(),
            children: adTabs.map((tab) {
              final status = tab["status"];
              return MyItemTab(getItemsWithStatus: status);
            }).toList(),
          ),
        ),
    ),
    ];

  }
}

/// رأس الشاشة: صورة + اسم المستخدم.
/// تم استخدام BlocBuilder للتحديث الفوري عند تغيّر بيانات المستخدم.
class _HeaderSection extends StatelessWidget {
  final Widget Function() buildProfileImage;
  final VoidCallback onAvatarEditPressed;
  const _HeaderSection({
    required this.buildProfileImage,
    required this.onAvatarEditPressed,
  });


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 18, start: 16, end: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // إطار صورة بروفايل دائري
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAvatarEditPressed,
              customBorder: const CircleBorder(),
              child: Container(
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
              StatBox(value: showInt(fav),   label: "المفضلة".translate(context)),
              StatBox(value: showInt(ads),   label: "الإعلانات".translate(context)),
              StatBox(value: showInt(chats), label: "الرسائل".translate(context)),
              StatBox(value: showRating(rating), label: "التقييم".translate(context)),
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
  const StatBox({super.key, required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    final hPad     = clamp(width * 0.04, 12, 20);
    final vPad     = clamp(width * 0.02, 10, 14);
    final minH     = clamp(width * 0.12, 44, 52);

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
  static const double preferredHeight = kToolbarHeight + 16;

  const _ProfileTabBar({
    required this.controller,
    required this.adTabs,
    this.counts,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final indicatorThickness =
    ((textStyle?.fontSize ?? 16) / 6).clamp(2.0, 4.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: context.color.secondaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        physics: const BouncingScrollPhysics(),

        // تباعد أفضل للنصّ داخل التبويب
        labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            width: indicatorThickness,
            color: context.color.territoryColor,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 20.0),
        ),
        indicatorSize: TabBarIndicatorSize.label,

        // استخدام MaterialStateProperty لمواءمة الإصدارات المختلفة
        overlayColor: MaterialStatePropertyAll(
          context.color.territoryColor.withOpacity(.06),
        ),

        labelColor: context.color.territoryColor,
        unselectedLabelColor: context.color.textLightColor,
        labelStyle: textStyle?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textStyle,
        onTap: onTap,

        tabs: List.generate(adTabs.length, (i) {
          final title = adTabs[i]['title']!.translate(context);
          final count = (counts != null && i < counts!.length) ? counts![i] : null;

          return Tab(
            child: Semantics(
              label: count == null ? title : '$title ($count)',
              selected: controller.index == i,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 88), // حد أدنى مريح
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



class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _SliverTabBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    return ColoredBox(
      color: context.color.primaryColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}