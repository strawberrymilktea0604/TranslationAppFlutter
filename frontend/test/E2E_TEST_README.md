# E2E Test Documentation

## Overview

This directory contains comprehensive End-to-End (E2E) tests for the Translation App Flutter project. These tests are designed to run **independently of the backend**, using mock repositories and WebSocket servers.

## Test Structure

```
test/
├── helpers/
│   ├── mock_repositories.dart         # Mock implementations of all repositories
│   ├── e2e_seed_data.dart            # Predefined test data (users, banks, questions)
│   ├── mock_websocket_server.dart    # Mock WebSocket for real-time messaging
│   └── e2e_test_helper.dart          # Test utilities and navigation helpers
│
└── e2e/
    ├── user_conversation_flow_test.dart    # 10 user flow tests
    ├── admin_dashboard_flow_test.dart      # 14 admin flow tests
    └── complete_app_e2e_test.dart         # Full integration test suite
```

## Key Features

### ✅ Mock Repositories
- `FakeAuthRepository` - User authentication
- `FakeTranslationRepository` - Text translation
- `FakeVocabularyRepository` - Vocabulary management
- `FakeAdminUsersRepository` - Admin user management
- `FakeAdminQuestionBankRepository` - Quiz bank management
- `FakeAdminQuestionRepository` - Question CRUD
- `FakeConversationRepository` - Real-time conversations
- `FakeSyncRepository` - Data synchronization

### ✅ Seed Data
Pre-defined test users, question banks, questions, and translations:
```dart
E2ETestSeedData.seedUsers
E2ETestSeedData.seedAdminUsers
E2ETestSeedData.seedQuestionBanks
E2ETestSeedData.seedQuestions
E2ETestSeedData.seedVocabulary
```

### ✅ Mock WebSocket
Simulates real-time conversation without backend:
```dart
MockConversationWebSocket(
  conversationId: 1,
  targetLanguage: 'Vietnamese',
)
```

### ✅ Test Helpers
- `E2ETestHelper` - Setup/teardown, repository access
- `E2ETestExpectations` - Common assertions
- `E2ETestUtils` - Widget interactions
- `E2EScreenNavigation` - Screen navigation
- `E2EAuthFlow` - Login/logout flows

## Running Tests

### Run All E2E Tests
```bash
cd frontend
flutter test test/e2e/
```

### Run Specific Test File
```bash
flutter test test/e2e/user_conversation_flow_test.dart
flutter test test/e2e/admin_dashboard_flow_test.dart
flutter test test/e2e/complete_app_e2e_test.dart
```

### Run Single Test
```bash
flutter test test/e2e/user_conversation_flow_test.dart -n "T1: User can login"
```

### Run with Verbose Output
```bash
flutter test test/e2e/ -v
```

### Run Tests in Watch Mode (Auto-rerun on changes)
```bash
flutter test test/e2e/ --watch
```

## Test Coverage

### User Flow Tests (T1-T10)
```
T1:  User can login with valid credentials
T2:  User login fails with invalid credentials
T3:  User can open conversation screen
T4:  User can start a conversation session
T5:  User receives translation from mock backend
T6:  User can see message bubble with translation
T7:  User can stop conversation session
T8:  User can handle network error during conversation
T9:  Multiple conversation messages work correctly
T10: User logout from conversation screen
```

### Admin Flow Tests (A1-A14)
```
A1:  Admin can login with valid credentials
A2:  Admin login fails with non-admin account
A3:  Admin can view dashboard with statistics
A4:  Admin can view user list
A5:  Admin can ban a user
A6:  Admin can unban a user
A7:  Admin can view question banks
A8:  Admin can create a new question bank
A9:  Admin can edit a question bank
A10: Admin can add question to quiz
A11: Admin can edit quiz question
A12: Admin can delete quiz question
A13: Admin can toggle question bank active status
A14: Admin logout from dashboard
```

### Integration Tests
- Complete user flow (login → conversation → logout)
- Complete admin flow (login → manage users/banks → logout)
- Error handling validation
- Permission checking
- Seed data validation
- Repository mock validation
- WebSocket mock validation

## Test Seed Data

### Users
```dart
// Credentials
admin@test.com : password123  (admin role)
user@test.com : password123   (user role)
invalid@test.com : wrongpassword  (for error testing)
```

