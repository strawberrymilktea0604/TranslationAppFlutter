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
    String? status,
    String? avatarUrl,
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
      await _secureStorage.write(
        key: SecureStorageKeys.accessToken,
        value: accessToken,
      );
      await _secureStorage.write(
        key: SecureStorageKeys.refreshToken,
        value: refreshToken,
      );
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
    String? status,
    String? avatarUrl,
  }) async {
    try {
      await _secureStorage.write(key: SecureStorageKeys.userId, value: userId);
      await _secureStorage.write(key: SecureStorageKeys.userEmail, value: email);
      if (name != null) {
        await _secureStorage.write(key: SecureStorageKeys.userName, value: name);
      }
      if (role != null) {
        await _secureStorage.write(key: SecureStorageKeys.userRole, value: role);
      }
      if (status != null) {
        await _secureStorage.write(key: 'user_status', value: status);
      }
      if (avatarUrl != null) {
        await _secureStorage.write(key: 'user_avatar', value: avatarUrl);
      }
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
    final status = await _secureStorage.read('user_status');
    final avatarUrl = await _secureStorage.read('user_avatar');

    return {'userId': userId, 'email': email, 'name': name, 'role': role, 'status': status, 'avatarUrl': avatarUrl};
  }

  @override
  Future<void> clearAll() async {
    try {
      // Workaround for flutter_secure_storage Web bug:
      // deleteAll() can corrupt the storage state in the same session,
      // causing subsequent writes to silently fail until a page reload (F5).
      // Workaround for flutter_secure_storage Web concurrency bug:
      // Sequential operations are safe, Future.wait or deleteAll() can fail or corrupt state.
      await _secureStorage.delete(SecureStorageKeys.accessToken);
      await _secureStorage.delete(SecureStorageKeys.refreshToken);
      await _secureStorage.delete(SecureStorageKeys.userId);
      await _secureStorage.delete(SecureStorageKeys.userEmail);
      await _secureStorage.delete(SecureStorageKeys.userName);
      await _secureStorage.delete(SecureStorageKeys.userRole);
      await _secureStorage.delete('user_status');
      await _secureStorage.delete('user_avatar');
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
