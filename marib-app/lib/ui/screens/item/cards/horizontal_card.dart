import 'package:marib/ui/screens/widgets/promoted_widget.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/string_extenstion.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/app_theme.dart';
import 'package:marib/data/repositories/favourites_repository.dart';
import 'package:marib/data/cubits/favorite/favorite_cubit.dart';
import 'package:marib/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/utils/constant.dart';
import 'package:marquee/marquee.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/geo_rules.dart';
import 'package:marib/utils/currency_utils.dart';










/// ✅ تعريف كلاس حالة الإعلان (محجوز / مباعة...)
class StatusButton {
  final String lable;
  final Color color;
  final Color? textColor;

  StatusButton({
    required this.lable,
    required this.color,
    this.textColor,
  });
}

/// ✅ ويدجت لحالة الإعلان (مباعة / محجوزة...)
class StatusBadgeWidget extends StatelessWidget {
  final StatusButton status;

  const StatusBadgeWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      width: 80,
      height: 24,
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(status.lable)
            .size(context.font.small)
            .bold()
            .color(status.textColor ?? Colors.black),
      ),
    );
  }
}

/// ✅ صورة المنتج + شعار promoted + شارة "جديد"
class ItemImageSection extends StatelessWidget {
  final ItemModel item;
  final double imageHeight;
  final double imageWidth;
  final StatusButton? statusButton;

  const ItemImageSection({
    super.key,
    required this.item,
    required this.imageHeight,
    required this.imageWidth,
    this.statusButton,
  });

