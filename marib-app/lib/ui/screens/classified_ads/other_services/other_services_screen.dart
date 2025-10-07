import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
        title: Text('otherServices'.translate(context)),
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: const BackButton(), // زر رجوع متوافق مع الثيم
      ),
      body: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: _isLoaded ? _buildGrid(context) : _buildShimmerGrid(context),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
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
  }

  Widget _buildShimmerGrid(BuildContext context) {
    // ألوان شيمر متوافقة مع الثيم
    final base = context.color.secondaryColor.withOpacity(0.35);
    final highlight = context.color.secondaryColor.withOpacity(0.18);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: 8, // عدد عناصر وهمي أثناء التحميل
      itemBuilder: (context, _) {
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: Container(
                  height: 70, // ✅ نفس مقاس الأيقونة في الرئيسية
                  width: double.infinity,
                  color: base,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: Container(
                height: 12,
                width: 64,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        );
      },
    );
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
    // ✅ توحيد المقاسات والشكل مع بطاقات الرئيسية: 70px + نصف قطر 18 + أيقونة 36
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 70,
                width: double.infinity,
                color: context.color.secondaryColor,
                alignment: Alignment.center,
                child: Icon(icon, size: 36, color: context.color.textDefaultColor),
              ),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Text(title)
                  .centerAlign()
                  .setMaxLines(lines: 2)
                  .size(context.font.smaller)
                  .color(context.color.textDefaultColor),
            ),
          ],
        ),
      ),
    );
  }
}
