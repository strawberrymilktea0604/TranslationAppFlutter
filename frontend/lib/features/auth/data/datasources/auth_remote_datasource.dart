import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/auth/data/models/auth_token_model.dart';

/// Abstract interface for remote auth API calls.
///
/// Maps to backend endpoints at `/api/v1/auth/*`.
/// Reference: copilot-instructions.md §4.1, §4.2
abstract class AuthRemoteDataSource {
  /// Calls `POST /api/v1/auth/login`.
  ///
  /// Backend uses OAuth2PasswordRequestForm, so the request
  /// is sent as form-encoded data with `username` (email)
  /// and `password` fields.
  Future<AuthTokenModel> login({
    required String email,
    required String password,
  });

  /// Calls `POST /api/v1/auth/register`.
  ///
  /// Backend expects JSON body with `email` and `password`.
  /// Note: Backend does not support a `name` field in UserCreate.
  Future<AuthTokenModel> register({
    required String email,
    required String password,
  });

  /// Calls `POST /api/v1/auth/refresh`.
  ///
  /// Sends the refresh token to obtain new access + refresh tokens.
  /// Implements single-use refresh token pattern.
  Future<AuthTokenModel> refreshToken({
    required String refreshToken,
  });

  /// Calls `POST /api/v1/auth/logout`.
  ///
  /// Revokes both tokens by sending them to the backend.
  /// Requires valid access token in Authorization header.
  Future<void> logout({
    required String accessToken,
    required String refreshToken,
  });
}

/// Implementation of [AuthRemoteDataSource] using [http.Client].
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  const AuthRemoteDataSourceImpl({
    required this.client,
    required this.baseUrl,
  });

  @override
  Future<AuthTokenModel> login({
    required String email,
    required String password,
  }) async {
    // Backend uses OAuth2PasswordRequestForm (form-encoded).
    // The `username` field maps to the user's email.
    final response = await client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'username': email,
        'password': password,
      },
    );

    return _handleTokenResponse(response, 'Login');
  }

  @override
  Future<AuthTokenModel> register({
    required String email,
    required String password,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    return _handleTokenResponse(response, 'Register');
  }

  @override
  Future<AuthTokenModel> refreshToken({
    required String refreshToken,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'refresh_token': refreshToken,
      }),
    );

    return _handleTokenResponse(response, 'Refresh token');
  }

  @override
  Future<void> logout({
    required String accessToken,
    required String refreshToken,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'access_token': accessToken,
        'refresh_token': refreshToken,
      }),
    );

    if (response.statusCode != 200) {
      // Logout is best-effort: even if BE fails,
      // we still clear local tokens.
      final body = _decodeBody(response);
      throw ServerException(
        message: body['detail'] as String? ?? 'Logout failed',
        statusCode: response.statusCode,
      );
    }
  }

  /// Parses the token response or throws appropriate exceptions.
  ///
  /// Backend response format (success):
  /// ```json
  /// {
  ///   "access_token": "...",
  ///   "refresh_token": "...",
  ///   "token_type": "bearer",
  ///   "expires_in": 900
  /// }
  /// ```
  ///
  /// Backend response format (error):
  /// ```json
  /// {"detail": "Error message"}
  /// ```
  AuthTokenModel _handleTokenResponse(
    http.Response response,
    String operation,
  ) {
    final body = _decodeBody(response);

    switch (response.statusCode) {
      case 200:
        return AuthTokenModel.fromJson(body);
      case 401:
        throw AuthException(
          message: body['detail'] as String? ??
              '$operation failed: Invalid credentials',
        );
      case 400:
        throw AuthException(
          message: body['detail'] as String? ??
              '$operation failed: Bad request',
        );
      case 403:
        throw AuthException(
          message: body['detail'] as String? ??
              '$operation failed: Account locked',
        );
      case 422:
        // Pydantic validation error from backend.
        final detail = body['detail'];
        String message;
        if (detail is List && detail.isNotEmpty) {
          message = (detail[0]['msg'] as String?) ??
              '$operation failed: Validation error';
        } else {
          message = detail?.toString() ??
              '$operation failed: Validation error';
        }
        throw ValidationException(message: message);
      default:
        throw ServerException(
          message: body['detail'] as String? ??
              '$operation failed with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
    }
  }

  /// Safely decodes the response body as JSON.
  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'detail': response.body};
    }
  }
}
