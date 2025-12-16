import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/fetch_notifications_cubit.dart';
import 'package:marib/data/cubits/notifications/unread_notifications_cubit.dart';
import 'package:marib/data/model/notification_data.dart';
import 'package:marib/ui/screens/notifications/action_request_details_screen.dart';
import 'package:marib/data/helper/custom_exception.dart';

import 'package:marib/utils/extensions/extensions.dart';
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
import 'package:intl/intl.dart' as intl;
import 'package:timeago/timeago.dart' as timeago;
import 'package:marib/app/app_scroll_behavior.dart';

enum NotificationCategory {
  all,
  marketing,
  wallet,
  account,
  updates,
  system,
}


extension NotificationCategoryX on NotificationCategory {
  String label(BuildContext context) {
    switch (this) {
      case NotificationCategory.all:
        return 'الكل';
      case NotificationCategory.account:
        return 'الحساب والإعدادات';
      case NotificationCategory.wallet:
        return 'المحفظة والمدفوعات';
      case NotificationCategory.updates:
        return 'مستجدات التطبيق';
      case NotificationCategory.marketing:
        return 'العروض والإعلانات';
      case NotificationCategory.system:
        return 'تنبيهات النظام';
    }
  }
}


class Notifications extends StatefulWidget {
  const Notifications({super.key, this.highlightNotificationId});

  final String? highlightNotificationId;

  @override
  NotificationsState createState() => NotificationsState();

  static Route route(RouteSettings routeSettings) {
    String? highlightId;
    final Object? args = routeSettings.arguments;
    if (args is Map<String, dynamic>) {
      highlightId = args['highlightId']?.toString();
    } else if (args is String) {
      highlightId = args;
    }
    return BlurredRouter(
      builder: (_) => Notifications(highlightNotificationId: highlightId),
      settings: routeSettings,
    );
  }
}

