import 'package:flutter/cupertino.dart';
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
      icon: CupertinoIcons.rectangle_stack,
    ),
    EmptyStateIssue.network: _EmptyStateMessage(
      titleKey: 'emptyStateGeneralNetworkTitle',
      subtitleKey: 'emptyStateGeneralNetworkDescription',
      icon: CupertinoIcons.wifi,
    ),
    EmptyStateIssue.server: _EmptyStateMessage(
      titleKey: 'emptyStateGeneralServerTitle',
      subtitleKey: 'emptyStateGeneralServerDescription',
      icon: CupertinoIcons.cloud,
    ),
  },
  EmptyStateCategory.favorites: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateFavoritesTitle',
      subtitleKey: 'emptyStateFavoritesDescription',
      icon: CupertinoIcons.heart,
    ),
  },
  EmptyStateCategory.transactions: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateTransactionsTitle',
      subtitleKey: 'emptyStateTransactionsDescription',
      icon: CupertinoIcons.chart_bar,
    ),
  },
  EmptyStateCategory.subscriptions: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateSubscriptionsTitle',
      subtitleKey: 'emptyStateSubscriptionsDescription',
      icon: CupertinoIcons.mail,
    ),
  },
  EmptyStateCategory.wallet: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateWalletTitle',
      subtitleKey: 'emptyStateWalletDescription',
      icon: CupertinoIcons.money_dollar,
    ),
  },
  EmptyStateCategory.chat: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateChatTitle',
      subtitleKey: 'emptyStateChatDescription',
      icon: CupertinoIcons.chat_bubble,
    ),
  },
  EmptyStateCategory.blocked: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateBlockedTitle',
      subtitleKey: 'emptyStateBlockedDescription',
      icon: CupertinoIcons.nosign,
    ),
  },
  EmptyStateCategory.faqs: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateFaqsTitle',
      subtitleKey: 'emptyStateFaqsDescription',
      icon: CupertinoIcons.question_circle,
    ),
  },
  EmptyStateCategory.profile: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateProfileTitle',
      subtitleKey: 'emptyStateProfileDescription',
      icon: CupertinoIcons.person_crop_circle,
    ),
  },
  EmptyStateCategory.items: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateItemsTitle',
      subtitleKey: 'emptyStateItemsDescription',
      icon: CupertinoIcons.cube,
    ),
  },
  EmptyStateCategory.search: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateSearchTitle',
      subtitleKey: 'emptyStateSearchDescription',
      icon: CupertinoIcons.search,
    ),
  },
  EmptyStateCategory.notifications: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateNotificationsTitle',
      subtitleKey: 'emptyStateNotificationsDescription',
      icon: CupertinoIcons.bell_slash,
    ),
  },
  EmptyStateCategory.categories: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateCategoriesTitle',
      subtitleKey: 'emptyStateCategoriesDescription',
      icon: CupertinoIcons.square_grid_2x2,
    ),
  },
  EmptyStateCategory.location: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateLocationTitle',
      subtitleKey: 'emptyStateLocationDescription',
      icon: CupertinoIcons.map_pin,
    ),
  },
  EmptyStateCategory.advertisements: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateAdvertisementsTitle',
      subtitleKey: 'emptyStateAdvertisementsDescription',
      icon: CupertinoIcons.news,
    ),
  },
  EmptyStateCategory.reviews: {
    EmptyStateIssue.noData: _EmptyStateMessage(
      titleKey: 'emptyStateReviewsTitle',
      subtitleKey: 'emptyStateReviewsDescription',
      icon: CupertinoIcons.star,
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
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.32);
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
                  .bold(weight: FontWeight.w600),
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

    final resolvedSize = height ?? 64;

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
          side: BorderSide(color: onSurface.withOpacity(0.3)),
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
