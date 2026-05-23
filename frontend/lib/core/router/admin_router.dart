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

/// Admin Route paths
class AdminRoutes {
  AdminRoutes._();

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
    initialLocation: AdminRoutes.dashboard,
    debugLogDiagnostics: true,

    /// Admin redirect logic - only authenticated admin users
    redirect: (BuildContext context, GoRouterState state) {
      final authState = context.read<AuthCubit>().state;
      final isAuthenticated = authState is AuthAuthenticated;
      
      // TODO: Check if user has admin role
      // final isAdmin = (authState as AuthAuthenticated?)?.user?.role == 'admin';

      if (!isAuthenticated) {
        return '/login';
      }

      return null;
    },

    /// Refreshes the router when the AuthCubit emits a new state.
    refreshListenable: GoRouterRefreshStream(context),

    routes: <RouteBase>[
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
    ],
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
