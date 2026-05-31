

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/app_config.dart';
import 'package:frontend/core/router/admin_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/bloc/tts_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/core/network/bloc/network_cubit.dart';
import 'package:frontend/features/sync/presentation/bloc/sync_cubit.dart';
import 'package:frontend/injection_container.dart' show sl;
import 'package:frontend/injection_container_web.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/main.dart' show config;

/// Web entry point for the Translation Admin Dashboard
///
/// NOTE: Isar 3.x does NOT support Flutter Web.
/// All local datasources (Vocabulary, History) are replaced with
/// no-op Web stubs — data comes exclusively from the backend API.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _configureWebRenderer();

  // Initialize config for web environment
  config = const AppConfig(
    appName: 'Translation Admin',
    apiUrl: 'http://localhost:8000/api/v1',
  );

  // Initialize all dependencies — Web version (no Isar)
  await initDependenciesWeb();

  runApp(const AdminApp());
}

/// Configures the web renderer
/// Uses CanvasKit for better performance and compatibility
void _configureWebRenderer() {
  // Force CanvasKit renderer for consistent rendering across browsers
  // CanvasKit provides better:
  // - Performance on complex UIs
  // - Text rendering consistency
  // - Shader support
  // - Stability across different browsers
  
  // This is set via URL parameter: ?canvaskit=true or in web/index.html
  // For production, configure in pubspec.yaml:
  // flutter_web:
  //   renderer: canvaskit  # or 'html'
  
  // You can also check at runtime:
  debugPrint('Web Renderer check skipped to avoid dart:html dependency');
}

/// Root widget for Admin Dashboard
/// Web-specific configuration for admin interface
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => sl<AuthCubit>()..checkAuthStatus(isAdminApp: true),
        ),
        BlocProvider<NetworkCubit>(create: (_) => sl<NetworkCubit>()),
        BlocProvider<TtsCubit>(create: (_) => sl<TtsCubit>()),
        BlocProvider<SyncCubit>(create: (_) => sl<SyncCubit>()),
      ],
      child: const _AdminAppWithRouter(),
    );
  }
}

/// Separated widget to access AuthCubit from context
class _AdminAppWithRouter extends StatefulWidget {
  const _AdminAppWithRouter();

  @override
  State<_AdminAppWithRouter> createState() => _AdminAppWithRouterState();
}

class _AdminAppWithRouterState extends State<_AdminAppWithRouter> {
  late final GoRouter _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router = createAdminRouter(context);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) {
        return AppLocalizations.of(context)?.appTitle ?? 'Translation Admin';
      },
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // TODO: Add theme preference to settings
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('vi', ''),
      ],
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
