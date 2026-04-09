import 'package:frontend/core/utils/constants.dart';

/// Utility class for input validation.
/// All user inputs must be validated client-side before processing.
class InputValidator {
  InputValidator._();

  /// Validates translation text input.
  /// Returns null if valid, or an error message string.
  static String? validateTranslationText(String text) {
    if (text.trim().isEmpty) {
      return 'Translation text cannot be empty';
    }
    if (text.length > AppConstants.maxTranslationChars) {
      return 'Text exceeds maximum ${AppConstants.maxTranslationChars} characters';
    }
    return null;
  }

  /// Validates email format.
  static String? validateEmail(String email) {
    if (email.trim().isEmpty) {
      return 'Email cannot be empty';
    }
    final emailRegex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );
    if (!emailRegex.hasMatch(email)) {
      return 'Invalid email format';
    }
    return null;
  }

  /// Validates password strength.
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validates image file size.
  static String? validateImageSize(int fileSizeBytes) {
    if (fileSizeBytes > AppConstants.maxImageSizeBytes) {
      return 'Image exceeds maximum size of 5MB';
    }
    return null;
  }
}
