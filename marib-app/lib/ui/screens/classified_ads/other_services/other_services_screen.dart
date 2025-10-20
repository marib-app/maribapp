import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'dart:math' as math;
import 'package:marib/utils/ui_utils.dart';

class OtherServicesScreen extends StatefulWidget {
  const OtherServicesScreen({super.key});

  /// استخدمها في onGenerateRoute
  static Route route(RouteSettings s) => MaterialPageRoute(
        builder: (_) => const OtherServicesScreen(),
        settings: s,
        maintainState: true,
      );

  @override
  State<OtherServicesScreen> createState() => _OtherServicesScreenState();
}

class _OtherServicesScreenState extends State<OtherServicesScreen> {
  bool _isLoaded = false;

  // عناصر الشبكة (يمكن توسيعها لاحقاً)
  List<Map<String, dynamic>> get _items => [
        {
          'key': 'wifiCabin',
          'titleKey': 'wifiCabin',
          'icon': Icons.wifi,
          'route': Routes.otherServicesWifiCabin,
        },
      ];

  @override
  void initState() {
    super.initState();
    // ✅ جلب/تهيئة البيانات بعد أول فريم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isLoaded = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: 'otherServices'.translate(context),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(color: context.color.backgroundColor),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child:
                  _isLoaded ? _buildGrid(context) : _buildShimmerGrid(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = _resolveCrossAxisCount(constraints.maxWidth);
        final double childAspectRatio =
            _resolveChildAspectRatio(constraints.maxWidth);

        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final m = _items[i];
            final title = (m['titleKey'] as String).translate(context);
            return _OtherServiceCard(
              title: title,
              icon: m['icon'] as IconData,
              onTap: () => Navigator.pushNamed(context, m['route'] as String),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerGrid(BuildContext context) {
    final colorScheme = context.color;
    final base = colorScheme.shimmerBaseColor;
    final highlight = colorScheme.shimmerHighlightColor;
    final content = colorScheme.shimmerContentColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = _resolveCrossAxisCount(constraints.maxWidth);
        final double childAspectRatio =
            _resolveChildAspectRatio(constraints.maxWidth);
        final int itemCount = math.max(crossAxisCount * 2, 6);

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: (context, _) {
            return Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: Container(
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: content,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 14,
                      width: 96,
                      decoration: BoxDecoration(
                        color: content,
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  int _resolveCrossAxisCount(double width) {
    if (width >= 1200) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    if (width >= 360) return 3;
    return 1;
  }

  double _resolveChildAspectRatio(double width) {
    if (width >= 900) return 1.1;
    if (width >= 600) return 1.0;
    if (width >= 420) return 0.95;
    if (width >= 360) return 0.82;
    return 0.78;
  }
}

class _OtherServiceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _OtherServiceCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.color;
    final Color accent = colorScheme.territoryColor;
    final Color secondaryAccent = colorScheme.forthColor;
    final BorderRadius radius = BorderRadius.circular(20);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        overlayColor: MaterialStateProperty.resolveWith(
          (states) {
            if (states.contains(MaterialState.pressed) ||
                states.contains(MaterialState.hovered)) {
              return Colors.white.withOpacity(0.10);
            }
            return null;
          },
        ),
        splashColor: Colors.white.withOpacity(0.12),
        highlightColor: Colors.white.withOpacity(0.08),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                accent.withOpacity(0.96),
                Color.lerp(accent, secondaryAccent, 0.45)!.withOpacity(0.98),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.22),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 26, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.font.normal,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
