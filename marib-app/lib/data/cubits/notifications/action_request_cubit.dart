import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/action_request.dart';
import 'package:marib/data/repositories/action_request_repository.dart';

abstract class ActionRequestState {}

class ActionRequestInitial extends ActionRequestState {}

class ActionRequestLoading extends ActionRequestState {}

class ActionRequestSuccess extends ActionRequestState {
  final ActionRequestModel request;
  final bool performing;
  ActionRequestSuccess({required this.request, this.performing = false});

  ActionRequestSuccess copyWith({
    ActionRequestModel? request,
    bool? performing,
  }) {
    return ActionRequestSuccess(
      request: request ?? this.request,
      performing: performing ?? this.performing,
    );
  }
}

class ActionRequestFailure extends ActionRequestState {
  final String message;
  ActionRequestFailure(this.message);
}

class ActionRequestCubit extends Cubit<ActionRequestState> {
  ActionRequestCubit(this._repository) : super(ActionRequestInitial());

  final ActionRequestRepository _repository;

  Future<void> load(String id, String token) async {
    emit(ActionRequestLoading());
    try {
      final ActionRequestModel request =
          await _repository.fetchRequest(requestId: id, token: token);
      emit(ActionRequestSuccess(request: request));
    } catch (error) {
      emit(ActionRequestFailure(error.toString()));
    }
  }

  Future<void> perform(String id, String token) async {
    final current = state;
    if (current is! ActionRequestSuccess) return;

    emit(current.copyWith(performing: true));
    try {
      final ActionRequestModel updated =
          await _repository.perform(requestId: id, token: token);
      emit(ActionRequestSuccess(request: updated));
    } catch (error) {
      emit(ActionRequestFailure(error.toString()));
    }
  }
}
