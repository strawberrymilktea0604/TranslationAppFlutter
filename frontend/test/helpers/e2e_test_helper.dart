import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/core/network/bloc/network_cubit.dart';
import 'package:frontend/core/network/services/realtime_sync_service.dart';
import 'package:frontend/core/tts/tts_service.dart';
import 'package:frontend/core/tts/bloc/tts_cubit.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/login_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/register_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/check_email_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/change_password_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/upload_avatar_usecase.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/sync/domain/entities/sync_entity.dart';
import 'package:frontend/features/sync/domain/entities/sync_push_entity.dart';
import 'package:frontend/features/sync/domain/repositories/sync_repository.dart';
import 'package:frontend/features/sync/domain/usecases/sync_data_usecase.dart';
import 'package:frontend/features/sync/domain/usecases/full_sync_usecase.dart';
import 'package:frontend/features/sync/presentation/bloc/sync_cubit.dart';

import 'mock_repositories.dart';
import 'e2e_seed_data.dart';

import 'package:frontend/app_config.dart';
import 'package:frontend/main.dart' show config;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:frontend/features/admin/presentation/pages/admin_login_page.dart';

import 'package:frontend/features/vocabulary/domain/repositories/vocabulary_repository.dart';
import 'package:frontend/features/vocabulary/domain/repositories/vocabulary_category_repository.dart';
import 'package:frontend/features/vocabulary/domain/usecases/save_vocabulary_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/get_vocabulary_list_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/delete_vocabulary_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/get_categories_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/create_category_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/update_category_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/delete_category_usecase.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_category_cubit.dart';

import 'package:frontend/core/audio_recorder/audio_recorder_service.dart';
import 'package:frontend/core/audio_recorder/bloc/recording_cubit.dart';

import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:frontend/features/conversation/domain/usecases/connect_conversation_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/start_session_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/send_audio_chunk_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/switch_speaker_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/end_session_usecase.dart';
import 'package:frontend/features/conversation/presentation/bloc/conversation_viewmodel.dart';

import 'package:frontend/features/translation/domain/repositories/translation_repository.dart';
import 'package:frontend/features/translation/domain/usecases/translate_text_usecase.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_cubit.dart';

/// Test environment setup helper
class E2ETestHelper {
  static final GetIt _getIt = GetIt.instance;

