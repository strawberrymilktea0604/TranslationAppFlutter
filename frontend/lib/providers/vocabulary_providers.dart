// Vocabulary Service Provider Setup.
// Use this to provide vocabulary services throughout your app.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/vocabulary_service.dart';
import 'package:frontend/services/local_vocabulary_service.dart';

// ==================== HELPER FUNCTION ====================

/// Get auth service instance - implement based on your auth setup
AuthService _getAuthService() {
  // TODO: Replace with your actual auth service
  // If you have auth service in your project:
  // return locator<AuthService>(); // GetIt
  // Or: return ref.watch(authServiceProvider); // Riverpod
  return AuthService();
}

// ==================== PROVIDERS ====================

/// Provider for cloud vocabulary service (authenticated users)
final vocabularyServiceProvider = ChangeNotifierProvider((ref) {
  final authService = _getAuthService();
  return VocabularyService(authService);
});

/// Provider for local vocabulary service (guest users/offline)
final localVocabularyServiceProvider = Provider((ref) {
  return LocalVocabularyService();
});
