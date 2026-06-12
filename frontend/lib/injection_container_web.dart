// ignore_for_file: duplicate_ignore
// Web-specific dependency injection.
// Mirrors injection_container.dart but replaces all Isar-backed local
// datasources with lightweight Web stubs (no offline DB on web).

import 'package:http/http.dart' as http;

import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/core/network/bloc/network_cubit.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/core/tts/tts_service.dart';
import 'package:frontend/core/tts/bloc/tts_cubit.dart';
import 'package:frontend/core/image_picker/image_picker_service.dart';
import 'package:frontend/core/image_picker/image_compress_service.dart';
import 'package:frontend/core/audio_recorder/audio_recorder_service.dart';
import 'package:frontend/core/audio_recorder/bloc/recording_cubit.dart';
import 'package:frontend/core/image_picker/image_crop_service.dart';
import 'package:frontend/core/database/web_stub_datasources.dart';

import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository_impl.dart';
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

import 'package:frontend/features/translation/data/datasources/translation_remote_datasource.dart';
import 'package:frontend/features/translation/data/repositories/translation_repository_impl.dart';
import 'package:frontend/features/translation/domain/repositories/translation_repository.dart';
import 'package:frontend/features/translation/domain/usecases/translate_text_usecase.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_cubit.dart';

import 'package:frontend/features/vocabulary/data/datasources/vocabulary_local_datasource.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_remote_datasource.dart';
import 'package:frontend/features/vocabulary/data/repositories/vocabulary_repository_impl.dart';
import 'package:frontend/features/vocabulary/domain/repositories/vocabulary_repository.dart';
import 'package:frontend/features/vocabulary/domain/usecases/save_vocabulary_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/get_vocabulary_list_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/delete_vocabulary_usecase.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_category_local_datasource.dart';
import 'package:frontend/features/vocabulary/data/datasources/vocabulary_category_remote_datasource.dart';
import 'package:frontend/features/vocabulary/data/repositories/vocabulary_category_repository_impl.dart';
import 'package:frontend/features/vocabulary/domain/repositories/vocabulary_category_repository.dart';
import 'package:frontend/features/vocabulary/domain/usecases/get_categories_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/create_category_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/update_category_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/delete_category_usecase.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_category_cubit.dart';

import 'package:frontend/features/history/data/datasources/history_local_datasource.dart';
import 'package:frontend/features/history/data/repositories/history_repository_impl.dart';
import 'package:frontend/features/history/domain/repositories/history_repository.dart';
import 'package:frontend/features/history/domain/usecases/get_history_usecase.dart';
import 'package:frontend/features/history/presentation/bloc/history_cubit.dart';

import 'package:frontend/features/ocr/data/datasources/ocr_remote_datasource.dart';
import 'package:frontend/features/ocr/data/repositories/ocr_repository_impl.dart';
import 'package:frontend/features/ocr/domain/repositories/ocr_repository.dart';
import 'package:frontend/features/ocr/domain/usecases/ocr_translate_usecase.dart';
import 'package:frontend/features/ocr/domain/usecases/retranslate_ocr_text_usecase.dart';
import 'package:frontend/features/ocr/presentation/bloc/ocr_cubit.dart';

import 'package:frontend/features/speech/data/datasources/speech_remote_datasource.dart';
import 'package:frontend/features/speech/data/repositories/speech_repository_impl.dart';
import 'package:frontend/features/speech/domain/repositories/speech_repository.dart';
import 'package:frontend/features/speech/domain/usecases/speech_to_text_usecase.dart';
import 'package:frontend/features/speech/domain/usecases/retranslate_voice_text_usecase.dart';
import 'package:frontend/features/speech/presentation/bloc/speech_cubit.dart';

import 'package:frontend/features/sync/data/datasources/sync_remote_datasource.dart';
import 'package:frontend/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:frontend/features/sync/domain/repositories/sync_repository.dart';
import 'package:frontend/features/sync/domain/usecases/sync_data_usecase.dart';
import 'package:frontend/features/sync/presentation/bloc/sync_cubit.dart';

import 'package:frontend/features/learning/data/repositories/learning_repository_impl.dart';
import 'package:frontend/features/learning/domain/repositories/learning_repository.dart';
import 'package:frontend/features/learning/domain/usecases/get_learning_summary_usecase.dart';
import 'package:frontend/features/learning/domain/usecases/get_question_banks_usecase.dart';
import 'package:frontend/features/learning/domain/usecases/get_recent_quiz_results_usecase.dart';
import 'package:frontend/features/learning/presentation/bloc/learning_dashboard_cubit.dart';
import 'package:frontend/features/learning/data/datasources/quiz_remote_datasource.dart';
import 'package:frontend/features/learning/data/repositories/quiz_repository_impl.dart';
import 'package:frontend/features/learning/domain/repositories/quiz_repository.dart';
import 'package:frontend/features/learning/domain/usecases/get_quiz_questions_usecase.dart';
import 'package:frontend/features/learning/domain/usecases/submit_quiz_result_usecase.dart';
import 'package:frontend/features/learning/presentation/bloc/quiz_cubit.dart';

