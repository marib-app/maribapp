// lib/ui/screens/profile/show_profile_ui.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ?Ï???Ò?Ð?ê?è?Ð ?Ï???»?Ï?«???è ???é?Ï?Î?à?Ñ ?Ï???Í?????Ï???Ï?Ò
import 'my_item_tab.dart';

// ?Õ?Ï???Ï?Ò ?Ï???à???Ò?«?»?à ?ê?Ï???Í?Õ???Ï?Î?è?Ï?Ò
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/cubits/profile/profile_stats_cubit.dart';

// ?Ó?è?à + ?Ë?»?ê?Ï?Ò ?à???Ï???»?Ñ
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';

/// ?ê?Ï?Ô?ç?Ñ ???Ï???Ñ ?Ï???à???? ?Ï?????«???è (?????? ???é??) Ù?¤ ?Ò???Ò?é?Ð?? ?â?? ???è?É ???Ð?? Params.
/// ???Ï ?è?ê?Ô?» ?à?????é ?Ð?è?Ï???Ï?Ò ?ç???Ï?Ä ?Ë?è ?à?????é ?è?Ô?Ð ?Ë?? ?è?Ð?é?ë ?«?Ï???Ô ?ç???Ï ?Ï???à????.
class ProfileScreenUI extends StatelessWidget {
  final TabController tabController;
  final List<Map<String, String>> adTabs;

  final VoidCallback onEditProfilePressed;
  final VoidCallback onShareProfilePressed;
  final VoidCallback onAvatarEditPressed;

  /// ?à???ê?ø?» ???ê???Ñ ?Ï???Ð???ê???Ï?è?? (File/Network/SVG) ?à?? ?Ï???? State ?Ï???«?Ï???Ô?è
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
    final height = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        _HeaderSection(buildProfileImage: buildProfileImage),
        const SizedBox(height: 11),
        const _StatsRow(),
        const SizedBox(height: 14),

        _ProfileButtons(
          onEditProfilePressed: onEditProfilePressed,
          onShareProfilePressed: onShareProfilePressed,
        ),

        const SizedBox(height: 14),

        _ProfileTabBar(
          controller: tabController,
          adTabs: adTabs,
        ),

        const SizedBox(height: 8),

        // ?à???Ï?Õ???Ñ: ???Ë?? ?Ï???ê?Ï?Ô?ç?Ñ ?Ò?????Ò?«?»?à ?»?Ï?«?? SingleChildScrollView ???è ?Ï?????Ï???Ñ ?Ï???Ë?à?î
        // ???????è TabBarView ?Ï???Ò???Ï???ï?Ï ?Ó?Ï?Ð?Ò?ï?Ï ?????Ð?è?ï?Ï ?à?? ?Ï?????Ï???Ñ ?Õ?Ò?ë ?è?â?ê?? ???ç?Ï ?é?è?ê?» ???Ï???Õ?Ñ.
        SizedBox(
          height: height * 0.7,
          child: TabBarView(
            controller: tabController,
            physics: const BouncingScrollPhysics(),
            children: adTabs.map((tab) {
              final status = tab["status"];
              return MyItemTab(getItemsWithStatus: status);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// ???Ë?? ?Ï?????Ï???Ñ: ???ê???Ñ + ?Ï???à ?Ï???à???Ò?«?»?à.
/// ?Ò?à ?Ï???Ò?«?»?Ï?à BlocBuilder ?????Ò?Õ?»?è?Ó ?Ï?????ê???è ?????» ?Ò???è?ø?? ?Ð?è?Ï???Ï?Ò ?Ï???à???Ò?«?»?à.
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
          // ?Í???Ï?? ???ê???Ñ ?Ð???ê???Ï?è?? ?»?Ï?Î???è
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

          // ?Ï???Ï???à Ù?¤ ?è?????Ï?» ?Ð???Ï?Ì?ç ?Ò???é?Ï?Î?è?ï?Ï ?????» ?Ò???è?? ?Õ?Ï???Ñ UserDetailsCubit
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

/// ???? ?Ï???Í?Õ???Ï?Î?è?Ï?Ò: (?Ï???à???????Ñ / ?Ï???Í?????Ï???Ï?Ò / ?Ï???????Ï?Î?? / ?Ï???Ò?é?è?è?à)
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
          // TODO: ?Ï???Ð?? ?Ï???Ò?é?è?è?à ?Ï???Õ?é?è?é?è ?????» ?Ò?ê?????ç ?à?? ?Ï???? API
          // rating = s.rating;
        }

        String showInt(int v) => isReady ? '$v' : 'Ù?¤';
        String showRating(double v) => isReady ? v.toStringAsFixed(1) : 'Ù?¤';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatBox(value: showInt(fav),   label: "?Ï???à???????Ñ".translate(context)),
              StatBox(value: showInt(ads),   label: "?Ï???Í?????Ï???Ï?Ò".translate(context)),
              StatBox(value: showInt(chats), label: "?Ï???????Ï?Î??".translate(context)),
              StatBox(value: showRating(rating), label: "?Ï???Ò?é?è?è?à".translate(context)),
            ],
          ),
        );
      },
    );
  }
}

