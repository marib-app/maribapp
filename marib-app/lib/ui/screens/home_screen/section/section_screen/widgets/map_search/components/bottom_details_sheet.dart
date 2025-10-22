import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/theme/theme.dart';

import 'auto_scroll_text.dart';
import 'map_search_types.dart';

class BottomDetailsSheet extends StatelessWidget {
  final bool open;
  final ItemModel? ad;
  final ImageUrlResolver? imageUrlResolver;
  final PriceFormatter priceFormatter;
  final VoidCallback onClose;
  final VoidCallback onOpenDetails;

  const BottomDetailsSheet({
    super.key,
    required this.open,
    required this.ad,
    required this.imageUrlResolver,
    required this.priceFormatter,
    required this.onClose,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.color.territoryColor;
    final currentAd = ad;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: open ? 0 : -360,
      child: IgnorePointer(
        ignoring: !open,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: open ? 1 : 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: currentAd == null
                  ? const SizedBox.shrink()
                  : Material(
                      elevation: 22,
                      color: Theme.of(context).cardColor,
                      shadowColor: Colors.black.withOpacity(.35),
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AdHeroHeader(
                            ad: currentAd,
                            priceFormatter: priceFormatter,
                            brand: brand,
                            imageBuilder: (context) =>
                                _previewImage(context, currentAd),
                            onClose: onClose,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AutoScrollText(
                                  text:
                                      currentAd.name?.trim().isNotEmpty == true
                                          ? currentAd.name!
                                          : 'إعلان عقاري',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  gap: 40,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(.7),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        currentAd.address?.trim().isNotEmpty ==
                                                true
                                            ? currentAd.address!.trim()
                                            : 'بدون عنوان محدد',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(.75),
                                          height: 1.3,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: onClose,
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: brand,
                                        ),
                                        label: Text(
                                          'إغلاق البطاقة',
                                          style: TextStyle(color: brand),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: brand.withOpacity(.7),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: onOpenDetails,
                                        icon: const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 20,
                                        ),
                                        label: const Text('عرض التفاصيل'),
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: brand,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewImage(BuildContext context, ItemModel? ad) {
    final url = (ad == null) ? null : imageUrlResolver?.call(ad);
    if (url != null && url.isNotEmpty) {
      return Image.network(url, fit: BoxFit.cover);
    }
    return Container(
      color: Theme.of(context).dividerColor.withOpacity(.12),
      child: Icon(
        Icons.image_outlined,
        size: 36,
        color: Theme.of(context).hintColor,
      ),
    );
  }
}

class _AdHeroHeader extends StatelessWidget {
  final ItemModel ad;
  final PriceFormatter priceFormatter;
  final Color brand;
  final WidgetBuilder imageBuilder;
  final VoidCallback onClose;

  const _AdHeroHeader({
    required this.ad,
    required this.priceFormatter,
    required this.brand,
    required this.imageBuilder,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final priceText = priceFormatter(ad);
    final currency = (ad.currency ?? '').trim();

    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: imageBuilder(context)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(.05),
                    Colors.black.withOpacity(.45),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.48),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                color: Colors.white,
                tooltip: 'إغلاق البطاقة',
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sell_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        priceText.isNotEmpty ? priceText : 'السعر غير متاح',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (currency.isNotEmpty)
                        Text(
                          currency,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.85),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: brand.withOpacity(.82),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ad.category?.name ?? ad.type ?? 'إعلان',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
