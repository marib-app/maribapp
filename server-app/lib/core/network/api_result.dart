import '../exceptions/app_exception.dart';

sealed class ApiResult<T> {
  const ApiResult();

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) {
    final self = this;
    switch (self) {
      case ApiSuccess<T>():
        return success(self.data);
      case ApiFailure<T>():
        return failure(self.error);
    }
  }
}

class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);
  final T data;
}

class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.error);
  final AppException error;
}
