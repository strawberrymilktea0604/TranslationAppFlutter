import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/database/isar_database.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/core/network/bloc/network_cubit.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/l10n/app_localizations.dart';

import 'app_config.dart';

late AppConfig config;
late IsarDatabase isarDatabase;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Isar database.
  isarDatabase = IsarDatabase();
  await isarDatabase.init();

  // Initialize config if not already initialized.
  // Config is usually set in main_dev.dart / main_prod.dart
  // before calling this function.
  try {
    config;
  } catch (e) {
    config = const AppConfig(
      appName: 'Translation App',
      apiUrl: 'http://localhost:8000/api/v1',
    );
  }

  // Initialize all dependencies (GetIt).
  await initDependencies();

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
          create: (_) => sl<AuthCubit>()..checkAuthStatus(),
        ),
        BlocProvider<NetworkCubit>(create: (_) => sl<NetworkCubit>()),
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
