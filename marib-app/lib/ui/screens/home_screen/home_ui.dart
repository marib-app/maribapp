import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/merchant/merchant_store_snapshot.dart';
import 'package:marib/data/model/user_model.dart';
import 'package:marib/ui/screens/home/widgets/grid_list_adapter.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:marib/ui/widgets/dialogs/store_review_dialogs.dart';

import 'package:marib/ui/screens/item/cards/horizontal_card.dart';
import 'package:marib/ui/screens/item/cards/sections_adapter.dart';

import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:marib/utils/hive_keys.dart';

import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/merchant_display_helper.dart';

import 'package:marib/data/cubits/notifications/unread_notifications_cubit.dart';

// ظ…ظ„ط§ط­ط¸ط©: ProfileHeaderUI ظٹط¯ط¹ظ… welcomeText ظˆ welcomeColor ظˆ shrinkFactor.

class HomeScreenUI extends StatelessWidget {
  // ط§ظ„ط£ط³ط§ط³ظٹط§طھ
  final ScrollController scrollController;
  final VoidCallback onSupportPressed;
  final List<Widget> bodySlivers;

  // ط¥ظ…ظ‘ط§ طھظ…ط±ط± ظˆط¯ط¬طھ ط¬ط§ظ‡ط² ظ„ظ„ظ‡ظٹط¯ط±... (ط§ط®طھظٹط§ط±ظٹ)
  final Widget? appBarLeading;

  // ...ط£ظˆ طھظ…ط±ط± ط¨ظٹط§ظ†ط§طھ ط§ظ„ط¨ط±ظˆظپط§ظٹظ„ ظˆظ†ط¨ظ†ظٹ ط§ظ„ظ‡ظٹط¯ط± ط¯ط§ط®ظ„ظٹط§ظ‹ (ط§ط®طھظٹط§ط±ظٹ)
  final bool? isAuthenticated;
  final String? name;
  final String? mobile;
  final String? profileUrl;
  final bool? isVerified;
  final int? cartCount;
  final int? notifCount;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onInfoTap;

  // ط³ط·ط± ط§ظ„طھط±ط­ظٹط¨
  final String? userId;
  final bool showWelcomeLine;

  // ط®ظٹط§ط±ط§طھ ط¥ط¶ط§ظپظٹط©
  final Future<void> Function()? onRefresh;
  final bool hideFabOnScroll;
  final double? expandedHeight;
  final Widget? appBarBackdrop;
  final bool showHeaderShimmer;

