// lib/ui/screens/profile/show_profile_ui.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';
// ╪د┘╪ز╪ذ┘ê┘è╪ذ ╪د┘╪»╪د╪«┘┘è ┘┘é╪د╪خ┘à╪ر ╪د┘╪ح╪╣┘╪د┘╪د╪ز
import 'my_item_tab.dart';

// ╪ص╪د┘╪د╪ز ╪د┘┘à╪│╪ز╪«╪»┘à ┘ê╪د┘╪ح╪ص╪╡╪د╪خ┘è╪د╪ز
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/cubits/profile/profile_stats_cubit.dart';
import 'package:marib/data/cubits/item/fetch_my_item_cubit.dart';

// ╪س┘è┘à + ╪ث╪»┘ê╪د╪ز ┘à╪│╪د╪╣╪»╪ر
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/merchant_display_helper.dart';
import 'package:marib/app/app_scroll_behavior.dart';
import 'package:marib/app/routes.dart';

/// ┘ê╪د╪ش┘ç╪ر ╪┤╪د╪┤╪ر ╪د┘┘à┘┘ ╪د┘╪┤╪«╪╡┘è (╪╣╪▒╪╢ ┘┘é╪╖) ظ¤ ╪ز╪│╪ز┘é╪ذ┘ ┘â┘ ╪┤┘è╪ة ╪╣╪ذ╪▒ Params.
/// ┘╪د ┘è┘ê╪ش╪» ┘à┘╪╖┘é ╪ذ┘è╪د┘╪د╪ز ┘ç┘╪د╪ؤ ╪ث┘è ┘à┘╪╖┘é ┘è╪ش╪ذ ╪ث┘ ┘è╪ذ┘é┘ë ╪«╪د╪▒╪ش ┘ç╪░╪د ╪د┘┘à┘┘.


class ProfileScreenUI extends StatelessWidget {
  final TabController tabController;
  final List<Map<String, String>> adTabs;

  final VoidCallback onEditProfilePressed;
  final VoidCallback onShareProfilePressed;
  final VoidCallback onAvatarEditPressed;
  final bool isUserAuthenticated;
  final ValueNotifier<bool> fullPageLoadingNotifier;
  final VoidCallback onRequestFullRefresh;

  /// ┘à╪▓┘ê┘ّ╪» ╪╡┘ê╪▒╪ر ╪د┘╪ذ╪▒┘ê┘╪د┘è┘ (File/Network/SVG) ┘à┘ ╪د┘┘ State ╪د┘╪«╪د╪▒╪ش┘è
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

    int? countForTab(String? status) {
      final String key = normalizeStatus(status);
      final cubit = myAdsCubitReference[key];
      final state = cubit?.state;
      if (state is FetchMyItemsSuccess) {
        return state.total;
      }
      return null;
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
      final List<int?> tabCounts =
          adTabs.map<int?>((tab) => countForTab(tab["status"])).toList();

      return NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 0),
          _HeaderSection(
            buildProfileImage: buildProfileImage,
            isUserAuthenticated: isUserAuthenticated,
          ),
          const SizedBox(height: 12),
          const _StatsRow(),
          const SizedBox(height: 12),
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
          statsBuilder: (ctx) => const SizedBox.shrink(),
          tabBarBuilder: (ctx) => _AdsTabChips(
            controller: tabController,
            adTabs: adTabs,
            counts: tabCounts,
            onTap: (index) => tabController.animateTo(index),
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
              return PrimaryScrollController(
                controller: ScrollController(),
                child: MyItemTab(
                  getItemsWithStatus: status,
                  onLoadingChanged: updateLoading,
                  onFullRefreshRequested: () {
                    updateLoading(statusKey, true);
                    onRequestFullRefresh();
                  },
                ),
              );
            }).toList(),
        ),
      );
    }

    return BlocBuilder<ProfileStatsCubit, ProfileStatsState>(
      builder: (context, statsState) {
        return ValueListenableBuilder<bool>(
          valueListenable: fullPageLoadingNotifier,
          builder: (context, adsLoading, _) {
            return buildContent();
          },
        );
      },
    );
  }
}

/// ╪▒╪ث╪│ ╪د┘╪┤╪د╪┤╪ر: ╪╡┘ê╪▒╪ر + ╪د╪│┘à ╪د┘┘à╪│╪ز╪«╪»┘à.
/// ╪ز┘à ╪د╪│╪ز╪«╪»╪د┘à BlocBuilder ┘┘╪ز╪ص╪»┘è╪س ╪د┘┘┘ê╪▒┘è ╪╣┘╪» ╪ز╪║┘è┘ّ╪▒ ╪ذ┘è╪د┘╪د╪ز ╪د┘┘à╪│╪ز╪«╪»┘à.
class _HeaderSection extends StatelessWidget {
  final Widget Function() buildProfileImage;
  final bool isUserAuthenticated;

