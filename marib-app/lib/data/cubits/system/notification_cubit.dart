import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/notification_data.dart';
import 'package:marib/data/repositories/notifications_repository_repository.dart';

abstract class NotificationState {}

class NotificationInitial extends NotificationState {}

class NotificationSetProgress extends NotificationState {}

class NotificationSetSuccess extends NotificationState {
  List<NotificationData> notificationlist = [];

  NotificationSetSuccess(this.notificationlist);
}

class NotificationSetFailure extends NotificationState {
  final String errmsg;

  NotificationSetFailure(this.errmsg);
}

class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit() : super(NotificationInitial());

  void getNotification(
    BuildContext context,
  ) {
    emit(NotificationSetProgress());
    getNotificationFromDb(
      context,
    )
        .then((value) => emit(NotificationSetSuccess(value)))
        .catchError((e) => emit(NotificationSetFailure(e.toString())));
  }

  Future<List<NotificationData>> getNotificationFromDb(
    BuildContext context,
  ) async {
    final NotificationsRepository repository = NotificationsRepository();
    final NotificationPageResult result =
        await repository.fetchNotifications(perPage: 50);
    return result.items;
  }
}
