import 'package:flutter/material.dart';
import 'package:marib/data/model/subscription_pacakage_model.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/ui/theme/theme.dart';

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
        : '${HelperUtils.formatPrice(priceValue)} ${model.currency ?? ''}'
            .trim();
    final bool hasDiscount =
        !isFree && (model.discount ?? 0) > 0 && (model.price ?? 0) > priceValue;
    final String? oldPriceLabel = hasDiscount
        ? '${HelperUtils.formatPrice(model.price)} ${model.currency ?? ''}'
            .trim()
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

    final Color accent = accentColor.withOpacity(0.9);
    final Color borderColor =
        selected ? accent : colors.borderColor.withOpacity(0.65);

    final chips = <Widget>[
      _InfoChip(
        icon: Icons.schedule_rounded,
        label: durationLabel,
        accentColor: accent,
      ),
    ];

    if (limitLabel.isNotEmpty) {
      chips.add(
        _InfoChip(
          icon: Icons.layers_outlined,
          label: limitLabel,
          accentColor: accent,
        ),
      );
    }
    if (remainingItems != null) {
      chips.add(
        _InfoChip(
          icon: Icons.playlist_add_check_rounded,
          label: 'المتبقي: $remainingItems',
          accentColor: accent,
        ),
      );
    }
    if (remainingDays != null) {
      chips.add(
        _InfoChip(
          icon: Icons.timer_rounded,
          label: 'أيام متبقية: $remainingDays',
          accentColor: accent,
        ),
      );
    }

    final statusChips = <Widget>[];
    if (isActive) {
      statusChips.add(
        _StatusChip(
          label: 'activePlanLbl'.translate(context),
          accentColor: accent,
          foregroundColor: colors.textDefaultColor,
        ),
      );
    } else if (isFree) {
      statusChips.add(
        _StatusChip(
          label: 'free'.translate(context),
          accentColor: accent,
          foregroundColor: accent,
          softBackground: true,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: colors.secondaryColor,
          border: Border.all(
            color: borderColor,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.08 : 0.03),
              blurRadius: selected ? 28 : 16,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: colors.backgroundColor,
                    border: Border.all(
                      color: colors.borderColor.withOpacity(0.6),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: accent,
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
                      const SizedBox(height: 6),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceLabel,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.textDefaultColor,
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
                    const SizedBox(height: 8),
                    _PositionBadge(position: position, accentColor: accent),
                    const SizedBox(height: 8),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected
                          ? accent
                          : colors.borderColor.withOpacity(0.6),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textDefaultColor.withOpacity(0.78),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (statusChips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: statusChips,
              ),
            ],
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: colors.borderColor.withOpacity(0.6),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: chips,
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
    final String typeLabel =
        (model.type ?? '').toLowerCase().contains('feature')
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
    final colors = context.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colors.backgroundColor,
        border: Border.all(
          color: accentColor.withOpacity(0.4),
        ),
      ),
      child: Text(
        '#$position',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: colors.textDefaultColor.withOpacity(0.8),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.backgroundColor,
        border: Border.all(
          color: colors.borderColor.withOpacity(0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: accentColor.withOpacity(0.9),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textDefaultColor.withOpacity(0.82),
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
    final colors = context.color;
    final Color background =
        softBackground ? colors.backgroundColor : accentColor.withOpacity(0.12);
    final Color border = accentColor.withOpacity(0.35);
    final Color textColor = softBackground ? accentColor : foregroundColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: background,
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