  const _HeaderSection({
    required this.buildProfileImage,
    required this.isUserAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12, start: 16, end: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ╪ح╪╖╪د╪▒ ╪╡┘ê╪▒╪ر ╪ذ╪▒┘ê┘╪د┘è┘ ╪»╪د╪خ╪▒┘è
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

          // ╪د┘╪د╪│┘à ظ¤ ┘è┘╪╣╪د╪» ╪ذ┘╪د╪ج┘ç ╪ز┘┘é╪د╪خ┘è┘ï╪د ╪╣┘╪» ╪ز╪║┘è╪▒ ╪ص╪د┘╪ر UserDetailsCubit
          Expanded(
            child: BlocBuilder<UserDetailsCubit, UserDetailsState>(
              buildWhen: (prev, curr) => prev.user != curr.user,
              builder: (context, state) {
                final user = state.user;
                final bool isMerchantAccount =
                    user?.userType == Constant.accountTypeSeller;
                final String resolvedName = user == null
                    ? ''
                    : MerchantDisplayHelper.resolveDisplayName(
                        isMerchant: isMerchantAccount,
                        store: user.store,
                        additionalInfo: user.additionalInfo,
                        fallbackName: user.name,
                      ).trim();
                final String displayName =
                    resolvedName.isNotEmpty ? resolvedName : (user?.name ?? '');
                final bool isVerified = (user?.isVerified ?? 0) == 1;
                final bool showVerificationButton = !isVerified && isUserAuthenticated;

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showVerificationButton) ...[
                      const SizedBox(width: 10),
                      _VerifyAccountChip(onTap: () {
                        Navigator.of(context)
                            .pushNamed(Routes.accountVerificationInfo);
                      }),
                    ] else if (isVerified) ...[
                      const SizedBox(width: 10),
                      const _VerifiedBadge(),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyAccountChip extends StatelessWidget {
  final VoidCallback onTap;

  const _VerifyAccountChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: context.color.territoryColor, width: 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor:
            context.color.territoryColor.withOpacity(isDark ? 0.12 : 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined,
              size: 18, color: context.color.territoryColor),
          const SizedBox(width: 6),
          Text(
            "توثيق الحساب",
            style: TextStyle(
              color: context.color.territoryColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final Color accent = context.color.territoryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            "موثق",
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// ╪╡┘ ╪د┘╪ح╪ص╪╡╪د╪خ┘è╪د╪ز: (╪د┘┘à┘╪╢┘╪ر / ╪د┘╪ح╪╣┘╪د┘╪د╪ز / ╪د┘╪▒╪│╪د╪خ┘ / ╪د┘╪ز┘é┘è┘è┘à)
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
          // TODO: ╪د╪▒╪ذ╪╖ ╪د┘╪ز┘é┘è┘è┘à ╪د┘╪ص┘é┘è┘é┘è ╪╣┘╪» ╪ز┘ê┘╪▒┘ç ┘à┘ ╪د┘┘ API
          // rating = s.rating;
        }
        String showInt(int v) => isReady ? "$v" : "-";
        String showRating(double v) => isReady ? v.toStringAsFixed(1) : "-";

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: StatBox(
                  value: showInt(fav),
                  label: "\u0627\u0644\u0645\u0641\u0636\u0644\u0629".translate(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatBox(
                  value: showInt(ads),
                  label: "\u0627\u0644\u0625\u0639\u0644\u0627\u0646\u0627\u062a".translate(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatBox(
                  value: showInt(chats),
                  label: "\u0627\u0644\u0631\u0633\u0627\u0626\u0644".translate(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatBox(
                  value: showRating(rating),
                  label: "\u0627\u0644\u062a\u0642\u064a\u064a\u0645".translate(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}



/// ╪╡┘╪»┘ê┘é ╪▒┘é┘à + ╪╣┘┘ê╪د┘ ╪ذ╪│┘è╪╖ ┘à╪╣ ╪ح┘à┘â╪د┘┘è╪ر ╪د┘╪╢╪║╪╖ (╪د╪«╪ز┘è╪د╪▒┘è)
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

/// ╪ث╪▓╪▒╪د╪▒ ╪د┘╪ح╪ش╪▒╪د╪ة╪د╪ز (╪ز╪╣╪»┘è┘ / ┘à╪┤╪د╪▒┘â╪ر) ┘à╪╣ ╪ص╪د┘╪د╪ز ╪ز╪╣╪╖┘è┘/╪ز╪ص┘à┘è┘ ╪د╪«╪ز┘è╪د╪▒┘è╪ر.
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

    // ┘à┘é╪د╪│╪د╪ز ┘à╪ز╪ش╪د┘ê╪ذ╪ر ╪ذ╪│┘è╪╖╪ر
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
      minimumSize: Size(0, minH), // ╪د╪▒╪ز┘╪د╪╣ ┘à┘ê╪ص┘ّ╪» ┘ê┘à╪ز╪ش╪د┘ê╪ذ
    ).copyWith(
      // ╪د╪│╪ز╪«╪»╪د┘à MaterialStateProperty ┘┘à┘╪د╪ة┘à╪ر ╪ح╪╡╪»╪د╪▒╪د╪ز Flutter ╪د┘╪ث┘é╪»┘à
      overlayColor: MaterialStatePropertyAll(cs.primary.withOpacity(.06)),
    );

    Widget labelText(String text) => FittedBox(
          fit: BoxFit.scaleDown, // ┘è╪╢┘à┘ ╪ذ┘é╪د╪ة ╪د┘┘╪╡ ┘┘è ╪│╪╖╪▒ ┘ê╪د╪ص╪»
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
        mainAxisSize: MainAxisSize.max, // ┘è╪║╪╖┘è ╪د┘╪╣╪▒╪╢ ┘â╪د┘à┘
        children: [
          // ╪▓╪▒ ╪د┘╪ز╪╣╪»┘è┘ ╪ث╪╣╪▒╪╢
          Expanded(
            flex: 7,
            child: Semantics(
              button: true,
              label: '╪ز╪╣╪»┘è┘ ╪د┘┘à┘┘ ╪د┘╪┤╪«╪╡┘è',
              child: buildBtn(
                icon: Icons.edit,
                text: "╪ز╪╣╪»┘è┘ ╪د┘┘à┘┘ ╪د┘╪┤╪«╪╡┘è".translate(context),
                onPressed: onEditProfilePressed,
                enabled: editEnabled,
                loading: isEditLoading,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ╪▓╪▒ ╪د┘┘à╪┤╪د╪▒┘â╪ر ╪ث╪╢┘è┘é
          Expanded(
            flex: 5,
            child: Semantics(
              button: true,
              label: '┘à╪┤╪د╪▒┘â╪ر ╪د┘┘à┘┘',
              child: buildBtn(
                icon: Icons.share,
                text: "┘à╪┤╪د╪▒┘â╪ر ╪د┘┘à┘┘".translate(context),
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

/// ╪ز╪ذ┘ê┘è╪ذ╪د╪ز ╪د┘╪ص╪د┘╪د╪ز + ╪┤╪د╪▒╪ر ╪╣╪»┘ّ╪د╪» ╪د╪«╪ز┘è╪د╪▒┘è╪ر ┘┘â┘ ╪ز╪ذ┘ê┘è╪ذ.
/// Ads tabs bar with pill styling and per-tab counts.
class _AdsTabChips extends StatelessWidget {
  final TabController controller;
  final List<Map<String, String>> adTabs;
  final List<int?> counts;
  final void Function(int index)? onTap;

  static const double preferredHeight = 64;

  const _AdsTabChips({
    required this.controller,
    required this.adTabs,
    required this.counts,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color base = context.color.secondaryColor;
    final Color brand = context.color.territoryColor;
    final Color textDefault = context.color.textDefaultColor;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final int selectedIndex = controller.index;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(adTabs.length, (i) {
              final title = adTabs[i]['title']!.translate(context);
              final int? count = i < counts.length ? counts[i] : null;
              final bool selected = i == selectedIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _AdTabChip(
                  label: title,
                  count: count,
                  selected: selected,
                  background: base,
                  brand: brand,
                  textColor: textDefault,
                  onTap: () => onTap?.call(i),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _AdTabChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final Color background;
  final Color brand;
  final Color textColor;
  final VoidCallback? onTap;

  const _AdTabChip({
    required this.label,
    this.count,
    required this.selected,
    required this.background,
    required this.brand,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill = selected ? brand.withOpacity(0.16) : background;
    final Color border = selected ? brand : textColor.withOpacity(0.25);
    final Color labelColor = selected ? brand : textColor.withOpacity(0.9);
    final Color badgeBg =
        selected ? brand.withOpacity(0.22) : textColor.withOpacity(0.12);
    final Color badgeText =
        selected ? brand : textColor.withOpacity(0.8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                  fontSize: 14,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: badgeText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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

  static const double _statsSectionExtent = 0;
  static const double _topSpacing = 0;
  static const double _betweenSpacing = 6;
  static const double _bottomSpacing = 12;

  double get _tabsSectionExtent =>
      _AdsTabChips.preferredHeight +
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

/// ╪┤╪د╪▒╪ر ╪╣╪»┘ّ╪د╪» ╪╡╪║┘è╪▒╪ر




