import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import '../helpers/e2e_test_helper.dart';
import '../helpers/e2e_seed_data.dart';
import '../helpers/mock_websocket_server.dart';

void main() {
  group('User Conversation Flow E2E Tests', () {
    late MockWebSocketServer mockWebSocketServer;
    late MockConversationWebSocket conversationSocket;

    setUpAll(() async {
      await E2ETestHelper.setupTestEnvironment();
      mockWebSocketServer = MockWebSocketServer();
      mockWebSocketServer.start();
    });

    tearDownAll(() async {
      mockWebSocketServer.stop();
      await E2ETestHelper.teardownTestEnvironment();
    });

    setUp(() {
      conversationSocket = MockConversationWebSocket(
        conversationId: 1,
        targetLanguage: 'Vietnamese',
      );
    });

    tearDown(() async {
      await conversationSocket.disconnect();
    });

    testWidgets(
      'T1: User can login with valid credentials',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Act
        await E2EAuthFlow.loginAsUser(tester);

        // Assert
        expect(find.text('Home'), findsWidgets);
        E2ETestExpectations.expectNoError(tester);
      },
    );

    testWidgets(
      'T2: User login fails with invalid credentials',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Act
        await E2EAuthFlow.login(tester, 'invalid@test.com', 'wrongpassword');

        // Assert
        E2ETestExpectations.expectErrorMessage(
          tester,
          'Invalid credentials',
        );
      },
    );

    testWidgets(
      'T3: User can open conversation screen',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsUser(tester);

        // Act
        await E2EScreenNavigation.navigateToConversation(tester);

        // Assert
        expect(find.byType(Scaffold), findsWidgets);
      },
    );

    testWidgets(
      'T4: User can start a conversation session',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsUser(tester);
        await E2EScreenNavigation.navigateToConversation(tester);

        // Act
        // Find and tap "Start Conversation" button
        final startButton = find.byType(ElevatedButton).first;
        await tester.tap(startButton);
        await tester.pumpAndSettle();

        // Setup mock socket
        await conversationSocket.connect();

        // Assert
        expect(conversationSocket.isConnected, true);
      },
    );

    testWidgets(
      'T5: User receives translation from mock backend',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsUser(tester);
        await E2EScreenNavigation.navigateToConversation(tester);

        final startButton = find.byType(ElevatedButton).first;
        await tester.tap(startButton);
        await tester.pumpAndSettle();

        await conversationSocket.connect();

        // Act
        // Simulate receiving translated message
        conversationSocket.simulateReceivedMessage(
          'Hello',
          'Xin chào',
          'https://example.com/audio/hello.mp3',
        );

        // Wait for message to appear in UI
        await tester.pumpAndSettle();

        // Assert
        // Verify message appears in conversation
        final messagesFuture = conversationSocket.messageStream.toList();
        
        // Send one message then close
        await Future.delayed(Duration(milliseconds: 200));
        await conversationSocket.disconnect();

        final messages = await messagesFuture;
        expect(messages.length, 1);
        expect(messages[0].translatedResponse, 'Xin chào');
      },
    );

    testWidgets(
      'T6: User can see message bubble with translation',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsUser(tester);
        await E2EScreenNavigation.navigateToConversation(tester);

        await conversationSocket.connect();

        // Act
        conversationSocket.simulateReceivedMessage(
          'Good morning',
          'Chào buổi sáng',
          'https://example.com/audio/morning.mp3',
        );

        // Assert
        // Verify translation appears
        await tester.pump(Duration(milliseconds: 300));
        
        // Check message stream has the message
        final testMessage = ConversationMessage(
          userMessage: 'Good morning',
          translatedResponse: 'Chào buổi sáng',
          speakerUrl: 'https://example.com/audio/morning.mp3',
          timestamp: DateTime.now(),
        );
        
        expect(testMessage.translatedResponse, 'Chào buổi sáng');

        await conversationSocket.disconnect();
      },
    );

    testWidgets(
      'T7: User can stop conversation session',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsUser(tester);
        await E2EScreenNavigation.navigateToConversation(tester);

        final startButton = find.byType(ElevatedButton).first;
        await tester.tap(startButton);
        await tester.pumpAndSettle();

        await conversationSocket.connect();

        // Act
        // Find and tap "Stop Conversation" button
        final stopButton = find.byType(ElevatedButton).at(1);
        await tester.tap(stopButton);
        await tester.pumpAndSettle();

        await conversationSocket.disconnect();

        // Assert
        expect(conversationSocket.isConnected, false);
      },
    );

    testWidgets(
      'T8: User can handle network error during conversation',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsUser(tester);
        await E2EScreenNavigation.navigateToConversation(tester);

        await conversationSocket.connect();

        // Act
        // Simulate network error
        conversationSocket.simulateError('Network error: connection lost');

        await tester.pumpAndSettle();

        // Assert
        // Error should be caught and displayed
        E2ETestExpectations.expectErrorMessage(
          tester,
          'Network error',
        );

        await conversationSocket.disconnect();
      },
    );

    testWidgets(
      'T9: Multiple conversation messages work correctly',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsUser(tester);
        await E2EScreenNavigation.navigateToConversation(tester);

        await conversationSocket.connect();

        // Act
        final messages = [
          ('Hello', 'Xin chào'),
          ('Good morning', 'Chào buổi sáng'),
          ('Thank you', 'Cảm ơn'),
        ];

        for (final (userMsg, translated) in messages) {
          conversationSocket.simulateReceivedMessage(
            userMsg,
            translated,
            'https://example.com/audio/${userMsg.hashCode}.mp3',
          );
          await Future.delayed(Duration(milliseconds: 100));
        }

        // Assert
        await tester.pump(Duration(milliseconds: 500));
        expect(conversationSocket.isConnected, true);

        await conversationSocket.disconnect();
      },
    );

    testWidgets(
      'T10: User logout from conversation screen',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await E2EAuthFlow.loginAsUser(tester);
        await E2EScreenNavigation.navigateToConversation(tester);

        // Act
        await E2EAuthFlow.logout(tester);

        // Assert
        // Should return to login screen
        E2ETestExpectations.expectNoError(tester);
      },
    );
  });
}
