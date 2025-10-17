import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

class CategoryWidgetOffline extends StatelessWidget {
  const CategoryWidgetOffline({super.key});

  // نفس قائمتك + أيقونة مؤقتة لخدمات أخرى
  final List<Map<String, dynamic>> staticCategories = const [
    {"id": 8,  "name": "requestYourAd",       "url": "assets/category/0.png", 'interfaceType': 'request_ad'},
    {"id": 0,  "name": "exchangeAndTransfer", "url": "assets/category/8.png", 'interfaceType': 'homepage'},
    {"id": 174,"name": "localServices",       "url": "assets/category/1.png", 'interfaceType': 'services_local'},
    {"id": 181,"name": "medicalServices",     "url": "assets/category/7.png", 'interfaceType': 'services_medical'},
    {"id": 180,"name": "studentServices",     "url": "assets/category/6.png", 'interfaceType': 'services_student'},
    {"id": 175,"name": "jobs",                "url": "assets/category/2.png", 'interfaceType': 'jobs'},
    {"id": 175,"name": "eventsOffers",        "url": "assets/category/3.png", 'interfaceType': 'events_offers'},
    {"id": 114,"name": "maribLost",           "url": "assets/category/4.png", 'interfaceType': 'marib_lost'},
    {"id": 177,"name": "maribGuide",          "url": "assets/category/5.png", 'interfaceType': 'marib_guide'},

    // ✅ جديد: خدمات أخرى (أيقونة مؤقتة بدون صورة)
    {"id": 182, "name": "otherServices", "url": null, "icon": Icons.apps, 'interfaceType': 'other_services'},
  ];

  // تحدد اسم الـ route المطلوب لكل مجموعة
  String _resolveRouteByName(String key) {
    switch (key) {
    // المجموعة 1 ➜ ClassifiedScreen
      case 'requestYourAd':
      case 'localServices':
      case 'medicalServices':
      case 'studentServices':
        return Routes.classifiedScreenRoute;

    // المجموعة 2 ➜ ClassifiedScreen3
      case 'jobs':
      case 'eventsOffers':
        return Routes.classifiedScreenRoute3;

    // المجموعة 3 ➜ ClassifiedScreen2
      case 'maribLost':
      case 'maribGuide':
        return Routes.classifiedScreenRoute2;

    // خدمات أخرى ➜ شاشة مستقلة
      case 'otherServices':
        return Routes.otherServices;

    // افتراضيًا
      default:
        return Routes.classifiedScreenRoute;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: context.screenWidth,
        height: 103,
        child: ListView.separated(

          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: staticCategories.length,
          itemBuilder: (context, index) {
            final category = staticCategories[index];
            final String title = category['name'].toString().translate(context);

            // ✅ آمن: نتعامل مع url/icon كاختياريين
            final String? url = category['url'] as String?;
            final IconData? icon = category['icon'] as IconData?;

            return CategoryHomeCard(
              title: title,
              url: url,
              icon: icon,
              onTap: () {
                // استثناء: العملة
                if (category['id'] == 0) {
                  Navigator.pushNamed(context, Routes.currency);
                  return;
                }

                final routeName = _resolveRouteByName(category['name'] as String);

                Navigator.pushNamed(
                  context,
                  routeName,
                  arguments: {
                    'catID': category['id'].toString(),
                    'catName': title,
                    'interfaceType': category['interfaceType'],
                  },
                );
              },
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 12),
        ),
      ),
    );
  }
}

class CategoryHomeCard extends StatelessWidget {
  final String title;
  final String? url;        // اختياري
  final IconData? icon;     // اختياري (لخدمات أخرى)
  final VoidCallback onTap;

  const CategoryHomeCard({
    super.key,
    required this.title,
    this.url,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget thumbChild = icon != null
        ? Icon(icon, size: 36, color: context.color.textDefaultColor) // أيقونة مؤقتة
        : (url != null
        ? Image.asset(url!, fit: BoxFit.cover)
        : Icon(Icons.apps, size: 36, color: context.color.textDefaultColor)); // fallback

    return SizedBox(
      width: 70,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container
                  (
                  height: 70,
                  width: double.infinity,
                  color: context.color.secondaryColor,
                  alignment: Alignment.center,
                  child: thumbChild,
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
      ),
    );
  }
}