  /// Initialize test environment with mock repositories and all Cubits
  /// that [MyApp] requires from GetIt.
  static Future<void> setupTestEnvironment() async {
    // Keep default scheduler speed to satisfy flutter_test invariants.
    // Using non-default values can fail tests with:
    // "The timeDilation was changed and not reset by the test."
    timeDilation = 1.0;

    // Clear previous instances
    await _getIt.reset();

    // ── Core services ──────────────────────────────────────────────
    _getIt.registerLazySingleton<NetworkInfo>(() => FakeNetworkInfo());
    _getIt.registerLazySingleton<TtsService>(() => FakeTtsService());
    _getIt.registerLazySingleton<RealtimeSyncService>(
      () => FakeRealtimeSyncService(),
    );
    _getIt.registerLazySingleton<AuthLocalDataSource>(
      () => FakeAuthLocalDataSource(),
    );

    // ── Auth feature (Repository → UseCases → Cubit) ───────────────
    _getIt.registerLazySingleton<AuthRepository>(
      () => FakeAuthRepositoryImpl(),
    );

    _getIt.registerLazySingleton(() => LoginUseCase(_getIt()));
    _getIt.registerLazySingleton(() => RegisterUseCase(_getIt()));
    _getIt.registerLazySingleton(() => LogoutUseCase(_getIt()));
    _getIt.registerLazySingleton(() => GetCurrentUserUseCase(_getIt()));
    _getIt.registerLazySingleton(() => CheckEmailUseCase(_getIt()));
    _getIt.registerLazySingleton(() => UpdateProfileUseCase(_getIt()));
    _getIt.registerLazySingleton(() => ChangePasswordUseCase(_getIt()));
    _getIt.registerLazySingleton(() => UploadAvatarUseCase(_getIt()));

    _getIt.registerFactory(
      () => AuthCubit(
        loginUseCase: _getIt(),
        registerUseCase: _getIt(),
        logoutUseCase: _getIt(),
        getCurrentUserUseCase: _getIt(),
        checkEmailUseCase: _getIt(),
        updateProfileUseCase: _getIt(),
        changePasswordUseCase: _getIt(),
        uploadAvatarUseCase: _getIt(),
      ),
    );

    // ── Network Cubit ──────────────────────────────────────────────
    _getIt.registerLazySingleton<NetworkCubit>(
      () => NetworkCubit(networkInfo: _getIt()),
    );

    // ── TTS Cubit ──────────────────────────────────────────────────
    _getIt.registerLazySingleton<TtsCubit>(
      () => TtsCubit(ttsService: _getIt()),
    );

    // ── Sync Cubit (with stub use cases) ───────────────────────────
    _getIt.registerLazySingleton(() => _FakeSyncDataUseCase());
    _getIt.registerLazySingleton(() => _FakeFullSyncUseCase());

    _getIt.registerLazySingleton<SyncCubit>(
      () => SyncCubit(
        syncDataUseCase: _getIt<_FakeSyncDataUseCase>(),
        fullSyncUseCase: _getIt<_FakeFullSyncUseCase>(),
        networkCubit: _getIt(),
        realtimeSyncService: _getIt(),
      ),
    );

    // ── Fake repositories (for direct test assertions) ─────────────
    _getIt.registerSingleton<FakeAuthRepository>(FakeAuthRepository());
    _getIt.registerSingleton<FakeTranslationRepository>(
      FakeTranslationRepository(),
    );
    _getIt.registerSingleton<FakeVocabularyRepository>(
      FakeVocabularyRepository(),
    );
    _getIt.registerSingleton<FakeAdminUsersRepository>(
      FakeAdminUsersRepository(),
    );
    _getIt.registerSingleton<FakeAdminQuestionBankRepository>(
      FakeAdminQuestionBankRepository(),
    );
    _getIt.registerSingleton<FakeAdminQuestionRepository>(
      FakeAdminQuestionRepository(),
    );
    _getIt.registerSingleton<FakeConversationRepository>(
      FakeConversationRepository(),
    );
    _getIt.registerSingleton<FakeSyncRepository>(FakeSyncRepository());

    // ── Vocabulary & Categories ────────────────────────────────────
    _getIt.registerLazySingleton<VocabularyRepository>(
      () => FakeVocabularyRepositoryImpl(),
    );
    _getIt.registerLazySingleton<VocabularyCategoryRepository>(
      () => FakeVocabularyCategoryRepositoryImpl(),
    );
    _getIt.registerLazySingleton(() => SaveVocabularyUseCase(_getIt()));
    _getIt.registerLazySingleton(() => GetVocabularyListUseCase(_getIt()));
    _getIt.registerLazySingleton(() => DeleteVocabularyUseCase(_getIt()));
    _getIt.registerLazySingleton(() => GetCategorySummariesUseCase(_getIt()));
    _getIt.registerLazySingleton(() => GetCategoriesUseCase(_getIt()));
    _getIt.registerLazySingleton(() => CreateCategoryUseCase(_getIt()));
    _getIt.registerLazySingleton(() => UpdateCategoryUseCase(_getIt()));
    _getIt.registerLazySingleton(() => DeleteCategoryUseCase(_getIt()));

    _getIt.registerFactory(
      () => VocabularyCubit(
        saveVocabularyUseCase: _getIt(),
        getVocabularyListUseCase: _getIt(),
        deleteVocabularyUseCase: _getIt(),
      ),
    );
    _getIt.registerFactory(
      () => VocabularyCategoryCubit(
        getCategoriesUseCase: _getIt(),
        createCategoryUseCase: _getIt(),
        updateCategoryUseCase: _getIt(),
        deleteCategoryUseCase: _getIt(),
      ),
    );

    // ── Audio & Recording ───────────────────────────────────────────
    _getIt.registerLazySingleton<AudioRecorderService>(
      () => FakeAudioRecorderService(),
    );
    _getIt.registerFactory(() => RecordingCubit(recorderService: _getIt()));

    // ── Translation ─────────────────────────────────────────────────
    _getIt.registerLazySingleton<TranslationRepository>(
      () => FakeTranslationRepositoryImpl(),
    );
    _getIt.registerLazySingleton(() => TranslateTextUseCase(_getIt()));
    _getIt.registerFactory(() => TranslationCubit(_getIt()));

    // ── Conversation ────────────────────────────────────────────────
    _getIt.registerLazySingleton<ConversationRepository>(
      () => FakeConversationRepositoryImpl(),
      dispose: (repo) async {
        if (repo is FakeConversationRepositoryImpl) {
          await repo.dispose();
        }
      },
    );
    _getIt.registerLazySingleton(() => ConnectConversationUseCase(_getIt()));
    _getIt.registerLazySingleton(() => StartSessionUseCase(_getIt()));
    _getIt.registerLazySingleton(() => SendAudioChunkUseCase(_getIt()));
    _getIt.registerLazySingleton(() => SwitchSpeakerUseCase(_getIt()));
    _getIt.registerLazySingleton(() => EndSessionUseCase(_getIt()));
    _getIt.registerFactory(
      () => ConversationViewModel(
        connectUseCase: _getIt(),
        startSessionUseCase: _getIt(),
        sendAudioChunkUseCase: _getIt(),
        switchSpeakerUseCase: _getIt(),
        endSessionUseCase: _getIt(),
        repository: _getIt(),
        authLocalDataSource: _getIt(),
        audioRecorderService: _getIt(),
      ),
    );

    // Initialize app config (normally done by main_dev.dart)
    config = const AppConfig(
      appName: 'Translation App Test',
      apiUrl: 'http://localhost:8000/api/v1',
    );

    // Register mock HTTP client to intercept all service API calls
    final mockClient = _createMockHttpClient();
    _getIt.registerSingleton<http.Client>(mockClient);

    // Initialize other necessary services
    WidgetsFlutterBinding.ensureInitialized();
  }

