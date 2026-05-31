import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:frontend/injection_container.dart';
import 'mock_repositories.dart';
import 'e2e_seed_data.dart';

/// Test environment setup helper
class E2ETestHelper {
  static final GetIt _getIt = GetIt.instance;

  /// Initialize test environment with mock repositories
  static Future<void> setupTestEnvironment() async {
    // Clear previous instances
    _getIt.reset();

    // Register fake repositories
    _getIt.registerSingleton<FakeAuthRepository>(FakeAuthRepository());
    _getIt.registerSingleton<FakeTranslationRepository>(
      FakeTranslationRepository(),
    );
    _getIt.registerSingleton<FakeVocabularyRepository>(
      FakeVocabularyRepository(),
    );
    _getIt.registerSingleton<FakeAdminUsersRepository>(
      FakeAdminUsersRepository(),
    );
    _getIt.registerSingleton<FakeAdminQuestionBankRepository>(
      FakeAdminQuestionBankRepository(),
    );
    _getIt.registerSingleton<FakeAdminQuestionRepository>(
      FakeAdminQuestionRepository(),
    );
    _getIt.registerSingleton<FakeConversationRepository>(
      FakeConversationRepository(),
    );
    _getIt.registerSingleton<FakeSyncRepository>(FakeSyncRepository());

    // Initialize other necessary services
    WidgetsFlutterBinding.ensureInitialized();
  }

  /// Cleanup test environment
  static Future<void> teardownTestEnvironment() async {
    _getIt.reset();
  }

  /// Get fake auth repository
  static FakeAuthRepository getAuthRepository() =>
      _getIt<FakeAuthRepository>();

  /// Get fake translation repository
  static FakeTranslationRepository getTranslationRepository() =>
      _getIt<FakeTranslationRepository>();

  /// Get fake vocabulary repository
  static FakeVocabularyRepository getVocabularyRepository() =>
      _getIt<FakeVocabularyRepository>();

  /// Get fake admin users repository
  static FakeAdminUsersRepository getAdminUsersRepository() =>
      _getIt<FakeAdminUsersRepository>();

  /// Get fake admin question bank repository
  static FakeAdminQuestionBankRepository getAdminQuestionBankRepository() =>
      _getIt<FakeAdminQuestionBankRepository>();

  /// Get fake admin question repository
  static FakeAdminQuestionRepository getAdminQuestionRepository() =>
      _getIt<FakeAdminQuestionRepository>();

  /// Get fake conversation repository
  static FakeConversationRepository getConversationRepository() =>
      _getIt<FakeConversationRepository>();

  /// Get fake sync repository
  static FakeSyncRepository getSyncRepository() => _getIt<FakeSyncRepository>();
}

/// Common test expectations and matchers
class E2ETestExpectations {
  /// Expect success message
  static void expectSuccessMessage(WidgetTester tester, String message) {
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  }

  /// Expect error message
  static void expectErrorMessage(WidgetTester tester, String message) {
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  }

  /// Expect loading indicator
  static void expectLoadingIndicator(WidgetTester tester) {
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  }

  /// Expect widget text
  static void expectText(WidgetTester tester, String text) {
    expect(find.text(text), findsOneWidget);
  }

  /// Expect button exists
  static void expectButton(WidgetTester tester, String buttonText) {
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ElevatedButton &&
            widget.child is Text &&
            (widget.child as Text).data == buttonText,
      ),
      findsOneWidget,
    );
  }

  /// Expect list item
  static void expectListItem(WidgetTester tester, String itemText) {
    expect(find.text(itemText), findsOneWidget);
  }

  /// Expect no error
  static void expectNoError(WidgetTester tester) {
    expect(find.byType(SnackBar), findsNothing);
  }
}

/// Test utilities for common operations
class E2ETestUtils {
  /// Wait for widget to appear
  static Future<void> waitForWidget(
    WidgetTester tester,
    Type widget,
  ) async {
    await tester.pumpAndSettle();
    await tester.pumpUntilFound(find.byType(widget));
  }

  /// Wait for text to appear
  static Future<void> waitForText(
    WidgetTester tester,
    String text,
  ) async {
    await tester.pumpAndSettle();
    await tester.pumpUntilFound(find.text(text));
  }

  /// Tap button by text
  static Future<void> tapButton(WidgetTester tester, String text) async {
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();
  }

