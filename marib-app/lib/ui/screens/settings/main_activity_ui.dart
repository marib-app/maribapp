import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/app/routes.dart'; // لـ Routes.selectCategoryScreen
import 'package:flutter_bloc/flutter_bloc.dart'; // لـ context.read(...)
import 'package:marib/data/cubits/subscription/fetch_user_package_limit_cubit.dart'; // نوع الكيوبت
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/ui/screens/chat/chat_badge_controller.dart';



// ===========================
// تبويبات واضحة بدل int
// ===========================
enum MainTab { home, chat, transactions, more }

typedef TabSelect = void Function(MainTab tab);
typedef CenterActionBuilder = Widget Function(BuildContext context);



// ===========================
// تعريف عنصر ناف بار
// ===========================
class MainNavItem {
  final String titleKey; // key للترجمة (مثلاً "homeTab")
  final String svg;
  final String activeSvg;
  final MainTab tab;

  const MainNavItem({
    required this.titleKey,
    required this.svg,
    required this.activeSvg,
    required this.tab,
  });
}

// ===========================
// واجهة MainActivityUI (نسختان من المُنشئ: config + متوافق قديم)
// ===========================
class MainActivityUI extends StatelessWidget {
  // ====== الحقول (Config) ======
  final PageController _pageControllerCfg;
  final MainTab _currentTabCfg;
  final int _pageCountCfg;
  final IndexedWidgetBuilder _pageBuilderCfg;

  final TabSelect _onTabSelectedCfg;
  final bool _maintenanceOnCfg;
  final Widget? _maintenanceOverlayCfg;
  final CenterActionBuilder? _centerActionBuilderCfg;
  final List<MainNavItem> _navItemsCfg;

  // ====== مُنشئ جديد قائم على Config/Enum ======
  MainActivityUI.config({
    super.key,
    required PageController pageController,
    required MainTab currentTab,
    required int pageCount,
    required IndexedWidgetBuilder pageBuilder,

    required TabSelect onTabSelected,
    bool maintenanceOn = false,
    Widget? maintenanceOverlay,
    CenterActionBuilder? centerActionBuilder,
    List<MainNavItem>? navItems,
  })  : _pageControllerCfg = pageController,
        _currentTabCfg = currentTab,
        _pageCountCfg = pageCount,
        _pageBuilderCfg = pageBuilder,
        _onTabSelectedCfg = onTabSelected,
        _maintenanceOnCfg = maintenanceOn,
        _maintenanceOverlayCfg = maintenanceOverlay,
        _centerActionBuilderCfg = centerActionBuilder,
        _navItemsCfg = navItems ??
            [
              MainNavItem(
                titleKey: "homeTab",
                svg: AppIcons.homeNav,
                activeSvg: AppIcons.homeNavActive,
                tab: MainTab.home,
              ),
              MainNavItem(
                titleKey: "chat",
                svg: AppIcons.chatNav,
                activeSvg: AppIcons.chatNavActive,
                tab: MainTab.chat,
              ),
              // (الزر الأوسط يبقى FAB منفصل)
              MainNavItem(
                titleKey: "transaction",
                svg: AppIcons.transaction,
                activeSvg: AppIcons.transactionActive,
                tab: MainTab.transactions,
              ),
              MainNavItem(
                titleKey: "more",
                svg: AppIcons.more,
                activeSvg: AppIcons.more_active,
                tab: MainTab.more,
              ),
            ];

