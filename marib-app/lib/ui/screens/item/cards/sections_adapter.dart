import 'package:marib/app/routes.dart';
import 'package:marib/ui/screens/home_screen/home_screen.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/data/repositories/favourites_repository.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:flutter/material.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/data/cubits/favorite/favorite_cubit.dart';
import 'package:marib/data/model/home/home_screen_section.dart';
import 'package:marib/ui/screens/widgets/promoted_widget.dart';
import 'package:marib/ui/screens/home/widgets/grid_list_adapter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marquee/marquee.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';

import 'package:timeago/timeago.dart' as timeago;
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/delivery_department.dart';

class SectionsAdapter extends StatelessWidget {
  final HomeScreenSection section;
  final bool showLoadMore;
  final VoidCallback? onLoadMore;

  const SectionsAdapter({
    super.key,
    required this.section,
    this.showLoadMore = false,
    this.onLoadMore,
  });

  /// واجهة العنوان + قائمة العناصر
  Widget _buildSection(BuildContext context, Widget listWidget) {
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

      final String? initialSort = _mapFilterToSort(section.filter);

      if (section.sectionId != null) {
        Navigator.pushNamed(
          context,
          Routes.sectionWiseItemsScreen,
          arguments: {
            "title": section.title,
            "sectionId": section.sectionId,
          },
        );
        return;
      }

      final ItemModel? firstItem = (section.sectionData?.isNotEmpty ?? false)
          ? section.sectionData!.first
          : null;
      final int? catId = firstItem?.category?.id;
      if (catId != null) {
        Navigator.pushNamed(
          context,
          Routes.itemsList,
          arguments: {
            'catID': catId.toString(),
            'catName': section.title ?? firstItem?.category?.name ?? '',
            'categoryIds': <String>[catId.toString()],
            'interfaceType': section.sectionType ?? '',
            'initialSortBy': initialSort,
          },
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بيانات لعرض الكل'),
        ),
      );
    }

    return Column(
      children: [
        TitleHeader(
          title: section.title ?? "",
          onTap: _navigateSeeAll,
        ),
        listWidget,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = section.sectionData;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    final height = MediaQuery.of(context).size.height / 3.5.rh(context);
    final bool hasMore = showLoadMore && (section.hasMore ?? false);

    Widget _loaderTile({double? width}) {
      final Widget shimmer = CustomShimmer(
        height: height,
        width: width,
        margin: const EdgeInsets.symmetric(vertical: 4),
      );
      if (onLoadMore != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore!());
      }
      return shimmer;
    }

    switch (section.style) {
      case "style_1":
        final int total = data.length + (hasMore ? 1 : 0);
        return _buildSection(
          context,
          GridListAdapter(
            type: ListUiType.List,
            height: height,
            listAxis: Axis.horizontal,
            listSaperator: (_, __) => const SizedBox(width: 14),
            builder: (_, index, __) {
              if (hasMore && index >= data.length) {
                return _loaderTile(width: 220);
              }
              final item = data[index];
              return ICard(item: item, bigCard: true);
            },
            total: total,
          ),
        );

      case "style_2":
        final int total = data.length + (hasMore ? 1 : 0);
        return _buildSection(
          context,
          GridListAdapter(
            type: ListUiType.List,
            height: height,
            listAxis: Axis.horizontal,
            listSaperator: (_, __) => const SizedBox(width: 14),
            builder: (_, index, __) {
              if (hasMore && index >= data.length) {
                return _loaderTile(width: 144);
              }
              final item = data[index];
              return ICard(item: item, width: 144);
            },
            total: total,
          ),
        );

      case "style_3":
        final int total = data.length + (hasMore ? 1 : 0);
        return _buildSection(
          context,
          GridListAdapter(
            type: ListUiType.Grid,
            crossAxisCount: 2,
            height: height,
            builder: (_, index, __) {
              if (hasMore && index >= data.length) {
                return _loaderTile();
              }
              final item = data[index];
              return ICard(item: item, width: 192);
            },
            total: total,
          ),
        );

      case "style_4":
        final int total = data.length + (hasMore ? 1 : 0);
        return _buildSection(
          context,
          GridListAdapter(
            type: ListUiType.List,
            height: height,
            listAxis: Axis.horizontal,
            listSaperator: (_, __) => const SizedBox(width: 14),
            builder: (_, index, __) {
              if (hasMore && index >= data.length) {
                return _loaderTile(width: 192);
              }
              final item = data[index];
              return ICard(item: item, width: 192);
            },
            total: total,
          ),
        );

      default:
        return const SizedBox.shrink();
    }
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
          top: 18, bottom: 12, start: sidePadding, end: sidePadding),
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
    // تهيئة timeago بالعربية
    timeago.setLocaleMessages('ar', timeago.ArMessages());

    // نحسب تاريخ الإنشاء مرة واحدة
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

  // ───────── helpers: قراءة التاريخ من حقول محتملة ─────────
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
      // تحوّط لكونه seconds أو millis
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

