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
import 'package:frontend/features/home/presentation/pages/guest_home_mockup_page.dart';
import 'package:frontend/features/home/presentation/pages/authenticated_home_mockup_page.dart';
import 'package:frontend/features/translation/presentation/pages/translation_page.dart';

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
  static const String authenticatedHome = '/authenticated-home';
  static const String home = '/';
  static const String translate = '/translate';
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
    ///
    /// IMPORTANT: Only guards unauthenticated users from protected routes.
    /// Post-authentication navigation (e.g., register → success page) is
    /// handled exclusively by BlocConsumer listeners inside each page.
    /// This avoids a race condition where GoRouter fires before BlocConsumer.
    ///
    /// Route classification:
    ///   - Public/auth pages: accessible without login (login, signup, etc.)
    ///   - Protected pages: /authenticated-home, / — require authentication.
    redirect: (BuildContext context, GoRouterState state) {
      final authState = context.read<AuthCubit>().state;
      final isAuthenticated = authState is AuthAuthenticated;

      // The splash screen handles its own routing after the animation completes.
      if (state.matchedLocation == AppRoutes.splash) {
        return null;
      }

      // Pages that do NOT require authentication.
      // NOTE: authenticatedHome is intentionally excluded — it is a protected
      // route so that logout correctly redirects the user back to /login.
      final isPublicPage =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.passwordSetup ||
          state.matchedLocation == AppRoutes.welcome ||
          state.matchedLocation == AppRoutes.success ||
          state.matchedLocation == AppRoutes.guestHome;

      // Guard: unauthenticated users cannot access protected routes.
      // Covers /authenticated-home, / (home), and any future protected routes.
      if (!isAuthenticated && !isPublicPage) {
        return AppRoutes.login;
      }

      // Do NOT redirect authenticated users away from public pages here.
      // BlocConsumer listeners in each page drive post-auth navigation so that
      // the success page (and other intermediate screens) are not skipped.
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
            final slide =
                Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const AuthenticatedHomeMockupPage(),
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
            final slide =
                Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
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
            final slide =
                Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final fade = CurveTween(
                    curve: Curves.easeInOut,
                  ).animate(animation);
                  final slide =
                      Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                  return SlideTransition(
                    position: slide,
                    child: FadeTransition(opacity: fade, child: child),
                  );
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
            final slide =
                Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
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
            final slide =
                Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.authenticatedHome,
        name: 'authenticated_home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthenticatedHomeMockupPage(),
          transitionDuration: const Duration(milliseconds: 700),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurveTween(curve: Curves.easeInOut).animate(animation);
            final scale = Tween<double>(begin: 0.97, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return ScaleTransition(
              scale: scale,
              child: FadeTransition(opacity: fade, child: child),
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.translate,
        name: 'translate',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const TranslationPage(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurveTween(curve: Curves.easeInOut).animate(animation);
            final slide =
                Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: fade, child: child),
            );
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
    _subscription = context.read<AuthCubit>().stream.listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
