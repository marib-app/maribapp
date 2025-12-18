import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:marib/data/model/merchant/storefront_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class MerchantStorefrontHeader extends StatelessWidget {
  const MerchantStorefrontHeader({
    required this.details,
    this.onCallTap,
    this.onWhatsappTap,
    this.onDirectionsTap,
    this.onFollowTap,
    this.isFollowingOverride,
    this.followersCountOverride,
    this.isFollowLoading = false,
    super.key,
  });

  final StorefrontDetails details;
  final VoidCallback? onCallTap;
  final VoidCallback? onWhatsappTap;
  final VoidCallback? onDirectionsTap;
  final VoidCallback? onFollowTap;
  final bool? isFollowingOverride;
  final int? followersCountOverride;
  final bool isFollowLoading;

  @override
  Widget build(BuildContext context) {
    final int followersCount =
        followersCountOverride ?? details.followersCount ?? 0;
    final bool isFollowing = isFollowingOverride ?? details.isFollowed;
    final int? itemsCount = details.itemsCount;
    final double? ratingsAverage = details.ratingsAverage;
    final bool hasAbout =
        (details.description?.trim().isNotEmpty ?? false) ||
            details.policies.isNotEmpty ||
            (details.settings?.checkoutNotice?.trim().isNotEmpty ?? false);

    const double avatarSize = 64;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StorefrontHero(
          details: details,
          avatarSize: avatarSize,
          isFollowing: isFollowing,
          isFollowLoading: isFollowLoading,
          onFollowTap: onFollowTap,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StorefrontStatsRow(
                followersCount: followersCount,
                itemsCount: itemsCount,
                ratingsAverage: ratingsAverage,
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (onCallTap != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: _StorefrontActionChip(
                          label: 'callBtnLbl'.translate(context),
                          icon: Icons.call_rounded,
                          onTap: onCallTap,
                        ),
                      ),
                    if (onWhatsappTap != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: _StorefrontActionChip(
                          label:
                              'storefrontWhatsappAction'.translate(context),
                          iconData: FontAwesomeIcons.whatsapp,
                          iconColor: const Color(0xFF25D366),
                          onTap: onWhatsappTap,
                        ),
                      ),
                    if (onDirectionsTap != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: _StorefrontActionChip(
                          label:
                              'storefrontDirectionsAction'.translate(context),
                          icon: Icons.location_on_rounded,
                          onTap: onDirectionsTap,
                        ),
                      ),
                    if (hasAbout)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: _StorefrontActionChip(
                          label: 'حول',
                          icon: Icons.info_outline_rounded,
                          onTap: () => _showAboutSheet(context, details),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _showAboutSheet(BuildContext context, StorefrontDetails details) {
  final String? description = details.description?.trim();
  final List<StorefrontPolicy> policies = details.policies;
  final String? returnPolicy = details.settings?.checkoutNotice?.trim();
  final List<Widget> policyEntries = <Widget>[];

  if (returnPolicy != null && returnPolicy.isNotEmpty) {
    policyEntries.add(
      Text(
        returnPolicy,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  for (final StorefrontPolicy policy in policies) {
    final String content = policy.content.trim();
    if (content.isEmpty) continue;
    policyEntries.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (policy.title.trim().isNotEmpty)
              Text(
                policy.title,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 4),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.9,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        builder: (_, controller) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SingleChildScrollView(
              controller: controller,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'حول المتجر',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (description != null && description.isNotEmpty)
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    Text(
                      'لا يوجد وصف للمتجر.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 18),
                  Divider(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                    thickness: 1,
                    height: 1,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'سياسة الاسترجاع الخاصة بالتاجر',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (policyEntries.isNotEmpty)
                    ...policyEntries
                  else
                    Text(
                      'لا توجد سياسة استرجاع متاحة.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _StorefrontHero extends StatelessWidget {
  const _StorefrontHero({
    required this.details,
    required this.avatarSize,
    required this.isFollowing,
    this.isFollowLoading = false,
    this.onFollowTap,
  });

  final StorefrontDetails details;
  final double avatarSize;
  final bool isFollowing;
  final bool isFollowLoading;
  final VoidCallback? onFollowTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return SizedBox(
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _StorefrontBanner(details: details)),
          PositionedDirectional(
            bottom: 12,
            start: 16,
            end: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _StoreAvatar(
                  logoUrl: details.logoUrl,
                  size: avatarSize,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        details.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _StatusChip(
                        label: details.status.displayLabel,
                        isOpen: details.status.isOpenNow,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: isFollowLoading ? null : onFollowTap ?? () {},
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surface.withValues(alpha: 0.9),
                    foregroundColor: colors.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: isFollowLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(colors.primary),
                          ),
                        )
                      : Icon(
                          isFollowing
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 20,
                        ),
                  tooltip: isFollowing
                      ? 'storefrontFollowCta'.translate(context)
                      : 'storefrontFollowCta'.translate(context),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StorefrontStatsRow extends StatelessWidget {
  const _StorefrontStatsRow({
    this.followersCount,
    this.itemsCount,
    this.ratingsAverage,
  });

  final int? followersCount;
  final int? itemsCount;
  final double? ratingsAverage;

  String _formatInt(int? value) {
    if (value == null) return '0';
    return value.toString();
  }

  String _formatRating(double? value) {
    if (value == null) return '—';
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _MetricTile(
            icon: Icons.people_outline_rounded,
            value: _formatInt(followersCount),
            label: 'Followers',
          ),
          _VerticalDivider(color: colors.onSurface.withValues(alpha: 0.08)),
          _MetricTile(
            icon: Icons.inventory_2_outlined,
            value: _formatInt(itemsCount),
            label: 'Products',
          ),
          _VerticalDivider(color: colors.onSurface.withValues(alpha: 0.08)),
          _MetricTile(
            icon: Icons.star_rate_rounded,
            value: _formatRating(ratingsAverage),
            label: 'Rating',
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 1,
      height: 34,
      color: color,
    );
  }
}

class _StorefrontBanner extends StatelessWidget {
  const _StorefrontBanner({required this.details});

  final StorefrontDetails details;

  @override
  Widget build(BuildContext context) {
    final bool hasBanner = details.bannerUrl?.trim().isNotEmpty == true;
    final Color fallbackColor = context.color.secondaryColor;

    return SizedBox(
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasBanner)
            UiUtils.getImage(
              details.bannerUrl!,
              fit: BoxFit.cover,
            )
          else
            Container(color: fallbackColor),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({this.logoUrl, this.size = 72});

  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool hasLogo = logoUrl?.trim().isNotEmpty == true;
    final Color borderColor = context.color.surface;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
      ),
      child: ClipOval(
        child: hasLogo
            ? UiUtils.getImage(
                logoUrl!,
                fit: BoxFit.cover,
              )
            : Container(
                color: context.color.secondaryColor,
                child: Icon(
                  Icons.storefront_rounded,
                  color: context.color.territoryColor,
                ),
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.isOpen,
  });

  final String label;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color successAccent = context.color.territoryColor;
    final Color background = isOpen
        ? successAccent.withValues(alpha: 0.12)
        : theme.colorScheme.errorContainer.withValues(alpha: 0.3);

    final Color foreground =
        isOpen ? successAccent : theme.colorScheme.error;

    String localizeLabel(String raw) {
      final String normalized = raw.toLowerCase();
      if (normalized.contains('open')) {
        return 'storefrontOpenNow'.translate(context);
      }
      if (normalized.contains('closed') || normalized.contains('close')) {
        return 'storefrontClosedNow'.translate(context);
      }
      return raw;
    }

    final String sanitizedLabel = label.trim();
    final String effectiveLabel = sanitizedLabel.isEmpty
        ? (isOpen
            ? 'storefrontOpenNow'.translate(context)
            : 'storefrontClosedNow'.translate(context))
        : localizeLabel(sanitizedLabel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        effectiveLabel,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StorefrontActionChip extends StatelessWidget {
  const _StorefrontActionChip({
    required this.label,
    this.icon,
    this.iconData,
    this.iconColor,
    this.onTap,
  }) : assert(icon != null || iconData != null);

  final String label;
  final IconData? icon;
  final IconData? iconData;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? iconData!,
                size: 18,
                color: iconColor ?? colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}










