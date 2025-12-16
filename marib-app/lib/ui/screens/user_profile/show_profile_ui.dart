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
import 'package:marib/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:marib/ui/widgets/verification_subscription_sheet.dart';

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
                final verificationState =
                    context.watch<FetchVerificationRequestsCubit>().state;
                bool isVerified = (user?.isVerified ?? 0) == 1;
                final verificationStatus = verificationState is FetchVerificationRequestSuccess
                    ? verificationState.data.status?.trim().toLowerCase()
                    : null;
                final DateTime? verificationExpiresAt =
                    verificationState is FetchVerificationRequestSuccess
                        ? verificationState.data.expiresAt
                        : null;
                if (!isVerified && verificationState is FetchVerificationRequestSuccess) {
                  final bool active = verificationStatus == 'approved' &&
                      (verificationExpiresAt == null ||
                          verificationExpiresAt.isAfter(DateTime.now()));
                  isVerified = active;
                }

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
                    ] else if (isVerified ||
                        verificationStatus == 'pending' ||
                        verificationStatus == 'resubmitted' ||
                        verificationStatus == 'rejected') ...[
                      const SizedBox(width: 10),
                      _buildVerificationStatusBadge(
                        context: context,
                        isVerified: isVerified,
                        status: verificationStatus,
                        expiresAt: verificationExpiresAt,
                      ),
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
          // rating placeholder kept zero until API provides value
        }

        String showInt(int v) => isReady ? '$v' : '-';
        String showRating(double v) => isReady ? v.toStringAsFixed(1) : '-';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatBox(value: showInt(fav), label: "favorites".translate(context)),
              StatBox(value: showInt(ads), label: "adsLbl".translate(context)),
              StatBox(value: showInt(chats), label: "chats".translate(context)),
              StatBox(value: showRating(rating), label: "rating".translate(context)),
            ],
          ),
        );
      },
    );
  }
}

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
      minimumSize: Size(0, minH),
    ).copyWith(
      overlayColor: MaterialStatePropertyAll(cs.primary.withOpacity(.06)),
    );

    Widget labelText(String text) => FittedBox(
          fit: BoxFit.scaleDown,
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
        mainAxisSize: MainAxisSize.max,
        children: [
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

class _StatsTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Color backgroundColor;
  final WidgetBuilder statsBuilder;
  final WidgetBuilder tabBarBuilder;

  _StatsTabsHeaderDelegate({
    required this.backgroundColor,
    required this.statsBuilder,
    required this.tabBarBuilder,
  });

  @override
  double get minExtent => 96;

  @override
  double get maxExtent => 120;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          statsBuilder(context),
          tabBarBuilder(context),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StatsTabsHeaderDelegate oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.statsBuilder != statsBuilder ||
        oldDelegate.tabBarBuilder != tabBarBuilder;
  }
}

class _AdsTabChips extends StatelessWidget {
  final TabController controller;
  final List<Map<String, String>> adTabs;
  final List<int?> counts;
  final void Function(int index)? onTap;

  const _AdsTabChips({
    required this.controller,
    required this.adTabs,
    required this.counts,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final indicatorThickness = ((textStyle?.fontSize ?? 16) / 6).clamp(2.0, 4.0);

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
        labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: indicatorThickness, color: context.color.territoryColor),
          insets: const EdgeInsets.symmetric(horizontal: 20.0),
        ),
        indicatorSize: TabBarIndicatorSize.label,
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
          final count = (i < counts.length) ? counts[i] : null;
          return Tab(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 88),
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
          );
        }),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.color.territoryColor.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 12, color: context.color.territoryColor),
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
            "قم بتوثيق حسابك",
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

Widget _buildVerificationStatusBadge({
  required BuildContext context,
  required bool isVerified,
  required String? status,
  required DateTime? expiresAt,
}) {
  final normalized = (status ?? "").trim().toLowerCase();
  final bool expired = expiresAt != null && expiresAt.isBefore(DateTime.now());

  if (isVerified && !expired) {
    return _VerifiedBadge(
      label: "موثق",
      color: Colors.green,
      onTap: () => showVerificationSubscriptionSheet(
        context,
        status: status,
        expiresAt: expiresAt,
        isVerified: isVerified,
      ),
    );
  }

  if (normalized == "approved" && !expired) {
    return _VerifiedBadge(
      label: "موثق",
      color: Colors.green,
      onTap: () => showVerificationSubscriptionSheet(
        context,
        status: status,
        expiresAt: expiresAt,
        isVerified: isVerified,
      ),
    );
  }

  if (normalized == "pending" || normalized == "resubmitted") {
    return _VerifiedBadge(
      label: "جاري المراجعة",
      color: Colors.amber,
      onTap: () => showVerificationSubscriptionSheet(
        context,
        status: status,
        expiresAt: expiresAt,
        isVerified: isVerified,
      ),
    );
  }

  if (normalized == "rejected") {
    return _VerifiedBadge(
      label: "تم الرفض",
      color: Colors.red,
      onTap: () => showVerificationSubscriptionSheet(
        context,
        status: status,
        expiresAt: expiresAt,
        isVerified: isVerified,
      ),
    );
  }

  return _VerifyAccountChip(
    onTap: () =>
        Navigator.of(context).pushNamed(Routes.accountVerificationInfo),
  );
}

class _VerifiedBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final String? label;
  final Color? color;

  const _VerifiedBadge({this.onTap, this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? context.color.territoryColor;
    final badge = Container(
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
            (label ?? "verifiedLbl".translate(context)),
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return badge;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: badge,
    );
  }
}

