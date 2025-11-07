import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';

class SubscriptionTabData {
  const SubscriptionTabData({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
}

class SubscriptionPackagesTabSwitcher extends StatelessWidget {
  const SubscriptionPackagesTabSwitcher({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<SubscriptionTabData> tabs;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final int activeIndex = controller.index;
        return Container(
          decoration: BoxDecoration(
            color: colors.secondaryColor.withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.borderColor.withOpacity(0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (int i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabButton(
                    data: tabs[i],
                    isActive: i == activeIndex,
                    onTap: () {
                      if (controller.index != i) {
                        controller.animateTo(i);
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  final SubscriptionTabData data;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      data.accentColor.withOpacity(0.9),
                      data.accentColor,
                    ],
                  )
                : null,
            color: isActive ? null : Colors.transparent,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: data.accentColor.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                data.icon,
                size: 20,
                color: isActive
                    ? Colors.white
                    : colors.textDefaultColor.withOpacity(0.65),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : colors.textDefaultColor.withOpacity(0.75),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}