import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/core/storage/secure_storage_keys.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';

/// Abstract interface for local auth data operations.
///
/// Uses [flutter_secure_storage] to store JWT tokens in
/// encrypted Keychain (iOS) / EncryptedSharedPreferences (Android).
/// NEVER use SharedPreferences for tokens (copilot-instructions §3.5).
abstract class AuthLocalDataSource {
  /// Persists both JWT tokens to secure storage.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  /// Returns the stored access token, or `null` if absent.
  Future<String?> getAccessToken();

  /// Returns the stored refresh token, or `null` if absent.
  Future<String?> getRefreshToken();

  /// Persists user profile data alongside tokens.
  Future<void> saveUserData({
    required String userId,
    required String email,
    String? name,
    String? role,
  });

  /// Returns cached user data as a map, or `null` if absent.
  Future<Map<String, String?>?> getUserData();

  /// Deletes all tokens and cached user data.
  /// Must be called on logout to prevent token leakage.
  Future<void> clearAll();

  /// Checks whether stored tokens exist (quick auth check).
  Future<bool> hasTokens();
}

/// Implementation of [AuthLocalDataSource] using [SecureStorageService].
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SecureStorageService _secureStorage;

  const AuthLocalDataSourceImpl({required SecureStorageService secureStorage})
    : _secureStorage = secureStorage;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await Future.wait([
        _secureStorage.write(
          key: SecureStorageKeys.accessToken,
          value: accessToken,
        ),
        _secureStorage.write(
          key: SecureStorageKeys.refreshToken,
          value: refreshToken,
        ),
      ]);
    } catch (e) {
      throw CacheException(message: 'Failed to save tokens: ${e.toString()}');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(SecureStorageKeys.accessToken);
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(SecureStorageKeys.refreshToken);
  }

  @override
  Future<void> saveUserData({
    required String userId,
    required String email,
    String? name,
    String? role,
  }) async {
    try {
      await Future.wait([
        _secureStorage.write(key: SecureStorageKeys.userId, value: userId),
        _secureStorage.write(key: SecureStorageKeys.userEmail, value: email),
        if (name != null)
          _secureStorage.write(key: SecureStorageKeys.userName, value: name),
        if (role != null)
          _secureStorage.write(key: SecureStorageKeys.userRole, value: role),
      ]);
    } catch (e) {
      throw CacheException(
        message: 'Failed to save user data: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, String?>?> getUserData() async {
    final userId = await _secureStorage.read(SecureStorageKeys.userId);
    if (userId == null) return null;

    final email = await _secureStorage.read(SecureStorageKeys.userEmail);
    final name = await _secureStorage.read(SecureStorageKeys.userName);
    final role = await _secureStorage.read(SecureStorageKeys.userRole);

    return {'userId': userId, 'email': email, 'name': name, 'role': role};
  }

  @override
  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      throw CacheException(message: 'Failed to clear storage: ${e.toString()}');
    }
  }

  @override
  Future<bool> hasTokens() async {
    final token = await _secureStorage.read(SecureStorageKeys.accessToken);
    return token != null;
  }
}
