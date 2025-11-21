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
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
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

// ملاحظة: ProfileHeaderUI يدعم welcomeText و welcomeColor و shrinkFactor.

class HomeScreenUI extends StatelessWidget {
  // الأساسيات
  final ScrollController scrollController;
  final VoidCallback onSupportPressed;
  final List<Widget> bodySlivers;

  // إمّا تمرر ودجت جاهز للهيدر... (اختياري)
  final Widget? appBarLeading;

  // ...أو تمرر بيانات البروفايل ونبني الهيدر داخلياً (اختياري)
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

  // سطر الترحيب
  final String? userId;
  final bool showWelcomeLine;

  // خيارات إضافية
  final Future<void> Function()? onRefresh;
  final bool hideFabOnScroll;
  final double? expandedHeight;
  final Widget? appBarBackdrop;

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
  });

  @override
  Widget build(BuildContext context) {
    // قياس الهيدر
    final double kExpanded =
        expandedHeight ?? (110.0.rh(context)).clamp(100.0, 200.0);

    // القيم القادمة من البراميترز
    final String idStr = (userId ?? '').trim();
    final String paramName = (name ?? '').trim();

    // بيانات المستخدم الحقيقية من التخزين
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
        final String resolvedMerchantName = MerchantDisplayHelper
            .resolveDisplayName(
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
            return '  زائر';
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
          return '  زائر';
        })();

        final String phone = (mobile?.isNotEmpty == true)
            ? mobile!
            : (details.mobile?.toString() ?? '');
        final String? merchantAvatar = MerchantDisplayHelper.resolveProfileImage(
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
            // لا تغيّر ألوان الـAppBar
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

                      final Widget header = appBarLeading ??
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
                                ? "مرحبًا بك: $idStr"
                                : null,
                            welcomeColor: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withOpacity(.85),
                          );

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
    // ✨ لا نستخدم SingleChildScrollView ولا PrimaryScrollController هنا
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
    // انحناءة بسيطة تندمج مع أسفل الـAppBar
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

