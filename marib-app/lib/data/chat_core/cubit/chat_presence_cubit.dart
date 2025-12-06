import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/chat_core/chat_repository_v2.dart';
import 'package:marib/data/chat_core/paging_models.dart';

class ChatPresenceState extends Equatable {
  const ChatPresenceState({
    this.byUserId = const <int, PresenceEvent>{},
  });

  final Map<int, PresenceEvent> byUserId;

  ChatPresenceState copyWith({
    Map<int, PresenceEvent>? byUserId,
  }) {
    return ChatPresenceState(
      byUserId: byUserId ?? this.byUserId,
    );
  }

  @override
  List<Object?> get props => <Object?>[byUserId];
}

/// Minimal presence cubit: merges events into a map keyed by userId.
class ChatPresenceCubit extends Cubit<ChatPresenceState> {
  ChatPresenceCubit(this._repository) : super(const ChatPresenceState()) {
    _subscription = _repository.presenceStream().listen(_onPresence);
  }

  final ChatRepositoryV2 _repository;
  StreamSubscription<PresenceEvent>? _subscription;

  void _onPresence(PresenceEvent event) {
    final Map<int, PresenceEvent> updated = Map<int, PresenceEvent>.from(
      state.byUserId,
    )..[event.userId] = event;
    emit(state.copyWith(byUserId: updated));
  }

  PresenceEvent? presenceFor(int userId) => state.byUserId[userId];

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
