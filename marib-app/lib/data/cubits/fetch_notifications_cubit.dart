import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/notification_data.dart';
import 'package:marib/data/repositories/notifications_repository_repository.dart';

abstract class FetchNotificationsState {}

class FetchNotificationsInitial extends FetchNotificationsState {}

class FetchNotificationsInProgress extends FetchNotificationsState {}

class FetchNotificationsSuccess extends FetchNotificationsState {
  final bool isLoadingMore;
  final bool loadingMoreError;
  final List<NotificationData> notificationdata;
  final bool hasMore;
  final String? nextCursor;
  final int unreadCount;

  FetchNotificationsSuccess({
    required this.isLoadingMore,
    required this.loadingMoreError,
    required this.notificationdata,
    required this.hasMore,
    required this.nextCursor,
    required this.unreadCount,
  });

  FetchNotificationsSuccess copyWith({
    bool? isLoadingMore,
    bool? loadingMoreError,
    List<NotificationData>? notificationdata,
    bool? hasMore,
    String? nextCursor,
    int? unreadCount,
  }) {
    return FetchNotificationsSuccess(
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadingMoreError: loadingMoreError ?? this.loadingMoreError,
      notificationdata: notificationdata ?? this.notificationdata,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class FetchNotificationsFailure extends FetchNotificationsState {
  final dynamic errorMessage;

  FetchNotificationsFailure(this.errorMessage);
}

class FetchNotificationsCubit extends Cubit<FetchNotificationsState> {
  FetchNotificationsCubit({int perPage = 20})
      : _perPage = perPage,
        super(FetchNotificationsInitial());

  final NotificationsRepository _notificationsRepository =
      NotificationsRepository();
  final int _perPage;

  Future<void> fetchNotifications() async {
    try {
      emit(FetchNotificationsInProgress());
      final NotificationPageResult result =
          await _notificationsRepository.fetchNotifications(
        perPage: _perPage,
      );
      emit(FetchNotificationsSuccess(
        isLoadingMore: false,
        loadingMoreError: false,
        notificationdata: result.items,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        unreadCount: result.unreadCount,
      ));
    } catch (e) {
      emit(FetchNotificationsFailure(e));
    }
  }

  Future<void> fetchNotificationsMore() async {
    final current = state;
    if (current is! FetchNotificationsSuccess || current.isLoadingMore) {
      return;
    }
    if (!current.hasMore || (current.nextCursor?.isEmpty ?? true)) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true, loadingMoreError: false));
    try {
      final NotificationPageResult result =
          await _notificationsRepository.fetchNotifications(
        cursor: current.nextCursor,
        perPage: _perPage,
      );

      final List<NotificationData> merged = List<NotificationData>.from(
        _mergeNotifications(
          current.notificationdata,
          result.items,
          appendToEnd: true,
        ),
      );

      emit(current.copyWith(
        isLoadingMore: false,
        loadingMoreError: false,
        notificationdata: merged,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor,
        unreadCount: result.unreadCount,
      ));
    } catch (error) {
      emit(
        current.copyWith(
          isLoadingMore: false,
          loadingMoreError: true,
        ),
      );
    }
  }

  Future<void> refreshNotifications() async {
    final current = state;
    if (current is! FetchNotificationsSuccess) {
      await fetchNotifications();
      return;
    }

    try {
      final NotificationPageResult result =
          await _notificationsRepository.fetchNotifications(
        perPage: _perPage,
      );
      final List<NotificationData> merged = _mergeNotifications(
        result.items,
        current.notificationdata,
      );
      emit(
        current.copyWith(
          notificationdata: merged,
          hasMore: result.hasMore,
          nextCursor: result.nextCursor,
          unreadCount: result.unreadCount,
        ),
      );
    } catch (_) {}
  }

  bool hasMoreData() {
    final current = state;
    if (current is! FetchNotificationsSuccess) {
      return false;
    }
    return current.hasMore;
  }

  Future<void> markNotificationAsRead(NotificationData notification) async {
    if (notification.id.isEmpty ||
        (state is! FetchNotificationsSuccess) ||
        notification.isRead) {
      return;
    }
    final current = state as FetchNotificationsSuccess;
    try {
      final int unread = await _notificationsRepository
          .markNotificationsRead(<String>[notification.id]);
      final List<NotificationData> updated = current.notificationdata
          .map((NotificationData n) => n.id == notification.id
              ? n.copyWith(openedAt: DateTime.now().toUtc())
              : n)
          .toList(growable: false);

      emit(current.copyWith(
        notificationdata: updated,
        unreadCount: unread,
      ));
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    if (state is! FetchNotificationsSuccess) {
      return;
    }
    final current = state as FetchNotificationsSuccess;
    try {
      final int unread = await _notificationsRepository.markAllRead();
      final List<NotificationData> updated = current.notificationdata
          .map(
            (NotificationData n) => n.openedAt != null
                ? n
                : n.copyWith(openedAt: DateTime.now().toUtc()),
          )
          .toList(growable: false);
      emit(current.copyWith(
        notificationdata: updated,
        unreadCount: unread,
      ));
    } catch (_) {}
  }

  List<NotificationData> _mergeNotifications(
    List<NotificationData> fresh,
    List<NotificationData> existing, {
    bool appendToEnd = false,
  }) {
    final Map<String, NotificationData> map = <String, NotificationData>{};

    void add(NotificationData notification, {bool toEnd = false}) {
      final String key = notification.id.isNotEmpty
          ? notification.id
          : '${notification.createdAt ?? notification.created}-${notification.title}';
      if (!map.containsKey(key)) {
        map[key] = notification;
      } else if (toEnd) {
        map.remove(key);
        map[key] = notification;
      }
    }

    if (!appendToEnd) {
      for (final NotificationData notification in fresh) {
        add(notification);
      }
      for (final NotificationData notification in existing) {
        add(notification, toEnd: true);
      }
    } else {
      for (final NotificationData notification in existing) {
        add(notification);
      }
      for (final NotificationData notification in fresh) {
        add(notification, toEnd: true);
      }
    }

    return map.values.toList(growable: false);
  }
}
