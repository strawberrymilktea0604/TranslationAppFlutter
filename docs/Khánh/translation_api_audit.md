# 🔍 Audit: Translation API Integration & Guest/Authenticated UI

## Tổng quan

Audit kiểm tra tích hợp API dịch thuật cơ bản và UI cho Guest/Authenticated, dựa trên các rules từ `copilot-instructions.md`.

---

## ✅ Đã tuân thủ tốt

### 1. Clean Architecture (§2)
| Layer | File | Trạng thái |
|---|---|---|
| Entity | `translation_entity.dart` | ✅ Pure Dart class, có `isSynced`, `isDeleted` |
| Repository Interface | `translation_repository.dart` | ✅ Abstract class ở Domain layer |
| Repository Impl | `translation_repository_impl.dart` | ✅ Bắt exception → `Failure`, check network |
| UseCase | `translate_text_usecase.dart` | ✅ Extends `UseCase<T, P>`, 1 file = 1 usecase |
| DataSource | `translation_remote_datasource.dart` | ✅ Abstract + Impl, gọi API chuẩn |
| Cubit | `translation_cubit.dart` | ✅ Emit Loading → Success/Failure |
| State | `translation_state.dart` | ✅ Sealed class, Equatable, @immutable |

### 2. State Management — BLoC/Cubit (§3.1)
- ✅ Dùng `TranslationCubit` đúng flow `UI → Cubit → UseCase → Repository → DataSource`
- ✅ Emit `TranslationInProgress` trước async, sau đó `TranslationSuccess` hoặc `TranslationFailure`
- ✅ State sealed class với exhaustive switch

### 3. Error Handling (§3.2)
- ✅ Dùng `Either<Failure, T>` (dartz) ở Repository + UseCase
- ✅ Repository bắt `ServerException`, `Exception` → convert sang `Failure`
- ✅ Network check trước khi gọi API → `NetworkFailure`
- ✅ Không dùng try/catch ở Presentation layer

### 4. Performance (§3.4)
- ✅ **Debounce 800ms** sau khi người dùng ngừng gõ (vượt yêu cầu tối thiểu 500ms)
- ✅ **Shimmer loading** widget cho visual feedback
- ✅ Không gọi API trong `build()`
- ✅ Max 5,000 ký tự validation phía client (§7.2)

### 5. API Integration
- ✅ Gọi đúng endpoint: `POST /api/v1/translate/text`
- ✅ **Timeout 10 giây** (§4.3)
- ✅ Parse cả `SuccessResponse` wrapper `{ "status": "success", "data": {...} }`
- ✅ Parse error detail từ backend format
- ✅ Request body khớp: `text`, `source_language`, `target_language`

### 6. DI — Injection Container
- ✅ Đăng ký đúng thứ tự: DataSource → Repository → UseCase → Cubit
- ✅ `TranslationCubit` dùng `registerFactory` (mỗi screen tạo instance mới)

### 7. Guest vs Authenticated Home Pages
- ✅ `GuestHomeMockupPage` — hiển thị Guest Mode banner, nút Sign In/Create Account
- ✅ `AuthenticatedHomeMockupPage` — hiển thị stats, history, logout
- ✅ Cả 2 đều dùng `QuickTranslateWidget` (shared, self-contained BlocProvider)
- ✅ BlocListener cho logout → redirect về `/login`

---

## ⚠️ Vấn đề phát hiện & cần sửa

### Issue 1: Guest KHÔNG được chọn ngôn ngữ (Sai logic)