  /// Tap text
  static Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Enter text in text field
  static Future<void> enterText(
    WidgetTester tester,
    String hintText,
    String text,
  ) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pumpAndSettle();
  }

  /// Scroll to widget
  static Future<void> scrollToWidget(
    WidgetTester tester,
    Type widget,
  ) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(widget).first);
    await tester.pumpAndSettle();
  }

  /// Get text from widget
  static String getTextFromWidget(WidgetTester tester, String text) {
    final textWidget =
        find.text(text).evaluate().first.widget as Text;
    return textWidget.data ?? '';
  }

  /// Verify list contains text
  static bool listContainsText(WidgetTester tester, String text) {
    return find.text(text).evaluate().isNotEmpty;
  }

  /// Wait and verify
  static Future<void> waitAndVerify(
    WidgetTester tester,
    Future<void> Function() action,
    String expectedText,
  ) async {
    await action();
    await tester.pumpAndSettle();
    expect(find.text(expectedText), findsOneWidget);
  }
}

/// Screen navigation helpers
class E2EScreenNavigation {
  /// Navigate to login screen
  static Future<void> navigateToLogin(WidgetTester tester) async {
    await E2ETestUtils.waitForText(tester, 'Login');
  }

  /// Navigate to home screen after login
  static Future<void> navigateToHome(WidgetTester tester) async {
    await E2ETestUtils.waitForText(tester, 'Home');
  }

  /// Navigate to translation screen
  static Future<void> navigateToTranslation(WidgetTester tester) async {
    await E2ETestUtils.waitForWidget(tester, Text);
    // Find and tap translation nav item
    final translationButton = find.byTooltip('Dịch');
    if (translationButton.evaluate().isNotEmpty) {
      await tester.tap(translationButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to vocabulary screen
  static Future<void> navigateToVocabulary(WidgetTester tester) async {
    final vocabButton = find.byTooltip('Từ vựng');
    if (vocabButton.evaluate().isNotEmpty) {
      await tester.tap(vocabButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to conversation screen
  static Future<void> navigateToConversation(WidgetTester tester) async {
    final conversationButton = find.byTooltip('Hội thoại');
    if (conversationButton.evaluate().isNotEmpty) {
      await tester.tap(conversationButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to admin dashboard
  static Future<void> navigateToAdminDashboard(WidgetTester tester) async {
    await E2ETestUtils.waitForText(tester, 'Dashboard');
  }

  /// Navigate to admin users page
  static Future<void> navigateToAdminUsers(WidgetTester tester) async {
    final usersButton = find.byIcon(Icons.people);
    if (usersButton.evaluate().isNotEmpty) {
      await tester.tap(usersButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to admin question banks
  static Future<void> navigateToAdminQuestionBanks(
    WidgetTester tester,
  ) async {
    final banksButton = find.byIcon(Icons.book);
    if (banksButton.evaluate().isNotEmpty) {
      await tester.tap(banksButton);
      await tester.pumpAndSettle();
    }
  }

  /// Navigate to admin quiz editor
  static Future<void> navigateToAdminQuizEditor(WidgetTester tester) async {
    final editorButton = find.byIcon(Icons.quiz);
    if (editorButton.evaluate().isNotEmpty) {
      await tester.tap(editorButton);
      await tester.pumpAndSettle();
    }
  }
}

/// Auth flow helpers
class E2EAuthFlow {
  /// Login with credentials
  static Future<void> login(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    // Enter email
    await tester.enterText(
      find.byType(TextField).at(0),
      email,
    );
    await tester.pumpAndSettle();

    // Enter password
    await tester.enterText(
      find.byType(TextField).at(1),
      password,
    );
    await tester.pumpAndSettle();

    // Tap login button
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle(Duration(seconds: 1));
  }

  /// Login as admin
  static Future<void> loginAsAdmin(WidgetTester tester) async {
    await login(
      tester,
      E2ETestSeedData.adminUser['email'] as String,
      'password123',
    );
  }

  /// Login as regular user
  static Future<void> loginAsUser(WidgetTester tester) async {
    await login(
      tester,
      E2ETestSeedData.regularUser['email'] as String,
      'password123',
    );
  }

  /// Logout
  static Future<void> logout(WidgetTester tester) async {
    final settingsButton = find.byIcon(Icons.settings);
    if (settingsButton.evaluate().isNotEmpty) {
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();
    }

    final logoutButton = find.text('Đăng xuất');
    if (logoutButton.evaluate().isNotEmpty) {
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
    }
  }
}
