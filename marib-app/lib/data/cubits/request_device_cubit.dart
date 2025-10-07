import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/repositories/request_device_repository.dart';

abstract class RequestDeviceState {}

class RequestDeviceInitial extends RequestDeviceState {}

class RequestDeviceInProgress extends RequestDeviceState {}

class RequestDeviceSuccess extends RequestDeviceState {
  final String message;

  RequestDeviceSuccess(this.message);
}

class RequestDeviceFailure extends RequestDeviceState {
  final String errorMessage;

  RequestDeviceFailure(this.errorMessage);
}

class RequestDeviceCubit extends Cubit<RequestDeviceState> {
  final RequestDeviceRepository _repository = RequestDeviceRepository();

  RequestDeviceCubit() : super(RequestDeviceInitial());

  Future<void> requestDevice({
    required String phone,
    required String subject,
    required String message,
  }) async {
    try {
      emit(RequestDeviceInProgress());

      final response = await _repository.storeRequestDevice(
        phone: phone,
        subject: subject,
        message: message,
      );

      emit(RequestDeviceSuccess(response['message']));
    } catch (e) {
      emit(RequestDeviceFailure(e.toString()));
    }
  }
}
