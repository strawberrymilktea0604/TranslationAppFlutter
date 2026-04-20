import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/core/network/bloc/network_cubit.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/login_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/register_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/check_email_usecase.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';

import 'main.dart' show config;

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
  sl.registerLazySingleton<NetworkCubit>(
    () => NetworkCubit(networkInfo: sl()),
  );

  // Secure storage — encrypted Keychain (iOS) /
  // EncryptedSharedPreferences (Android).
  // JWT tokens MUST be stored here, NEVER in SharedPreferences.
  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(),
  );

  // ==============================
  //  Feature: Auth
  // ==============================

  // DataSources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(secureStorage: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      client: sl(),
      baseUrl: config.apiUrl,
    ),
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

  // Cubits — registered as factory (new instance per provider).
  sl.registerFactory(() => AuthCubit(
        loginUseCase: sl(),
        registerUseCase: sl(),
        logoutUseCase: sl(),
        getCurrentUserUseCase: sl(),
        checkEmailUseCase: sl(),
      ));

  // ==============================
  //  Feature: Translation
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: Vocabulary
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: History
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: Speech (STT)
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: OCR
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: Sync
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits
}
