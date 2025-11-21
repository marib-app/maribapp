import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/notification_preference.dart';
import 'package:marib/data/repositories/notifications_repository_repository.dart';

abstract class NotificationPreferencesState {}

class NotificationPreferencesLoading extends NotificationPreferencesState {}

class NotificationPreferencesLoaded extends NotificationPreferencesState {
  final List<NotificationPreferenceModel> preferences;
  final bool saving;

  NotificationPreferencesLoaded({
    required this.preferences,
    this.saving = false,
  });

  NotificationPreferencesLoaded copyWith({
    List<NotificationPreferenceModel>? preferences,
    bool? saving,
  }) {
    return NotificationPreferencesLoaded(
      preferences: preferences ?? this.preferences,
      saving: saving ?? this.saving,
    );
  }
}

class NotificationPreferencesError extends NotificationPreferencesState {
  final String message;

  NotificationPreferencesError(this.message);
}

class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState> {
  NotificationPreferencesCubit(this._repository)
      : super(NotificationPreferencesLoading());

  final NotificationsRepository _repository;

  Future<void> load() async {
    emit(NotificationPreferencesLoading());
    try {
      final List<NotificationPreferenceModel> prefs =
          await _repository.fetchPreferences();
      emit(NotificationPreferencesLoaded(preferences: prefs));
    } catch (error) {
      emit(NotificationPreferencesError(error.toString()));
    }
  }

  Future<void> update(List<NotificationPreferenceModel> preferences) async {
    final current = state;
    if (current is! NotificationPreferencesLoaded) return;

    emit(current.copyWith(saving: true));
    try {
      final List<NotificationPreferenceModel> updated =
          await _repository.updatePreferences(preferences);
      emit(NotificationPreferencesLoaded(preferences: updated));
    } catch (error) {
      emit(NotificationPreferencesError(error.toString()));
    }
  }
}