/// ?????»?ê?é ???é?à + ?????ê?Ï?? ?Ð???è?? ?à?? ?Í?à?â?Ï???è?Ñ ?Ï???????? (?Ï?«?Ò?è?Ï???è)
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

/// ?Ë?????Ï?? ?Ï???Í?Ô???Ï?É?Ï?Ò (?Ò???»?è?? / ?à???Ï???â?Ñ) ?à?? ?Õ?Ï???Ï?Ò ?Ò?????è??/?Ò?Õ?à?è?? ?Ï?«?Ò?è?Ï???è?Ñ.
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

    // ?à?é?Ï???Ï?Ò ?à?Ò?Ô?Ï?ê?Ð?Ñ ?Ð???è???Ñ
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
      minimumSize: Size(0, minH), // ?Ï???Ò???Ï?? ?à?ê?Õ?ø?» ?ê?à?Ò?Ô?Ï?ê?Ð
    ).copyWith(
      // ?Ï???Ò?«?»?Ï?à MaterialStateProperty ???à???Ï?É?à?Ñ ?Í???»?Ï???Ï?Ò Flutter ?Ï???Ë?é?»?à
      overlayColor: MaterialStatePropertyAll(cs.primary.withOpacity(.06)),
    );

    Widget labelText(String text) => FittedBox(
      fit: BoxFit.scaleDown, // ?è???à?? ?Ð?é?Ï?É ?Ï?????? ???è ?????? ?ê?Ï?Õ?»
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
        mainAxisSize: MainAxisSize.max, // ?è?????è ?Ï???????? ?â?Ï?à??
        children: [
          // ???? ?Ï???Ò???»?è?? ?Ë??????
          Expanded(
            flex: 7,
            child: Semantics(
              button: true,
              label: '?Ò???»?è?? ?Ï???à???? ?Ï?????«???è',
              child: buildBtn(
                icon: Icons.edit,
                text: "?Ò???»?è?? ?Ï???à???? ?Ï?????«???è".translate(context),
                onPressed: onEditProfilePressed,
                enabled: editEnabled,
                loading: isEditLoading,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ???? ?Ï???à???Ï???â?Ñ ?Ë???è?é
          Expanded(
            flex: 5,
            child: Semantics(
              button: true,
              label: '?à???Ï???â?Ñ ?Ï???à????',
              child: buildBtn(
                icon: Icons.share,
                text: "?à???Ï???â?Ñ ?Ï???à????".translate(context),
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

/// ?Ò?Ð?ê?è?Ð?Ï?Ò ?Ï???Õ?Ï???Ï?Ò + ???Ï???Ñ ???»?ø?Ï?» ?Ï?«?Ò?è?Ï???è?Ñ ???â?? ?Ò?Ð?ê?è?Ð.
class _ProfileTabBar extends StatelessWidget {
  final TabController controller;
  final List<Map<String, String>> adTabs;

  // ???»?Ï?»?Ï?Ò ?Ï?«?Ò?è?Ï???è?Ñ (?Ð?????? ?Ò???Ò?è?Ð ?Ï???Ò?Ð?ê?è?Ð?Ï?Ò)
  final List<int>? counts;

  // ?Õ?»?Ó ?Ò???è?è?? ?Ï???Ò?Ð?ê?è?Ð (?Ï?«?Ò?è?Ï???è)
  final void Function(int index)? onTap;

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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: context.color.secondaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        physics: const BouncingScrollPhysics(),

        // ?Ò?Ð?Ï???» ?Ë?????? ?????????ø ?»?Ï?«?? ?Ï???Ò?Ð?ê?è?Ð
        labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            width: indicatorThickness,
            color: context.color.territoryColor,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 20.0),
        ),
        indicatorSize: TabBarIndicatorSize.label,

        // ?Ï???Ò?«?»?Ï?à MaterialStateProperty ???à?ê?Ï?É?à?Ñ ?Ï???Í???»?Ï???Ï?Ò ?Ï???à?«?Ò?????Ñ
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
                constraints: const BoxConstraints(minWidth: 88), // ?Õ?» ?Ë?»???ë ?à???è?Õ
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

/// ???Ï???Ñ ???»?ø?Ï?» ?????è???Ñ
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

