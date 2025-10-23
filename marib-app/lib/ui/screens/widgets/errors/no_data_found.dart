import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/material.dart';

import 'package:marib/utils/app_icon.dart';


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
    this.illustration,
  });

  final String titleKey;
  final String subtitleKey;
  final String? illustration;
}

const _defaultEmptyStateIllustration = AppIcons.no_data_found;

final Map<EmptyStateCategory, Map<EmptyStateIssue, _EmptyStateMessage>>
_emptyStateMessages = {
  EmptyStateCategory.general: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateGeneralTitle',
      subtitleKey: 'emptyStateGeneralDescription',
      illustration: _defaultEmptyStateIllustration,
    ),
    EmptyStateIssue.network: const _EmptyStateMessage(
      titleKey: 'emptyStateGeneralNetworkTitle',
      subtitleKey: 'emptyStateGeneralNetworkDescription',
      illustration: AppIcons.no_internet,
    ),
    EmptyStateIssue.server: const _EmptyStateMessage(
      titleKey: 'emptyStateGeneralServerTitle',
      subtitleKey: 'emptyStateGeneralServerDescription',
      illustration: AppIcons.somethingWentWrong,
    ),
  },
  EmptyStateCategory.favorites: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateFavoritesTitle',
      subtitleKey: 'emptyStateFavoritesDescription',
      illustration: AppIcons.like,
    ),
  },
  EmptyStateCategory.transactions: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateTransactionsTitle',
      subtitleKey: 'emptyStateTransactionsDescription',
      illustration: AppIcons.transaction,
    ),
  },
  EmptyStateCategory.subscriptions: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateSubscriptionsTitle',
      subtitleKey: 'emptyStateSubscriptionsDescription',
      illustration: AppIcons.subscription,
    ),
  },
  EmptyStateCategory.wallet: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateWalletTitle',
      subtitleKey: 'emptyStateWalletDescription',
      illustration: AppIcons.wallet,
    ),
  },
  EmptyStateCategory.chat: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateChatTitle',
      subtitleKey: 'emptyStateChatDescription',
      illustration: AppIcons.message,
    ),
  },
  EmptyStateCategory.blocked: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateBlockedTitle',
      subtitleKey: 'emptyStateBlockedDescription',
      illustration: AppIcons.blockedUserIcon,
    ),
  },
  EmptyStateCategory.faqs: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateFaqsTitle',
      subtitleKey: 'emptyStateFaqsDescription',
      illustration: AppIcons.faqsIcon,
    ),
  },
  EmptyStateCategory.profile: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateProfileTitle',
      subtitleKey: 'emptyStateProfileDescription',
      illustration: AppIcons.profile,
    ),
  },
  EmptyStateCategory.items: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateItemsTitle',
      subtitleKey: 'emptyStateItemsDescription',
      illustration: AppIcons.items,
    ),
  },
  EmptyStateCategory.search: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateSearchTitle',
      subtitleKey: 'emptyStateSearchDescription',
      illustration: AppIcons.search,
    ),
  },
  EmptyStateCategory.notifications: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateNotificationsTitle',
      subtitleKey: 'emptyStateNotificationsDescription',
      illustration: AppIcons.notification,
    ),
  },
  EmptyStateCategory.categories: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateCategoriesTitle',
      subtitleKey: 'emptyStateCategoriesDescription',
      illustration: AppIcons.categoryIcon,
    ),
  },
  EmptyStateCategory.location: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateLocationTitle',
      subtitleKey: 'emptyStateLocationDescription',
      illustration: AppIcons.location,
    ),
  },
  EmptyStateCategory.advertisements: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateAdvertisementsTitle',
      subtitleKey: 'emptyStateAdvertisementsDescription',
      illustration: AppIcons.ads,
    ),
  },
  EmptyStateCategory.reviews: {
    EmptyStateIssue.noData: const _EmptyStateMessage(
      titleKey: 'emptyStateReviewsTitle',
      subtitleKey: 'emptyStateReviewsDescription',
      illustration: AppIcons.myReviewIcon,
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
    final generalMessages = _emptyStateMessages[EmptyStateCategory.general]!;


    return categoryMessages != null && categoryMessages.containsKey(issue)
        ? categoryMessages[issue]!
        : categoryMessages != null &&
        categoryMessages.containsKey(EmptyStateIssue.noData)
        ? categoryMessages[EmptyStateIssue.noData]!
        : generalMessages[issue] ??
        generalMessages[EmptyStateIssue.noData]!;
  }


  @override
  Widget build(BuildContext context) {
    final message = _resolveMessage();
    final color = context.color.territoryColor;
    final resolvedTitle = mainMessage ?? message.titleKey.translate(context);
    final resolvedSubtitle =
        subMessage ?? message.subtitleKey.translate(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withOpacity(0.14), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 28,
              spreadRadius: 0,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
        Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.18),
              color.withOpacity(0.06),
            ],
          ),
        ),
        child: _buildIllustration(message),
            ),
              const SizedBox(height: 24),
              Text(
                resolvedTitle,
                textAlign: TextAlign.center,
              )
                  .size(context.font.extraLarge)
                  .color(color)
                  .bold(weight: FontWeight.w700),
              const SizedBox(height: 12),
              Text(
                resolvedSubtitle,
                textAlign: TextAlign.center,
              )
                  .size(context.font.large)
                  .color(context.color.textLightColor)
                  .centerAlign(),
              if (onTap != null) ...[
                const SizedBox(height: 24),
                _buildActionButton(context, color),
              ],
            ],
        ),
      ),
    );
  }

  Widget _buildIllustration(_EmptyStateMessage message) {
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

    final resolvedHeight = height ?? 120;
    final asset = message.illustration ?? _defaultEmptyStateIllustration;

    if (asset.endsWith('.json')) {
      return SizedBox(
        height: resolvedHeight,
        width: resolvedHeight,
        child: Lottie.asset(
          asset,
          repeat: true,
          fit: BoxFit.contain,
        ),
      );
    }

    return SizedBox(
      height: resolvedHeight,
      width: resolvedHeight,
      child: UiUtils.getSvg(
        asset,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, Color color) {
    final label = (actionLabel ?? 'retry').translate(context);

    return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 160),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: color,
            foregroundColor: context.color.buttonColor,
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
