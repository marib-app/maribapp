import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/repositories/notifications_repository_repository.dart';

abstract class NotificationTopicsState {}

class NotificationTopicsLoading extends NotificationTopicsState {}

class NotificationTopicsLoaded extends NotificationTopicsState {
  final List<String> topics;
  final bool updating;

  NotificationTopicsLoaded({
    required this.topics,
    this.updating = false,
  });

  NotificationTopicsLoaded copyWith({
    List<String>? topics,
    bool? updating,
  }) {
    return NotificationTopicsLoaded(
      topics: topics ?? this.topics,
      updating: updating ?? this.updating,
    );
  }
}

class NotificationTopicsError extends NotificationTopicsState {
  final String message;

  NotificationTopicsError(this.message);
}

class NotificationTopicsCubit extends Cubit<NotificationTopicsState> {
  NotificationTopicsCubit(this._repository)
      : super(NotificationTopicsLoading());

  final NotificationsRepository _repository;

  Future<void> fetchTopics() async {
    emit(NotificationTopicsLoading());
    try {
      final List<String> topics = await _repository.fetchTopics();
      emit(NotificationTopicsLoaded(topics: topics));
    } catch (error) {
      emit(NotificationTopicsError(error.toString()));
    }
  }

  Future<void> subscribe(String topic) async {
    final current = state;
    if (current is! NotificationTopicsLoaded) return;
    emit(current.copyWith(updating: true));
    try {
      final List<String> topics = await _repository.subscribeTopic(topic);
      emit(NotificationTopicsLoaded(topics: topics));
    } catch (error) {
      emit(NotificationTopicsError(error.toString()));
    }
  }

  Future<void> unsubscribe(String topic) async {
    final current = state;
    if (current is! NotificationTopicsLoaded) return;
    emit(current.copyWith(updating: true));
    try {
      final List<String> topics = await _repository.unsubscribeTopic(topic);
      emit(NotificationTopicsLoaded(topics: topics));
    } catch (error) {
      emit(NotificationTopicsError(error.toString()));
    }
  }
}
