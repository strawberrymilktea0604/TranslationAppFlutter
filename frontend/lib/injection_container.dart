import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

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
import 'package:frontend/features/vocabulary/data/repositories/vocabulary_repository_impl.dart';
import 'package:frontend/features/vocabulary/domain/repositories/vocabulary_repository.dart';
import 'package:frontend/features/vocabulary/domain/usecases/save_vocabulary_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/get_vocabulary_list_usecase.dart';
import 'package:frontend/features/vocabulary/domain/usecases/delete_vocabulary_usecase.dart';
import 'package:frontend/features/vocabulary/presentation/bloc/vocabulary_cubit.dart';
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

import 'main.dart' show config, isarDatabase;

/// Global service locator instance for Dependency Injection.
/// Use get_it to register and resolve dependencies.
///
/// Registration follows Clean Architecture layer order:
/// 1. External services (network, DB, secure storage)
/// 2. DataSources (Remote & Local)
/// 3. Repositories (bind implementation to abstract interface)
/// 4. UseCases
/// 5. Cubits/Blocs
final sl = GetIt.instance;

/// Initializes all dependencies.
/// Must be called before runApp() in main.dart.
Future<void> initDependencies() async {
  // ==============================
  //  Core — External Services
  // ==============================

  // HTTP client for REST API calls.
  sl.registerLazySingleton<http.Client>(() => http.Client());

  // Network connectivity checker — verifies real internet access.
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(InternetConnection()),
  );

  // Global network connectivity state
  sl.registerLazySingleton<NetworkCubit>(() => NetworkCubit(networkInfo: sl()));

  // Secure storage — encrypted Keychain (iOS) /
  // EncryptedSharedPreferences (Android).
  // JWT tokens MUST be stored here, NEVER in SharedPreferences.
  sl.registerLazySingleton<SecureStorageService>(() => SecureStorageService());

  // Text-to-Speech engine — shared singleton so only one voice
  // plays at a time across the entire app.
  sl.registerLazySingleton<TtsService>(() => TtsServiceImpl());
  sl.registerLazySingleton<TtsCubit>(
    () => TtsCubit(ttsService: sl()),
  );

  // Image picker — wraps the image_picker plugin behind an interface
  // so Cubits/UseCases don't depend on the Flutter plugin directly.
  sl.registerLazySingleton<ImagePickerService>(
    () => ImagePickerServiceImpl(),
  );

  // Image compression — wraps flutter_image_compress behind an interface.
  sl.registerLazySingleton<ImageCompressService>(
    () => const ImageCompressServiceImpl(),
  );

  // Image cropping — wraps image_cropper behind an interface.
  // Allows user to select text region in a photo before OCR (UC06).
  sl.registerLazySingleton<ImageCropService>(
    () => ImageCropServiceImpl(),
  );

  // Audio recorder — wraps the `record` plugin behind an interface
  // so Cubits/UseCases don't depend on the Flutter plugin directly.
  // Required for speech-to-text feature (UC05).
  sl.registerLazySingleton<AudioRecorderService>(
    () => AudioRecorderServiceImpl(),
  );
  sl.registerFactory<RecordingCubit>(
    () => RecordingCubit(recorderService: sl()),
  );

  // ==============================
  //  Feature: Auth
  // ==============================

  // DataSources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(secureStorage: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );

  // Repository — binds implementation to abstract interface.
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // UseCases — one use case = one business action.
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => CheckEmailUseCase(sl()));

  sl.registerLazySingleton(() => UpdateProfileUseCase(sl()));
  sl.registerLazySingleton(() => ChangePasswordUseCase(sl()));
  sl.registerLazySingleton(() => UploadAvatarUseCase(sl()));

  // Cubits — registered as factory (new instance per provider).
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

  // Factory: new cubit per screen/widget that provides it.
  sl.registerFactory(() => TranslationCubit(sl()));

  // ==============================
  //  Feature: Vocabulary (UC07 — Offline-first with Isar)
  // ==============================

  // DataSource — local Isar DB only (offline-first).
  sl.registerLazySingleton<VocabularyLocalDataSource>(
    () => VocabularyLocalDataSourceImpl(isar: isarDatabase.isar),
  );

  // Repository — all operations go through local Isar DB.
  sl.registerLazySingleton<VocabularyRepository>(
    () => VocabularyRepositoryImpl(localDataSource: sl()),
  );

  // UseCases
  sl.registerLazySingleton(() => SaveVocabularyUseCase(sl()));
  sl.registerLazySingleton(() => GetVocabularyListUseCase(sl()));
  sl.registerLazySingleton(() => DeleteVocabularyUseCase(sl()));

  // Cubit — factory: new instance per screen that provides it.
  sl.registerFactory(() => VocabularyCubit(
    saveVocabularyUseCase: sl(),
    getVocabularyListUseCase: sl(),
    deleteVocabularyUseCase: sl(),
  ));

  // ==============================
  //  Feature: History
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: Speech (STT)
  // ==============================

  // DataSource
  sl.registerLazySingleton<SpeechRemoteDataSource>(
    () => SpeechRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );

  // Repository — binds implementation to abstract interface.
  sl.registerLazySingleton<SpeechRepository>(
    () => SpeechRepositoryImpl(
      speechRemoteDataSource: sl(),
      translationRemoteDataSource: sl(),
      authLocalDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => SpeechTranslateUseCase(sl()));
  sl.registerLazySingleton(() => RetranslateVoiceTextUseCase(sl()));

  // Cubit — factory: new instance per screen that provides it.
  sl.registerFactory(() => SpeechCubit(
    speechTranslateUseCase: sl(),
    retranslateUseCase: sl(),
  ));

  // ==============================
  //  Feature: OCR
  // ==============================

  // DataSource
  sl.registerLazySingleton<OcrRemoteDataSource>(
    () => OcrRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );

  // Repository — binds implementation to abstract interface.
  sl.registerLazySingleton<OcrRepository>(
    () => OcrRepositoryImpl(
      ocrRemoteDataSource: sl(),
      translationRemoteDataSource: sl(),
      authLocalDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => OcrTranslateUseCase(sl()));
  sl.registerLazySingleton(() => RetranslateOcrTextUseCase(sl()));

  // Cubit — factory: new instance per screen that provides it.
  sl.registerFactory(() => OcrCubit(
    ocrTranslateUseCase: sl(),
    retranslateUseCase: sl(),
    imagePickerService: sl(),
    imageCompressService: sl(),
    imageCropService: sl(),
  ));

  // ==============================
  //  Feature: Sync
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits
}
