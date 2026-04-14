import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/auth/domain/entities/user_entity.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/domain/usecases/login_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/register_usecase.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/core/database/isar_database.dart';
import 'app_config.dart';

late AppConfig config;
late IsarDatabase isarDatabase;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Isar database
  isarDatabase = IsarDatabase();
  await isarDatabase.init();

  // TODO: Initialize dependencies after packages are added.
  // await initDependencies();

  // TODO: Initialize BlocObserver for global state observation.
  // Bloc.observer = AppBlocObserver();

  // Initialize config if not already initialized
  // This is a workaround since config is usually initialized in main_dev.dart etc.
  try {
    config;
  } catch (e) {
    config = const AppConfig(
      appName: 'Translation App',
      apiUrl: 'http://localhost:8000/api/v1',
    );
  }

  runApp(const MyApp());
}

/// Root widget of the application.
/// Global ReadCubits are provided here at the app level.
/// WriteCubits are scoped per-feature at their respective pages.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide global ReadCubits at the app level
    // so they are accessible throughout the widget tree.
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(
            // TODO: Replace with real use cases from DI
            // once injection_container is fully wired.
            // Example: loginUseCase: sl<LoginUseCase>(),
            loginUseCase: _StubLoginUseCase(),
            registerUseCase: _StubRegisterUseCase(),
          ),
        ),
      ],
      child: const _AppWithRouter(),
    );
  }
}

/// Separated widget to access AuthCubit from context
/// after it has been provided by MultiBlocProvider.
class _AppWithRouter extends StatefulWidget {
  const _AppWithRouter();

  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

class _AppWithRouterState extends State<_AppWithRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router = createRouter(context);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) {
        return AppLocalizations.of(context)?.appTitle ?? config.appName;
      },
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('vi'), // Vietnamese
      ],
    );
  }
}

// =============================================================
// Temporary stubs — Remove once DI is fully wired.
// These allow the app to run and test the navigation flow
// without real backend connections.
// =============================================================

/// Stub [AuthRepository] that always returns success.
class _StubAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    return Right(UserEntity(
      id: 'stub',
      email: email,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    return Right(UserEntity(
      id: 'stub',
      email: email,
      name: name,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, void>> logout() async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    return const Left(AuthFailure('Not implemented'));
  }

  @override
  Future<Either<Failure, void>> refreshToken() async {
    return const Left(AuthFailure('Not implemented'));
  }
}

/// Stub [LoginUseCase] that simulates a successful login
/// after a 1-second delay.
class _StubLoginUseCase extends LoginUseCase {
  _StubLoginUseCase() : super(_StubAuthRepository());

  @override
  Future<Either<Failure, UserEntity>> call(
    LoginParams params,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    return Right(UserEntity(
      id: 'stub-user-id',
      email: params.email,
      name: 'Người dùng',
      createdAt: DateTime.now(),
    ));
  }
}

/// Stub [RegisterUseCase] that simulates a successful registration
/// after a 1-second delay.
class _StubRegisterUseCase extends RegisterUseCase {
  _StubRegisterUseCase() : super(_StubAuthRepository());

  @override
  Future<Either<Failure, UserEntity>> call(
    RegisterParams params,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    return Right(UserEntity(
      id: 'stub-user-id',
      email: params.email,
      name: params.name,
      createdAt: DateTime.now(),
    ));
  }
}