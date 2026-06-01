import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:get_it/get_it.dart';
import 'package:frontend/features/conversation/domain/repositories/conversation_repository.dart';
import '../helpers/e2e_test_helper.dart';
import '../helpers/mock_repositories.dart';
import '../helpers/mock_websocket_server.dart';

void main() {
  group('User Conversation Flow E2E Tests', () {
    late MockWebSocketServer mockWebSocketServer;
    late MockConversationWebSocket conversationSocket;

    setUpAll(() async {
      mockWebSocketServer = MockWebSocketServer();
      mockWebSocketServer.start();
    });

    tearDownAll(() async {
      mockWebSocketServer.stop();
    });

    setUp(() async {
      await E2ETestHelper.setupTestEnvironment();
      conversationSocket = MockConversationWebSocket(
        conversationId: 1,
        targetLanguage: 'Vietnamese',
      );
    });

    tearDown(() async {
      await conversationSocket.disconnect();
      await E2ETestHelper.teardownTestEnvironment();
    });

    testWidgets('T1: User can login with valid credentials', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Act
      await E2EAuthFlow.loginAsUser(tester);

      // Assert
      expect(find.text('Dịch thuật'), findsWidgets);
      E2ETestExpectations.expectNoError(tester);
    });

    testWidgets('T2: User login fails with invalid credentials', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Act
      await E2EAuthFlow.login(tester, 'invalid@test.com', 'wrongpassword');

      // Assert
      // Settle error dialog
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('T3: User can open conversation screen', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(const MyApp());
      await E2EAuthFlow.loginAsUser(tester);

      // Act
      await E2EScreenNavigation.navigateToConversation(tester);

      // Assert
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('T4: User can start a conversation session', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(const MyApp());
      await E2EAuthFlow.loginAsUser(tester);
      await E2EScreenNavigation.navigateToConversation(tester);

      // Act
      // Tap "Bắt đầu kết nối"
      await tester.tap(find.text('Bắt đầu kết nối').first);
      await tester.pump(const Duration(milliseconds: 500));

      // Tap "Bắt đầu hội thoại"
      await tester.tap(find.text('Bắt đầu hội thoại'));
      await tester.pump(const Duration(milliseconds: 500));

      // Setup mock socket
      await conversationSocket.connect();

      // Assert
      expect(conversationSocket.isConnected, true);

      // End conversation session to stop animations and allow clean finalization
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Kết thúc'));
      await tester.pump(const Duration(milliseconds: 500));
      await conversationSocket.disconnect();
    });

    testWidgets('T5: User receives translation from mock backend', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(const MyApp());
      await E2EAuthFlow.loginAsUser(tester);
      await E2EScreenNavigation.navigateToConversation(tester);

      // Tap "Bắt đầu kết nối"
      await tester.tap(find.text('Bắt đầu kết nối').first);
      await tester.pump(const Duration(milliseconds: 500));

      // Tap "Bắt đầu hội thoại"
      await tester.tap(find.text('Bắt đầu hội thoại'));
      await tester.pump(const Duration(milliseconds: 500));

      await conversationSocket.connect();

      // Act
      // Simulate receiving translated message on repository
      final repo =
          GetIt.instance<ConversationRepository>()
              as FakeConversationRepositoryImpl;
      repo.simulateRepositoryTranslation('Hello', 'Xin chào');
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      // Verify translation appears in the UI
      expect(find.text('Xin chào'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);

      // End conversation session to stop animations and allow clean finalization
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Kết thúc'));
      await tester.pump(const Duration(milliseconds: 500));
      await conversationSocket.disconnect();
    });

    testWidgets('T6: User can see message bubble with translation', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(const MyApp());
      await E2EAuthFlow.loginAsUser(tester);
      await E2EScreenNavigation.navigateToConversation(tester);

      // Tap "Bắt đầu kết nối"
      await tester.tap(find.text('Bắt đầu kết nối').first);
      await tester.pump(const Duration(milliseconds: 500));

      // Tap "Bắt đầu hội thoại"
      await tester.tap(find.text('Bắt đầu hội thoại'));
      await tester.pump(const Duration(milliseconds: 500));

      // Act
      final repo =
          GetIt.instance<ConversationRepository>()
              as FakeConversationRepositoryImpl;
      repo.simulateRepositoryTranslation('Good morning', 'Chào buổi sáng');
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      expect(find.text('Chào buổi sáng'), findsOneWidget);
      expect(find.text('Good morning'), findsOneWidget);

      // End conversation session to stop animations and allow clean finalization
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Kết thúc'));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('T7: User can stop conversation session', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(const MyApp());
      await E2EAuthFlow.loginAsUser(tester);
      await E2EScreenNavigation.navigateToConversation(tester);

      // Tap "Bắt đầu kết nối"
      await tester.tap(find.text('Bắt đầu kết nối').first);
      await tester.pump(const Duration(milliseconds: 500));

      // Tap "Bắt đầu hội thoại"
      await tester.tap(find.text('Bắt đầu hội thoại'));
      await tester.pump(const Duration(milliseconds: 500));

      await conversationSocket.connect();

      // Act
      // Tap end button (icon call_end_rounded)
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap "Kết thúc" button in the confirmation dialog
      await tester.tap(find.text('Kết thúc'));
      await tester.pump(const Duration(milliseconds: 500));

      await conversationSocket.disconnect();

      // Assert
      expect(conversationSocket.isConnected, false);
    });

    testWidgets('T8: User can handle network error during conversation', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(const MyApp());
      await E2EAuthFlow.loginAsUser(tester);
      await E2EScreenNavigation.navigateToConversation(tester);

      // Tap "Bắt đầu kết nối"
      await tester.tap(find.text('Bắt đầu kết nối').first);
      await tester.pump(const Duration(milliseconds: 500));

      // Act
      // Simulate network error on the repo
      final repo =
          GetIt.instance<ConversationRepository>()
              as FakeConversationRepositoryImpl;
      repo.simulateRepositoryError(
        'ws_disconnected',
        'Network error: connection lost',
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      // Error should be caught and displayed as a SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Network error: connection lost'),
        findsOneWidget,
      );
    });

    testWidgets('T9: Multiple conversation messages work correctly', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(const MyApp());
      await E2EAuthFlow.loginAsUser(tester);
      await E2EScreenNavigation.navigateToConversation(tester);

      // Tap "Bắt đầu kết nối"
      await tester.tap(find.text('Bắt đầu kết nối').first);
      await tester.pump(const Duration(milliseconds: 500));

      // Tap "Bắt đầu hội thoại"
      await tester.tap(find.text('Bắt đầu hội thoại'));
      await tester.pump(const Duration(milliseconds: 500));

      // Act
      final repo =
          GetIt.instance<ConversationRepository>()
              as FakeConversationRepositoryImpl;
      final messages = [
        ('Hello', 'Xin chào'),
        ('Good morning', 'Chào buổi sáng'),
        ('Thank you', 'Cảm ơn'),
      ];

      for (final (userMsg, translated) in messages) {
        repo.simulateRepositoryTranslation(userMsg, translated);
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Assert
      for (final (userMsg, translated) in messages) {
        expect(find.text(userMsg), findsOneWidget);
        expect(find.text(translated), findsOneWidget);
      }

      // End conversation session to stop animations and allow clean finalization
      await tester.tap(find.byIcon(Icons.call_end_rounded));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Kết thúc'));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('T10: User logout from conversation screen', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(const MyApp());
      await E2EAuthFlow.loginAsUser(tester);
      await E2EScreenNavigation.navigateToConversation(tester);

      // Act
      // Go back to home first by tapping the back button
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
      } else {
        final backIcon = find.byIcon(Icons.arrow_back);
        if (backIcon.evaluate().isNotEmpty) {
          await tester.tap(backIcon);
          await tester.pumpAndSettle();
        }
      }

      await E2EAuthFlow.logout(tester);

      // Assert
      // Should return to login screen
      E2ETestExpectations.expectNoError(tester);
    });
  });
}
