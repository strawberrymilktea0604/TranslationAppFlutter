import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:mockito/mockito.dart';
import 'package:get_it/get_it.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/core/network/services/realtime_sync_service.dart';
import 'package:frontend/core/tts/tts_service.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/auth/domain/entities/user_entity.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/vocabulary/domain/repositories/vocabulary_repository.dart';
import 'package:frontend/features/vocabulary/domain/repositories/vocabulary_category_repository.dart';
import 'package:frontend/features/vocabulary/domain/entities/vocabulary_entity.dart';
import 'package:frontend/features/vocabulary/domain/entities/vocabulary_category_entity.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart'
    show CategorySummary;
import 'package:frontend/core/audio_recorder/audio_recorder_service.dart';
import 'package:frontend/features/conversation/domain/entities/conversation_entity.dart'
    as dom;
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:frontend/features/history/domain/entities/history_entity.dart';
import 'package:frontend/features/history/domain/repositories/history_repository.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';
import 'package:frontend/features/translation/domain/repositories/translation_repository.dart';
import 'e2e_seed_data.dart';

// ==================== Fake Core Services ====================

/// Fake NetworkInfo that always reports online and emits no changes.
class FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectedChange => const Stream.empty();
}

/// Fake TtsService that does nothing (no platform TTS in tests).
class FakeTtsService implements TtsService {
  @override
  Future<void> speak(String text, {required String languageCode}) async {}

  @override
  Future<void> stop() async {}

  @override
  bool get isSpeaking => false;

  @override
  Future<void> dispose() async {}

  @override
  void setOnComplete(void Function() onComplete) {}

  @override
  void setOnCancel(void Function() onCancel) {}

  @override
  void setOnError(void Function(String message) onError) {}
}

/// Fake RealtimeSyncService that never connects (no WebSocket in tests).
class FakeRealtimeSyncService extends RealtimeSyncService {
  FakeRealtimeSyncService() : super(baseApiUrl: 'http://localhost:8000/api/v1');

  @override
  Future<void> connect(String accessToken) async {
    // No-op in tests
  }

  @override
  Future<void> disconnect() async {
    // No-op in tests
  }
}

/// Fake AuthLocalDataSource that stores tokens in memory.
class FakeAuthLocalDataSource implements AuthLocalDataSource {
  String? _accessToken;
  String? _refreshToken;
  Map<String, String?>? _userData;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> saveUserData({
    required String userId,
    required String email,
    String? name,
    String? role,
    String? status,
    String? avatarUrl,
  }) async {
    _userData = {
      'userId': userId,
      'email': email,
      'name': name,
      'role': role,
      'status': status,
      'avatarUrl': avatarUrl,
    };
  }

  @override
  Future<Map<String, String?>?> getUserData() async => _userData;

  @override
  Future<void> clearAll() async {
    _accessToken = null;
    _refreshToken = null;
    _userData = null;
  }

  @override
  Future<bool> hasTokens() async => _accessToken != null;
}

/// Fake AuthRepository that implements the real interface for E2E tests.
class FakeAuthRepositoryImpl implements AuthRepository {
  static final _adminUser = UserEntity(
    id: '1',
    email: 'admin@test.com',
    name: 'Admin User',
    role: 'admin',
    status: 'active',
    createdAt: DateTime(2024, 1, 1),
  );

  static final _regularUser = UserEntity(
    id: '2',
    email: 'user@test.com',
    name: 'Test User',
    role: 'user',
    status: 'active',
    createdAt: DateTime(2024, 1, 1),
  );

  UserEntity? _currentUser;

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    if (password != 'password123') {
      return const Left(ServerFailure('Invalid credentials'));
    }

    final localDataSource = GetIt.instance<AuthLocalDataSource>();

