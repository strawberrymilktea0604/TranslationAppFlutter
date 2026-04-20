import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:frontend/features/auth/presentation/pages/splash_page.dart';
import 'package:frontend/features/auth/presentation/pages/welcome_page.dart';
import 'package:frontend/features/auth/presentation/pages/login_page.dart';
import 'package:frontend/features/auth/presentation/pages/signup_page.dart';
import 'package:frontend/features/auth/presentation/pages/password_setup_page.dart';
import 'package:frontend/features/auth/presentation/pages/success_page.dart';
import 'package:frontend/features/auth/presentation/pages/register_page.dart';
import 'package:frontend/features/home/presentation/pages/home_page.dart';
import 'package:frontend/features/home/presentation/pages/guest_home_mockup_page.dart';

/// Route path constants to avoid hardcoded strings.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String passwordSetup = '/password-setup';
  static const String success = '/success';
  static const String register = '/register';
  static const String guestHome = '/guest-home';
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
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,

    /// Redirect logic based on authentication state.
    /// Listens to AuthCubit state to determine redirect rules.
    redirect: (BuildContext context, GoRouterState state) {
      final authState = context.read<AuthCubit>().state;
      final isAuthenticated = authState is AuthAuthenticated;

      // The splash screen handles its own routing after the animation completes
      if (state.matchedLocation == AppRoutes.splash) {
        return null;
      }

      final isOnAuthPage = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.passwordSetup ||
          state.matchedLocation == AppRoutes.welcome ||
          state.matchedLocation == AppRoutes.success ||
          state.matchedLocation == AppRoutes.guestHome;

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
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const WelcomePage(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurveTween(curve: Curves.easeInOut).animate(animation);
            final slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginPage(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurveTween(curve: Curves.easeInOut).animate(animation);
            final slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignUpPage(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurveTween(curve: Curves.easeInOut).animate(animation);
            final slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.passwordSetup,
        name: 'password_setup',
        pageBuilder: (context, state) {
          final extra = Map<String, String>.from(state.extra as Map? ?? {});
          return CustomTransitionPage(
            key: state.pageKey,
            child: PasswordSetupPage(
              email: extra['email'] ?? '',
              firstName: extra['firstName'] ?? '',
              lastName: extra['lastName'] ?? '',
            ),
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final fade = CurveTween(curve: Curves.easeInOut).animate(animation);
              final slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
              return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.success,
        name: 'success',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SuccessPage(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurveTween(curve: Curves.easeInOut).animate(animation);
            final slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.guestHome,
        name: 'guest_home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const GuestHomeMockupPage(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurveTween(curve: Curves.easeInOut).animate(animation);
            final slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            return SlideTransition(position: slide, child: FadeTransition(opacity: fade, child: child));
          },
        ),
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