### Question Banks
1. **English Basics** (3 questions, active)
2. **Business English** (1 question, active)
3. **Travel Phrases** (0 questions, inactive)

### Questions Per Bank
- Bank 1: 2 questions about basic English
- Bank 2: 1 question about business terms
- All have Vietnamese translations for mock responses

### Admin Users
- 3 seed users for testing ban/unban functionality
- Mix of active and banned users

## Mock Repository Features

### Authentication
```dart
final auth = FakeAuthRepository();
await auth.login('admin@test.com', 'password123');  // Returns token
await auth.getAccessToken();                        // Get current token
await auth.logout();                                // Clear token
```

### Translation
```dart
final translation = FakeTranslationRepository();
final result = await translation.translateText(
  'hello',
  'English',
  'Vietnamese',
);
// Returns: {original_text, translated_text, source_language, target_language}
```

### User Management
```dart
final admin = FakeAdminUsersRepository();
final users = await admin.getUsers(1, 20);
await admin.banUser(1);    // Ban user
await admin.unbanUser(1);  // Unban user
```

### Question Banks
```dart
final banks = FakeAdminQuestionBankRepository();
await banks.getBanks(1, 20);              // List banks
await banks.createBank(title, desc, dur); // Create
await banks.updateBank(id, title, ...);   // Update
await banks.toggleBank(id);               // Toggle active
await banks.deleteBank(id);               // Delete
```

### Questions
```dart
final questions = FakeAdminQuestionRepository();
await questions.getQuestions(bankId, 1, 20);  // List questions
await questions.createQuestion(bankId, ...);  // Create
await questions.updateQuestion(id, ...);      // Update
await questions.toggleQuestion(id);           // Toggle active
await questions.deleteQuestion(id);           // Delete
```

### Conversations
```dart
final conv = FakeConversationRepository();
final conversation = await conv.startConversation('Vietnamese');
await conv.sendMessage(conversationId, 'Hello');  // Returns translated response
await conv.getConversationHistory(conversationId);
await conv.endConversation(conversationId);
```

## Mock WebSocket Features

### Setup and Connection
```dart
final socket = MockConversationWebSocket(
  conversationId: 1,
  targetLanguage: 'Vietnamese',
);
await socket.connect();        // Establish connection
expect(socket.isConnected, true);
```

### Simulating Server Responses
```dart
// Simulate receiving a translated message
socket.simulateReceivedMessage(
  'Hello',                           // User message
  'Xin chào',                       // Translation
  'https://example.com/audio/hello.mp3',  // Speaker URL
);

// Simulate error
socket.simulateError('Network error: connection lost');
```

### Message Stream
```dart
socket.messageStream.listen((message) {
  print('User said: ${message.userMessage}');
  print('Response: ${message.translatedResponse}');
  print('Audio: ${message.speakerUrl}');
});

// Simulate receiving 3 messages
await MockConversationScenarios.simulateSuccessfulConversation(
  socket,
  ['hello', 'good morning', 'thank you'],
);
```

### Cleanup
```dart
await socket.disconnect();  // Disconnect and close stream
expect(socket.isConnected, false);
```

## Common Testing Patterns

### Testing Login Flow
```dart
testWidgets('User login works', (tester) async {
  await tester.pumpWidget(MyApp());
  await E2EAuthFlow.loginAsUser(tester);
  expect(find.text('Home'), findsOneWidget);
});
```

### Testing Admin Operations
```dart
testWidgets('Admin can ban user', (tester) async {
  await tester.pumpWidget(MyApp());
  await E2EAuthFlow.loginAsAdmin(tester);
  await E2EScreenNavigation.navigateToAdminUsers(tester);
  
  // Tap ban button and verify success
  await tester.tap(find.byIcon(Icons.block).first);
  await tester.pumpAndSettle();
  E2ETestExpectations.expectSuccessMessage(tester, 'Đã khóa');
});
```

### Testing Conversations
```dart
testWidgets('Conversation messages work', (tester) async {
  final socket = MockConversationWebSocket(...);
  await socket.connect();
  
  socket.simulateReceivedMessage('Hello', 'Xin chào', 'audio.mp3');
  
  final messages = await socket.messageStream.take(1).toList();
  expect(messages[0].translatedResponse, 'Xin chào');
  
  await socket.disconnect();
});
```

