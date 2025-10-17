import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/fetch_notifications_cubit.dart';
import 'package:marib/data/helper/custom_exception.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/notification_data.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/api.dart'; // إن لم تكن تستعمله يمكنك حذفه
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/helper_utils.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/utils/hive_utils.dart';

/// =========
/// Utils
/// =========

/// طبّع رابط الصورة بدون الاعتماد على Api.baseUrl
/// لو عندك base لاحقاً (مثل Constant.mediaBaseUrl) مرّره عبر البراميتر.
String? normalizeImage(String? url, {String? base}) {
  if (url == null) return null;
  final u = url.trim();
  if (u.isEmpty) return null;
  if (u.startsWith('http')) return u;
  if (u.startsWith('/'))
    return (base != null && base.isNotEmpty) ? '$base$u' : u;
  return (base != null && base.isNotEmpty) ? '$base/$u' : u;
}

/// تخزين حالة المقروء لكل مستخدم
class ReadNotifStore {
  static const _prefix = 'read_notifications';

  static String _keyForUser(String userId) => '$_prefix:$userId';

  static Future<Set<String>> load(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return <String>{};
    }
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyForUser(userId)) ?? const <String>[];
    return list.toSet();
  }

  static Future<void> save(String? userId, Set<String> ids) async {
    if (userId == null || userId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyForUser(userId), ids.toList(growable: false));
  }
}

/// =========
/// Screen
/// =========

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  NotificationsState createState() => NotificationsState();

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(builder: (_) => const Notifications());
  }
}

class NotificationsState extends State<Notifications> {
  late final ScrollController _pageScrollController = ScrollController();

  String? _userId;


  Set<String> _readIds = <String>{};
  bool _isPaging = false;
  bool _adShown = false;

  List<ItemModel> itemData = [];

  @override
  void initState() {
    super.initState();

    AdHelper.loadInterstitialAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_adShown) {
        AdHelper.showInterstitialAd();
        _adShown = true;
      }
    });

    context.read<FetchNotificationsCubit>().fetchNotifications();
    _restoreReadState();

    _pageScrollController.addListener(_pageScroll);
  }

  Future<void> _restoreReadState() async {
    final currentUserId = HiveUtils.getUserId();
    final saved = await ReadNotifStore.load(currentUserId);

    if (!mounted) return;
    setState(() {
      _userId = currentUserId;
      _readIds = saved;
    });
  }

  void _pageScroll() {
    if (_pageScrollController.isEndReached()) {
      final cubit = context.read<FetchNotificationsCubit>();
      if (!_isPaging && cubit.hasMoreData()) {
        _isPaging = true;
        cubit.fetchNotificationsMore().whenComplete(() => _isPaging = false);
      }
    }
  }

  @override
  void dispose() {
    _pageScrollController.removeListener(_pageScroll);
    _pageScrollController.dispose();
    super.dispose();
  }

  String _notifKey(NotificationData n, int index) {
    final hasId = (n.id?.toString().trim().isNotEmpty == true);
    return hasId ? n.id.toString() : '${n.title}-${n.createdAt}-$index';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "notifications".translate(context),
        showBackButton: true,
      ),
      body: BlocBuilder<FetchNotificationsCubit, FetchNotificationsState>(
        builder: (context, state) {
          if (state is FetchNotificationsInProgress) {
            return _buildNotificationShimmer(context);
          }
          if (state is FetchNotificationsFailure) {
            if (state.errorMessage is ApiException &&
                state.errorMessage.error == "no-internet") {
              return NoInternet(
                onRetry: () => context
                    .read<FetchNotificationsCubit>()
                    .fetchNotifications(),
              );
            }
            return const SomethingWentWrong();
          }
          if (state is FetchNotificationsSuccess) {
            if (state.notificationdata.isEmpty) {
              return NoDataFound(
                onTap: () => context
                    .read<FetchNotificationsCubit>()
                    .fetchNotifications(),
              );
            }
            return _buildNotificationList(context, state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// شيمر مطابق 1:1 لمقاس البطاقة
  Widget _buildNotificationShimmer(BuildContext context) {
    const double avatar = 53;
    const double radius = 10;

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Material(
          color: Theme.of(context).colorScheme.secondaryColor,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: context.color.borderColor.darken(50),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  child: const CustomShimmer(width: avatar, height: avatar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomShimmer(height: 16, width: 220),
                      const SizedBox(height: 8),
                      CustomShimmer(height: 12, width: 260),
                      const SizedBox(height: 10),
                      CustomShimmer(height: 10, width: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationList(
      BuildContext context, FetchNotificationsSuccess state) {
    final cubit = context.read<FetchNotificationsCubit>();

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.territoryColor,
            onRefresh: () => cubit.refreshNotifications(),
            child: ListView.separated(
              controller: _pageScrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(10),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: state.notificationdata.length,
              itemBuilder: (context, index) {
                final NotificationData n = state.notificationdata[index];

                final String id = _notifKey(n, index);
                final bool isRead = _readIds.contains(id);

                // صورة مع تطبيع/حماية
                final String img = (normalizeImage(n.image) ?? '').trim();

                return Material(
                  key: ValueKey(id),
                  color: Theme.of(context).colorScheme.secondaryColor,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() => _readIds.add(id));
                      ReadNotifStore.save(_userId, _readIds);

                      Navigator.pushNamed(
                        context,
                        Routes.notificationDetailPage,
                        arguments: n,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.color.borderColor.darken(50),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // صورة الإشعار - باستخدام أسلوبك UiUtils.getImage
                          ClipRRect(
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(15)),
                            child: UiUtils.getImage(
                              img, // قد يكون فارغًا؛ UiUtils عادة يتعامل مع ذلك
                              height: 53.rh(context),
                              width: 53.rw(context),
                              fit: BoxFit.cover, // أفضل من fill لتفادي التشويه
                            ),
                          ),
                          const SizedBox(width: 12),

                          // نصوص
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (n.title ?? '').firstUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium!
                                            .merge(TextStyle(
                                              fontWeight: isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.w700,
                                            )),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin:
                                            const EdgeInsetsDirectional.only(
                                                start: 8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .territoryColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (n.message ?? '').firstUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(height: 1.35),
                                ).color(context.color.textLightColor),
                                const SizedBox(height: 10),
                                Text((n.createdAt?.formatDate().toString() ??
                                        ''))
                                    .size(context.font.smaller)
                                    .color(context.color.textLightColor),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (state.isLoadingMore) UiUtils.progress(),
      ],
    );
  }

  /// (اختياري) غير مستخدمة هنا
  Future<List<ItemModel>> getItemById() async {
    final body = <String, dynamic>{};
    final response = await Api.get(url: Api.getItemApi, queryParameters: body);
    if (!response[Api.error]) {
      List list = response['data'];
      itemData = list.map((model) => ItemModel.fromJson(model)).toList();
    } else {
      throw CustomException(response[Api.message]);
    }
    return itemData;
  }
}