  // عنصر واجهة صغير لعرض التاريخ
  Widget _dateRow(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 14, color: Colors.grey),
        const SizedBox(width: 5),
        Text(
          timeago.format(_createdAt!, locale: 'ar'),
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
        if (id == null) {
          // ممكن تحب تعرض Toast هنا بدل السكوت
          // UiUtils.showToast(context, 'المعرف غير متوفر');
          return;
        }
        Navigator.pushNamed(
          context,
          Routes.adDetailsScreen,
          arguments: {"model": widget.item}, // ✅ يمرِّر ItemModel
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
                // ✅ صورة المنتج + الشارات (مميز / جديد)
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

                    // ⭐ شارة "مميز"
                    if (widget.item?.isFeature ?? false)
                      const PositionedDirectional(
                        start: 10,
                        top: 5,
                        child: PromotedCard(type: PromoteCardType.icon),
                      ),

                    // 🟨 شارة "جديد" (أول 24 ساعة)
                    if (_isNew)
                      PositionedDirectional(
                        start: 10,
                        top: (widget.item?.isFeature ?? false) ? 31 : 5,
                        child: const _NewBadge(),
                      ),

                    if (_isCommercial(widget.item))
                      PositionedDirectional(
                        end: 10,
                        bottom: discountText != null ? 36 : 12,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
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

                // ✅ النصوص السفلية: السعر + الاسم + تاريخ النشر

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPrice(context),
                        _buildTitle(widget.item?.name ?? "", context),

                        // بدل الموقع → تاريخ النشر (مرن مع أسماء حقول مختلفة)
                        if (_extractCreatedAt(widget.item) != null)
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 5),
                              Text(
                                timeago.format(_extractCreatedAt(widget.item)!,
                                    locale: 'ar'),
                                style: TextStyle(
                                  fontSize: widget.bigCard == true
                                      ? context.font.small
                                      : context.font.smaller,
                                  color: context.color.textDefaultColor
                                      .withOpacity(0.6),
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

            // ✅ زر المفضلة
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
    const int titleLengthThreshold = 18; // عدد الأحرف المسموح بها قبل التمرير

    if (title.length > titleLengthThreshold) {
      // ✅ نص طويل → Marquee
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
      // ✅ نص عادي
      return Text(title)
          .setMaxLines(lines: 1)
          .size(context.font.large)
          .bold()
          .color(context.color.textDefaultColor);
    }
  }

  // 🔵 دالة لتنسيق السعر والعملة بألوان وأحجام مختلفة مع دعم الوضع الليلي، الحركة، والخطوط من الثيم

  /// ✅ دالة لبناء عنصر السعر والعملة بشكل منسق
  /// تُخفي العنصر تمامًا إذا كان السعر 0 أو غير صالح
  Widget _buildPrice(BuildContext context) {
    final rawPrice = widget.item?.price ?? 0;

    // إذا السعر صفر أو أقل، لا نعرض شيئًا
    if (rawPrice <= 0) return const SizedBox.shrink();

    final formattedPrice = HelperUtils.formatPrice(rawPrice);
    final price = formattedPrice.isEmpty
        ? '—'
        : formattedPrice; // ✅ تنسيق السعر مثل "55 ألف"
    //    final currency = widget.item?.currency ?? "";

    final currency = _resolveCurrency(widget.item);

    return Align(
      alignment: Alignment.centerRight, // ✅ إرجاع السعر لليمين
      child: RichText(
        text: TextSpan(
          children: [
            // ✅ السعر - واضح وأبرز بلون أساسي
            TextSpan(
              text: "$price ",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.color.territoryColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),

            // ✅ العملة - لون هادئ وخط أصغر قليلاً
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
                    // مزامنة قائمة المفضلة بعد نجاح العملية
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
                    backgroundColor: Colors.black54, // ✅ نفس باقي الأزرار
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

  bool _isCommercial(ItemModel? item) {
    final String? normalized = _normalizedDepartment(item);
    return normalized == 'shein' ||
        normalized == 'computer' ||
        normalized == 'store';
  }

  String? _normalizedDepartment(ItemModel? item) {
    if (item == null) return null;

    // 1) Explicit department slug or itemType.
    final String? fromSlug =
        normalizeDeliveryDepartment(item.departmentSlug ?? item.itemType);
    if (fromSlug != null) return fromSlug;

    // 2) Category ids (current + all parents).
    final List<int> categoryIds = <int>[];
    if (item.categoryId != null) categoryIds.add(item.categoryId!);
    if (item.allCategoryIds != null && item.allCategoryIds!.isNotEmpty) {
      final parts = item.allCategoryIds!.split(',');
      for (final p in parts) {
        final int? id = int.tryParse(p.trim());
        if (id != null) categoryIds.add(id);
      }
    }
    final String? fromCats =
        resolveDeliveryDepartmentFromCategoryIds(categoryIds);
    if (fromCats != null) return fromCats;

    return null;
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
