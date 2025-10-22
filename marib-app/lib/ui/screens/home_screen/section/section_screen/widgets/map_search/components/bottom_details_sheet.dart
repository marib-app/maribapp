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

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      left: 0,
      right: 0,
      bottom: open ? 0 : -240,
      child: SafeArea(
        top: false,
        child: Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: (ad == null)
              ? const SizedBox.shrink()
              : Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _previewImage(context, ad),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoScrollText(
                      text: ad?.name ?? 'إعلان عقاري',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      gap: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ad?.address ?? 'بدون عنوان محدد',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      priceFormatter(ad!),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: brand,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: onClose,
                          icon: const Icon(Icons.close),
                          label: const Text('إغلاق'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: onOpenDetails,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('تفاصيل الإعلان'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
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
    );
  }

  Widget _previewImage(BuildContext context, ItemModel? ad) {
    final url = (ad == null) ? null : imageUrlResolver?.call(ad);
    if (url != null && url.isNotEmpty) {
      return Image.network(url, fit: BoxFit.cover);
    }
    return Container(
      color: Theme.of(context).dividerColor.withOpacity(.15),
      child: const Icon(Icons.image, size: 36),
    );
  }
}