import 'package:frontend/core/network/services/realtime_sync_service.dart';

import 'package:frontend/features/conversation/data/datasources/conversation_remote_datasource.dart';
import 'package:frontend/features/conversation/data/repositories/conversation_repository_impl.dart';
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:frontend/features/conversation/domain/usecases/connect_conversation_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/start_session_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/send_audio_chunk_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/end_session_usecase.dart';
import 'package:frontend/features/conversation/domain/usecases/switch_speaker_usecase.dart';
import 'package:frontend/features/conversation/presentation/bloc/conversation_viewmodel.dart';

import 'injection_container.dart' show sl;
import 'main.dart' show config;

/// Initializes all dependencies for the Web/Admin platform.
/// Isar-backed local datasources are replaced with no-op Web stubs.
Future<void> initDependenciesWeb() async {
  // ==============================
  //  Core — External Services
  // ==============================

  sl.registerLazySingleton<http.Client>(() => http.Client());

  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(
      client: sl(),
      healthUri: backendHealthUri(config.apiUrl),
    ),
  );

  sl.registerLazySingleton<NetworkCubit>(() => NetworkCubit(networkInfo: sl()));

  sl.registerLazySingleton<RealtimeSyncService>(
    () => RealtimeSyncService(baseApiUrl: config.apiUrl),
  );

  sl.registerLazySingleton<SecureStorageService>(() => SecureStorageService());

  sl.registerLazySingleton<TtsService>(() => TtsServiceImpl());
  sl.registerLazySingleton<TtsCubit>(() => TtsCubit(ttsService: sl()));

  sl.registerLazySingleton<ImagePickerService>(() => ImagePickerServiceImpl());
  sl.registerLazySingleton<ImageCompressService>(
    () => const ImageCompressServiceImpl(),
  );
  sl.registerLazySingleton<ImageCropService>(() => ImageCropServiceImpl());
  sl.registerLazySingleton<AudioRecorderService>(
    () => AudioRecorderServiceImpl(),
  );
  sl.registerFactory<RecordingCubit>(
    () => RecordingCubit(recorderService: sl()),
  );

  // ==============================
  //  Feature: Auth
  // ==============================

  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(secureStorage: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => CheckEmailUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl()));
  sl.registerLazySingleton(() => ChangePasswordUseCase(sl()));
  sl.registerLazySingleton(() => UploadAvatarUseCase(sl()));

  sl.registerFactory(
    () => AuthCubit(
      loginUseCase: sl(),
      registerUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
      checkEmailUseCase: sl(),
      updateProfileUseCase: sl(),
      changePasswordUseCase: sl(),
      uploadAvatarUseCase: sl(),
    ),
  );

  // ==============================
  //  Feature: Translation
  // ==============================

  sl.registerLazySingleton<TranslationRemoteDataSource>(
    () => TranslationRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );
  sl.registerLazySingleton<TranslationRepository>(
    () => TranslationRepositoryImpl(
      remoteDataSource: sl(),
      authLocalDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton(() => TranslateTextUseCase(sl()));
  sl.registerFactory(() => TranslationCubit(sl()));

  // ==============================
  //  Feature: Vocabulary — Web stubs (no Isar)
  // ==============================

  sl.registerLazySingleton<VocabularyLocalDataSource>(
    () => const WebVocabularyLocalDataSource(),
  );
  sl.registerLazySingleton<VocabularyRemoteDataSource>(
    () => VocabularyRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );
  sl.registerLazySingleton<VocabularyRepository>(
    () => VocabularyRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton(() => SaveVocabularyUseCase(sl()));
  sl.registerLazySingleton(() => GetVocabularyListUseCase(sl()));
  sl.registerLazySingleton(() => DeleteVocabularyUseCase(sl()));
  sl.registerLazySingleton(() => GetCategorySummariesUseCase(sl()));

  // ==============================
  //  Vocabulary Category — Web stub
  // ==============================

  sl.registerLazySingleton<VocabularyCategoryLocalDataSource>(
    () => const WebVocabularyCategoryLocalDataSource(),
  );
  sl.registerLazySingleton<VocabularyCategoryRemoteDataSource>(
    () => VocabularyCategoryRemoteDataSourceImpl(
      client: sl(),
      baseUrl: config.apiUrl,
    ),
  );
  sl.registerLazySingleton<VocabularyCategoryRepository>(
    () => VocabularyCategoryRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      networkInfo: sl(),
      authLocalDataSource: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => CreateCategoryUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCategoryUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCategoryUseCase(sl()));
  sl.registerFactory(
    () => VocabularyCategoryCubit(
      getCategoriesUseCase: sl(),
      createCategoryUseCase: sl(),
      updateCategoryUseCase: sl(),
      deleteCategoryUseCase: sl(),
    ),
  );
  sl.registerFactory(
    () => VocabularyCubit(
      saveVocabularyUseCase: sl(),
      getVocabularyListUseCase: sl(),
      deleteVocabularyUseCase: sl(),
    ),
  );

  // ==============================
  //  Feature: History — Web stub
  // ==============================

  sl.registerLazySingleton<HistoryLocalDataSource>(
    () => const WebHistoryLocalDataSource(),
  );
  sl.registerLazySingleton<HistoryRepository>(
    () => HistoryRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetHistoryUseCase(sl()));
  sl.registerLazySingleton(() => DeleteHistoryUseCase(sl()));
  sl.registerLazySingleton(() => ClearHistoryUseCase(sl()));
  sl.registerFactory(
    () => HistoryCubit(
      getHistoryUseCase: sl(),
      deleteHistoryUseCase: sl(),
      clearHistoryUseCase: sl(),
    ),
  );

  // ==============================
  //  Feature: Speech (STT)
  // ==============================

  sl.registerLazySingleton<SpeechRemoteDataSource>(
    () => SpeechRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );
  sl.registerLazySingleton<SpeechRepository>(
    () => SpeechRepositoryImpl(
      speechRemoteDataSource: sl(),
      translationRemoteDataSource: sl(),
      authLocalDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton(() => SpeechTranslateUseCase(sl()));
  sl.registerLazySingleton(() => RetranslateVoiceTextUseCase(sl()));
  sl.registerFactory(
    () => SpeechCubit(speechTranslateUseCase: sl(), retranslateUseCase: sl()),
  );

  // ==============================
  //  Feature: OCR
  // ==============================

  sl.registerLazySingleton<OcrRemoteDataSource>(
    () => OcrRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );
  sl.registerLazySingleton<OcrRepository>(
    () => OcrRepositoryImpl(
      ocrRemoteDataSource: sl(),
      translationRemoteDataSource: sl(),
      authLocalDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton(() => OcrTranslateUseCase(sl()));
  sl.registerLazySingleton(() => RetranslateOcrTextUseCase(sl()));
  sl.registerFactory(
    () => OcrCubit(
      ocrTranslateUseCase: sl(),
      retranslateUseCase: sl(),
      imagePickerService: sl(),
      imageCompressService: sl(),
      imageCropService: sl(),
    ),
  );

  // ==============================
  //  Feature: Sync
  // ==============================

  sl.registerLazySingleton<SyncRemoteDataSource>(
    () => SyncRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );
  sl.registerLazySingleton<SyncRepository>(
    () => SyncRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      syncLocalDataSource: sl(),
      vocabularyRemoteDataSource: sl(),
      authLocalDataSource: sl(),
    ),
  );
  sl.registerLazySingleton(() => SyncDataUseCase(sl()));
  sl.registerLazySingleton(
    () => SyncCubit(
      syncDataUseCase: sl(),
      fullSyncUseCase: sl(),
      networkCubit: sl(),
      realtimeSyncService: sl(),
    ),
  );

  // ==============================
  //  Feature: Learning Dashboard
  // ==============================

  sl.registerLazySingleton<LearningRepository>(
    () => LearningRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      authLocalDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetLearningSummaryUseCase(sl()));
  sl.registerLazySingleton(() => GetQuestionBanksUseCase(sl()));
  sl.registerLazySingleton(() => GetRecentQuizResultsUseCase(sl()));
  sl.registerFactory(
    () => LearningDashboardCubit(
      getLearningSummaryUseCase: sl(),
      getQuestionBanksUseCase: sl(),
      getCategorySummariesUseCase: sl(),
      getRecentQuizResultsUseCase: sl(),
    ),
  );

  // ==============================
  //  Feature: Quiz Engine
  // ==============================

  sl.registerLazySingleton<QuizRemoteDataSource>(
    () => QuizRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );
  sl.registerLazySingleton<QuizRepository>(
    () => QuizRepositoryImpl(
      remoteDataSource: sl(),
      authLocalDataSource: sl(),
      networkInfo: sl(),
      localDataSource: sl(),
    ),
  );
  sl.registerLazySingleton(() => GetQuizQuestionsUseCase(sl()));
  sl.registerLazySingleton(() => SubmitQuizResultUseCase(sl()));
  sl.registerFactory(
    () =>
        QuizCubit(getQuizQuestionsUseCase: sl(), submitQuizResultUseCase: sl()),
  );

  // ==============================
  //  Feature: Conversation
  // ==============================

  sl.registerLazySingleton<ConversationRemoteDataSource>(
    () => ConversationRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<ConversationRepository>(
    () =>
        ConversationRepositoryImpl(dataSource: sl(), baseApiUrl: config.apiUrl),
  );
  sl.registerLazySingleton(() => ConnectConversationUseCase(sl()));
  sl.registerLazySingleton(() => StartSessionUseCase(sl()));
  sl.registerLazySingleton(() => SendAudioChunkUseCase(sl()));
  sl.registerLazySingleton(() => EndSessionUseCase(sl()));
  sl.registerLazySingleton(() => SwitchSpeakerUseCase(sl()));
  sl.registerFactory(
    () => ConversationViewModel(
      connectUseCase: sl(),
      startSessionUseCase: sl(),
      sendAudioChunkUseCase: sl(),
      switchSpeakerUseCase: sl(),
      endSessionUseCase: sl(),
      repository: sl(),
      authLocalDataSource: sl(),
      audioRecorderService: sl(),
      historyRepository: sl(),
    ),
  );
}
