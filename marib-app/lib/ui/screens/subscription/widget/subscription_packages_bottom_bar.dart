import 'package:flutter/material.dart';
import 'package:marib/data/model/subscription_pacakage_model.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/ui/theme/theme.dart';

enum SubscriptionPackageTab { listing, featured }

class SubscriptionPackageBottomBar extends StatelessWidget {
  const SubscriptionPackageBottomBar({
    super.key,
    required this.tabController,
    required this.selectedListing,
    required this.selectedFeatured,
    required this.listingIndex,
    required this.featuredIndex,
    required this.onPay,
    required this.listingAccentColor,
    required this.featuredAccentColor,
  });

  final TabController tabController;
  final ValueNotifier<SubscriptionPackageModel?> selectedListing;
  final ValueNotifier<SubscriptionPackageModel?> selectedFeatured;
  final int listingIndex;
  final int featuredIndex;
  final void Function(SubscriptionPackageModel?, SubscriptionPackageTab) onPay;
  final Color listingAccentColor;
  final Color featuredAccentColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) {
        final bool isFeatured = tabController.index == 1;
        final notifier = isFeatured ? selectedFeatured : selectedListing;
        final tab =
            isFeatured ? SubscriptionPackageTab.featured : SubscriptionPackageTab.listing;
        final int index = isFeatured ? featuredIndex : listingIndex;
        final Color accent = isFeatured ? featuredAccentColor : listingAccentColor;
        return ValueListenableBuilder<SubscriptionPackageModel?>(
          valueListenable: notifier,
          builder: (context, model, __) {
            return SubscriptionPackageSummaryBar(
              model: model,
              tab: tab,
              index: index,
              accentColor: accent,
              onPay: model == null ? null : () => onPay(model, tab),
            );
          },
        );
      },
    );
  }
}

class SubscriptionPackageSummaryBar extends StatelessWidget {
  const SubscriptionPackageSummaryBar({
    super.key,
    required this.model,
    required this.tab,
    required this.index,
    required this.accentColor,
    required this.onPay,
  });

  final SubscriptionPackageModel? model;
  final SubscriptionPackageTab tab;
  final int index;
  final Color accentColor;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final bool hasModel = model != null;
    final double priceValue =
        (model?.finalPrice ?? model?.price ?? 0).toDouble();
    final bool isFree = priceValue <= 0;
    final bool isActive = model?.isActive ?? false;
    final String title = hasModel
        ? (model!.name?.trim().isNotEmpty == true
            ? model!.name!.trim()
            : '${_tabLabel(context, tab)} #${index + 1}')
        : 'اختر الباقة التي تناسب هدفك';
    final String subtitle = hasModel
        ? '${_tabLabel(context, tab)} #${index + 1}'
        : 'نقرك على أي بطاقة سيعرض تفاصيلها هنا';
    final String priceLabel = hasModel
        ? (isFree
            ? 'free'.translate(context)
            : '${HelperUtils.formatPrice(priceValue)} ${model!.currency ?? ''}'.trim())
        : '';
    final String buttonLabel = !hasModel
        ? 'اختر باقة'
        : isFree
            ? 'تفعيل مجاني'
            : 'متابعة الدفع';

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.secondaryColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryIcon(
                  accentColor: accentColor,
                  tab: tab,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: hasModel
                        ? _SummaryTexts(
                            key: ValueKey(model!.id ?? model.hashCode),
                            title: title,
                            subtitle: subtitle,
                            priceLabel: priceLabel,
                            isActive: isActive,
                            accentColor: accentColor,
                          )
                        : _SummaryTexts(
                            key: const ValueKey('empty-summary'),
                            title: title,
                            subtitle: subtitle,
                            priceLabel: priceLabel,
                            isActive: false,
                            accentColor: accentColor,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  disabledBackgroundColor: colors.borderColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tabLabel(BuildContext context, SubscriptionPackageTab tab) {
    switch (tab) {
      case SubscriptionPackageTab.listing:
        return 'adsListing'.translate(context);
      case SubscriptionPackageTab.featured:
        return 'featuredAdsLbl'.translate(context);
    }
  }
}

class _SummaryIcon extends StatelessWidget {
  const _SummaryIcon({
    required this.accentColor,
    required this.tab,
  });

  final Color accentColor;
  final SubscriptionPackageTab tab;

  @override
  Widget build(BuildContext context) {
    final IconData icon =
        tab == SubscriptionPackageTab.featured
            ? Icons.workspace_premium_rounded
            : Icons.layers_rounded;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        icon,
        color: accentColor,
        size: 26,
      ),
    );
  }
}

class _SummaryTexts extends StatelessWidget {
  const _SummaryTexts({
    super.key,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.isActive,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final String priceLabel;
  final bool isActive;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.textDefaultColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: colors.textDefaultColor.withOpacity(0.65),
            height: 1.4,
          ),
        ),
        if (priceLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accentColor.withOpacity(0.12),
            ),
            child: Text(
              priceLabel,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (isActive) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_rounded,
                color: accentColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'activePlanLbl'.translate(context),
                style: TextStyle(
                  color: colors.textDefaultColor.withOpacity(0.75),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}