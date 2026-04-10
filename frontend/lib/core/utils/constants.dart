// Application-wide constants.

/// Contains application-wide constant values.
class AppConstants {
  AppConstants._();

  /// Maximum characters allowed per translation request.
  static const int maxTranslationChars = 5000;

  /// Maximum image upload size in bytes (5MB).
  static const int maxImageSizeBytes = 5 * 1024 * 1024;

  /// Debounce duration for translation input (ms).
  static const int translationDebounceDurationMs = 500;

  /// JWT Access Token expiry in minutes.
  static const int accessTokenExpiryMinutes = 15;

  /// JWT Refresh Token expiry in days.
  static const int refreshTokenExpiryDays = 7;

  /// Sync retry delays (Exponential Backoff) in seconds.
  static const List<int> syncRetryDelaysSeconds = [5, 10, 30];
}