    if (email == 'admin@test.com') {
      _currentUser = _adminUser;
      await localDataSource.saveTokens(
        accessToken: 'fake_admin_token',
        refreshToken: 'fake_admin_refresh_token',
      );
      await localDataSource.saveUserData(
        userId: _adminUser.id,
        email: _adminUser.email,
        name: _adminUser.name,
        role: _adminUser.role,
        status: _adminUser.status,
      );
      return Right(_adminUser);
    }
    if (email == 'user@test.com') {
      _currentUser = _regularUser;
      await localDataSource.saveTokens(
        accessToken: 'fake_user_token',
        refreshToken: 'fake_user_refresh_token',
      );
      await localDataSource.saveUserData(
        userId: _regularUser.id,
        email: _regularUser.email,
        name: _regularUser.name,
        role: _regularUser.role,
        status: _regularUser.status,
      );
      return Right(_regularUser);
    }
    return const Left(ServerFailure('Invalid credentials'));
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final user = UserEntity(
      id: '3',
      email: email,
      name: '$firstName $lastName',
      role: 'user',
      status: 'active',
      createdAt: DateTime.now(),
    );
    _currentUser = user;
    final localDataSource = GetIt.instance<AuthLocalDataSource>();
    await localDataSource.saveTokens(
      accessToken: 'fake_register_token',
      refreshToken: 'fake_register_refresh_token',
    );
    await localDataSource.saveUserData(
      userId: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      status: user.status,
    );
    return Right(user);
  }

  @override
  Future<Either<Failure, bool>> checkEmail(String email) async {
    if (email == 'admin@test.com' || email == 'user@test.com') {
      return const Right(false); // already registered
    }
    return const Right(true); // available
  }

  @override
  Future<Either<Failure, void>> logout() async {
    _currentUser = null;
    await GetIt.instance<AuthLocalDataSource>().clearAll();
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    if (_currentUser != null) return Right(_currentUser!);
    return const Left(ServerFailure('Not authenticated'));
  }

  @override
  Future<Either<Failure, void>> refreshToken() async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    String? firstName,
    String? lastName,
  }) async {
    if (_currentUser == null) {
      return const Left(ServerFailure('Not authenticated'));
    }
    _currentUser = UserEntity(
      id: _currentUser!.id,
      email: _currentUser!.email,
      name: '${firstName ?? ''} ${lastName ?? ''}'.trim(),
      role: _currentUser!.role,
      status: _currentUser!.status,
      createdAt: _currentUser!.createdAt,
    );
    return Right(_currentUser!);
  }

  @override
  Future<Either<Failure, void>> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> uploadAvatar({
    required String filePath,
  }) async {
    if (_currentUser == null) {
      return const Left(ServerFailure('Not authenticated'));
    }
    return Right(_currentUser!);
  }
}

// ==================== Mock Classes ====================

class MockAuthRepository extends Mock {}

class MockTranslationRepository extends Mock {}

class MockVocabularyRepository extends Mock {}

class MockAdminUsersRepository extends Mock {}

class MockAdminQuestionBankRepository extends Mock {}

class MockAdminQuestionRepository extends Mock {}

class MockConversationRepository extends Mock {}

class MockSyncRepository extends Mock {}

// ==================== Mock Implementations ====================

class FakeAuthRepository {
  final _registeredUsers = <String, String>{};
  String? _currentToken;

  Future<String> login(String email, String password) async {
    // Seed users: admin@test.com, user@test.com
    if ((email == 'admin@test.com' || email == 'user@test.com') &&
        password == 'password123') {
      _currentToken = 'fake_jwt_token_${email.hashCode}';
      return _currentToken!;
    }
    throw Exception('Invalid credentials');
  }

  Future<void> logout() async {
    _currentToken = null;
  }

  Future<String?> getAccessToken() async => _currentToken;

  Future<void> refreshToken() async {
    if (_currentToken != null) {
      _currentToken = 'fake_jwt_token_refreshed_${DateTime.now().millisecond}';
    }
  }

  Future<void> register(String email, String password, String name) async {
    _registeredUsers[email] = password;
  }

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

class FakeTranslationRepository {
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

  Future<void> saveToHistory(Map<String, dynamic> translation) async {
    // Mock save
  }

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
        'timestamp': DateTime.now()
            .subtract(Duration(hours: 1))
            .toIso8601String(),
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

class FakeVocabularyRepository {
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

  Future<void> saveWord(String word, String translation) async {
    // Mock save
  }

  Future<void> deleteWord(int id) async {
    // Mock delete
  }
}

class FakeAdminUsersRepository {
  final _users = E2ETestSeedData.seedAdminUsers
      .map((u) => Map<String, dynamic>.from(u))
      .toList();

  Future<List<Map<String, dynamic>>> getUsers(int page, int pageSize) async {
    return _users;
  }

  Future<Map<String, dynamic>> createUser({
    required String email,
    String? firstName,
    String? lastName,
    String role = 'user',
    String status = 'active',
  }) async {
    final user = {
      'id': _users.length + 1,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'is_banned': status == 'locked',
      'created_at': '2026-06-01T00:00:00.000Z',
    };
    _users.insert(0, user);
    return user;
  }

