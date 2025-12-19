import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marquee/marquee.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/favorite/favorite_cubit.dart';
import 'package:marib/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:marib/data/model/home/home_screen_section.dart';
import 'package:marib/data/model/merchant/storefront_ui_config.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/repositories/favourites_repository.dart';
import 'package:marib/ui/screens/home/widgets/grid_list_adapter.dart';
import 'package:marib/ui/screens/widgets/promoted_widget.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';

const double cardSidePadding = 16.0;

class SectionsAdapter extends StatefulWidget {
  final HomeScreenSection section;
  final bool showLoadMore;
  final VoidCallback? onLoadMore;

  const SectionsAdapter({
    super.key,
    required this.section,
    this.showLoadMore = false,
    this.onLoadMore,
  });

  @override
  State<SectionsAdapter> createState() => _SectionsAdapterState();
}

class _SectionsAdapterState extends State<SectionsAdapter> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  StorefrontUiConfig? _uiConfig;
  bool _uiConfigLoading = false;
  int _promoRotation = 0;

  @override
  void initState() {
    super.initState();
    if (_isStoreSection) {
      _loadUiConfig();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isStoreSection {
    final type = (widget.section.sectionType ?? '').toLowerCase();
    final slug = (widget.section.slug ?? '').toLowerCase();
    final root = (widget.section.rootIdentifier ?? '').toLowerCase();
    return type == 'e_store' ||
        type == 'estore' ||
        type == 'store' ||
        type == 'stores' ||
        type.contains('store') ||
        slug.contains('store') ||
        root.contains('store');
  }

  List<ItemModel> _filterData(List<ItemModel> data) {
    if (_query.trim().isEmpty) return data;
    final q = _query.trim().toLowerCase();
    return data.where((item) {
      bool matches(String? value) => (value ?? '').toLowerCase().contains(q);
      return matches(item.name) ||
          matches(item.description) ||
          matches(item.slug) ||
          matches(item.city) ||
          matches(item.state);
    }).toList(growable: false);
  }

  Future<void> _loadUiConfig() async {
    if (_uiConfigLoading) return;
    setState(() => _uiConfigLoading = true);
    try {
      final res = await Api.get(
        url: 'storefront/ui-config',
        enableEtagCache: true,
      );
      final data = res['data'];
      if (data is Map<String, dynamic>) {
        _uiConfig = StorefrontUiConfig.fromJson(data);
      }
    } catch (_) {
      // optional config
    } finally {
      if (mounted) {
        setState(() => _uiConfigLoading = false);
      }
    }
  }

  List<_Entry> _buildEntries(List<ItemModel> data) {
    final List<_Entry> entries = [];
    final slots = (_uiConfig?.enabled ?? false)
        ? _uiConfig?.promotionSlots ?? const <PromotionSlot>[]
        : const <PromotionSlot>[];

    if (slots.isEmpty) {
      return data.map((item) => _Entry.item(item)).toList(growable: false);
    }

    int slotCursor = _promoRotation;
    int sinceLastPromo = 0;

    for (final item in data) {
      entries.add(_Entry.item(item));
      sinceLastPromo += 1;

      if (slots.isEmpty) continue;
      final PromotionSlot slot = slots[slotCursor % slots.length];
      final int frequency = slot.frequency <= 0 ? 4 : slot.frequency;
      if (sinceLastPromo >= frequency && slot.items.isNotEmpty) {
        final PromotionItem promo = slot.items[slotCursor % slot.items.length];
        entries.add(_Entry.promo(promo));
        slotCursor += 1;
        sinceLastPromo = 0;
      }
    }

    _promoRotation = slotCursor;
    return entries;
  }

  Widget _buildSection(
    BuildContext context,
    Widget listWidget, {
    Widget? searchBar,
    Widget? featuredRibbon,
  }) {
    void _navigateSeeAll() {
      String? _mapFilterToSort(String? filter) {
        switch ((filter ?? '').toLowerCase()) {
          case 'latest':
            return 'new-to-old';
          case 'highest_price':
            return 'price-high-to-low';
          case 'lowest_price':
          case 'price_range':
            return 'price-low-to-high';
          default:
            return null;
        }
      }

      final String? initialSort = _mapFilterToSort(widget.section.filter);

      if (widget.section.sectionId != null) {
        Navigator.pushNamed(
          context,
          Routes.sectionWiseItemsScreen,
          arguments: {
            "title": widget.section.title,
            "sectionId": widget.section.sectionId,
          },
        );
        return;
      }

      final ItemModel? firstItem =
          (widget.section.sectionData?.isNotEmpty ?? false)
              ? widget.section.sectionData!.first
              : null;
      final int? catId = firstItem?.category?.id;
      if (catId != null) {
        Navigator.pushNamed(
          context,
          Routes.itemsList,
          arguments: {
            'catID': catId.toString(),
            'catName': widget.section.title ?? firstItem?.category?.name ?? '',
            'categoryIds': <String>[catId.toString()],
            'interfaceType': widget.section.sectionType ?? '',
            'initialSortBy': initialSort,
          },
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح هذه الفئة، حاول مرة أخرى لاحقاً'),
        ),
      );
    }

    return Column(
      children: [
        TitleHeader(
          title: widget.section.title ?? "",
          onTap: _navigateSeeAll,
        ),
        if (searchBar != null) searchBar,
        if (featuredRibbon != null) featuredRibbon,
        listWidget,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.section.sectionData;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    final filteredData = _filterData(data);
    final entries = _buildEntries(filteredData);
    final bool isSearching = _query.trim().isNotEmpty;

    final height = MediaQuery.of(context).size.height / 3.5.rh(context);
    final bool hasMore = widget.showLoadMore &&
        (widget.section.hasMore ?? false) &&
        !isSearching;

    Widget? _buildSearchBar() {
      if (!_isStoreSection) return null;
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: cardSidePadding,
          vertical: 6,
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'ابحث في المتاجر',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    Widget _loaderTile({double? width}) {
      final Widget shimmer = CustomShimmer(
        height: height,
        width: width,
        margin: const EdgeInsets.symmetric(vertical: 4),
      );
      if (widget.onLoadMore != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => widget.onLoadMore!());
      }
      return shimmer;
    }

    switch (widget.section.style) {
      case "style_1":
        return _buildSection(
          context,
          GridListAdapter(
            type: ListUiType.List,
            height: height,
            listAxis: Axis.horizontal,
            listSaperator: (_, __) => const SizedBox(width: 14),
            builder: (_, index, __) {
              if (hasMore && index >= entries.length) {
                return _loaderTile(width: 220);
              }
              final entry = entries[index];
              if (entry.isPromo) {
                return _PromotionCard(promo: entry.promo!, width: 220);
              }
              return ICard(item: entry.item, bigCard: true);
            },
            total: entries.length + (hasMore ? 1 : 0),
          ),
          searchBar: _buildSearchBar(),
          featuredRibbon: _buildFeaturedRibbon(),
        );

      case "style_2":
        return _buildSection(
          context,
          GridListAdapter(
            type: ListUiType.List,
            height: height,
            listAxis: Axis.horizontal,
            listSaperator: (_, __) => const SizedBox(width: 14),
            builder: (_, index, __) {
              if (hasMore && index >= entries.length) {
                return _loaderTile(width: 144);
              }
              final entry = entries[index];
              if (entry.isPromo) {
                return _PromotionCard(promo: entry.promo!, width: 144);
              }
              return ICard(item: entry.item, width: 144);
            },
            total: entries.length + (hasMore ? 1 : 0),
          ),
          searchBar: _buildSearchBar(),
          featuredRibbon: _buildFeaturedRibbon(),
        );

      case "style_3":
        return _buildSection(
          context,
          GridListAdapter(
            type: ListUiType.Grid,
            crossAxisCount: 2,
            height: height,
            builder: (_, index, __) {
              if (hasMore && index >= entries.length) {
                return _loaderTile();
              }
              final entry = entries[index];
              if (entry.isPromo) {
                return _PromotionCard(promo: entry.promo!, width: 192);
              }
              return ICard(item: entry.item, width: 192);
            },
            total: entries.length + (hasMore ? 1 : 0),
          ),
          searchBar: _buildSearchBar(),
          featuredRibbon: _buildFeaturedRibbon(),
        );

      case "style_4":
        return _buildSection(
          context,
          GridListAdapter(
            type: ListUiType.List,
            height: height,
            listAxis: Axis.horizontal,
            listSaperator: (_, __) => const SizedBox(width: 14),
            builder: (_, index, __) {
              if (hasMore && index >= entries.length) {
                return _loaderTile(width: 192);
              }
              final entry = entries[index];
              if (entry.isPromo) {
                return _PromotionCard(promo: entry.promo!, width: 192);
              }
              return ICard(item: entry.item, width: 192);
            },
            total: entries.length + (hasMore ? 1 : 0),
          ),
          searchBar: _buildSearchBar(),
          featuredRibbon: _buildFeaturedRibbon(),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildFeaturedRibbon() {
    if (!_isStoreSection) return null;
    final cats = (_uiConfig?.enabled ?? false)
        ? _uiConfig?.featuredCategories ?? const <FeaturedCategory>[]
        : const <FeaturedCategory>[];
    if (cats.isEmpty) return null;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: cardSidePadding),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final cat = cats[index];
          return ActionChip(
            backgroundColor: Colors.grey.shade200,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            label: Text(cat.label.isNotEmpty ? cat.label : 'فئة'),
            avatar: cat.icon != null && cat.icon!.isNotEmpty
                ? UiUtils.getSvg(
                    cat.icon!,
                    color: Colors.black54,
                    width: 18,
                    height: 18,
                  )
                : null,
            onPressed: () => _openCategory(cat),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: cats.length,
      ),
    );
  }

  void _openCategory(FeaturedCategory cat) {
    final idText = cat.id.trim();
    final int? catId = int.tryParse(idText);
    final String? slug = catId == null ? idText : null;

    if (catId == null && (slug == null || slug.isEmpty)) {
      UiUtils.showSoftSnackBar(context, message: 'تعذر فتح الفئة المحددة.');
      return;
    }

    Navigator.pushNamed(
      context,
      Routes.itemsList,
      arguments: {
        'catID': catId?.toString() ?? '',
        'catName': cat.label,
        'categoryIds': catId != null ? <String>[catId.toString()] : <String>[],
        if (slug != null && slug.isNotEmpty) 'slug': slug,
        'interfaceType': widget.section.sectionType ?? '',
      },
    );
  }
}

class TitleHeader extends StatelessWidget {
  final String title;
  final Function() onTap;
  final bool? hideSeeAll;

  const TitleHeader({
    super.key,
    required this.title,
    required this.onTap,
    this.hideSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
          top: 18, bottom: 12, start: cardSidePadding, end: cardSidePadding),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(title)
                .size(context.font.large)
                .bold(weight: FontWeight.w600)
                .setMaxLines(lines: 1),
          ),
          const Spacer(),
          if (!(hideSeeAll ?? false))
            GestureDetector(
              onTap: onTap,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2.2),
                  child: Text("seeAll".translate(context))
                      .size(context.font.smaller + 1)),
            )
        ],
      ),
    );
  }
}

