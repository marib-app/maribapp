import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/repositories/request_device_repository.dart';

// States
abstract class RequestDeviceState {}

class RequestDeviceInitial extends RequestDeviceState {}

class RequestDeviceInProgress extends RequestDeviceState {}

class RequestDeviceSuccess extends RequestDeviceState {
  final String message;
  RequestDeviceSuccess(this.message);
}

class RequestDeviceFailure extends RequestDeviceState {
  final String error;
  RequestDeviceFailure(this.error);
}

// Cubit
class RequestDeviceCubit extends Cubit<RequestDeviceState> {
  final RequestDeviceRepository _repository = RequestDeviceRepository();

  RequestDeviceCubit() : super(RequestDeviceInitial());

  Future<void> requestDevice({
    required String phone,
    required String subject,
    required String message,
    required String section,
  }) async {
    try {
      emit(RequestDeviceInProgress());

      await _repository.storeRequestDevice(
        phone: phone,
        subject: subject,
        message: message,
        section: section.trim(),
      );

      emit(RequestDeviceSuccess('تم إرسال الطلب بنجاح'));
    } catch (e) {
      emit(RequestDeviceFailure(e.toString()));
    }
  }
}
