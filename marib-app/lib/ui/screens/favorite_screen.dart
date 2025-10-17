import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/favorite/favorite_cubit.dart';
import 'package:marib/data/helper/designs.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/item/cards/horizontal_card.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/intertitial_ads_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(builder: (_) => const FavoriteScreen());
  }

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen>
    with AutomaticKeepAliveClientMixin<FavoriteScreen> {
  final ScrollController _controller = ScrollController();
  bool _adShown = false;
  bool _showToTop = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // إعلان مرّة واحدة
    AdHelper.loadInterstitialAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_adShown) {
        AdHelper.showInterstitialAd();
        _adShown = true;
      }
    });

    _controller.addListener(_onScroll);
    _getFavorite(); // أول تحميل
  }

  void _onScroll() {
    // إظهار زر للأعلى
    final y = _controller.offset;
    if ((_showToTop && y < 600) || (!_showToTop && y >= 600)) {
      setState(() => _showToTop = y >= 600);
    }

    // جلب المزيد مبكرًا عندما يتبقى ~500px
    if (_controller.position.extentAfter < 500) {
      final cubit = context.read<FavoriteCubit>();
      if (cubit.hasMoreFavorite()) {
        cubit.getMoreFavorite();
      }
    }
  }

  void _getFavorite() {
    debugPrint("🎯 المستخدم طلب تحديث قائمة المفضلة");
    context.read<FavoriteCubit>().getFavorite();
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  // Prefetch بسيط لأوّل N صور (لو الكرت يستخدم Image.network داخليًا سيستفيد)
  Future<void> _prefetchFirstImages(List<ItemModel> items, BuildContext ctx,
      {int count = 4}) async {
    final n = items.take(count);
    for (final it in n) {
      final url = it.image;
      if (url != null && url.trim().isNotEmpty && url.startsWith('http')) {
        // ImageProvider بسيط
        final img = NetworkImage(url);
        // تجاهل الأخطاء
        // قد لا تحتاج await هنا، لكن تركته للوضوح
        await precacheImage(img, ctx).catchError((_) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: "favorites".translate(context),
      ),
      backgroundColor: context.color.primaryColor,
      body: BlocListener<FavoriteCubit, FavoriteState>(
        listenWhen: (p, c) => c is FavoriteFetchSuccess,
        listener: (context, state) {
          if (state is FavoriteFetchSuccess && state.favorite.isNotEmpty) {
            _prefetchFirstImages(state.favorite, context);
          }
        },
        child: RefreshIndicator(
          color: context.color.territoryColor,
          onRefresh: () async => _getFavorite(),
          child: BlocBuilder<FavoriteCubit, FavoriteState>(
            builder: (context, state) {
              if (state is FavoriteFetchInProgress) {
                return _shimmerEffect(context);
              }

              if (state is FavoriteFetchFailure) {
                if (state.errorMessage is ApiException &&
                    (state.errorMessage as ApiException).errorMessage ==
                        "no-internet") {
                  return NoInternet(onRetry: _getFavorite);
                }
                return const SomethingWentWrong();
              }

              if (state is FavoriteFetchSuccess) {
                final items = state.favorite;
                if (items.isEmpty) {
                  return Center(child: NoDataFound(onTap: _getFavorite));
                }

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _controller,

                      padding: const EdgeInsets.all(16),
                      itemCount: items.length + 1, // +1 للذيل
                      itemBuilder: (context, index) {
                        if (index == items.length) {
                          // ذيل القائمة
                          if (state.isLoadingMore) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: UiUtils.progress(
                                normalProgressColor: context.color.territoryColor,
                              ),
                            );
                          }
                          if (!state.hasMore) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  "لا مزيد من العناصر",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: context.color.textDefaultColor
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }

                        final item = items[index];

                        // سحب لحذف من المفضلة + تراجع
                        return Dismissible(
                          key: ValueKey("fav_${item.id}_${item.slug}_${index}"),
                          direction: DismissDirection.endToStart,
                          background: _buildSwipeBackground(context),
                          confirmDismiss: (_) async {
                            // تأكيد بسيط أو مباشرة (نستخدم مباشرة + تراجع)
                            return true;
                          },
                          onDismissed: (_) {
                            // تحديث متفائل في الواجهة
                            context.read<FavoriteCubit>().removeFavoriteItem(item);

                            // استدعاء API في الخلفية (سريع)
                            context
                                .read<FavoriteCubit>()
                                .favoriteRepository
                                .manageFavorites(item.id!);

                            // تراجع
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text("تمت إزالة العنصر من المفضلة"),
                                action: SnackBarAction(
                                  label: "تراجع",
                                  onPressed: () {
                                    context
                                        .read<FavoriteCubit>()
                                        .addFavoriteitem(item);
                                    // مزامنة مع السيرفر مرة ثانية (اختياري)
                                    context
                                        .read<FavoriteCubit>()
                                        .favoriteRepository
                                        .manageFavorites(item.id!);
                                  },
                                ),
                              ),
                            );
                          },
                          child: InkWell(
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
                          ),
                        );
                      },
                    ),

                    // زر للأعلى
                    if (_showToTop)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          backgroundColor: context.color.territoryColor,
                          foregroundColor: context.color.secondaryColor,
                          onPressed: () {
                            _controller.animateTo(
                              0,
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: const Icon(Icons.arrow_upward_rounded),
                        ),
                      ),
                  ],
                );
              }

              // حالة افتراضية
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.delete_forever_rounded,
          color: Colors.red.withOpacity(0.85)),
    );
  }

  // شيمر أقرب لمقاسات الكرت الأفقي
  Widget _shimmerEffect(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.color.borderColor.darken(30),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: CustomShimmer(width: 96, height: 96),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomShimmer(height: 12, width: c.maxWidth * 0.65),
                        const SizedBox(height: 10),
                        const CustomShimmer(height: 10),
                        const SizedBox(height: 8),
                        CustomShimmer(height: 10, width: c.maxWidth * 0.8),
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: CustomShimmer(width: c.maxWidth * 0.25),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
