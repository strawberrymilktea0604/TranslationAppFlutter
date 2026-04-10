import 'package:get_it/get_it.dart';

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
  //  Core
  // ==============================
  // TODO: Register NetworkInfo, HttpClient, Isar, SecureStorage
  // sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(...));

  // ==============================
  //  Feature: Auth
  // ==============================
  // DataSources
  // sl.registerLazySingleton<AuthRemoteDataSource>(
  //   () => AuthRemoteDataSourceImpl(client: sl()),
  // );
  // sl.registerLazySingleton<AuthLocalDataSource>(
  //   () => AuthLocalDataSourceImpl(secureStorage: sl()),
  // );

  // Repository
  // sl.registerLazySingleton<AuthRepository>(
  //   () => AuthRepositoryImpl(
  //     remoteDataSource: sl(),
  //     localDataSource: sl(),
  //     networkInfo: sl(),
  //   ),
  // );

  // UseCases
  // sl.registerLazySingleton(() => LoginUseCase(sl()));
  // sl.registerLazySingleton(() => RegisterUseCase(sl()));

  // Cubits
  // sl.registerFactory(() => AuthCubit(
  //   loginUseCase: sl(),
  //   registerUseCase: sl(),
  // ));

  // ==============================
  //  Feature: Translation
  // ==============================
  // DataSources
  // sl.registerLazySingleton<TranslationRemoteDataSource>(...);
  // sl.registerLazySingleton<TranslationLocalDataSource>(...);

  // Repository
  // sl.registerLazySingleton<TranslationRepository>(...);

  // UseCases
  // sl.registerLazySingleton(() => TranslateTextUseCase(sl()));

  // Cubits
  // sl.registerFactory(() => TranslationCubit(sl()));

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
