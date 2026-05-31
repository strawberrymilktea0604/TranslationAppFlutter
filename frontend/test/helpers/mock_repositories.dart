import 'package:mockito/mockito.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository.dart';
import 'package:frontend/features/translation/data/repositories/translation_repository.dart';
import 'package:frontend/features/vocabulary/data/repositories/vocabulary_repository.dart';
import 'package:frontend/features/admin/data/repositories/admin_users_repository.dart';
import 'package:frontend/features/admin/data/repositories/admin_question_bank_repository.dart';
import 'package:frontend/features/admin/data/repositories/admin_question_repository.dart';
import 'package:frontend/features/conversation/data/repositories/conversation_repository.dart';
import 'package:frontend/features/sync/data/repositories/sync_repository.dart';

// ==================== Mock Classes ====================

class MockAuthRepository extends Mock implements AuthRepository {}

class MockTranslationRepository extends Mock implements TranslationRepository {}

class MockVocabularyRepository extends Mock implements VocabularyRepository {}

class MockAdminUsersRepository extends Mock implements AdminUsersRepository {}

class MockAdminQuestionBankRepository extends Mock
    implements AdminQuestionBankRepository {}

class MockAdminQuestionRepository extends Mock
    implements AdminQuestionRepository {}

class MockConversationRepository extends Mock
    implements ConversationRepository {}

class MockSyncRepository extends Mock implements SyncRepository {}

// ==================== Mock Implementations ====================

class FakeAuthRepository implements AuthRepository {
  final _registeredUsers = <String, String>{};
  String? _currentToken;

  @override
  Future<String> login(String email, String password) async {
    // Seed users: admin@test.com, user@test.com
    if ((email == 'admin@test.com' || email == 'user@test.com') &&
        password == 'password123') {
      _currentToken = 'fake_jwt_token_${email.hashCode}';
      return _currentToken!;
    }
    throw Exception('Invalid credentials');
  }

  @override
  Future<void> logout() async {
    _currentToken = null;
  }

  @override
  Future<String?> getAccessToken() async => _currentToken;

  @override
  Future<void> refreshToken() async {
    if (_currentToken != null) {
      _currentToken = 'fake_jwt_token_refreshed_${DateTime.now().millisecond}';
    }
  }

  @override
  Future<void> register(String email, String password, String name) async {
    _registeredUsers[email] = password;
  }

  @override
  Future<Map<String, dynamic>> getCurrentUser() async {
    if (_currentToken == null) throw Exception('Not authenticated');
    return {
      'id': 1,
      'email': 'user@test.com',
      'first_name': 'Test',
      'last_name': 'User',
      'role': 'user',
    };
  }
}

