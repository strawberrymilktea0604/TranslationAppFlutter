import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized wrapper around [FlutterSecureStorage].
///
/// All sensitive data (JWT tokens, API keys) MUST be stored
/// through this service — NEVER via SharedPreferences.
/// Reference: copilot-instructions.md §3.5
class SecureStorageService {
  final FlutterSecureStorage _storage;

  /// Android-specific options to avoid issues with
  /// Android Auto Backup corrupting encrypted data.
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  /// iOS-specific options for Keychain accessibility.
  /// `first_unlock` ensures the app can access tokens
  /// after the device is unlocked at least once after restart.
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: _androidOptions,
              iOptions: _iosOptions,
            );

  /// Reads a value for the given [key].
  /// Returns `null` if the key does not exist or on read error.
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // On some devices (e.g., older Samsung), read can fail
      // after an OS update. Return null to trigger re-login.
      return null;
    }
  }

  /// Writes a [value] for the given [key].
  Future<void> write({
    required String key,
    required String value,
  }) async {
    await _storage.write(key: key, value: value);
  }

  /// Deletes the value for the given [key].
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Deletes all stored key-value pairs.
  /// Call this on logout to prevent token leakage.
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Checks whether a value exists for the given [key].
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }
}
