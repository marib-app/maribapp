import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/repositories/notifications_repository_repository.dart';
import 'package:marib/utils/hive_utils.dart';

class UnreadNotificationsCubit extends Cubit<int> {
  UnreadNotificationsCubit(this._repository) : super(0);

  final NotificationsRepository _repository;

  Future<void> refresh({bool silent = false}) async {
    if (!HiveUtils.isUserAuthenticated()) {
      emit(0);
      return;
    }
    if (!silent) {
      emit(state);
    }
    try {
      final int count = await _repository.fetchUnreadCount();
      emit(math.max(0, count));
    } catch (_) {}
  }

  void setCount(int value) {
    emit(math.max(0, value));
  }

  void decrement(int amount) {
    emit(math.max(0, state - amount));
  }

  void clear() {
    emit(0);
  }
}