  /// Create a mock HTTP client to handle admin endpoints without backend running
  static http.Client _createMockHttpClient() {
    return MockClient((request) async {
      final path = request.url.path;
      final method = request.method;
      final authHeader = request.headers['Authorization'] ?? '';
      final isUserToken = authHeader.contains('fake_user_token');

      if (isUserToken && path.contains('/admin/')) {
        return http.Response(
          jsonEncode({'detail': 'Forbidden'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      }

      try {
        // --- 1. Admin Users ---
        if (path.endsWith('/admin/users') && method == 'GET') {
          final page =
              int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
          final pageSize =
              int.tryParse(request.url.queryParameters['page_size'] ?? '20') ??
              20;
          final usersRepo = _getIt<FakeAdminUsersRepository>();
          final users = await usersRepo.getUsers(page, pageSize);
          final itemsJson = users
              .map(
                (u) => {
                  'id': u['id'],
                  'email': u['email'],
                  'first_name': u['first_name'],
                  'last_name': u['last_name'],
                  'avatar_url': u['avatar_url'],
                  'role': u['role'] ?? 'user',
                  'status': (u['is_banned'] == true) ? 'locked' : 'active',
                  'created_at': u['created_at'] ?? '2026-06-01T00:00:00.000Z',
                },
              )
              .toList();

          return http.Response(
            jsonEncode({
              'items': itemsJson,
              'total': users.length,
              'page': page,
              'page_size': pageSize,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/admin/users') && method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final usersRepo = _getIt<FakeAdminUsersRepository>();
          final u = await usersRepo.createUser(
            email: body['email'] as String,
            firstName: body['first_name'] as String?,
            lastName: body['last_name'] as String?,
            role: body['role'] as String? ?? 'user',
            status: body['status'] as String? ?? 'active',
          );
          return http.Response(
            jsonEncode({
              'id': u['id'],
              'email': u['email'],
              'first_name': u['first_name'],
              'last_name': u['last_name'],
              'avatar_url': u['avatar_url'],
              'role': u['role'] ?? 'user',
              'status': (u['is_banned'] == true) ? 'locked' : 'active',
              'is_deleted': false,
              'created_at': u['created_at'] ?? '2026-06-01T00:00:00.000Z',
              'updated_at': u['updated_at'] ?? '2026-06-01T00:00:00.000Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/users/') &&
            path.endsWith('/ban') &&
            method == 'PATCH') {
          final parts = path.split('/');
          final userId = int.parse(parts[parts.length - 2]);
          final usersRepo = _getIt<FakeAdminUsersRepository>();
          final u = await usersRepo.banUser(userId);
          return http.Response(
            jsonEncode({
              'id': u['id'],
              'email': u['email'],
              'first_name': u['first_name'],
              'last_name': u['last_name'],
              'avatar_url': u['avatar_url'],
              'role': u['role'] ?? 'user',
              'status': 'locked',
              'created_at': u['created_at'] ?? '2026-06-01T00:00:00.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/users/') &&
            path.endsWith('/unban') &&
            method == 'PATCH') {
          final parts = path.split('/');
          final userId = int.parse(parts[parts.length - 2]);
          final usersRepo = _getIt<FakeAdminUsersRepository>();
          final u = await usersRepo.unbanUser(userId);
          return http.Response(
            jsonEncode({
              'id': u['id'],
              'email': u['email'],
              'first_name': u['first_name'],
              'last_name': u['last_name'],
              'avatar_url': u['avatar_url'],
              'role': u['role'] ?? 'user',
              'status': 'active',
              'created_at': u['created_at'] ?? '2026-06-01T00:00:00.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // --- 2. Admin Question Banks ---
        if (path.endsWith('/admin/question-banks') && method == 'GET') {
          final page =
              int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
          final pageSize =
              int.tryParse(request.url.queryParameters['page_size'] ?? '20') ??
              20;
          final bankRepo = _getIt<FakeAdminQuestionBankRepository>();
          final banks = await bankRepo.getBanks(page, pageSize);
          final itemsJson = banks
              .map(
                (b) => {
                  'id': b['id'],
                  'title': b['title'],
                  'description': b['description'],
                  'duration_minutes':
                      b['duration_minutes'] ?? b['duration'] ?? 10,
                  'is_deleted': b['is_deleted'] ?? !(b['is_active'] ?? true),
                  'question_count': b['question_count'] ?? 0,
                  'created_at': b['created_at'] ?? '2026-06-01T00:00:00.000Z',
                  'updated_at': b['updated_at'] ?? '2026-06-01T00:00:00.000Z',
                },
              )
              .toList();

          return http.Response(
            jsonEncode({
              'items': itemsJson,
              'total': banks.length,
              'page': page,
              'page_size': pageSize,
              'total_pages': 1,
              'has_next': false,
              'has_prev': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/admin/question-banks') && method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final title = body['title'] as String;
          final description = body['description'] as String?;
          final duration = body['duration_minutes'] as int?;
          final bankRepo = _getIt<FakeAdminQuestionBankRepository>();
          final b = await bankRepo.createBank(
            title,
            description ?? '',
            duration,
          );
          return http.Response(
            jsonEncode({
              'id': b['id'],
              'title': b['title'],
              'description': b['description'],
              'duration_minutes': b['duration_minutes'] ?? b['duration'] ?? 10,
              'is_deleted': b['is_deleted'] ?? !(b['is_active'] ?? true),
              'question_count': b['question_count'] ?? 0,
              'created_at': b['created_at'] ?? '2026-06-01T00:00:00.000Z',
              'updated_at': b['updated_at'] ?? '2026-06-01T00:00:00.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/question-banks/') && method == 'PUT') {
          final parts = path.split('/');
          final bankId = int.parse(parts[parts.length - 1]);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final title = body['title'] as String?;
          final description = body['description'] as String?;
          final duration = body['duration_minutes'] as int?;
          final bankRepo = _getIt<FakeAdminQuestionBankRepository>();
          final b = await bankRepo.updateBank(
            bankId,
            title ?? '',
            description ?? '',
            duration,
          );
          return http.Response(
            jsonEncode({
              'id': b['id'],
              'title': b['title'],
              'description': b['description'],
              'duration_minutes': b['duration_minutes'] ?? b['duration'] ?? 10,
              'is_deleted': b['is_deleted'] ?? !(b['is_active'] ?? true),
              'question_count': b['question_count'] ?? 0,
              'created_at': b['created_at'] ?? '2026-06-01T00:00:00.000Z',
              'updated_at': b['updated_at'] ?? '2026-06-01T00:00:00.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/question-banks/') &&
            path.endsWith('/toggle') &&
            method == 'PATCH') {
          final parts = path.split('/');
          final bankId = int.parse(parts[parts.length - 2]);
          final bankRepo = _getIt<FakeAdminQuestionBankRepository>();
          final b = await bankRepo.toggleBank(bankId);
          return http.Response(
            jsonEncode({
              'id': b['id'],
              'is_deleted': b['is_deleted'] ?? !(b['is_active'] ?? true),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/question-banks/') && method == 'DELETE') {
          final parts = path.split('/');
          final bankId = int.parse(parts[parts.length - 1]);
          final bankRepo = _getIt<FakeAdminQuestionBankRepository>();
          await bankRepo.deleteBank(bankId);
          return http.Response('', 204);
        }

        // --- 3. Admin Questions ---
        if (path.contains('/admin/question-banks/') &&
            path.endsWith('/questions') &&
            method == 'GET') {
          final parts = path.split('/');
          final bankId = int.parse(parts[parts.length - 2]);
          final page =
              int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
          final pageSize =
              int.tryParse(request.url.queryParameters['page_size'] ?? '20') ??
              20;
          final questionRepo = _getIt<FakeAdminQuestionRepository>();
          final questions = await questionRepo.getQuestions(
            bankId,
            page,
            pageSize,
          );
          final itemsJson = questions
              .map(
                (q) => {
                  'id': q['id'],
                  'bank_id': q['bank_id'],
                  'content': q['content'] ?? q['text'] ?? '',
                  'choices': q['choices'] ?? {},
                  'correct_answer': q['correct_answer'] ?? '',
                  'is_deleted': q['is_deleted'] ?? !(q['is_active'] ?? true),
                  'created_at': q['created_at'] ?? '2026-06-01T00:00:00.000Z',
                  'updated_at': q['updated_at'] ?? '2026-06-01T00:00:00.000Z',
                },
              )
              .toList();

          return http.Response(
            jsonEncode({
              'items': itemsJson,
              'total': questions.length,
              'page': page,
              'page_size': pageSize,
              'total_pages': 1,
              'has_next': false,
              'has_prev': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/question-banks/') &&
            path.endsWith('/questions') &&
            method == 'POST') {
          final parts = path.split('/');
          final bankId = int.parse(parts[parts.length - 2]);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final content = body['content'] as String;
          final choices = Map<String, String>.from(body['choices'] as Map);
          final correctAnswer = body['correct_answer'] as String;
          final questionRepo = _getIt<FakeAdminQuestionRepository>();
          final q = await questionRepo.createQuestion(
            bankId,
            content,
            choices,
            correctAnswer,
          );
          return http.Response(
            jsonEncode({
              'id': q['id'],
              'bank_id': q['bank_id'],
              'content': q['content'] ?? q['text'] ?? '',
              'choices': q['choices'] ?? {},
              'correct_answer': q['correct_answer'] ?? '',
              'is_deleted': q['is_deleted'] ?? !(q['is_active'] ?? true),
              'created_at': q['created_at'] ?? '2026-06-01T00:00:00.000Z',
              'updated_at': q['updated_at'] ?? '2026-06-01T00:00:00.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/questions/') && method == 'PUT') {
          final parts = path.split('/');
          final questionId = int.parse(parts[parts.length - 1]);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final content = body['content'] as String?;
          final choices = body['choices'] != null
              ? Map<String, String>.from(body['choices'] as Map)
              : null;
          final correctAnswer = body['correct_answer'] as String?;
          final questionRepo = _getIt<FakeAdminQuestionRepository>();
          final q = await questionRepo.updateQuestion(
            questionId,
            content ?? '',
            choices ?? {},
            correctAnswer ?? '',
          );
          return http.Response(
            jsonEncode({
              'id': q['id'],
              'bank_id': q['bank_id'],
              'content': q['content'] ?? q['text'] ?? '',
              'choices': q['choices'] ?? {},
              'correct_answer': q['correct_answer'] ?? '',
              'is_deleted': q['is_deleted'] ?? !(q['is_active'] ?? true),
              'created_at': q['created_at'] ?? '2026-06-01T00:00:00.000Z',
              'updated_at': q['updated_at'] ?? '2026-06-01T00:00:00.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/questions/') &&
            path.endsWith('/toggle') &&
            method == 'PATCH') {
          final parts = path.split('/');
          final questionId = int.parse(parts[parts.length - 2]);
          final questionRepo = _getIt<FakeAdminQuestionRepository>();
          final q = await questionRepo.toggleQuestion(questionId);
          return http.Response(
            jsonEncode({
              'id': q['id'],
              'is_deleted': q['is_deleted'] ?? !(q['is_active'] ?? true),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.contains('/admin/questions/') && method == 'DELETE') {
          final parts = path.split('/');
          final questionId = int.parse(parts[parts.length - 1]);
          final questionRepo = _getIt<FakeAdminQuestionRepository>();
          await questionRepo.deleteQuestion(questionId);
          return http.Response('', 204);
        }

        // --- 4. Other stats/dashboard requests ---
        if (path.endsWith('/admin/services/summary') && method == 'GET') {
          return http.Response(
            jsonEncode({
              'total_translations': 120,
              'today_translations': 12,
              'week_translations': 48,
              'month_translations': 120,
              'by_type': [
                {'type': 'text', 'count': 80, 'percentage': 66.67},
                {'type': 'image', 'count': 25, 'percentage': 20.83},
                {'type': 'voice', 'count': 15, 'percentage': 12.5},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/admin/activities/recent') && method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'type': 'translation',
                  'title': 'Translation created',
                  'description': 'Hello, how are you today?',
                  'actor_id': 1,
                  'actor_email': 'user1@test.com',
                  'created_at': '2026-06-01T10:00:00.000Z',
                  'metadata': {
                    'translation_id': 1000,
                    'translation_type': 'text',
                  },
                },
                {
                  'type': 'user_created',
                  'title': 'User created',
                  'description': 'user2@test.com',
                  'actor_id': 2,
                  'actor_email': 'user2@test.com',
                  'created_at': '2026-06-01T09:30:00.000Z',
                  'metadata': {'role': 'user', 'status': 'active'},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/admin/services/translations') && method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1000,
                  'user_id': 1,
                  'user_email': 'user1@test.com',
                  'user_name': 'User One',
                  'source_language': 'en',
                  'target_language': 'vi',
                  'source_text': 'Hello, how are you today?',
                  'translated_text': 'Xin chào, hôm nay bạn khỏe không?',
                  'translation_type': 'text',
                  'is_deleted': false,
                  'created_at': '2026-06-01T10:00:00.000Z',
                  'updated_at': '2026-06-01T10:00:00.000Z',
                },
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
              'has_next': false,
              'has_prev': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/admin/analytics/overview') && method == 'GET') {
          return http.Response(
            jsonEncode({
              'days': 7,
              'average_translations_per_day': {
                'value': 17.14,
                'previous_value': 12.0,
                'change_percent': 42.86,
              },
              'active_users': {
                'value': 3.0,
                'previous_value': 2.0,
                'change_percent': 50.0,
              },
              'average_response_time_ms': {
                'value': 245.0,
                'previous_value': 260.0,
                'change_percent': -5.77,
              },
              'translation_accuracy_percent': {
                'value': 94.2,
                'previous_value': 93.0,
                'change_percent': 1.29,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/admin/analytics/translation-types') &&
            method == 'GET') {
          return http.Response(
            jsonEncode({
              'days': 7,
              'items': [
                {'type': 'text', 'count': 80, 'percentage': 66.67},
                {'type': 'image', 'count': 25, 'percentage': 20.83},
                {'type': 'voice', 'count': 15, 'percentage': 12.5},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/admin/analytics/languages') && method == 'GET') {
          return http.Response(
            jsonEncode({
              'days': 7,
              'source_languages': [
                {'language': 'en', 'count': 70, 'percentage': 58.33},
                {'language': 'vi', 'count': 50, 'percentage': 41.67},
              ],
              'target_languages': [
                {'language': 'vi', 'count': 85, 'percentage': 70.83},
                {'language': 'en', 'count': 35, 'percentage': 29.17},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/admin/analytics/services') && method == 'GET') {
          return http.Response(
            jsonEncode({
              'days': 7,
              'items': [
                {
                  'endpoint': 'translation/text',
                  'ai_model': 'google-translate',
                  'total_requests': 120,
                  'successful_requests': 118,
                  'failed_requests': 2,
                  'average_response_time_ms': 245.0,
                  'total_tokens_used': 0,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (path.endsWith('/api/v1/translations') && method == 'GET') {
          return http.Response(
            jsonEncode({'items': [], 'total': 120}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      } catch (e) {
        return http.Response(jsonEncode({'message': e.toString()}), 500);
      }

      return http.Response('Not Found', 404);
    });
  }

  /// Cleanup test environment
  static Future<void> teardownTestEnvironment() async {
    // Reset scheduler speed so each test ends with default invariant values.
    timeDilation = 1.0;
    await _getIt.reset();
  }

  /// Get fake auth repository
  static FakeAuthRepository getAuthRepository() => _getIt<FakeAuthRepository>();

  /// Get fake translation repository
  static FakeTranslationRepository getTranslationRepository() =>
      _getIt<FakeTranslationRepository>();

  /// Get fake vocabulary repository
  static FakeVocabularyRepository getVocabularyRepository() =>
      _getIt<FakeVocabularyRepository>();

  /// Get fake admin users repository
  static FakeAdminUsersRepository getAdminUsersRepository() =>
      _getIt<FakeAdminUsersRepository>();

  /// Get fake admin question bank repository
  static FakeAdminQuestionBankRepository getAdminQuestionBankRepository() =>
      _getIt<FakeAdminQuestionBankRepository>();

  /// Get fake admin question repository
  static FakeAdminQuestionRepository getAdminQuestionRepository() =>
      _getIt<FakeAdminQuestionRepository>();

  /// Get fake conversation repository
  static FakeConversationRepository getConversationRepository() =>
      _getIt<FakeConversationRepository>();

  /// Get fake sync repository
  static FakeSyncRepository getSyncRepository() => _getIt<FakeSyncRepository>();
}

/// Stub [SyncDataUseCase] that always returns success with zero items.
/// Cannot extend SyncDataUseCase because the constructor requires a real
/// SyncRepository. Instead we implement the UseCase interface directly.
class _FakeSyncDataUseCase extends SyncDataUseCase {
  _FakeSyncDataUseCase() : super(_FakeSyncRepository());

  @override
  Future<Either<Failure, SyncResponseEntity>> call(NoParams params) async {
    return const Right(SyncResponseEntity(syncedCount: 0, results: []));
  }
}

/// Stub [FullSyncUseCase] that always returns success with zero items.
class _FakeFullSyncUseCase extends FullSyncUseCase {
  _FakeFullSyncUseCase() : super(_FakeSyncRepository());

  @override
  Future<Either<Failure, SyncPushResponseEntity>> call(NoParams params) async {
    return const Right(
      SyncPushResponseEntity(succeededCount: 0, failedCount: 0, results: []),
    );
  }
}

/// Minimal fake SyncRepository to satisfy the use case constructors.
class _FakeSyncRepository implements SyncRepository {
  @override
  Future<Either<Failure, SyncResponseEntity>> syncVocabulary() async {
    return const Right(SyncResponseEntity(syncedCount: 0, results: []));
  }

  @override
  Future<Either<Failure, SyncPushResponseEntity>> fullSync() async {
    return const Right(
      SyncPushResponseEntity(succeededCount: 0, failedCount: 0, results: []),
    );
  }
}

/// Common test expectations and matchers
class E2ETestExpectations {
  /// Expect success message
  static void expectSuccessMessage(WidgetTester tester, String message) {
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  }

  /// Expect error message
  static void expectErrorMessage(WidgetTester tester, String message) {
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  }

  /// Expect loading indicator
  static void expectLoadingIndicator(WidgetTester tester) {
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  }

  /// Expect widget text
  static void expectText(WidgetTester tester, String text) {
    expect(find.text(text), findsOneWidget);
  }

  /// Expect button exists
  static void expectButton(WidgetTester tester, String buttonText) {
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ElevatedButton &&
            widget.child is Text &&
            (widget.child as Text).data == buttonText,
      ),
      findsOneWidget,
    );
  }

  /// Expect list item
  static void expectListItem(WidgetTester tester, String itemText) {
    expect(find.text(itemText), findsOneWidget);
  }

  /// Expect no error
  static void expectNoError(WidgetTester tester) {
    final snackBarFinder = find.byType(SnackBar);
    if (snackBarFinder.evaluate().isNotEmpty) {
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      if (snackBar.content is Text) {
        debugPrint(
          'DEBUG: SnackBar found with text: ${(snackBar.content as Text).data}',
        );
      } else {
        debugPrint(
          'DEBUG: SnackBar found but content is not Text: ${snackBar.content}',
        );
      }
    }
    expect(snackBarFinder, findsNothing);
  }
}

/// Test utilities for common operations
class E2ETestUtils {
  /// Wait for widget to appear
  static Future<void> waitForWidget(WidgetTester tester, Type widget) async {
    await tester.pumpAndSettle();
    int tries = 0;
    while (find.byType(widget).evaluate().isEmpty && tries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      tries++;
    }
  }

  /// Wait for text to appear
  static Future<void> waitForText(WidgetTester tester, String text) async {
    await tester.pumpAndSettle();
    int tries = 0;
    while (find.text(text).evaluate().isEmpty && tries < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      tries++;
    }
  }

  /// Tap button by text
  static Future<void> tapButton(WidgetTester tester, String text) async {
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();
  }

  /// Tap text
  static Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Enter text in text field
  static Future<void> enterText(
    WidgetTester tester,
    String hintText,
    String text,
  ) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pumpAndSettle();
  }

  /// Scroll to widget
  static Future<void> scrollToWidget(WidgetTester tester, Type widget) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(widget).first);
    await tester.pumpAndSettle();
  }

  /// Get text from widget
  static String getTextFromWidget(WidgetTester tester, String text) {
    final textWidget = find.text(text).evaluate().first.widget as Text;
    return textWidget.data ?? '';
  }

  /// Verify list contains text
  static bool listContainsText(WidgetTester tester, String text) {
    return find.text(text).evaluate().isNotEmpty;
  }

  /// Wait and verify
  static Future<void> waitAndVerify(
    WidgetTester tester,
    Future<void> Function() action,
    String expectedText,
  ) async {
    await action();
    await tester.pumpAndSettle();
    expect(find.text(expectedText), findsOneWidget);
  }
}

/// Screen navigation helpers
class E2EScreenNavigation {
  /// Navigate to login screen
  static Future<void> navigateToLogin(WidgetTester tester) async {
    await E2ETestUtils.waitForText(tester, 'Login');
  }

  /// Navigate to home screen after login
  static Future<void> navigateToHome(WidgetTester tester) async {
    await E2ETestUtils.waitForText(tester, 'Home');
  }

  /// Navigate to translation screen
  static Future<void> navigateToTranslation(WidgetTester tester) async {
    await E2ETestUtils.waitForWidget(tester, Text);
    // Find and tap translation nav item
    final translationButton = find.byTooltip('Dịch');
    if (translationButton.evaluate().isNotEmpty) {
      await tester.tap(translationButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to vocabulary screen
  static Future<void> navigateToVocabulary(WidgetTester tester) async {
    final vocabButton = find.byTooltip('Từ vựng');
    if (vocabButton.evaluate().isNotEmpty) {
      await tester.tap(vocabButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to conversation screen
  static Future<void> navigateToConversation(WidgetTester tester) async {
    final conversationButton = find.byTooltip('Hội thoại');
    if (conversationButton.evaluate().isNotEmpty) {
      await tester.tap(conversationButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to admin dashboard
  static Future<void> navigateToAdminDashboard(WidgetTester tester) async {
    await E2ETestUtils.waitForText(tester, 'Dashboard');
  }

  /// Navigate to admin users page
  static Future<void> navigateToAdminUsers(WidgetTester tester) async {
    final usersButton = find.byIcon(Icons.people_outline);
    if (usersButton.evaluate().isNotEmpty) {
      await tester.tap(usersButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to admin question banks
  static Future<void> navigateToAdminQuestionBanks(WidgetTester tester) async {
    final banksButton = find.byIcon(Icons.help_outline_rounded);
    if (banksButton.evaluate().isNotEmpty) {
      await tester.tap(banksButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to admin quiz editor
  static Future<void> navigateToAdminQuizEditor(WidgetTester tester) async {
    final editorButton = find.byIcon(Icons.quiz_rounded);
    if (editorButton.evaluate().isNotEmpty) {
      await tester.tap(editorButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to admin translation service-management page
  static Future<void> navigateToAdminTranslations(WidgetTester tester) async {
    final translationsButton = find.byIcon(Icons.translate_outlined);
    if (translationsButton.evaluate().isNotEmpty) {
      await tester.tap(translationsButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to admin analytics page
  static Future<void> navigateToAdminAnalytics(WidgetTester tester) async {
    final analyticsButton = find.byIcon(Icons.analytics_outlined);
    if (analyticsButton.evaluate().isNotEmpty) {
      await tester.tap(analyticsButton);
      await tester.pumpAndSettle();
    }
  }
}

/// Auth flow helpers
class E2EAuthFlow {
  /// Navigate past the splash screen to the welcome/login page.
  /// The splash has a 2500ms animation + 1000ms delay + health check.
  static Future<void> _navigatePastSplash(WidgetTester tester) async {
    // Pump through the splash animation (2500ms) + linger delay (1000ms)
    // + health check timeout. We pump in increments to advance timers.
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
  }

  /// Navigate from the Welcome page to the Login page.
  /// The Welcome page has 3 slides; the Login button is on slide 3.
  static Future<void> _navigateToLoginPage(WidgetTester tester) async {
    // Tap "Skip" to jump to the last slide
    final skipButton = find.text('Skip');
    if (skipButton.evaluate().isNotEmpty) {
      await tester.tap(skipButton);
      // Wait for the page controller to animate to page 2 (takes 600ms)
      await tester.pumpAndSettle();
    }

    // Now find the Login button. Because of PageView caching, we might have multiple
    // "Login" buttons in the tree. We want the one that is hit-testable (not ignored).
    // The active one is the one on the 3rd slide (index 2).
    final loginButtonFinder = find.widgetWithText(OutlinedButton, 'Login');
    if (loginButtonFinder.evaluate().isNotEmpty) {
      await tester.tap(loginButtonFinder.last);
      await tester.pumpAndSettle();
    }
  }

  /// Login with credentials.
  /// Handles both flows: user flow (splash → welcome → login) and admin flow (direct login page).
  static Future<void> login(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    // Set screen size to prevent overflow or off-screen tap errors
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;

    // We must call pumpAndSettle to propagate the viewport change and let GoRouter settle before checking for page type
    await tester.pumpAndSettle();

    final isAdminPage = find.byType(AdminLoginPage).evaluate().isNotEmpty;

    if (!isAdminPage) {
      // Navigate past splash screen
      await _navigatePastSplash(tester);

      // Navigate from welcome to login page
      await _navigateToLoginPage(tester);
    }

    // Wait for login page to render
    await tester.pumpAndSettle();

    // Find TextFormFields (login page uses TextFormField, not TextField)
    final textFormFields = find.byType(TextFormField);
    expect(
      textFormFields,
      findsAtLeastNWidgets(2),
      reason: 'Expected at least two TextFormFields on the login page',
    );

    // Enter email
    await tester.enterText(textFormFields.at(0), email);
    await tester.pumpAndSettle();

    // Enter password
    await tester.enterText(textFormFields.at(1), password);
    await tester.pumpAndSettle();

    // Tap login button (Sign In)
    if (isAdminPage) {
      final signInButton = find.text('Sign In to Dashboard');
      expect(signInButton, findsOneWidget);
      await tester.tap(signInButton);
    } else {
      final signInButton = find.byType(ElevatedButton).first;
      await tester.tap(signInButton);
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  /// Login as admin
  static Future<void> loginAsAdmin(WidgetTester tester) async {
    await login(
      tester,
      E2ETestSeedData.adminUser['email'] as String,
      'password123',
    );
  }

  /// Login as regular user
  static Future<void> loginAsUser(WidgetTester tester) async {
    await login(
      tester,
      E2ETestSeedData.regularUser['email'] as String,
      'password123',
    );
  }

  /// Logout
  static Future<void> logout(WidgetTester tester) async {
    final settingsButton = find.byIcon(Icons.settings);
    if (settingsButton.evaluate().isNotEmpty) {
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      final logoutButton = find.text('Đăng xuất');
      if (logoutButton.evaluate().isNotEmpty) {
        await tester.tap(logoutButton);
        await tester.pumpAndSettle();
      }
      return;
    }

    final avatarButton = find.byTooltip('Tài khoản');
    if (avatarButton.evaluate().isNotEmpty) {
      await tester.tap(avatarButton);
      await tester.pumpAndSettle();

      final logoutItem = find.text('Đăng xuất');
      if (logoutItem.evaluate().isNotEmpty) {
        await tester.tap(logoutItem);
        await tester.pumpAndSettle();
      }
      return;
    }
  }
}
