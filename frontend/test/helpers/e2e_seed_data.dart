// E2E Test Seed Data
// Contains predefined test users, content, and expected responses

class E2ETestSeedData {
  // ==================== Users ====================

  static const Map<String, String> seedUsers = {
    'admin@test.com': 'password123',
    'user@test.com': 'password123',
    'invalid@test.com': 'wrongpassword',
  };

  static const Map<String, dynamic> adminUser = {
    'id': 1,
    'email': 'admin@test.com',
    'first_name': 'Admin',
    'last_name': 'User',
    'role': 'admin',
    'is_banned': false,
  };

  static const Map<String, dynamic> regularUser = {
    'id': 2,
    'email': 'user@test.com',
    'first_name': 'Regular',
    'last_name': 'User',
    'role': 'user',
    'is_banned': false,
  };

  // ==================== Admin Users ====================

  static const List<Map<String, dynamic>> seedAdminUsers = [
    {
      'id': 1,
      'email': 'user1@test.com',
      'first_name': 'User',
      'last_name': 'One',
      'role': 'user',
      'is_banned': false,
      'created_at': '2026-05-01T10:00:00Z',
    },
    {
      'id': 2,
      'email': 'user2@test.com',
      'first_name': 'User',
      'last_name': 'Two',
      'role': 'user',
      'is_banned': false,
      'created_at': '2026-05-05T14:30:00Z',
    },
    {
      'id': 3,
      'email': 'user3@test.com',
      'first_name': 'User',
      'last_name': 'Three',
      'role': 'user',
      'is_banned': true,
      'created_at': '2026-05-10T09:15:00Z',
    },
  ];

  // ==================== Question Banks ====================

  static const List<Map<String, dynamic>> seedQuestionBanks = [
    {
      'id': 1,
      'title': 'English Basics',
      'description': 'Basic English vocabulary and phrases',
      'is_active': true,
      'duration_minutes': 30,
      'question_count': 2,
      'created_at': '2026-04-01T10:00:00Z',
    },
    {
      'id': 2,
      'title': 'Business English',
      'description': 'Business terminology and communication',
      'is_active': true,
      'duration_minutes': 45,
      'question_count': 1,
      'created_at': '2026-04-15T14:30:00Z',
    },
    {
      'id': 3,
      'title': 'Travel Phrases',
      'description': 'Useful phrases for travelers',
      'is_active': false,
      'duration_minutes': 20,
      'question_count': 0,
      'created_at': '2026-05-01T09:00:00Z',
    },
  ];

  // ==================== Questions ====================

  static const List<Map<String, dynamic>> seedQuestions = [
    // Bank 1: English Basics
    {
      'id': 1,
      'bank_id': 1,
      'text': 'What is "hello" in Vietnamese?',
      'choices': {
        'A': 'Xin chào',
        'B': 'Tạm biệt',
        'C': 'Cảm ơn',
        'D': 'Vâng',
      },
      'correct_answer': 'A',
      'is_active': true,
      'difficulty': 'easy',
    },
    {
      'id': 2,
      'bank_id': 1,
      'text': 'What is "goodbye" in Vietnamese?',
      'choices': {
        'A': 'Xin chào',
        'B': 'Tạm biệt',
        'C': 'Cảm ơn',
        'D': 'Vâng',
      },
      'correct_answer': 'B',
      'is_active': true,
      'difficulty': 'easy',
    },
    // Bank 2: Business English
    {
      'id': 3,
      'bank_id': 2,
      'text': 'What is the term for a formal business meeting?',
      'choices': {
        'A': 'Appointment',
        'B': 'Conference',
        'C': 'Gathering',
        'D': 'Convention',
      },
      'correct_answer': 'B',
      'is_active': true,
      'difficulty': 'medium',
    },
  ];

  // ==================== Conversations ====================

  static const List<Map<String, dynamic>> seedConversationMessages = [
    {
      'id': 1,
      'user_message': 'Hello, how are you?',
      'translated_response': 'Xin chào, bạn khỏe không?',
      'speaker_url': 'https://example.com/audio/hello_vietnamese.mp3',
    },
    {
      'id': 2,
      'user_message': 'Good morning',
      'translated_response': 'Chào buổi sáng',
      'speaker_url': 'https://example.com/audio/morning_vietnamese.mp3',
    },
    {
      'id': 3,
      'user_message': 'Thank you',
      'translated_response': 'Cảm ơn bạn',
      'speaker_url': 'https://example.com/audio/thank_vietnamese.mp3',
    },
  ];

  // ==================== Translation History ====================

