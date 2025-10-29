import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/app/app_scroll_behavior.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:marib/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:marib/data/cubits/slider_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/home/home_screen_section.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/sliders/slider_widget.dart';
import 'package:marib/ui/screens/subscription/packages_list.dart';

// استيراد صريح لتفادي التعارض
import 'package:marib/utils/payment/bank_transfer_screen.dart' show BankTransferScreen;
import 'package:marib/utils/payment/bank_transfer_args.dart' show BankTransferArgs;
import 'package:marib/utils/payment/manual_payment_service.dart'
    show ManualPaymentSubmissionResult;



class SoonScreen extends StatefulWidget {
  const SoonScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(builder: (_) => const SoonScreen());
  }

  @override
  State<SoonScreen> createState() => SoonScreenState();
}

class SoonScreenState extends State<SoonScreen> with TickerProviderStateMixin {
  static const double _horizontalPadding = 20;

  late final ScrollController _scrollController;
  final NumberFormat _countFormatter = NumberFormat.compact(locale: 'ar');

  double _headerCollapse = 0;
  bool _requestedInitialFetch = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _triggerInitialFetch();
    });
  }

  void _handleScroll() {
    final double offset = _scrollController.hasClients ? _scrollController.offset : 0;
    final double nextCollapse = (offset / 140).clamp(0.0, 1.0);
    if (nextCollapse != _headerCollapse) {
      setState(() {
        _headerCollapse = nextCollapse;
      });
    }
  }


  Future<void> _triggerInitialFetch() async {
    if (_requestedInitialFetch) return;
    _requestedInitialFetch = true;

    final sliderCubit = context.read<SliderCubit>();
    await Future.wait<void>([
    sliderCubit.fetchSlider(
    context,
    interfaceType: 'homepage',
      ),
      context.read<FetchHomeScreenCubit>().fetch(interfaceType: 'homepage'),
      context.read<FetchCategoryCubit>().fetchCategories(),
    ]);
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      context.read<SliderCubit>().fetchSlider(
        context,
        interfaceType: 'homepage',
        forceRefresh: true,
      ),
      context.read<FetchHomeScreenCubit>().fetch(interfaceType: 'homepage'),
      context.read<FetchCategoryCubit>().fetchCategories(),
    ]);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            displacement: 72,
            onRefresh: _refreshAll,
            child: CustomScrollView(
              controller: _scrollController,
              physics: AppScrollBehavior.defaultPhysics,
              slivers: [
                SliverToBoxAdapter(child: _buildHeroHeader(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildSliderShowcase()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildQuickActions(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverToBoxAdapter(child: _buildSections(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                SliverToBoxAdapter(child: _buildTrendingGrid(context)),
                const SliverPadding(padding: EdgeInsets.only(bottom: 48)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final media = MediaQuery.of(context);
    final paddingTop = media.padding.top + 16;
    final user = HiveUtils.getUserDetails();
    final bool isAuthenticated = HiveUtils.isUserAuthenticated();
    final String name = (user.name ?? '').trim().isEmpty
        ? 'زائر'
        : user.name!.trim();
    final String? phone = user.mobile?.toString();

    final List<String> locationParts = <dynamic>[
      HiveUtils.getCountryName(),
      HiveUtils.getStateName(),
      HiveUtils.getCityName(),
    ]
        .where((dynamic value) =>
    value != null && value.toString().trim().isNotEmpty)
        .map((dynamic value) => value.toString())
        .toList();

    final FetchHomeScreenState sectionsState =
        context.watch<FetchHomeScreenCubit>().state;
    final FetchCategoryState categoryState =
        context.watch<FetchCategoryCubit>().state;
    final FetchHomeAllItemsState itemsState =
        context.watch<FetchHomeAllItemsCubit>().state;

    final int? sectionsCount = sectionsState is FetchHomeScreenSuccess
        ? sectionsState.sections.length
        : null;
    final int? categoryCount = categoryState is FetchCategorySuccess
        ? categoryState.total
        : null;
    final int? listingsCount = itemsState is FetchHomeAllItemsSuccess
        ? itemsState.total
        : null;

    final Color baseColor = context.color.territoryColor;
    final Color textColor = context.color.textAutoAdapt(baseColor);

    return Padding(
        padding: EdgeInsetsDirectional.only(
          start: _horizontalPadding,
          end: _horizontalPadding,
          top: paddingTop,
        ),
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  baseColor,
                  baseColor.withOpacity(0.92),
                  context.color.forthColor.withOpacity(0.88),
                ],
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withOpacity(0.25 * (1 - _headerCollapse)),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsetsDirectional.only(
              start: 26,
              end: 26,
              top: 32,
              bottom: 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProfileAvatar(user.profile, textColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAuthenticated ? 'مرحبًا، $name' : 'مرحبًا بك في مارب',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (locationParts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          locationParts.join(' • '),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildHeroMetricsRow(
              context,
              sectionsCount: sectionsCount,
              categoryCount: categoryCount,
              listingsCount: listingsCount,
            ),
            if (isAuthenticated && phone != null && phone.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildPhoneChip(phone.trim(), textColor),
            ],
              ],
            ),
        ),
    );
  }

  Widget _buildProfileAvatar(String? profileUrl, Color borderColor) {
    final bool hasImage = profileUrl != null && profileUrl.trim().isNotEmpty;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
          imageUrl: profileUrl!,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildInitialsAvatar(borderColor),
        )
            : _buildInitialsAvatar(borderColor),
      ),
    );
  }

  Widget _buildInitialsAvatar(Color color) {
    final String initials = HiveUtils.getUserDetails().name
        ?.trim()
        .split(RegExp(r'\s+'))
        .where((element) => element.isNotEmpty)
        .map((word) => word.characters.first)
        .take(2)
        .join()
        .toUpperCase() ??
        'M';
    return Container(
      color: color.withOpacity(0.2),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMetricsRow(
      BuildContext context, {
        int? sectionsCount,
        int? categoryCount,
        int? listingsCount,
      }) {
    final List<_HeroMetric> metrics = [
      _HeroMetric('القطاعات', sectionsCount),
      _HeroMetric('الفئات', categoryCount),
      _HeroMetric('العروض النشطة', listingsCount),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: metrics
            .map(
              (metric) => Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMetricValue(metric.value),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
                ),
              ),
        )
            .toList(),
      ),
    );
  }

  String _formatMetricValue(int? value) {
    if (value == null) {
      return '…';
    }
    return _countFormatter.format(value);
  }

  Widget _buildPhoneChip(String phone, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(
            phone,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderShowcase() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: const SliderWidget(interfaceType: 'homepage'),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
        builder: (context, state) {
          if (state is FetchCategoryInProgress || state is FetchCategoryInitial) {
            return _buildLoadingStrip();
          }

          if (state is FetchCategoryFailure) {
            return _buildErrorMessage(state.errorMessage);
          }

          if (state is FetchCategorySuccess && state.categories.isNotEmpty) {
            final List<CategoryModel> categories =
            state.categories.take(10).toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                ),
                  child: _SectionHeader(
                    title: 'الخدمات المتكاملة',
                    subtitle: 'دخول سريع لكل القطاعات المتاحة من المنصة',
                    actionLabel: 'جميع الفئات',
                    onActionTap: () {
                      Navigator.pushNamed(
                        context,
                        Routes.categories,
                        arguments: {'from': Routes.home},
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    padding: const EdgeInsetsDirectional.only(
                      start: _horizontalPadding,
                      end: _horizontalPadding,
                    ),
                    scrollDirection: Axis.horizontal,
                    physics: AppScrollBehavior.defaultPhysics,
                    itemBuilder: (context, index) {
                      final CategoryModel category = categories[index];
                      return _CategoryShortcut(
                        category: category,
                        onTap: () => _openCategory(context, category),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemCount: categories.length,
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
    );
  }

  Widget _buildSections(BuildContext context) {
    return BlocBuilder<FetchHomeScreenCubit, FetchHomeScreenState>(
      builder: (context, state) {
        if (state is FetchHomeScreenInProgress ||
            state is FetchHomeScreenInitial) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Column(
              children: [
                _buildLoadingStrip(height: 180),
                const SizedBox(height: 16),
                _buildLoadingStrip(height: 180),
              ],
            ),
          );
        }

        if (state is FetchHomeScreenFail) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: _buildErrorMessage(state.error.toString()),
          );
        }

        if (state is FetchHomeScreenSuccess) {
          final List<HomeScreenSection> populatedSections = state.sections
              .where((section) =>
          (section.sectionData?.isNotEmpty ?? false) &&
              (section.title ?? '').trim().isNotEmpty)
              .take(4)
              .toList(growable: false);

          if (populatedSections.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  title: 'أبرز الوجهات',
                  subtitle: 'أحدث الأقسام العقارية والتجارية والسياحية المتاحة الآن',
                ),
                const SizedBox(height: 18),
                for (final HomeScreenSection section in populatedSections) ...[
                  _SectionShowcase(
                    section: section,
                    onItemTap: (ItemModel item) => _openItem(context, item),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTrendingGrid(BuildContext context) {
    return BlocBuilder<FetchHomeAllItemsCubit, FetchHomeAllItemsState>(
      builder: (context, state) {
        if (state is FetchHomeAllItemsInProgress ||
            state is FetchHomeAllItemsInitial) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: _buildLoadingStrip(height: 240),
          );
        }

        if (state is FetchHomeAllItemsFail) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: _buildErrorMessage(state.error.toString()),
          );
        }

        if (state is FetchHomeAllItemsSuccess && state.items.isNotEmpty) {
          final List<ItemModel> items =
          state.items.take(6).toList(growable: false);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  title: 'منصّة متعددة الخدمات',
                  subtitle: 'عقارات، سياحة، تجارة إلكترونية، وخدمات متخصصة في مكان واحد',
                ),
                const SizedBox(height: 18),
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    return _GridItemCard(
                      item: items[index],
                      onTap: () => _openItem(context, items[index]),
                    );
                  },
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadingStrip({double height = 140}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.color.secondaryColor.withOpacity(0.65),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(
            context.color.territoryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.color.borderColor.darken(20)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: context.color.territoryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.color.textDefaultColor.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCategory(BuildContext context, CategoryModel category) {
    final List<CategoryModel>? children = category.children;
    if (children != null && children.isNotEmpty) {
      Navigator.pushNamed(
        context,
        Routes.subCategoryScreen,
        arguments: {
          'categoryList': children,
          'catName': category.name,
          'catId': category.id,
          'categoryIds': [category.id?.toString()].whereType<String>().toList(),
        },
      );
      return;
    }

    Navigator.pushNamed(
      context,
      Routes.itemsList,
      arguments: {
        'catID': category.id?.toString(),
        'catName': category.name,
        'categoryIds': [category.id?.toString()].whereType<String>().toList(),
      },
    );
  }

  void _openItem(BuildContext context, ItemModel item) {
    Navigator.pushNamed(
      context,
      Routes.adDetailsScreen,
      arguments: {
        'model': item,
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
    Row(
    children: [
    Expanded(
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: context.color.textDefaultColor,
        fontWeight: FontWeight.w700,
                    ),
    ),
    ),
        if (actionLabel != null && onActionTap != null)
      TextButton(
        onPressed: onActionTap,
        style: TextButton.styleFrom(
          foregroundColor: context.color.territoryColor,
          textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(actionLabel!),
      ),
    ],
    ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.color.textDefaultColor.withOpacity(0.65),
            ),
          ),
        ],
      ],
    );
  }
}


class _CategoryShortcut extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _CategoryShortcut({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = context.color.secondaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 124,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.color.borderColor.darken(10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Expanded(
        child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: category.url ?? '',
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            color: context.color.backgroundColor,
            child: Icon(
              Icons.grid_view_rounded,
              color: context.color.territoryColor,
            ),
          ),
                ),

              ),
        ),
              const SizedBox(height: 10),
              Text(
                category.name ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.color.textDefaultColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
        ),
      ),
    );
  }
}

class _SectionShowcase extends StatelessWidget {
  final HomeScreenSection section;
  final ValueChanged<ItemModel> onItemTap;

  const _SectionShowcase({
    required this.section,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<ItemModel> items = section.sectionData!
        .where((item) => (item.name ?? '').trim().isNotEmpty)
        .toList();
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Text(
      section.title ?? '',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: context.color.textDefaultColor,
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 12),
    SizedBox(
    height: 250,
    child: ListView.separated(
    scrollDirection: Axis.horizontal,
    physics: AppScrollBehavior.defaultPhysics,
    itemBuilder: (context, index) => _HighlightedItemCard(
    item: items[index],
    onTap: () => onItemTap(items[index]),
    ),
    separatorBuilder: (_, __) => const SizedBox(width: 16),
    itemCount: math.min(items.length, 6),
          ),
        ),
      ],
    );
  }
}

class _HighlightedItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const _HighlightedItemCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double? price = item.finalPrice ?? item.price;
    final String priceLabel = price == null || price <= 0
        ? 'السعر عند الطلب'
        : '${HelperUtils.formatPrice(price)} ${item.currency ?? ''}'.trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: context.color.borderColor.darken(10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
              child: CachedNetworkImage(
                imageUrl: item.image ?? '',
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: 140,
                  color: context.color.backgroundColor,
                  child: Icon(
                    Icons.photo_size_select_actual_outlined,
                    color: context.color.territoryColor,
                    size: 36,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      priceLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.color.territoryColor,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.name ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.color.textDefaultColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((item.city ?? item.country ?? '').isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: context.color.textDefaultColor.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _resolveLocation(item),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: context.color.textDefaultColor
                                    .withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveLocation(ItemModel item) {
    return [item.city, item.state, item.country]
        .where((element) => element != null && element!.trim().isNotEmpty)
        .map((element) => element!.trim())
        .join('، ');
  }
}

class _GridItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const _GridItemCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double? price = item.finalPrice ?? item.price;
    final String priceLabel = price == null || price <= 0
        ? 'السعر عند الطلب'
        : '${HelperUtils.formatPrice(price)} ${item.currency ?? ''}'.trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.color.borderColor.darken(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: CachedNetworkImage(
                imageUrl: item.image ?? '',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: 120,
                  color: context.color.backgroundColor,
                  child: Icon(
                    Icons.image_outlined,
                    color: context.color.territoryColor,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    priceLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.color.territoryColor,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name ?? '',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.color.textDefaultColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if ((item.city ?? item.country ?? '').isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: context.color.textDefaultColor.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [item.city, item.state]
                                .where((value) =>
                            value != null &&
                                value.trim().isNotEmpty)
                                .whereType<String>()
                                .map((v) => v.trim())
                                .where((v) => v.isNotEmpty)

                                .join('، '),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: context.color.textDefaultColor
                                  .withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _HeroMetric {
  final String label;
  final int? value;

  const _HeroMetric(this.label, this.value);
}