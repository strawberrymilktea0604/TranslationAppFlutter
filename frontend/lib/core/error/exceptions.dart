// Custom exceptions for the data layer.
// These are thrown by DataSources and caught by Repositories
// to be converted into Failure objects.

/// Exception thrown when a server request fails.
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({required this.message, this.statusCode});

  @override
  String toString() =>
      'ServerException(message: $message, statusCode: $statusCode)';
}

/// Exception thrown when there is a network connectivity issue.
class NetworkException implements Exception {
  final String message;

  const NetworkException({this.message = 'No internet connection'});

  @override
  String toString() => 'NetworkException(message: $message)';
}

/// Exception thrown when local database operations fail.
class CacheException implements Exception {
  final String message;

  const CacheException({required this.message});

  @override
  String toString() => 'CacheException(message: $message)';
}

/// Exception thrown when authentication fails.
class AuthException implements Exception {
  final String message;

  const AuthException({required this.message});

  @override
  String toString() => 'AuthException(message: $message)';
}

/// Exception thrown when input validation fails.
class ValidationException implements Exception {
  final String message;
  final Map<String, String>? fieldErrors;

  const ValidationException({required this.message, this.fieldErrors});

  @override
  String toString() => 'ValidationException(message: $message)';
}

/// Exception thrown when audio recording operations fail.
class RecordingException implements Exception {
  final String message;

  const RecordingException({required this.message});

  @override
  String toString() => 'RecordingException(message: $message)';
}

/// Exception thrown when microphone permission is denied.
class PermissionDeniedException implements Exception {
  final String message;

  const PermissionDeniedException(
      {this.message = 'Required permission was denied'});

  @override
  String toString() => 'PermissionDeniedException(message: $message)';
}
