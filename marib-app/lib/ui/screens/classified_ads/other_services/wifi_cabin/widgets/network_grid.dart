part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

class _NetworksGrid extends StatelessWidget {
  const _NetworksGrid({
    super.key,
    required this.networks,
    required this.onSelect,
    required this.onRefresh,
    required this.searchQuery,
  });

  final List<WifiNetwork> networks;
  final ValueChanged<WifiNetwork> onSelect;
  final VoidCallback onRefresh;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    if (networks.isEmpty) {
      final String trimmed = searchQuery.trim();
      final String subtitle = trimmed.isEmpty
          ? 'ابدأ بالبحث عن اسم الشبكة أو راجع قائمة الشبكات المتاحة من مزودي الخدمة.'
          : 'لم يتم العثور على نتائج لـ "$trimmed". جرّب جزءًا من الاسم أو تحقق من التهجئة.';
      return _EmptyState(
        title: 'لم يتم العثور على شبكات',
        subtitle: subtitle,
        onAction: onRefresh,
        actionLabel: 'تحديث القائمة',
      );
    }

    return GridView.builder(

      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: networks.length,
      itemBuilder: (context, index) {
        final WifiNetwork network = networks[index];
        final String subtitle = network.planCount > 0
            ? 'عدد الفئات: ${network.planCount}'
            : 'اطلع على تفاصيل الشبكة';
        final String? currencyBadge = network.currencies.isNotEmpty
            ? network.currencies.first
            : null;

        return _WifiNetworkCard(
          name: network.name,
          subtitle: subtitle,
          imageUrl: network.iconUrl ?? network.loginScreenshotUrl,
          currencyBadge: currencyBadge,
          onTap: () => onSelect(network),
        );
      },
    );
  }
}

class _WifiNetworkCard extends StatelessWidget {
  const _WifiNetworkCard({
    required this.name,
    required this.subtitle,
    this.imageUrl,
    this.currencyBadge,
    required this.onTap,
  });

  final String name;
  final String subtitle;

  final VoidCallback onTap;
  final String? imageUrl;
  final String? currencyBadge;
  @override
  Widget build(BuildContext context) {
    final color = context.color;

    Widget buildImage() {
      if (imageUrl == null || imageUrl!.isEmpty) {
        return Container(
          height: 70,
          width: double.infinity,
          color: color.secondaryColor,
          alignment: Alignment.center,
          child: const Icon(Icons.wifi, size: 36),
        );
      }

      return Image.network(
        imageUrl!,
        height: 70,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 70,
            width: double.infinity,
            color: color.secondaryColor,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, _, __) {
          return Container(
            height: 70,
            width: double.infinity,
            color: color.secondaryColor,
            alignment: Alignment.center,
            child: const Icon(Icons.wifi, size: 36),
          );
        },
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(child: buildImage()),
                  if (currencyBadge != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          currencyBadge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
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
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.textDefaultColor.withOpacity(0.8),
                fontSize: 11,
              ),
            ),

          ],
        ),
      ),
    );
  }
}