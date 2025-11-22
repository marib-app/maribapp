import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/notification_data.dart';
import 'package:marib/data/repositories/notifications_repository_repository.dart';

sealed class NotificationDetailState {}

class NotificationDetailInitial extends NotificationDetailState {}

class NotificationDetailLoading extends NotificationDetailState {}

class NotificationDetailSuccess extends NotificationDetailState {
  NotificationDetailSuccess(this.notification);

  final NotificationData notification;
}

class NotificationDetailFailure extends NotificationDetailState {
  NotificationDetailFailure(this.errorMessage);

  final dynamic errorMessage;
}

class NotificationDetailCubit extends Cubit<NotificationDetailState> {
  NotificationDetailCubit(this._repository)
      : super(NotificationDetailInitial());

  final NotificationsRepository _repository;

  Future<void> load(String id, NotificationData fallback) async {
    emit(NotificationDetailLoading());
    try {
      final NotificationData data =
          await _repository.fetchNotificationDetail(id);
      emit(NotificationDetailSuccess(data));
    } catch (error) {
      emit(NotificationDetailSuccess(fallback));
    }
  }
}
