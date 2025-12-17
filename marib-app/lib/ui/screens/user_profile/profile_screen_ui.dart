part of "profile_screen.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with
        AutomaticKeepAliveClientMixin<ProfileScreen>,
        RouteAware,
        ProfileScreenLogic<ProfileScreen> {
  final ValueNotifier<bool> _isDark = ValueNotifier(false);
  late final ValueNotifier<bool> _verificationBadgeLoading;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier(0);
  final InAppReview _inAppReview = InAppReview.instance;
  ModalRoute<dynamic>? _route;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _verificationBadgeLoading =
        ValueNotifier<bool>(HiveUtils.isUserAuthenticated());
    _isDark.value = context.read<AppThemeCubit>().isDarkMode();
    _scroll.addListener(() => _scrollY.value = _scroll.offset);
    _fetchVerificationRequests();
  }

  @override
  void dispose() {
    _isDark.dispose();
    _verificationBadgeLoading.dispose();
    _scroll.dispose();
    _scrollY.dispose();
    if (_route != null) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && _route != route) {
      if (_route != null) {
        routeObserver.unsubscribe(this);
      }
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _fetchVerificationRequests();
  }

  @override
  void didPush() {
    _fetchVerificationRequests();
  }

  void _fetchVerificationRequests() {
    final bool isAuthenticated = HiveUtils.isUserAuthenticated();
    if (!isAuthenticated) {
      if (_verificationBadgeLoading.value) {
        _verificationBadgeLoading.value = false;
      }
      return;
    }

    final currentState = context.read<FetchVerificationRequestsCubit>().state;
    if (currentState is FetchVerificationRequestInProgress) {
      return;
    }

    _verificationBadgeLoading.value = true;
    context.read<FetchVerificationRequestsCubit>().fetchVerificationRequests();
  }

  void _toggleLanguage() {
    final settingsCubit = context.read<FetchSystemSettingsCubit>();
    final List<dynamic>? languages =
        settingsCubit.getSetting(SystemSetting.language) as List<dynamic>?;

    if (languages == null || languages.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'somethingWentWrong'.translate(context),
      );
      return;
    }

    final dynamic storedLanguage = HiveUtils.getLanguage();
    String? currentCode;

    if (storedLanguage is Map && storedLanguage['code'] is String) {
      currentCode = storedLanguage['code'] as String;
    }

    final int currentIndex = languages.indexWhere(
      (lang) => lang is Map && lang['code'] == currentCode,
    );

    final int nextIndex =
        currentIndex >= 0 ? (currentIndex + 1) % languages.length : 0;
    final dynamic nextLanguage = languages[nextIndex];

    if (nextLanguage is! Map || nextLanguage['code'] is! String) {
      HelperUtils.showSnackBarMessage(
        context,
        'somethingWentWrong'.translate(context),
      );
      return;
    }

    context
        .read<FetchLanguageCubit>()
        .getLanguage(nextLanguage['code'] as String);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final int? userType = HiveUtils.getUserDetails().userType;
    final bool isCommercial = userType == 3; // احتياطي لو احتجته لاحقًا

    return BlocListener<FetchLanguageCubit, FetchLanguageState>(
      listener: (context, state) {
        if (state is FetchLanguageInProgress) {
          Widgets.showLoader(context);
        } else if (state is FetchLanguageSuccess) {
          Widgets.hideLoder(context);
          final Map<String, dynamic> map = state.toMap();
          map['data'] = state.data;
          map.remove('file_name');
          HiveUtils.storeLanguage(map);
          context.read<LanguageCubit>().emit(LanguageLoader(map));
          context.read<FetchCategoryCubit>().fetchCategories();
        } else if (state is FetchLanguageFailure) {
          Widgets.hideLoder(context);
          HelperUtils.showSnackBarMessage(context, state.errorMessage);
        }
      },
      child: AnnotatedRegion(
        value: UiUtils.getSystemUiOverlayStyle(
          context: context,
          statusBarColor: context.color.secondaryColor,
        ),
        child: Scaffold(
          backgroundColor: context.color.primaryColor,
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
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: BlocListener<FetchVerificationRequestsCubit,
                    FetchVerificationRequestState>(
                  listener: (context, state) {
                    if (!HiveUtils.isUserAuthenticated()) {
                      if (_verificationBadgeLoading.value) {
                        _verificationBadgeLoading.value = false;
                      }
                      return;
                    }

                    final bool isLoading =
                        state is FetchVerificationRequestInProgress ||
                            state is FetchVerificationRequestInitial;
                    if (_verificationBadgeLoading.value != isLoading) {
                      _verificationBadgeLoading.value = isLoading;
                    }
                  },
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrollY,
                    builder: (_, y, __) {
                      final double shift = (y * 0.06).clamp(0, 24);
                      return Transform.translate(
                        offset: Offset(0, -shift),
                        child: _ProfileGlassCard(
                          isDark: _isDark.value,
                          verificationBadgeLoadingNotifier:
                              _verificationBadgeLoading,
                        ),
                      );
                    },
                  ),
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
                      // الملف الشخصي
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

                      // تقييماتي
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

                      // إعلاناتي المروّجة
                      _ServiceItemTile(
                        title: "إعلاناتي المروّجة",
                        svg: AppIcons.promoted,
                        onTap: () {
                          UiUtils.checkUser(
                            onNotGuest: () {
                              //    APICallTrigger.trigger(); // تفعيل إعادة الجلب في شاشة الإعلانات المروّجة
                              Navigator.pushNamed(
                                  context, Routes.myAdvertisment);
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
                          title:
                              "التحديث متاح  •  v${Constant.newVersionNumber}",
                          svg: AppIcons.update,
                          onTap: () async {
                            if (Platform.isIOS) {
                              await launchUrl(
                                  Uri.parse(Constant.appstoreURLios));
                            } else if (Platform.isAndroid) {
                              await launchUrl(
                                  Uri.parse(Constant.playstoreURLAndroid));
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      // ─────────── بقية البنود كما هي ───────────

                      _ServiceItemTile(
                        title: "المسابقات",
                        svg: AppIcons.competition,
                        onTap: () {
                          UiUtils.checkUser(
                            onNotGuest: () => Navigator.pushNamed(
                                context, Routes.competition),
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
                        title: "تبديل اللغة",
                        svg: AppIcons.language,
                        onTap: _toggleLanguage,
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

                      // (ملاحظة): تم إزالة كرت التحديث من الأسفل لأنه أصبح فوق تحت "تقييماتي"

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
                                          "+${HiveUtils.getCountryCode()}",
                                          "")) {
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
      ),
    );
  }
}

class _ProfileGlassCard extends StatelessWidget {
  final bool isDark;
  final ValueNotifier<bool> verificationBadgeLoadingNotifier;

  const _ProfileGlassCard({
    required this.isDark,
    required this.verificationBadgeLoadingNotifier,
  });

  String _formatJoined(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    DateTime? dt = DateTime.tryParse(raw);
    if (dt != null) {
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return 'تاريخ الانضمام: $dd/$mm/$yyyy';
    }
    final dateOnly = raw.split(' ').first;
    final parts = dateOnly.split('-');
    if (parts.length == 3) {
      final yyyy = parts[0],
          mm = parts[1].padLeft(2, '0'),
          dd = parts[2].padLeft(2, '0');
      return 'تاريخ الانضمام: $dd/$mm/$yyyy';
    }
    return 'تاريخ الانضمام: $dateOnly';
  }

  @override
  Widget build(BuildContext context) {
    final user = HiveUtils.getUserDetails();
    final String name =
        (user.name ?? "").trim().isEmpty ? "مستخدم" : user.name!;
    final int? type = user.userType; // 1 فردي، 2 عقاري، 3 تجاري
    final _AccountStyle style = _AccountStyle.fromType(context, type);
    final String joined = _formatJoined(user.createdAt);
    final verificationState =
        context.watch<FetchVerificationRequestsCubit>().state;
    VerificationRequestModel? verificationRequest;
    if (verificationState is FetchVerificationRequestSuccess) {
      verificationRequest = verificationState.data;
    } else if (verificationState is FetchVerificationRequestFail) {
      verificationRequest = HiveUtils.getCachedVerificationRequest();
    }

    final String? verificationStatus =
        verificationRequest?.status?.trim().toLowerCase();
    final DateTime? verificationExpiresAt = verificationRequest?.expiresAt;
    final bool expired = verificationExpiresAt != null &&
        verificationExpiresAt.isBefore(DateTime.now());
    final bool approvedActive =
        verificationStatus == 'approved' && !expired;
    final bool fallbackVerified =
        (verificationStatus == null || verificationStatus.isEmpty) &&
            (user.isVerified ?? 0) == 1 &&
            !expired;
    final bool isVerified = approvedActive || fallbackVerified;
    final bool hasExistingRequest =
        verificationStatus != null && verificationStatus.isNotEmpty;
    final String? statusForBadge = hasExistingRequest
        ? verificationStatus
        : (isVerified ? 'approved' : verificationStatus);
    final bool showVerificationButton =
        !isVerified && HiveUtils.isUserAuthenticated() && !hasExistingRequest;

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
                  child: (user.profile ?? "").isEmpty
                      ? Container(
                          color: context.color.backgroundColor,
                          alignment: Alignment.center,
                          child: UiUtils.getSvg(AppIcons.defaultPersonLogo,
                              color: style.base, fit: BoxFit.none),
                        )
                      : UiUtils.getImage(
                          height: 70,
                          width: 70,
                          user.profile!,
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(name)
                              .bold(weight: FontWeight.w800)
                              .size(context.font.large + 1)
                              .color(context.color.textColorDark),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<bool>(
                          valueListenable: verificationBadgeLoadingNotifier,
                          builder: (context, badgeLoading, _) {
                            void handleVerificationTap() {
                              if (isVerified || hasExistingRequest) {
                                showVerificationSubscriptionSheet(
                                  context,
                                  status: statusForBadge,
                                  expiresAt: verificationExpiresAt,
                                  isVerified: isVerified,
                                );
                                return;
                              }

                              Navigator.of(context)
                                  .pushNamed(Routes.accountVerificationInfo);
                            }

                            return VerificationBadgeAnimated(
                              isLoading: badgeLoading,
                              showVerificationButton: showVerificationButton,
                              isVerified: isVerified,
                              status: statusForBadge,
                              expiresAt: verificationExpiresAt,
                              onVerifyTap: handleVerificationTap,
                              onStatusTap: handleVerificationTap,
                            );
                          },
                        ),
                      ],
                    ),
                    if (user.id != null) ...[
                      const SizedBox(height: 6),
                      Text('#${user.id}')
                          .size(context.font.normal)
                          .color(context.color.textDefaultColor)
                          .bold(weight: FontWeight.w600),
                    ],
                    const SizedBox(height: 10),
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

Widget _resolveVerificationBadge({
  required BuildContext context,
  required bool isVerified,
  required String? status,
  required DateTime? expiresAt,
}) {
  final normalized = (status ?? '').trim().toLowerCase();
  final bool expired = expiresAt != null && expiresAt.isBefore(DateTime.now());

  Widget badge({required String label, required Color color}) {
    return InkWell(
      onTap: () => showVerificationSubscriptionSheet(
        context,
        status: status,
        expiresAt: expiresAt,
        isVerified: isVerified,
      ),
      borderRadius: BorderRadius.circular(18),
      child: _StatusBadge(label: label, color: color),
    );
  }

  if (isVerified && !expired) {
    return badge(label: "موثَّق", color: Colors.green);
  }

  if (normalized == 'approved' && !expired) {
    return badge(label: "موثَّق", color: Colors.green);
  }

  if (normalized == 'pending' || normalized == 'resubmitted') {
    return badge(label: "جاري المراجعة", color: Colors.amber);
  }

  if (normalized == 'rejected') {
    return badge(label: "تم الرفض", color: Colors.red);
  }

  return badge(label: "غير موثّق", color: Colors.blueGrey);
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
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

    // â•ھâ”¤â•ھâ–’â”کأ¨â•ھâ•– â•ھط«â”کأ§â•ھآ»â•ھط« â”کأ â•ھط³â”کآ„ _ServiceItemTile
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
              // â‰،ط§ظ‘أھ â”کآ†â”کآپâ•ھâ”‚ â•ھط¯â•ھâ–’â•ھط²â”کآپâ•ھط¯â•ھâ•£ â•ھط¯â”کآ„â•ھآ«â•ھآ»â”کأ â•ھط¯â•ھط²
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

              // â•ھط¯â”کآ„â•ھâ”¤â•ھâ–’â”کأ¨â•ھâ•– â•ھط¯â”کآ„â•ھط´â•ھط¯â”کآ†â•ھط°â”کأ¨ â”کآ†â”کآپâ•ھâ”‚â”کأ§
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
                textDirection: TextDirection.ltr,
                // â•ھط«â”کأ¨â”کأ©â”کأھâ”کآ†â•ھط± â”کأ¨â”کأ â”کأ¨â”کآ†â•ھأ® â•ھâ”‚â”کأھâ”کأ¨â•ھط²â•ھâ”¤ â”کأ¨â•ھâ”‚â•ھط¯â•ھâ–’
                children: [
                  // â•ھط¯â”کآ„â•ھâ”‚â”کأھâ”کأ¨â•ھط²â•ھâ”¤ â”کأ¨â•ھâ”‚â•ھط¯â•ھâ–’ (adaptive â•ھâ”¤â”کأ¢â”کآ„â”کأ§ â•ھط«â•ھط´â”کأ â”کآ„)
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

                  // â•ھط¯â”کآ„â”کآ†â•ھâ•، â”کأھâ•ھâ”‚â•ھâ•–
                  Expanded(
                    child: Text(v ? "المظهر الداكن" : "المظهر الفاتح",
                            textAlign: TextAlign.center)
                        .bold(weight: FontWeight.w600)
                        .size(context.font.normal)
                        .color(context.color.textColorDark),
                  ),

                  const SizedBox(width: 12),

                  // â•ھط¯â”کآ„â•ھط«â”کأ¨â”کأ©â”کأھâ”کآ†â•ھط± â”کأ¨â”کأ â”کأ¨â”کآ† â”کأ â•ھâ•£ â•ھط«â”کآ†â”کأ¨â”کأ â”کأ¨â•ھâ”¤â”کآ†
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
 *  â”کأ©â•ھط¯â•ھط®â”کأ â•ھط± "â•ھط¯â•ھâ”‚â•ھط²â”کأ¢â•ھâ”¤â”کآپ"
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
              child: Text("اكتشف المزيد")
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
 *  â•ھâ•£â”کآ†â•ھط¯â•ھâ•،â•ھâ–’ â”کأ â•ھâ”‚â•ھط¯â•ھâ•£â•ھآ»â•ھط± â”کأ©â•ھâ•،â”کأ¨â•ھâ–’â•ھط±
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
 * â•ھâ•،â”کآپâ”کأھâ”کآپ â•ھط´â•ھط¯â”کأ§â•ھâ–“â•ھط± â•ھط°â”کأ©â”کأ¨â•ھط² â”کأ¢â”کأ â•ھط¯ â”کأ§â”کأ¨ â”کآ„â•ھآ»â”کأ¨â”کأ¢:
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

    // â”کآ„â”کأھâ”کآ† â•ھط¯â”کآ„â•ھâ”¤â•ھâ–’â”کأ¨â•ھâ•– â•ھط«â”کأ§â•ھآ»â•ھط« â”کأ â”کآ† â”کآ„â”کأھâ”کآ† â•ھط¯â”کآ„â”کأ§â”کأھâ”کأ¨â•ھط± (â”کآ†â”کآپâ•ھâ”‚ â•ھط¯â”کآ„â”کأ§â”کأ¨â”کأھ â”کآ„â”کأ¢â”کآ† â•ھط²â•ھâ”¤â•ھط°â”کظ‘â•ھâ•£ â•ھط«â”کأ©â”کآ„ â”کأھâ•ھط­â•ھâ•¢â•ھط¯â•ھط©â•ھط± â•ھط«â•ھâ•£â”کآ„â”کأ« â”کأ©â”کآ„â”کأ¨â”کآ„â”کأ¯â•ھط¯)
    final _hsl = HSLColor.fromColor(accent);
    final barBase = _hsl
        .withSaturation((_hsl.saturation * 0.45).clamp(0.0, 1.0))
        .withLightness((_hsl.lightness * 1.05).clamp(0.0, 1.0))
        .toColor();

    return _Pressable(
      onTap: onTap,
      child: ClipRRect(
        // â”کأ¨â•ھâ•¢â”کأ â”کآ† â•ھط²â•ھâ•–â•ھط¯â•ھط°â”کأ© â•ھط¯â”کآ„â•ھطµâ”کأھâ•ھط¯â”کآپ â”کأ â•ھâ•£ â•ھط«â”کأ¨ â•ھط«â”کآ†â”کأ¨â”کأ â”کأ¨â•ھâ”¤â”کآ†/â•ھâ”‚â”کأ¢â”کأ¨â”کآ„
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

          // â•ھط¯â”کآ„â•ھâ”¤â•ھâ–’â”کأ¨â•ھâ•– â•ھط´â•ھâ–“â•ھط© â•ھط«â•ھâ”‚â•ھط¯â•ھâ”‚â”کأ¨ â”کأ â”کآ† â•ھط¯â”کآ„â•ھâ–“â•ھâ–’ (â”کآ„â•ھط¯ â”کأ¨â•ھط²â•ھط«â•ھط³â•ھâ–’ â•ھط°â”کأ â”کأ©â•ھط¯â•ھâ”‚â•ھط¯â•ھط² â•ھط¯â”کآ„â•ھâ”¤â•ھط¯â•ھâ”¤â•ھط¯â•ھط²)
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                barBase.withOpacity(0.40),
                // â•ھط«â”کأ©â”کأھâ”کأ« â•ھâ•£â”کآ†â•ھآ» â•ھط¯â”کآ„â•ھطµâ•ھط¯â”کآپâ•ھط±
                barBase.withOpacity(0.18),
                // â”کأ¨â•ھط²â•ھآ»â•ھâ–’â”کظ‘â•ھط´ â”کآ„â”کآ„â•ھآ»â•ھط¯â•ھآ«â”کآ„
                Colors.transparent,
                // â”کأ¨â•ھط²â”کآ„â•ھط¯â•ھâ”¤â”کأ«
              ],
              stops: const [
                0.0,
                0.08,
                0.20
              ], // â•ھط¯â•ھâ•¢â•ھط°â•ھâ•–â”کأ§â•ھط¯ â”کآ„â”کأھ â•ھط²â•ھط°â•ھâ•‘â”کأ¨â”کأ§ â•ھط«â•ھâ–’â”کآپâ•ھâ•£/â•ھط«â•ھâ•£â•ھâ–’â•ھâ•¢
            ),
          ),

          child: Row(
            textDirection: TextDirection.ltr,
            // â”کأ¨â•ھط³â•ھط°â”کظ‘â•ھط² â•ھط¯â”کآ„â•ھط«â”کأ¨â”کأ©â”کأھâ”کآ†â•ھط± â”کأ¨â”کأ â”کأ¨â”کآ† â•ھآ»â•ھط¯â•ھط®â”کأ â”کأ¯â•ھط¯
            children: [
              // â•ھط¯â”کآ„â”کآ†â•ھâ•، â•ھط°â•ھط¯â”کآ„â”کأھâ•ھâ”‚â•ھâ•–
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

              // â•ھط¯â”کآ„â•ھط«â”کأ¨â”کأ©â”کأھâ”کآ†â•ھط± â”کأ¨â”کأ â”کأ¨â”کآ† â•ھط°â”کآ„â”کأھâ”کآ† â•ھط¯â”کآ„â”کأ§â”کأھâ”کأ¨â•ھط± â•ھط¯â”کآ„â”کأ¢â•ھط¯â”کأ â”کآ„
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