  const HomeScreenUI({
    super.key,
    required this.scrollController,
    required this.onSupportPressed,
    required this.bodySlivers,
    this.appBarLeading,
    this.isAuthenticated,
    this.name,
    this.mobile,
    this.profileUrl,
    this.isVerified,
    this.cartCount,
    this.notifCount,
    this.onAvatarTap,
    this.onCartTap,
    this.onNotificationTap,
    this.onInfoTap,
    this.userId,
    this.showWelcomeLine = true,
    this.onRefresh,
    this.hideFabOnScroll = true,
    this.expandedHeight,
    this.appBarBackdrop,
    this.showHeaderShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    // ظ‚ظٹط§ط³ ط§ظ„ظ‡ظٹط¯ط±
    final double kExpanded =
        expandedHeight ?? (110.0.rh(context)).clamp(100.0, 200.0);

    // ط§ظ„ظ‚ظٹظ… ط§ظ„ظ‚ط§ط¯ظ…ط© ظ…ظ† ط§ظ„ط¨ط±ط§ظ…ظٹطھط±ط²
    final String idStr = (userId ?? '').trim();
    final String paramName = (name ?? '').trim();

    // ط¨ظٹط§ظ†ط§طھ ط§ظ„ظ…ط³طھط®ط¯ظ… ط§ظ„ط­ظ‚ظٹظ‚ظٹط© ظ…ظ† ط§ظ„طھط®ط²ظٹظ†
    return ValueListenableBuilder<Box<dynamic>>(
      valueListenable: Hive.box(HiveKeys.userDetailsBox).listenable(),
      builder: (context, _, __) {
        final details = HiveUtils.getUserDetails();
        final bool auth = HiveUtils.isUserAuthenticated();

        final bool merchantAccount = _isMerchant(details);
        final MerchantStoreSnapshot? storeSnapshot = details.store == null
            ? null
            : MerchantStoreSnapshot.fromDynamic(details.store);
        final bool canAccessMerchantDashboard =
            storeSnapshot?.isApproved ?? false;
        final String resolvedMerchantName =
            MerchantDisplayHelper.resolveDisplayName(
          isMerchant: merchantAccount,
          store: details.store,
          additionalInfo: details.additionalInfo,
          fallbackName: details.name,
        );

        final String accountName = (() {
          if (!auth) {
            if (paramName.isNotEmpty && paramName != idStr) {
              return paramName;
            }
            return '  ط²ط§ط¦ط±';
          }

          final String trimmedMerchant = resolvedMerchantName.trim();
          if (trimmedMerchant.isNotEmpty && trimmedMerchant != idStr) {
            return trimmedMerchant;
          }

          if (paramName.isNotEmpty && paramName != idStr) {
            return paramName;
          }

          final String dn = (details.name ?? '').trim();
          if (dn.isNotEmpty && dn != idStr) {
            return dn;
          }
          return '  ط²ط§ط¦ط±';
        })();

        final String phone = (() {
          final String rawId = idStr.isNotEmpty
              ? idStr
              : (details.id != null ? details.id.toString() : '');
          if (rawId.isNotEmpty) {
            return '#$rawId';
          }

          // Fallback to provided mobile only if no id was found.
          if (mobile?.isNotEmpty == true) {
            return mobile!;
          }

          return details.mobile?.toString() ?? '';
        })();
        final String? merchantAvatar =
            MerchantDisplayHelper.resolveProfileImage(
          isMerchant: merchantAccount,
          store: details.store,
          fallbackImage: details.profile,
        );
        final String avatar = (profileUrl?.isNotEmpty == true)
            ? profileUrl!
            : (merchantAvatar ?? '');
        final bool verified = isVerified ?? (details.isVerified == 1);
        final int cart = cartCount ?? 0;
        final int notif = notifCount ?? 0;

        final VoidCallback resolvedAvatarTap = onAvatarTap ??
            () {
              UiUtils.checkUser(
                onNotGuest: () {
                  if (merchantAccount) {
                    if (!canAccessMerchantDashboard) {
                      showStoreReviewDialog(
                        context,
                        variant: StoreReviewDialogVariant.management,
                      );
                      return;
                    }
                    Navigator.pushNamed(context, Routes.merchantDashboard);
                    return;
                  }
                  HelperUtils.goToNextPage(
                    Routes.showProfile,
                    context,
                    false,
                    args: {"from": "profile"},
                  );
                },
                context: context,
              );
            };

        return SafeArea(
          child: Scaffold(
            backgroundColor: context.color.primaryColor,
            // ظ„ط§ طھط؛ظٹظ‘ط± ط£ظ„ظˆط§ظ† ط§ظ„ظ€AppBar
            body: NestedScrollView(
              controller: scrollController,
              headerSliverBuilder: (context, _) => [
                SliverAppBar(
                  pinned: true,
                  stretch: true,
                  elevation: 0,
                  backgroundColor: context.color.primaryColor,
                  expandedHeight: kExpanded,
                  flexibleSpace: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final double current = constraints.biggest.height;
                      final double denom = (kExpanded - kToolbarHeight);
                      final double t = denom <= 0
                          ? 0.0
                          : ((current - kToolbarHeight) / denom)
                              .clamp(0.0, 1.0);

                      Widget header = appBarLeading ??
                          ProfileHeaderUI(
                            isAuthenticated: isAuthenticated ?? auth,
                            name: accountName,
                            mobile: phone,
                            profileUrl: avatar,
                            isVerified: verified,
                            cartCount: cart,
                            notifCount: notif,
                            onAvatarTap: resolvedAvatarTap,
                            onCartTap: onCartTap ?? () {},
                            onNotificationTap: onNotificationTap ?? () {},
                            onInfoTap: onInfoTap ?? () {},
                            shrinkFactor: t,
                            welcomeText: (showWelcomeLine && idStr.isNotEmpty)
                                ? "ظ…ط±ط­ط¨ظ‹ط§ ط¨ظƒ: $idStr"
                                : null,
                            welcomeColor: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(.85),
                          );

                      if (showHeaderShimmer) {
                        header = const ProfileHeaderShimmer();
                      }

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (appBarBackdrop != null)
                            Opacity(opacity: t, child: appBarBackdrop!)
                          else
                            Opacity(
                              opacity: t,
                              child:
                                  Container(color: context.color.primaryColor),
                            ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: _curvedBottom(context, opacity: t),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(
                                start: 10.rw(context),
                                end: 10.rw(context),
                                bottom: (12.rh(context)).floorToDouble(),
                              ),
                              child: header,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              body: _buildBody(context),
            ),
            floatingActionButton: hideFabOnScroll
                ? _FabHider(
                    scrollController: scrollController,
                    onPressed: onSupportPressed,
                  )
                : FloatingActionButton(
                    onPressed: onSupportPressed,
                    backgroundColor: context.color.territoryColor,
                    child: SvgPicture.asset(
                      AppIcons.support,
                      height: 26,
                      width: 26,
                      color: Colors.white,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    // âœ¨ ظ„ط§ ظ†ط³طھط®ط¯ظ… SingleChildScrollView ظˆظ„ط§ PrimaryScrollController ظ‡ظ†ط§
    final List<Widget> slivers = bodySlivers.isEmpty
        ? <Widget>[const SliverToBoxAdapter(child: SizedBox.shrink())]
        : bodySlivers;

    final scroll = CustomScrollView(
      slivers: slivers,
    );

    return onRefresh == null
        ? scroll
        : RefreshIndicator.adaptive(
            onRefresh: onRefresh!,
            child: scroll,
          );
  }

  Widget _curvedBottom(BuildContext context, {required double opacity}) {
    // ط§ظ†ط­ظ†ط§ط،ط© ط¨ط³ظٹط·ط© طھظ†ط¯ظ…ط¬ ظ…ط¹ ط£ط³ظپظ„ ط§ظ„ظ€AppBar
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Container(
          height: 18,
          decoration: BoxDecoration(
            color: context.color.primaryColor,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isMerchant(UserModel? details) {
  if (details == null) {
    return false;
  }
  if (details.userType == Constant.accountTypeSeller) {
    return true;
  }
  final String? normalized = details.type?.trim().toLowerCase();
  return normalized == 'seller' || normalized == 'commercial';
}

/// ط¥ط®ظپط§ط،/ط¥ط¸ظ‡ط§ط± ط§ظ„ظپط§ط¨ ط£ط«ظ†ط§ط، ط§ظ„طھظ…ط±ظٹط±
class _FabHider extends StatefulWidget {
  const _FabHider({
    required this.scrollController,
    required this.onPressed,
  });

  final ScrollController scrollController;
  final VoidCallback onPressed;

  @override
  State<_FabHider> createState() => _FabHiderState();
}

class _FabHiderState extends State<_FabHider> {
  bool _visible = true;
  double _last = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final curr = widget.scrollController.position.pixels;
    if (curr > _last + 6 && _visible) {
      setState(() => _visible = false); // ظ†ط²ظˆظ„ â†’ ط£ط®ظپظگ
    } else if (curr < _last - 6 && !_visible) {
      setState(() => _visible = true); // طµط¹ظˆط¯ â†’ ط£ط¸ظ‡ط±
    }
    _last = curr;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 180),
      offset: _visible ? Offset.zero : const Offset(0, 2 / 3),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _visible ? 1 : 0,
        child: FloatingActionButton(
          onPressed: widget.onPressed,
          backgroundColor: context.color.territoryColor,
          child: SvgPicture.asset(
            AppIcons.support,
            height: 26,
            width: 26,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/* =======================
   Header UI (ط¯ط§ط®ظ„ظٹ) ظ…ط¹ طھط­ط¬ظٹظ… ظ…ط±ظ†
   ======================= */

class ProfileHeaderShimmer extends StatelessWidget {
  const ProfileHeaderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final double bottomPad = (12.rh(context)).floorToDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double available =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                ? constraints.maxHeight - bottomPad
                : 64.0;
        final double headerHeight =
            available.isFinite ? available.clamp(0.0, 64.0) : 64.0;

        return Padding(
          padding: EdgeInsetsDirectional.only(
            start: 10.rw(context),
            end: 10.rw(context),
            bottom: bottomPad,
          ),
          child: SizedBox(
            height: headerHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const ShimmerBox(
                  width: 52,
                  height: 52,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShimmerBox(
                        height: 16,
                        width: MediaQuery.of(context).size.width * 0.35,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 8),
                      ShimmerBox(
                        height: 12,
                        width: MediaQuery.of(context).size.width * 0.5,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: EdgeInsetsDirectional.only(
                          start: index == 0 ? 0 : 8),
                      child: const ShimmerBox(
                        width: 40,
                        height: 40,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProfileHeaderUI extends StatelessWidget {
  const ProfileHeaderUI({
    super.key,
    required this.isAuthenticated,
    required this.name,
    required this.mobile,
    required this.profileUrl,
    required this.isVerified,
    required this.cartCount,
    required this.notifCount,
    required this.onAvatarTap,
    required this.onCartTap,
    required this.onNotificationTap,
    required this.onInfoTap,
    this.guestIconSize,
    this.guestIconScale = 0.80,
    this.guestIconMin,
    this.guestIconMax,
    this.shrinkFactor = 1.0, // 1 ظ…ظˆط³ظ‘ط¹طŒ 0 ظ…ظ†ظƒظ…ط´
    this.welcomeText,
    this.welcomeColor,
  });

  final bool isAuthenticated;
  final String name;
  final String mobile;
  final String profileUrl;
  final bool isVerified;

  // ط£ط¶ظپ ظ‡ط°ظ‡ ط§ظ„ط­ظ‚ظˆظ„ ظ…ط¹ ط§ظ„ط¨ظ‚ظٹط©
  final double?
      guestIconSize; // ط­ط¬ظ… ط«ط§ط¨طھ ط¨ط§ظ„ط¨ظƒط³ظ„ (ط¥ظ† ط­ط¯ط¯طھظ‡ ظٹطھط¬ط§ظ‡ظ„ scale)
  final double
      guestIconScale; // ظ†ط³ط¨ط© ظ…ظ† ظ‚ط·ط± ط§ظ„ط£ظپط§طھط§ط± (ط§ظپطھط±ط§ط¶ظٹ 0.62)
  final double? guestIconMin; // ط­ط¯ ط£ط¯ظ†ظ‰ ط§ط®طھظٹط§ط±ظٹ
  final double? guestIconMax; // ط­ط¯ ط£ظ‚طµظ‰ ط§ط®طھظٹط§ط±ظٹ

  final int cartCount;
  final int notifCount;

  final VoidCallback onAvatarTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onInfoTap;

  final double shrinkFactor;

  final String? welcomeText; // ط؛ظٹط± ظ…ط³طھط®ط¯ظ… ط§ظ„ط¢ظ†
  final Color? welcomeColor; // ط؛ظٹط± ظ…ط³طھط®ط¯ظ… ط§ظ„ط¢ظ†

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;

        /* =============================
       * 1) ظ…ظ‚ط§ط³ط§طھ ط¹ط§ظ…ط© طھطھظ‚ظ„ظ‘طµ ط¨ط³ظ„ط§ط³ط©
       * ============================= */
        final double maxIconTap = (w * 0.12).clamp(36.0, 44.0);
        final double minIconTap = maxIconTap * 0.84;
        final double iconTap =
            (minIconTap + (maxIconTap - minIconTap) * shrinkFactor);

        final double maxIconSize = (w * 0.06).clamp(20.0, 24.0);
        final double minIconSize = maxIconSize * 0.88;
        final double iconSize =
            (minIconSize + (maxIconSize - minIconSize) * shrinkFactor);

        /* ============================================
       * 2) ط§ظ„ط£ظپط§طھط§ط±: ظƒط¨ظٹط± ظ…ظˆط³ظ‘ط¹ â†’ ظٹطھظ‚ظ„ظ‘طµ طھط¯ط±ظٹط¬ظٹظ‹ط§
       *    (ط§ظ†ظٹظ…ظٹط´ظ†ظ‡ ظ…ط³طھظ‚ظ„ ط¹ظ† ط±ظ‚ظ… ط§ظ„ط¬ظˆط§ظ„/ط§ظ„ط§ط³ظ…)
       * ============================================ */
        const double avatarExpandScale =
            1.70; // ظ…ظ‚ط¯ط§ط± طھظƒط¨ظٹط± ط§ظ„ط£ظپط§طھط§ط± ظ‚ط¨ظ„ ط§ظ„طھظ…ط±ظٹط±
        final double maxAvatarTap = maxIconTap * avatarExpandScale;
        final double minAvatarTap = minIconTap *
            0.82; // ط­ط¬ظ… ط§ظ„ط£ظپط§طھط§ط± ط¹ظ†ط¯ ط§ظ„ط§ظ†ظƒظ…ط§ط´ ط§ظ„ظƒط§ظ…ظ„
        final double avatarTap =
            (minAvatarTap + (maxAvatarTap - minAvatarTap) * shrinkFactor);

        const double borderStroke = 1.0;
        const double innerPadding = 0.0;
        final double avatarRadius =
            (avatarTap / 2) - (borderStroke + innerPadding);

        /* =============================
       * 3) طھط¨ط§ط¹ط¯ط§طھ ط¹ط§ظ…ط© ظˆظ†ظ‚ط§ط· ط¶ط¨ط·
       * ============================= */
        final double hPad = (w * 0.03).clamp(8.0, 14.0);
        const double vPad = 8.0;
        final double gap = (w * 0.02).clamp(6.0, 12.0);

        final bool small = w < 360; // ط´ط§ط´ط© ط¶ظٹظ‘ظ‚ط©
        final double nameMin = context.font.small;
        final double nameMax = context.font.large;
        final double nameSize = nameMin +
            (nameMax - nameMin) *
                shrinkFactor; // ط­ط¬ظ… ط§ط³ظ… ط¯ظٹظ†ط§ظ…ظٹظƒظٹ (ظ…ط³طھظ‚ظ„)

        /* ====================================================
       * 4) ط³ظ„ظˆظƒ ط±ظ‚ظ… ط§ظ„ط¬ظˆط§ظ„: ظٹط¸ظ‡ط± ظ…ظˆط³ظ‘ط¹طŒ ظٹط®طھظپظٹ ط¨ط§ظ†ظƒظ…ط§ط´ ط§ظ„ظ‡ظٹط¯ط±
       *    (ط§ظ†ظٹظ…ظٹط´ظ†ظ‡ ظ…ط³طھظ‚ظ„ â€” ظ„ط§ ظٹط²ط§ط­ظ… ط§ظ„ط§ط³ظ… ظ„ط£ظ†ظ‡ ظ…ظڈط«ط¨طھ ط¨ط£ط³ظپظ„)
       * ==================================================== */
        const double phoneThreshold = 0.60; // طھط­طھظ‡ط§ ظٹط®طھظپظٹ ط§ظ„ط±ظ‚ظ…
        final bool showPhoneNow =
            isAuthenticated && (shrinkFactor > phoneThreshold);

        /* ===================================================
       * 5) ط´ط§ط±ط© ط§ظ„طھط­ظ‚ظ‚: طھط¸ظ‡ط± ظ…ظˆط³ظ‘ط¹طŒ طھط®طھظپظٹ ط¨ط§ظ†ظƒظ…ط§ط´ ظ‚ظˆظٹ
       *    AnimatedSwitcher ط­طھظ‰ ظ„ط§ طھط­ط¬ط² ظ…ط³ط§ط­ط© ط¹ظ†ط¯ ط§ظ„ط¥ط®ظپط§ط،
       * =================================================== */
        const double badgeThreshold = 0.60;
        final bool showBadge = isVerified && (shrinkFactor > badgeThreshold);

        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            hPad.floorToDouble(),
            vPad,
            hPad.floorToDouble(),
            vPad,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              /* =============================
             * طµظˆط±ط© ط§ظ„ط­ط³ط§ط¨ (InkWell â†’ ط§ظ„ظ…ظ„ظپ ط§ظ„ط´ط®طµظٹ)
             * ============================= */
              SizedBox(
                width: avatarTap,
                height: avatarTap,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onAvatarTap, // opens the appropriate destination
                    customBorder: const CircleBorder(),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.territoryColor,
                          width: borderStroke,
                        ),
                      ),
                      padding: const EdgeInsets.all(innerPadding),
                      child: TweenAnimationBuilder<double>(
                        // ط§ظ†ظٹظ…ظٹط´ظ† ط­ط¬ظ… ط§ظ„ط£ظپط§طھط§ط± ظ…ط³طھظ‚ظ„ ظˆط«ط§ط¨طھ ط§ظ„ظ†ط¹ظˆظ…ط©
                        tween: Tween(begin: avatarRadius, end: avatarRadius),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        builder: (context, r, _) => CircleAvatar(
                          backgroundColor: colors.backgroundColor,
                          radius: r,
                          child: _buildAvatar(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(width: gap),

              /* ============================================================
             * ط§ظ„ظ†طµظˆطµ ط¯ط§ط®ظ„ ظ…ط³ط§ط­ط© ط«ط§ط¨طھط© ط§ظ„ط§ط±طھظپط§ط¹ = ط§ط±طھظپط§ط¹ ط§ظ„ط£ظپط§طھط§ط±
             * ظ†ط³طھط®ط¯ظ… Stack ظ„طھط«ط¨ظٹطھ ط§ظ„طھظ…ظˆط¶ط¹:
             *  - ط§ظ„ط´ط§ط±ط©: ط£ط¹ظ„ظ‰ ظٹط³ط§ط±
             *  - ط§ظ„ط§ط³ظ…: ظ…ظ†طھطµظپ ظٹط³ط§ط± (ظ„ط§ ظٹطھط£ط«ط± ط¨ط¸ظ‡ظˆط±/ط§ط®طھظپط§ط، ط§ظ„ط±ظ‚ظ…)
             *  - ط§ظ„ط±ظ‚ظ…: ط£ط³ظپظ„ ظٹط³ط§ط± (AnimatedSwitcher ظ…ط³طھظ‚ظ„)
             * ============================================================ */
              Expanded(
                child: SizedBox(
                  height:
                      avatarTap, // ظ†ظپط³ ط§ط±طھظپط§ط¹ ط§ظ„ط£ظپط§طھط§ط± â†’ ظ„ط§ Overflow
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // (ط£) ط§ظ„ط´ط§ط±ط© ط£ط¹ظ„ظ‰ ط§ظ„ظ€start ط¨ط¯ظ„ left
                      PositionedDirectional(
                        top: 0,
                        start: 0,
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, anim) => SizeTransition(
                              sizeFactor: anim,
                              axisAlignment: -1.0,
                              child:
                                  FadeTransition(opacity: anim, child: child),
                            ),
                            child: showBadge
                                ? Container(
                                    key: const ValueKey('badge'),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: colors.forthColor,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: small ? 4 : 6,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        UiUtils.getSvg(AppIcons.verifiedIcon,
                                            width: 14, height: 14),
                                        if (!small) ...[
                                          const SizedBox(width: 4),
                                          Text("verifiedLbl".translate(context))
                                              .color(colors.secondaryColor)
                                              .bold(weight: FontWeight.w500),
                                        ],
                                      ],
                                    ),
                                  )
                                : const SizedBox(key: ValueKey('no_badge')),
                          ),
                        ),
                      ),

                      // (ط¨) ط§ظ„ط§ط³ظ… ظپظٹ ظ…ظ†طھطµظپ ط§ظ„ظ€start (ظ…ط­ط§ط°ظٹ ظ„ظ„ط£ظپط§طھط§ط± ظپظٹ RTL/LTR)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: GestureDetector(
                          onTap: () {
                            UiUtils.checkUser(
                              onNotGuest: () {
                                HelperUtils.goToNextPage(
                                  Routes.showProfile,
                                  context,
                                  false,
                                  args: {"from": "profile"},
                                );
                              },
                              context: context,
                            );
                          }, // ظٹظپطھط­ ط§ظ„ظ…ظ„ظپ ط§ظ„ط´ط®طµظٹ
                          child: Padding(
                            // ظ†ط¨ط¹ط¯ ط§ظ„ط§ط³ظ… ط´ظˆظٹ ط¹ظ† ط§ظ„ط£ظٹظ‚ظˆظ†ط§طھ ظپظٹ ط§ظ„ط¬ظ‡ط© ط§ظ„ظ…ظ‚ط§ط¨ظ„ط©
                            padding: EdgeInsetsDirectional.only(
                              // ط§ط­طھظٹط§ط·ظٹ ط¨ط³ظٹط· ظ†ط§ط­ظٹط© ط§ظ„ظ€end ط­طھظ‰ ظ„ط§ ظٹظ„طھطµظ‚ ط¨ط§ظ„ط³ظ„ط© ط¨ط¹ط¯ ط§ظ„ط§ظ†ظƒظ…ط§ط´
                              end: iconTap + gap,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                    fontSize: nameSize,
                                    color: colors.textColorDark,
                                    height: 1.1,
                                  ),
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // (ط¬) ط±ظ‚ظ… ط§ظ„ط¬ظˆط§ظ„ ط£ط³ظپظ„ ط§ظ„ظ€start ط¨ط¯ظ„ bottom/left
                      PositionedDirectional(
                        start: 3,
                        end: 0,
                        bottom: 8,
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, anim) => SizeTransition(
                              sizeFactor: anim,
                              axisAlignment: 1.0,
                              child:
                                  FadeTransition(opacity: anim, child: child),
                            ),
                            child: (isAuthenticated && showPhoneNow)
                                ? Text(
                                    mobile,
                                    key: const ValueKey('phone'),
                                    maxLines: small ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                    style: TextStyle(
                                      fontSize: small
                                          ? (context.font.small * 0.92)
                                          : context.font.small,
                                      color: colors.textColorDark,
                                      height: 1.1,
                                    ),
                                  )
                                : const SizedBox(key: ValueKey('no_phone')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: gap),
// ط²ط± ط§ظ„ط§ط´ط¹ط§ط±ط§طھ ظ…طھط¨ظ‚ظٹ ط±ط¨ط· ط§ظ„ط¹ط¯ط§ط¯
              // ط¨ط§ظ‚ظٹ ط§ظ„ط£ظٹظ‚ظˆظ†ط§طھ ظ…ط¹ ط§ظ„ط´ط§ط±ط§طھ
              _IconWithBadge(
                icon: AppIcons.cart,
                onTap: () {
                  UiUtils.checkUser(
                    onNotGuest: () {
                      Navigator.pushNamed(context, Routes.cart);
                    },
                    context: context,
                  );
                },
                count: cartCount,
                tapSize: iconTap,
                iconSize: iconSize,
                badgeColor: colors.territoryColor,
              ),

              _IconWithBadge(
                icon: AppIcons.notification,
                onTap: () {
                  UiUtils.checkUser(
                    onNotGuest: () {
                      Navigator.pushNamed(context, Routes.notificationPage);
                    },
                    context: context,
                  );
                },
                count: notifCount,
                //     count: context.watch<UnreadNotificationsCubit>().state,

                tapSize: iconTap,
                iconSize: iconSize,
                badgeColor: colors.territoryColor,
              ),

              SizedBox(
                width: iconTap,
                height: iconTap,
                child: IconButton(
                  splashRadius: iconTap * .5,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.info);
                  },
                  icon: UiUtils.getSvg(
                    AppIcons.aboutUs,
                    height: iconSize,
                    width: iconSize,
                    color: colors.territoryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // طµظˆط±ط© ط§ظ„ط­ط³ط§ط¨: ط´ط¨ظƒط© ط£ظˆ ط£ظٹظ‚ظˆظ†ط© ط§ظپطھط±ط§ط¶ظٹط©
  Widget _buildAvatar(BuildContext context) {
    if (profileUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: profileUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (_, __) => ShimmerBox(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.circular(999),
          ),
          errorWidget: (_, __, ___) => ShimmerBox(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.circular(999),
            animate: false,
            baseColor:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final double side = constraints.biggest.shortestSide;

        // ط­ط¬ظ… ط§ظ„ط£ظٹظ‚ظˆظ†ط©: ط«ط§ط¨طھ ط¥ظ† ظˆظڈط¶ط¹طŒ ظˆط¥ظ„ط§ ظ†ط³ط¨ط© ظ…ظ† ظ‚ط·ط± ط§ظ„ط£ظپط§طھط§ط±
        double size = guestIconSize ?? (side * guestIconScale);

        if (guestIconMin != null)
          size = size < guestIconMin! ? guestIconMin! : size;
        if (guestIconMax != null)
          size = size > guestIconMax! ? guestIconMax! : size;

        return Icon(
          Icons.person,
          color: context.color.territoryColor,
          size: size,
        );
      },
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    required this.icon,
    required this.onTap,
    required this.count,
    required this.tapSize,
    required this.iconSize,
    required this.badgeColor,
  });

  final String icon;
  final VoidCallback onTap;
  final int count;
  final double tapSize;
  final double iconSize;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final bool showBadge = count > 0;
    return SizedBox(
      width: tapSize,
      height: tapSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IconButton(
              splashRadius: tapSize * .5,
              padding: EdgeInsets.zero,
              onPressed: onTap,
              icon: UiUtils.getSvg(
                icon,
                height: iconSize,
                width: iconSize,
                color: context.color.territoryColor,
              ),
            ),
          ),
          if (showBadge)
            PositionedDirectional(
              top: -2,
              end: -2,
              child: _BadgeDot(
                value: count,
                color: badgeColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String text = value > 99 ? '99+' : value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// ظ„ط¥ط¸ظ‡ط§ط± ظ‚ظٹظ…ط© ط§ظ„ط´ط§ط±ط© ط¯ط§ط®ظ„ ط§ظ„ظ€Center ط¨ط¯ظˆظ† ط¥ط¹ط§ط¯ط© ط¨ظ†ط§ط، ط§ظ„ط´ظƒظ„
extension on _BadgeDot {
  Widget build(BuildContext context) {
    final String text = value > 99 ? '99+' : value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// ظ†ظپط³ ط§ظ„ط´ظٹظ…ط± ط§ظ„ط³ط§ط¨ظ‚ ظ„ظƒظ† ظƒط¯ط§ظ„ط© ظˆط§ط¬ظ‡ط©

Widget homeShimmerEffect(BuildContext context) {
  const double horizontalPadding = 18.0;
  const double sectionGap = 18.0;

  Widget sectionHeader(double titleWidth, double actionWidth) {
    return Row(
      children: [
        ShimmerBox(
          height: 16,
          width: titleWidth,
          borderRadius: BorderRadius.circular(10),
        ),
        const Spacer(),
        ShimmerBox(
          height: 12,
          width: actionWidth,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 20,
      horizontal: horizontalPadding,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ShimmerBox(
          height: 50,
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        const SizedBox(height: sectionGap),
        const ShimmerBox(
          height: 180,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        const SizedBox(height: sectionGap),
        sectionHeader(160, 68),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => const Column(
              children: [
                ShimmerBox(
                  height: 56,
                  width: 56,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                SizedBox(height: 8),
                ShimmerBox(
                  height: 10,
                  width: 60,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: sectionGap),
        sectionHeader(150, 72),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: ShimmerBox(
                height: 110,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ShimmerBox(
                height: 110,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ],
        ),
        const SizedBox(height: sectionGap),
        sectionHeader(180, 82),
        const SizedBox(height: 12),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) => const _HomeGridCardShimmer(),
        ),
        const SizedBox(height: sectionGap),
        sectionHeader(150, 70),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => const SizedBox(
              width: 220,
              child: _HomeWideCardShimmer(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _BottomNavShimmer(),
      ],
    ),
  );
}

class _HomeGridCardShimmer extends StatelessWidget {
  const _HomeGridCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        ShimmerBox(
          height: 140,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        SizedBox(height: 10),
        ShimmerBox(
          height: 12,
          width: 120,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        SizedBox(height: 6),
        ShimmerBox(
          height: 12,
          width: 80,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ],
    );
  }
}

class _HomeWideCardShimmer extends StatelessWidget {
  const _HomeWideCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        ShimmerBox(
          height: 120,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        SizedBox(height: 12),
        ShimmerBox(
          height: 12,
          width: 140,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        SizedBox(height: 8),
        ShimmerBox(
          height: 12,
          width: 90,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ],
    );
  }
}

class _BottomNavShimmer extends StatelessWidget {
  const _BottomNavShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          const ShimmerBox(
            height: 64,
            width: double.infinity,
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                4,
                (index) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShimmerBox(
                      width: 30,
                      height: 30,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    SizedBox(height: 6),
                    ShimmerBox(
                      width: 42,
                      height: 8,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            child: ShimmerBox(
              width: 64,
              height: 64,
              borderRadius: BorderRadius.all(Radius.circular(32)),
            ),
          ),
        ],
      ),
    );
  }
}

/// ظˆط§ط¬ظ‡ط© ط¹ظ†ط§طµط± "ط§ظ„ظƒظ„"
class AllItemsWidget extends StatelessWidget {
  const AllItemsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchHomeAllItemsCubit, FetchHomeAllItemsState>(
      builder: (context, state) {
        if (state is FetchHomeAllItemsSuccess) {
          if (state.items.isNotEmpty) {
            return GridListAdapter(
              type: ListUiType.Mixed,
              mixMode: true,
              crossAxisCount: 2,
              height: (MediaQuery.of(context).size.height / 3.5).rh(context),
              total: state.items.length,
              trailing: state.isLoadingMore ? UiUtils.progress() : null,
              builder: (context, int index, bool isGrid) {
                final ItemModel item = state.items[index];

                if (isGrid) {
                  return ICard(item: item, width: 192);
                }

                return InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      Routes.adDetailsScreen,
                      arguments: {'model': item},
                    );
                  },
                  child: ItemHorizontalCard(
                    item: item,
                    showLikeButton: true,
                    additionalImageWidth: 8,
                  ),
                );
              },
            );
          } else {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
        }
        if (state is FetchHomeAllItemsFail) {
          if (state.error is ApiException) {
            if (state.error.error == "no-internet") {
              return const SliverToBoxAdapter(
                  child: Center(child: NoInternet()));
            }
          }
          return const SliverToBoxAdapter(child: SomethingWentWrong());
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }
}
