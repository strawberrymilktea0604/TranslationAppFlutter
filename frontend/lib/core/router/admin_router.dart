import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:frontend/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:frontend/features/admin/presentation/pages/admin_users_page.dart';
import 'package:frontend/features/admin/presentation/pages/admin_question_bank_page.dart';
import 'package:frontend/features/admin/presentation/pages/admin_quiz_editor_page.dart';
import 'package:frontend/features/admin/presentation/pages/admin_translations_page.dart';
import 'package:frontend/features/admin/presentation/pages/admin_analytics_page.dart';
import 'package:frontend/features/admin/presentation/pages/admin_login_page.dart';
import 'package:frontend/features/admin/presentation/pages/admin_settings_page.dart';

/// Admin Route paths
class AdminRoutes {
  AdminRoutes._();

  static const String login = '/login';
  static const String dashboard = '/admin/dashboard';
  static const String users = '/admin/users';
  static const String questionBank = '/admin/question-bank';
  static const String quizEditor = '/admin/quiz-editor';
  static const String translations = '/admin/translations';
  static const String analytics = '/admin/analytics';
  static const String settings = '/admin/settings';
}

/// Creates and configures the Admin router.
/// This router is separate from the main app router.
/// Used for web admin dashboard interface.
GoRouter createAdminRouter(BuildContext context) {
  return GoRouter(
    initialLocation: AdminRoutes.login,
    debugLogDiagnostics: true,

    /// Admin redirect logic — only authenticated users can access /admin/* routes.
    redirect: (BuildContext context, GoRouterState state) {
      final authState = context.read<AuthCubit>().state;
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoading = authState is AuthInitial || authState is AuthInProgress;
      final isOnLogin = state.matchedLocation == AdminRoutes.login;

      // Wait until auth check completes
      if (isLoading) return null;

      // Not authenticated → go to login
      if (!isAuthenticated && !isOnLogin) return AdminRoutes.login;

      // Already authenticated → skip login page
      if (isAuthenticated && isOnLogin) return AdminRoutes.dashboard;

      return null;
    },

    /// Refreshes the router when the AuthCubit emits a new state.
    refreshListenable: GoRouterRefreshStream(context),

    routes: <RouteBase>[
      // Public route — login page
      GoRoute(
        path: AdminRoutes.login,
        name: 'admin_login',
        builder: (context, state) => const AdminLoginPage(),
      ),

      // Protected routes — require authentication
      GoRoute(
        path: AdminRoutes.dashboard,
        name: 'admin_dashboard',
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: AdminRoutes.users,
        name: 'admin_users',
        builder: (context, state) => const AdminUsersPage(),
      ),
      GoRoute(
        path: AdminRoutes.questionBank,
        name: 'admin_question_bank',
        builder: (context, state) => const AdminQuestionBankPage(),
      ),
      GoRoute(
        path: AdminRoutes.quizEditor,
        name: 'admin_quiz_editor',
        builder: (context, state) => const AdminQuizEditorPage(),
      ),
      GoRoute(
        path: AdminRoutes.translations,
        name: 'admin_translations',
        builder: (context, state) => const AdminTranslationsPage(),
      ),
      GoRoute(
        path: AdminRoutes.analytics,
        name: 'admin_analytics',
        builder: (context, state) => const AdminAnalyticsPage(),
      ),
      GoRoute(
        path: AdminRoutes.settings,
        name: 'admin_settings',
        builder: (context, state) => const AdminSettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Không tìm thấy trang')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('GoException: no routes for location: ${state.uri.path}'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AdminRoutes.dashboard),
              child: const Text('Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Stream for GoRouter to listen to authentication state changes
class GoRouterRefreshStream extends ChangeNotifier {
  late StreamSubscription<AuthState> _subscription;

  GoRouterRefreshStream(BuildContext context) {
    _subscription = context.read<AuthCubit>().stream.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