class NotificationsState extends State<Notifications>
    with SingleTickerProviderStateMixin {
  late final ScrollController _pageScrollController = ScrollController();
  late final TabController _tabController;

  static const Set<String> _marketingTokens = <String>{
    'broadcast',
    'marketing',
    'campaign',
    'ads',
    'promo',
    'promotion',
    'offer',
    'announcement',
    'عرض',
    'عروض',
    'إعلان',
    'إعلانات',
    'ترويج',
    'ترويجي',
    'خصم',
    'كوبون',
    'صفقة',
    'تسويق',
    'دعاية',
    'حملة',
    'حملات',
    'مهرجان',
    'تنزيلات',
    'كشك',
  };
  static const Set<String> _walletTokens = <String>{
    'wallet',
    'wallet.alert',
    'wallet.balance',
    'wallet_balance',
    'wallet_top_up',
    'wallet.transfer',
    'wallet.payment',
    'wallet-payment',
    'wallet_payments',
    'wallet.cashout',
    'wallet.deposit',
    'wallet.withdraw',
    'wallet.withdrawal',
    'wallet.payout',
    'wallet.remittance',
    'wallet.settlement',
    'payment',
    'payment.request',
    'payout',
    'transfer',
    'transfer.request',
    'money_transfer',
    'finance',
    'transaction',
    'invoice',
    'billing',
    'balance',
    'topup',
    'top_up',
    'top-up',
    'recharge',
    'withdraw',
    'withdrawal',
    'withdrawn',
    'deposit',
    'محفظة',
    'المحفظة',
    'مدفوعات',
    'دفعة',
    'دفعات',
    'دفع',
    'سحب',
    'إيداع',
    'ايداع',
    'حوالة',
    'تحويل',
    'تحويل مالي',
    'رصيد',
    'رصيدك',
    'الفاتورة',
    'فاتورة',
    'فاتورتك',
    'الفواتير',
    'سداد',
    'سحب نقدي',
    'إضافة رصيد',
    'إضافة رصيدك',
    'شحن المحفظة',
    'شحن رصيد',
  };
  static const Set<String> _accountTokens = <String>{
    'account',
    'profile',
    'action.request',
    'kyc',
    'kyc.request',
    'security',
    'auth',
    'login',
    'verification',
    'password',
    'حساب',
    'الحساب',
    'إعدادات',
    'اعدادات',
    'ملف',
    'الملف',
    'هوية',
    'توثيق',
    'التحقق',
    'التحقق من الهوية',
    'رمز',
    'otp',
    'تسجيل',
    'الدخول',
    'الخروج',
    'أمان',
    'كلمة المرور',
    'تغيير كلمة المرور',
    'تغيير كلمة السر',
    'البريد',
    'البريد الإلكتروني',
    'البريد الالكتروني',
    'تحديث الحساب',
    'إعداد حسابك',
    'إدارة الحساب',
    'ملفك',
    'حسابك',
    'رقم الجوال',
    'رقم الهاتف',
  };
  static const Set<String> _updateTokens = <String>{
    'update',
    'version',
    'release',
    'changelog',
    'feature',
    'تحسين',
    'تحسينات',
    'تحديث',
    'تحديثات',
    'مستجدات',
    'خبر',
    'أخبار التطبيق',
    'ميزة جديدة',
    'اصدار',
    'الإصدار',
    'إطلاق',
    'تجربة جديدة',
    'خدمة جديدة',
    'تحسين جديد',
  };
  bool _isPaging = false;
  bool _adShown = false;
  NotificationCategory _selectedCategory = NotificationCategory.all;
  String? _highlightNotificationId;

  @override
  void initState() {
    super.initState();
    _highlightNotificationId = widget.highlightNotificationId;
    _tabController = TabController(
      length: NotificationCategory.values.length,
      vsync: this,
    )..addListener(_handleTabChange);

    AdHelper.loadInterstitialAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_adShown) {
        AdHelper.showInterstitialAd();
        _adShown = true;
      }
    });

    context.read<FetchNotificationsCubit>().fetchNotifications();
    context.read<UnreadNotificationsCubit>().refresh(silent: true);

    _pageScrollController.addListener(_pageScroll);
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
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Notifications oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightNotificationId != widget.highlightNotificationId) {
      _highlightNotificationId = widget.highlightNotificationId;
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    setState(() {
      _selectedCategory = NotificationCategory.values[_tabController.index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FetchNotificationsCubit, FetchNotificationsState>(
      listenWhen: (_, current) => current is FetchNotificationsSuccess,
      listener: (context, state) {
        if (state is FetchNotificationsSuccess) {
          context.read<UnreadNotificationsCubit>().setCount(state.unreadCount);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primaryColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: "notifications".translate(context),
          showBackButton: true,
          actions: [
            BlocBuilder<FetchNotificationsCubit, FetchNotificationsState>(
              builder: (context, state) {
                final bool canMarkAll = state is FetchNotificationsSuccess &&
                    state.unreadCount > 0 &&
                    state.notificationdata.isNotEmpty;
                return IconButton(
                  icon: const Icon(Icons.done_all_outlined),
                  tooltip: "mark_all_read".translate(context),
                  onPressed: canMarkAll
                      ? () => context
                          .read<FetchNotificationsCubit>()
                          .markAllAsRead()
                      : null,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: "notification_settings".translate(context),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  Routes.notificationSettingsPage,
                );
              },
            ),
          ],
          bottom: [_buildCategoryTabs(context)],
          bottomHeight: 48,
        ),
        body: BlocBuilder<FetchNotificationsCubit, FetchNotificationsState>(
          builder: (context, state) {
            if (state is FetchNotificationsInProgress) {
              return _buildNotificationShimmer(context);
            }

            if (state is FetchNotificationsFailure) {
              final dynamic error = state.errorMessage;
              final String normalizedError =
                  error is CustomException ? error.toString() : '$error';
              if (normalizedError.contains('no-internet')) {
                return const NoInternet();
              }
              return const SomethingWentWrong();
            }

            if (state is FetchNotificationsSuccess) {
              if (state.notificationdata.isEmpty) {
                return const NoDataFound(
                  category: EmptyStateCategory.notifications,
                );
              }
              return _buildNotificationList(context, state);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildNotificationShimmer(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => const NotificationShimmerLoadingContainer(),
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    FetchNotificationsSuccess state,
  ) {
    final cubit = context.read<FetchNotificationsCubit>();
    final List<NotificationData> filteredNotifications = state
        .notificationdata
        .where(_matchesSelectedCategory)
        .toList(growable: false);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.territoryColor,
            onRefresh: () => cubit.refreshNotifications(),
            child: filteredNotifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: AppScrollBehavior.defaultPhysics,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    children: [
                      const SizedBox(height: 32),
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .textLightColor
                            .withOpacity(0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد إشعارات ضمن هذا التصنيف حالياً',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _pageScrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: AppScrollBehavior.defaultPhysics,
                    ),
                    padding: const EdgeInsets.all(10),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final NotificationData notification =
                          filteredNotifications[index];
                      final String id = notification.id;
                      final bool isRead = notification.isRead;
                      final bool isHighlighted =
                          _highlightNotificationId != null &&
                              _highlightNotificationId == id;
                      final String? message =
                          notification.displayMessage ?? '';
                      final String image = HelperUtils.absoluteImage(
                        notification.image ??
                            notification.data['image']?.toString(),
                      );
                      final bool hasImage = image.trim().isNotEmpty;
                      final String timeLabel =
                        _formatArabicTime(context, notification);

                      final Color baseColor =
                          Theme.of(context).colorScheme.secondaryColor;
                      final Color highlightBorder =
                          Theme.of(context).colorScheme.territoryColor;

                      return Material(
                        key: ValueKey(id),
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handleNotificationTap(notification),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: isHighlighted
                                  ? baseColor.withOpacity(0.8)
                                  : baseColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isHighlighted
                                    ? highlightBorder
                                    : context.color.borderColor.darken(50),
                                width: isHighlighted ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                hasImage
                                    ? ClipRRect(
                                        clipBehavior:
                                            Clip.antiAliasWithSaveLayer,
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(15),
                                        ),
                                        child: UiUtils.getImage(
                                          image,
                                          height: 53.rh(context),
                                          width: 53.rw(context),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Container(
                                        height: 53.rh(context),
                                        width: 53.rw(context),
                                        decoration: BoxDecoration(
                                          color: context
                                              .color.territoryColor
                                              .withOpacity(0.12),
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(15),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.notifications_rounded,
                                          color:
                                              context.color.territoryColor,
                                        ),
                                      ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (notification.title ?? '')
                                                  .firstUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium!
                                                  .merge(
                                                    TextStyle(
                                                      fontWeight: isRead
                                                          ? FontWeight.w500
                                                          : FontWeight.w700,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          if (!isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin:
                                                  const EdgeInsetsDirectional
                                                      .only(
                                                start: 8,
                                              ),
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
                                        (message ?? '').firstUpperCase(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(height: 1.35),
                                      ).color(context.color.textLightColor),
                                      const SizedBox(height: 10),
                                      Text(timeLabel)
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

  bool _matchesSelectedCategory(NotificationData notification) {
    if (_selectedCategory == NotificationCategory.all) {
      return true;
    }
    return _categoryForNotification(notification) == _selectedCategory;
  }

  NotificationCategory _categoryForNotification(NotificationData notification) {
    final String normalizedCategory =
        (notification.category ?? notification.data['category']?.toString() ?? '')
            .trim()
            .toLowerCase();

    final NotificationCategory? explicitCategory =
        _categoryFromLabel(normalizedCategory);

    final Set<String> tokens = _extractTokens(notification);
    final bool walletHit = _matchesTokens(tokens, _walletTokens);
    final bool accountHit = _matchesTokens(tokens, _accountTokens);
    final bool marketingHit = _matchesTokens(tokens, _marketingTokens);
    final bool updateHit = _matchesTokens(tokens, _updateTokens);
    final bool manualBroadcast = _isManualBroadcast(notification);

    if (!manualBroadcast && walletHit) {
      return NotificationCategory.wallet;
    }

    if (explicitCategory != null) {
      return explicitCategory;
    }

    if (walletHit) {
      return NotificationCategory.wallet;
    }

    if (accountHit) {
      return NotificationCategory.account;
    }

    if (marketingHit) {
      return NotificationCategory.marketing;
    }

    if (updateHit) {
      return NotificationCategory.updates;
    }

    return NotificationCategory.system;
  }

  Set<String> _extractTokens(NotificationData notification) {
    final Set<String> tokens = <String>{};

    void addValue(dynamic value) {
      if (value == null) return;

      if (value is Map) {
        for (final MapEntry<dynamic, dynamic> entry in value.entries) {
          addValue(entry.key);
          addValue(entry.value);
        }
        return;
      }

      if (value is Iterable) {
        for (final dynamic element in value) {
          addValue(element);
        }
        return;
      }

      final String normalized = value.toString().trim().toLowerCase();
      if (normalized.isEmpty) {
        return;
      }
      tokens.add(normalized);
      tokens.addAll(
        normalized
            .split(RegExp(r'[^a-z0-9\u0600-\u06FF]+'))
            .where((segment) => segment.trim().isNotEmpty),
      );
    }

    addValue(notification.type);
    addValue(notification.category);
    addValue(notification.deeplink);
    addValue(notification.title);
    addValue(notification.message);
    addValue(notification.body);
    addValue(notification.displayMessage);
    addValue(notification.data['category']);
    addValue(notification.data['entity']);
    addValue(notification.data['context']);
    addValue(notification.data['topic']);
    addValue(notification.data['type']);
    addValue(notification.data['title']);
    addValue(notification.data['subtitle']);
    addValue(notification.data['body']);
    addValue(notification.data['message']);
    addValue(notification.data['tags']);
    addValue(notification.data);
    addValue(notification.meta);

    return tokens;
  }

  NotificationCategory? _categoryFromLabel(String normalized) {
    switch (normalized) {
      case 'marketing':
      case 'العروض والإعلانات':
      case 'العروض والاعلانات':
        return NotificationCategory.marketing;
      case 'account':
      case 'account_settings':
      case 'الحساب والإعدادات':
      case 'الحساب والاعدادات':
        return NotificationCategory.account;
      case 'wallet':
      case 'wallet_payments':
      case 'wallet-payments':
      case 'المحفظة والمدفوعات':
      case 'المحفظة والمدفوعات ':
        return NotificationCategory.wallet;
      case 'updates':
      case 'app_updates':
      case 'app-updates':
      case 'مستجدات التطبيق':
      case 'اخر مستجدات التطبيق':
        return NotificationCategory.updates;
      case 'system':
      case 'system_alerts':
      case 'system-alerts':
      case 'تنبيهات النظام':
        return NotificationCategory.system;
      case 'all':
        return NotificationCategory.all;
      default:
        return null;
    }
  }

  bool _isManualBroadcast(NotificationData notification) {
    final dynamic source =
        notification.data['source'] ?? notification.meta?['source'];
    if (source == null) {
      return false;
    }
    final String normalized = source.toString().trim().toLowerCase();
    return normalized == 'manual-broadcast' || normalized == 'manual_broadcast';
  }

  bool _matchesTokens(Set<String> haystack, Set<String> needles) {
    for (final String token in haystack) {
      for (final String needle in needles) {
        if (token.contains(needle)) {
          return true;
        }
      }
    }
    return false;
  }

  Widget _buildCategoryTabs(BuildContext context) {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      indicatorColor: Theme.of(context).colorScheme.territoryColor,
      labelColor: Theme.of(context).colorScheme.territoryColor,
      unselectedLabelColor: Theme.of(context).colorScheme.textLightColor,
      tabs: NotificationCategory.values
          .map((category) => Tab(text: category.label(context)))
          .toList(growable: false),
    );
  }

  void _handleNotificationTap(NotificationData notification) {
    context
        .read<FetchNotificationsCubit>()
        .markNotificationAsRead(notification);
    if (_highlightNotificationId == notification.id) {
      setState(() => _highlightNotificationId = null);
    }

    final ActionRequestRouteArgs? actionArgs =
        _parseActionRequest(notification);
    if (actionArgs != null) {
      Navigator.pushNamed(
        context,
        Routes.actionRequestPage,
        arguments: actionArgs,
      );
      return;
    }

    Navigator.pushNamed(
      context,
      Routes.notificationDetailPage,
      arguments: notification,
    );
  }

  ActionRequestRouteArgs? _parseActionRequest(NotificationData notification) {
    final String? deeplink = notification.deeplink ??
        notification.data['deeplink']?.toString() ??
        notification.data['request_deeplink']?.toString();
    if (deeplink == null || deeplink.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(deeplink);
    if (uri == null) return null;

    if (uri.scheme != 'marib') return null;
    if (uri.host != 'action-request') return null;

    if (uri.pathSegments.isEmpty) return null;
    final String id = uri.pathSegments.first;
    final String? token =
        uri.queryParameters['token'] ?? notification.data['token']?.toString();

    if (id.isEmpty || token == null || token.isEmpty) {
      return null;
    }

    return ActionRequestRouteArgs(
      requestId: id,
      token: token,
    );
  }
}

class NotificationShimmerLoadingContainer extends StatelessWidget {
  const NotificationShimmerLoadingContainer({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme palette = Theme.of(context).colorScheme;
    return Card(
      color: palette.secondaryColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            CustomShimmer(width: double.infinity, height: 16),
            SizedBox(height: 12),
            CustomShimmer(width: double.infinity, height: 12),
            SizedBox(height: 12),
            CustomShimmer(width: 120, height: 10),
          ],
        ),
      ),
    );
  }
}

String _formatArabicTime(
    BuildContext context, NotificationData notification) {
  final String? raw = notification.createdAt ??
      notification.deliveredAt?.toIso8601String() ??
      notification.openedAt?.toIso8601String();
  if (raw == null || raw.isEmpty) {
    return '';
  }
  try {
    _ensureArabicTimeago();
    final String locale = UiUtils.resolveLanguageCode(context);
    return timeago.format(DateTime.parse(raw).toLocal(), locale: locale);
  } catch (_) {
    return '';
  }
}

bool _timeagoArabicConfigured = false;

void _ensureArabicTimeago() {
  if (_timeagoArabicConfigured) {
    return;
  }
  try {
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _timeagoArabicConfigured = true;
  } catch (_) {}
}
