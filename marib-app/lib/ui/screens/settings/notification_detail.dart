import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/model/notification_data.dart';
import 'package:marib/ui/screens/notifications/action_request_details_screen.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/helper_utils.dart';

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
        body: const Center(child: Text('notification_not_available')),
      );
    }

    final NotificationData notification = args;
    final String imageUrl = HelperUtils.absoluteImage(
      notification.image ?? notification.data['image'],
    );
    final String title = (notification.title ?? '').trim();
    final String message = (notification.displayMessage ?? '').trim();
    final String timeStr = UiUtils.formatSmartTime(
      notification.createdAt ?? notification.deliveredAt?.toIso8601String(),
    );
    final ActionRequestRouteArgs? actionArgs =
        _parseActionRequest(notification);

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
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: _NetworkImageSafe(imgUrl: imageUrl),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 10),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: Colors.grey.withOpacity(0.25),
            ),
          ),
          const SizedBox(height: 10),
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
          if (actionArgs != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    Routes.actionRequestPage,
                    arguments: actionArgs,
                  ),
                  child: Text("open".translate(context)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ActionRequestRouteArgs? _parseActionRequest(NotificationData notification) {
    final String? deeplink =
        notification.deeplink ?? notification.data['deeplink']?.toString();
    if (deeplink == null || deeplink.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(deeplink);
    if (uri == null || uri.scheme != 'marib' || uri.host != 'action-request') {
      return null;
    }
    if (uri.pathSegments.isEmpty) {
      return null;
    }
    final String id = uri.pathSegments.first;
    final String? token = uri.queryParameters['token'];
    if (id.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return ActionRequestRouteArgs(requestId: id, token: token);
  }
}

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
