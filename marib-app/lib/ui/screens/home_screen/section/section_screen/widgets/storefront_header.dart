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
    super.key,
  });

  final StorefrontDetails details;
  final VoidCallback? onCallTap;
  final VoidCallback? onWhatsappTap;
  final VoidCallback? onDirectionsTap;
  final VoidCallback? onFollowTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String? description = _clean(details.description);
    final String? locationText = details.location?.primaryLine;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StorefrontBanner(details: details),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StoreAvatar(logoUrl: details.logoUrl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            details.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
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
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onFollowTap ?? () {},
                      icon: const Icon(Icons.star_border_rounded, size: 18),
                      label: Text('storefrontFollowCta'.translate(context)),
                    ),
                  ],
                ),
                if (description != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (locationText != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locationText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      if (onDirectionsTap != null)
                        TextButton(
                          onPressed: onDirectionsTap,
                          child: Text(
                            'storefrontDirectionsAction'.translate(context),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (onCallTap != null)
                      _StorefrontActionChip(
                        label: 'callBtnLbl'.translate(context),
                        icon: Icons.call_rounded,
                        onTap: onCallTap,
                      ),
                    if (onWhatsappTap != null)
                      _StorefrontActionChip(
                        label: 'storefrontWhatsappAction'.translate(context),
                        iconData: FontAwesomeIcons.whatsapp,
                        iconColor: const Color(0xFF25D366),
                        onTap: onWhatsappTap,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _clean(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class _StorefrontBanner extends StatelessWidget {
  const _StorefrontBanner({required this.details});

  final StorefrontDetails details;

  @override
  Widget build(BuildContext context) {
    final bool hasBanner = details.bannerUrl?.trim().isNotEmpty == true;
    final Color fallbackColor = context.color.secondaryColor;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
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
      ),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final bool hasLogo = logoUrl?.trim().isNotEmpty == true;
    final Color borderColor = context.color.surface;

    return Container(
      width: 72,
      height: 72,
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

    final String effectiveLabel = label.trim().isEmpty
        ? (isOpen
            ? 'storefrontOpenNow'.translate(context)
            : 'storefrontClosedNow'.translate(context))
        : label.trim();

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
