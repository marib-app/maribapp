import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:marib/data/model/notification_data.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

class NotificationDetail extends StatefulWidget {
  const NotificationDetail({super.key});

  @override
  State<NotificationDetail> createState() => _NotificationDetailState();

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const NotificationDetail(),
      settings: routeSettings,
    );
  }
}

class _NotificationDetailState extends State<NotificationDetail> {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! NotificationData) {
      return Scaffold(
        backgroundColor: context.color.primaryColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: "notifications".translate(context),
          showBackButton: true,
        ),
        body: const Center(child: Text('لا توجد بيانات إشعار')),
      );
    }

    final notif = args;
    final imgUrl = _normalizeImage(notif.image);
    final title = (notif.title ?? '').trim();
    final message = (notif.message ?? '').trim();
    final timeStr = UiUtils.formatSmartTime(notif.createdAt);

    return Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "notifications".translate(context),
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: <Widget>[
          // صورة الإشعار (إن وُجدت)
          if (imgUrl != null && imgUrl.isNotEmpty) const SizedBox(height: 10),
          if (imgUrl != null && imgUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: _NetworkImageSafe(imgUrl: imgUrl),
                ),
              ),
            ),

          const SizedBox(height: 10),

// سطر واحد: العنوان يمين — التاريخ يسار

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Directionality(
              textDirection: TextDirection.ltr, // نجبر الـ Row على LTR
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // التاريخ يسار (يظهر أول عنصر في LTR)
                  Text(
                    timeStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),

                  // العنوان يمين (يظهر آخر عنصر في LTR)
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),

          // فاصل خفيف جدًا (نصف خط تقريبًا) بلون رمادي باهت
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 10),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: Colors.grey.withOpacity(0.25),
            ),
          ),

          const SizedBox(height: 10),

          // نص الإشعار مع دعم الروابط
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Linkify(
                text: message,
                style: Theme.of(context).textTheme.bodyMedium,
                options: const LinkifyOptions(looseUrl: true),
                onOpen: (link) async {
                  final uri = Uri.tryParse(link.url);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  /// تطبيع بسيط للرابط (أضف base لاحقًا إذا احتجت)
  String? _normalizeImage(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;
    if (u.startsWith('http')) return u;
    if (u.startsWith('/')) return u; // أضف base هنا لو يلزم
    return u; // اسم ملف فقط — بدّله إلى '$base/$u' لو احتجت
  }
}

/// صورة شبكة آمنة مع معالجة أخطاء
class _NetworkImageSafe extends StatelessWidget {
  final String imgUrl;
  const _NetworkImageSafe({required this.imgUrl});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imgUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
