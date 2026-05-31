import 'dart:convert';
import 'package:http/http.dart' as http;

/// HTTP error response details
class ApiErrorResponse {
  final int statusCode;
  final String message;
  final String? detail;
  final Map<String, dynamic>? errors;

  ApiErrorResponse({
    required this.statusCode,
    required this.message,
    this.detail,
    this.errors,
  });

  @override
  String toString() =>
      'ApiErrorResponse(statusCode: $statusCode, message: $message, detail: $detail)';
}

/// Centralized API error handler utility
class ApiErrorHandler {
  /// Handle HTTP response errors consistently
  /// Throws [ApiErrorResponse] with appropriate message
  static void handleHttpResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return; // Success
    }

    // Parse error response
    final error = _parseErrorResponse(response);
    throw error;
  }

  /// Parse error response body to extract error details
  static ApiErrorResponse _parseErrorResponse(http.Response response) {
    String message = _getHttpErrorMessage(response.statusCode);
    String? detail;
    Map<String, dynamic>? errors;

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      detail = json['detail']?.toString();
      errors = json['errors'] as Map<String, dynamic>?;
    } catch (_) {
      // Body is not JSON or cannot be parsed
    }

    return ApiErrorResponse(
      statusCode: response.statusCode,
      message: message,
      detail: detail,
      errors: errors,
    );
  }

  /// Get human-readable error message for HTTP status code
  static String _getHttpErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad Request — Kiểm tra lại dữ liệu nhập vào';
      case 401:
        return 'Unauthorized — Vui lòng đăng nhập lại';
      case 403:
        return 'Forbidden — Bạn không có quyền truy cập';
      case 404:
        return 'Not Found — Tài nguyên không tìm thấy';
      case 409:
        return 'Conflict — Dữ liệu đã tồn tại hoặc xung đột';
      case 422:
        return 'Validation Error — Vui lòng kiểm tra dữ liệu';
      case 429:
        return 'Too Many Requests — Quá nhiều yêu cầu, vui lòng thử lại sau';
      case 500:
        return 'Server Error — Máy chủ gặp sự cố';
      case 502:
        return 'Bad Gateway — Máy chủ tạm thời không phản hồi';
      case 503:
        return 'Service Unavailable — Dịch vụ tạm thời không khả dụng';
      default:
        return 'Error — Request failed (HTTP $statusCode)';
    }
  }

  /// Format error for user display in SnackBar
  /// Returns a brief, user-friendly message
  static String formatErrorMessage(dynamic error) {
    if (error is ApiErrorResponse) {
      // Prefer detail over generic message
      if (error.detail != null && error.detail!.isNotEmpty) {
        return error.detail!;
      }
      return error.message;
    }

    final errorStr = error.toString();

    // Extract message from common exception patterns
    if (errorStr.contains('Exception:')) {
      return errorStr.replaceAll('Exception:', '').trim();
    }

    return errorStr;
  }

  /// Check if error is authentication-related (401/403)
  static bool isAuthError(dynamic error) {
    if (error is ApiErrorResponse) {
      return error.statusCode == 401 || error.statusCode == 403;
    }
    return false;
  }

  /// Check if error is client error (4xx)
  static bool isClientError(dynamic error) {
    if (error is ApiErrorResponse) {
      return error.statusCode >= 400 && error.statusCode < 500;
    }
    return false;
  }

  /// Check if error is server error (5xx)
  static bool isServerError(dynamic error) {
    if (error is ApiErrorResponse) {
      return error.statusCode >= 500;
    }
    return false;
  }
}
