import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/repositories/request_support_repository.dart';

// States
abstract class RequestSupportState {}

class RequestSupportInitial extends RequestSupportState {}

class RequestSupportInProgress extends RequestSupportState {}

class RequestSupportSuccess extends RequestSupportState {
  final String message;
  RequestSupportSuccess(this.message);
}

class RequestSupportFailure extends RequestSupportState {
  final String error;
  RequestSupportFailure(this.error);
}

// Cubit
class RequestSupportCubit extends Cubit<RequestSupportState> {
  final RequestSupportRepository _repository = RequestSupportRepository();

  RequestSupportCubit() : super(RequestSupportInitial());

  Future<void> requestSupport({
    required String name,
    required String phone,
    required String subject,
    required String message,
  }) async {
    try {
      emit(RequestSupportInProgress());

      await _repository.storeRequestSupport(
        name: name,
        phone: phone,
        subject: subject,
        message: message,
      );

      emit(RequestSupportSuccess('تم إرسال الطلب بنجاح'));
    } catch (e) {
      emit(RequestSupportFailure(e.toString()));
    }
  }
}