**File:** [translation_widgets.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/translation/presentation/widgets/translation_widgets.dart#L113-L117)

```dart
// ❌ HIỆN TẠI: Guest bấm chọn ngôn ngữ → bị redirect login
Future<void> _pickLanguage({required bool isSource}) async {
  if (!widget.isAuthenticated) {
    context.push('/login');
    return;
  }
```

**Vấn đề:** Theo `copilot-instructions.md` §6:
- **UC01 — Dịch văn bản thuần**: Guest ✅, User ✅, **KHÔNG yêu cầu Auth**
- **UC02 — Chuyển đổi ngôn ngữ**: Guest ✅, User ✅, **KHÔNG yêu cầu Auth**

Guest phải được chọn ngôn ngữ và dịch văn bản mà **không cần đăng nhập**. Backend cũng đã hỗ trợ Guest với `get_current_user_optional` (Bearer token tùy chọn).

> [!CAUTION]
> Đây là bug nghiêm trọng: Guest không thể sử dụng tính năng dịch cơ bản mặc dù copilot-instructions cho phép.

### Issue 2: TranslationPage (full screen) không có guard cho tính năng cần Auth

**File:** [translation_page.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/translation/presentation/pages/translation_page.dart)

Trang dịch full-screen hiện mở cho tất cả mọi người, nhưng:
- Nút **"Lưu từ vựng"** (UC07) → cần Auth → chỉ hiện "Coming soon" ✅ (tạm OK)
- Nút **Mic (STT)** (UC05) → cần Auth → chỉ hiện "Coming soon" ✅ (tạm OK)
- Nút **Camera (OCR)** (UC06) → cần Auth → chỉ hiện "Coming soon" ✅ (tạm OK)

Khi implement các tính năng này, cần thêm auth check phân biệt Guest/User.

### Issue 3: Translation API không gửi token cho authenticated user

**File:** [translation_remote_datasource.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/translation/data/datasources/translation_remote_datasource.dart#L34-L49)

```dart
// ❌ HIỆN TẠI: Luôn gọi API không có Bearer token
final response = await client.post(
  Uri.parse('$baseUrl/translate/text'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({...}),
);
```

Backend phân biệt Guest vs User thông qua `Authorization: Bearer <token>`:
- Guest: 10 req/hour, max 500 chars
- User: 100 req/hour, max 5000 chars

**Hiện tại**, authenticated user cũng bị backend coi là Guest (rate limit thấp hơn, 500 chars max). Cần truyền token khi user đã đăng nhập.

> [!WARNING]
> User đã đăng nhập sẽ bị giới hạn như Guest (500 chars, 10 req/hour) vì không gửi token.

### Issue 4: Route `/translate` là protected route

**File:** [app_router.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/core/router/app_router.dart#L69-L82)

```dart
// Hiện tại: /translate KHÔNG nằm trong isPublicPage
final isPublicPage =
    state.matchedLocation == AppRoutes.login ||
    // ... other public pages ...
    state.matchedLocation == AppRoutes.guestHome;

// → Guest truy cập /translate sẽ bị redirect về /login!
```

Theo UC01, UC02 — Guest được phép dùng trang dịch. Route `/translate` phải là **public**.

> [!IMPORTANT]
> Guest bấm "Mở màn hình dịch" từ QuickTranslateWidget → bị redirect login vì `/translate` không public.

---

## ✅ Đã sửa — Tất cả các issues

| # | File | Thay đổi | Status |
|---|---|---|---|
| 1 | `app_router.dart` | Thêm `/translate` vào `isPublicPage` | ✅ Fixed |
| 2 | `translation_widgets.dart` | Xóa redirect login khi Guest chọn ngôn ngữ | ✅ Fixed |
| 3 | `translation_remote_datasource.dart` | Thêm param `authToken`, gửi `Authorization: Bearer` | ✅ Fixed |
| 4 | `translation_repository_impl.dart` | Inject `AuthLocalDataSource`, đọc token, truyền vào datasource | ✅ Fixed |
| 5 | `injection_container.dart` | Thêm `authLocalDataSource: sl()` vào `TranslationRepositoryImpl` | ✅ Fixed |
| 6 | `translation_page.dart` | Phân biệt UI Guest/User: hide STT/OCR/Vocabulary cho Guest, hiện CTA login banner | ✅ Fixed |

### Chi tiết thay đổi

```diff:app_router.dart
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
===
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
      // UC01 (Dịch văn bản thuần) and UC02 (Chuyển đổi ngôn ngữ) are
      // accessible by Guest — /translate must be a public route.
      final isPublicPage =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.signup ||
          state.matchedLocation == AppRoutes.passwordSetup ||
          state.matchedLocation == AppRoutes.welcome ||
          state.matchedLocation == AppRoutes.success ||
          state.matchedLocation == AppRoutes.guestHome ||
          state.matchedLocation == AppRoutes.translate;

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
```

```diff:translation_widgets.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/injection_container.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_cubit.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_state.dart';
import 'package:frontend/features/translation/presentation/widgets/shimmer_loading_widget.dart';

// ---------------------------------------------------------------------------
// QuickTranslateWidget — compact version for home screens.
// Wraps its own BlocProvider so it's self-contained.
// ---------------------------------------------------------------------------

class QuickTranslateWidget extends StatelessWidget {
  final bool isAuthenticated;

  const QuickTranslateWidget({super.key, this.isAuthenticated = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TranslationCubit>(),
      child: _QuickTranslateView(isAuthenticated: isAuthenticated),
    );
  }
}

class _QuickTranslateView extends StatefulWidget {
  final bool isAuthenticated;

  const _QuickTranslateView({required this.isAuthenticated});

  @override
  State<_QuickTranslateView> createState() => _QuickTranslateViewState();
}

class _QuickTranslateViewState extends State<_QuickTranslateView> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _srcCode = 'auto';
  String _tgtCode = 'vi';

  static const Map<String, String> _langNames = {
    'auto': 'Tự động',
    'en': 'Tiếng Anh',
    'vi': 'Tiếng Việt',
    'fr': 'Tiếng Pháp',
    'ja': 'Tiếng Nhật',
    'ko': 'Tiếng Hàn',
    'zh': 'Tiếng Trung',
    'de': 'Tiếng Đức',
    'es': 'Tiếng Tây Ban Nha',
  };

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      context.read<TranslationCubit>().reset();
      return;
    }
    // Client-side validation: max 5,000 characters (§7.2).
    if (trimmed.length > 5000) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      context.read<TranslationCubit>().translateText(
        text: trimmed,
        sourceLanguage: _srcCode,
        targetLanguage: _tgtCode,
      );
    });
  }

  void _swapLanguages() {
    if (_srcCode == 'auto') return;
    final state = context.read<TranslationCubit>().state;
    String? swappedText;
    if (state is TranslationSuccess) {
      swappedText = state.translation.translatedText;
    }
    setState(() {
      final tmp = _srcCode;
      _srcCode = _tgtCode;
      _tgtCode = tmp;
    });
    if (swappedText != null && swappedText.isNotEmpty) {
      _controller.text = swappedText;
      _onTextChanged(swappedText);
    } else {
      context.read<TranslationCubit>().reset();
    }
  }

  void _clear() {
    _controller.clear();
    context.read<TranslationCubit>().reset();
  }

  Future<void> _pickLanguage({required bool isSource}) async {
    if (!widget.isAuthenticated) {
      context.push('/login');
      return;
    }

    final langs = isSource ? _langNames : Map.of(_langNames)
      ..remove('auto');
    final current = isSource ? _srcCode : _tgtCode;

    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          _QuickLanguagePickerSheet(langs: langs, selected: current),
    );

    if (picked == null || !mounted) return;
    setState(() {
      if (isSource) {
        _srcCode = picked;
      } else {
        _tgtCode = picked;
      }
    });
    if (_controller.text.trim().isNotEmpty) {
      _onTextChanged(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasText = _controller.text.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/translate'),
      behavior: HitTestBehavior.translucent,
      child: AbsorbPointer(
        absorbing: false,
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Language selector
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickLanguage(isSource: true),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _langNames[_srcCode] ?? _srcCode,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              color: cs.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    color: _srcCode != 'auto'
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.3),
                    onPressed: _srcCode != 'auto' ? _swapLanguages : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickLanguage(isSource: false),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _langNames[_tgtCode] ?? _tgtCode,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              color: cs.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              // Input row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 3,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Nhập văn bản cần dịch...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _onTextChanged,
                    ),
                  ),
                  if (hasText)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      color: cs.onSurfaceVariant,
                      onPressed: _clear,
                    ),
                ],
              ),
              // Result
              BlocBuilder<TranslationCubit, TranslationState>(
                builder: (ctx, state) {
                  if (state is TranslationInitial) {
                    return const SizedBox.shrink();
                  }
                  if (state is TranslationInProgress) {
                    return const ShimmerTranslationLoadingCompact();
                  }
                  if (state is TranslationSuccess) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 20),
                        Text(
                          state.translation.translatedText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: state.translation.translatedText,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép bản dịch'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: const Text('Sao chép'),
                          ),
                        ),
                      ],
                    );
                  }
                  if (state is TranslationFailure) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              state.message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              // Open full page hint
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => context.push('/translate'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Mở màn hình dịch',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language picker bottom sheet specifically for QuickTranslate
// ---------------------------------------------------------------------------

class _QuickLanguagePickerSheet extends StatelessWidget {
  final Map<String, String> langs;
  final String selected;

  const _QuickLanguagePickerSheet({
    required this.langs,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = langs.entries.toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn ngôn ngữ',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: entries.length,
              itemBuilder: (ctx, i) {
                final code = entries[i].key;
                final name = entries[i].value;
                final isSelected = code == selected;

                // Cờ tượng trưng
                String flag = '🌐';
                if (code == 'en') flag = '🇺🇸';
                if (code == 'vi') flag = '🇻🇳';
                if (code == 'ja') flag = '🇯🇵';
                if (code == 'ko') flag = '🇰🇷';
                if (code == 'zh') flag = '🇨🇳';
                if (code == 'fr') flag = '🇫🇷';
                if (code == 'es') flag = '🇪🇸';
                if (code == 'de') flag = '🇩🇪';
                if (code == 'auto') flag = '🔍';

                return ListTile(
                  leading: Text(flag, style: const TextStyle(fontSize: 24)),
                  title: Text(name),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  selected: isSelected,
                  selectedTileColor: cs.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => Navigator.of(ctx).pop(code),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
===
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/injection_container.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_cubit.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_state.dart';
import 'package:frontend/features/translation/presentation/widgets/shimmer_loading_widget.dart';

// ---------------------------------------------------------------------------
// QuickTranslateWidget — compact version for home screens.
// Wraps its own BlocProvider so it's self-contained.
// ---------------------------------------------------------------------------

class QuickTranslateWidget extends StatelessWidget {
  final bool isAuthenticated;

  const QuickTranslateWidget({super.key, this.isAuthenticated = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TranslationCubit>(),
      child: _QuickTranslateView(isAuthenticated: isAuthenticated),
    );
  }
}

class _QuickTranslateView extends StatefulWidget {
  final bool isAuthenticated;

  const _QuickTranslateView({required this.isAuthenticated});

  @override
  State<_QuickTranslateView> createState() => _QuickTranslateViewState();
}

class _QuickTranslateViewState extends State<_QuickTranslateView> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _srcCode = 'auto';
  String _tgtCode = 'vi';

  static const Map<String, String> _langNames = {
    'auto': 'Tự động',
    'en': 'Tiếng Anh',
    'vi': 'Tiếng Việt',
    'fr': 'Tiếng Pháp',
    'ja': 'Tiếng Nhật',
    'ko': 'Tiếng Hàn',
    'zh': 'Tiếng Trung',
    'de': 'Tiếng Đức',
    'es': 'Tiếng Tây Ban Nha',
  };

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      context.read<TranslationCubit>().reset();
      return;
    }
    // Client-side validation: max 5,000 characters (§7.2).
    if (trimmed.length > 5000) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      context.read<TranslationCubit>().translateText(
        text: trimmed,
        sourceLanguage: _srcCode,
        targetLanguage: _tgtCode,
      );
    });
  }

  void _swapLanguages() {
    if (_srcCode == 'auto') return;
    final state = context.read<TranslationCubit>().state;
    String? swappedText;
    if (state is TranslationSuccess) {
      swappedText = state.translation.translatedText;
    }
    setState(() {
      final tmp = _srcCode;
      _srcCode = _tgtCode;
      _tgtCode = tmp;
    });
    if (swappedText != null && swappedText.isNotEmpty) {
      _controller.text = swappedText;
      _onTextChanged(swappedText);
    } else {
      context.read<TranslationCubit>().reset();
    }
  }

  void _clear() {
    _controller.clear();
    context.read<TranslationCubit>().reset();
  }

  Future<void> _pickLanguage({required bool isSource}) async {
    // UC02: Language switching is available to Guest and User (no auth needed).

    final langs = isSource ? _langNames : Map.of(_langNames)
      ..remove('auto');
    final current = isSource ? _srcCode : _tgtCode;

    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          _QuickLanguagePickerSheet(langs: langs, selected: current),
    );

    if (picked == null || !mounted) return;
    setState(() {
      if (isSource) {
        _srcCode = picked;
      } else {
        _tgtCode = picked;
      }
    });
    if (_controller.text.trim().isNotEmpty) {
      _onTextChanged(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasText = _controller.text.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/translate'),
      behavior: HitTestBehavior.translucent,
      child: AbsorbPointer(
        absorbing: false,
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Language selector
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickLanguage(isSource: true),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _langNames[_srcCode] ?? _srcCode,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              color: cs.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    color: _srcCode != 'auto'
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.3),
                    onPressed: _srcCode != 'auto' ? _swapLanguages : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickLanguage(isSource: false),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _langNames[_tgtCode] ?? _tgtCode,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              color: cs.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              // Input row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 3,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Nhập văn bản cần dịch...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _onTextChanged,
                    ),
                  ),
                  if (hasText)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      color: cs.onSurfaceVariant,
                      onPressed: _clear,
                    ),
                ],
              ),
              // Result
              BlocBuilder<TranslationCubit, TranslationState>(
                builder: (ctx, state) {
                  if (state is TranslationInitial) {
                    return const SizedBox.shrink();
                  }
                  if (state is TranslationInProgress) {
                    return const ShimmerTranslationLoadingCompact();
                  }
                  if (state is TranslationSuccess) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 20),
                        Text(
                          state.translation.translatedText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: state.translation.translatedText,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép bản dịch'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: const Text('Sao chép'),
                          ),
                        ),
                      ],
                    );
                  }
                  if (state is TranslationFailure) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              state.message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              // Open full page hint
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => context.push('/translate'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Mở màn hình dịch',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language picker bottom sheet specifically for QuickTranslate
// ---------------------------------------------------------------------------

class _QuickLanguagePickerSheet extends StatelessWidget {
  final Map<String, String> langs;
  final String selected;

  const _QuickLanguagePickerSheet({
    required this.langs,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = langs.entries.toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn ngôn ngữ',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: entries.length,
              itemBuilder: (ctx, i) {
                final code = entries[i].key;
                final name = entries[i].value;
                final isSelected = code == selected;

                // Cờ tượng trưng
                String flag = '🌐';
                if (code == 'en') flag = '🇺🇸';
                if (code == 'vi') flag = '🇻🇳';
                if (code == 'ja') flag = '🇯🇵';
                if (code == 'ko') flag = '🇰🇷';
                if (code == 'zh') flag = '🇨🇳';
                if (code == 'fr') flag = '🇫🇷';
                if (code == 'es') flag = '🇪🇸';
                if (code == 'de') flag = '🇩🇪';
                if (code == 'auto') flag = '🔍';

                return ListTile(
                  leading: Text(flag, style: const TextStyle(fontSize: 24)),
                  title: Text(name),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  selected: isSelected,
                  selectedTileColor: cs.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => Navigator.of(ctx).pop(code),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
```

```diff:translation_remote_datasource.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/translation/data/models/translation_model.dart';

/// Abstract interface for remote translation API.
abstract class TranslationRemoteDataSource {
  /// Calls `POST /api/v1/translate/text`.
  /// Throws [ServerException] on non-200 responses or timeout.
  Future<TranslationModel> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });
}

class TranslationRemoteDataSourceImpl implements TranslationRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  const TranslationRemoteDataSourceImpl({
    required this.client,
    required this.baseUrl,
  });

  @override
  Future<TranslationModel> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final response = await client
        .post(
          Uri.parse('$baseUrl/translate/text'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'source_language': sourceLanguage,
            'target_language': targetLanguage,
          }),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw const ServerException(
            message: 'Yêu cầu hết thời gian, vui lòng thử lại.',
          ),
        );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // Backend wraps responses in SuccessResponse:
      // { "status": "success", "data": { ... } }
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      return TranslationModel.fromJson(data);
    }

    // Parse error detail from backend error response format:
    // { "detail": { "status": "error", "code": "...", "message": "..." } }
    // or { "detail": "simple string" }
    Map<String, dynamic> errorBody;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        errorBody = decoded;
      } else {
        errorBody = {'detail': response.body};
      }
    } catch (_) {
      errorBody = {'detail': response.body};
    }

    String errorMessage;
    final detail = errorBody['detail'];
    if (detail is Map<String, dynamic>) {
      errorMessage =
          detail['message'] as String? ??
          'Lỗi máy chủ ${response.statusCode}';
    } else if (detail is String) {
      errorMessage = detail;
    } else {
      errorMessage = 'Lỗi máy chủ ${response.statusCode}';
    }

    throw ServerException(
      message: errorMessage,
      statusCode: response.statusCode,
    );
  }
}
===
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/translation/data/models/translation_model.dart';

/// Abstract interface for remote translation API.
abstract class TranslationRemoteDataSource {
  /// Calls `POST /api/v1/translate/text`.
  ///
  /// When [authToken] is provided, attaches it as `Authorization: Bearer`
  /// so the backend applies User-level rate limits (100 req/hour, 5000 chars).
  /// Without a token, the backend treats the request as Guest (10 req/hour,
  /// 500 chars).
  ///
  /// Throws [ServerException] on non-200 responses or timeout.
  Future<TranslationModel> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? authToken,
  });
}

class TranslationRemoteDataSourceImpl implements TranslationRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  const TranslationRemoteDataSourceImpl({
    required this.client,
    required this.baseUrl,
  });

  @override
  Future<TranslationModel> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? authToken,
  }) async {
    // Build headers — attach Bearer token when available so
    // the backend applies User-level limits instead of Guest.
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final response = await client
        .post(
          Uri.parse('$baseUrl/translate/text'),
          headers: headers,
          body: jsonEncode({
            'text': text,
            'source_language': sourceLanguage,
            'target_language': targetLanguage,
          }),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw const ServerException(
            message: 'Yêu cầu hết thời gian, vui lòng thử lại.',
          ),
        );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // Backend wraps responses in SuccessResponse:
      // { "status": "success", "data": { ... } }
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      return TranslationModel.fromJson(data);
    }

    // Parse error detail from backend error response format:
    // { "detail": { "status": "error", "code": "...", "message": "..." } }
    // or { "detail": "simple string" }
    Map<String, dynamic> errorBody;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        errorBody = decoded;
      } else {
        errorBody = {'detail': response.body};
      }
    } catch (_) {
      errorBody = {'detail': response.body};
    }

    String errorMessage;
    final detail = errorBody['detail'];
    if (detail is Map<String, dynamic>) {
      errorMessage =
          detail['message'] as String? ??
          'Lỗi máy chủ ${response.statusCode}';
    } else if (detail is String) {
      errorMessage = detail;
    } else {
      errorMessage = 'Lỗi máy chủ ${response.statusCode}';
    }

    throw ServerException(
      message: errorMessage,
      statusCode: response.statusCode,
    );
  }
}

```

```diff:translation_repository_impl.dart
import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/features/translation/data/datasources/translation_remote_datasource.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';
import 'package:frontend/features/translation/domain/repositories/translation_repository.dart';

/// Concrete implementation of [TranslationRepository].
///
/// Strategy:
/// - Checks connectivity first → [NetworkFailure] if offline.
/// - Delegates to [TranslationRemoteDataSource].
/// - Catches all exceptions and converts to [Failure] subclasses.
/// - [switchLanguages] is a no-op: language state is managed by the UI layer.
class TranslationRepositoryImpl implements TranslationRepository {
  final TranslationRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  const TranslationRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, TranslationEntity>> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Không có kết nối internet'));
    }

    try {
      final model = await remoteDataSource.translateText(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> switchLanguages({
    required String currentSource,
    required String currentTarget,
  }) async {
    // Language switching is managed in the UI layer — no server call needed.
    return const Right(null);
  }
}
===
import 'package:dartz/dartz.dart';

import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/translation/data/datasources/translation_remote_datasource.dart';
import 'package:frontend/features/translation/domain/entities/translation_entity.dart';
import 'package:frontend/features/translation/domain/repositories/translation_repository.dart';

/// Concrete implementation of [TranslationRepository].
///
/// Strategy:
/// - Checks connectivity first → [NetworkFailure] if offline.
/// - Reads JWT access token (if available) from [AuthLocalDataSource] so the
///   backend applies User-level rate limits instead of Guest-level.
/// - Delegates to [TranslationRemoteDataSource].
/// - Catches all exceptions and converts to [Failure] subclasses.
/// - [switchLanguages] is a no-op: language state is managed by the UI layer.
class TranslationRepositoryImpl implements TranslationRepository {
  final TranslationRemoteDataSource remoteDataSource;
  final AuthLocalDataSource authLocalDataSource;
  final NetworkInfo networkInfo;

  const TranslationRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, TranslationEntity>> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Không có kết nối internet'));
    }

    try {
      // Read access token — null means Guest mode (still allowed per UC01).
      // Token read failure is intentionally swallowed: if secure storage
      // throws, the user still gets a translation (as Guest).
      String? authToken;
      try {
        authToken = await authLocalDataSource.getAccessToken();
      } catch (_) {
        // Ignore — proceed as Guest.
      }

      final model = await remoteDataSource.translateText(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        authToken: authToken,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> switchLanguages({
    required String currentSource,
    required String currentTarget,
  }) async {
    // Language switching is managed in the UI layer — no server call needed.
    return const Right(null);
  }
}

```

```diff:injection_container.dart
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/core/network/bloc/network_cubit.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/core/tts/tts_service.dart';
import 'package:frontend/core/tts/bloc/tts_cubit.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/login_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/register_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/check_email_usecase.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/translation/data/datasources/translation_remote_datasource.dart';
import 'package:frontend/features/translation/data/repositories/translation_repository_impl.dart';
import 'package:frontend/features/translation/domain/repositories/translation_repository.dart';
import 'package:frontend/features/translation/domain/usecases/translate_text_usecase.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_cubit.dart';

import 'main.dart' show config;

/// Global service locator instance for Dependency Injection.
/// Use get_it to register and resolve dependencies.
///
/// Registration follows Clean Architecture layer order:
/// 1. External services (network, DB, secure storage)
/// 2. DataSources (Remote & Local)
/// 3. Repositories (bind implementation to abstract interface)
/// 4. UseCases
/// 5. Cubits/Blocs
final sl = GetIt.instance;

/// Initializes all dependencies.
/// Must be called before runApp() in main.dart.
Future<void> initDependencies() async {
  // ==============================
  //  Core — External Services
  // ==============================

  // HTTP client for REST API calls.
  sl.registerLazySingleton<http.Client>(() => http.Client());

  // Network connectivity checker — verifies real internet access.
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(InternetConnection()),
  );

  // Global network connectivity state
  sl.registerLazySingleton<NetworkCubit>(() => NetworkCubit(networkInfo: sl()));

  // Secure storage — encrypted Keychain (iOS) /
  // EncryptedSharedPreferences (Android).
  // JWT tokens MUST be stored here, NEVER in SharedPreferences.
  sl.registerLazySingleton<SecureStorageService>(() => SecureStorageService());

  // Text-to-Speech engine — shared singleton so only one voice
  // plays at a time across the entire app.
  sl.registerLazySingleton<TtsService>(() => TtsServiceImpl());
  sl.registerLazySingleton<TtsCubit>(
    () => TtsCubit(ttsService: sl()),
  );

  // ==============================
  //  Feature: Auth
  // ==============================

  // DataSources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(secureStorage: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );

  // Repository — binds implementation to abstract interface.
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // UseCases — one use case = one business action.
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => CheckEmailUseCase(sl()));

  // Cubits — registered as factory (new instance per provider).
  sl.registerFactory(
    () => AuthCubit(
      loginUseCase: sl(),
      registerUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
      checkEmailUseCase: sl(),
    ),
  );

  // ==============================
  //  Feature: Translation
  // ==============================

  sl.registerLazySingleton<TranslationRemoteDataSource>(
    () => TranslationRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );

  sl.registerLazySingleton<TranslationRepository>(
    () => TranslationRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );

  sl.registerLazySingleton(() => TranslateTextUseCase(sl()));

  // Factory: new cubit per screen/widget that provides it.
  sl.registerFactory(() => TranslationCubit(sl()));

  // ==============================
  //  Feature: Vocabulary
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: History
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: Speech (STT)
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: OCR
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: Sync
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits
}
===
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'package:frontend/core/network/network_info.dart';
import 'package:frontend/core/network/bloc/network_cubit.dart';
import 'package:frontend/core/storage/secure_storage_service.dart';
import 'package:frontend/core/tts/tts_service.dart';
import 'package:frontend/core/tts/bloc/tts_cubit.dart';
import 'package:frontend/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/login_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/logout_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/register_usecase.dart';
import 'package:frontend/features/auth/domain/usecases/check_email_usecase.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/translation/data/datasources/translation_remote_datasource.dart';
import 'package:frontend/features/translation/data/repositories/translation_repository_impl.dart';
import 'package:frontend/features/translation/domain/repositories/translation_repository.dart';
import 'package:frontend/features/translation/domain/usecases/translate_text_usecase.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_cubit.dart';

import 'main.dart' show config;

/// Global service locator instance for Dependency Injection.
/// Use get_it to register and resolve dependencies.
///
/// Registration follows Clean Architecture layer order:
/// 1. External services (network, DB, secure storage)
/// 2. DataSources (Remote & Local)
/// 3. Repositories (bind implementation to abstract interface)
/// 4. UseCases
/// 5. Cubits/Blocs
final sl = GetIt.instance;

/// Initializes all dependencies.
/// Must be called before runApp() in main.dart.
Future<void> initDependencies() async {
  // ==============================
  //  Core — External Services
  // ==============================

  // HTTP client for REST API calls.
  sl.registerLazySingleton<http.Client>(() => http.Client());

  // Network connectivity checker — verifies real internet access.
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(InternetConnection()),
  );

  // Global network connectivity state
  sl.registerLazySingleton<NetworkCubit>(() => NetworkCubit(networkInfo: sl()));

  // Secure storage — encrypted Keychain (iOS) /
  // EncryptedSharedPreferences (Android).
  // JWT tokens MUST be stored here, NEVER in SharedPreferences.
  sl.registerLazySingleton<SecureStorageService>(() => SecureStorageService());

  // Text-to-Speech engine — shared singleton so only one voice
  // plays at a time across the entire app.
  sl.registerLazySingleton<TtsService>(() => TtsServiceImpl());
  sl.registerLazySingleton<TtsCubit>(
    () => TtsCubit(ttsService: sl()),
  );

  // ==============================
  //  Feature: Auth
  // ==============================

  // DataSources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(secureStorage: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );

  // Repository — binds implementation to abstract interface.
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // UseCases — one use case = one business action.
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => CheckEmailUseCase(sl()));

  // Cubits — registered as factory (new instance per provider).
  sl.registerFactory(
    () => AuthCubit(
      loginUseCase: sl(),
      registerUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
      checkEmailUseCase: sl(),
    ),
  );

  // ==============================
  //  Feature: Translation
  // ==============================

  sl.registerLazySingleton<TranslationRemoteDataSource>(
    () => TranslationRemoteDataSourceImpl(client: sl(), baseUrl: config.apiUrl),
  );

  sl.registerLazySingleton<TranslationRepository>(
    () => TranslationRepositoryImpl(
      remoteDataSource: sl(),
      authLocalDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  sl.registerLazySingleton(() => TranslateTextUseCase(sl()));

  // Factory: new cubit per screen/widget that provides it.
  sl.registerFactory(() => TranslationCubit(sl()));

  // ==============================
  //  Feature: Vocabulary
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: History
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: Speech (STT)
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: OCR
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits

  // ==============================
  //  Feature: Sync
  // ==============================
  // TODO: Register DataSources, Repository, UseCases, Cubits
}
```

```diff:translation_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/injection_container.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/widgets/tts_icon_button.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_cubit.dart';
import 'package:frontend/features/translation/presentation/widgets/shimmer_loading_widget.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_state.dart';

// ---------------------------------------------------------------------------
// Language model
// ---------------------------------------------------------------------------

class _Lang {
  final String code;
  final String name;
  final String flag;

  const _Lang({required this.code, required this.name, required this.flag});
}

const _kLangs = [
  _Lang(code: 'auto', name: 'Tự động', flag: '🔍'),
  _Lang(code: 'en', name: 'Tiếng Anh', flag: '🇺🇸'),
  _Lang(code: 'vi', name: 'Tiếng Việt', flag: '🇻🇳'),
  _Lang(code: 'fr', name: 'Tiếng Pháp', flag: '🇫🇷'),
  _Lang(code: 'ja', name: 'Tiếng Nhật', flag: '🇯🇵'),
  _Lang(code: 'ko', name: 'Tiếng Hàn', flag: '🇰🇷'),
  _Lang(code: 'zh', name: 'Tiếng Trung', flag: '🇨🇳'),
  _Lang(code: 'de', name: 'Tiếng Đức', flag: '🇩🇪'),
  _Lang(code: 'es', name: 'Tiếng Tây Ban Nha', flag: '🇪🇸'),
];

_Lang _findLang(String code) =>
    _kLangs.firstWhere((l) => l.code == code, orElse: () => _kLangs[1]);

// ---------------------------------------------------------------------------
// Entry point — wraps page in BlocProvider
// ---------------------------------------------------------------------------

class TranslationPage extends StatelessWidget {
  const TranslationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TranslationCubit>(),
      child: const _TranslationView(),
    );
  }
}

// ---------------------------------------------------------------------------
// Main view
// ---------------------------------------------------------------------------

class _TranslationView extends StatefulWidget {
  const _TranslationView();

  @override
  State<_TranslationView> createState() => _TranslationViewState();
}

class _TranslationViewState extends State<_TranslationView>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _srcCode = 'auto';
  String _tgtCode = 'vi';
  late AnimationController _swapAnim;

  @override
  void initState() {
    super.initState();
    _swapAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _swapAnim.dispose();
    super.dispose();
  }

  // ---- constants ----

  /// Maximum character length per translation request (§7.2).
  static const int _kMaxTextLength = 5000;

  // ---- helpers ----

  TranslationCubit get _cubit => context.read<TranslationCubit>();

  void _onTextChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _cubit.reset();
      return;
    }
    // Client-side validation: max 5,000 characters per request (§7.2).
    if (trimmed.length > _kMaxTextLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Văn bản vượt quá $_kMaxTextLength ký tự '
            '(hiện tại: ${trimmed.length})',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _cubit.translateText(
        text: trimmed,
        sourceLanguage: _srcCode,
        targetLanguage: _tgtCode,
      );
    });
  }

  void _swapLanguages() {
    if (_srcCode == 'auto') return;
    _swapAnim.forward(from: 0);
    final state = _cubit.state;
    String? swappedText;
    if (state is TranslationSuccess) {
      swappedText = state.translation.translatedText;
    }
    setState(() {
      final tmp = _srcCode;
      _srcCode = _tgtCode;
      _tgtCode = tmp;
    });
    if (swappedText != null && swappedText.isNotEmpty) {
      _controller.text = swappedText;
      _onTextChanged(swappedText);
    } else {
      _cubit.reset();
    }
  }

  void _clear() {
    _controller.clear();
    _cubit.reset();
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — tính năng sắp ra mắt 🚀'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickLanguage({required bool isSource}) async {
    final langs = isSource
        ? _kLangs
        : _kLangs.where((l) => l.code != 'auto').toList();
    final current = isSource ? _srcCode : _tgtCode;

    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LanguagePickerSheet(langs: langs, selected: current),
    );

    if (picked == null || !mounted) return;
    setState(() {
      if (isSource) {
        _srcCode = picked;
      } else {
        _tgtCode = picked;
      }
    });
    if (_controller.text.trim().isNotEmpty) {
      _onTextChanged(_controller.text);
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dịch thuật'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_outlined),
            tooltip: 'Dịch bằng giọng nói',
            onPressed: () => _showComingSoon('Dịch giọng nói'),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Dịch bằng hình ảnh',
            onPressed: () => _showComingSoon('Dịch hình ảnh'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            _buildLangBar(cs),
            const SizedBox(height: 12),
            Expanded(flex: 5, child: _buildSourceCard(theme)),
            const SizedBox(height: 12),
            Expanded(flex: 5, child: _buildResultCard(theme)),
          ],
        ),
      ),
    );
  }

  // ---- Language bar ----

  Widget _buildLangBar(ColorScheme cs) {
    final src = _findLang(_srcCode);
    final tgt = _findLang(_tgtCode);
    final canSwap = _srcCode != 'auto';

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              onTap: () => _pickLanguage(isSource: true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(src.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      src.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          RotationTransition(
            turns: Tween(begin: 0.0, end: 0.5).animate(
              CurvedAnimation(parent: _swapAnim, curve: Curves.easeInOut),
            ),
            child: IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              color: canSwap ? cs.primary : cs.onSurface.withValues(alpha: 0.3),
              tooltip: 'Đổi ngôn ngữ',
              onPressed: canSwap ? _swapLanguages : null,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(14),
              ),
              onTap: () => _pickLanguage(isSource: false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tgt.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      tgt.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Source card ----

  Widget _buildSourceCard(ThemeData theme) {
    final cs = theme.colorScheme;
    final hasText = _controller.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: label + clear button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 0),
            child: Row(
              children: [
                Text(
                  'Nguồn · ${_findLang(_srcCode).name}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (hasText)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Xóa',
                    color: cs.onSurfaceVariant,
                    onPressed: _clear,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // TextField
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Nhập văn bản cần dịch...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _onTextChanged,
              ),
            ),
          ),
          // Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TtsIconButton(
                  text: _controller.text,
                  languageCode: _srcCode == 'auto' ? 'en' : _srcCode,
                  tooltip: 'Phát âm văn bản nguồn',
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  tooltip: 'Sao chép',
                  color: hasText
                      ? AppTheme.primaryColor
                      : cs.onSurface.withValues(alpha: 0.3),
                  onPressed: hasText
                      ? () => _copyText(
                          _controller.text,
                          'Đã sao chép văn bản nguồn',
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Result card ----

  Widget _buildResultCard(ThemeData theme) {
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'Dịch · ${_findLang(_tgtCode).name}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: BlocBuilder<TranslationCubit, TranslationState>(
                builder: (context, state) {
                  return switch (state) {
                    TranslationInitial() => _ResultHint(cs: cs),
                    TranslationInProgress() => const _ResultLoading(),
                    TranslationSuccess(translation: final t) => _ResultText(
                      text: t.translatedText,
                      theme: theme,
                    ),
                    TranslationFailure(message: final msg) => _ResultError(
                      message: msg,
                      theme: theme,
                    ),
                  };
                },
              ),
            ),
          ),
          // Action bar
          BlocBuilder<TranslationCubit, TranslationState>(
            builder: (context, state) {
              final resultText = state is TranslationSuccess
                  ? state.translation.translatedText
                  : null;
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                      tooltip: 'Lưu từ vựng',
                      color: cs.onSurfaceVariant,
                      onPressed: () => _showComingSoon('Lưu từ vựng'),
                    ),
                    const Spacer(),
                    if (resultText != null)
                      TtsIconButton(
                        text: resultText,
                        languageCode: _tgtCode,
                        tooltip: 'Phát âm bản dịch',
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 20),
                      tooltip: 'Sao chép',
                      color: resultText != null
                          ? AppTheme.primaryColor
                          : cs.onSurface.withValues(alpha: 0.3),
                      onPressed: resultText != null
                          ? () => _copyText(resultText, 'Đã sao chép bản dịch')
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result sub-states
// ---------------------------------------------------------------------------

class _ResultHint extends StatelessWidget {
  final ColorScheme cs;
  const _ResultHint({required this.cs});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.translate_rounded,
          size: 40,
          color: cs.primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        Text(
          'Bản dịch sẽ xuất hiện ở đây',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45)),
        ),
      ],
    ),
  );
}

class _ResultLoading extends StatelessWidget {
  const _ResultLoading();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: ShimmerTranslationLoading(lineCount: 4),
    );
  }
}

class _ResultText extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _ResultText({required this.text, required this.theme});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: AppTheme.primaryColor,
        height: 1.5,
      ),
    ),
  );
}

class _ResultError extends StatelessWidget {
  final String message;
  final ThemeData theme;
  const _ResultError({required this.message, required this.theme});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 36,
          color: theme.colorScheme.error.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Language picker bottom sheet
// ---------------------------------------------------------------------------

class _LanguagePickerSheet extends StatelessWidget {
  final List<_Lang> langs;
  final String selected;

  const _LanguagePickerSheet({required this.langs, required this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn ngôn ngữ',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: langs.length,
              itemBuilder: (ctx, i) {
                final l = langs[i];
                final isSelected = l.code == selected;
                return ListTile(
                  leading: Text(l.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(l.name),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  selected: isSelected,
                  selectedTileColor: cs.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => Navigator.of(ctx).pop(l.code),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
===
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/injection_container.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/tts/widgets/tts_icon_button.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_cubit.dart';
import 'package:frontend/features/translation/presentation/widgets/shimmer_loading_widget.dart';
import 'package:frontend/features/translation/presentation/bloc/translation_state.dart';

// ---------------------------------------------------------------------------
// Language model
// ---------------------------------------------------------------------------

class _Lang {
  final String code;
  final String name;
  final String flag;

  const _Lang({required this.code, required this.name, required this.flag});
}

const _kLangs = [
  _Lang(code: 'auto', name: 'Tự động', flag: '🔍'),
  _Lang(code: 'en', name: 'Tiếng Anh', flag: '🇺🇸'),
  _Lang(code: 'vi', name: 'Tiếng Việt', flag: '🇻🇳'),
  _Lang(code: 'fr', name: 'Tiếng Pháp', flag: '🇫🇷'),
  _Lang(code: 'ja', name: 'Tiếng Nhật', flag: '🇯🇵'),
  _Lang(code: 'ko', name: 'Tiếng Hàn', flag: '🇰🇷'),
  _Lang(code: 'zh', name: 'Tiếng Trung', flag: '🇨🇳'),
  _Lang(code: 'de', name: 'Tiếng Đức', flag: '🇩🇪'),
  _Lang(code: 'es', name: 'Tiếng Tây Ban Nha', flag: '🇪🇸'),
];

_Lang _findLang(String code) =>
    _kLangs.firstWhere((l) => l.code == code, orElse: () => _kLangs[1]);

// ---------------------------------------------------------------------------
// Entry point — wraps page in BlocProvider
// ---------------------------------------------------------------------------

class TranslationPage extends StatelessWidget {
  const TranslationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TranslationCubit>(),
      child: const _TranslationView(),
    );
  }
}

// ---------------------------------------------------------------------------
// Main view
// ---------------------------------------------------------------------------

class _TranslationView extends StatefulWidget {
  const _TranslationView();

  @override
  State<_TranslationView> createState() => _TranslationViewState();
}

class _TranslationViewState extends State<_TranslationView>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _srcCode = 'auto';
  String _tgtCode = 'vi';
  late AnimationController _swapAnim;

  @override
  void initState() {
    super.initState();
    _swapAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _swapAnim.dispose();
    super.dispose();
  }

  // ---- constants ----

  /// Maximum character length per translation request (§7.2).
  static const int _kMaxTextLength = 5000;

  // ---- helpers ----

  TranslationCubit get _cubit => context.read<TranslationCubit>();

  void _onTextChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _cubit.reset();
      return;
    }
    // Client-side validation: max 5,000 characters per request (§7.2).
    if (trimmed.length > _kMaxTextLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Văn bản vượt quá $_kMaxTextLength ký tự '
            '(hiện tại: ${trimmed.length})',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _cubit.translateText(
        text: trimmed,
        sourceLanguage: _srcCode,
        targetLanguage: _tgtCode,
      );
    });
  }

  void _swapLanguages() {
    if (_srcCode == 'auto') return;
    _swapAnim.forward(from: 0);
    final state = _cubit.state;
    String? swappedText;
    if (state is TranslationSuccess) {
      swappedText = state.translation.translatedText;
    }
    setState(() {
      final tmp = _srcCode;
      _srcCode = _tgtCode;
      _tgtCode = tmp;
    });
    if (swappedText != null && swappedText.isNotEmpty) {
      _controller.text = swappedText;
      _onTextChanged(swappedText);
    } else {
      _cubit.reset();
    }
  }

  void _clear() {
    _controller.clear();
    _cubit.reset();
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — tính năng sắp ra mắt 🚀'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickLanguage({required bool isSource}) async {
    final langs = isSource
        ? _kLangs
        : _kLangs.where((l) => l.code != 'auto').toList();
    final current = isSource ? _srcCode : _tgtCode;

    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LanguagePickerSheet(langs: langs, selected: current),
    );

    if (picked == null || !mounted) return;
    setState(() {
      if (isSource) {
        _srcCode = picked;
      } else {
        _tgtCode = picked;
      }
    });
    if (_controller.text.trim().isNotEmpty) {
      _onTextChanged(_controller.text);
    }
  }

  // ---- build ----

  /// Whether the current user is authenticated.
  /// Used to show/hide features that require Auth (UC05, UC06, UC07).
  bool get _isAuthenticated {
    try {
      return context.read<AuthCubit>().state is AuthAuthenticated;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isAuth = _isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dịch thuật'),
        centerTitle: true,
        actions: [
          // UC05 — Dịch giọng nói: requires Auth
          if (isAuth)
            IconButton(
              icon: const Icon(Icons.mic_outlined),
              tooltip: 'Dịch bằng giọng nói',
              onPressed: () => _showComingSoon('Dịch giọng nói'),
            ),
          // UC06 — Dịch hình ảnh (OCR): requires Auth
          if (isAuth)
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: 'Dịch bằng hình ảnh',
              onPressed: () => _showComingSoon('Dịch hình ảnh'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            // Guest CTA banner — encourage sign-in for premium features
            if (!isAuth) _buildGuestBanner(cs, theme),
            _buildLangBar(cs),
            const SizedBox(height: 12),
            Expanded(flex: 5, child: _buildSourceCard(theme)),
            const SizedBox(height: 12),
            Expanded(flex: 5, child: _buildResultCard(theme, isAuth)),
          ],
        ),
      ),
    );
  }

  /// A compact banner shown to Guest users, informing them of the
  /// benefits of signing in (UC05, UC06, UC07, higher limits).
  Widget _buildGuestBanner(ColorScheme cs, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.08),
            cs.tertiary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đăng nhập để dịch giọng nói, hình ảnh, lưu từ vựng và nâng giới hạn.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push('/login'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Đăng nhập',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Language bar ----

  Widget _buildLangBar(ColorScheme cs) {
    final src = _findLang(_srcCode);
    final tgt = _findLang(_tgtCode);
    final canSwap = _srcCode != 'auto';

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              onTap: () => _pickLanguage(isSource: true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(src.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      src.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          RotationTransition(
            turns: Tween(begin: 0.0, end: 0.5).animate(
              CurvedAnimation(parent: _swapAnim, curve: Curves.easeInOut),
            ),
            child: IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              color: canSwap ? cs.primary : cs.onSurface.withValues(alpha: 0.3),
              tooltip: 'Đổi ngôn ngữ',
              onPressed: canSwap ? _swapLanguages : null,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(14),
              ),
              onTap: () => _pickLanguage(isSource: false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tgt.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      tgt.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Source card ----

  Widget _buildSourceCard(ThemeData theme) {
    final cs = theme.colorScheme;
    final hasText = _controller.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: label + clear button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 0),
            child: Row(
              children: [
                Text(
                  'Nguồn · ${_findLang(_srcCode).name}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (hasText)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Xóa',
                    color: cs.onSurfaceVariant,
                    onPressed: _clear,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // TextField
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Nhập văn bản cần dịch...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _onTextChanged,
              ),
            ),
          ),
          // Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TtsIconButton(
                  text: _controller.text,
                  languageCode: _srcCode == 'auto' ? 'en' : _srcCode,
                  tooltip: 'Phát âm văn bản nguồn',
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  tooltip: 'Sao chép',
                  color: hasText
                      ? AppTheme.primaryColor
                      : cs.onSurface.withValues(alpha: 0.3),
                  onPressed: hasText
                      ? () => _copyText(
                          _controller.text,
                          'Đã sao chép văn bản nguồn',
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Result card ----

  Widget _buildResultCard(ThemeData theme, bool isAuth) {
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'Dịch · ${_findLang(_tgtCode).name}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: BlocBuilder<TranslationCubit, TranslationState>(
                builder: (context, state) {
                  return switch (state) {
                    TranslationInitial() => _ResultHint(cs: cs),
                    TranslationInProgress() => const _ResultLoading(),
                    TranslationSuccess(translation: final t) => _ResultText(
                      text: t.translatedText,
                      theme: theme,
                    ),
                    TranslationFailure(message: final msg) => _ResultError(
                      message: msg,
                      theme: theme,
                    ),
                  };
                },
              ),
            ),
          ),
          // Action bar
          BlocBuilder<TranslationCubit, TranslationState>(
            builder: (context, state) {
              final resultText = state is TranslationSuccess
                  ? state.translation.translatedText
                  : null;
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Row(
                  children: [
                    // UC07 — Lưu từ vựng: requires Auth.
                    // Guest: show lock icon; Authenticated: show bookmark.
                    if (isAuth)
                      IconButton(
                        icon: const Icon(
                          Icons.bookmark_border_rounded,
                          size: 20,
                        ),
                        tooltip: 'Lưu từ vựng',
                        color: cs.onSurfaceVariant,
                        onPressed: () => _showComingSoon('Lưu từ vựng'),
                      )
                    else
                      Tooltip(
                        message: 'Đăng nhập để lưu từ vựng',
                        child: IconButton(
                          icon: const Icon(Icons.lock_outline_rounded, size: 18),
                          color: cs.onSurface.withValues(alpha: 0.3),
                          onPressed: () => context.push('/login'),
                        ),
                      ),
                    const Spacer(),
                    // UC03 — TTS: available to Guest and User.
                    if (resultText != null)
                      TtsIconButton(
                        text: resultText,
                        languageCode: _tgtCode,
                        tooltip: 'Phát âm bản dịch',
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 20),
                      tooltip: 'Sao chép',
                      color: resultText != null
                          ? AppTheme.primaryColor
                          : cs.onSurface.withValues(alpha: 0.3),
                      onPressed: resultText != null
                          ? () => _copyText(resultText, 'Đã sao chép bản dịch')
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result sub-states
// ---------------------------------------------------------------------------

class _ResultHint extends StatelessWidget {
  final ColorScheme cs;
  const _ResultHint({required this.cs});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.translate_rounded,
          size: 40,
          color: cs.primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        Text(
          'Bản dịch sẽ xuất hiện ở đây',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45)),
        ),
      ],
    ),
  );
}

class _ResultLoading extends StatelessWidget {
  const _ResultLoading();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: ShimmerTranslationLoading(lineCount: 4),
    );
  }
}

class _ResultText extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _ResultText({required this.text, required this.theme});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: AppTheme.primaryColor,
        height: 1.5,
      ),
    ),
  );
}

class _ResultError extends StatelessWidget {
  final String message;
  final ThemeData theme;
  const _ResultError({required this.message, required this.theme});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 36,
          color: theme.colorScheme.error.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Language picker bottom sheet
// ---------------------------------------------------------------------------

class _LanguagePickerSheet extends StatelessWidget {
  final List<_Lang> langs;
  final String selected;

  const _LanguagePickerSheet({required this.langs, required this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn ngôn ngữ',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: langs.length,
              itemBuilder: (ctx, i) {
                final l = langs[i];
                final isSelected = l.code == selected;
                return ListTile(
                  leading: Text(l.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(l.name),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  selected: isSelected,
                  selectedTileColor: cs.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => Navigator.of(ctx).pop(l.code),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
```

---

## Kết luận

**API dịch thuật cơ bản đã tích hợp đúng Clean Architecture** — flow từ UI → Cubit → UseCase → Repository → DataSource hoạt động tốt, có debounce, shimmer, error handling, timeout.

**4 bug đã được sửa:**
1. ✅ Guest giờ có thể chọn ngôn ngữ trong QuickTranslateWidget (không bị redirect login)
2. ✅ Route `/translate` giờ là public — Guest truy cập được
3. ✅ Authenticated user gửi Bearer token → backend áp dụng đúng rate limit User
4. ✅ TranslationPage phân biệt Guest/User — ẩn STT/OCR/Vocabulary cho Guest, hiện banner CTA đăng nhập

**Flutter analyze: 0 errors, 0 warnings** (chỉ 1 info pre-existing ở splash_page.dart)
