sealed class AppException implements Exception {
  const AppException(this.message, [this.stackTrace]);

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

class ValidationException extends AppException {
  const ValidationException(
    this.errors, {
    String message = 'Validation error',
    StackTrace? stackTrace,
  }) : super(message, stackTrace);

  final Map<String, dynamic> errors;
}

class UnknownAppException extends AppException {
  const UnknownAppException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}
