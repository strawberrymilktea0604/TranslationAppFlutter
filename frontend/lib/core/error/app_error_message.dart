import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'failures.dart';

class AppErrorMessage {
  const AppErrorMessage._();

  static String fromFailure(Failure failure) {
    if (failure is NetworkFailure) {
      return 'Mất kết nối internet. Vui lòng kiểm tra mạng rồi thử lại.';
    }
    if (failure is AuthFailure) {
      return _authMessage(failure.message);
    }
    if (failure is ServerFailure) {
      return _serverMessage(failure.statusCode, failure.message);
    }
    if (failure is CacheFailure) {
      return 'Không thể lưu dữ liệu trên thiết bị. Vui lòng thử lại.';
    }
    if (failure is ValidationFailure) {
      return failure.message;
    }
    return _clean(failure.message);
  }

  static String fromError(Object error) {
    if (error is TimeoutException) {
      return 'Yêu cầu mất quá lâu. Vui lòng thử lại.';
    }
    if (error is SocketException || error is http.ClientException) {
      return 'Mất kết nối internet. Vui lòng kiểm tra mạng rồi thử lại.';
    }
    if (error is NetworkException) {
      return 'Mất kết nối internet. Vui lòng kiểm tra mạng rồi thử lại.';
    }
    if (error is AuthException) {
      return _authMessage(error.message);
    }
    if (error is ServerException) {
      return _serverMessage(error.statusCode, error.message);
    }
    return _clean(error.toString());
  }

  static String _serverMessage(int? statusCode, String rawMessage) {
    switch (statusCode) {
      case 401:
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 404:
        return 'Không tìm thấy dữ liệu cần xử lý.';
      case 408:
        return 'Yêu cầu mất quá lâu. Vui lòng thử lại.';
      case 413:
        return 'Tệp quá lớn. Vui lòng chọn tệp nhỏ hơn.';
      case 422:
        return _clean(rawMessage);
      case 429:
        return 'Bạn thao tác quá nhanh. Vui lòng chờ một lát rồi thử lại.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Dịch vụ AI đang gặp sự cố. Vui lòng thử lại sau ít phút.';
    }

    final lower = rawMessage.toLowerCase();
    if (lower.contains('no internet') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('clientexception')) {
      return 'Mất kết nối internet. Vui lòng kiểm tra mạng rồi thử lại.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Yêu cầu mất quá lâu. Vui lòng thử lại.';
    }
    if (lower.contains('access token') ||
        lower.contains('unauthorized') ||
        lower.contains('jwt') ||
        lower.contains('session expired')) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504')) {
      return 'Dịch vụ AI đang gặp sự cố. Vui lòng thử lại sau ít phút.';
    }

    return _clean(rawMessage);
  }

  static String _authMessage(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('token') ||
        lower.contains('session') ||
        lower.contains('unauthorized') ||
        lower.contains('no access')) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    return _clean(rawMessage);
  }

  static String _clean(String value) {
    var message = value
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^ServerException\(message:\s*'), '')
        .replaceFirst(RegExp(r',\s*statusCode:\s*.*\)$'), '')
        .trim();

    if (message.isEmpty || message == 'null') {
      return 'Đã xảy ra lỗi. Vui lòng thử lại.';
    }
    return message;
  }
}
