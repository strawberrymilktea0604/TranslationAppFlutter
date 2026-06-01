# E2E Test Setup and Execution Guide

## Quick Start

### 1. Install Dependencies
```bash
cd frontend
flutter pub get
```

### 2. Run All E2E Tests
```bash
flutter test test/e2e/
```

### 3. Run Specific Test Suite
```bash
# User conversation flow tests
flutter test test/e2e/user_conversation_flow_test.dart

# Admin dashboard flow tests
flutter test test/e2e/admin_dashboard_flow_test.dart

# Complete integration tests
flutter test test/e2e/complete_app_e2e_test.dart
```

### 4. Run Single Test
```bash
flutter test test/e2e/user_conversation_flow_test.dart -n "T1: User can login"
```

---

## Test Files Overview

| File | Purpose | Tests | Status |
|------|---------|-------|--------|
| `test/helpers/mock_repositories.dart` | Mock implementations | 8 repos | ✅ Ready |
| `test/helpers/e2e_seed_data.dart` | Test data | 3+ users, 3 banks | ✅ Ready |
| `test/helpers/mock_websocket_server.dart` | WebSocket mock | Real-time msgs | ✅ Ready |
| `test/helpers/e2e_test_helper.dart` | Test utilities | Navigation, assertions | ✅ Ready |
| `test/e2e/user_conversation_flow_test.dart` | User flows | 10 tests | ✅ Ready |
| `test/e2e/admin_dashboard_flow_test.dart` | Admin flows | 14 tests | ✅ Ready |
| `test/e2e/complete_app_e2e_test.dart` | Integration | 12 tests | ✅ Ready |

---

## Mock Repositories

### FakeAuthRepository
- Login with credentials
- Get/store access token
- Logout
- Refresh token

**Seed Users:**
```
admin@test.com : password123
user@test.com : password123
```

### FakeTranslationRepository
- Translate text between languages
- Save translation history
- Get translation history

### FakeAdminUsersRepository
- Get users list
- Ban/unban users

**Seed Data:** 3 test users

### FakeAdminQuestionBankRepository
- CRUD operations for question banks
- Toggle bank active/inactive

**Seed Data:** 3 question banks

### FakeAdminQuestionRepository
- CRUD operations for questions
- Toggle question active/inactive

**Seed Data:** 3 questions

### FakeConversationRepository
- Start/end conversations
- Send messages (auto-translated)
- Get conversation history

### MockConversationWebSocket
- Simulate real-time messaging
- Simulate errors and timeouts
- Message streaming

---

## Test Scenarios

### User Conversation Flow (10 tests)
```
T1  → Login with valid credentials
T2  → Login fails with invalid credentials
T3  → Open conversation screen
T4  → Start a conversation session
T5  → Receive translation from mock backend
T6  → See message bubble with translation
T7  → Stop conversation session
T8  → Handle network error during conversation
T9  → Multiple conversation messages work
T10 → Logout from conversation screen
```

### Admin Dashboard Flow (14 tests)
```
A1  → Admin login with valid credentials
A2  → Admin login fails with non-admin account
A3  → View dashboard with statistics
A4  → View user list
A5  → Ban a user
A6  → Unban a user
A7  → View question banks
A8  → Create a new question bank
A9  → Edit a question bank
A10 → Add question to quiz
A11 → Edit quiz question
A12 → Delete quiz question
A13 → Toggle question bank active status
A14 → Logout from dashboard
```

### Complete Integration (12 tests)
```
1. Complete user flow (login → conversation → logout)
2. Complete admin flow (login → manage users/banks → logout)
3. Error handling (invalid credentials)
4. Permission checking (regular user vs admin)
5. Seed data validation
6. Auth repository mock
7. Translation repository mock
8. Admin repository mock
9. Question repository mock
10. Conversation repository mock
11. WebSocket mock
12. All test data accessible
```

---

## Workflow: Adding New Tests

### 1. Create Test File
```bash
# In frontend/test/e2e/
touch new_feature_test.dart
```

### 2. Import Helpers
```dart
import '../helpers/e2e_test_helper.dart';
import '../helpers/e2e_seed_data.dart';
```

### 3. Setup and Teardown
```dart
void main() {
  group('New Feature Tests', () {
    setUpAll(() async {
      await E2ETestHelper.setupTestEnvironment();
    });

    tearDownAll(() async {
      await E2ETestHelper.teardownTestEnvironment();
    });

    testWidgets('Test case', (tester) async {
      // Test code
    });
  });
}
```

### 4. Common Operations
```dart
// Login
await E2EAuthFlow.loginAsUser(tester);
await E2EAuthFlow.loginAsAdmin(tester);

// Navigation
await E2EScreenNavigation.navigateToHome(tester);

// Expectations
E2ETestExpectations.expectSuccessMessage(tester, 'Success!');
E2ETestExpectations.expectErrorMessage(tester, 'Error!');

// Utilities
await E2ETestUtils.tapButton(tester, 'Button Text');
await E2ETestUtils.enterText(tester, 'TextField', 'text');
```

