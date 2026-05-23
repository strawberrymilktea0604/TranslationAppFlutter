import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/app_config.dart';
import 'package:frontend/core/database/isar_database.dart';
import 'package:frontend/core/router/admin_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/bloc/tts_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/core/network/bloc/network_cubit.dart';
import 'package:frontend/features/sync/presentation/bloc/sync_cubit.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/main.dart' show isarDatabase, GoRouterRefreshStream;

/// Web entry point for the Translation Admin Dashboard
/// 
/// Configuration:
/// - Uses CanvasKit renderer for better performance and rendering consistency
/// - Optimized layout for desktop/tablet screens
/// - Admin-only routing
/// - Supports both light and dark themes

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure CanvasKit renderer for web
  _configureWebRenderer();

  // Initialize Isar database (shared with mobile)
  isarDatabase = IsarDatabase();
  await isarDatabase.init();

  // Initialize config for web environment
  config = const AppConfig(
    appName: 'Translation Admin',
    apiUrl: 'http://localhost:8000/api/v1',
  );

  // Initialize all dependencies (GetIt)
  await initDependencies();

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
  final renderer = html.window.localStorage['flutter.renderer'] ?? 'canvaskit';
  debugPrint('Web Renderer: $renderer');
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
          create: (_) => sl<AuthCubit>()..checkAuthStatus(),
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
