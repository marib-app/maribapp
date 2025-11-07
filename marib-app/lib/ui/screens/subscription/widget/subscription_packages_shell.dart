import 'package:flutter/material.dart';
import 'package:marib/ui/screens/subscription/widget/subscription_packages_tab_switcher.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/theme/theme.dart';

class SubscriptionHighlightItem {
  const SubscriptionHighlightItem({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
}

class SubscriptionPackageShell extends StatelessWidget {
  const SubscriptionPackageShell({
    super.key,
    required this.tabController,
    required this.tabs,
    required this.tabViews,
    required this.bottomBar,
    required this.title,
    required this.subtitle,
    required this.highlights,
  });

  final TabController tabController;
  final List<SubscriptionTabData> tabs;
  final List<Widget> tabViews;
  final Widget bottomBar;
  final String title;
  final String subtitle;
  final List<SubscriptionHighlightItem> highlights;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Scaffold(
      backgroundColor: colors.backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.territoryColor.withOpacity(0.12),
              colors.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: title,
                subtitle: subtitle,
                highlights: highlights,
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SubscriptionPackagesTabSwitcher(
                  controller: tabController,
                  tabs: tabs,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.secondaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: TabBarView(
                      controller: tabController,
                      physics: const BouncingScrollPhysics(),
                      children: tabViews
                          .map(
                            (view) => Padding(
                              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                              child: view,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.highlights,
  });

  final String title;
  final String subtitle;
  final List<SubscriptionHighlightItem> highlights;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackButton(accentColor: colors.territoryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: colors.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.textDefaultColor.withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colors.territoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: colors.territoryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: highlights
                .map((item) => _HighlightChip(item: item))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({
    required this.accentColor,
  });

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: accentColor.withOpacity(0.12),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          color: accentColor,
        ),
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({
    required this.item,
  });

  final SubscriptionHighlightItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            item.accentColor.withOpacity(0.18),
            item.accentColor.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: item.accentColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.icon,
            size: 18,
            color: item.accentColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.label,
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