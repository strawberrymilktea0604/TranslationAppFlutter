import 'dart:convert';

/// Utility to decode JWT token payload without signature verification.
///
/// Client-side decoding is used only for extracting claims like
/// `sub` (user ID). The server handles actual token verification.
/// No sensitive logic should depend on client-side JWT decoding.
class JwtDecoder {
  JwtDecoder._();

  /// Decodes a JWT and returns the payload as a [Map].
  ///
  /// Returns `null` if the token format is invalid.
  /// Does NOT verify the token signature — that is the server's
  /// responsibility.
  static Map<String, dynamic>? decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the `sub` (subject / user ID) claim from a JWT.
  static String? getUserId(String token) {
    final payload = decode(token);
    return payload?['sub']?.toString();
  }

  /// Checks whether the token is expired based on the `exp` claim.
  static bool isExpired(String token) {
    final payload = decode(token);
    if (payload == null || payload['exp'] == null) return true;

    final expiry = DateTime.fromMillisecondsSinceEpoch(
      (payload['exp'] as int) * 1000,
    );
    // Add a 30-second buffer to account for clock skew.
    return DateTime.now().isAfter(
      expiry.subtract(const Duration(seconds: 30)),
    );
  }
}
