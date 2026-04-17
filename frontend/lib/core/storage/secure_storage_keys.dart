/// Centralized constants for all secure storage keys.
///
/// All keys used with [SecureStorageService] are defined here
/// to prevent typos and ensure consistency.
class SecureStorageKeys {
  SecureStorageKeys._();

  /// JWT access token key.
  static const String accessToken = 'access_token';

  /// JWT refresh token key.
  static const String refreshToken = 'refresh_token';

  /// Cached user ID (from JWT `sub` claim).
  static const String userId = 'user_id';

  /// Cached user email.
  static const String userEmail = 'user_email';

  /// Cached user display name (may be null).
  static const String userName = 'user_name';

  /// Cached user role ('user' or 'admin').
  static const String userRole = 'user_role';
}
