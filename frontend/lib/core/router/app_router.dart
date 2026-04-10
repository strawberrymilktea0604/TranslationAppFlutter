import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:frontend/features/auth/presentation/pages/login_page.dart';
import 'package:frontend/features/auth/presentation/pages/register_page.dart';
import 'package:frontend/features/home/presentation/pages/home_page.dart';

/// Route path constants to avoid hardcoded strings.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
}

/// Creates and configures the application router.
///
/// Uses [GoRouter] for declarative navigation with deep linking
/// and authentication-based redirect. When the user is not
/// authenticated, they are redirected to the login page.
/// When authenticated, accessing auth pages redirects to home.
GoRouter createRouter(BuildContext context) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,

    /// Redirect logic based on authentication state.
    /// Listens to AuthCubit state to determine redirect rules.
    redirect: (BuildContext context, GoRouterState state) {
      final authState = context.read<AuthCubit>().state;
      final isAuthenticated = authState is AuthAuthenticated;

      final isOnAuthPage = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      // If not authenticated and not on an auth page, redirect to login.
      if (!isAuthenticated && !isOnAuthPage) {
        return AppRoutes.login;
      }

      // If already authenticated and on an auth page, redirect to home.
      if (isAuthenticated && isOnAuthPage) {
        return AppRoutes.home;
      }

      // No redirect needed.
      return null;
    },

    /// Refreshes the router when the AuthCubit emits a new state.
    refreshListenable: GoRouterRefreshStream(context),

    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
    ],
  );
}

/// A [ChangeNotifier] that listens to the [AuthCubit] stream
/// and notifies [GoRouter] to re-evaluate redirect rules.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(BuildContext context) {
    // Subscribe to the AuthCubit's state stream.
    // Whenever auth state changes, notify GoRouter to re-evaluate.
    _subscription = context
        .read<AuthCubit>()
        .stream
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
