import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

enum EmptyStateCategory {
  general,
  favorites,
  transactions,
  subscriptions,
  wallet,
  chat,
  blocked,
  faqs,
  profile,
  items,
  search,
  notifications,
  categories,
  location,
  advertisements,
  reviews,
}

enum EmptyStateIssue {
  noData,
  network,
  server,
}

class _EmptyStateMessage {
  const _EmptyStateMessage({
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
  });

  final String titleKey;
  final String subtitleKey;
  final IconData icon;
}

const Map<EmptyStateCategory, Map<EmptyStateIssue, _EmptyStateMessage>>
_emptyStateMessages = {
  EmptyStateCategory.general: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateGeneralTitle',
      subtitleKey: 'emptyStateGeneralDescription',
      icon: Icons.inbox_outlined,
    ),
    EmptyStateIssue.network: _EmptyStateMessage(
      titleKey: 'emptyStateGeneralNetworkTitle',
      subtitleKey: 'emptyStateGeneralNetworkDescription',
      icon: Icons.wifi_off_outlined,
    ),
    EmptyStateIssue.server: _EmptyStateMessage(
      titleKey: 'emptyStateGeneralServerTitle',
      subtitleKey: 'emptyStateGeneralServerDescription',
      icon: Icons.cloud_off_outlined,
    ),
  },
  EmptyStateCategory.favorites: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateFavoritesTitle',
      subtitleKey: 'emptyStateFavoritesDescription',
      icon: Icons.favorite_border,
    ),
  },
  EmptyStateCategory.transactions: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateTransactionsTitle',
      subtitleKey: 'emptyStateTransactionsDescription',
      icon: Icons.receipt_long_outlined,
    ),
  },
  EmptyStateCategory.subscriptions: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateSubscriptionsTitle',
      subtitleKey: 'emptyStateSubscriptionsDescription',
      icon: Icons.subscriptions_outlined,
    ),
  },
  EmptyStateCategory.wallet: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateWalletTitle',
      subtitleKey: 'emptyStateWalletDescription',
      icon: Icons.account_balance_wallet_outlined,
    ),
  },
  EmptyStateCategory.chat: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateChatTitle',
      subtitleKey: 'emptyStateChatDescription',
      icon: Icons.chat_bubble_outline,
    ),
  },
  EmptyStateCategory.blocked: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateBlockedTitle',
      subtitleKey: 'emptyStateBlockedDescription',
      icon: Icons.block_outlined,
    ),
  },
  EmptyStateCategory.faqs: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateFaqsTitle',
      subtitleKey: 'emptyStateFaqsDescription',
      icon: Icons.help_outline,
    ),
  },
  EmptyStateCategory.profile: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateProfileTitle',
      subtitleKey: 'emptyStateProfileDescription',
      icon: Icons.person_outline,
    ),
  },
  EmptyStateCategory.items: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateItemsTitle',
      subtitleKey: 'emptyStateItemsDescription',
      icon: Icons.widgets_outlined,
    ),
  },
  EmptyStateCategory.search: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateSearchTitle',
      subtitleKey: 'emptyStateSearchDescription',
      icon: Icons.search_outlined,
    ),
  },
  EmptyStateCategory.notifications: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateNotificationsTitle',
      subtitleKey: 'emptyStateNotificationsDescription',
      icon: Icons.notifications_none_outlined,
    ),
  },
  EmptyStateCategory.categories: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateCategoriesTitle',
      subtitleKey: 'emptyStateCategoriesDescription',
      icon: Icons.category_outlined,
    ),
  },
  EmptyStateCategory.location: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateLocationTitle',
      subtitleKey: 'emptyStateLocationDescription',
      icon: Icons.location_on_outlined,
    ),
  },
  EmptyStateCategory.advertisements: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateAdvertisementsTitle',
      subtitleKey: 'emptyStateAdvertisementsDescription',
      icon: Icons.campaign_outlined,
    ),
  },
  EmptyStateCategory.reviews: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateReviewsTitle',
      subtitleKey: 'emptyStateReviewsDescription',
      icon: Icons.rate_review_outlined,
    ),
  },
};

class NoDataFound extends StatelessWidget {
  const NoDataFound({
    super.key,
    this.height,
    this.mainMessage,
    this.subMessage,
    this.onTap,
    this.actionLabel,
    this.category = EmptyStateCategory.general,
    this.issue = EmptyStateIssue.noData,
    this.padding,
    this.customIllustration,
  });

  final double? height;
  final String? mainMessage;
  final String? subMessage;
  final VoidCallback? onTap;
  final String? actionLabel;
  final EmptyStateCategory category;
  final EmptyStateIssue issue;
  final EdgeInsetsGeometry? padding;
  final Widget? customIllustration;

  _EmptyStateMessage _resolveMessage() {
    final categoryMessages = _emptyStateMessages[category];
    final generalMessages =
    _emptyStateMessages[EmptyStateCategory.general]!;

    if (categoryMessages == null) {
      return generalMessages[issue] ??
          generalMessages[EmptyStateIssue.noData]!;
    }

    if (categoryMessages.containsKey(issue)) {
      return categoryMessages[issue]!;
    }

    if (categoryMessages.containsKey(EmptyStateIssue.noData)) {
      return categoryMessages[EmptyStateIssue.noData]!;
    }

    return generalMessages[issue] ??
        generalMessages[EmptyStateIssue.noData]!;
  }

  @override
  Widget build(BuildContext context) {
    final message = _resolveMessage();
    final palette = context.color;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.4);
    final titleColor = palette.textDefaultColor;
    final subtitleColor = palette.textLightColor;
    final resolvedTitle = mainMessage ?? message.titleKey.translate(context);
    final resolvedSubtitle =
        subMessage ?? message.subtitleKey.translate(context);

    return Center(
      child: Padding(
        padding:
        padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIllustration(context, message, iconColor),
              const SizedBox(height: 20),
              Text(
                resolvedTitle,
                textAlign: TextAlign.center,
              )
                  .size(context.font.extraLarge)
                  .color(titleColor)
                  .bold(weight: FontWeight.w700),
              const SizedBox(height: 10),
              Text(
                resolvedSubtitle,
                textAlign: TextAlign.center,
              )
                  .size(context.font.large)
                  .color(subtitleColor)
                  .centerAlign(),
              if (onTap != null) ...[
                const SizedBox(height: 28),
                _buildActionButton(context, onSurface),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration(
      BuildContext context,
      _EmptyStateMessage message,
      Color iconColor,
      ) {
    if (customIllustration != null) {
      return SizedBox(
        height: height ?? 120,
        width: height ?? 120,
        child: FittedBox(
          fit: BoxFit.contain,
          child: customIllustration!,
        ),
      );
    }

    final resolvedSize = height ?? 80;

    return Icon(
      message.icon,
      size: resolvedSize,
      color: iconColor,
    );
  }

  Widget _buildActionButton(BuildContext context, Color onSurface) {
    final label = (actionLabel ?? 'retry').translate(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: onSurface.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(label)
            .size(context.font.large)
            .bold(weight: FontWeight.w600),
      ),
    );
  }
}
