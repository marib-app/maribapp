part of 'profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with
        AutomaticKeepAliveClientMixin<ProfileScreen>,
        ProfileScreenLogic<ProfileScreen> {
  final ValueNotifier<bool> _isDark = ValueNotifier(false);
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier(0);
  final InAppReview _inAppReview = InAppReview.instance;
  StreamSubscription<ThemeState>? _themeSubscription;

  void _onThemeChanged(bool isDark) {
    if (_isDark.value != isDark) {
      _isDark.value = isDark;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final appThemeCubit = context.read<AppThemeCubit>();
    _onThemeChanged(appThemeCubit.isDarkMode());
    _themeSubscription = appThemeCubit.stream.listen((state) {
      if (!mounted) return;
      _onThemeChanged(state.appTheme == AppTheme.dark);
    });

    _scroll.addListener(() => _scrollY.value = _scroll.offset);
  }

  @override
  void dispose() {
    _themeSubscription?.cancel();
    _isDark.dispose();
    _scroll.dispose();
    _scrollY.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final int? userType = HiveUtils.getUserDetails().userType;
    final bool isCommercial = userType == Constant.accountTypeSeller;

    final Widget view = AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.primaryColor,

        // AppBar أعلى قليلًا مع زر خروج
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: UiUtils.buildAppBar(
            context,
            showBackButton: false,
            bottomHeight: 0,
            title: "myProfile".translate(context),
            actions: [
              if (HiveUtils.isUserAuthenticated())
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 8),
                  child: _IconSquareButton(
                    svg: AppIcons.logout,
                    onTap: () => logOutConfirmWidget(),
                  ),
                ),
              const SizedBox(width: 10),
            ],
          ),
        ),

        body: CustomScrollView(
          controller: _scroll,
          physics: AppScrollBehavior.defaultPhysics,
          slivers: [
            // بطاقة البروفايل الزجاجية
            SliverToBoxAdapter(
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollY,
                builder: (_, y, __) {
                  final double shift = (y * 0.06).clamp(0, 24);
                  return Transform.translate(
                    offset: Offset(0, -shift),
                    child: isCommercial
                        ? BlocBuilder<MerchantStoreCubit, MerchantStoreState>(
                            builder: (_, state) => _ProfileGlassCard(
                              isDark: _isDark.value,
                              storeSnapshot: state.snapshot,
                            ),
                          )
                        : _ProfileGlassCard(isDark: _isDark.value),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // القائمة الرئيسية (عمودية بكروت بنفس الثيم)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCommercial)
                      BlocBuilder<MerchantStoreCubit, MerchantStoreState>(
                        builder: (_, state) {
                          final bool allowAccess =
                              state.snapshot?.isApproved ?? false;
                          return _ServiceItemTile(
                            title: "لوحة المتجر",
                            svg: AppIcons.home,
                            onTap: () {
                              UiUtils.checkUser(
                                onNotGuest: () {
                                  if (!allowAccess) {
                                    showStoreReviewDialog(
                                      context,
                                      variant:
                                          StoreReviewDialogVariant.management,
                                    );
                                    return;
                                  }
                                  Navigator.pushNamed(
                                      context, Routes.merchantDashboard);
                                },
                                context: context,
                              );
                            },
                          );
                        },
                      )
                    else
                      _ServiceItemTile(
                        title: "الملف الشخصي ",
                        svg: AppIcons.profileNavActive,
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
                        },
                      ),
                    const SizedBox(height: 10),
                    // تقييمي
                    _ServiceItemTile(
                      title: "تقييماتي",
                      svg: AppIcons.myReviewIcon,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () => Navigator.pushNamed(
                              context, Routes.myReviewsScreen),
                          context: context,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // ─────────── العناصر المطلوبة أسفل "تقييماتي" ───────────

                    // إعلاناتي المروّجة
                    _ServiceItemTile(
                      title: "إعلاناتي المروّجة",
                      svg: AppIcons.promoted,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () {
                            //    APICallTrigger.trigger(); // تفعيل إعادة الجلب في شاشة الإعلانات المروّجة
                            Navigator.pushNamed(context, Routes.myAdvertisment);
                          },
                          context: context,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // الاشتراكات
                    _ServiceItemTile(
                      title: "الاشتراكات",
                      svg: AppIcons.subscription,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () => Navigator.pushNamed(
                              context, Routes.subscriptionPackageListRoute),
                          context: context,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _ServiceItemTile(
                      title: "المحفظة".translate(context),
                      svg: AppIcons.money,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () =>
                              Navigator.pushNamed(context, Routes.wallet),
                          context: context,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _ServiceItemTile(
                      title: "طلباتي",
                      svg: AppIcons.competition,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () =>
                              Navigator.pushNamed(context, Routes.ordersList),
                          context: context,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // كرت "التحديث متاح" (شرطي) — نُقِل هنا أسفل تقييماتي
                    if (Constant.isUpdateAvailable == true) ...[
                      _ServiceItemTile(
                        title: "التحديث متاح  •  v${Constant.newVersionNumber}",
                        svg: AppIcons.update,
                        onTap: () async {
                          if (Platform.isIOS) {
                            await launchUrl(Uri.parse(Constant.appstoreURLios));
                          } else if (Platform.isAndroid) {
                            await launchUrl(
                                Uri.parse(Constant.playstoreURLAndroid));
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    //

                    // ─────────── بقية البنود كما هي ───────────

                    _ServiceItemTile(
                      title: "المسابقات",
                      svg: AppIcons.competition,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () =>
                              Navigator.pushNamed(context, Routes.competition),
                          context: context,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _ServiceItemTile(
                      title: "المفضلة",
                      svg: AppIcons.favorites,
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () => Navigator.pushNamed(
                              context, Routes.favoritesScreen),
                          context: context,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    _ServiceItemTile(
                      title: "تجربة الدفع",
                      svg: AppIcons.favorites, // يمكنك استبدال الأيقونة لاحقًا
                      onTap: () {
                        UiUtils.checkUser(
                          onNotGuest: () =>
                              Navigator.pushNamed(context, Routes.soon),
                          context: context,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // تبديل الثيم
                    _ThemeSwitchTile(
                      isDark: _isDark,
                      onToggle: () {
                        final v = !_isDark.value;
                        context
                            .read<AppThemeCubit>()
                            .changeTheme(v ? AppTheme.dark : AppTheme.light);
                        _isDark.value = v;
                      },
                    ),
                    const SizedBox(height: 10),

                    // قيّمنا
                    _ServiceItemTile(
                      title: "قيّمنا",
                      svg: AppIcons.rateUs,
                      onTap: () => _inAppReview.openStoreListing(
                        appStoreId: Constant.iOSAppId,
                        microsoftStoreId: 'microsoftStoreId',
                      ),
                    ),

                    // (ملاحظة): تمت إزالة كرت التحديث من الأسفل لأنه أصبح فوق تحت "تقييماتي"

                    // حذف الحساب (للمسجلين فقط)
                    if (HiveUtils.isUserAuthenticated()) ...[
                      const SizedBox(height: 10),
                      _ServiceItemTile(
                        title: "حذف الحساب",
                        svg: AppIcons.delete,
                        onTap: () {
                          if (Constant.isDemoModeOn) {
                            final mobile = HiveUtils.getUserDetails().mobile;
                            if (mobile != null &&
                                Constant.demoMobileNumber ==
                                    mobile.replaceFirst(
                                        "+${HiveUtils.getCountryCode()}", "")) {
                              HelperUtils.showSnackBarMessage(
                                context,
                                "thisActionNotValidDemo".translate(context),
                              );
                              return;
                            }
                          }
                          deleteConfirmWidget();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );

    if (!isCommercial) {
      return view;
    }

    return BlocProvider<MerchantStoreCubit>(
      create: (_) => MerchantStoreCubit()..load(),
      child: view,
    );
  }
}

/* =========================
 *  بطاقة البروفايل (كما هي)
 * ========================= */

class _ProfileGlassCard extends StatelessWidget {
  final bool isDark;
  final MerchantStoreSnapshot? storeSnapshot;

  const _ProfileGlassCard({
    required this.isDark,
    this.storeSnapshot,
  });

  String _formatJoined(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    DateTime? dt = DateTime.tryParse(raw);
    if (dt != null) {
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return 'تم الانضمام في : $dd/$mm/$yyyy';
    }
    final dateOnly = raw.split(' ').first;
    final parts = dateOnly.split('-');
    if (parts.length == 3) {
      final yyyy = parts[0],
          mm = parts[1].padLeft(2, '0'),
          dd = parts[2].padLeft(2, '0');
      return 'تم الانضمام في : $dd/$mm/$yyyy';
    }
    return 'تم الانضمام في : $dateOnly';
  }

  @override
  Widget build(BuildContext context) {
    final user = HiveUtils.getUserDetails();
    final int? type = user.userType; // 1 فردي، 2 عقاري، 3 تجاري
    final bool isMerchantAccount = type == Constant.accountTypeSeller;
    final String resolvedMerchantName =
        MerchantDisplayHelper.resolveDisplayName(
      isMerchant: isMerchantAccount,
      store: user.store,
      additionalInfo: user.additionalInfo,
      fallbackName: user.name,
    );
    final String fallbackName = (user.name ?? "").trim().isEmpty
        ? "anonymous".translate(context)
        : user.name!;
    final String name = resolvedMerchantName.trim().isNotEmpty
        ? resolvedMerchantName.trim()
        : fallbackName;
    final _AccountStyle style = _AccountStyle.fromType(context, type);
    final String joined = _formatJoined(user.createdAt);
    final bool showPendingBadge = storeSnapshot?.isPendingReview ?? false;
    final String? profileImage = MerchantDisplayHelper.resolveProfileImage(
      isMerchant: isMerchantAccount,
      store: user.store,
      fallbackImage: user.profile,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 0),
      child: _Pressable(
        scaleDown: 0.98,
        child: Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 30),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: context.color.textDefaultColor.withOpacity(0.10)),
                ),
                child: ClipOval(
                  child: (profileImage ?? "").isEmpty
                      ? Container(
                          color: context.color.backgroundColor,
                          alignment: Alignment.center,
                          child: UiUtils.getSvg(AppIcons.defaultPersonLogo,
                              color: style.base, fit: BoxFit.none),
                        )
                      : UiUtils.getImage(
                          height: 70,
                          width: 70,
                          profileImage!,
                          fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name)
                              .bold(weight: FontWeight.w800)
                              .size(context.font.large + 1)
                              .color(context.color.textColorDark),
                        ),
                        const SizedBox(width: 8),
                        if ((user.isVerified ?? 0) != 1)
                          _VerifyAccountPill(
                            onTap: () => Navigator.of(context)
                                .pushNamed(Routes.accountVerificationInfo),
                          )
                        else
                          const _VerifiedBadge(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (showPendingBadge) ...[
                      _StoreReviewBadge(compact: false),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.color.secondaryColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: style.base.withOpacity(0.18)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(style.icon, size: 16, color: style.base),
                          const SizedBox(width: 10),
                          Text(style.label(context),
                              style: TextStyle(
                                  color: style.base,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    if (joined.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(joined)
                          .size(context.font.small)
                          .color(context.color.textDefaultColor),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountStyle {
  final Color base;
  final IconData icon;
  final int? type;

  _AccountStyle(this.base, this.icon, this.type);

  factory _AccountStyle.fromType(BuildContext context, int? type) {
    switch (type) {
      case 2:
        return _AccountStyle(Colors.green, Icons.house_rounded, type);
      case 3:
        return _AccountStyle(Colors.orange, Icons.store_rounded, type);
      case 1:
      default:
        return _AccountStyle(Colors.blue, Icons.person_rounded, type);
    }
  }

  String label(BuildContext context) {
    switch (type) {
      case 1:
        return 'individual'.translate(context);
      case 2:
        return 'realEstate'.translate(context);
      case 3:
        return 'commercial'.translate(context);
      default:
        return 'notSpecified'.translate(context);
    }
  }
}

class _VerifyAccountPill extends StatelessWidget {
  final VoidCallback onTap;

  const _VerifyAccountPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        side: BorderSide(color: context.color.territoryColor, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor:
            context.color.territoryColor.withOpacity(isDark ? 0.12 : 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined,
              size: 17, color: context.color.territoryColor),
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

class _StoreReviewBadge extends StatelessWidget {
  const _StoreReviewBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.color.territoryColor;
    final Color background = accent.withOpacity(0.12);
    final double fontSize =
        compact ? context.font.small : context.font.small + 0.5;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_bottom,
            size: compact ? 14 : 16,
            color: accent,
          ),
          const SizedBox(width: 6),
          Text(
            'storePendingBadge'.translate(context),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSwitchTile extends StatelessWidget {
  final ValueNotifier<bool> isDark;
  final VoidCallback onToggle;

  const _ThemeSwitchTile({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final accent = context.color.territoryColor;

    // شريط أهدأ مثل _ServiceItemTile
    final _hsl = HSLColor.fromColor(accent);
    final barBase = _hsl
        .withSaturation((_hsl.saturation * 0.45).clamp(0.0, 1.0))
        .withLightness((_hsl.lightness * 1.05).clamp(0.0, 1.0))
        .toColor();

    return ValueListenableBuilder<bool>(
      valueListenable: isDark,
      builder: (_, v, __) {
        return _Pressable(
          onTap: onToggle,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              // 👈 نفس ارتفاع الخدمات
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: context.color.textDefaultColor.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),

              // الشريط الجانبي نفسه
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    barBase.withOpacity(0.40),
                    barBase.withOpacity(0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.08, 0.20],
                ),
              ),

              child: Row(
                textDirection: TextDirection.ltr, // أيقونة يمين، سويتش يسار
                children: [
                  // السويتش يسار (adaptive شكله أجمل)
                  Switch.adaptive(
                    value: v,
                    onChanged: (_) => onToggle(),
                    activeColor: Colors.white,
                    activeTrackColor: accent,
                    inactiveThumbColor: context.color.textDefaultColor,
                    inactiveTrackColor:
                        context.color.textDefaultColor.withOpacity(0.2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),

                  const SizedBox(width: 12),

                  // النص وسط
                  Expanded(
                    child: Text(v ? "الوضع الداكن" : "الوضع الفاتح",
                            textAlign: TextAlign.center)
                        .bold(weight: FontWeight.w600)
                        .size(context.font.normal)
                        .color(context.color.textColorDark),
                  ),

                  const SizedBox(width: 12),

                  // الأيقونة يمين مع أنيميشن
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) {
                      return ScaleTransition(
                        scale: CurvedAnimation(
                            parent: anim, curve: Curves.easeOutBack),
                        child: FadeTransition(opacity: anim, child: child),
                      );
                    },
                    child: v
                        ? SizedBox(
                            key: const ValueKey("dark"),
                            height: 22,
                            width: 22,
                            child: UiUtils.getSvg(AppIcons.darkTheme,
                                color: accent),
                          )
                        : SizedBox(
                            key: const ValueKey("light"),
                            height: 22,
                            width: 22,
                            child: UiUtils.getSvg(AppIcons.language,
                                color: accent),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionTab {
  final String label;
  final String svg;
  final VoidCallback? onTap;

  const _ActionTab(this.label, this.svg, {this.onTap});
}

class _TabChip extends StatelessWidget {
  final _ActionTab tab;

  const _TabChip({required this.tab});

  @override
  Widget build(BuildContext context) {
    final core = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.color.territoryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: context.color.textDefaultColor.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UiUtils.getSvg(tab.svg,
              height: 18, width: 18, color: context.color.territoryColor),
          const SizedBox(width: 8),
          Text(tab.label)
              .bold(weight: FontWeight.w700)
              .size(context.font.small)
              .color(context.color.textColorDark),
        ],
      ),
    );
    return _Pressable(onTap: tab.onTap, child: core);
  }
}

/* =========================
 *  قائمة "استكشف"
 * ========================= */
class _ExploreItem {
  final String title;
  final String svg;
  final VoidCallback onTap;

  _ExploreItem(this.title, this.svg, this.onTap);
}

class _ExploreList extends StatelessWidget {
  final List<_ExploreItem> items;

  const _ExploreList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text("استكشف")
                  .bold(weight: FontWeight.w700)
                  .size(context.font.normal)
                  .color(context.color.textColorDark),
            ),
            ...items.map((e) {
              return InkWell(
                onTap: e.onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      Text(e.title)
                          .bold(weight: FontWeight.w600)
                          .color(context.color.textColorDark),
                      const Spacer(),
                      UiUtils.getSvg(e.svg,
                          color: context.color.textDefaultColor),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

/* =========================
 *  عناصر مساعدة قصيرة
 * ========================= */
class _ThemeToggle extends StatelessWidget {
  final ValueNotifier<bool> isDark;
  final VoidCallback onToggle;

  const _ThemeToggle({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDark,
      builder: (_, v, __) {
        return _Pressable(
          onTap: onToggle,
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: context.color.textDefaultColor.withOpacity(0.12)),
            ),
            alignment: Alignment.center,
            child: AnimatedRotation(
              turns: v ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutQuart,
              child: v
                  ? UiUtils.getSvg(AppIcons.darkTheme,
                      color: context.color.textDefaultColor)
                  : UiUtils.getSvg(AppIcons.language,
                      color: context.color.textDefaultColor),
            ),
          ),
        );
      },
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  final String svg;
  final VoidCallback onTap;

  const _IconSquareButton({required this.svg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: context.color.textDefaultColor.withOpacity(0.12)),
      ),
      child: InkWell(
        onTap: onTap,
        child: UiUtils.getSvg(svg,
            height: 22, width: 22, color: context.color.textDefaultColor),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const _Pressable({required this.child, this.onTap, this.scaleDown = 0.96});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _down ? widget.scaleDown : 1.0,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

/* ==========
 * صفوف جاهزة بقيت كما هي لديك:
 *  - _UpdateRow
 *  - _DeleteAccountRow
 * ========== */

// ================== FIX: missing widgets ==================

class _UpdateRow extends StatelessWidget {
  final VoidCallback onTap;

  const _UpdateRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.color.territoryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: UiUtils.getSvg(AppIcons.update,
                  color: context.color.territoryColor),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("update".translate(context))
                    .bold(weight: FontWeight.w700)
                    .color(context.color.textColorDark),
                Text("v${Constant.newVersionNumber}")
                    .size(context.font.small)
                    .italic()
                    .color(context.color.textColorDark),
              ],
            ),
            const Spacer(),
            UiUtils.getSvg(AppIcons.arrowRight,
                color: context.color.textDefaultColor),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountRow extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteAccountRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            UiUtils.getSvg(AppIcons.delete,
                color: context.color.territoryColor),
            const SizedBox(width: 12),
            Text("deleteAccount".translate(context))
                .bold(weight: FontWeight.w700)
                .color(context.color.textColorDark),
            const Spacer(),
            UiUtils.getSvg(AppIcons.arrowRight,
                color: context.color.textDefaultColor),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final String svg;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double iconSize;
  final bool showIcon;

  const _ActionChip({
    required this.label,
    required this.svg,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.iconSize = 20,
    this.showIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final core = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: context.color.textDefaultColor.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon)
            UiUtils.getSvg(svg,
                height: iconSize,
                width: iconSize,
                color: context.color.territoryColor),
          if (showIcon) const SizedBox(width: 8),
          Flexible(
            child: Text(label)
                .bold(weight: FontWeight.w700)
                .size(context.font.normal)
                .color(context.color.textColorDark),
          ),
        ],
      ),
    );
    return onTap == null ? core : _Pressable(onTap: onTap, child: core);
  }
}

class _ServiceItemTile extends StatelessWidget {
  final String title;
  final String svg;
  final VoidCallback? onTap;

  const _ServiceItemTile({required this.title, required this.svg, this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.color.territoryColor;

    // لون الشريط أهدأ من لون الهوية (نفس الهيو لكن تشبّع أقل وإضاءة أعلى قليلًا)
    final _hsl = HSLColor.fromColor(accent);
    final barBase = _hsl
        .withSaturation((_hsl.saturation * 0.45).clamp(0.0, 1.0))
        .withLightness((_hsl.lightness * 1.05).clamp(0.0, 1.0))
        .toColor();

    return _Pressable(
      onTap: onTap,
      child: ClipRRect(
        // يضمن تطابق الحواف مع أي أنيميشن/سكيل
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: context.color.textDefaultColor.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),

          // الشريط جزء أساسي من الزر (لا يتأثر بمقاسات الشاشات)
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                barBase.withOpacity(0.40), // أقوى عند الحافة
                barBase.withOpacity(0.18), // يتدرّج للداخل
                Colors.transparent, // يتلاشى
              ],
              stops: const [0.0, 0.08, 0.20], // اضبطها لو تبغيه أرفع/أعرض
            ),
          ),

          child: Row(
            textDirection: TextDirection.ltr, // يثبّت الأيقونة يمين دائمًا
            children: [
              // النص بالوسط
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                )
                    .bold(weight: FontWeight.w600)
                    .size(context.font.normal)
                    .color(context.color.textColorDark),
              ),
              const SizedBox(width: 12),

              // الأيقونة يمين بلون الهوية الكامل
              UiUtils.getSvg(
                svg,
                height: 22,
                width: 22,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
