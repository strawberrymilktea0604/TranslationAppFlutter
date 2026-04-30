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
import 'package:frontend/features/translation/presentation/pages/translation_page.dart';
import 'package:frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:frontend/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:frontend/features/profile/presentation/pages/change_password_page.dart';

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
  static const String home = '/';
  static const String translate = '/translate';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String changePassword = '/change-password';

  // Legacy routes — kept for backward compatibility, all resolve to
  // TranslationPage (the new primary screen).
  static const String guestHome = '/guest-home';
  static const String authenticatedHome = '/authenticated-home';
}

/// Creates and configures the application router.
///
/// The primary screen is [TranslationPage], which serves both Guest
/// and Authenticated users. Guest/Auth differentiation is handled
/// within the page itself (inline CTA banner, menu items, feature guards).
GoRouter createRouter(BuildContext context) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,

    /// Redirect logic based on authentication state.
    ///
    /// IMPORTANT: The translation page (home, translate, guest-home,
    /// authenticated-home) is accessible to ALL users — both Guest and
    /// Authenticated. Only truly protected routes (e.g., future /settings,
    /// /profile) would be guarded here.
    ///
    /// Post-authentication navigation (e.g., register → success page) is
    /// handled exclusively by BlocConsumer listeners inside each page.
    redirect: (BuildContext context, GoRouterState state) {
      final authState = context.read<AuthCubit>().state;
      final isAuthenticated = authState is AuthAuthenticated;

      // The splash screen handles its own routing after the animation.
      if (state.matchedLocation == AppRoutes.splash) {
        return null;
      }

      // All public pages — accessible without login.
      // TranslationPage (home, translate, guest-home, authenticated-home)
      // is public per UC01 & UC02 in copilot-instructions §6.
      final isPublicPage =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.passwordSetup ||
          state.matchedLocation == AppRoutes.welcome ||
          state.matchedLocation == AppRoutes.success ||
          state.matchedLocation == AppRoutes.home ||
          state.matchedLocation == AppRoutes.translate ||
          state.matchedLocation == AppRoutes.guestHome ||
          state.matchedLocation == AppRoutes.authenticatedHome ||
          state.matchedLocation == AppRoutes.profile;

      // Guard: unauthenticated users cannot access protected routes.
      if (!isAuthenticated && !isPublicPage) {
        return AppRoutes.login;
      }

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
          transitionsBuilder: _slideUpFade,
        ),
      ),
      // ── Primary screen: TranslationPage ─────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const TranslationPage(),
      ),
      GoRoute(
        path: AppRoutes.translate,
        name: 'translate',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const TranslationPage(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: _slideUpFade,
        ),
      ),
      // Legacy routes — redirect to TranslationPage
      GoRoute(
        path: AppRoutes.guestHome,
        name: 'guest_home',
        redirect: (context, state) => AppRoutes.home,
      ),
      GoRoute(
        path: AppRoutes.authenticatedHome,
        name: 'authenticated_home',
        redirect: (context, state) => AppRoutes.home,
      ),
      // ── Auth routes ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginPage(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: _slideUpFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignUpPage(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: _slideUpFade,
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
            transitionsBuilder: _slideUpFade,
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
          transitionsBuilder: _slideUpFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfilePage(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: _slideUpFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        name: 'edit_profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const EditProfilePage(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: _slideUpFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        name: 'change_password',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ChangePasswordPage(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: _slideUpFade,
        ),
      ),
    ],
  );
}

/// Shared slide-up + fade transition for consistency.
Widget _slideUpFade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final fade = CurveTween(curve: Curves.easeInOut).animate(animation);
  final slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
  );
  return SlideTransition(
    position: slide,
    child: FadeTransition(opacity: fade, child: child),
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
