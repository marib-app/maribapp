import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

class CurrencyTabBar extends StatelessWidget {
  const CurrencyTabBar({
    super.key,
    required this.tabController,
  });

  final TabController tabController;

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = _isDark(context);
    final border = isDark ? Colors.white12 : Colors.black12;
    final background = isDark ? Colors.black : Colors.white;
    final onBackground = isDark ? Colors.white : Colors.black;
    final Color brand = context.color.territoryColor;

    final base = theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final selected = base.copyWith(fontWeight: FontWeight.w700, height: 1.1);
    final unselected = base.copyWith(fontWeight: FontWeight.w500, height: 1.1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: TabBar(
        controller: tabController,
        tabs: const [
          Tab(text: 'الأسعار'),
          Tab(text: 'التحويل'),
          Tab(text: 'الذهب والفضة'),
        ],
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: brand, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 24),
        ),
        labelStyle: selected,
        unselectedLabelStyle: unselected,
        labelColor: onBackground,
        unselectedLabelColor: onBackground.withOpacity(0.5),
        overlayColor: MaterialStateProperty.all(Colors.transparent),
      ),
    );
  }
}