class ICard extends StatefulWidget {
  final double? width;
  final double? imageHeight;
  final double? likeButtonSize;
  final bool? bigCard;
  final ItemModel? item;
  final String? created;

  const ICard({
    super.key,
    required this.item,
    this.width,
    this.imageHeight,
    this.likeButtonSize,
    this.bigCard,
    this.created,
  });

  @override
  _ItemCardState createState() => _ItemCardState();
}

class _ItemCardState extends State<ICard> {
  late final DateTime? _createdAt;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _createdAt =
        _extractCreatedAt(widget.item) ?? _parseAnyDate(widget.created);
  }

  bool get _isNew {
    final d = _createdAt;
    if (d == null) return false;
    return DateTime.now().difference(d).inHours < 24;
  }

  String? _discountLabel(ItemModel? item) {
    if (item == null) return null;
    final ItemDiscount? discount = item.discount;

    double? percent;

    final double? original = item.price;
    final double? finalPrice = item.finalPrice ?? item.price;
    if (original != null &&
        finalPrice != null &&
        original > 0 &&
        finalPrice < original) {
      percent = ((original - finalPrice) / original) * 100;
    } else if (discount?.isActive == true &&
        discount?.value != null &&
        (discount?.type?.toLowerCase() == 'percent' ||
            discount?.type?.toLowerCase() == 'percentage')) {
      percent = discount?.value;
    }

    if (percent != null && percent > 0) {
      final int rounded = percent.round();
      final int display = rounded <= 0 ? 1 : rounded;
      return "خصم $display%";
    }
    return null;
  }

  DateTime? _extractCreatedAt(ItemModel? item) {
    if (item == null) return null;
    final d = item as dynamic;
    dynamic v;
    try {
      v ??= d.createdAt;
    } catch (_) {}
    try {
      v ??= d.created_at;
    } catch (_) {}
    try {
      v ??= d.date;
    } catch (_) {}
    try {
      v ??= d.createdOn;
    } catch (_) {}
    try {
      v ??= d.postedAt;
    } catch (_) {}
    try {
      v ??= d.timestamp;
    } catch (_) {}
    try {
      v ??= d.time;
    } catch (_) {}
    try {
      v ??= d.created;
    } catch (_) {}
    return _parseAnyDate(v);
  }

  DateTime? _parseAnyDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        v > 20000000000 ? v : v * 1000,
      );
    }
    if (v is String) {
      final iso = DateTime.tryParse(v);
      if (iso != null) return iso;
      final n = int.tryParse(v);
      if (n != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          n > 20000000000 ? n : n * 1000,
        );
      }
    }
    return null;
  }

  Widget _dateRow(BuildContext context) {
    if (_createdAt == null) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.access_time, size: 14, color: Colors.grey),
        const SizedBox(width: 5),
        Text(
          timeago.format(
            _createdAt!,
            locale: UiUtils.resolveLanguageCode(context),
          ),
          style: TextStyle(
            fontSize: widget.bigCard == true
                ? context.font.small
                : context.font.smaller,
            color: context.color.textDefaultColor.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final String? discountText = _discountLabel(item);

    String? preferredThumb;
    final thumb = item?.thumbnailUrl;
    if (thumb != null && thumb.trim().isNotEmpty) {
      preferredThumb = thumb;
    }

    String? fallbackThumb;
    final fallbackCandidate = item?.thumbnailFallbackUrl;
    if (fallbackCandidate != null && fallbackCandidate.trim().isNotEmpty) {
      fallbackThumb = fallbackCandidate;
    } else {
      final image = item?.image;
      if (image != null && image.trim().isNotEmpty) {
        fallbackThumb = image;
      }
    }

    final resolvedUrl = preferredThumb ?? fallbackThumb ?? '';

    return UiUtils.ripple(
      onTap: () {
        final id = widget.item?.id;
        if (id == null) return;
        Navigator.pushNamed(
          context,
          Routes.adDetailsScreen,
          arguments: {"model": widget.item},
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: widget.width ?? 250,
        decoration: BoxDecoration(
          border: Border.all(
            color: context.color.borderColor.darken(30),
            width: 1,
          ),
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: RepaintBoundary(
                        child: UiUtils.getImage(
                          resolvedUrl.isNotEmpty
                              ? resolvedUrl
                              : "assets/image/2.png",
                          height: widget.imageHeight ?? 147,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          fallbackUrl: fallbackThumb,
                          cacheWidth: 200,
                          cacheHeight: 200,
                        ),
                      ),
                    ),
                    if (widget.item?.isFeature ?? false)
                      const PositionedDirectional(
                        start: 10,
                        top: 5,
                        child: PromotedCard(type: PromoteCardType.icon),
                      ),
                    if (_isNew)
                      PositionedDirectional(
                        start: 10,
                        top: (widget.item?.isFeature ?? false) ? 31 : 5,
                        child: const _NewBadge(),
                      ),
                    if (discountText != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.shade700,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(18),
                              bottomRight: Radius.circular(18),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            discountText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPrice(context),
                        _buildTitle(widget.item?.name ?? "", context),
                        _dateRow(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            PositionedDirectional(
              top: 10,
              end: 10,
              child: favButton(
                item: widget.item!,
                size: widget.likeButtonSize ?? 35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(String title, BuildContext context) {
    const int titleLengthThreshold = 18;

    if (title.length > titleLengthThreshold) {
      return SizedBox(
        height: 20,
        child: Marquee(
          text: title,
          style: TextStyle(
            fontSize: context.font.large,
            fontWeight: FontWeight.w600,
            color: context.color.textDefaultColor,
          ),
          scrollAxis: Axis.horizontal,
          blankSpace: 20.0,
          velocity: 30.0,
          pauseAfterRound: const Duration(seconds: 1),
          startPadding: 0.0,
          accelerationDuration: const Duration(milliseconds: 800),
          accelerationCurve: Curves.ease,
          decelerationDuration: const Duration(milliseconds: 500),
          decelerationCurve: Curves.easeOut,
        ),
      );
    } else {
      return Text(title)
          .setMaxLines(lines: 1)
          .size(context.font.large)
          .bold()
          .color(context.color.textDefaultColor);
    }
  }

  Widget _buildPrice(BuildContext context) {
    final double basePrice = widget.item?.price ?? 0;
    final double finalPrice = widget.item?.finalPrice ?? basePrice;
    final double displayPrice = finalPrice > 0 ? finalPrice : basePrice;

    final String display = HelperUtils.formatPrice(displayPrice).isNotEmpty
        ? HelperUtils.formatPrice(displayPrice)
        : displayPrice.toString();
    final bool hasOriginal = basePrice > displayPrice && basePrice > 0;
    final String? original =
        hasOriginal ? HelperUtils.formatPrice(basePrice) : null;

    final currency = _resolveCurrency(widget.item);

    return Align(
      alignment: Alignment.centerRight,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "$display ",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.color.territoryColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (original != null && original.isNotEmpty)
              TextSpan(
                text: "$original ",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.color.textDefaultColor.withOpacity(0.55),
                      decoration: TextDecoration.lineThrough,
                    ),
              ),
            TextSpan(
              text: currency,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.color.textDefaultColor.withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveCurrency(ItemModel? item) {
    final String? raw = item?.currency;
    final String? code =
        item?.currencyCode ?? CurrencyUtils.normalizeCurrencyCode(raw);

    final String? preferred = CurrencyUtils.preferredDisplayFor(code ?? raw);
    if (preferred != null && preferred.trim().isNotEmpty) {
      return preferred.trim();
    }

    final String? normalizedFromRaw =
        raw != null ? CurrencyUtils.preferredDisplayFor(raw) : null;
    if (normalizedFromRaw != null && normalizedFromRaw.trim().isNotEmpty) {
      return normalizedFromRaw.trim();
    }

    final String? trimmed = raw?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }

    return CurrencyUtils.preferredDisplayFor('YER') ?? Constant.currencySymbol;
  }

  Widget favButton({required ItemModel item, required double size}) {
    final int? itemId = item.id;
    if (itemId == null) {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (context) => UpdateFavoriteCubit(FavoriteRepository()),
      child: Builder(
        builder: (outerContext) {
          final favoriteCubit = outerContext.read<FavoriteCubit>();

          return BlocBuilder<FavoriteCubit, FavoriteState>(
            bloc: favoriteCubit,
            builder: (context, likeAndDislikeState) {
              final bool isLikeFromCubit = favoriteCubit.isItemFavorite(itemId);

              return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
                bloc: context.read<UpdateFavoriteCubit>(),
                listener: (context, state) {
                  if (state is UpdateFavoriteSuccess &&
                      state.item.id == itemId) {
                    favoriteCubit.getFavorite();
                  }
                },
                builder: (context, state) {
                  final inProgress = state is UpdateFavoriteInProgress;
                  final bool isLike =
                      state is UpdateFavoriteSuccess && state.item.id == itemId
                          ? state.wasProcess
                          : isLikeFromCubit;

                  return CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: size / 2,
                    child: IconButton(
                      icon: inProgress
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : UiUtils.getSvg(
                              isLike ? AppIcons.like_fill : AppIcons.like,
                              width: 22,
                              height: 22,
                              color: isLike ? Colors.redAccent : Colors.white,
                            ),
                      onPressed: inProgress
                          ? null
                          : () {
                              UiUtils.checkUser(
                                onNotGuest: () {
                                  context
                                      .read<UpdateFavoriteCubit>()
                                      .setFavoriteItem(
                                        item: item,
                                        type: isLike ? 0 : 1,
                                      );

                                  UiUtils.showSoftSnackBar(
                                    context,
                                    message: isLike
                                        ? "تمت إزالة الإعلان من المفضلة"
                                        : "تمت إضافة الإعلان إلى المفضلة",
                                  );
                                },
                                context: context,
                              );
                            },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        "جديد",
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _Entry {
  final ItemModel? item;
  final PromotionItem? promo;

  const _Entry._({this.item, this.promo});

  factory _Entry.item(ItemModel item) => _Entry._(item: item);

  factory _Entry.promo(PromotionItem promo) => _Entry._(promo: promo);

  bool get isPromo => promo != null;
}

class _PromotionCard extends StatelessWidget {
  final PromotionItem promo;
  final double? width;

  const _PromotionCard({required this.promo, this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: width ?? 220,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((promo.image ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: UiUtils.getImage(
                  promo.image!,
                  height: 90,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              promo.title ?? 'عرض مميز',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if ((promo.subtitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                promo.subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurface.withOpacity(0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
