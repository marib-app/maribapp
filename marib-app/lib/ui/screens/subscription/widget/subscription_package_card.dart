import 'package:flutter/material.dart';
import 'package:marib/data/model/subscription_pacakage_model.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';

class SubscriptionPackageCard extends StatelessWidget {
  const SubscriptionPackageCard({
    super.key,
    required this.model,
    required this.position,
    required this.selected,
    required this.accentColor,
    required this.icon,
    required this.categoryLabel,
    required this.onTap,
  });

  final SubscriptionPackageModel model;
  final int position;
  final bool selected;
  final Color accentColor;
  final IconData icon;
  final String categoryLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final bool isActive = model.isActive ?? false;
    final double priceValue = (model.finalPrice ?? model.price ?? 0).toDouble();
    final bool isFree = priceValue <= 0;
    final String priceLabel = isFree
        ? 'free'.translate(context)
        : '${HelperUtils.formatPrice(priceValue)} ${model.currency ?? ''}'.trim();
    final bool hasDiscount =
        !isFree && (model.discount ?? 0) > 0 && (model.price ?? 0) > priceValue;
    final String? oldPriceLabel = hasDiscount
        ? '${HelperUtils.formatPrice(model.price)} ${model.currency ?? ''}'.trim()
        : null;

    final String? remainingItems = _cleanValue(
        model.userPurchasedPackages?.isNotEmpty == true
            ? model.userPurchasedPackages!.first.remainingItemLimit
            : null);
    final String? remainingDays = _cleanValue(
        model.userPurchasedPackages?.isNotEmpty == true
            ? model.userPurchasedPackages!.first.remainingDays
            : null);

    final String limitLabel = _buildLimitLabel(context);
    final String durationLabel = _buildDurationLabel(context);
    final String description = _buildDescription(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color:
                selected ? accentColor : colors.borderColor.withOpacity(0.45),
            width: selected ? 1.8 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    accentColor.withOpacity(0.18),
                    colors.secondaryColor,
                  ]
                : [
                    colors.secondaryColor,
                    colors.secondaryColor,
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accentColor.withOpacity(0.22)
                  : Colors.black.withOpacity(0.08),
              blurRadius: selected ? 30 : 18,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textLightColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        model.name?.trim().isNotEmpty == true
                            ? model.name!.trim()
                            : 'باقة رقم $position',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: colors.textDefaultColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                _PositionBadge(position: position, accentColor: accentColor),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textDefaultColor.withOpacity(0.72),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: durationLabel,
                  accentColor: accentColor,
                ),
                if (limitLabel.isNotEmpty)
                  _InfoChip(
                    icon: Icons.layers_outlined,
                    label: limitLabel,
                    accentColor: accentColor,
                  ),
                if (remainingItems != null)
                  _InfoChip(
                    icon: Icons.playlist_add_check_rounded,
                    label: 'المتبقي: $remainingItems',
                    accentColor: accentColor,
                  ),
                if (remainingDays != null)
                  _InfoChip(
                    icon: Icons.timer_rounded,
                    label:
                        'أيام متبقية: $remainingDays',
                    accentColor: accentColor,
                  ),
                if (isActive)
                  _StatusChip(
                    label: 'activePlanLbl'.translate(context),
                    accentColor: accentColor,
                    foregroundColor: colors.secondaryColor,
                  )
                else if (isFree)
                  _StatusChip(
                    label: 'free'.translate(context),
                    accentColor: accentColor,
                    foregroundColor: accentColor,
                    softBackground: true,
                  ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      priceLabel,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (oldPriceLabel != null && oldPriceLabel.isNotEmpty)
                      Text(
                        oldPriceLabel,
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: colors.textLightColor,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.touch_app_rounded,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildLimitLabel(BuildContext context) {
    final raw = model.limit?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') {
      return '';
    }
    final bool unlimited = raw.toLowerCase() == 'unlimited';
    final String base =
        unlimited ? 'unlimitedLbl'.translate(context) : raw.trim();
    final String typeLabel = (model.type ?? '').toLowerCase().contains('feature')
        ? 'featuredAdsLbl'.translate(context)
        : 'adsListing'.translate(context);
    return '$base · $typeLabel';
  }

  String _buildDurationLabel(BuildContext context) {
    final raw = model.duration?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') {
      return 'مدة غير محددة';
    }
    return '$raw ${"days".translate(context)}';
  }

  String _buildDescription(BuildContext context) {
    final raw = model.description?.trim();
    if (raw != null && raw.isNotEmpty && raw.toLowerCase() != 'null') {
      return raw;
    }
    return 'صممنا هذه الباقة لتمنح إعلانك دفعة إضافية من الظهور.';
  }

  String? _cleanValue(String? input) {
    if (input == null) return null;
    final normalized = input.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return null;
    }
    return normalized;
  }
}

class _PositionBadge extends StatelessWidget {
  const _PositionBadge({
    required this.position,
    required this.accentColor,
  });

  final int position;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: accentColor.withOpacity(0.12),
      ),
      child: Text(
        '#$position',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: accentColor,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accentColor.withOpacity(0.08),
        border: Border.all(
          color: accentColor.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textDefaultColor.withOpacity(0.78),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.accentColor,
    required this.foregroundColor,
    this.softBackground = false,
  });

  final String label;
  final Color accentColor;
  final Color foregroundColor;
  final bool softBackground;

  @override
  Widget build(BuildContext context) {
    final Color background = softBackground
        ? accentColor.withOpacity(0.08)
        : accentColor.withOpacity(0.8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: background,
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: softBackground ? accentColor : foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}