/// إخفاء/إظهار الفاب أثناء التمرير
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
      setState(() => _visible = false); // نزول → أخفِ
    } else if (curr < _last - 6 && !_visible) {
      setState(() => _visible = true); // صعود → أظهر
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
   Header UI (داخلي) مع تحجيم مرن
   ======================= */

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
    this.shrinkFactor = 1.0, // 1 موسّع، 0 منكمش
    this.welcomeText,
    this.welcomeColor,
  });

  final bool isAuthenticated;
  final String name;
  final String mobile;
  final String profileUrl;
  final bool isVerified;

  // أضف هذه الحقول مع البقية
  final double? guestIconSize; // حجم ثابت بالبكسل (إن حددته يتجاهل scale)
  final double guestIconScale; // نسبة من قطر الأفاتار (افتراضي 0.62)
  final double? guestIconMin; // حد أدنى اختياري
  final double? guestIconMax; // حد أقصى اختياري

  final int cartCount;
  final int notifCount;

  final VoidCallback onAvatarTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onInfoTap;

  final double shrinkFactor;

  final String? welcomeText; // غير مستخدم الآن
  final Color? welcomeColor; // غير مستخدم الآن

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;

        /* =============================
       * 1) مقاسات عامة تتقلّص بسلاسة
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
       * 2) الأفاتار: كبير موسّع → يتقلّص تدريجيًا
       *    (انيميشنه مستقل عن رقم الجوال/الاسم)
       * ============================================ */
        const double avatarExpandScale =
            1.70; // مقدار تكبير الأفاتار قبل التمرير
        final double maxAvatarTap = maxIconTap * avatarExpandScale;
        final double minAvatarTap =
            minIconTap * 0.82; // حجم الأفاتار عند الانكماش الكامل
        final double avatarTap =
            (minAvatarTap + (maxAvatarTap - minAvatarTap) * shrinkFactor);

        const double borderStroke = 1.0;
        const double innerPadding = 0.0;
        final double avatarRadius =
            (avatarTap / 2) - (borderStroke + innerPadding);

        /* =============================
       * 3) تباعدات عامة ونقاط ضبط
       * ============================= */
        final double hPad = (w * 0.03).clamp(8.0, 14.0);
        const double vPad = 8.0;
        final double gap = (w * 0.02).clamp(6.0, 12.0);

        final bool small = w < 360; // شاشة ضيّقة
        final double nameMin = context.font.small;
        final double nameMax = context.font.large;
        final double nameSize = nameMin +
            (nameMax - nameMin) * shrinkFactor; // حجم اسم ديناميكي (مستقل)

        /* ====================================================
       * 4) سلوك رقم الجوال: يظهر موسّع، يختفي بانكماش الهيدر
       *    (انيميشنه مستقل — لا يزاحم الاسم لأنه مُثبت بأسفل)
       * ==================================================== */
        const double phoneThreshold = 0.60; // تحتها يختفي الرقم
        final bool showPhoneNow =
            isAuthenticated && (shrinkFactor > phoneThreshold);

        /* ===================================================
       * 5) شارة التحقق: تظهر موسّع، تختفي بانكماش قوي
       *    AnimatedSwitcher حتى لا تحجز مساحة عند الإخفاء
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
             * صورة الحساب (InkWell → الملف الشخصي)
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
                        // انيميشن حجم الأفاتار مستقل وثابت النعومة
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
             * النصوص داخل مساحة ثابتة الارتفاع = ارتفاع الأفاتار
             * نستخدم Stack لتثبيت التموضع:
             *  - الشارة: أعلى يسار
             *  - الاسم: منتصف يسار (لا يتأثر بظهور/اختفاء الرقم)
             *  - الرقم: أسفل يسار (AnimatedSwitcher مستقل)
             * ============================================================ */
              Expanded(
                child: SizedBox(
                  height: avatarTap, // نفس ارتفاع الأفاتار → لا Overflow
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // (أ) الشارة أعلى الـstart بدل left
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

                      // (ب) الاسم في منتصف الـstart (محاذي للأفاتار في RTL/LTR)
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
                          }, // يفتح الملف الشخصي
                          child: Padding(
                            // نبعد الاسم شوي عن الأيقونات في الجهة المقابلة
                            padding: EdgeInsetsDirectional.only(
                              // احتياطي بسيط ناحية الـend حتى لا يلتصق بالسلة بعد الانكماش
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

                      // (ج) رقم الجوال أسفل الـstart بدل bottom/left
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
// زر الاشعارات متبقي ربط العداد
              // باقي الأيقونات مع الشارات
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

  // صورة الحساب: شبكة أو أيقونة افتراضية
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

        // حجم الأيقونة: ثابت إن وُضع، وإلا نسبة من قطر الأفاتار
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
      child: const Center(
        child: Text(
          // سيتم تعيين النص لاحقًا مع نفس النمط
          '',
          style: TextStyle(
              fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// لإظهار قيمة الشارة داخل الـCenter بدون إعادة بناء الشكل
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

/// نفس الشيمر السابق لكن كدالة واجهة

Widget homeShimmerEffect(BuildContext context) {
  const defaultPadding = 16.0;
  return Padding(
    padding:
        const EdgeInsets.symmetric(vertical: 24, horizontal: defaultPadding),
    child: Column(
      children: [
        const _ShimmerBox(h: 52),
        const SizedBox(height: 12),
        const _ShimmerBox(h: 170),
        const SizedBox(height: 24),
        const _ShimmerBox(h: 52),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 10,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.symmetric(horizontal: index == 0 ? 0 : 8.0),
              child: const Column(
                children: [
                  _ShimmerBox(h: 70, w: 66),
                  SizedBox(height: 5),
                  _ShimmerBox(h: 10, w: 48),
                  SizedBox(height: 4),
                  _ShimmerBox(h: 10, w: 60),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < 6; i++) ...[
          const _ShimmerBox(h: 52),
          const SizedBox(height: 12),
        ]
      ],
    ),
  );
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.h, this.w});

  final double h;
  final double? w;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: CustomShimmer(height: h, width: w ?? double.maxFinite),
    );
  }
}

/// واجهة عناصر "الكل"
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