class FakeTranslationRepository implements TranslationRepository {
  @override
  Future<Map<String, dynamic>> translateText(
    String text,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    // Mock translation response
    return {
      'original_text': text,
      'translated_text': _mockTranslate(text, targetLanguage),
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> saveToHistory(Map<String, dynamic> translation) async {
    // Mock save
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory() async {
    return [
      {
        'id': 1,
        'original_text': 'Hello',
        'translated_text': 'Xin chào',
        'timestamp': DateTime.now().toIso8601String(),
      },
      {
        'id': 2,
        'original_text': 'Good morning',
        'translated_text': 'Chào buổi sáng',
        'timestamp': DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
      },
    ];
  }

  String _mockTranslate(String text, String targetLang) {
    const translations = {
      'hello': 'xin chào',
      'good morning': 'chào buổi sáng',
      'how are you': 'bạn khỏe không',
      'thank you': 'cảm ơn',
      'goodbye': 'tạm biệt',
    };
    return translations[text.toLowerCase()] ?? 'Dịch: $text';
  }
}

class FakeVocabularyRepository implements VocabularyRepository {
  @override
  Future<List<Map<String, dynamic>>> getSavedVocabulary() async {
    return [
      {
        'id': 1,
        'word': 'hello',
        'translation': 'xin chào',
        'pronunciation': 'hə-ˈlō',
      },
      {
        'id': 2,
        'word': 'goodbye',
        'translation': 'tạm biệt',
        'pronunciation': 'ˌɡu̇d-ˈbī',
      },
    ];
  }

  @override
  Future<void> saveWord(String word, String translation) async {
    // Mock save
  }

  @override
  Future<void> deleteWord(int id) async {
    // Mock delete
  }
}

class FakeAdminUsersRepository implements AdminUsersRepository {
  final _users = [
    {
      'id': 1,
      'email': 'user1@test.com',
      'first_name': 'User',
      'last_name': 'One',
      'is_banned': false,
    },
    {
      'id': 2,
      'email': 'user2@test.com',
      'first_name': 'User',
      'last_name': 'Two',
      'is_banned': false,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getUsers(int page, int pageSize) async {
    return _users;
  }

  @override
  Future<Map<String, dynamic>> banUser(int userId) async {
    final user = _users.firstWhere((u) => u['id'] == userId);
    user['is_banned'] = true;
    return user;
  }

  @override
  Future<Map<String, dynamic>> unbanUser(int userId) async {
    final user = _users.firstWhere((u) => u['id'] == userId);
    user['is_banned'] = false;
    return user;
  }
}

class FakeAdminQuestionBankRepository
    implements AdminQuestionBankRepository {
  final _banks = [
    {
      'id': 1,
      'title': 'English Basics',
      'description': 'Basic English vocabulary',
      'is_active': true,
      'question_count': 10,
    },
    {
      'id': 2,
      'title': 'Business English',
      'description': 'Business terminology',
      'is_active': true,
      'question_count': 15,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getBanks(int page, int pageSize) async {
    return _banks;
  }

  @override
  Future<Map<String, dynamic>> createBank(
    String title,
    String description,
    int? duration,
  ) async {
    final newBank = {
      'id': _banks.length + 1,
      'title': title,
      'description': description,
      'is_active': true,
      'duration_minutes': duration,
      'question_count': 0,
    };
    _banks.add(newBank);
    return newBank;
  }

  @override
  Future<Map<String, dynamic>> updateBank(
    int bankId,
    String title,
    String description,
    int? duration,
  ) async {
    final bank = _banks.firstWhere((b) => b['id'] == bankId);
    bank['title'] = title;
    bank['description'] = description;
    bank['duration_minutes'] = duration;
    return bank;
  }

  @override
  Future<Map<String, dynamic>> toggleBank(int bankId) async {
    final bank = _banks.firstWhere((b) => b['id'] == bankId);
    bank['is_active'] = !(bank['is_active'] as bool);
    return bank;
  }

  @override
  Future<void> deleteBank(int bankId) async {
    _banks.removeWhere((b) => b['id'] == bankId);
  }
}

class FakeAdminQuestionRepository implements AdminQuestionRepository {
  final _questions = {
    1: [
      {
        'id': 1,
        'bank_id': 1,
        'text': 'What is hello in Vietnamese?',
        'choices': {
          'A': 'Xin chào',
          'B': 'Tạm biệt',
          'C': 'Cảm ơn',
          'D': 'Vâng',
        },
        'correct_answer': 'A',
        'is_active': true,
      },
      {
        'id': 2,
        'bank_id': 1,
        'text': 'What is goodbye in Vietnamese?',
        'choices': {
          'A': 'Xin chào',
          'B': 'Tạm biệt',
          'C': 'Cảm ơn',
          'D': 'Vâng',
        },
        'correct_answer': 'B',
        'is_active': true,
      },
    ],
    2: [
      {
        'id': 3,
        'bank_id': 2,
        'text': 'What is the term for a meeting in business?',
        'choices': {
          'A': 'Appointment',
          'B': 'Conference',
          'C': 'Gathering',
          'D': 'All of above',
        },
        'correct_answer': 'D',
        'is_active': true,
      },
    ],
  };

  @override
  Future<List<Map<String, dynamic>>> getQuestions(
    int bankId,
    int page,
    int pageSize,
  ) async {
    return _questions[bankId] ?? [];
  }

  @override
  Future<Map<String, dynamic>> createQuestion(
    int bankId,
    String text,
    Map<String, String> choices,
    String correctAnswer,
  ) async {
    final questions = _questions[bankId] ?? [];
    final newQuestion = {
      'id': questions.length + 1,
      'bank_id': bankId,
      'text': text,
      'choices': choices,
      'correct_answer': correctAnswer,
      'is_active': true,
    };
    questions.add(newQuestion);
    _questions[bankId] = questions;
    return newQuestion;
  }

  @override
  Future<Map<String, dynamic>> updateQuestion(
    int questionId,
    String text,
    Map<String, String> choices,
    String correctAnswer,
  ) async {
    for (final qList in _questions.values) {
      final question = qList.firstWhere(
        (q) => q['id'] == questionId,
        orElse: () => {},
      );
      if (question.isNotEmpty) {
        question['text'] = text;
        question['choices'] = choices;
        question['correct_answer'] = correctAnswer;
        return question;
      }
    }
    throw Exception('Question not found');
  }

  @override
  Future<Map<String, dynamic>> toggleQuestion(int questionId) async {
    for (final qList in _questions.values) {
      final question = qList.firstWhere(
        (q) => q['id'] == questionId,
        orElse: () => {},
      );
      if (question.isNotEmpty) {
        question['is_active'] = !(question['is_active'] as bool);
        return question;
      }
    }
    throw Exception('Question not found');
  }

  @override
  Future<void> deleteQuestion(int questionId) async {
    for (final qList in _questions.values) {
      qList.removeWhere((q) => q['id'] == questionId);
    }
  }
}

class FakeConversationRepository implements ConversationRepository {
  final _conversations = <int, List<Map<String, dynamic>>>{};
  int _conversationIdCounter = 1;
  int _messageIdCounter = 1;

  @override
  Future<Map<String, dynamic>> startConversation(
    String targetLanguage,
  ) async {
    final conversationId = _conversationIdCounter++;
    _conversations[conversationId] = [];
    return {
      'id': conversationId,
      'target_language': targetLanguage,
      'started_at': DateTime.now().toIso8601String(),
      'status': 'active',
    };
  }

  @override
  Future<Map<String, dynamic>> sendMessage(
    int conversationId,
    String message,
  ) async {
    final id = _messageIdCounter++;
    final response = {
      'id': id,
      'conversation_id': conversationId,
      'user_message': message,
      'translated_response': _mockTranslateResponse(message),
      'speaker_url': 'https://example.com/audio/speaker_$id.mp3',
      'timestamp': DateTime.now().toIso8601String(),
    };
    _conversations[conversationId]?.add(response);
    return response;
  }

  @override
  Future<void> endConversation(int conversationId) async {
    // Mock end
  }

  @override
  Future<List<Map<String, dynamic>>> getConversationHistory(
    int conversationId,
  ) async {
    return _conversations[conversationId] ?? [];
  }

  String _mockTranslateResponse(String message) {
    const responses = {
      'hello': 'Xin chào! Bạn khỏe không?',
      'good morning': 'Chào buổi sáng! Ngủ ngon không?',
      'how are you': 'Tôi khỏe, cảm ơn bạn hỏi!',
      'thank you': 'Không có gì, rất vui được giúp bạn!',
      'goodbye': 'Tạm biệt! Gặp bạn lần sau!',
    };
    return responses[message.toLowerCase()] ?? 'Phản hồi: $message';
  }
}

class FakeSyncRepository implements SyncRepository {
  @override
  Future<void> syncData() async {
    // Mock sync - do nothing
  }

  @override
  Future<bool> isSyncNeeded() async => false;
}
