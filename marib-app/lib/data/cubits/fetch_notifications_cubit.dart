import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/repositories/notifications_repository_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/model/notification_data.dart';
import 'dart:math' as math;







abstract class FetchNotificationsState {}

class FetchNotificationsInitial extends FetchNotificationsState {}

class FetchNotificationsInProgress extends FetchNotificationsState {}

class FetchNotificationsSuccess extends FetchNotificationsState {
  final bool isLoadingMore;
  final bool loadingMoreError;
  final List<NotificationData> notificationdata;
  final int page;
  final int total;
  final DateTime? newestTimestamp;

  FetchNotificationsSuccess({
    required this.isLoadingMore,
    required this.loadingMoreError,
    required this.notificationdata,
    required this.page,
    required this.total,
    this.newestTimestamp,

  });

  FetchNotificationsSuccess copyWith({
    bool? isLoadingMore,
    bool? loadingMoreError,
    List<NotificationData>? notificationdata,
    int? page,
    int? total,
    Object? newestTimestamp = _sentinel,

  }) {
    return FetchNotificationsSuccess(
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadingMoreError: loadingMoreError ?? this.loadingMoreError,
      notificationdata: notificationdata ?? this.notificationdata,
      page: page ?? this.page,
      total: total ?? this.total,
      newestTimestamp: identical(newestTimestamp, _sentinel)
          ? this.newestTimestamp
          : newestTimestamp as DateTime?,
    );
  }
  static const Object _sentinel = Object();
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

  Future fetchNotifications() async {
    try {
      emit(FetchNotificationsInProgress());

      DataOutput<NotificationData> result =
      await _notificationsRepository.fetchNotifications(
        page: 1,
        perPage: _perPage,
      );
      emit(FetchNotificationsSuccess(
          isLoadingMore: false,
          loadingMoreError: false,
          notificationdata: result.modelList,
          page: 1,
          total: result.total,
          newestTimestamp: _latestTimestamp(result.modelList)));
    } catch (e) {
      emit(FetchNotificationsFailure(e));
    }
  }

  Future<void> fetchNotificationsMore() async {
    try {
      if (state is FetchNotificationsSuccess) {
        if ((state as FetchNotificationsSuccess).isLoadingMore) {
          return;
        }
        final FetchNotificationsSuccess currentState =
        state as FetchNotificationsSuccess;
        emit(currentState.copyWith(isLoadingMore: true, loadingMoreError: false));

        final DataOutput<NotificationData> result =
            await _notificationsRepository.fetchNotifications(
              page: currentState.page + 1,
              perPage: _perPage,
        );

        final List<NotificationData> combined =
        List<NotificationData>.of(currentState.notificationdata)
          ..addAll(result.modelList);

        emit(currentState.copyWith(
          isLoadingMore: false,
          loadingMoreError: false,
          notificationdata: combined,
          page: currentState.page + 1,
          total: result.total,
        ));
      }
    } catch (e) {
      if (state is FetchNotificationsSuccess) {
        emit((state as FetchNotificationsSuccess)
            .copyWith(isLoadingMore: false, loadingMoreError: true));
      } else {
        emit(FetchNotificationsFailure(e));
      }
    }
  }

  Future<void> refreshNotifications() async {
    final current = state;
    if (current is! FetchNotificationsSuccess) {
      await fetchNotifications();
      return;
    }

    try {
      final DataOutput<NotificationData> result =
      await _notificationsRepository.fetchNotifications(
        page: 1,
        perPage: _perPage,
        since: current.newestTimestamp,
      );

      if (result.modelList.isEmpty) {
        return;
      }

      final List<NotificationData> merged =
      _mergeNotifications(result.modelList, current.notificationdata);

      emit(current.copyWith(
        notificationdata: merged,
        total: math.max(current.total, merged.length),
        newestTimestamp: _latestTimestamp(merged),
      ));
    } catch (_) {
      // Swallow refresh errors to keep the existing state intact.
    }
  }

  bool hasMoreData() {
    if (state is FetchNotificationsSuccess) {
      return (state as FetchNotificationsSuccess).notificationdata.length <
          (state as FetchNotificationsSuccess).total;
    }
    return false;
  }

  DateTime? _latestTimestamp(List<NotificationData> notifications) {
    DateTime? newest;
    for (final NotificationData notification in notifications) {
      final DateTime? candidate = _parseTimestamp(notification);
      if (candidate == null) {
        continue;
      }
      if (newest == null || candidate.isAfter(newest)) {
        newest = candidate;
      }
    }
    return newest;
  }

  DateTime? _parseTimestamp(NotificationData notification) {
    return _parseTimestampString(notification.createdAt) ??
        _parseTimestampString(notification.created);
  }

  DateTime? _parseTimestampString(String? raw) {
    if (raw == null) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(trimmed).toUtc();
    } catch (_) {
      return null;
    }
  }

  List<NotificationData> _mergeNotifications(
      List<NotificationData> fresh,
      List<NotificationData> existing,
      ) {
    final Set<String> seen = <String>{};
    final List<NotificationData> merged = <NotificationData>[];

    for (final NotificationData notification in fresh) {
      final String key = _notificationKey(notification);
      if (seen.add(key)) {
        merged.add(notification);
      }
    }

    for (final NotificationData notification in existing) {
      final String key = _notificationKey(notification);
      if (seen.add(key)) {
        merged.add(notification);
      }
    }

    return merged;
  }

  String _notificationKey(NotificationData notification) {
    final String? id = notification.id?.trim();
    if (id != null && id.isNotEmpty) {
      return 'id:$id';
    }

    final String createdAt = notification.createdAt?.trim() ?? '';
    final String created = notification.created?.trim() ?? '';
    final String title = notification.title?.trim() ?? '';

    return 'fallback:${createdAt.isNotEmpty ? createdAt : created}::$title';
  }
}