  static const List<Map<String, dynamic>> seedTranslationHistory = [
    {
      'id': 1,
      'original_text': 'Hello, how are you today?',
      'translated_text': 'Xin chào, hôm nay bạn khỏe không?',
      'source_language': 'English',
      'target_language': 'Vietnamese',
      'timestamp': '2026-05-31T10:00:00Z',
    },
    {
      'id': 2,
      'original_text': 'Good morning',
      'translated_text': 'Chào buổi sáng',
      'source_language': 'English',
      'target_language': 'Vietnamese',
      'timestamp': '2026-05-31T09:30:00Z',
    },
    {
      'id': 3,
      'original_text': 'Thank you very much',
      'translated_text': 'Cảm ơn bạn rất nhiều',
      'source_language': 'English',
      'target_language': 'Vietnamese',
      'timestamp': '2026-05-31T08:00:00Z',
    },
  ];

  // ==================== Vocabulary ====================

  static const List<Map<String, dynamic>> seedVocabulary = [
    {
      'id': 1,
      'word': 'Hello',
      'translation': 'Xin chào',
      'pronunciation': 'hə-ˈlō',
      'example': 'Hello, how are you?',
      'added_date': '2026-05-20T10:00:00Z',
    },
    {
      'id': 2,
      'word': 'Good morning',
      'translation': 'Chào buổi sáng',
      'pronunciation': 'ˌɡu̇d ˈmȯr-niŋ',
      'example': 'Good morning, everyone!',
      'added_date': '2026-05-21T09:00:00Z',
    },
    {
      'id': 3,
      'word': 'Thank you',
      'translation': 'Cảm ơn',
      'pronunciation': 'ˈθaŋk ˌyu̇',
      'example': 'Thank you for your help.',
      'added_date': '2026-05-22T14:30:00Z',
    },
    {
      'id': 4,
      'word': 'Goodbye',
      'translation': 'Tạm biệt',
      'pronunciation': 'ˌɡu̇d-ˈbī',
      'example': 'Goodbye, see you tomorrow!',
      'added_date': '2026-05-23T11:00:00Z',
    },
  ];

  // ==================== Expected Responses ====================

  /// Mock API responses for conversation flow
  static Map<String, dynamic> mockConversationResponse(String userMessage) {
    final responses = {
      'hello': {
        'translated': 'Xin chào!',
        'audio_url': 'https://example.com/audio/hello.mp3',
      },
      'good morning': {
        'translated': 'Chào buổi sáng!',
        'audio_url': 'https://example.com/audio/morning.mp3',
      },
      'thank you': {
        'translated': 'Cảm ơn!',
        'audio_url': 'https://example.com/audio/thanks.mp3',
      },
      'goodbye': {
        'translated': 'Tạm biệt!',
        'audio_url': 'https://example.com/audio/goodbye.mp3',
      },
    };

    return responses[userMessage.toLowerCase()] ??
        {
          'translated': 'Hiểu được, $userMessage',
          'audio_url': 'https://example.com/audio/generic.mp3',
        };
  }

  // ==================== Test Tokens ====================

  static const String fakeAdminToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsInJvbGUiOiJhZG1pbiIsImV4cCI6OTk5OTk5OTk5OX0.test_token_admin';

  static const String fakeUserToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyIiwicm9sZSI6InVzZXIiLCJleHAiOjk5OTk5OTk5OTl9.test_token_user';

  static const String expiredToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyIiwicm9sZSI6InVzZXIiLCJleHAiOjEwMDAwMDAwMDB9.expired_token';

  // ==================== Helper Methods ====================

  /// Get admin user token
  static String getAdminToken() => fakeAdminToken;

  /// Get regular user token
  static String getUserToken() => fakeUserToken;

  /// Check if user is valid
  static bool isValidUser(String email, String password) {
    return seedUsers[email] == password;
  }

  /// Get user by email
  static Map<String, dynamic>? getUserByEmail(String email) {
    if (email == 'admin@test.com') return adminUser;
    if (email == 'user@test.com') return regularUser;
    return null;
  }

  /// Get question bank by ID
  static Map<String, dynamic>? getQuestionBankById(int id) {
    try {
      return seedQuestionBanks.firstWhere((b) => b['id'] == id);
    } catch (e) {
      return null;
    }
  }

  /// Get questions by bank ID
  static List<Map<String, dynamic>> getQuestionsByBankId(int bankId) {
    return seedQuestions.where((q) => q['bank_id'] == bankId).toList();
  }

  /// Get question by ID
  static Map<String, dynamic>? getQuestionById(int id) {
    try {
      return seedQuestions.firstWhere((q) => q['id'] == id);
    } catch (e) {
      return null;
    }
  }
}