  // ====== مُنشئ قديم (Drop-in) يبقي استدعاءك الحالي كما هو) ======
  factory MainActivityUI({
    Key? key,
    // نفس توقيعك القديم تمامًا:
    required PageController pageController,
    required int currentTab,
    required List<Widget> pages,
    required ValueChanged<int> onTabSelected,
    required bool maintenanceOn,
    required Widget maintenanceOverlay,
    required Widget centerAddButton,
  }) {
    // تحويل int -> enum
    MainTab _intToTab(int i) {
      switch (i) {
        case 0:
          return MainTab.home;
        case 1:
          return MainTab.chat;
        case 2:
          return MainTab.transactions;
        case 3:
        default:
          return MainTab.more;
      }
    }

    // محول onTabSelected(int) -> TabSelect
    TabSelect _wrapSelect(ValueChanged<int> cb) {
      return (MainTab t) {
        switch (t) {
          case MainTab.home:
            cb(0);
            break;
          case MainTab.chat:
            cb(1);
            break;
          case MainTab.transactions:
            cb(2);
            break;
          case MainTab.more:
            cb(3);
            break;
        }
      };
    }

    // Builder للزر الأوسط (نفس الودجت الممرّر)
    CenterActionBuilder centerBuilder = (ctx) => centerAddButton;

    return MainActivityUI.config(
      key: key,
      pageController: pageController,
      currentTab: _intToTab(currentTab),
      pageCount: pages.length,
      pageBuilder: (_, index) => pages[index],
      onTabSelected: _wrapSelect(onTabSelected),
      maintenanceOn: maintenanceOn,
      maintenanceOverlay: maintenanceOverlay,
      centerActionBuilder: centerBuilder,
    );
  }

  // ===========================
  // واجهة البناء
  // ===========================
  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return Scaffold(
      backgroundColor: colors.primaryColor,

      // ✅ زر الإضافة العائم (المنتصف) — مطابق للشكل السابق مع إصلاح الـHero
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 5),
        child: BlocBuilder<FetchUserPackageLimitCubit, FetchUserPackageLimitState>(
          buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
          builder: (context, state) {
            final busy = state is FetchUserPackageLimitInProgress;

            final Widget action =
                _centerActionBuilderCfg?.call(context) ?? _buildDefaultCenterAction(context, busy);

            return AbsorbPointer(
              absorbing: busy, // يمنع النقرات المكررة أثناء التحميل
              child: action,

            );
          },
        ),
      ),

      floatingActionButtonLocation: const _FixedCenterDockedFabLocation(),

      // ✅ الشريط السفلي المعتمد (كما هو)
      bottomNavigationBar: _maintenanceOnCfg
          ? null
          : ValueListenableBuilder<int>(
        valueListenable: ChatBadgeController.totalUnread,
        builder: (context, totalUnread, _) {
          final badges = <MainTab, String>{};

          if (totalUnread > 0) {
            final chatBadge = totalUnread > 99 ? '99+' : '$totalUnread';
            badges[MainTab.chat] = chatBadge;
          }

          return AnimatedBottomBar(
            items: _navItemsCfg,
            current: _currentTabCfg,
            onSelect: _onTabSelectedCfg,
            centerActionBuilder:
            _centerActionBuilderCfg ?? (ctx) => const SizedBox.shrink(),
            background: colors.secondaryColor,
            showTopShadow: true,
            badges: badges,
          );
        },
      ),

      body: Stack(
        children: [
          // ✅ ظل دائري تحت الزر العائم
          Positioned(
            bottom: 0,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEB5924).withOpacity(0.30),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),

          // ✅ المحتوى (صفحات)
          Positioned.fill(
            child: PageView.builder(
              physics: const NeverScrollableScrollPhysics(),
              controller: _pageControllerCfg,
              itemCount: _pageCountCfg,
              itemBuilder: _pageBuilderCfg,
            ),
          ),

          if (_maintenanceOnCfg) (_maintenanceOverlayCfg ?? const SizedBox.shrink()),
        ],
      ),
    );
  }



  Widget _buildDefaultCenterAction(BuildContext context, bool busy) {
    final Widget icon = busy
        ? const SizedBox(
      key: ValueKey('spinner'),
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.6,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    )
        : const Icon(
      Icons.add,
      key: ValueKey('plus'),
      size: 32,
      color: Colors.white,
    );

    return Semantics(
      button: true,
      label: "addAdvertisement".translate(context),
      child: FloatingActionButton(
        heroTag: 'add-ad-fab',
        backgroundColor: const Color(0xFFEB5924),
        elevation: 6,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: busy
            ? null
            : () {
          HapticFeedback.selectionClick();
          UiUtils.checkUser(
            context: context,
            onNotGuest: () {
              context
                  .read<FetchUserPackageLimitCubit>()
                  .fetchUserPackageLimit(packageType: "item_listing");
            },
          );
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: icon,
        ),
      ),
    );
  }
}




