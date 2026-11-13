/// Base application exception and specialized exception subtypes.
abstract class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const AppException({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => '$runtimeType: $message (statusCode: $statusCode)';
}

/// Server or API communication exception.
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// Authentication or authorization failure exception.
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.statusCode,
    super.details,
  });
}

typedef AppAuthException = AuthException;

/// Network connectivity exception.
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// Storage upload or retrieval exception.
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.statusCode,
    super.details,
  });
}

/// Client or form validation exception.
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.statusCode,
    super.details,
  });
}
