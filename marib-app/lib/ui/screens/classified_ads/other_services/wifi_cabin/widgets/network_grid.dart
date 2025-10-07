part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

class _NetworksGrid extends StatelessWidget {
  const _NetworksGrid({
    super.key,
    required this.networks,
    required this.onSelect,
    required this.locationDenied,
    required this.onEnableLocation,
  });

  final List<WifiNetwork> networks;
  final ValueChanged<WifiNetwork> onSelect;
  final bool locationDenied;
  final VoidCallback onEnableLocation;

  @override
  Widget build(BuildContext context) {
    if (networks.isEmpty) {
      return _EmptyState(
        title: 'لا توجد شبكات ضمن النطاق',
        subtitle: locationDenied
            ? 'فعّل خدمات الموقع أو زد نطاق البحث.'
            : 'جرّب زيادة نطاق البحث بالكيلومترات.',
        onAction: locationDenied ? onEnableLocation : null,
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: networks.length,
      itemBuilder: (context, index) {
        final network = networks[index];
        final distance = network.distanceKm;
        final distanceLabel = distance == null
            ? 'المسافة غير متاحة'
            : 'يبعد ${distance.toStringAsFixed(1)} كم';

        return _WifiNetworkCard(
          name: network.name,
          distanceText: distanceLabel,
          rating: network.rating ?? 0,
          onTap: () => onSelect(network),
        );
      },
    );
  }
}

class _WifiNetworkCard extends StatelessWidget {
  const _WifiNetworkCard({
    required this.name,
    required this.distanceText,
    required this.rating,
    required this.onTap,
  });

  final String name;
  final String distanceText;
  final double rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 70,
                width: double.infinity,
                color: color.secondaryColor,
                alignment: Alignment.center,
                child: const Icon(Icons.wifi, size: 36),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.textDefaultColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              distanceText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.textDefaultColor.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(
                    color: color.textDefaultColor.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}