  Future<Map<String, dynamic>> banUser(int userId) async {
    final user = _users.firstWhere((u) => u['id'] == userId);
    user['is_banned'] = true;
    return user;
  }

  Future<Map<String, dynamic>> unbanUser(int userId) async {
    final user = _users.firstWhere((u) => u['id'] == userId);
    user['is_banned'] = false;
    return user;
  }
}

class FakeAdminQuestionBankRepository {
  final _banks = E2ETestSeedData.seedQuestionBanks
      .map((b) => Map<String, dynamic>.from(b))
      .toList();

  Future<List<Map<String, dynamic>>> getBanks(int page, int pageSize) async {
    return _banks;
  }

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

  Future<Map<String, dynamic>> updateBank(
    int bankId,
    String title,
    String description,
    int? duration,
  ) async {
    final index = _banks.indexWhere((b) => b['id'] == bankId);
    final bank = Map<String, dynamic>.from(_banks[index]);
    bank['title'] = title;
    bank['description'] = description;
    bank['duration_minutes'] = duration;
    _banks[index] = bank;
    return bank;
  }

  Future<Map<String, dynamic>> toggleBank(int bankId) async {
    final index = _banks.indexWhere((b) => b['id'] == bankId);
    final bank = Map<String, dynamic>.from(_banks[index]);
    bank['is_active'] = !(bank['is_active'] as bool);
    _banks[index] = bank;
    return bank;
  }

  Future<void> deleteBank(int bankId) async {
    _banks.removeWhere((b) => b['id'] == bankId);
  }
}

class FakeAdminQuestionRepository {
  final _questions = <int, List<Map<String, dynamic>>>{
    1: E2ETestSeedData.seedQuestions
        .where((q) => q['bank_id'] == 1)
        .map((q) => Map<String, dynamic>.from(q))
        .toList(),
    2: E2ETestSeedData.seedQuestions
        .where((q) => q['bank_id'] == 2)
        .map((q) => Map<String, dynamic>.from(q))
        .toList(),
    3: E2ETestSeedData.seedQuestions
        .where((q) => q['bank_id'] == 3)
        .map((q) => Map<String, dynamic>.from(q))
        .toList(),
  };

  Future<List<Map<String, dynamic>>> getQuestions(
    int bankId,
    int page,
    int pageSize,
  ) async {
    return _questions[bankId] ?? [];
  }

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

  Future<Map<String, dynamic>> updateQuestion(
    int questionId,
    String text,
    Map<String, String> choices,
    String correctAnswer,
  ) async {
    for (final entry in _questions.entries) {
      final qList = entry.value;
      final index = qList.indexWhere((q) => q['id'] == questionId);
      if (index != -1) {
        final question = Map<String, dynamic>.from(qList[index]);
        question['text'] = text;
        question['choices'] = choices;
        question['correct_answer'] = correctAnswer;
        qList[index] = question;
        return question;
      }
    }
    throw Exception('Question not found');
  }

  Future<Map<String, dynamic>> toggleQuestion(int questionId) async {
    for (final entry in _questions.entries) {
      final qList = entry.value;
      final index = qList.indexWhere((q) => q['id'] == questionId);
      if (index != -1) {
        final question = Map<String, dynamic>.from(qList[index]);
        question['is_active'] = !(question['is_active'] as bool);
        qList[index] = question;
        return question;
      }
    }
    throw Exception('Question not found');
  }

  Future<void> deleteQuestion(int questionId) async {
    for (final qList in _questions.values) {
      qList.removeWhere((q) => q['id'] == questionId);
    }
  }
}

class FakeConversationRepository {
  final _conversations = <int, List<Map<String, dynamic>>>{};
  int _conversationIdCounter = 1;
  int _messageIdCounter = 1;

  Future<Map<String, dynamic>> startConversation(String targetLanguage) async {
    final conversationId = _conversationIdCounter++;
    _conversations[conversationId] = [];
    return {
      'id': conversationId,
      'target_language': targetLanguage,
      'started_at': DateTime.now().toIso8601String(),
      'status': 'active',
    };
  }

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

  Future<void> endConversation(int conversationId) async {
    // Mock end
  }

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

class FakeSyncRepository {
  Future<void> syncData() async {
    // Mock sync - do nothing
  }