### 5. Run New Test
```bash
flutter test test/e2e/new_feature_test.dart
```

---

## Running Tests with Options

### Verbose Output
```bash
flutter test test/e2e/ -v
```

### With Coverage Report
```bash
flutter test test/e2e/ --coverage
```

### Watch Mode (Auto-rerun on changes)
```bash
flutter test test/e2e/ --watch
```

### Specific Pattern
```bash
flutter test test/e2e/ -k "Admin"  # Run only admin tests
```

### Timeout Configuration
```bash
flutter test test/e2e/ --timeout=60s
```

---

## CI/CD Integration

### GitHub Actions
```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: 'latest'
      
      - name: Get dependencies
        run: |
          cd frontend
          flutter pub get
      
      - name: Run E2E Tests
        run: |
          cd frontend
          flutter test test/e2e/ --coverage
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v2
```

### Local Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

cd frontend
flutter test test/e2e/ --timeout=30s

if [ $? -ne 0 ]; then
  echo "E2E tests failed. Push aborted."
  exit 1
fi
```

---

## Debugging Tests

### Print Widget Tree
```dart
testWidgets('Debug test', (tester) async {
  await tester.pumpWidget(MyApp());
  tester.printToConsole();  // Print widget tree
});
```

### Take Screenshot
```dart
testWidgets('Screenshot test', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.takeScreenshot(name: 'home_screen');
});
```

### Wait for Widget
```dart
await E2ETestUtils.waitForWidget(tester, MyWidget);
```

### Check Widget Properties
```dart
final widget = find.byType(TextField).evaluate().first.widget as TextField;
print(widget.hintText);
```

---

## Expected Test Results

### Successful Run
```
╭─ null
├─ All E2E tests pass
├─ Tests: 36 total (24 from flows + 12 integration)
├─ Time: ~2-3 minutes
└─ No backend required ✅
```

### Test Results Breakdown
| Category | Count | Status |
|----------|-------|--------|
| User Flow Tests | 10 | ✅ Pass |
| Admin Flow Tests | 14 | ✅ Pass |
| Integration Tests | 12 | ✅ Pass |
| **Total** | **36** | **✅ Pass** |

---

## Seed Data Reference

### Users (3)
```
admin@test.com (admin role)
user@test.com (regular role)
invalid@test.com (for error testing)
```

### Question Banks (3)
```
1. English Basics (active, 2 questions)
2. Business English (active, 1 question)
3. Travel Phrases (inactive, 0 questions)
```

### Questions (3)
```
1. "What is hello in Vietnamese?" (Bank 1)
2. "What is goodbye in Vietnamese?" (Bank 1)
3. "What is the term for business meeting?" (Bank 2)
```

### Admin Users (3)
```
user1@test.com (active)
user2@test.com (active)
user3@test.com (banned)
```

---

## Troubleshooting

### Tests Timeout
- Increase timeout: `flutter test --timeout=60s`
- Check for missing `pumpAndSettle()` calls
- Verify mock responses are returning data

### "Widget not found" Error
- Add `await tester.pumpAndSettle()` after actions
- Check widget is visible (may need scroll)
- Use `tester.printToConsole()` to debug

### Mock not working
- Verify `setupTestEnvironment()` called in `setUpAll()`
- Check repository access: `E2ETestHelper.getAuthRepository()`
- Review mock implementation in helper files

### WebSocket tests fail
- Ensure socket is `await connect()`ed
- Check `isConnected` before using socket
- Verify listeners attached before sending data

---

## Best Practices

### ✅ DO
- Use E2E helpers for common operations
- Test both success and error paths
- Keep tests independent (no shared state)
- Use seed data consistently
- Name tests descriptively
- Mock all external dependencies

### ❌ DON'T
- Depend on backend being running
- Use `sleep()` - use `pumpAndSettle()` instead
- Hardcode test data - use `E2ETestSeedData`
- Modify production code for testing
- Skip error test cases
- Create inter-test dependencies

---

## Advanced: Custom Mock Repositories

### Create Custom Mock
```dart
class CustomMockRepository implements MyRepository {
  @override
  Future<void> operation() async {
    // Custom implementation
  }
}
```

### Register in setupTestEnvironment
```dart
_getIt.registerSingleton<CustomMockRepository>(
  CustomMockRepository(),
);
```

### Use in Tests
```dart
final mock = E2ETestHelper.getIt<CustomMockRepository>();
```

---

## Contact & Support

- **Documentation**: See `E2E_TEST_README.md`
- **Helpers**: `test/helpers/*.dart`
- **Test Files**: `test/e2e/*.dart`
- **Flutter Testing Docs**: https://flutter.dev/docs/testing
- **Mockito Guide**: https://github.com/dart-lang/mockito

---

**Last Updated**: June 1, 2026
**Status**: ✅ Ready for Production
**Coverage**: 36 tests across all major flows
**Backend Dependency**: ❌ None (fully mocked)