class _FixedCenterDockedFabLocation extends FloatingActionButtonLocation {
  const _FixedCenterDockedFabLocation();

  static const double _bottomBarHeight = 195; // 👈 كما في كودك
  static const double _extraYOffset = 8;     // 👈 كما في كودك

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final Size fabSize = geometry.floatingActionButtonSize;
    final Size scaffoldSize = geometry.scaffoldSize;

    // X: منتصف الشاشة
    final double dx = (scaffoldSize.width - fabSize.width) / 2;

    // Y: أعلى الشريط السفلي بنصف ارتفاع الـ FAB + إزاحة بسيطة
    final double dy = scaffoldSize.height
        - _bottomBarHeight / 2
        - fabSize.height / 2
        + _extraYOffset;

    return Offset(dx, dy);
  }

  @override
  String toString() => 'FixedCenterDockedFabLocation';
}

// ===========================
// الشريط السفلي: BottomAppBar + خصائص المواصفات المعتمدة
// ===========================
class AnimatedBottomBar extends StatelessWidget {
  const AnimatedBottomBar({
    super.key,
    required this.items,
    required this.current,
    required this.onSelect,
    required this.centerActionBuilder,
    this.background,
    this.showTopShadow = true,
    this.badges = const <MainTab, String>{},
    });

  final List<MainNavItem> items; // 4 عناصر (يمين 2 ويسار 2)
  final MainTab current;
  final void Function(MainTab tab) onSelect;
  final Widget Function(BuildContext) centerActionBuilder;
  final Color? background;
  final bool showTopShadow;
  final Map<MainTab, String> badges;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    final List<MainNavItem> left = items.take(2).toList();
    final List<MainNavItem> right = items.skip(2).toList();

    return BottomAppBar(
      color: background ?? colors.secondaryColor,
      elevation: 10,
      shape: const CircularNotchedRectangle(), // ✅ انحناء للزر
      notchMargin: 4.0, // ✅ مسافة حول النُتش
      clipBehavior: Clip.antiAlias, // ✅ قص فعلي للانحناء
      child: Container(
        decoration: BoxDecoration(
          color: background ?? colors.secondaryColor,
          boxShadow: showTopShadow
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              offset: const Offset(0, -2),
              blurRadius: 2,
            )
          ]
              : null,
        ),
        child: SizedBox(
          height: 80, // ✅ ارتفاع موحّد
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in left)
                _NavItemTile(
                  item: item,
                  isActive: current == item.tab,
                  onTap: () => _handleTap(item.tab),
                  badge: badges[item.tab],
                ),

              const SizedBox(width: 50), // ✅ فراغ للنُتش/FAB بالوسط

              for (final item in right)
                _NavItemTile(
                  item: item,
                  isActive: current == item.tab,
                  onTap: () => _handleTap(item.tab),
                  badge: badges[item.tab],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(MainTab tab) {
    HapticFeedback.selectionClick();
    onSelect(tab);
  }
}

// ===========================
// عنصر أيقونة/نص داخل الشريط (مع المؤشر والـ ripple)
// ===========================
class _NavItemTile extends StatelessWidget {
  const _NavItemTile({
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.badge,
  });

  final MainNavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    const selectedColor = Color(0xFFEB5924);
    final unselectedColor = colors.textLightColor.withOpacity(0.40);

    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          splashColor: const Color(0x1FEB5924), // ✅ Ripple متوافق
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: isActive ? 1.30 : 1.0, // ✅ التكبير عند التحديد
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: isActive
                          ? UiUtils.getSvg(item.activeSvg, color: selectedColor)
                          : UiUtils.getSvg(item.svg, color: unselectedColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.titleKey.translate(context),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11, // ✅ حجم النص المعتمد
                        color: isActive ? selectedColor : unselectedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // ✅ Badge (اختياري)
                if (badge != null && badge!.isNotEmpty)
                  Positioned(
                    top: -2,
                    right: 28, // عدّل عند الحاجة حسب الأيقونة
                    child: AnimatedScale(
                      key: ValueKey<String>(badge!),
                      duration: const Duration(milliseconds: 200),
                      scale: 1.0,
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