  Future<bool> isSyncNeeded() async => false;
}

class FakeHistoryRepositoryImpl implements HistoryRepository {
  final List<HistoryEntity> _items = [];
  int _idCounter = 1;

  @override
  Future<Either<Failure, List<HistoryEntity>>> getHistory({
    String? searchQuery,
    String? langFilter,
    int offset = 0,
    int limit = 50,
  }) async {
    var list = _items.where((item) => !item.isDeleted).toList();
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      list = list
          .where(
            (item) =>
                item.sourceText.toLowerCase().contains(query) ||
                item.translatedText.toLowerCase().contains(query),
          )
          .toList();
    }
    if (langFilter != null && langFilter.isNotEmpty) {
      list = list
          .where(
            (item) =>
                item.sourceLanguage == langFilter ||
                item.targetLanguage == langFilter,
          )
          .toList();
    }
    return Right(list.skip(offset).take(limit).toList());
  }

  @override
  Future<Either<Failure, void>> saveHistory(HistoryEntity entity) async {
    _items.add(
      HistoryEntity(
        isarId: _idCounter++,
        id: entity.id,
        sourceText: entity.sourceText,
        translatedText: entity.translatedText,
        sourceLanguage: entity.sourceLanguage,
        targetLanguage: entity.targetLanguage,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
        isSynced: entity.isSynced,
        isDeleted: entity.isDeleted,
      ),
    );
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteHistory(int isarId) async {
    final index = _items.indexWhere((item) => item.isarId == isarId);
    if (index != -1) {
      final old = _items[index];
      _items[index] = HistoryEntity(
        isarId: old.isarId,
        id: old.id,
        sourceText: old.sourceText,
        translatedText: old.translatedText,
        sourceLanguage: old.sourceLanguage,
        targetLanguage: old.targetLanguage,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
        isSynced: old.isSynced,
        isDeleted: true,
      );
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearHistory() async {
    for (var i = 0; i < _items.length; i++) {
      final old = _items[i];
      _items[i] = HistoryEntity(
        isarId: old.isarId,
        id: old.id,
        sourceText: old.sourceText,
        translatedText: old.translatedText,
        sourceLanguage: old.sourceLanguage,
        targetLanguage: old.targetLanguage,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
        isSynced: old.isSynced,
        isDeleted: true,
      );
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, int>> count() async {
    return Right(_items.where((item) => !item.isDeleted).length);
  }
}

class FakeVocabularyRepositoryImpl implements VocabularyRepository {
  final List<VocabularyEntity> _items = [];
  int _idCounter = 1;

  @override
  Future<Either<Failure, List<VocabularyEntity>>> getVocabularyList({
    String? searchQuery,
    String? category,
  }) async {
    var list = _items.where((i) => !i.isDeleted).toList();
    if (category != null && category.isNotEmpty) {
      list = list.where((i) => i.category == category).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where(
            (i) =>
                i.word.toLowerCase().contains(q) ||
                i.translation.toLowerCase().contains(q),
          )
          .toList();
    }
    return Right(list);
  }

  @override
  Future<Either<Failure, List<String>>> getCategories() async {
    final cats = _items
        .where((i) => !i.isDeleted)
        .map((i) => i.category)
        .toSet()
        .toList();
    cats.sort();
    return Right(cats);
  }

  @override
  Future<Either<Failure, List<CategorySummary>>> getCategorySummaries() async {
    final summaries = <CategorySummary>[];
    final map = <String, List<VocabularyEntity>>{};
    for (final i in _items.where((i) => !i.isDeleted)) {
      map.putIfAbsent(i.category, () => []).add(i);
    }
    map.forEach((cat, list) {
      final learned = list.where((w) => w.masteryLevel >= 3).length;
      summaries.add(
        CategorySummary(
          name: cat,
          wordCount: list.length,
          learnedCount: learned,
        ),
      );
    });
    return Right(summaries);
  }

  @override
  Future<Either<Failure, List<VocabularyEntity>>> getByCategory(
    String category,
  ) async {
    return Right(
      _items.where((i) => !i.isDeleted && i.category == category).toList(),
    );
  }

  @override
  Future<Either<Failure, VocabularyEntity>> saveVocabulary({
    required String word,
    required String translation,
    required String sourceLanguage,
    required String targetLanguage,
    String category = 'Chưa phân loại',
    int? categoryId,
    int? translationId,
  }) async {
    final entity = VocabularyEntity(
      id: 'local_$_idCounter',
      isarId: _idCounter++,
      word: word,
      translation: translation,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      category: category,
      categoryId: categoryId,
      translationId: translationId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _items.add(entity);
    return Right(entity);
  }

  @override
  Future<Either<Failure, void>> toggleStar(int isarId) async {
    final idx = _items.indexWhere((i) => i.isarId == isarId);
    if (idx != -1) {
      final old = _items[idx];
      _items[idx] = VocabularyEntity(
        id: old.id,
        isarId: old.isarId,
        word: old.word,
        translation: old.translation,
        sourceLanguage: old.sourceLanguage,
        targetLanguage: old.targetLanguage,
        category: old.category,
        categoryId: old.categoryId,
        isStarred: !old.isStarred,
        masteryLevel: old.masteryLevel,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateMastery(int isarId, int newLevel) async {
    final idx = _items.indexWhere((i) => i.isarId == isarId);
    if (idx != -1) {
      final old = _items[idx];
      _items[idx] = VocabularyEntity(
        id: old.id,
        isarId: old.isarId,
        word: old.word,
        translation: old.translation,
        sourceLanguage: old.sourceLanguage,
        targetLanguage: old.targetLanguage,
        category: old.category,
        categoryId: old.categoryId,
        isStarred: old.isStarred,
        masteryLevel: newLevel,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteVocabulary(int isarId) async {
    final idx = _items.indexWhere((i) => i.isarId == isarId);
    if (idx != -1) {
      final old = _items[idx];
      _items[idx] = VocabularyEntity(
        id: old.id,
        isarId: old.isarId,
        word: old.word,
        translation: old.translation,
        sourceLanguage: old.sourceLanguage,
        targetLanguage: old.targetLanguage,
        category: old.category,
        categoryId: old.categoryId,
        isStarred: old.isStarred,
        masteryLevel: old.masteryLevel,
        isDeleted: true,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    return const Right(null);
  }
}

class FakeVocabularyCategoryRepositoryImpl
    implements VocabularyCategoryRepository {
  final List<VocabularyCategoryEntity> _categories = [];
  int _idCounter = 1;

  @override
  Future<Either<Failure, List<VocabularyCategoryEntity>>>
  getCategories() async {
    return Right(_categories.where((c) => !c.isDeleted).toList());
  }

  @override
  Future<Either<Failure, VocabularyCategoryEntity>> createCategory(
    String name,
  ) async {
    final cat = VocabularyCategoryEntity(
      id: _idCounter,
      isarId: _idCounter++,
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _categories.add(cat);
    return Right(cat);
  }

  @override
  Future<Either<Failure, VocabularyCategoryEntity>> updateCategory(
    int id,
    String name,
  ) async {
    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx != -1) {
      final old = _categories[idx];
      final cat = VocabularyCategoryEntity(
        id: old.id,
        isarId: old.isarId,
        name: name,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
      _categories[idx] = cat;
      return Right(cat);
    }
    return const Left(ServerFailure('Category not found'));
  }

  @override
  Future<Either<Failure, void>> deleteCategory(int id) async {
    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx != -1) {
      final old = _categories[idx];
      _categories[idx] = VocabularyCategoryEntity(
        id: old.id,
        isarId: old.isarId,
        name: old.name,
        isDeleted: true,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    return const Right(null);
  }
}

class FakeAudioRecorderService implements AudioRecorderService {
  bool _isRecording = false;
  bool _isPaused = false;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> startRecording() async {
    _isRecording = true;
    _isPaused = false;
  }

  @override
  Future<RecordingResult?> stopRecording() async {
    _isRecording = false;
    _isPaused = false;
    return const RecordingResult(
      filePath: 'fake/path/audio.m4a',
      duration: Duration(seconds: 2),
      format: 'm4a',
    );
  }

  @override
  Future<Stream<Uint8List>> startStreamRecording() async {
    _isRecording = true;
    _isPaused = false;
    return Stream.value(Uint8List.fromList([0, 1, 2, 3]));
  }

  @override
  Future<void> stopStreamRecording() async {
    _isRecording = false;
    _isPaused = false;
  }

  @override
  Future<void> cancelRecording() async {
    _isRecording = false;
    _isPaused = false;
  }

  @override
  Future<void> pauseRecording() async {
    _isPaused = true;
  }

  @override
  Future<void> resumeRecording() async {
    _isPaused = false;
  }

  @override
  bool get isRecording => _isRecording;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> dispose() async {}
}

class FakeConversationRepositoryImpl extends Mock
    implements ConversationRepository {
  dom.WebSocketConnectionStatus _status =
      dom.WebSocketConnectionStatus.disconnected;
  final StreamController<dom.ConversationEvent> _eventController =
      StreamController<dom.ConversationEvent>.broadcast();
  final List<Timer> _pendingTimers = [];

  @override
  dom.WebSocketConnectionStatus get connectionStatus => _status;

  @override
  Stream<dom.ConversationEvent> connect(String accessToken) {
    _status = dom.WebSocketConnectionStatus.connected;
    _schedule(const Duration(milliseconds: 100), () {
      if (!_eventController.isClosed) {
        _eventController.add(
          const dom.ConversationConnectionChanged(
            status: dom.WebSocketConnectionStatus.connected,
          ),
        );
      }
    });
    return _eventController.stream;
  }

  @override
  void startSession({
    required String sourceLanguage,
    required String targetLanguage,
    dom.ConversationSpeaker speaker = dom.ConversationSpeaker.speakerA,
  }) {
    _schedule(const Duration(milliseconds: 100), () {
      if (!_eventController.isClosed) {
        _eventController.add(
          const dom.ConversationSessionStarted(
            sessionId: 'fake_session',
            status: 'active',
          ),
        );
      }
    });
  }

  @override
  void sendAudioMetadata({
    required int sampleRate,
    required String audioFormat,
    required dom.ConversationSpeaker speaker,
    required String sourceLanguage,
    required String targetLanguage,
  }) {}

  @override
  void sendAudioChunk(Uint8List chunk) {}

  @override
  void endUtterance() {
    _schedule(const Duration(milliseconds: 200), () {
      if (!_eventController.isClosed) {
        _eventController.add(
          dom.ConversationTranslationReceived(
            message: dom.ConversationMessage(
              id: 'fake_msg_id',
              speaker: dom.ConversationSpeaker.speakerA,
              sourceText: 'Test input',
              translatedText: 'Xin chào',
              sourceLanguage: 'English',
              targetLanguage: 'Vietnamese',
              timestamp: DateTime.now(),
            ),
          ),
        );
      }
    });
  }

  @override
  void changeSpeaker(dom.ConversationSpeaker speaker) {}

  @override
  void endSession() {
    if (!_eventController.isClosed) {
      _eventController.add(
        const dom.ConversationConnectionChanged(
          status: dom.WebSocketConnectionStatus.disconnected,
        ),
      );
    }
  }

  void simulateRepositoryTranslation(String sourceText, String translatedText) {
    if (!_eventController.isClosed) {
      _eventController.add(
        dom.ConversationTranslationReceived(
          message: dom.ConversationMessage(
            id: 'fake_msg_id_${DateTime.now().microsecondsSinceEpoch}',
            speaker: dom.ConversationSpeaker.speakerA,
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: 'English',
            targetLanguage: 'Vietnamese',
            timestamp: DateTime.now(),
          ),
        ),
      );
    }
  }

  void simulateRepositoryError(String code, String message) {
    if (!_eventController.isClosed) {
      _eventController.add(
        dom.ConversationErrorEvent(code: code, message: message),
      );
    }
  }

  @override
  void disconnect() {
    _cancelPendingTimers();
    _status = dom.WebSocketConnectionStatus.disconnected;
  }

  Future<void> dispose() async {
    _cancelPendingTimers();
    if (!_eventController.isClosed) {
      await _eventController.close();
    }
  }

  void _schedule(Duration duration, void Function() callback) {
    late final Timer timer;
    timer = Timer(duration, () {
      _pendingTimers.remove(timer);
      callback();
    });
    _pendingTimers.add(timer);
  }

  void _cancelPendingTimers() {
    for (final timer in _pendingTimers) {
      timer.cancel();
    }
    _pendingTimers.clear();
  }
}

class FakeTranslationRepositoryImpl implements TranslationRepository {
  @override
  Future<Either<Failure, TranslationEntity>> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final translation = TranslationEntity(
      id: '1',
      sourceText: text,
      translatedText: 'Dịch: $text',
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return Right(translation);
  }

  @override
  Future<Either<Failure, void>> switchLanguages({
    required String currentSource,
    required String currentTarget,
  }) async {
    return const Right(null);
  }
}