### Testing Error Handling
```dart
testWidgets('Invalid credentials show error', (tester) async {
  await E2EAuthFlow.login(tester, 'invalid@test.com', 'wrong');
  E2ETestExpectations.expectErrorMessage(tester, 'Invalid');
});
```

## Debugging Tests

### Enable Verbose Logging
```bash
flutter test test/e2e/ -v
```

### Run Single Test with Debugging
```bash
flutter test test/e2e/user_conversation_flow_test.dart \
  -n "T1: User can login" \
  --verbose
```

### Check Widget Tree
In test code:
```dart
await tester.pumpWidget(MyApp());
expect(find.byType(MyWidget), findsOneWidget);

// Print widget tree
tester.printToConsole();
```

### Verify Mock Data
```dart
test('Verify seed data structure', () {
  expect(E2ETestSeedData.seedAdminUsers.length, 3);
  expect(E2ETestSeedData.seedQuestionBanks.length, 3);
  print(E2ETestSeedData.seedAdminUsers);  // Print for debugging
});
```

## Performance Tips

1. **Use `pumpAndSettle()`** to wait for animations
   ```dart
   await tester.pumpAndSettle();  // Waits for all animations
   ```

2. **Minimize mock responses** - Keep them fast
   ```dart
   // Good - returns immediately
   Future<String> login() async => 'token';
   
   // Avoid - unnecessary delays
   await Future.delayed(Duration(seconds: 1));
   ```

3. **Reuse test setup** with `setUpAll()`
   ```dart
   setUpAll(() async {
     await E2ETestHelper.setupTestEnvironment();  // Once for all tests
   });
   ```

4. **Parallel test execution** (if supported)
   ```bash
   flutter test test/e2e/ --concurrency=4
   ```

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Run E2E Tests
  run: |
    cd frontend
    flutter test test/e2e/ \
      --coverage \
      --coverage-path=coverage/lcov.info
```

### Coverage Report
```bash
flutter test test/e2e/ --coverage
# Check coverage
lcov -l coverage/lcov.info
```

## Troubleshooting

### Test hangs or times out
- Increase timeout: `flutter test --timeout=30s`
- Check for missing `pumpAndSettle()` calls
- Verify mock repository methods complete

### Widget not found
- Use `tester.pumpAndSettle()` to rebuild UI
- Check widget visibility (may need scroll)
- Use `tester.printToConsole()` to debug

### Mock data not loading
- Verify `E2ETestHelper.setupTestEnvironment()` called
- Check seed data paths are correct
- Print seed data for debugging

### WebSocket mock not working
- Ensure socket is `await connect()`ed before use
- Check `isConnected` property
- Verify stream listeners attached before sending data

## Best Practices

✅ **DO:**
- Use helper functions from `E2ETestHelper`
- Run tests before committing
- Keep mock responses simple and fast
- Use seed data consistently
- Write descriptive test names
- Verify both success and error cases
- Mock external dependencies

❌ **DON'T:**
- Depend on backend being running
- Use sleep() - use pumpAndSettle() instead
- Hardcode test data - use E2ETestSeedData
- Skip error test cases
- Create circular dependencies in mocks
- Modify production code for testing

## Next Steps

1. ✅ **Run tests** - Make sure they pass
   ```bash
   flutter test test/e2e/
   ```

2. ✅ **Add to CI/CD** - Run tests on every PR
   ```yaml
   - name: E2E Tests
     run: flutter test test/e2e/
   ```

3. ✅ **Extend coverage** - Add tests for new features
   ```bash
   # Create new test file
   flutter test test/e2e/new_feature_test.dart
   ```

4. ✅ **Generate reports** - Track test coverage
   ```bash
   flutter test test/e2e/ --coverage
   ```

## Support

For issues or questions about E2E tests:
1. Check this documentation
2. Review existing test examples
3. Check Flutter testing docs: https://flutter.dev/docs/testing/integration-tests
4. Review mockito docs: https://github.com/dart-lang/mockito

---

**Last Updated**: June 1, 2026
**Test Count**: 24 tests (10 user + 14 admin)
**Mock Repositories**: 8 implementations
**Seed Data**: 3+ test users, 3 banks, 3+ questions