  bool _isItemNew(String? created) {
    if (created == null) return false;
    try {
      final d = DateTime.parse(created);
      return DateTime.now().difference(d).inHours < 24;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _isItemNew(item.created);

    final String? preferredThumb =
    (item.thumbnailUrl?.trim().isNotEmpty ?? false) ? item.thumbnailUrl : null;
    final String? fallbackThumb =
    (item.thumbnailFallbackUrl?.trim().isNotEmpty ?? false)
        ? item.thumbnailFallbackUrl
        : item.image;
    final String resolvedUrl =
        preferredThumb ?? fallbackThumb ?? item.image ?? '';

    return Column(
      children: [
        Stack(
          children: [
            // ✅ صورة مباشرة (بدون شيمر)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RepaintBoundary(
                child: UiUtils.getImage(
                  resolvedUrl,
                  height: imageHeight,
                  width: imageWidth,
                  fit: BoxFit.cover,
                  fallbackUrl: fallbackThumb,
                  cacheWidth: 200,
                  cacheHeight: 200,
                ),
              ),
            ),

            // ⭐ شارة "مميز"
            if (item.isFeature ?? false)
              const PositionedDirectional(
                start: 5,
                top: 5,
                child: PromotedCard(type: PromoteCardType.icon),
              ),

            // 🟨 شارة "جديد" خلال 24 ساعة
            if (isNew)
              PositionedDirectional(
                start: 5,
                top: (item.isFeature ?? false) ? 5 + 26 : 5,
                child: const _NewBadge(),
              ),
          ],
        ),

        // ✅ حالة الإعلان (اختياري)
        if (statusButton != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IntrinsicWidth(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                height: 24,
                decoration: BoxDecoration(
                  color: statusButton!.color,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(statusButton!.lable)
                      .size(context.font.small)
                      .bold()
                      .color(statusButton?.textColor ?? Colors.black),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ✅ ويدجت شارة "جديد"
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

/// ✅ زر الإعجاب المخصص داخل البطاقة
class FavoriteButtonWidget extends StatelessWidget {
  final ItemModel item;

  const FavoriteButtonWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    bool isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);

    return BlocProvider(
      create: (_) => UpdateFavoriteCubit(FavoriteRepository()),
      child: BlocConsumer<FavoriteCubit, FavoriteState>(
        bloc: context.read<FavoriteCubit>(),
        listener: (_, state) {
          if (state is FavoriteFetchSuccess) {
            isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);
          }
        },
        builder: (_, __) {
          return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
            bloc: context.read<UpdateFavoriteCubit>(),
            listener: (_, state) {
              if (state is UpdateFavoriteSuccess) {
                final favCubit = context.read<FavoriteCubit>();
                state.wasProcess
                    ? favCubit.addFavoriteitem(state.item)
                    : favCubit.removeFavoriteItem(state.item);
              }
            },
            builder: (context, state) {
              return InkWell(
                onTap: () {
                  UiUtils.checkUser(
                    context: context,
                    onNotGuest: () {
                      context.read<UpdateFavoriteCubit>().setFavoriteItem(
                        item: item,
                        type: isLike ? 0 : 1,
                      );
                    },
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    shape: BoxShape.circle,
                    boxShadow:
                    context.watch<AppThemeCubit>().state.appTheme ==
                        AppTheme.dark
                        ? null
                        : [
                      const BoxShadow(
                        color: Color.fromARGB(12, 0, 0, 0),
                        offset: Offset(0, 2),
                        blurRadius: 10,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.none,
                    child: state is UpdateFavoriteInProgress
                        ? Center(child: UiUtils.progress())
                        : UiUtils.getSvg(
                      isLike ? AppIcons.like_fill : AppIcons.like,
                      width: 22,
                      height: 22,
                      color: context.color.territoryColor,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ✅ التفاصيل اليمنى (اسم - سعر - موقع - زر إعجاب)
class ItemDetailsSection extends StatelessWidget {
  final ItemModel item;
  final bool showLikeButton;

  const ItemDetailsSection({
    super.key,
    required this.item,
    this.showLikeButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final String? address =
    (item.address?.trim().isNotEmpty ?? false) ? item.address : null;
    final bool hideLocation = GeoRules.isDisabledForItem(item);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),

        // ✅ اسم المنتج (Marquee عند الطول)
        Builder(
          builder: (context) {
            final title = item.name?.firstUpperCase() ?? "بدون عنوان";
            final dynamicFontSize =
            title.length > 30 ? context.font.smaller : context.font.normal;
            final style = TextStyle(
              fontSize: dynamicFontSize,
              color: context.color.textDefaultColor,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  blurRadius: 1,
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 0.5),
                ),
              ],
            );

            if (title.length > 28) {
              return SizedBox(
                height: (style.fontSize ?? 14) + 2,
                child: Marquee(
                  text: title,
                  style: style,
                  scrollAxis: Axis.horizontal,
                  blankSpace: 30.0,
                  velocity: 25.0,
                  pauseAfterRound: const Duration(seconds: 1),
                  startPadding: 10.0,
                  accelerationDuration: const Duration(seconds: 1),
                  decelerationDuration: const Duration(milliseconds: 500),
                ),
              );
            }
            return Text(title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
          },
        ),

        // 🟢 السعر + زر الإعجاب
        Row(
          children: [
            Expanded(
              child: _PriceInline(
                price: item.price,
                currency: item.currency,
                currencyCode: item.currencyCode,
                textColor: context.color.textDefaultColor,
                priceColor: context.color.territoryColor,
                style: TextStyle(fontSize: context.font.normal),
              ),
            ),
            if (showLikeButton) favButton(item: item, size: 32),

          ],
        ),

        // 📍 الموقع (إن وُجد)
        if (!hideLocation && address != null)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: context.color.textDefaultColor.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final style = TextStyle(
                        fontSize: context.font.smaller,
                        color:
                        context.color.textDefaultColor.withOpacity(0.5),
                      );
                      if ((address?.length ?? 0) > 28) {
                        return SizedBox(
                          height: style.fontSize! + 2,
                          child: Marquee(
                            text: address ?? "",
                            style: style,
                            scrollAxis: Axis.horizontal,
                            blankSpace: 30.0,
                            velocity: 25.0,
                            pauseAfterRound: const Duration(seconds: 1),
                            startPadding: 10.0,
                            accelerationDuration:
                            const Duration(seconds: 1),
                            decelerationDuration:
                            const Duration(milliseconds: 500),
                          ),
                        );
                      }
                      return Text(address ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}




Widget favButton({required ItemModel item, required double size}) {
  return BlocProvider(
    create: (context) => UpdateFavoriteCubit(FavoriteRepository()),
    child: Builder(
      builder: (context) {
        return BlocConsumer<FavoriteCubit, FavoriteState>(
          bloc: context.read<FavoriteCubit>(),
          listener: (context, state) {
            // لما تجي نتيجة التفضيلات
          },
          builder: (context, likeAndDislikeState) {
            bool isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);

            return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
              bloc: context.read<UpdateFavoriteCubit>(),
              listener: (context, state) {
                if (state is UpdateFavoriteSuccess) {
                  if (state.wasProcess) {
                    context.read<FavoriteCubit>().addFavoriteitem(state.item);
                  } else {
                    context.read<FavoriteCubit>().removeFavoriteItem(state.item);
                  }
                }
              },
              builder: (context, state) {
                final inProgress = state is UpdateFavoriteInProgress;

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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                          context.read<UpdateFavoriteCubit>().setFavoriteItem(
                            item: item,
                            type: isLike ? 0 : 1,
                          );

                          UiUtils.showSoftSnackBar(
                            context,
                            message: isLike
                                ? "تمت الإزالة من المفضلة"
                                : "تمت الإضافة إلى المفضلة",
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









/// ✅ ويدجت سعر مبسط (بدون شيمر)
class _PriceInline extends StatelessWidget {
  final num? price;
  final String? currency;
  final String? currencyCode;
  final Color textColor;
  final Color priceColor;
  final TextStyle style;
  final double spacing;

  const _PriceInline({
    required this.price,
    required this.currency,
    required this.textColor,
    required this.priceColor,
    required this.style,
    this.currencyCode,
    this.spacing = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _priceLabel,
          style: style.copyWith(color: priceColor),
        ).bold(),
        SizedBox(width: spacing),
        Text(
          _currencyLabel,
          style: style.copyWith(
            fontSize:
            style.fontSize != null ? style.fontSize! * 0.75 : null,
            color: textColor.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  String get _priceLabel {
    final formatted = HelperUtils.formatPrice(price);
    if (formatted.isEmpty) {
      return 'غير متوفر';
    }
    return formatted;
  }
  String get _currencyLabel {
    final String? preferred =
    CurrencyUtils.preferredDisplayFor(currencyCode ?? currency);
    if (preferred != null && preferred.trim().isNotEmpty) {
      return preferred.trim();
    }

    final String? trimmed = currency?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      final String? normalized =
          CurrencyUtils.preferredDisplayFor(trimmed) ?? trimmed;
      if (normalized.trim().isNotEmpty) {
        return normalized.trim();
      }
    }

    return CurrencyUtils.preferredDisplayFor('YER') ?? Constant.currencySymbol;
  }

}

/// ✅ الكارد الأفقي
class ItemHorizontalCard extends StatelessWidget {
  final ItemModel item;
  final List<Widget>? addBottom;
  final double? additionalHeight;
  final StatusButton? statusButton;
  final bool? useRow;
  final VoidCallback? onTap;
  final double? additionalImageWidth;
  final bool? showLikeButton;

  const ItemHorizontalCard({
    super.key,
    required this.item,
    this.onTap,
    this.useRow,
    this.addBottom,
    this.additionalHeight,
    this.statusButton,
    this.additionalImageWidth,
    this.showLikeButton,
  });

  @override
  Widget build(BuildContext context) {
    final double cardHeight = 124 + (additionalHeight ?? 0);
    final double imageWidth = 100 + (additionalImageWidth ?? 0);

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 4.5),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: context.color.borderColor, width: 1),
      ),
      child: SizedBox(
        height: cardHeight,
        child: Row(
          children: [
            ItemImageSection(
              item: item,
              imageHeight: cardHeight - 2,
              imageWidth: imageWidth,
              statusButton: statusButton,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ItemDetailsSection(
                item: item,
                showLikeButton: showLikeButton ?? true,
              ),
            ),
          ],
        ),
      ),
    );

  }
}




