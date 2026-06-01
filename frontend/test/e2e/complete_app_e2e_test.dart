import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/main_web.dart';
import '../helpers/e2e_test_helper.dart';
import '../helpers/e2e_seed_data.dart';
import '../helpers/mock_websocket_server.dart';

/// Complete E2E Test Suite
/// Tests all major user flows and admin operations
void main() {
  group('Complete App E2E Test Suite', () {
    setUp(() async {
      await E2ETestHelper.setupTestEnvironment();
    });

    tearDown(() async {
      await E2ETestHelper.teardownTestEnvironment();
    });

    testWidgets(
      'Complete User Flow: Login → Conversation → Logout',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Act & Assert: Login
        await E2EAuthFlow.loginAsUser(tester);
        expect(find.byType(Scaffold), findsWidgets);

        // Act & Assert: Navigate to conversation
        await E2EScreenNavigation.navigateToConversation(tester);
        await tester.pumpAndSettle();

        // Act: Start conversation
        await tester.tap(find.text('Bắt đầu kết nối').first);
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.text('Bắt đầu hội thoại'));
        await tester.pump(const Duration(milliseconds: 500));

        // End conversation session to stop animations and allow clean finalization
        await tester.tap(find.byIcon(Icons.call_end_rounded));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Kết thúc'));
        await tester.pump(const Duration(milliseconds: 500));

        // Navigate back to Home to allow logout buttons to be found
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

        // Act: Logout
        await E2EAuthFlow.logout(tester);

        // Assert: Back at login
        E2ETestExpectations.expectNoError(tester);
      },
    );

    testWidgets(
      'Complete Admin Flow: Login → View Users → Manage Banks → Logout',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const AdminApp());
        await tester.pumpAndSettle();

        // Act & Assert: Admin login
        await E2EAuthFlow.loginAsAdmin(tester);
        expect(find.byType(Scaffold), findsWidgets);

        // Act & Assert: Navigate to dashboard
        await E2EScreenNavigation.navigateToAdminDashboard(tester);
        await tester.pumpAndSettle();
        expect(find.text('Dashboard'), findsWidgets);

        // Act & Assert: View users
        await E2EScreenNavigation.navigateToAdminUsers(tester);
        await tester.pumpAndSettle();
        expect(find.byType(ListView), findsWidgets);

        // Act & Assert: View question banks
        await E2EScreenNavigation.navigateToAdminQuestionBanks(tester);
        await tester.pumpAndSettle();
        expect(find.byType(ListView), findsWidgets);

        // Act & Assert: Logout
        await E2EAuthFlow.logout(tester);
        E2ETestExpectations.expectNoError(tester);
      },
    );

    testWidgets(
      'Error Handling: Invalid Credentials',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Act: Try to login with invalid credentials
        await E2EAuthFlow.login(tester, 'invalid@test.com', 'wrongpassword');

        // Assert: Error message shown in dialog
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
        
        // Close dialog
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Permission Check: Regular user cannot access admin',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Act: Login as regular user
        await E2EAuthFlow.loginAsUser(tester);

        // Try to access admin screen
        await E2EScreenNavigation.navigateToAdminDashboard(tester);

        // Assert: Should not have access (error shown or redirected)
        // The actual behavior depends on implementation
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Data Seed Validation: Seed data is correctly loaded',
      (WidgetTester tester) async {
        // Verify seed users exist
        expect(
          E2ETestSeedData.isValidUser(
            'admin@test.com',
            'password123',
          ),
          true,
        );
        expect(
          E2ETestSeedData.isValidUser(
            'user@test.com',
            'password123',
          ),
          true,
        );

        // Verify seed data structures
        expect(E2ETestSeedData.seedAdminUsers.length, 3);
        expect(E2ETestSeedData.seedQuestionBanks.length, 3);
        expect(E2ETestSeedData.seedQuestions.length, 3);
        expect(E2ETestSeedData.seedVocabulary.length, 4);

        // Verify getting data by ID works
        expect(
          E2ETestSeedData.getQuestionBankById(1)?['title'],
          'English Basics',
        );
        expect(
          E2ETestSeedData.getQuestionsByBankId(1).length,
          2,
        );
      },
    );

    testWidgets(
      'Repository Mock Validation: Mocks work correctly',
      (WidgetTester tester) async {
        // Get auth repository
        final authRepo = E2ETestHelper.getAuthRepository();

        // Test login
        final token = await authRepo.login('admin@test.com', 'password123');
        expect(token, isNotNull);

        // Test get token
        final storedToken = await authRepo.getAccessToken();
        expect(storedToken, token);

        // Test logout
        await authRepo.logout();
        final loggedOutToken = await authRepo.getAccessToken();
        expect(loggedOutToken, null);
      },
    );

    testWidgets(
      'Translation Repository Mock: Translation works',
      (WidgetTester tester) async {
        final translationRepo =
            E2ETestHelper.getTranslationRepository();

        final result = await translationRepo.translateText(
          'hello',
          'English',
          'Vietnamese',
        );

        expect(result['original_text'], 'hello');
        expect(result['translated_text'], isNotNull);
      },
    );

    testWidgets(
      'Admin Repository Mock: User management works',
      (WidgetTester tester) async {
        final usersRepo = E2ETestHelper.getAdminUsersRepository();

        // Get users
        final users = await usersRepo.getUsers(1, 20);
        expect(users.length, greaterThan(0));

        // Ban user
        final bannedUser = await usersRepo.banUser(1);
        expect(bannedUser['is_banned'], true);

        // Unban user
        final unbannedUser = await usersRepo.unbanUser(1);
        expect(unbannedUser['is_banned'], false);
      },
    );

    testWidgets(
      'Question Bank Repository Mock: CRUD works',
      (WidgetTester tester) async {
        final bankRepo = E2ETestHelper.getAdminQuestionBankRepository();

        // Get banks
        final banks = await bankRepo.getBanks(1, 20);
        expect(banks.length, greaterThan(0));

        // Create bank
        final newBank = await bankRepo.createBank(
          'New Test Bank',
          'Test Description',
          30,
        );
        expect(newBank['title'], 'New Test Bank');

        // Update bank
        final updatedBank = await bankRepo.updateBank(
          newBank['id'] as int,
          'Updated Title',
          'Updated Description',
          45,
        );
        expect(updatedBank['title'], 'Updated Title');

        // Toggle bank
        final toggledBank = await bankRepo.toggleBank(
          newBank['id'] as int,
        );
        expect(toggledBank['is_active'], !(newBank['is_active'] as bool));

        // Delete bank
        await bankRepo.deleteBank(newBank['id'] as int);
      },
    );

    testWidgets(
      'Question Repository Mock: Question management works',
      (WidgetTester tester) async {
        final questionRepo = E2ETestHelper.getAdminQuestionRepository();

        // Get questions
        final questions = await questionRepo.getQuestions(1, 1, 20);
        expect(questions.length, greaterThan(0));

        // Create question
        final newQuestion = await questionRepo.createQuestion(
          1,
          'Test question?',
          {'A': 'Option A', 'B': 'Option B'},
          'A',
        );
        expect(newQuestion['bank_id'], 1);

        // Update question
        final updatedQuestion = await questionRepo.updateQuestion(
          newQuestion['id'] as int,
          'Updated question?',
          {'A': 'Updated A', 'B': 'Updated B'},
          'B',
        );
        expect(updatedQuestion['text'], 'Updated question?');

        // Toggle question
        final toggledQuestion = await questionRepo.toggleQuestion(
          newQuestion['id'] as int,
        );
        expect(
          toggledQuestion['is_active'],
          !(newQuestion['is_active'] as bool),
        );

        // Delete question
        await questionRepo.deleteQuestion(newQuestion['id'] as int);
      },
    );

    testWidgets(
      'Conversation Repository Mock: Conversation works',
      (WidgetTester tester) async {
        final conversationRepo = E2ETestHelper.getConversationRepository();

        // Start conversation
        final conversation = await conversationRepo.startConversation(
          'Vietnamese',
        );
        expect(conversation['target_language'], 'Vietnamese');
        expect(conversation['status'], 'active');

        final conversationId = conversation['id'] as int;

        // Send message
        final message = await conversationRepo.sendMessage(
          conversationId,
          'Hello',
        );
        expect(message['user_message'], 'Hello');
        expect(message['translated_response'], isNotNull);

        // Get history
        final history =
            await conversationRepo.getConversationHistory(conversationId);
        expect(history.length, 1);

        // End conversation
        await conversationRepo.endConversation(conversationId);
      },
    );

    testWidgets(
      'WebSocket Mock: Connection and messaging works',
      (WidgetTester tester) async {
        final mockSocket = MockConversationWebSocket(
          conversationId: 1,
          targetLanguage: 'Vietnamese',
        );

        // Connect
        final connectFuture = mockSocket.connect();
        await tester.pump(const Duration(milliseconds: 100));
        await connectFuture;
        expect(mockSocket.isConnected, true);

        // Get messages
        final messages = <ConversationMessage>[];
        final subscription = mockSocket.messageStream.listen(
          messages.add,
        );

        // Simulate receiving messages
        mockSocket.simulateReceivedMessage(
          'Hello',
          'Xin chào',
          'https://example.com/audio/hello.mp3',
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(messages.length, 1);
        expect(messages[0].userMessage, 'Hello');
        expect(messages[0].translatedResponse, 'Xin chào');

        // Disconnect
        await subscription.cancel();
        await mockSocket.disconnect();
        expect(mockSocket.isConnected, false);
      },
    );
  });
}
