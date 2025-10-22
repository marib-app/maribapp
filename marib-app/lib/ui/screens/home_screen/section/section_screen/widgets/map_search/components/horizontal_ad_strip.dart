import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/theme/theme.dart';

import 'auto_scroll_text.dart';
import 'map_search_types.dart';

class HorizontalAdStrip extends StatefulWidget {
  final List<ItemModel> ads;
  final ImageUrlResolver? imageUrlResolver;
  final PriceFormatter priceFormatter;
  final ValueChanged<ItemModel> onTapCard;
  final Future<void> Function()? onLoadMore;
  final bool hasMore;
  final bool isLoadingMore;

  const HorizontalAdStrip({
    super.key,
    required this.ads,
    required this.imageUrlResolver,
    required this.priceFormatter,
    required this.onTapCard,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  @override
  State<HorizontalAdStrip> createState() => _HorizontalAdStripState();
}

class _HorizontalAdStripState extends State<HorizontalAdStrip> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!widget.hasMore || widget.onLoadMore == null || widget.isLoadingMore) {
      return;
    }
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (!position.hasPixels) return;

    const threshold = 80.0;
    if (position.pixels >= position.maxScrollExtent - threshold) {
      widget.onLoadMore!();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (_, i) {
        final ad = widget.ads[i];

        return _AdThumbCard(
          ad: ad,
          imageUrl: widget.imageUrlResolver?.call(ad),
          price: widget.priceFormatter(ad),
          onTap: () => widget.onTapCard(ad),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemCount: widget.ads.length,
    );

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        list,
        if (widget.isLoadingMore)
          Positioned(
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withOpacity(.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(.2),
                ),
              ),
              child: const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdThumbCard extends StatelessWidget {
  final ItemModel ad;
  final String? imageUrl;
  final String price;
  final VoidCallback onTap;

  const _AdThumbCard({
    required this.ad,
    required this.imageUrl,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.color.territoryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(.98),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1,
                child: (imageUrl != null && imageUrl!.isNotEmpty)
                    ? Image.network(imageUrl!, fit: BoxFit.cover)
                    : Container(
                  color: Theme.of(context).dividerColor.withOpacity(.15),
                  child: const Icon(Icons.image, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoScrollText(
                    text: ad.name ?? 'إعلان عقاري',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    gap: 30,
                  ),
                  const Spacer(),
                  Text(
                    price.isEmpty ? '—' : price,
                    style: TextStyle(fontWeight: FontWeight.w700, color: brand),
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